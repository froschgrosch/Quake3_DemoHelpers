#!/bin/bash
###########################################################################
# Quake3_DemoHelpers - https://github.com/froschgrosch/Quake3_DemoHelpers #
# Licensed under GNU GPLv3. - File: rename.sh                             #
###########################################################################

for file in ./rename/input/*.dm_68; do
    file=$(basename -a $file)
    echo Old: ${file/.dm_68/}

    # get demo data
    udtoutput=$(zz_tools/UDT_json -a=g -c "./rename/input/$file")

    player=$(echo "$udtoutput" | jq -r .gameStates[0].demoTakerCleanName)

    # select canonical name
    player=$(jq -r --arg name "$player" '( .[] | select(.names | index($name) != null) | .names[0] ) // ($name | sub("^LPG "; ""))' ./zz_config/players.json)

    map=$(echo "$udtoutput" | jq -r .gameStates[0].configStringValues.mapname)

    newname=$(echo ${file:0:4}-${file:4:2}-${file:6:2}_${file:8:2}-${file:10:2}-${file:12:2}_$map\_$player)

    echo New: $newname ; echo

    mv ./rename/input/$file ./rename/output/$newname.dm_68
    touch -d "$(date -Rd "${file:0:4}-${file:4:2}-${file:6:2} ${file:8:2}:${file:10:2}:${file:12:2}")" ./rename/output/$newname.dm_68
done
