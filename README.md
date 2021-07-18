# MKVMergeBatch
## Merge a bunch of MKVs in one go

This script is a CLI-like MKVToolNix. However, MKVToolNix can only output one file. If, like me, you want to work on a whole series with multiple episodes, doing each episode one by one is tiedious. This script solves that

## WARNING

This tool is a personnal project that *should* work, at least it works on my machine™. It may mess your shell, and the code is ugly. **USE IT AT YOU OWN RISK**
I'll try to enhance the code in the following days tho.

## How to use

In the same folder as the script, put you files in numbered folders like this:
```
merge.sh
1
|-> file1.mkv
\-> file2.mkv
2
\-> file1.mka
3
|-> file1.ass
\-> file2.srt
```
For the same output file, the input files must have the same name as shown above (as least for now)
When you're done, simply run the script in its folder. It will parse all the files, then display the CLI-like MKVToolNix. The keybinds are shown at the bottom. The layout you set in the script will be applied to all the files having the same layout at the beginning
The column labelled "T" shows the type of the track (A for Audio, V for video, S for subtitles)
The column labelled "D" shows if the track is set to default (D) and/or is forced (F)
**The track name shouldn't contain ";" or "\\" as it will break the interface**

## Todo

- [ ] Clean the code
- [ ] Make sure that all variables are unset properly
- [ ] Be able to add fonts that aren't in any of the input files (with the `--attach-file` parameter) by puting them in a "font" folder
- [ ] Manage chapters and tags that are already in the input files
- [ ] Ba able to add external chapters as .xml by putting them in a "chapters" folder
- [ ] Same thing with tags (?)
- [ ] Be able to use different names for input files, and still recognize them (for example "Episode 1.mkv" and "[Series name]_EP1.mkv" should be treated as the same file)
- [ ] Add support for advanced properties like "commentary track" and so on
- [ ] Proper documentation

## Advanced features todo

- [ ] Be able to set up diffrent shift times for each file while keeping the same layout for the rest
- [ ] Automatically sync up a subtitles track to a reference subtitles track
- [ ] Automatically detect which fonts are needed for each output file and attach only them. We could also add a giant folder storage provided by the user in which the script can pick the missing fonts. We could aulso detect missing font and warn the user about that