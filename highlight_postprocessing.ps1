function Test-DemoName ($year, $filename) {
    if ($year -ne $settings.year) {
        Write-Output "$filename is not from the correct year ($($settings.year))!" 'Please check your input folders!'
        pause
        exit 1
    }
}

# read settings
$settings = Get-Content .\zz_config\autoprocessing\settings.json | ConvertFrom-Json

# check if all demos and clips are from the correct year, exit otherwise
$outputDemos = Get-ChildItem .\highlight\output_demo\*.dm_68
foreach ($f in $outputDemos){
    Test-DemoName -year $f.Name.Substring(0,4) -filename $f.Name
}

$outputClips = Get-ChildItem .\highlight\output_clip\*.dm_68
foreach ($f in $outputClips){
    Test-DemoName -year $f.Name.Substring(5,4) -filename $f.Name
}

# move finished demos
Write-Output 'Moving demos...'
$outputDemos.Name
$outputDemos | Move-Item -Destination $settings.demoPath

# get latest saved clip number
$lastclip = Get-ChildItem "$($settings.clipPath)\*.dm_68" | Sort-Object -Property Name | Select-Object -Last 1
$lastclip_number = [int]$lastclip.Name.Substring(0,4) + 1

# rename and move clip files
Write-Output ' ' 'Moving clips...'
foreach ($demo in $outputClips) {
    # check file name
    if ($demo.Name -match 'c\d{3}_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}_[\w-]+_\w+_\d+_\d+\w*\.dm_68'){
        Write-Output "New prefix: $lastclip_number - Moving $($demo.Name)..."
        Move-Item -Path $demo.FullName -Destination "$($settings.clipPath)\$('{0:d4}_{1}' -f $lastclip_number, $demo.Name.Substring(5))"
        $lastclip_number++
    }
}
Write-Output ' ' 'Post-processing is finished.'
pause
