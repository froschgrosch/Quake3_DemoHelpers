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
$settings = Get-Content .\zz_config\postprocessing\settings.json | ConvertFrom-Json

$games = $settings.outputPath.PSObject.Properties.Name

$demos = Get-ChildItem '.\highlight\output_demo\*.dm_68'

# move finished demos
Write-Output 'Moving demos...'

:demoLoop foreach ($demo in $demos) {
    $demoData = Get-DemoData $demo
    Write-Output $demo.name
    
    # check if fs_game is valid
    if ($games -NotContains $demoData.fs_game){
        Write-Output ('Warning: "{0}" is not a valid game! Moving to .\postprocessing\demo_invalid...' -f $demoData.fs_game)
        
        # create invalid folder if it does not exist
        if (!(Test-Path .\postprocessing\demo_invalid)) {
            $null = New-Item -Path .\postprocessing\demo_invalid -ItemType Directory
        }

        $demo | Move-Item -Destination .\postprocessing\demo_invalid
        continue :demoLoop
    }

    $outputPath = $settings.outputPath.($demoData.fs_game).demo
    $outputPath = $outputPath -f $demoData.player, $demoData.year
    
    # create output folder if it does not exist
    if (!(Test-Path $outputPath)) {
        $null = New-Item -Path $outputPath -ItemType Directory
    }

    $demo | Move-Item -Destination $outputPath
}


# generate fresh clip indexes
$maxfsGameLength = 0
$clipIndex = New-Object -TypeName PSCustomObject
foreach ($fs_game in $games){
    Add-ToObject $clipIndex $fs_game (-1)
    $maxfsGameLength = ($maxfsGameLength, $fs_game.Length | Measure-Object -Maximum).Maximum
}

$clipFiles = Get-ChildItem '.\highlight\output_clip\*.dm_68'

# move finished clips
Write-Output ' ' 'Moving clips...'

:clipLoop foreach ($clip in $clipFiles){
    $clipData = Get-DemoData $clip

    # check if fs_game is valid
    if ($games -NotContains $clipData.fs_game){
        Write-Output ('Warning: "{0}" is not a valid game! Moving to .\postprocessing\clip_invalid...' -f $clipData.fs_game)
        
        # create invalid folder if it does not exist
        if (!(Test-Path .\postprocessing\clip_invalid)) {
            $null = New-Item -Path .\postprocessing\clip_invalid -ItemType Directory
        }
        
        $clip | Move-Item -Destination .\postprocessing\clip_invalid
        continue :clipLoop
    }

    $outputPath = $settings.outputPath.($clipData.fs_game).clip
    $outputPath = $outputPath -f $clipData.player, $clipData.year

    if ($clipIndex.($clipData.fs_game) -eq -1) {
        if (!(Test-Path $outputPath)) { # create output folder if it does not exist
            $null = New-Item -Path $outputPath -ItemType Directory
            $clipIndex.($clipData.fs_game) = 0
        } 
        else { # output folder does exist, get next clip number
            $lastclip = Get-ChildItem "$outputPath\*.dm_68" | Sort-Object -Property Name | Select-Object -Last 1
            # todo: filter valid files
            
            if ($null -eq $lastclip) { # no files exist, start at 0
                $clipIndex.($clipData.fs_game) = 0
            }
            else { # assign current next number
                $clipIndex.($clipData.fs_game) = [int]$lastclip.Name.Substring(0,4) + 1
            }   
        }
    } 

    # add new prefix
    $newName = '{0:d4}_{1}' -f  $clipIndex.($clipData.fs_game), $clip.Name.Substring(5)
    
    # move to output folder with new name
    $clip | Move-Item -Destination "$outputPath\$newName"

    Write-Output ("(game: {2,$maxfsGameLength} - new index: {1:d4}) - Moving {0}..." -f $clip.Name, $clipIndex.($clipData.fs_game), $clipData.fs_game)

    $clipIndex.($clipData.fs_game)++
}
Write-Output ' ' 'Post-processing is finished.'
pause
