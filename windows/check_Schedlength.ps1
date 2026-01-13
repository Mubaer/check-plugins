$version = "0.9.0"

$SchTL = "(OK): Task Scheduler Queue empty"
$exitcode = 0

if ($($(Get-ScheduledTask | where {$_.State -like "Queued"}) | Measure-Object).Count -ne "0"){

$SchTL = "(WARNING): Task Scheduler Queue NOT empty"
$exitcode = 1

}

Write-Host $SchTL
Write-Host "Check version: " $version
$host.SetShouldExit($exitcode)
exit