#!/bin/bash
###########################################################################
# Quake3_DemoHelpers - https://github.com/froschgrosch/Quake3_DemoHelpers #
# Licensed under GNU GPLv3. - File: extract_highlight.sh                  #
###########################################################################

for file in ./highlight/input/*.dm_68; do
    file=$(basename -a $file)

    # get demo data
    udtoutput=$(zz_tools/UDT_json -a=mg -c "./highlight/input/$file")

    player=$(echo "$udtoutput" | jq -r .gameStates[0].demoTakerCleanName)

    # select canonical name
    player=$(jq -r --arg name "$player" '( .[] | select(.names | index($name) != null) | .names[0] )' ./zz_config/players.json)

    # check if player is in the players list, skip otherwise
    if [[ -z ${player} ]]
    then
        echo 'Player not found in config file!'; echo
        continue
    fi

    echo "Selecting $file..."

    # iterate through chat messages
    echo "$udtoutput" | jq -c '.chat.[]' | while read -r message; do

        # check if the message is matching criteria
        if jq -e --argjson msg "$message" --arg demoTaker "$player" 'any(.[]; (.names | index($msg.cleanPlayerName) != null) and (.demoMarkers | index($msg.cleanMessage) != null) and (.names | index($demoTaker) != null))' ./zz_config/players.json > /dev/null;
        then
            #echo $message | jq

            starttime=$(jq --argjson msg "$message" '($msg.serverTime / 1000 - .defaultOffset.start)|floor' ./zz_config/highlights/settings.json)
            endtime=$(jq --argjson msg "$message" '($msg.serverTime / 1000 + .defaultOffset.end)|floor' ./zz_config/highlights/settings.json)

            #echo "ST: $starttime - ET: $endtime"

            zz_tools/UDT_cutter t -q -s="$starttime" -e="$endtime" -o="./highlight/temp" "./highlight/input/$file"

            clipfile=$(basename -a ./highlight/temp/*.dm_68)
            mv ./highlight/temp/$clipfile ./highlight/output_clip/${clipfile/_CUT/}
        fi
    done
    mv ./highlight/input/$file ./highlight/output_demo/
done
