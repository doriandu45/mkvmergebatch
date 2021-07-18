#!/bin/bash

printarr() { declare -n __p="$1"; for k in "${!__p[@]}"; do printf "%s=%s\n" "$k" "${__p[$k]}" ; done ;  } 

# Create the array
declare -A jsons
declare -a folders
declare -A files
declare -a templates
declare -A fileTemplateMap

# Color definition
COLOR_CURRENT_LINE='\e[47;30m'
COLOR_RESET='\e[0m'
COLOR_ERROR='\e[41;37;1m\a'
COLOR_DISABLED_NON_CURRENT='\e[90m'
COLOR_DISABLED_CURRENT='\e[100;37m'

# Column sizes used for the display
# Because we print each line one by one, for now I will use fixed lengths. Maybe one day I'll implement dynamic sizing
SIZE_ID=4
SIZE_TYPE=3
SIZE_DEFAULT=2
SIZE_LANG=3
SIZE_CODEC=25
SIZE_NAME=35
SIZE_SHIFT=6

# Separator used for displaying columns
COLUMN_SEPARATOR="|"
HEADER_SEPARATOR="-"
COLUMN_HEADER_INTERSECTION="+"

# Indices constants used for the templates
TRACK_ID=0
TRACK_TYPE=1
TRACK_DEFAULT=2
TRACK_LANG=3
TRACK_CODEC=4
TRACK_NAME=5
TRACK_SHIFT=6
TRACK_DISABLED=7


# Newline constant used to add '\n' to strings
# See https://stackoverflow.com/a/64938613
nl="$(printf '\nq')"
nl=${nl%q}

# printf the $1 exactly as the size $2. Used to display the columns
function printfAsSize() {
	cutText=$(cut -c -$2 <<<$1)
	# Unfortunately printf count unicode characters such as é as 2 characters which breaks the padding
	# This can be fixed by counting the difference between the displayed characters and the true characters count
	# https://unix.stackexchange.com/a/609135
	bytes=$(printf '%s' "$1" | wc -c)
	chars=$(printf '%s' "$1" | wc -m)
	n=$(($2+bytes-chars))
	printf "%-${n}s" "$cutText"
}

# printf the same pattern ($1) N ($2) times. Used to display the line below the header
function nprintf() {
	for n in $(seq $2)
	do
		printf "$1"
	done
}

# Prints a line ($1) of the screen. $2 sets if the line is selected or not
function printLine() {
	# We parse the current line with the IFS as ; for printing
	IFS=";"
	currentLine=(${currentTemplate[$1]})
	
	if [[ "$2" = true ]]
	then
		if [[ "${currentLine[TRACK_DISABLED]}" = "D" ]]
		then
			printf "$COLOR_DISABLED_CURRENT"
		else
			printf "$COLOR_CURRENT_LINE"
		fi
	else
		if [[ "${currentLine[TRACK_DISABLED]}" = "D" ]]
		then
			printf "$COLOR_DISABLED_NON_CURRENT"
		fi
	fi
	
	printfAsSize "${currentLine[$TRACK_ID]}" "$SIZE_ID"
	printf "$COLUMN_SEPARATOR"
	printfAsSize "${currentLine[$TRACK_TYPE]}" "$SIZE_TYPE"
	printf "$COLUMN_SEPARATOR"
	printfAsSize "${currentLine[$TRACK_DEFAULT]}" "$SIZE_DEFAULT"
	printf "$COLUMN_SEPARATOR"
	printfAsSize "${currentLine[$TRACK_LANG]}" "$SIZE_LANG"
	printf "$COLUMN_SEPARATOR"
	printfAsSize "${currentLine[$TRACK_CODEC]}" "$SIZE_CODEC"
	printf "$COLUMN_SEPARATOR"
	printfAsSize "${currentLine[$TRACK_NAME]}" "$SIZE_NAME"
	printf "$COLUMN_SEPARATOR"
	printfAsSize "${currentLine[$TRACK_SHIFT]}" "$SIZE_SHIFT"
	printf "$COLOR_RESET\n"
}

