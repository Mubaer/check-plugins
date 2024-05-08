########################################################################################################
#  Check if Assets are not contacting or not reporting back to WSUS-Server for a period of time        #
#  Peter Ziegler Managed IT 7.5.2024                                                                   #
########################################################################################################


$ExitCode = 0

function Set-ExitCode {
    param ($code)
    if ($ExitCode -lt $code) {
        $ExitCode = $code
    }
    return $ExitCode
}

$warndate = $(Get-Date).AddDays(-50)


$warnsync = $(Get-WsusComputer -ToLastSyncTime $warndate| Where-Object {$_ -notmatch "Es sind keine"} | Measure-Object).count
$warnreport = $(Get-WsusComputer -ToLastReportedStatusTime $warndate| Where-Object {$_ -notmatch "Es sind keine"} | Measure-Object).count

if($warnsync -gt 0 -or $warnreport -gt 0){
$exitcode = Set-ExitCode -code 1     
}

$errordate = $(Get-Date).AddDays(-100)


$errorsync = $(Get-WsusComputer -ToLastSyncTime $errordate| Where-Object {$_ -notmatch "Es sind keine"} | Measure-Object).count - $warnsync
$errorreport = $(Get-WsusComputer -ToLastReportedStatusTime $errordate| Where-Object {$_ -notmatch "Es sind keine"} | Measure-Object).count - $warnreport

if($errorsync -gt 0 -or $errorreport -gt 0){
$exitcode = Set-ExitCode -code 2     
}


$ExitCode

Write-Host "Warning: Assets without contact: $warnsync; Assets not reporting back: $warnreport"
Write-Host ""
Write-Host "Critical: Assets without contact: $errorsync; Assets not reporting back: $errorreport"

$LASTEXITCODE = $exitCode
#;exit ($exitCode)
