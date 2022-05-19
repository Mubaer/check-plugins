###  Icinga Veeam BackupJob Check   ###
###   (c) MR-Daten - Charly Kupke   ###
###           Version 1.0           ###
### ### ### ### ### ### ### ### ### ###

### Usage ###

# Basic Information (all Jobs with Jobname, Result, State and Schedule Status)
# Example: .\check_VeeamBackupJob.ps1

# Extended Information (Basic + Runtime)
# Example: .\check_VeeamBackupJob.ps1 -runtime

# Extended Information (Basic + Runtime) with custom treshholds for runtime (Defaults: OK: <= 120 mins; WARNING: >120 mins, <= 600 mins; CRITICAL: > 600 mins)
# Example: .\check_VeeamBackupJob.ps1 -runtime -runtime_OK 180 -runtime_WARNING 3600

# Basic/Extended Information for specific Jobs (multiple possible, seperate with comma)
# Example: .\check_VeeamBackupJob.ps1 -exclusivejob '01-DCs','03-RDS'
# Example: .\check_VeeamBackupJob.ps1 -exclusivejob '02-Fileserver' -runtime -runtime_OK 240 -runtime_WARNING 3600

# Basic/Extended Information with exceptions (multiple possible, seperate with comma)
# Example: .\check_VeeamBackupJob.ps1 -ignorejob '99-TestJob'
# Example: .\check_VeeamBackupJob.ps1 -ignorejob '99-TestJob','50-Lab' -runtime




param([String[]]$exclusivejob, [String[]]$ignorejob, [Switch]$runtime, [Int]$runtime_OK = 120, [Int]$runtime_WARNING = 600)

if ($exclusivejob -and $ignorejob) {
    Write-Host "(UNKNOWN) Don't use -exclusivejob and -ignorejob at the same time"
    $host.SetShouldExit(3)
    exit 3
}



$ExitCode = 0
function Set-ExitCode {
    param ($code)
    if ($ExitCode -lt $code) {
        Set-Variable -Name ExitCode -Value $code -Scope global
    }
}

#=== Add a temporary value from User to session ($Env:PSModulePath) ======
#https://docs.microsoft.com/powershell/scripting/developer/module/modifying-the-psmodulepath-installation-path?view=powershell-7
$path = [Environment]::GetEnvironmentVariable('PSModulePath', 'Machine')
$env:PSModulePath +="$([System.IO.Path]::PathSeparator)$path"
$MyModulePath = "C:\Program Files\Veeam\Backup and Replication\Console\"
$env:PSModulePath = $env:PSModulePath + "$([System.IO.Path]::PathSeparator)$MyModulePath"
#=========================================================================
try {
    $veeamPSModule = Get-Module -ListAvailable | ?{$_.Name -match "Veeam.Backup.Powershell"}
    Import-Module $veeamPSModule.Path -DisableNameChecking
} catch {
    #Write-Host "Import Module failed, trying hardlink"
    try {
        import-module "C:\Program Files\Veeam\Backup and Replication\Console\Veeam.Backup.PowerShell.dll"
    }catch{
    Write-Host "(UNKNOWN) Failed to import Veeam PS Module"
    $host.SetShouldExit(3)
    exit 3
    }
}
$runtime = $true
$OutputContent = "`n"
$OutputCount_OK = 0
$OutputCount_WARNING = 0
$OutputCount_CRITICAL = 0
$OutputCount_PENDING = 0
$OutputCount_UNKNOWN = 0
$OutputCount_Jobs = 0

