function Format-ServerTime ($t) { 
    # This function takes the server time returned from UDT_json and formats it as min:sec
    $min = $t / 60000
    
    $sec = [Math]::floor($min * 60 % 60)
    $min = [Math]::floor($min)

    #return ('{0:d2}:{1:d2}' -f $min,$sec)
    return "$min`:$sec"
}

function Clear-SwappedConfigFiles {
    if ($config.settings.configSwapping){
        foreach ($gamename in $swappedConfigFiles){
            if (Test-Path -PathType Leaf -Path "$($config.settings.q3install.path)\$gamename\q3config.cfg.bak"){
                Remove-Item -Path "$($config.settings.q3install.path)\$gamename\q3config.cfg"
                Rename-Item -Path "$($config.settings.q3install.path)\$gamename\q3config.cfg.bak" -NewName 'q3config.cfg'
            }    
        }
    }
}

# check if output folder is empty - exit otherwise
if (Test-Path -Path .\highlight\output\*.dm_68){
    Write-Output 'Error: Output folder is not empty!'
    Pause
    exit
}

#Read config file
$config = Get-Content .\zz_config\highlights\config.json | ConvertFrom-Json
$inputFiles = Get-ChildItem  .\highlight\input | Where-Object -Property Extension -EQ '.dm_68'

# Install playback config 
$swappedConfigFiles = @()

