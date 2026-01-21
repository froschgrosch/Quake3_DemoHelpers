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
|---highlight_postprocessing.ps1
|
|---quake3e.ded.x64.exe
```

## Configuration

### Global configuration

#### `players.json`

This file contains all players and their respective aliases and chat binds.

The first player name is their "canonical" name. All occurences of the "alias" names (all other ones) will be replaced by this in the processing scripts.

*Example player object:*

```JSON
{ 
    "names": [ "froschgrosch", "LPG froschgrosch", "LPG froschgro" ],
    "demoMarkers": [ "burt, please mArKdEmO", "y" ]
}
```

### `autoprocessing\settings.json`

In this file the final output folder paths for the demo and clip files are defined. It is implied that the demos and clips are stored per year (not per month, week etc.). 

Please note that the program only runs if all input files are from the same year (this limitation might be removed in the future).

### Highlights

#### `highlights\settings.json`

| **Setting**      | **Explanation**                                                                                                                                      |
|------------------|------------------------------------------------------------------------------------------------------------------------------------------------------|
| `defaultOffset`  | This setting defines the default clip offset (the time from when the clip starts/ends until when the clip event actually happens)                  |
| `q3install.*`    | In this setting the quake3 install path, binary name and allowed mods are defined.                                                                 |
| `configSwapping` | This setting decides if config swapping is enabled or not.                                                                                         |
| `pauseAtStart`   | This setting makes the program pause before starting execution. Useful for moving the window to a different screen before starting the extraction. | 

#### Config swapping

An optional feature of `extract_highlight.ps1` is the config file swapping. This feature allows the user to have separate config files for viewing demo of multiple mods. Those config files will be swapped in dynamically while the script runs.

For each mod there should be a q3config file named appropiately, for example `arena.cfg` or `osp.cfg` in the *q3cfg* folder. Only files for mods contained in `q3install.allowedGames` will be considered.

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