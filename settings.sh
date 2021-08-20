# Configuration for the merger script

# The default regex used to parse filenames
# The regex is parsed trough bash built-in regex
# Input files will be matched to the same output file if the matching part of the regex is the same
# The regex will only be processed on the filename (without its extension) and not on the full path of the file
# If no regex matches, the whole filename will be used

# To match 2 numbers, you can use '([0-9][0-9])'
# To match a typical "SXXEXX" style like "S01E02", you can use '([sS][0-9][0-9][eE])([0-9][0-9])'
DEFAULT_FILE_REGEX=('([sS][0-9][0-9][eE])([0-9][0-9])' '([^0-9])([0-9][0-9])([^0-9])' '([0-9][0-9])')

# The matching group to use
# 1 is the first matching group
# And so on...
# If you have multiple regexes, you must provide the MATCH_NB for each regex, in the same order
DEFAULT_REGEX_MATCH_NB=(2 2 1)

# The default output name of the output file (without the extension)
# You can use ${regex_match} to put the matched part of the regex, and ${file_id} to put the file ID
DEFAULT_OUTPUT_NAME='${regex_match}_output'

# Attachments MIME type overrides
# To override a MIME type for a specific file extension, use the key as the extension and the value as the MIME type
# If the extension doesn't have an override, the file command will be used
# IMPORTANT: Extension must be in lowercase. When the files are being tested, all extensions are converted in lowercase
declare -A MIME_OVERRIDES
MIME_OVERRIDES=(["ttf"]="application/x-truetype-font" ["otf"]="application/vnd.ms-opentype")