function printHeader() {
	# Prints the header
	printfAsSize "ID" "$SIZE_ID"
	printf "$COLUMN_SEPARATOR"
	printfAsSize "T" "$SIZE_TYPE"
	printf "$COLUMN_SEPARATOR"
	printfAsSize "D" "$SIZE_DEFAULT"
	printf "$COLUMN_SEPARATOR"
	printfAsSize "Lan" "$SIZE_LANG"
	printf "$COLUMN_SEPARATOR"
	printfAsSize "Codec" "$SIZE_CODEC"
	printf "$COLUMN_SEPARATOR"
	printfAsSize "Track name" "$SIZE_NAME"
	printf "$COLUMN_SEPARATOR"
	printfAsSize "Shift" "$SIZE_SHIFT"
	printf "\n"

	# Prints the line
	nprintf "$HEADER_SEPARATOR" "$SIZE_ID"
	printf "$COLUMN_HEADER_INTERSECTION"
	nprintf "$HEADER_SEPARATOR" "$SIZE_TYPE"
	printf "$COLUMN_HEADER_INTERSECTION"
	nprintf "$HEADER_SEPARATOR" "$SIZE_DEFAULT"
	printf "$COLUMN_HEADER_INTERSECTION"
	nprintf "$HEADER_SEPARATOR" "$SIZE_LANG"
	printf "$COLUMN_HEADER_INTERSECTION"
	nprintf "$HEADER_SEPARATOR" "$SIZE_CODEC"
	printf "$COLUMN_HEADER_INTERSECTION"
	nprintf "$HEADER_SEPARATOR" "$SIZE_NAME"
	printf "$COLUMN_HEADER_INTERSECTION"
	nprintf "$HEADER_SEPARATOR" "$SIZE_SHIFT"
	printf "\n"
}

function printFooter() {
	# Prints the keyboard shortcuts
	printf " \n" # The space is needed because the array don't work with empty lines
	echo "UP/DOWN: Select track"
	echo "-/PG UP: shift track upwards"
	echo "+/PG DOWN: shift track downards"
	echo "D: Set/unset as default track"
	echo "F: Set/unset as forced track (for subtitles)"
	echo "L: Set track language"
	echo "N: Set track name"
	echo "S: Set track shift (in ms)"
	echo "SPACE: Enable/disable track (disabled track won't be copied)"
	echo "RETURN: Apply the template and set the next one"
}

function printAllLines() {
	for i in "${!currentTemplate[@]}"
	do
		printLine $i $1
	done
}

# Regenerate the whole screen in memory
function redraw() {

	printHeader
	
	for i in "${!currentTemplate[@]}"
	do
		printLine $i false
	done
	
	printFooter
}

# Prints the $file array in a pretty format
function printFiles() {
	# First cell
	printf "File\\Folder\t"
	# Print folders
	for i in "${folders[@]}"
	do
		printf "$i\t"
	done
	printf "Template\n"
	
	# For each file
	for i in $(seq 0 $(($fileNb - 1)))
	do
		printf "$i\t"
		# For each folder
		for j in "${folders[@]}"
		do
			if [[ -v files["$j $i"] ]]
			then # File exists in array
				printf "${files[$j $i]}\t"
			else # File don't exist in array
				printf "[none]\t"
			fi
		done
		# Remove the trailing \t and print newline
		printf "${fileTemplateMap[$i]}\n"
	done
}

