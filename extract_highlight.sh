#!/bin/bash
###########################################################################
# Quake3_DemoHelpers - https://github.com/froschgrosch/Quake3_DemoHelpers #
# Licensed under GNU GPLv3. - File: extract_highlight.sh                  #
###########################################################################

for file in ./highlight/input/*.dm_68; do
    file=$(basename -a $file)

    # todo: check if filename matches regex

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

    # preprocess values
    gamename=$(echo "$udtoutput" | jq -r .gameStates[0].configStringValues.gamename)
    demopath="$(jq -r '.q3install.path' ./zz_config/highlights/settings.json)/$gamename/demos/highlight_preview.dm_68"
    execpath=$(jq -r '.q3install.path + "/" + .q3install.executable' ./zz_config/highlights/settings.json)

    readarray -t messages < <(echo "$udtoutput" | jq -c '.chat.[]')

    # iterate through chat messages
    for message in "${messages[@]}"; do
        # check if the message is matching criteria
        if jq -e --argjson msg "$message" --arg demoTaker "$player" 'any(.[]; (.names | index($msg.cleanPlayerName) != null) and (.demoMarkers | index($msg.cleanMessage) != null) and (.names | index($demoTaker) != null))' ./zz_config/players.json > /dev/null;
        then
            #echo $message | jq

            starttime=$(jq --argjson msg "$message" '($msg.serverTime / 1000 - .defaultOffset.start)|floor' ./zz_config/highlights/settings.json)
            endtime=$(jq --argjson msg "$message" '($msg.serverTime / 1000 + .defaultOffset.end)|floor' ./zz_config/highlights/settings.json)

            #echo "ST: $starttime - ET: $endtime"

            zz_tools/UDT_cutter t -q -s="$starttime" -e="$endtime" -o="./highlight/temp" "./highlight/input/$file"

            clipfile=$(basename -a ./highlight/temp/*.dm_68)

            #echo ./highlight/temp/$clipfile "$demopath"
            cp ./highlight/temp/$clipfile "$demopath"

            # decision loop
            while true; do
                # play demo
                $execpath +set fs_game "$gamename" +set fs_homepath "$(dirname "$execpath")" +set nextdemo 'quit' +demo 'highlight_preview.dm_68' &> /dev/null

                # select action
                echo 'c) Quit'

                select action in 'Keep' 'Delete' 'Watch again'; do
                    #echo "$REPLY $action"

                    case $REPLY in
                        # Quit - clean up and exit
                        [Cc]*)
                            rm $demopath
                            exit 0
                        ;;

                        # Keep - move file to output folder
                        1)
                            newname=${clipfile/_CUT/}

                            suffix='!' # make it invalid so the loop runs at least once
                            until [[ $suffix == *([a-z0-9_]) ]]; do
                                read -p 'Enter new suffix (optional) ? ' 'suffix'
                            done

                            newname=${newname/.dm_68/}
                            newname="$newname${suffix:+_$suffix}.dm_68"

                            #echo $newname
                            mv ./highlight/temp/$clipfile ./highlight/output_clip/$newname

                            break 2 # decision loop
                        ;;

                        # Keep - move file to output folder
                        2)
                            rm ./highlight/temp/$clipfile

                            break 2 # decision loop
                        ;;

                        # Watch again
                        3)
                            # Do nothing - the decision loop will play the demo again
                            break 1 # select statement
                        ;;

                        *)
                        ;;
                    esac
                done # select loop
            done # decision loop
        fi # endif the message is matching criteria

        # clean up remaining preview file
        rm $demopath
    done # message loop

    # move demo to output folder
    mv ./highlight/input/$file ./highlight/output_demo/
done # file loop
echo 'Demo processing is finished.'
