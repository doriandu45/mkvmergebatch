#!/bin/bash

printarr() { declare -n __p="$1"; for k in "${!__p[@]}"; do printf "%s=%s\n" "$k" "${__p[$k]}" ; done ;  } 

# Create the array
declare -A jsons
declare -a folders
declare -A files
declare -a templates
declare -A fileTemplateMap

oldIFS="$IFS"

# Color definition
COLOR_CURRENT_LINE='\e[47;30m'
COLOR_RESET='\e[0m'
COLOR_ERROR='\e[41;37;1m\a'
COLOR_DISABLED_NON_CURRENT='\e[90m'
COLOR_DISABLED_CURRENT='\e[100;37m'
COLOR_HINT='\e[38;5;99m'

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


# Newline constant used to add '\n' to strings
# See https://stackoverflow.com/a/64938613
nl="$(printf '\nq')"
nl=${nl%q}


# Parse a template line ($1) into separate variables using read
# In the past, I used an array like array=($line) with the IFS set at ';' however, that messed up with certain characters like '*'
function parseLine() {
	IFS=";"
	read currentID currentType currentDefault currentLang currentCodec currentName currentShift currentDisabled<<<$1
}

# If a "multi value" is used (different value for different files), the variable $1 is in the form of "*( [file]=value ...)"
# Here, if $1 begins with '*', we want to extract the right value from the file $2
function parseMVal() {
	eval "mValLine=\$$1"
	# Checks if $1 begins with '*'
	[[ "$(cut -c -1 <<<$mValLine)" != "*" ]] && return
	declare -A mValArray
	IFS=" "
	eval "mValArray=$(cut -c 2- <<<$mValLine)"
	mValLine="${mValArray[$2]}"
	eval "$1=\$mValLine"
	
}

# Loads the configuration from settings.sh if it exists
if [[ -f "./settings.sh" ]]
then
	source ./settings.sh
else
	echo "WARNING: Config file not found. Using default values"
	DEFAULT_FILE_REGEX=('([sS][0-9][0-9][eE])([0-9][0-9])' '([0-9][0-9])')
	DEFAULT_REGEX_MATCH_NB=(2 1)
	DEFAULT_OUTPUT_NAME='${regex_match}'
	MKVFONTMAN_LIB_FILE="mkvfontman/lib.sh"
fi

# Loads the MKVFontMan lib if existing
if [[ -f "%MKVFONTMAN_LIB_FILE" ]]
then
	source "%MKVFONTMAN_LIB_FILE"
	MKVFONTMAN_LOADED=true
else
	MKVFONTMAN_LOADED=false
fi

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

# calls pintfAsSize but checks ifor the sepcial case of multiple values (begins with '*') and don't display the technical data
# Takes the same parameters as printfAsSize
function checkAndPrintfAsSize() {
	cutText=$(cut -c -1 <<<$1)
	if [[ "$cutText" = "*" ]]
	then
		printfAsSize "*" "$2"
	else
		printfAsSize "$1" "$2"
	fi
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
	parseLine "${currentTemplate[$1]}"
	
	if [[ "$2" = true ]]
	then
		if [[ "$currentDisabled" = "D" ]]
		then
			printf "$COLOR_DISABLED_CURRENT"
		else
			printf "$COLOR_CURRENT_LINE"
		fi
	else
		if [[ "$currentDisabled" = "D" ]]
		then
			printf "$COLOR_DISABLED_NON_CURRENT"
		fi
	fi
	
	printfAsSize "$currentID" "$SIZE_ID"
	printf "$COLUMN_SEPARATOR"
	printfAsSize "$currentType" "$SIZE_TYPE"
	printf "$COLUMN_SEPARATOR"
	printfAsSize "$currentDefault" "$SIZE_DEFAULT"
	printf "$COLUMN_SEPARATOR"
	checkAndPrintfAsSize "$currentLang" "$SIZE_LANG"
	printf "$COLUMN_SEPARATOR"
	printfAsSize "$currentCodec" "$SIZE_CODEC"
	printf "$COLUMN_SEPARATOR"
	checkAndPrintfAsSize "$currentName" "$SIZE_NAME"
	printf "$COLUMN_SEPARATOR"
	checkAndPrintfAsSize "$currentShift" "$SIZE_SHIFT"
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
	printf "Regex\tTemplate\n"
	
	IFS=$nl
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
		# Prints the end of the line
		printf "${files[regex $i]}\t${fileTemplateMap[$i]}\n"
	done
}

