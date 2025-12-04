###  Veeam added/removed Job Checker  ###
###   (c) MR-Daten - Charly Kupke     ###
###           Version 1.1             ###
### ### ### ### #### #### ### ### ### ###

$ErrorActionPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'

try {
    $veeamjobs = Get-VBRJob | Sort LogNameMainPart
} catch {
    Write-Host "(WARNING) Can't get VBR Jobs"
    ;exit (1)
}

$WorkPath = $env:SystemDrive + "\ProgramData\icinga2\var\temp"
If(!(Test-Path $WorkPath))
{
    ## Create Dir if not exists
    New-Item -ItemType Directory -Force -Path $WorkPath
}
cd $WorkPath
$filePath = "$WorkPath\check_VeeamAddedRemovedJobs.txt"

$currentJobs = @()
Foreach ($veeamjob in $veeamjobs) {
    $veeam_jobname = $veeamjob.LogNameMainPart
    $currentJobs += $veeam_jobname
}
try {
    $previousJobs = Get-Content -Path $filePath -ErrorAction Stop
} catch {
    $previousJobs = "(OK) [ Note: First Runtime of Job ]","(OK) [ Note: Initialize - ignore Warning ]"
}
$differences = Compare-Object $currentJobs $previousJobs
$currentJobs | Out-File -FilePath $filePath

if ($differences -eq $null) {
    $OutputContent = '(OK) Keine neuen / entfernte Jobs gefunden'
    $ExitCode = 0
}
else {
    $newJobsContent = ""
    $oldJobsContent = ""

    Foreach ($difference in $differences) {
        If ($difference.SideIndicator -eq '<=' -And $difference.InputObject -ne '') {
            $newJobsContent += $difference.InputObject + "`n"
        }
        If ($difference.SideIndicator -eq '=>' -And $difference.InputObject -ne '') {
            $oldJobsContent += $difference.InputObject + "`n"
        }
    }
    if ($newJobsContent -ne '') {
        $OutputContent = '(WARNING) Jobs seit letztem Check hinzugefügt:' + "`n"
        $OutputContent += $newJobsContent + "`n"
    }
    if ($oldJobsContent -ne '') {
        $OutputContent += '(WARNING) Jobs seit letztem Check entfernt:' + "`n"
        $OutputContent += $oldJobsContent
    }
    $ExitCode = 1
}

Write-Host $OutputContent
;exit ($ExitCode)
