function Format-ServerTime ($t) { 
    # This function takes the server time returned from UDT_json and formats it as min:sec
    $min = $t / 60000
    
    $sec = [Math]::floor($min * 60 % 60)
    $min = [Math]::floor($min)

    #return ('{0:d2}:{1:d2}' -f $min,$sec)
    return "$min`:$sec"
}

#Read config file
$config = Get-Content .\zz_config\highlights\config.json | ConvertFrom-Json

$inputFiles = Get-ChildItem  .\highlight\input | Where-Object -Property Extension -EQ '.dm_68'

:demoloop foreach ($file in $inputFiles) {
    # check file name
    if ($file.Name -match '\d{4}(?:-\d{2}){2}_\d{2}(?:-\d{2}){2}_\w*_\w*\.dm_68'){ 
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
    else {
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
            $clipfile = Move-Item -Force -PassThru $clipfile.FullName -Destination ".\highlight\output\$($clipfile.Name.Replace('_CUT',''))"
        }
    }
}
pause