# Generate the json for mkvmerge. The file number $1 must be specified
# The $trackOrder must also be set
# WARNING: This will permanently edit the template, by sorting it and removing disabled tracks
function generateJson() {
	printf "[\n"
	# Output file
	printf '\t"-o",\n'
	# To set the output file name, we set ${regex_match} and ${file_id}
	regex_match="${files[regex $file]}"
	file_id="$file"

	printf '\t"out/'$(eval "echo $DEFAULT_OUTPUT_NAME")'.mkv",\n'
	
	# Remove disabled tracks
	for i in "${!currentTemplate[@]}"
	do
		parseLine "${currentTemplate[$i]}"
		[[ "$currentDisabled" = "D" ]] && unset currentTemplate[$i]
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
		copyChapters="false"
		copyAttachments="false"
		
		IFS=$nl
		for track in "${tracks[@]}"
		do
			parseLine "${track}"
			currentID=$(cut -d: -f2<<<${currentID})
			currentFilepath="$currentFile/${files[$currentFile $1]}"
			# Apply the right "multi value" if needed
			parseMVal "currentLang" "$currentFilepath"
			parseMVal "currentName" "$currentFilepath"
			parseMVal "currentShift" "$currentFilepath"
			
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
				"Ch.")
					copyChapters="true"
				;;
				"At.")
					copyAttachments="true"
				;;
			esac
			
			# Special "tracks"
			# TODO: Special case to copy only specific attachments from a file
			if [[ "$currentType" = "Ch." ]]
			then
				# Chapter language
				if ! [[ "$currentLang" = "" ]]
				then
					printf '\t"--chapter-language",\n'
					printf '\t"'$currentLang'",\n'
				fi
				# Chapter shift if needed
				if ! [[ "$currentShift" = "" ]]
				then
					printf '\t"--chapter-sync",\n'
					printf '\t"'$currentShift'",\n'
				fi
				continue # We don't want to follow the classical tracks process
			fi
			if [[ "$currentType" = "At." ]]
			then
				# Well, we don't have anything to do here... Yet (see TODO above)
				continue # We don't want to follow the classical tracks process
			fi
			
			
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
		
		# Special "Tracks"
		if [[ "$copyChapters" = "false" ]]
		then
			printf '\t"--no-chapters",\n'
		fi
		if [[ "$copyAttachments" = "false" ]]
		then
			printf '\t"--no-attachments",\n'
		fi
		
		# File
		printf '\t"'$currentFilepath'",\n'
		
		# Extra attachments in the "attachments" folder
		IFS=$nl
		if [[ -d "attachments" ]]
		then
			for attach in $(ls "attachments")
			do
				extension=$(echo "${attach##*.}" | awk '{print tolower($0)}')
				if [[ -v MIME_OVERRIDES["$extension"] ]]
				then
					mime="${MIME_OVERRIDES[$extension]}"
				else
					mime="$(file --mime-type -b "attachments/$attach")"
				fi
				printf '\t"--attachment-name",\n'
				printf '\t"'$attach'",\n'
				printf '\t"--attachment-mime-type",\n'
				printf '\t"'$mime'",\n'
				printf '\t"--attach-file",\n'
				printf '\t"attachments/'$attach'",\n'
			done
		fi
		
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

