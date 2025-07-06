# This script won't handle mixed years in the input files - so be careful!

# read settings
$settings = Get-Content .\zz_config\autoprocessing\settings.json | ConvertFrom-Json

# move finished demos
$outputDemos = Get-ChildItem .\highlight\output_demo\*.dm_68
$outputDemos.Name
$outputDemos | Move-Item -Destination $settings.demoPath

# get latest saved clip number
$lastclip = Get-ChildItem "$($settings.clipPath)\*.dm_68" | Sort-Object -Property Name | Select-Object -Last 1
$lastclip_number = [int]$lastclip.Name.Substring(0,4) + 1

# rename and move clip files
$outputClips = Get-ChildItem .\highlight\output_clip | Where-Object -Property Extension -EQ '.dm_68'
foreach ($demo in $outputClips) {
    # check file name
    if ($demo.Name -match 'c\d{3}_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}_[\w-]+_\w+_\d+_\d+\w*\.dm_68'){
        Write-Output "New prefix: $lastclip_number - Moving $($demo.Name)..."
        Move-Item -Path $demo.FullName -Destination "$($settings.clipPath)\$('{0:d4}_{1}' -f $lastclip_number, $demo.Name.Substring(5))"
        $lastclip_number++
    }
}
pause
