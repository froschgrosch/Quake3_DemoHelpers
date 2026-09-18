#!/usr/bin/env bash
###########################################################################
# Quake3_DemoHelpers - https://github.com/froschgrosch/Quake3_DemoHelpers #
# Licensed under GNU GPLv3. - File: rename.sh                             #
###########################################################################

## INITIALIZATION ##

# check if all external dependencies are available
jq --version 1> /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo 'Error: jq is not available! Please refer to README.md'
    exit 1
fi

if [ ! -x ./zz_tools/UDT_json ]; then
    echo 'Error: UDT_json is not available at the expected path! Please refer to README.md'
    exit 1
fi

# check if there are files in the input folder
ls ./rename/input/*.dm_68 1> /dev/null 2>&1
if [ $? -eq 2 ]
then
    echo 'Error: No valid files in input folder!'
    exit 1
fi

regex_q3e='^[[:digit:]]{14}-[[:graph:]]+\.[[:digit:]]+-[[:alnum:]_-]+\.dm_68$'

## PROGRAM START ##

for file in ./rename/input/*.dm_68; do
    file=$(basename -a $file)
    echo Old: ${file/.dm_68/}

    if [[ $file =~ $regex_q3e ]]
    then
        y=${file:0:4}
        mn=${file:4:2}
        d=${file:6:2}
        h=${file:8:2}
        m=${file:10:2}
        s=${file:12:2}
    else
        echo 'Filename style not supported, skipping file!'
        echo
        continue
    fi

    # get demo data
    udtoutput=$(zz_tools/UDT_json -a=g -c "./rename/input/$file")
    if [[ $? -ne 0 ]]
    then
        echo "Return code of UDT_json is $?! Demo will be skipped."; echo

        mv "./rename/input/$file" ./rename/output/
        continue
    fi

    # unfortunately, UDT_json does not exit with error code 1 when the demo is invalid.
    # this statement checks if there is exactly one gamestate, and if there are players and configstrings in the demo
    if [[ $(echo $udtoutput | jq '(.gameStates[].players | length == 0) or (.gameStates | length != 1) or (.gameStates[].configStringValues | length == 0)') == true ]]
    then
        echo 'Something is wrong with this demo file (Not exactly one gamestate, or no players or configStrings).'
        echo; echo "UDT_json output of $file:"

        echo "$udtoutput" | jq .
        echo 'Moving to output folder.'; echo

        mv "./rename/input/$file" ./rename/output/
        continue
    fi

    # get player
    player=$(echo "$udtoutput" | jq -r .gameStates[0].demoTakerCleanName)

    # select canonical name
    player=$(jq -r --arg name "$player" '( .[] | select(.names | index($name) != null) | .names[0] ) // ($name | sub("^LPG "; ""))' ./zz_config/players.json)

    map=$(echo "$udtoutput" | jq -r .gameStates[0].configStringValues.mapname)

    newname="$y-$mn-$d""_$h-$m-$s""_$map""_$player"

    echo "New: $newname"; echo

    mv ./rename/input/$file ./rename/output/$newname.dm_68
    touch -d "$(date -Rd "$y-$mn-$d $h:$m:$s")" ./rename/output/$newname.dm_68
done

echo 'Demo renaming is finished.'