# Handle settings imput
# $1: prompt
# $2: type ("string" or "integer")
# $3: variable to set
# $4: enable multiple values (defaults to true)
function valueInput() {
	errorPrinted="false"
	stty echo
	while :
	do
		printf "\e[2K"
		# If no error is printed and multiple values are enabled, print the hint below
		if [[ "$4" != "false" ]] && [[ "$errorPrinted" = "false" ]]
		then
			printf '\n'
			printf "${COLOR_HINT}You can use \'*\' to set different values for different files${COLOR_RESET}"
			# Go one line up
			printf '\e[1A\e[0G'
		fi
		
		eval 'read -e -p "'$1'" -i "$'$3'" newvalue'
		errorPrinted="false"
		
		
		# If the input is "*", we enter multi values mode if enabled
		if [[ "$4" != "false" ]] && [[ "$newvalue" = "*" ]]
		then
			multiValueInput "$1" "$2" "newvalue" "false"
			break
		fi
		
		# If we want a string, we break immediatly to skip integer check
		[[ "$2" = "string" ]] && break
		
		# If the filed is empty
		if [ -z "$newvalue"  ]
		then
			newvalue=""
			break
		fi
		# Else, we check that it is a correct integer https://stackoverflow.com/a/19116862
		if [ "$newvalue" -eq "$newvalue" ] 2>/dev/null
		then
			break
		else
			printf "\e[2K${COLOR_ERROR}Please input a correct integer!${COLOR_RESET}\e[1A\e[0G"
			errorPrinted="true"
		fi
	done
	printf "\e[2K\e[1A\e[2K"
	eval "$3=\$newvalue"
}

# Handle different inputs for different files
# $1: prompt
# $2: type (see above)
# $3: variable to set
# $t (must be set): current template
function multiValueInput() {
	# Get the file ID from the selectd track
	currentFID=$(cut -d: -f1<<<${currentID})
	
	declare -a mValFilename
	declare -a mValIds
	declare -a mValIsSelected
	declare -a mValValues
	declare -i mValFilesNb=0
	
	# Look for all the files
	IFS=$nl
	for file in $(seq 0 $(($fileNb - 1)))
	do
		# If the file don't belong to this template, we skip it
		[[ "${fileTemplateMap[$file]}" = "$t" ]] || continue
		# Now we look for the Nth folder containing the file, with N being the FID
		declare -i filesFound=-1
		declare -i iFolder=0
		while ! [[ "$filesFound" = "$currentFID" ]]
		do
			if [[ -v files["$iFolder $file"] ]]
			then
				filesFound=$filesFound+1
			fi
			[[ "$filesFound" = "$currentFID" ]] && break
			iFolder=$iFolder+1
		done
		mValFilename+=("$iFolder/${files[$iFolder $file]}")
		mValIds+=("$file")
		mValIsSelected+=("false")
		mValFilesNb=$mValFilesNb+1
		mValValues+=("")
	done
	
	declare -i mValPos=0
	
	
	# Interface loop
	while :
	do
		stty -echo
		printf '\e[?25l'
		declare -i mValPrintedLines=0
		# Print all files
		for mValI in "${!mValFilename[@]}"
		do
			printf "\e[2K"
			[[ "$mValPos" = "$mValI" ]] && printf "$COLOR_CURRENT_LINE"
			if [[ "${mValIsSelected[$mValI]}" = "true" ]]
			then
				printf "> "
			else
				printf "  "
			fi
			printf "${mValFilename[$mValI]}: ${mValValues[$mValI]} ${COLOR_RESET}\n"
			mValPrintedLines=$mValPrintedLines+1
		done
		
		printf "\n"
		echo "UP/DOWN: Highlight file"
		echo "SPACE: select/unselect file for bulk editing"
		echo "E: edit values for all selected files (if any) or the current highlited file if none are selected"
		echo "A: select all files"
		echo "U: unselect all files"
		echo "RETURN: Apply values"
		mValPrintedLines=$mValPrintedLines+7
		
		
		# Flush keyboard buffer
		while read -t 0.01; do :; done
		# https://stackoverflow.com/a/46481173
		read -rsn1 mode
		if [[ $mode == $(printf "\u1b") ]]
		then
			read -rsn2 mode # read 2 more chars
		fi
		printf "\e[K"
		case $mode in
			'[A') # UP
				mValPos=$mValPos-1
				[ "$mValPos" = "-1" ] && mValPos=${mValFilesNb}-1
			;;
			'[B') # DOWN
				mValPos=$mValPos+1
				[ "$mValPos" = "$mValFilesNb" ] && mValPos=0
			;;
			'e' | 'E') # Change value
				valueInput "$1" "$2" "mValNewVal" "false"
				mValHasSelection="false"
				for mValI in "${!mValIsSelected[@]}"
				do
					if [[ "${mValIsSelected[$mValI]}" = "true" ]]
					then
						mValHasSelection="true"
						mValValues[$mValI]="$mValNewVal"
						mValIsSelected[$mValI]="false" # After changing, we unselect since the selection is not needed anymore
					fi
				done
				# If no file have bee selected
				[[ "$mValHasSelection" = "false" ]] && mValValues[$mValPos]="$mValNewVal"
			;;
			'a' | 'A') # Select all
				for mValI in "${!mValIsSelected[@]}"
				do
					mValIsSelected[$mValI]="true"
				done
			;;
			'u' | 'U') # Unselect all
				for mValI in "${!mValIsSelected[@]}"
				do
					mValIsSelected[$mValI]="false"
				done
			;;
			" ") #SPACE
				if [[ "${mValIsSelected[$mValPos]}" = "true" ]]
				then
					mValIsSelected[$mValPos]="false"
				else
					mValIsSelected[$mValPos]="true"
				fi
			;;
			"") # RETURN
				break
			;;
		esac
		# Go up top
		printf "\e[${mValPrintedLines}A\e[0G"
		
	done
	
	# Now, set the variable
	mValFinalValue="*( "
	for mValI in "${!mValFilename[@]}"
	do
		mValFinalValue="$mValFinalValue [\"${mValFilename[mValI]}\"]=\"${mValValues[mValI]}\""
	done
	mValFinalValue="$mValFinalValue )"
	
	eval "$3=\$mValFinalValue"
	
	# Remove all the mess in the console
	nprintf "\e[2K\e[1A" $mValPrintedLines
	# Since a lot of files could be printed, it is preferable to redraw the main interface
	mustRedraw=true
	
	unset mValFinalValue
	unset mValFilename
	unset mValIds
	unset mValPos
	unset mValFilesNb
	unset mValI
	unset mValIsSelected
	unset mValPrintedLines
	unset mValValues
	unset mValNewVal
	unset mValHasSelection
}


