$SFexe = 'D:\DocXtractorII\System\bin\SFControl.exe'
$TaskName = 'DailyTasks'
 
filter Status2Int {
    $_ -replace '^.*:\s' -as [int]
}
 
# Status values and description according to $SFexe help
switch (. $SFexe -Status $TaskName | Status2Int ) {
    -2 {
        <# Client or CoordinatorKernel is started: First OK status #>
        0
    }
    -3 {
        <# Client is working: Second OK status #>
        0
    }
    Default { 2 }
}
