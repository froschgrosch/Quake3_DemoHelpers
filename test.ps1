# add temp prefixes to demo files
$outputDemos = Get-ChildItem .\highlight\output | Where-Object -Property Extension -EQ '.dm_68'
$index = 1
foreach ($demo in $outputDemos) {
    # check file name
    if ($demo.Name -match '\d{4}(?:-\d{2}){2}_\d{2}(?:-\d{2}){2}_\w*_\w*(?:_\d+){2}.dm_68'){ # quite horrendous :/
        Rename-Item -Path $demo.FullName -NewName $('c{0:d3}_{1}' -f $index, $demo.Name)
        $index++
    }
}