$veeamjobs = Get-VBRJob
Foreach ($veeamjob in $veeamjobs) {
    $veeam_jobid = $veeamjob.Id
    $veeam_jobname = $veeamjob.LogNameMainPart
    $veeam_result = $veeamjob.GetLastResult()
    $veeam_schedule = $veeamjob.IsScheduleEnabled
    $veeam_state = $veeamjob.GetLastState()
    if (($exclusivejob -and $exclusivejob -contains $veeam_jobname) -or ($ignorejob -and $ignorejob -notcontains $veeam_jobname) -or (!$exclusivejob -and !$ignorejob)) {
        $OutputCount_Jobs = $OutputCount_Jobs + 1
        $veeam_backupsessions = Get-VBRBackupSession | Where {$_.JobId -eq $veeam_jobid} | Sort EndTimeUTC -Descending | Select -First 5
        if ($veeam_result -eq 'Failed') {
            $OutputContent += "(CRITICAL) Job: $veeam_jobname; Result: $veeam_result; State: $veeam_state; Scheduled: $veeam_schedule"
            $OutputContent += "`n"
            $OutputCount_CRITICAL = $OutputCount_CRITICAL + 1
            Set-ExitCode -code 2
            if($runtime) {
                $veeam_jobruntime = New-TimeSpan -Start $veeam_backupsessions[0].CreationTime -End $veeam_backupsessions[0].EndTime
                if ($veeam_jobruntime.TotalMinutes -le $runtime_OK) {
                    $OutputContent += "(OK) Job ($veeam_jobname) last Runtime (D:H:M:S): $($veeam_jobruntime.Days):$($veeam_jobruntime.Hours):$($veeam_jobruntime.Minutes):$($veeam_jobruntime.Seconds)"
                    $OutputContent += "`n"
                    $OutputCount_OK = $OutputCount_OK + 1
                }
                elseif (($veeam_jobruntime.TotalMinutes -gt $runtime_OK) -and ($veeam_jobruntime.TotalMinutes -le $runtime_WARNING)) {
                    $OutputContent += "(WARNING) Job ($veeam_jobname) last Runtime (D:H:M:S): $($veeam_jobruntime.Days):$($veeam_jobruntime.Hours):$($veeam_jobruntime.Minutes):$($veeam_jobruntime.Seconds)"
                    $OutputContent += "`n"
                    $OutputCount_WARNING = $OutputCount_WARNING + 1
                    Set-ExitCode -code 1
                }
                else {
                    $OutputContent += "(CRITICAL) Job ($veeam_jobname) last Runtime (D:H:M:S): $($veeam_jobruntime.Days):$($veeam_jobruntime.Hours):$($veeam_jobruntime.Minutes):$($veeam_jobruntime.Seconds)"
                    $OutputContent += "`n"
                    $OutputCount_CRITICAL = $OutputCount_CRITICAL + 1
                    Set-ExitCode -code 2
                }
            }
        }
        elseif ($veeam_result -eq 'Warning' -or $veeam_schedule -ne 'True') {
            $OutputContent += "(WARNING) Job: $veeam_jobname; Result: $veeam_result; State: $veeam_state; Scheduled: $veeam_schedule"
            $OutputContent += "`n"
            $OutputCount_WARNING = $OutputCount_WARNING + 1
            Set-ExitCode -code 1
            if($runtime) {
                $veeam_jobruntime = New-TimeSpan -Start $veeam_backupsessions[0].CreationTime -End $veeam_backupsessions[0].EndTime
                if ($veeam_jobruntime.TotalMinutes -le $runtime_OK) {
                    $OutputContent += "(OK) Job ($veeam_jobname) last Runtime (D:H:M:S): $($veeam_jobruntime.Days):$($veeam_jobruntime.Hours):$($veeam_jobruntime.Minutes):$($veeam_jobruntime.Seconds)"
                    $OutputContent += "`n"
                    $OutputCount_OK = $OutputCount_OK + 1
                }
                elseif (($veeam_jobruntime.TotalMinutes -gt $runtime_OK) -and ($veeam_jobruntime.TotalMinutes -le $runtime_WARNING)) {
                    $OutputContent += "(WARNING) Job ($veeam_jobname) last Runtime (D:H:M:S): $($veeam_jobruntime.Days):$($veeam_jobruntime.Hours):$($veeam_jobruntime.Minutes):$($veeam_jobruntime.Seconds)"
                    $OutputContent += "`n"
                    $OutputCount_WARNING = $OutputCount_WARNING + 1
                    Set-ExitCode -code 1
                }
                else {
                    $OutputContent += "(CRITICAL) Job ($veeam_jobname) last Runtime (D:H:M:S): $($veeam_jobruntime.Days):$($veeam_jobruntime.Hours):$($veeam_jobruntime.Minutes):$($veeam_jobruntime.Seconds)"
                    $OutputContent += "`n"
                    $OutputCount_CRITICAL = $OutputCount_CRITICAL + 1
                    Set-ExitCode -code 2
                }
            }
        }
        elseif ($veeam_result -eq 'None' -and $veeam_state -eq 'Working') {
            $OutputContent += "(PENDING) Job: $veeam_jobname; Result: $veeam_result; State: $veeam_state; Scheduled: $veeam_schedule"
            $OutputContent += "`n"
            $OutputCount_PENDING = $OutputCount_PENDING + 1
            if($runtime) {
                $OutputContent += "(PENDING) Job ($veeam_jobname) is currently running"
                $OutputContent += "`n"
                $OutputCount_PENDING = $OutputCount_PENDING + 1
            }
        }
        else {
            $OutputContent += "(OK) Job: $veeam_jobname; Result: $veeam_result; State: $veeam_state; Scheduled: $veeam_schedule"
            $OutputContent += "`n"
            $OutputCount_OK = $OutputCount_OK + 1
            if($runtime) {
                $veeam_jobruntime = New-TimeSpan -Start $veeam_backupsessions[0].CreationTime -End $veeam_backupsessions[0].EndTime
                if ($veeam_jobruntime.TotalMinutes -le $runtime_OK) {
                    $OutputContent += "(OK) Job ($veeam_jobname) last Runtime (D:H:M:S): $($veeam_jobruntime.Days):$($veeam_jobruntime.Hours):$($veeam_jobruntime.Minutes):$($veeam_jobruntime.Seconds)"
                    $OutputContent += "`n"
                    $OutputCount_OK = $OutputCount_OK + 1
                }
                elseif (($veeam_jobruntime.TotalMinutes -gt $runtime_OK) -and ($veeam_jobruntime.TotalMinutes -le $runtime_WARNING)) {
                    $OutputContent += "(WARNING) Job ($veeam_jobname) last Runtime (D:H:M:S): $($veeam_jobruntime.Days):$($veeam_jobruntime.Hours):$($veeam_jobruntime.Minutes):$($veeam_jobruntime.Seconds)"
                    $OutputContent += "`n"
                    $OutputCount_WARNING = $OutputCount_WARNING + 1
                    Set-ExitCode -code 1
                }
                else {
                    $OutputContent += "(CRITICAL) Job ($veeam_jobname) last Runtime (D:H:M:S): $($veeam_jobruntime.Days):$($veeam_jobruntime.Hours):$($veeam_jobruntime.Minutes):$($veeam_jobruntime.Seconds)"
                    $OutputContent += "`n"
                    $OutputCount_CRITICAL = $OutputCount_CRITICAL + 1
                    Set-ExitCode -code 2
                }
            }
        }
    }
}
Write-Host "(OK): $OutputCount_OK; (WARNING): $OutputCount_WARNING; (CRITICAL): $OutputCount_CRITICAL; (PENDING): $OutputCount_PENDING; Jobs in Check: $OutputCount_Jobs"
Write-Host $OutputContent

$host.SetShouldExit($ExitCode)
exit $ExitCode 

