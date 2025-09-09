# Quake3_DemoHelpers

A collection of tools to make the task of sorting demos and highlight clips easier. 

The `extract_serverdemo.ps1` script uses a very slightly modified version of Chomenor's [server side recording implementation](https://github.com/Chomenor/Quake3e/tree/server_side_recording) which ignores missing pak0-pak8 files. However, the programs are independent of each other so it is not mandatory to install that binary if you do not intend to use that particular tool.

It IS however required to install UDT_cutter and UDT_json to ensure functionality of all scripts. The aforementioned tools can be obtained at [myT's page](https://myt.playmorepromode.com/udt/redirections/), check *windows_console_x64* or *windows_console_x86*.

## File and folder structure

*"default.cfg" in baseq3 is to be extracted from pak0.pk3.*

```text
|---baseq3/
|   |
|   |---default.cfg
|   |---q3config_server.cfg (will be auto-generated)
|
|---highlight/
|   |
|   |---temp/
|   |---input/
|   |---output_clip/
|   |---output_demo/
|
|
|---rename/
|   |
|   |---input/
|   |---output/
|   
|---serverdemo/
|   |
|   |---input/
|   |    |
|   |    |---yyyy-mm-dd/
|   |        |
|   |        |---hh-mm-ss-map.rec
|   |            ...
|   |
|   |---output/
|
|---zz_config/
|   |
|   |---highlights/
|   |   |
|   |   |---q3cfg/
|   |   |   |
|   |   |   |---arena.cfg
|   |   |       ...
|   |   |
|   |   |---settings.json
|   |
|   |---players.json
|
|---zz_tools/
|   |
|   |---UDT_cutter.exe
|   |---UDT_json.exe
|
|---extract_highlight.ps1
|---extract_serverdemo.ps1
|---rename.ps1
|
|---quake3e.ded.x64.exe
```

## Recommended binds for viewing demos

```text
bind 1 "toggle timescale 1 0"
bind 2 "toggle timescale 2 0"
bind 3 "toggle timescale 5 0"
bind 4 "toggle timescale 10 0"
bind 5 "toggle timescale .5 0"
bind 6 "toggle timescale .25 0"
bind 7 "toggle timescale .1 0"
bind 8 "timescale 0; echo Playback paused."
bind b "timescale 1; demo highlight_preview; echo Playback restarted."
bind c "quit"
bind v "toggle s_volume 0 0.1"
bind s "toggle r_fastsky"
```