# ==============================================
# Loads file information

declare -i fileNb=0

# Loops through each numbered folders
for folder in $(find . -type d -regex \.\\/[0-9]* | sort -n)
do
	trimmedFolder=$(echo $folder | cut -c 3-) # (cut -c 3-) return N instead of ./N
	echo Parsing folder $trimmedFolder:
	folders+=($trimmedFolder)
	
	# Loops trough each file in $folder
	IFS=$nl
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
		
		regexFound=false
		for regex in "${!DEFAULT_FILE_REGEX[@]}"
		do
			if [[ ${file%.*} =~ ${DEFAULT_FILE_REGEX[$regex]} ]]
			then
				
				regex_match="${BASH_REMATCH[${DEFAULT_REGEX_MATCH_NB[$regex]}]}"
				regexFound=true
				break
			fi
		done
		
		if [[ "$regexFound" = "false" ]]
		then
			regex_match="${file%.*}"
		fi
		
		
		
		for i in $(seq 0 $(($fileNb - 1)))
		do
			if [[ "${files[regex $i]}" = "$regex_match" ]]
			then
				found=true
				files["$trimmedFolder $i"]="$file"
				jsons["$trimmedFolder $i"]="$json"
				break
			fi
			[[ "$found" = true ]] && break;
		done
		
		
		# If the file don't exist at all, we add it at a new id
		if [[ "$found" = false ]]
		then
			files["$trimmedFolder $fileNb"]="$file"
			files["regex $fileNb"]="$regex_match"
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
		# Add chapters if they exists
		fileChapters=$(echo ${jsons[$folder $file]} | jq -r '.chapters | map (.num_entries | tostring) | join("\n")')
		if [[ ! "$fileChapters" = "" ]]
		then
			currentTemplate+="${fileID}:C;Ch.;--;;Chapters;${fileChapters} chapter(s);;"
			currentTemplate+=$nl
		fi
		# Same thing with attachments
		fileAttach=$(echo ${jsons[$folder $file]} | jq -r '.attachments | length')
		if [[ ! "$fileAttach" = "0" ]]
		then
			currentTemplate+="${fileID}:A;At.;--;;Attachments;${fileAttach} attachment(s);;"
			currentTemplate+=$nl
		fi
		fileID=$fileID+1
	done
	currentTemplate=${currentTemplate%$nl} # Remove the trailing \n
	
	# Add the current template to the templates list (without duplicates) and add the matching index to $fileTemplateMap
	
	found=false
	#Since the IFS typically contains \n, it messes up when $currentTemplate is added to the array by removing all the \n.
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
	