:demoloop foreach ($file in $inputFiles) {
    # check file name
    if ($file.Name -match '\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}_[\w-]*_\w*.dm_68'){ 
        Write-Output ' ' "Selecting $($file.Name.Replace('.dm_68',''))..."

        # check if player is in the config file
        $udtoutput = $(.\zz_tools\UDT_json.exe -a=mg -c "..\highlight\input\$file" | ConvertFrom-Json)
        
        $playerFound = $false
        foreach ($p in $config.players){
            if ($p.names -contains $udtoutput.gamestates[0].demoTakerCleanName) {
                #Write-Output "Selecting player $($p.names[0])..."
                $player = $p 
                $playerFound = $true
            }
        } 

        if (-not $playerFound) {
            Write-Output 'Player not found in config file!' ' '
            continue demoloop  
        }      
    } 
    else { # file name format is not valid
        Write-Output "Skipping $($file.Name.Replace('.dm_68',''))..."
        continue demoloop
    }

    foreach ($message in $udtoutput.chat) {
        # check if message is from correct player and has the correct content
        if ($player.names -contains $message.cleanPlayerName -and $player.demoMarkers -contains $message.cleanMessage) {
            Write-Output "Clip at Matchtime $(Format-ServerTime($message.serverTime - $udtoutput.gameStates[0].startTime))" 

            # server time needs to be in seconds
            $starttime = [Math]::floor($message.serverTime / 1000 - $config.settings.defaultOffset.start)
            $endtime   = [Math]::floor($message.serverTime / 1000 + $config.settings.defaultOffset.end)

            .\zz_tools\UDT_cutter.exe t -q -s="$starttime" -e="$endtime" -o="..\highlight\temp" ..\highlight\input\$file
            $clipfile = Get-ChildItem .\highlight\temp -Depth 1

            $gamename = $udtoutput.gameStates[0].configStringValues.gamename

            # Swap config file in if necessary
            if ($config.settings.configSwapping -and (Test-Path -PathType Leaf -Path ".\zz_config\highlights\q3cfg\$gamename.cfg")){
                if (-Not (Test-Path -PathType Leaf -Path "$($config.settings.q3install.path)\$gamename\q3config.cfg.bak")){
                    Rename-Item -Path "$($config.settings.q3install.path)\$gamename\q3config.cfg" -NewName 'q3config.cfg.bak'
                    Copy-Item -Path ".\zz_config\highlights\q3cfg\$gamename.cfg" -Destination "$($config.settings.q3install.path)\$gamename\q3config.cfg"
                }
                $swappedConfigFiles += $gamename
            }    
            
            Copy-Item -Force $clipfile.FullName -Destination "$($config.settings.q3install.path)\$gamename\demos\highlight_preview.dm_68"
            
            $q3e_args = @(
                "+set fs_game $gamename",
                '+set nextdemo quit',
                '+demo highlight_preview'
            )

            # Select what to do
            Write-Output '1 - Keep' '2 - Delete' '3 - Watch again' '4 - Adjust start' '5 - Adjust end' 'c - Quit'
            :decisionLoop do {
                Start-Process -FilePath $($config.settings.q3install.path + '\' +  $config.settings.q3install.executable) -WorkingDirectory $config.settings.q3install.path -Wait -ArgumentList $q3e_args
                
                do {
                    $selection = Read-Host -Prompt 'Select action'
                } while ( -not (('1','2','3','4','5','c').Contains($selection)))
            
                switch($selection) {
                    '1' { # Keep - Add suffix and move file to output folder
                        $newName = ".\highlight\output\$($clipfile.Name.Replace('_CUT',''))"

                        # Validate suffix - only lowercase letters, digits and underscores are allowed
                        do {
                            $suffix = Read-Host -Prompt 'Enter new suffix (optional)' 
                        } while (-not ($suffix -match '^[a-z0-9_]+$' -or $suffix -eq ''))
                        
                        if ($suffix.Length -gt 0){
                            $newName = $newName.Replace('.dm_68', "_$suffix.dm_68")
                        }

                        $clipfile = Move-Item -Force -PassThru $clipfile.FullName -Destination $newName
                        break decisionLoop
                    }
                    '2' { # Delete -  Delete the clip file
                        Remove-Item $clipfile.FullName
                        break decisionLoop
                    }
                    '3' { # Watch again
                        <# Do Nothing - decisionLoop will play the demo again #>
                    }
                    '4' { # Adjust start
                        $selection = [int]$(Read-Host -Prompt 'Enter Value (+ = later, - = earlier)') # todo - input sanitization?
                        $starttime += $selection

                        Remove-Item $clipfile.FullName
                        .\zz_tools\UDT_cutter.exe t -q -s="$starttime" -e="$endtime" -o="..\highlight\temp" ..\highlight\input\$file
                        $clipfile = Get-ChildItem .\highlight\temp -Depth 1
                        $gamename = $udtoutput.gameStates[0].configStringValues.gamename
                        Copy-Item -Force $clipfile.FullName -Destination "$($config.settings.q3install.path)\$gamename\demos\highlight_preview.dm_68"
                    }
                    '5' { # Adjust end
                        $selection = [int]$(Read-Host -Prompt 'Enter Value (+ = later, - = earlier)') # todo - input sanitization?
                        $endtime += $selection
                        
                        Remove-Item $clipfile.FullName
                        .\zz_tools\UDT_cutter.exe t -q -s="$starttime" -e="$endtime" -o="..\highlight\temp" ..\highlight\input\$file
                        $clipfile = Get-ChildItem .\highlight\temp -Depth 1
                        $gamename = $udtoutput.gameStates[0].configStringValues.gamename
                        Copy-Item -Force $clipfile.FullName -Destination "$($config.settings.q3install.path)\$gamename\demos\highlight_preview.dm_68"
                    }
                    'c' { # Quit - clean up and exit

                        # Delete clip in temp folder
                        Remove-Item $clipfile.FullName 
                        Remove-Item "$($config.settings.q3install.path)\$gamename\demos\highlight_preview.dm_68"

                        Clear-SwappedConfigFiles
                        
                        exit 
                    }
                }
            } while ($true)
            Remove-Item "$($config.settings.q3install.path)\$gamename\demos\highlight_preview.dm_68"
        }
    }
} 

# put back old config
Clear-SwappedConfigFiles

# add temp prefixes to demo files
$outputDemos = Get-ChildItem .\highlight\output | Where-Object -Property Extension -EQ '.dm_68'
$index = 1
foreach ($demo in $outputDemos) {
    # check file name
    if ($demo.Name -match '\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}_[\w-]*_\w*_\d+_\d+\w*\.dm_68'){ # quite horrendous :/
        Rename-Item -Path $demo.FullName -NewName $('c{0:d3}_{1}' -f $index, $demo.Name)
        $index++
    }
}
Write-Output 'Demo processing is finished.'
pause
