function Invoke-Quake3e ($q3e_args) {
    $q3e_args += '+quit'

    Start-Process -FilePath .\quake3e.ded.x64.exe -Wait -ArgumentList $q3e_args -WindowStyle Minimized
}

$players = Get-Content .\zz_config\players.json | ConvertFrom-Json
$inputFiles = Get-ChildItem -Depth 2 .\serverdemo\input | Where-Object -Property Extension -EQ '.rec'

$starttime = Get-Date
Write-Output 'Starting server-side demo conversion...'

foreach ($f in $inputFiles){
  $name = $f.Name 
  $dirName = $f.Directory.Name

  $newName = "$dirName`_$name"
  Copy-Item -Path $f.FullName -Destination .\records\$newName
}

:demoloop foreach ($file in Get-ChildItem .\records){
    if ($file.Name -match '(?:\d{2}-){3}[\w-]+\.rec'){ # check file name
        $name = $file.Name.Replace('.rec','')
    } 
    else {
        Write-Output "Skipping $($file.Name)..."
        continue demoloop
    }

    # Scan server-side demo file
    Write-Output ' ' "Converting $name..."
    Invoke-Quake3e @('+set logfile 2',"+record_scan $name")
 
    $text = Get-Content .\baseq3\qconsole.log
    :lineloop foreach ($line in $text){
        if ($line -match 'client\(\d+\)\ instance\(\d+\)') { # line found
            $line = $line.Split(' ')
            
            $client   = $line[0].Substring($line[0].IndexOf('(') + 1, $line[0].IndexOf(')') - $line[0].IndexOf('(') - 1)
            $instance = $line[1].Substring($line[1].IndexOf('(') + 1, $line[1].IndexOf(')') - $line[1].IndexOf('(') - 1)

            Invoke-Quake3e @('+set logfile 0','+set sv_recordConvertSimulateFollow 0',"+record_convert $name $client $instance")

            if ($(Get-ItemProperty -Path .\baseq3\demos\output.dm_68 | Select-Object -ExpandProperty Length) -eq 0) { continue :lineloop }

            $udtoutput = $(.\zz_tools\UDT_json.exe -a=g -c ..\baseq3\demos\output.dm_68 | ConvertFrom-Json).gamestates[0]

            $player = $players | Where-Object -Property names -CContains $udtoutput.demoTakerCleanName
            if ($null -eq $player) { # player not found, fall back to old behaviour
                $player = $udtoutput.demoTakerCleanName.Replace('LPG ','').Replace(' ','')
            } 
            else {
                $player = $player.names[0]
            }

            $map = $udtoutput.configStringValues.mapname

            $date = Get-Date -Year $name.Substring(0,4) -Month $name.Substring(5,2) -Day $name.Substring(8,2) -Hour $name.Substring(11,2) -Minute $name.Substring(14,2) -Second $name.Substring(17,2)

            $newname = $name.Substring(0,19)
            $newname = "$newname`_$map`_$player"

            Write-Output "(C$client I$instance) - $newname"

            # create new output folder if necessary
            if (-not $(Test-Path ".\serverdemo\output\$player\")){
                $null = New-Item -Path ".\serverdemo\output\" -Name $player -ItemType "directory"
            }            

            if ($true) #$player -eq 'froschgrosch')
            {
                $file = Move-Item -Force .\baseq3\demos\output.dm_68 ".\serverdemo\output\$player\$newname.dm_68" -PassThru         
                $file.LastWriteTime = $date
            } else {
                Remove-Item .\baseq3\demos\output.dm_68
            }
        }
    }
}

$inputFiles = Get-ChildItem .\records\ | Where-Object -Property Extension -EQ '.rec' 
$demonumber = $inputFiles.Count

$inputFiles | Remove-Item
Remove-Item .\baseq3\qconsole.log


$endtime = Get-Date
$duration_total = ($endtime - $starttime).TotalMinutes
$duration_perDemo = ($endtime - $starttime).TotalSeconds / ($demonumber * 1.0)

Write-Output ' ' 'Server-side demo conversion is completed.' ' '
Write-Output "Number of demos: $demonumber" "Total time elapsed (min): $duration_total" "Average time per demo (sec): $duration_perDemo" ' '
pause
