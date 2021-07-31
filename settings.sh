# Configuration for the merger script

# The default regex used to parse filenames
# The regex is parsed trough bash built-in regex
# Input files will be matched to the same output file if the matching part of the regex is the same
# The regex will only be processed on the filename (without its extension) and not on the full path of the file
# IMPORTANT: Your regex MUST match something

# To match 2 numbers, you can use '([0-9][0-9])'
DEFAULT_FILE_REGEX='([0-9][0-9])'

# The matching group to use
# 1 is the first matching group
# And so on...
DEFAULT_REGEX_MATCH_NB=1

# The default output name of the output file (without the extension)
# You can use ${regex_match} to put the matched part of the regex, and ${file_id} to put the file ID
DEFAULT_OUTPUT_NAME='${regex_match}_output'