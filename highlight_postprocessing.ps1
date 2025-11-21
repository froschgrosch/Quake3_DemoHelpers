###########################################################################
# Quake3_DemoHelpers - https://github.com/froschgrosch/Quake3_DemoHelpers #
# Licensed under GNU GPLv3. - File: highlight_postprocessing.ps1          #
###########################################################################

## FUNCTION DECLARATION ##
function Add-ToObject ($inputObject, $name, $value) {
    Add-Member -Force -InputObject $inputObject -MemberType NoteProperty -Name $name -Value $value
}

function Get-DemoData ($file) {
    $udtoutput = $(.\zz_tools\UDT_json.exe -a=g -c $file | ConvertFrom-Json).gamestates[0]
    
    $player = $players | Where-Object -Property names -CContains $udtoutput.demoTakerCleanName
    if ($null -eq $player) { # player not found, fall back to old behaviour
        $player = $udtoutput.demoTakerCleanName.Replace('LPG ','').Replace(' ','')
    } 
    else {
        $player = $player.names[0]
    }

    $year = $file.Name.Substring(0,4)
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


# generate fresh clip indexes
$clipIndex = New-Object -TypeName PSCustomObject
foreach ($fs_game in $settings.outputPath.PSObject.Properties.Name){
    Add-ToObject $clipIndex $fs_game (-1)
}

# move finished clips
$clipFiles = Get-ChildItem '.\highlight\output_clip\*.dm_68'

foreach ($clip in $clipFiles){
    $clipData = Get-DemoData $clip

    $outputPath = $settings.outputPath.($clipData.fs_game).clip
    $outputPath = $outputPath -f $clipData.player, $clipData.year

    $i = $clipIndex.($clipData.fs_game)
    if ($i -eq -1) {
        if (!(Test-Path $outputPath)) { # create output folder if it does not exist
            $null = New-Item -Path $outputPath -ItemType Directory
            $i = 0
        } 
        else { # output folder does exist, get next clip number
            $lastclip = Get-ChildItem "$outputPath\*.dm_68" | Sort-Object -Property Name | Select-Object -Last 1
            # todo: filter valid files
            
            if ($null -eq $lastclip) { # no files exist, start at 0
                $i = 0
            }
            else { # assign current next number
                $i = [int]$lastclip.Name.Substring(0,4) + 1
            }   
        }
    } 

    # add new prefix
    $newName = '{0:d4}_{1}' -f $i, $clip.Name.Substring(5)
    
    # move to output folder with new name
    $clip | Copy-Item -Force -Destination "$outputPath\$newName"

    # todo: improve logging format, it does not look nice atm
    Write-Output ('Moving {0}... (game: {2} | new index: {1:d4})' -f $clip.Name, $i, $clipData.fs_game)

    $i++
}
