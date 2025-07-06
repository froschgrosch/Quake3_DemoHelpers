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

function Get-ClipFile ($s, $e, $f, $g){
    .\zz_tools\UDT_cutter.exe t -q -s="$s" -e="$e" -o="..\highlight\temp" ..\highlight\input\$f
    $cf = Get-ChildItem .\highlight\temp -Depth 1
    Copy-Item -Force $cf.FullName -Destination "$($config.settings.q3install.path)\$g\demos\highlight_preview.dm_68"

    return $cf
}

function Get-UserInput{
    Param (
        [Parameter(Mandatory=$true)] [String]$prompt, # Prompt to be displayed
        [Parameter(Mandatory=$true)] [String]$rgx,    # Regex that needs to be matched
        [Parameter(Mandatory=$false)] $allowEmpty = $false
    )

    do {
        $userinput = Read-Host -Prompt $prompt
    } while (-not ($userinput -match $rgx -or ($userinput -eq '' -and $allowEmpty)))
    
    return $userinput
}

# check if output folder is empty - exit otherwise
if (Test-Path -Path .\highlight\output_clip\*.dm_68){
    Write-Output 'Error: Output folder is not empty!'
    Pause
    exit
}

# Read config files
$config = New-Object -TypeName PSObject
Add-Member -InputObject $config -MemberType NoteProperty -Name 'players' -Value (Get-Content .\zz_config\players.json | ConvertFrom-Json)
Add-Member -InputObject $config -MemberType NoteProperty -Name 'settings' -Value (Get-Content .\zz_config\highlights\settings.json | ConvertFrom-Json)

# Get demos
$inputFiles = Get-ChildItem  .\highlight\input | Where-Object -Property Extension -EQ '.dm_68'

# Install playback config 
$swappedConfigFiles = @()

:demoloop foreach ($file in $inputFiles) {
    # check file name
    if ($file.Name -match '\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}_[\w-]+_\w+.dm_68'){ 
        Write-Output ' ' "Selecting $($file.Name.Replace('.dm_68',''))..."

        $udtoutput = $(.\zz_tools\UDT_json.exe -a=mg -c "..\highlight\input\$file" | ConvertFrom-Json)
        
        # check if player is in the config file
        $player = $config.players | Where-Object -Property names -CContains $udtoutput.gamestates[0].demoTakerCleanName
        if ($null -eq $player) {
            Write-Output 'Player not found in config file!' ' '
            continue demoloop  
        }
    } 
    else { # file name format is not valid
        Write-Output "Skipping $($file.Name.Replace('.dm_68',''))..."
        continue demoloop
    }

    $gamename = $udtoutput.gameStates[0].configStringValues.gamename

    # Swap config file in if necessary
    if ($config.settings.configSwapping -and (Test-Path -PathType Leaf -Path ".\zz_config\highlights\q3cfg\$gamename.cfg")){
        if (-Not (Test-Path -PathType Leaf -Path "$($config.settings.q3install.path)\$gamename\q3config.cfg.bak")){
            Rename-Item -Path "$($config.settings.q3install.path)\$gamename\q3config.cfg" -NewName 'q3config.cfg.bak'
            Copy-Item -Path ".\zz_config\highlights\q3cfg\$gamename.cfg" -Destination "$($config.settings.q3install.path)\$gamename\q3config.cfg"
        }
        $swappedConfigFiles += $gamename
    }

    # Set Quake3e arguments
    $q3e_args = @(
        "+set fs_game $gamename",
        '+set nextdemo quit',
        '+demo highlight_preview'
    )

    foreach ($message in $udtoutput.chat) {
        # check if message is from correct player and has the correct content
        if ($player.names -contains $message.cleanPlayerName -and $player.demoMarkers -contains $message.cleanMessage) {
            Write-Output "Clip at Matchtime $(Format-ServerTime($message.serverTime - $udtoutput.gameStates[0].startTime))" 

            # server time needs to be in seconds
            $starttime = [Math]::floor($message.serverTime / 1000 - $config.settings.defaultOffset.start)
            $endtime   = [Math]::floor($message.serverTime / 1000 + $config.settings.defaultOffset.end)

            $clipfile = Get-ClipFile $starttime $endtime $file $gamename

            # Select what to do
            Write-Output '1 - Keep' '2 - Delete' '3 - Watch again' '4 - Adjust start' '5 - Adjust end' 'c - Quit'
            :decisionLoop do {
                Start-Process -FilePath $($config.settings.q3install.path + '\' +  $config.settings.q3install.executable) -WorkingDirectory $config.settings.q3install.path -Wait -ArgumentList $q3e_args
                
                $selection = Get-UserInput 'Select action' '^[1-5|c]$'
                switch($selection) {
                    '1' { # Keep - Add suffix and move file to output folder
                        $newName = ".\highlight\output_clip\$($clipfile.Name.Replace('_CUT',''))"

                        # Validate suffix - only lowercase letters, digits and underscores are allowed
                        $suffix = Get-UserInput 'Enter new suffix (optional)' '^[a-z0-9_]+$' -allowEmpty $true
                        
                        if ($suffix.Length -gt 0){
                            $newName = $newName.Replace('.dm_68', "_$suffix.dm_68")
                        }

                        Move-Item -Force $clipfile.FullName -Destination $newName
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
                        $selection = [int]$(Get-UserInput 'Enter Value (+ = later, - = earlier)' '^(-|\+)?\d+$') # allow +, - or no prefix
                        $starttime += $selection

                        Remove-Item $clipfile.FullName
                        $clipfile = Get-ClipFile $starttime $endtime $file $gamename
                    }
                    '5' { # Adjust end
                        $selection = [int]$(Get-UserInput 'Enter Value (+ = later, - = earlier)' '^(-|\+)?\d+$') # allow +, - or no prefix
                        $endtime += $selection
                        
                        Remove-Item $clipfile.FullName
                        $clipfile = Get-ClipFile $starttime $endtime $file $gamename
                    }
                    'c' { # Quit - clean up and exit

                        # Delete clip in temp folder
                        Remove-Item $clipfile.FullName 
                        Remove-Item "$($config.settings.q3install.path)\$gamename\demos\highlight_preview.dm_68"

                        Clear-SwappedConfigFiles
                        
                        exit 
                    }
                }
            } while ($true) # :decisionLoop
            Remove-Item "$($config.settings.q3install.path)\$gamename\demos\highlight_preview.dm_68"
        }
    } # messageLoop

    # move demo file when finished
    Move-Item $file.FullName -Destination ".\highlight\output_demo\$($file.Name)"
} # demoLoop 

# put back old config
Clear-SwappedConfigFiles

# add temp prefixes to demo files
$outputDemos = Get-ChildItem .\highlight\output_clip | Where-Object -Property Extension -EQ '.dm_68'
$index = 1
foreach ($demo in $outputDemos) {
    # check file name
    if ($demo.Name -match '\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}_[\w-]+_\w+_\d+_\d+\w*\.dm_68'){ # quite horrendous :/
        Rename-Item -Path $demo.FullName -NewName $('c{0:d3}_{1}' -f $index, $demo.Name)
        $index++
    }
}
Write-Output 'Demo processing is finished.'
pause
