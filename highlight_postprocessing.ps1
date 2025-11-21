###########################################################################
# Quake3_DemoHelpers - https://github.com/froschgrosch/Quake3_DemoHelpers #
# Licensed under GNU GPLv3. - File: highlight_postprocessing.ps1          #
###########################################################################


function Get-DemoData ($file) {
    $udtoutput = $(.\zz_tools\UDT_json.exe -a=g -c $file | ConvertFrom-Json).gamestates[0]
    
    $player = $players | Where-Object -Property names -CContains $udtoutput.demoTakerCleanName
    if ($null -eq $player) { # player not found, fall back to old behaviour
        $player = $udtoutput.demoTakerCleanName.Replace('LPG ','').Replace(' ','')
    } 
    else {
        $player = $player.names[0]
    }

    $year = $file.NameSubstring(0,4)
    if ($year -clike 'c*') { # demo is a clip demo
        $year = $file.Name.Substring(5,4)
    }

    return @{
        year = $year
        fs_game = $udtoutput.configStringValues.fs_game
        player = $player
    }
}

## PROGRAM START ##
$players = Get-Content .\zz_config\players.json | ConvertFrom-Json
$settings = Get-Content .\zz_config\autoprocessing\settings.json | ConvertFrom-Json

$demos = Get-ChildItem '.\highlight\output_demo\*.dm_68'

# move finished demos
Write-Output 'Moving demos...'

foreach ($demo in $demos) {
    $demoData = Get-DemoData $demo
    Write-Output $demo.name $demoData ''
    
    $outputPath = $settings.outputPath.($demoData.fs_game).demo
    $outputPath = $outputPath -f $demoData.player, $demoData.year
    
    # create output folder if it does not exist
    if (!(Test-Path $outputPath)) {
        $null = New-Item -Path $outputPath -ItemType Directory
    }

    $demo | Copy-Item -Force -Destination $outputPath
}

#$clips = Get-ChildItem ".\highlight\output_clip\*.dm_68"