# Generate the json for mkvmerge. The file number $1 must be specified
# WARNING: This will permanently edit the template, by sorting it and removing disabled tracks
function generateJson() {
	printf "[\n"
	# Output file
	printf '\t"-o",\n'
	printf '\t"out/'$1'.mkv",\n'
	
	# Remove disabled tracks
	IFS=";"
	for i in "${!currentTemplate[@]}"
	do
		declare -a currentLine
		currentLine=(${currentTemplate[$i]})
		[[ "${currentLine[$TRACK_DISABLED]}" = "D" ]] && unset currentTemplate[$i]
	done
	# Sort the template so each file is in order
	IFS=$nl
	sorted=($(sort <<<"${currentTemplate[*]}"))
	
	# Get the last file ID in the template
	# NOTE: The file ID in the template (FID:TID) is different from the file ID in the folders
	# A file may also be skipped if no track are selected from the file (which is dumb, but that can happen)
	maxFile=$(cut -d: -f1<<<${sorted[-1]})
	declare -i currentFile=0
	
	
	# For each file in the template
	for i in $(seq 0 $maxFile)
	do
		declare -a tracks=()
		# We find the next file in the folder structure
		while ! [[ -v files["$currentFile $1"] ]]
		do
			currentFile=$currentFile+1
		done
		
		# We extract only the tracks that belong to this file
		for j in "${!sorted[@]}"
		do
			[[ "$(cut -d: -f1<<<${sorted[$j]})" = "$i" ]] && tracks+=(${sorted[$j]})
		done
		
		# We separate tracks by their types beacause mkvmerge needs that separation to select tracks
		# Since we will be parsing each track, we also print parameters for each track on the way
		videoTracks=""
		audioTracks=""
		subsTracks=""
		
		IFS=$nl
		for track in "${tracks[@]}"
		do
			IFS=";"
			declare -a currentLine
			currentLine=(${track})
			currentID="${currentLine[$TRACK_ID]}"
			currentID=$(cut -d: -f2<<<${currentID})
			currentType="${currentLine[$TRACK_TYPE]}"
			currentDefault="${currentLine[$TRACK_DEFAULT]}"
			currentLang="${currentLine[$TRACK_LANG]}"
			currentCodec="${currentLine[$TRACK_CODEC]}"
			currentName="${currentLine[$TRACK_NAME]}"
			currentShift="${currentLine[$TRACK_SHIFT]}"
			currentDisabled="${currentLine[$TRACK_DISABLED]}"
			
			case "$currentType" in
				"(V)")
					[[ "$videoTracks" = "" ]] || videoTracks="${videoTracks},"
					videoTracks="${videoTracks}${currentID}"
				;;
				"(A)")
					[[ "$audioTracks" = "" ]] || audioTracks="${audioTracks},"
					audioTracks="${audioTracks}${currentID}"
				;;
				"(S)")
					[[ "$subsTracks" = "" ]] || subsTracks="${subsTracks},"
					subsTracks="${subsTracks}${currentID}"
				;;
			esac
			
			# Default and forced track
			defaultStatus=$(cut -c -1 <<<$currentDefault)
			forcedStatus=$(cut -c 2- <<<$currentDefault)
			printf '\t"--default-track",\n'
			if [[ "$defaultStatus" = "D" ]]
			then
				printf '\t"'$currentID':true",\n'
			else
				printf '\t"'$currentID':false",\n'
			fi
			
			printf '\t"--forced-track",\n'
			if [[ "$forcedStatus" = "F" ]]
			then
				printf '\t"'$currentID':true",\n'
			else
				printf '\t"'$currentID':false",\n'
			fi
			
			# Track language
			if ! [[ "$currentLang" = "" ]]
			then
				printf '\t"--language",\n'
				printf '\t"'$currentID':'$currentLang'",\n'
			fi
			# Track name
			if ! [[ "$currentName" = "" ]]
			then
				printf '\t"--track-name",\n'
				printf '\t"'$currentID':'$currentName'",\n'
			fi
			# Track shift if needed
			if ! [[ "$currentShift" = "" ]]
			then
				printf '\t"--sync",\n'
				printf '\t"'$currentID':'$currentShift'",\n'
			fi
		done
		
		# Tracks
		if [[ "$videoTracks" = "" ]]
		then
			printf '\t"--no-video",\n'
		else
			printf '\t"--video-tracks",\n'
			printf '\t"'$videoTracks'",\n'
		fi
		if [[ "$audioTracks" = "" ]]
		then
			printf '\t"--no-audio",\n'
		else
			printf '\t"--audio-tracks",\n'
			printf '\t"'$audioTracks'",\n'
		fi
		if [[ "$subsTracks" = "" ]]
		then
			printf '\t"--no-subtitles",\n'
		else
			printf '\t"--subtitle-tracks",\n'
			printf '\t"'$subsTracks'",\n'
		fi
		
		# File
		printf '\t"'$currentFile'/'${files[$currentFile $1]}'",\n'
		
		
		currentFile=$currentFile+1
		IFS=$nl
	done
	# Finally, we add the track order
	printf '\t"--track-order",\n'
	printf '\t"'$trackOrder'"\n'
	
	# And we clone the json array
	printf "]"
}