done

# ==============================================
# Prints the templates and the file names

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
	IFS=$nl
	# We put each line of $template in an array element. We use the IFS as \n to do that
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
		parseLine "${currentTemplate[$pos]}"
		
		
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
				if [[ "$currentType" = "Ch."  || "$currentType" = "At." ]]
				then
					printf "${COLOR_ERROR}Chapters or attachments can't have a default value!${COLOR_RESET}"
				else
					defaultStatus=$(cut -c -1 <<<$currentDefault)
					forcedStatus=$(cut -c 2- <<<$currentDefault)
					if [[ "$defaultStatus" = "D" ]]
					then
						currentDefault="-$forcedStatus"
					else
						currentDefault="D$forcedStatus"
					fi
					mustRegenerateLine=true
				fi
			;;
			'f' | 'F') # Change track forced
				if [[ "$currentType" = "Ch."  || "$currentType" = "At." ]]
				then
					printf "${COLOR_ERROR}Chapters or attachments can't have a forced value!${COLOR_RESET}"
				else
					defaultStatus=$(cut -c -1 <<<$currentDefault)
					forcedStatus=$(cut -c 2- <<<$currentDefault)
					if [[ "$forcedStatus" = "F" ]]
					then
						currentDefault="${defaultStatus}-"
					else
						currentDefault="${defaultStatus}F"
					fi
					mustRegenerateLine=true
				fi
			;;
			'l' | 'L') # Change track language
				if [[ "$currentType" = "At." ]]
				then
					printf "${COLOR_ERROR}Attachments can't have a language!${COLOR_RESET}"
				else
					valueInput "Enter the new track language: " "string" "currentLang" 
					mustRegenerateLine=true
				fi
			;;
			'n' | 'N') # Change track name
				if [[ "$currentType" = "Ch."  || "$currentType" = "At." ]]
				then
					printf "${COLOR_ERROR}Chapters or attachments can't have a name!${COLOR_RESET}"
				else
					valueInput "Enter the new track name: " "string" "currentName" 
					mustRegenerateLine=true
				fi
			;;
			's' | 'S') # Change track shift
				if [[ "$currentType" = "At." ]]
				then
					printf "${COLOR_ERROR}Attachments can't have a shift value!${COLOR_RESET}"
				else
					valueInput "Enter the new track shift: " "integer" "currentShift" 
					mustRegenerateLine=true
				fi
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
			# Go up (header +array + footer size) lines
			printf "\e[${headerSize}A\e[${arraySize}A\e[${footerSize}A\e[0G"
			printHeader
			# Go down (tracks number) lines to print the footer
			nprintf "\n" ${arraySize}
			printFooter
		fi
		
		
	done
	stty echo
	printf "\n"
	IFS=""
	
	# A very hacky way to put back something with \n in an array in a single entry
	templates[$t]="$(printf "%s\n" "${currentTemplate[@]}")"
	
	unset pos
	unset currentTemplate
done

echo "Generating the jsons for mkvmerge"
[[ -d "json" ]] || mkdir "json"


for t in "${!templates[@]}"
do
	IFS=$nl
	currentTemplate=(${templates[$t]})
	trackOrder=""
	for i in "${!currentTemplate[@]}"
	do
		parseLine "${currentTemplate[$i]}"
		# Skip disabled tracks
		[[ "$currentDisabled" = "D" ]] && continue
		# Skip "special tracks" that aren't true tracks like chapters and attachments
		[[ "$currentType" = "Ch." ]] && continue
		[[ "$currentType" = "At." ]] && continue
		if [[ "$trackOrder" = "" ]]
		then
			trackOrder="$currentID"
		else
			trackOrder="${trackOrder},${currentID}"
		fi
	done
	 
	
	IFS=$nl
	for file in $(seq 0 $(($fileNb - 1)))
	do
		# If the file don't belong to this template, we skip it
		[[ "${fileTemplateMap[$file]}" = "$t" ]] || continue
		generateJson $file >"json/${file}.json"
		
	done
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