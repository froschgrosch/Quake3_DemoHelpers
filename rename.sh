###########################################################################
# Quake3_DemoHelpers - https://github.com/froschgrosch/Quake3_DemoHelpers #
# Licensed under GNU GPLv3. - File: rename.sh                             #
###########################################################################


file="demo.dm_68"

# get demo data
udtoutput=$(zz_tools/UDT_json -a=g -c "./rename/input/$file")

# put player name into variable
player=$(echo "$udtoutput" | jq -r .gameStates[0].demoTakerCleanName)

# select true name
player=$(cat zz_config/players.json | jq -r --arg name "$player" '( .[] | select(.names | index($name) != null) | .names[0] ) // ($name | sub("^LPG "; ""))')