# Swaps line $1 with line $2
function swapLines() {
	swapedLine="${currentTemplate[$2]}"
	currentTemplate[$2]="${currentTemplate[$1]}"
	currentTemplate[$1]="$swapedLine"
	
	swapedLine="${screenLinesSelected[$2]}"
	screenLinesSelected[$2]="${screenLinesSelected[$1]}"
	screenLinesSelected[$1]="$swapedLine"
	
	swapedLine="${screenLinesUnselected[$2]}"
	screenLinesUnselected[$2]="${screenLinesUnselected[$1]}"
	screenLinesUnselected[$1]="$swapedLine"
}

# ==============================================
# Loads file information

declare -i fileNb=0

# Loops through each numbered folders
for folder in $(find . -type d -regex \.\\/[0-9]*)
do
	trimmedFolder=$(echo $folder | cut -c 3-) # (cut -c 3-) return N instead of ./N
	echo Parsing folder $trimmedFolder:
	folders+=($trimmedFolder)
	
	# Loops trough each file in $folder
	for file in $(ls $folder)
	do
		echo \>Parsing file $file...
		
		# Add $file into $files only if $file does not already exists
		# Based on https://stackoverflow.com/a/47541882
		# if ! printf '%s\n' "${files[@]}" | grep -q -P $(eval echo "'^$file\$'")
		# then
			# files+=($file)
		# fi
		
		# Add the $file to the $files array and its json
		
		found=false
		json="$(mkvmerge -J $folder/$file)"
		
		for i in "${folders[@]}"
		do
			for j in $(seq 0 $(($fileNb - 1)))
			do
				# If the file don't exist at the id $i $j, we skip it
				[[ -v files["$i $j"] ]] || continue;
				fileToTest=${files[$i $j]}
				if [[ "${fileToTest%.*}" = "${file%.*}" ]]
				then
					found=true
					files["$trimmedFolder $j"]="$file"
					jsons["$trimmedFolder $j"]="$json"
					break
				fi
			done
			[[ "$found" = true ]] && break;
		done
		
		
		# If the file don't exist at all, we add it at a new id
		if [[ "$found" = false ]]
		then
			files["$trimmedFolder $fileNb"]="$file"
			jsons["$trimmedFolder $fileNb"]="$json"
			fileNb=$fileNb+1
		fi
		
	done
done





# ==============================================
# Parses the jsons to make the templates

# For each file
declare -i fileID
declare -i lastIndex=0

for file in $(seq 0 $(($fileNb - 1)))
do
	currentTemplate=""
	fileID=0
	for folder in "${folders[@]}"
	do
		# If the file don't exist, we skip
		[[ -v files["$folder $file"] ]] || continue;
		currentTemplate+=$(echo ${jsons[$folder $file]} | jq -r '.tracks | map( "'$fileID':" + (.id | tostring) + ";" + (if .type == "video" then "(V)" elif .type == "audio" then "(A)" elif .type == "subtitles" then "(S)" else "(?)" end)+ ";" + (if .properties.default_track == true then "D" else "-" end) + (if .properties.forced_track == true then "D" else "-" end) + ";"+ .properties.language + ";" + .codec + ";" + .properties.track_name +";;") | join("\n") ')
		currentTemplate+=$nl
		fileID=$fileID+1
	done
	currentTemplate=${currentTemplate%$nl} # Remove the trailing \n
	
	# Add the current template to the templates list (without duplicates) and add the matching index to $fileTemplateMap
	
	found=false
	#Since the IFS typically contains \n, it messes up when $currentTemplate is added to the array by removing all the \n.
	oldIFS="$IFS"
	IFS=""
	
	
	for i in "${!templates[@]}"
	do
		template="${templates[$i]}"
		
		if [ "$template" = "$currentTemplate" ]
		then
			found=true
			fileTemplateMap[$file]=$i
			break
		fi
	done
	if [ "$found" = false ]
	then
		templates+=("$currentTemplate")
		fileTemplateMap[$file]=$lastIndex
		lastIndex=$lastIndex+1
	fi
	
	IFS="$oldIFS"
