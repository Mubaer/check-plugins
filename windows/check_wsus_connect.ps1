########################################################################################################
#  Check if Assets are not contacting or not reporting back to WSUS-Server for a period of time        #
#  Peter Ziegler Managed IT 7.5.2024                                                                   #
########################################################################################################

$version = "2.0.5" # localized for english version of WSUS
$ExitCode = 0
Import-Module poshwsus
$connect = Connect-PSWSUSServer -WsusServer localhost -Port 8530


function Set-ExitCode {
    param ($code)
    if ($ExitCode -lt $code) {
        $ExitCode = $code
    }
    return $ExitCode
}
$errordate = $(Get-Date).AddDays(-10)


$errorsync = $(Get-WsusComputer -ToLastSyncTime $errordate | Where-Object {$_ -notmatch "Es sind keine" -and $_ -notmatch "No computers"} | Measure-Object).count
$errorreport = $(Get-WsusComputer -ToLastReportedStatusTime $errordate | Where-Object {$_ -notmatch "Es sind keine" -and $_ -notmatch "No computers"} | Measure-Object).count

if($errorsync -gt 0 -or $errorreport -gt 0){
$exitcode = Set-ExitCode -code 2     
}


$warndate = $(Get-Date).AddDays(-5)


$warnsync = $(Get-WsusComputer -ToLastSyncTime $warndate | Where-Object {$_ -notmatch "Es sind keine" -and $_ -notmatch "No computers"} | Measure-Object).count - $errorsync
$warnreport = $(Get-WsusComputer -ToLastReportedStatusTime $warndate | Where-Object {$_ -notmatch "Es sind keine" -and $_ -notmatch "No computers"} | Measure-Object).count - $errorreport

if($warnsync -gt 0 -or $warnreport -gt 0 -and $errorsync -eq 0 -and $errorreport -eq 0 ){
$exitcode = Set-ExitCode -code 1     
}





$result =  "WSUS-connect check plugin" + "`r`n"
$result += "Assets with errors:" + "`r"
$result += "(WARNING) Assets last contact > 5 days: " + $warnsync + "`r"
$result += "(CRITICAL) Assets last contact >10 days: " + $errorsync + "`r"
$result += "(WARNING) Assets not reported > 5 days: " + $warnreport + "`r"
$result += "(CRITICAL) Assets not reported >10 days: " + $errorreport + "`r`n"
$result += "WSUS Server Groups:" + "`r"


$groups = $(Get-PSWSUSGroup | where {$_.Name -match "MR_Server"}).name

foreach ($group in $groups){

$result += $group + ":" + "`t" + $(Get-WsusComputer -ComputerTargetGroups $group | Where-Object {$_ -notmatch "Es sind keine" -and $_ -notmatch "No computers"} ).Count + "`r"

}

$result += "`r`n" + "Check version: " + $version    
    
Write-Host $result

$LASTEXITCODE = $exitCode
;exit ($exitCode)
