#!/usr/bin/env bash
###########################################################################
# Quake3_DemoHelpers - https://github.com/froschgrosch/Quake3_DemoHelpers #
# Licensed under GNU GPLv3. - File: extract_highlight.sh                  #
###########################################################################

## function declaration ##

function clear_config_files() {
    if [[ $(jq '.configSwapping' ./zz_config/highlights/settings.json) != true ]] then
        return
    fi

    for game in "${allowedGames[@]}"; do
        # check if swap marker is present
        if [ -f "./zz_config/highlights/q3cfg/$game.swapped" ]
        then

            # check if the .bak file actually exists
            if [ -f "$q3path/$game/q3config.cfg.bak" ]
            then
                rm "$q3path/$game/q3config.cfg"
                mv "$q3path/$game/q3config.cfg.bak" "$q3path/$game/q3config.cfg" # is there a better way for renaming a file in place?!
            fi

            # remove swap marker
            rm "./zz_config/highlights/q3cfg/$game.swapped"
        fi
    done

    # would probably be good to handle the case when there is no swap marker present, but the config file has been swapped nonetheless
    return
}

function get_clip_file () {
    zz_tools/UDT_cutter t -q -s="$starttime" -e="$endtime" -o="./highlight/temp" "./highlight/input/$file"
    clipfile=$(basename -a ./highlight/temp/*.dm_68)

    if [ -f "$demopath" ]
    then
        rm "$demopath"
    fi

    cp ./highlight/temp/$clipfile "$demopath"
}

## initialization ##

# enable globbing (needed later)
shopt -s extglob

# check if input and output folders are empty
ls ./highlight/input/*.dm_68 1> /dev/null 2>&1
if [ $? -eq 2 ]
then
    echo 'Error: No files in input folder!'
    exit 1
fi

ls ./highlight/output_clip/*.dm_68 1> /dev/null 2>&1
if [ $? -eq 0 ]
then
    echo 'There are files in the output folder! Do you want to continue?'

    select action in 'Continue' 'Quit'; do
        case $REPLY in
            1)
                break
            ;;

            2)
                exit 0
            ;;
        esac
    done
fi

# check if there are any allowed mods
if [[ $(jq -c '.q3install.allowedGames | length' ./zz_config/highlights/settings.json) -eq '0' ]]
then
    echo 'Error: No valid mods specified in the config file'; echo 'Please specify at least one valid mod in the config file.'
    exit 1
else
    readarray -t allowedGames < <(jq -rc '.q3install.allowedGames.[]' ./zz_config/highlights/settings.json)
fi

# read install path and executable name
q3exec=$(jq -r '.q3install.executable' ./zz_config/highlights/settings.json)
q3path=$(jq -r '.q3install.path' ./zz_config/highlights/settings.json)

# check if q3 binary is present and is executable
if [ ! -x "$q3path/$q3exec" ]
then
    echo 'Error: The Quake 3 binary is not present and executable at the specified path!'
    exit 1
fi

# check if the mods are installed properly
for game in "${allowedGames[@]}";
do
    if [ ! -d "$q3path/$game" ]
    then
        echo "Error: Mod ""$game"" is specified in the config file, but not present in the Quake 3 installation!"; echo 'Please install the mod or remove it from the config file.'
        exit 1
    else
        # create "demos" folder in mod directory if it does not exist
        if [ ! -d "$q3path/$game/demos" ]
        then
            mkdir "$q3path/$game/demos"
        fi
    fi

    if [[ $(jq '.configSwapping' ./zz_config/highlights/settings.json) == true ]] then
        # check if swappable config file actually exists
        if [ ! -e "./zz_config/highlights/q3cfg/$game.cfg" ]
        then
            echo "Error: There is no swappable config file present for the mod ""$game""!"; echo 'Please add a swappable config file or disable config swapping.'
            exit 1
        fi
    fi
done

##  program start ##

# pause before starting execution (if desired)
if [[ $(jq '.pauseAtStart' ./zz_config/highlights/settings.json) == true ]] then
    echo 'Press enter to start.'
    read > /dev/null
fi

# main demo loop
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

    # skip the demo if there are no chat messages present
    if [[ $(echo "$udtoutput" | jq -c '.chat | length') -eq '0' ]]
    then
        #echo 'Demo contains no chat messages!'; echo

        mv ./highlight/input/$file ./highlight/output_demo/
        continue
    fi

    readarray -t messages < <(echo "$udtoutput" | jq -c '.chat.[]')

    # preprocess values
    gamename=$(echo "$udtoutput" | jq -r .gameStates[0].configStringValues.gamename)
    demopath="$q3path/$gamename/demos/highlight_preview.dm_68"

    # swap config file if needed
    if [[ $(jq '.configSwapping' ./zz_config/highlights/settings.json) == true ]]
    then
        if [ ! -f "./zz_config/highlights/q3cfg/$gamename.swapped" ]
        then
            if [ ! -f "$q3path/$gamename/q3config.cfg.bak" ]
            then
                mv "$q3path/$gamename/q3config.cfg" "$q3path/$gamename/q3config.cfg.bak"
                cp "./zz_config/highlights/q3cfg/$gamename.cfg" "$q3path/$gamename/q3config.cfg"
            fi
            touch "./zz_config/highlights/q3cfg/$gamename.swapped"
        fi
    fi

    # iterate through chat messages
    for message in "${messages[@]}"; do
        # check if the message is matching criteria
        if jq -e --argjson msg "$message" --arg demoTaker "$player" 'any(.[]; (.names | index($msg.cleanPlayerName) != null) and (.demoMarkers | index($msg.cleanMessage) != null) and (.names | index($demoTaker) != null))' ./zz_config/players.json > /dev/null;
        then
            #echo $message | jq

            starttime=$(jq --argjson msg "$message" '($msg.serverTime / 1000 - .defaultOffset.start) | floor' ./zz_config/highlights/settings.json)
            endtime=$(jq --argjson msg "$message" '($msg.serverTime / 1000 + .defaultOffset.end) | floor' ./zz_config/highlights/settings.json)

            #echo "ST: $starttime - ET: $endtime"
            get_clip_file

            # decision loop
            while true; do
                # play demo
                "$q3path/$q3exec" +set fs_game "$gamename" +set fs_homepath "$q3path" +set nextdemo 'quit' +demo 'highlight_preview.dm_68' &> /dev/null

                # select action
                echo 'c) Quit'

                select action in 'Keep' 'Delete' 'Watch again' 'Adjust start' 'Adjust end'; do
                    #echo "$REPLY $action"

                    case $REPLY in
                        # Quit - clean up and exit
                        [Cc]*)
                            rm ./highlight/temp/$clipfile $demopath
                            clear_config_files
                            exit 0
                        ;;

                        # Keep - move file to output folder
                        1)
                            newname=${clipfile/_CUT/}

                            suffix='!' # make it invalid so the loop runs at least once
                            until [[ $suffix == *([a-z0-9_]) ]]; do
                                read -p 'Enter new suffix (optional) ? ' 'suffix'
                            done

                            newname="${newname/.dm_68/}${suffix:+_$suffix}.dm_68"

                            #echo $newname
                            mv ./highlight/temp/$clipfile ./highlight/output_clip/$newname

                            break 2 # decision loop
                        ;;

                        # Delete - remove file from temp folder and move on
                        2)
                            rm ./highlight/temp/$clipfile

                            break 2 # decision loop
                        ;;

                        # Watch again
                        3)
                            # Do nothing - the decision loop will play the demo again
                            break 1 # select statement
                        ;;

                        # Adjust start time
                        4)
                            number='a' # make it invalid so the loop runs at least once
                            until [[ $number == ?(-|+)+([0-9]) ]]; do
                                read -p 'Enter Value (+ = later, - = earlier) ? ' 'number'
                            done

                            starttime=$(($starttime + $number))

                            rm $demopath ./highlight/temp/$clipfile
                            get_clip_file

                            # the decision loop will play the new demo
                            break 1 # select statement
                        ;;

                        5)
                            number='a' # make it invalid so the loop runs at least once
                            until [[ $number == ?(-|+)+([0-9]) ]]; do
                                read -p 'Enter Value (+ = later, - = earlier) ? ' 'number'
                            done

                            endtime=$(($endtime + $number))

                            rm $demopath ./highlight/temp/$clipfile
                            get_clip_file

                            # the decision loop will play the new demo
                            break 1 # select statement
                        ;;
                    esac
                done # select loop
            done # decision loop

            # clean up remaining preview file
            rm $demopath
        fi # endif the message is matching criteria
    done # message loop

    # move demo to output folder
    mv ./highlight/input/$file ./highlight/output_demo/
done # file loop

clear_config_files
echo 'Demo processing is finished.'
