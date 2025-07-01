$players = Get-Content .\zz_config\players.json | ConvertFrom-Json
$inputFiles = Get-ChildItem  .\rename\input | Where-Object -Property Extension -EQ '.dm_68'

:renameloop foreach ($file in $inputFiles) {
    Write-Output "Old: $($file.Name.Replace('.dm_68',''))"
    switch -Regex ($file.Name) { # extract timestamp from filename
        '\d{14}-\S+\.\d+-[\w-]+\.dm_68' # quake3e-named
        { 
            $year   = $file.name.Substring(0,4)
            $month  = $file.name.Substring(4,2)
            $day    = $file.name.Substring(6,2)
            $hour   = $file.name.Substring(8,2)
            $minute = $file.name.Substring(10,2)
            $second = $file.name.Substring(12,2)
        }
        
        Default {
            Write-Output 'Filename style not supported!' "Skipping $($file.Name.Replace('.dm_68',''))..." ' '
            continue renameloop
        }
    }
    
    $date = Get-Date -Year $year -Month $month -Day $day -Hour $hour -Minute $minute -Second $second 
        
    $udtoutput = $(.\zz_tools\UDT_json.exe -a=g -c "..\rename\input\$file" | ConvertFrom-Json).gamestates[0]

    #$player = $udtoutput.demoTakerCleanName.Replace('LPG ','')
    $playerFound = $false
    foreach ($p in $players){
        if ($p.names -contains $udtoutput.demoTakerCleanName) {
            #Write-Output "Selecting player $($p.names[0])..."
            $player = $p.names[0]
            $playerFound = $true
        }
    } 

    if (-not $playerFound) {
        Write-Output 'Player not found in config file!' "Skipping $($file.Name.Replace('.dm_68',''))..." ' '
        continue renameloop
    } 

    $map = $udtoutput.configStringValues.mapname

    $newname = "$year-$month-$day`_$hour-$minute-$second`_$map`_$player"

    Write-Output "New: $newname" ' '

    $file = Move-Item -Force $file.FullName ".\rename\output\$newname.dm_68" -PassThru         
    $file.LastWriteTime = $date
}
pause
