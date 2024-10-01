#######################################
#  Check Status of ELO's SFControl
#  by m.wahl@mr-daten.de
#  Version 0.2  2024-08-13
#  Version 0.3  2024-10-01 m.sander@mr-daten.de
#      - added checkPlugin-Output, set exit codes
#######################################
$SFexe = 'D:\DocXtractorII\System\bin\SFControl.exe'
$TaskName = 'DailyTasks'
 
filter Status2Int {
    $_ -replace '^.*:\s' -as [int]
}
 
# Status values and description according to $SFexe help
switch (. $SFexe -Status $TaskName | Status2Int ) {
    -2 {
        <# Client or CoordinatorKernel is started: First OK status #>
        "(OK) Client or CoordinatorKernel is started."
	;exit 0
    }
    -3 {
        <# Client is working: Second OK status #>
	"(OK) Client is working."
        ;exit 0
    }
    Default {
	"(CRITICAL) Client does not work"
	;exit 2
    }
}