done

printFiles | column -ts "$(printf "\t")"



# ==============================================
# Asks the user the final settings for each template and generate the json with the arguments for mkvmerge

echo "======================"
echo "${#templates[@]} template(s) found"

declare -i headerSize=$(wc -l <<<$(printHeader))
declare -i footerSize=$(wc -l <<<$(printFooter))

for t in "${!templates[@]}"
do
	declare -i pos=0
	declare -a currentTemplate
	oldIFS="$IFS"
	IFS=$nl
	# We put each line of $template in an array element. We use the IFS as \n to do that$
	currentTemplate=(${templates[$t]})
	
	arraySize=${#currentTemplate[@]}
	
	declare -a screenLinesUnselected
	declare -a screenLinesSelected
	screenLinesUnselected=($(printAllLines false))
	screenLinesSelected=($(printAllLines true))
	
	
	stty -echo
	printf '\e[?25l'
	
	printHeader
	# Go down (tracks number) lines to print the footer
	nprintf "\n" ${arraySize}
	printFooter
	
	
	while :
	do
		# We print the template
		IFS=$nl
		declare -a currentLine
		
		# Disable keyboard echo and hide terminal cursor
		stty -echo
		printf '\e[?25l'
		
		# Go up (footer size+array size) lines to print the array
		printf "\e[${arraySize}A\e[${footerSize}A\e[0G"
		
		
		for i in "${!screenLinesUnselected[@]}"
		do
			if [[ $i -eq $pos ]]
			then
				printf -- "${screenLinesSelected[$i]}\n"
			else
				printf -- "${screenLinesUnselected[$i]}\n"
			fi
		done
		
		# Go down (footer size) lines
		printf "\e[${footerSize}B\e[0G"
		
		
		# Show terminal cursor
		printf '\e[?25h'
		
		# We parse the current line with the IFS as ; for editing the line
		IFS=";"
		declare -a currentLine
		currentLine=(${currentTemplate[$pos]})

		currentID="${currentLine[$TRACK_ID]}"
		currentType="${currentLine[$TRACK_TYPE]}"
		currentDefault="${currentLine[$TRACK_DEFAULT]}"
		currentLang="${currentLine[$TRACK_LANG]}"
		currentCodec="${currentLine[$TRACK_CODEC]}"
		currentName="${currentLine[$TRACK_NAME]}"
		currentShift="${currentLine[$TRACK_SHIFT]}"
		currentDisabled="${currentLine[$TRACK_DISABLED]}"
		
		
		# We process user input
		
		# Flush keyboard buffer
		while read -t 0.01; do :; done
		# https://stackoverflow.com/a/46481173
		read -rsn1 mode
		if [[ $mode == $(printf "\u1b") ]]
		then
			read -rsn2 mode # read 2 more chars
		fi
		printf "\e[K"
		IFS=$nl
		mustRedraw=false
		mustRegenerateLine=false
		case $mode in
			'[A') # UP
				pos=$pos-1
				[ "$pos" = "-1" ] && pos=${#currentTemplate[@]}-1
			;;
			'[B') # DOWN
				pos=$pos+1
				[ "$pos" = "${#currentTemplate[@]}" ] && pos=0
			;;
			'-' | '[5') #PGUP - Shift track upwards
				if [[ "$pos" = "0" ]]
				then
					printf "${COLOR_ERROR}You are already at the top!${COLOR_RESET}"
				else
					swapLines $pos $(($pos-1))
					pos=$pos-1
				fi
			;;
			'+' | '[6') #PGDOWN - Shift track downards
				if [[ $pos -eq $((${#currentTemplate[@]}-1)) ]]
				then
					printf "${COLOR_ERROR}You are already at the bottom!${COLOR_RESET}"
				else
					swapLines $pos $(($pos+1))
					pos=$pos+1
				fi
			;;
			'd' | 'D') # Change track default
				defaultStatus=$(cut -c -1 <<<$currentDefault)
				forcedStatus=$(cut -c 2- <<<$currentDefault)
				if [[ "$defaultStatus" = "D" ]]
				then
					currentDefault="-$forcedStatus"
				else
					currentDefault="D$forcedStatus"
				fi
				mustRegenerateLine=true
			;;
			'f' | 'F') # Change track forced
				defaultStatus=$(cut -c -1 <<<$currentDefault)
				forcedStatus=$(cut -c 2- <<<$currentDefault)
				if [[ "$forcedStatus" = "F" ]]
				then
					currentDefault="${defaultStatus}-"
				else
					currentDefault="${defaultStatus}F"
				fi
				mustRegenerateLine=true
			;;
			'l' | 'L') # Change track language
				stty echo
				read -e -p "Enter the new track language: " -i "$currentLang" currentLang
				# Remove the prompt
				printf "\e[1A\e[0G\e[2K"
				mustRegenerateLine=true
			;;
			'n' | 'N') # Change track name
				stty echo
				read -e -p "Enter the new track name: " -i "$currentName" currentName
				# Remove the prompt
				printf "\e[1A\e[0G\e[2K"
				mustRegenerateLine=true
			;;
			's' | 'S') # Change track shift
				stty echo
				while :
				do
					printf "\e[2K"
					read -e -p "Enter the new shift in ms: " -i "$currentShift" newShift
					printf "\e[2K"
					# If the filed is empty
					if [ -z "$newShift"  ]
					then
						currentShift=""
						break
					fi
					# Else, we check that it is a correct integer https://stackoverflow.com/a/19116862
					if [ "$newShift" -eq "$newShift" ] 2>/dev/null
					then
						currentShift=$newShift
						break
					else
						printf "${COLOR_ERROR}Please input a correct integer!${COLOR_RESET}\e[1A\e[0G"
					fi
				done
				# Remove the prompt
				printf "\e[1A\e[0G\e[2K"
				mustRegenerateLine=true
			;;
			" ") #SPACE
				if [[ "$currentDisabled" = "D" ]]
				then
					currentDisabled=""
				else
					currentDisabled="D"
				fi
				mustRegenerateLine=true
			;;
			"") # RETURN
				break
			;;
		esac
		
		
		if [[ "$mustRegenerateLine" = true ]]
		then
			currentTemplate[$pos]="${currentID};${currentType};${currentDefault};${currentLang};${currentCodec};${currentName};${currentShift};${currentDisabled}"
			screenLinesSelected[$pos]="$(printLine $pos true)"
			screenLinesUnselected[$pos]="$(printLine $pos false)"
		fi
		if [[ "$mustRedraw" = true ]]
		then
			screenLinesUnselected=($(printAllLines false))
			screenLinesSelected=($(printAllLines true))
		fi
		
		
	done
	stty echo
	printf "\n"
	
	
	echo "Generating the jsons for mkvmerge"
	
	[[ -d "json" ]] || mkdir "json"
	
	trackOrder=""
	for i in "${!currentTemplate[@]}"
	do
		IFS=";"
		declare -a currentLine
		currentLine=(${currentTemplate[$i]})
		[[ "${currentLine[$TRACK_DISABLED]}" = "D" ]] && continue
		if [[ "$trackOrder" = "" ]]
		then
			trackOrder="${currentLine[$TRACK_ID]}"
		else
			trackOrder="${trackOrder},${currentLine[$TRACK_ID]}"
		fi
	done
	 
	
	IFS=$nl
	for file in $(seq 0 $(($fileNb - 1)))
	do
		# If the file don't belong to this template, we skip it
		[[ "${fileTemplateMap[$file]}" = "$t" ]] || continue
		generateJson $file >"json/${file}.json"
		
	done
	
	echo "Done!"
	
	
	printf "\n\n"
	unset pos
	unset currentTemplate
done

IFS=$nl
# Finally, we merge each file one by one
for file in $(ls json)
do
	mkvmerge @"json/${file}"
done
IFS=$oldIFS



unset jsons
unset folders
unset files

unset fileID
unset lastIndex