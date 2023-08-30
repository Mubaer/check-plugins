###  Icinga Veeam BackupJob Check   ###
###   (c) MR-Daten - Charly Kupke   ###
###           Version 2.3           ###
### ### ### ### ### ### ### ### ### ###

### Usage ###

# Basic Information (all Jobs with Jobname, Result, State, Schedule Status and Runtime)
# Example: .\check_VeeamBackupJob.ps1

# Basic Information with custom thresholds for runtime (Defaults: OK: < 1440 mins; WARNING: =>1440 mins, < 2880 mins; CRITICAL: => 2880 mins)
# Example: .\check_VeeamBackupJob.ps1 -runtime_WARNING 720 -runtime_CRITICAL 1440

# Basic Information for specific Jobs (multiple possible, seperate with comma)
# Example: .\check_VeeamBackupJob.ps1 -exclusivejob '01-DCs','03-RDS'
# Example: .\check_VeeamBackupJob.ps1 -exclusivejob '02-Fileserver' -runtime_OK 240 -runtime_WARNING 3600

# Basic Information with exceptions (multiple possible, seperate with comma)
# Example: .\check_VeeamBackupJob.ps1 -ignorejob '99-TestJob'
# Example: .\check_VeeamBackupJob.ps1 -ignorejob '99-TestJob','50-Lab'

param([String[]]$exclusivejob, [String[]]$ignorejob, [Switch]$runtime, [Int]$runtime_WARNING = 1440, [Int]$runtime_CRITICAL = 2880)

if ($exclusivejob -and $ignorejob) {
    Write-Host "(UNKNOWN) Don't use -exclusivejob and -ignorejob at the same time"
    ;exit (3)
}

$ExitCode = 0
function Set-ExitCode {
    param ($code)
    if ($ExitCode -lt $code) {
        $ExitCode = $code
    }
    return $ExitCode
}
function LastResultsString {
    param ($result1, $result2, $result3 = 'Optional')
    $results = @($result1, $result2, $result3)
    Foreach ($result in $results) {
        if ($result -eq 'Success') {
            $resultstring += 'Success, '
        }
        elseif ($result -eq 'Warning') {
            $resultstring += 'Warning, '
        }
        elseif ($result -eq 'Failed') {
            $resultstring += 'Failed, '
        }
        elseif ($result -eq 'None') {
            $resultstring += 'N/A, '
        }
    }
    $resultstring = $resultstring.Substring(0,$resultstring.Length-2)
    return $resultstring
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
    ;exit (3)
    }
}

$timeNow = Get-Date
$OutputContent = "`n"
$OutputCount_OK = 0
$OutputCount_WARNING = 0
$OutputCount_CRITICAL = 0
$OutputCount_PENDING = 0
$OutputCount_UNKNOWN = 0
$OutputCount_Jobs = 0

$veeamjobs = Get-VBRJob | Sort LogNameMainPart
$veeamjobshistory = Get-VBRBackupSession | Sort CreationTimeUTC -Descending

Foreach ($veeamjob in $veeamjobs) {
    $veeam_jobid = $veeamjob.Id
    $veeam_jobname = $veeamjob.LogNameMainPart
    $veeam_jobtype = $veeamjob.TypeToString
    $veeam_result = $veeamjob.GetLastResult()
    $veeam_schedule = $veeamjob.IsScheduleEnabled
    $veeam_state = $veeamjob.GetLastState()
    if (($exclusivejob -and $exclusivejob -contains $veeam_jobname) -or ($ignorejob -and $ignorejob -notcontains $veeam_jobname) -or (!$exclusivejob -and !$ignorejob)) {
        $OutputCount_Jobs = $OutputCount_Jobs + 1
        if (!(($veeam_jobtype -eq 'Hyper-V Backup Copy') -or ($veeam_jobtype -eq 'VMware Backup Copy')) -and $veeam_schedule) {
            $veeam_jobhistory = $veeamjobshistory | ?{$_.OrigJobName -eq $veeam_jobname}
            if ($veeam_jobhistory[0].State -eq 'Stopped') {
                $veeam_jobruntime = New-TimeSpan -Start $veeam_jobhistory[0].CreationTime -End $veeam_jobhistory[0].EndTime
                if ($veeam_jobhistory[0].Result -eq 'Success') {
                    $OutputContent += "(OK) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: $veeam_state; Scheduled: $veeam_schedule; Runtime: $($veeam_jobruntime.Days | % tostring 00):$($veeam_jobruntime.Hours | % tostring 00):$($veeam_jobruntime.Minutes | % tostring 00):$($veeam_jobruntime.Seconds | % tostring 00)"
                    $OutputContent += "`n"
                    $OutputCount_OK = $OutputCount_OK + 1
                }
                elseif ($veeam_jobhistory[0].Result -eq 'Warning') {
                    if ($veeam_jobhistory[1].Result -eq 'Success') {
                        $OutputContent += "(OK) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: $veeam_state; Scheduled: $veeam_schedule; Runtime: $($veeam_jobruntime.Days | % tostring 00):$($veeam_jobruntime.Hours | % tostring 00):$($veeam_jobruntime.Minutes | % tostring 00):$($veeam_jobruntime.Seconds | % tostring 00)"
                        $OutputContent += "`n"
                        $OutputCount_OK = $OutputCount_OK + 1
                    }
                    elseif ($veeam_jobhistory[1].Result -eq 'Warning') {
                        if ($veeam_jobhistory[2].Result -eq 'Success') {
                            $OutputContent += "(WARNING) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: $veeam_state; Scheduled: $veeam_schedule; Runtime: $($veeam_jobruntime.Days | % tostring 00):$($veeam_jobruntime.Hours | % tostring 00):$($veeam_jobruntime.Minutes | % tostring 00):$($veeam_jobruntime.Seconds | % tostring 00)"
                            $OutputContent += "`n"
                            $OutputCount_WARNING = $OutputCount_WARNING + 1
                            $ExitCode = Set-ExitCode -code 1
                        }
                        else {
                            $OutputContent += "(CRITICAL) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: $veeam_state; Scheduled: $veeam_schedule; Runtime: $($veeam_jobruntime.Days | % tostring 00):$($veeam_jobruntime.Hours | % tostring 00):$($veeam_jobruntime.Minutes | % tostring 00):$($veeam_jobruntime.Seconds | % tostring 00)"
                            $OutputContent += "`n"
                            $OutputCount_CRITICAL = $OutputCount_CRITICAL + 1
                            $ExitCode = Set-ExitCode -code 2
                        }
                    }
                    else {
                        $OutputContent += "(CRITICAL) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: $veeam_state; Scheduled: $veeam_schedule; Runtime: $($veeam_jobruntime.Days | % tostring 00):$($veeam_jobruntime.Hours | % tostring 00):$($veeam_jobruntime.Minutes | % tostring 00):$($veeam_jobruntime.Seconds | % tostring 00)"
                        $OutputContent += "`n"
                        $OutputCount_CRITICAL = $OutputCount_CRITICAL + 1
                        $ExitCode = Set-ExitCode -code 2
                    }
                }
                else {
                    if ($veeam_jobhistory[1].Result -eq 'OK') {
                        $OutputContent += "(OK) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: $veeam_state; Scheduled: $veeam_schedule; Runtime: $($veeam_jobruntime.Days | % tostring 00):$($veeam_jobruntime.Hours | % tostring 00):$($veeam_jobruntime.Minutes | % tostring 00):$($veeam_jobruntime.Seconds | % tostring 00)"
                        $OutputContent += "`n"
                        $OutputCount_OK = $OutputCount_OK + 1
                    }
                    elseif ($veeam_jobhistory[1].Result -eq 'Warning') {
                        $OutputContent += "(WARNING) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: $veeam_state; Scheduled: $veeam_schedule; Runtime: $($veeam_jobruntime.Days | % tostring 00):$($veeam_jobruntime.Hours | % tostring 00):$($veeam_jobruntime.Minutes | % tostring 00):$($veeam_jobruntime.Seconds | % tostring 00)"
                        $OutputContent += "`n"
                        $OutputCount_WARNING = $OutputCount_WARNING + 1
                        $ExitCode = Set-ExitCode -code 1
                    }
                    else {
                        $OutputContent += "(CRITICAL) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: $veeam_state; Scheduled: $veeam_schedule; Runtime: $($veeam_jobruntime.Days | % tostring 00):$($veeam_jobruntime.Hours | % tostring 00):$($veeam_jobruntime.Minutes | % tostring 00):$($veeam_jobruntime.Seconds | % tostring 00)"
                        $OutputContent += "`n"
                        $OutputCount_CRITICAL = $OutputCount_CRITICAL + 1
                        $ExitCode = Set-ExitCode -code 2
                    }
                }
            }
            else {
                $veeam_jobruntime = New-TimeSpan -Start $veeam_jobhistory[0].CreationTime -End $timeNow
                if (($veeam_jobruntime.TotalMinutes -ge $runtime_WARNING) -and ($veeam_jobruntime.TotalMinutes -lt $runtime_CRITICAL)) {
                    if (($veeam_jobhistory[1].Result -eq 'Failed') -or (($veeam_jobhistory[1].Result -eq 'Warning') -and ($veeam_jobhistory[2].Result -eq 'Failed'))) {
                        $OutputContent += "(CRITICAL) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: $veeam_state; Scheduled: $veeam_schedule; Runtime: $($veeam_jobruntime.Days | % tostring 00):$($veeam_jobruntime.Hours | % tostring 00):$($veeam_jobruntime.Minutes | % tostring 00):$($veeam_jobruntime.Seconds | % tostring 00)"
                        $OutputContent += "`n"
                        $OutputCount_CRITICAL = $OutputCount_CRITICAL + 1
                        $ExitCode = Set-ExitCode -code 2

                    }
                    else {
                        $OutputContent += "(WARNING) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: $veeam_state; Scheduled: $veeam_schedule; Runtime: $($veeam_jobruntime.Days | % tostring 00):$($veeam_jobruntime.Hours | % tostring 00):$($veeam_jobruntime.Minutes | % tostring 00):$($veeam_jobruntime.Seconds | % tostring 00)"
                        $OutputContent += "`n"
                        $OutputCount_WARNING = $OutputCount_WARNING + 1
                        $ExitCode = Set-ExitCode -code 1
                    }
                }
                elseif ($veeam_jobruntime.TotalMinutes -ge $runtime_CRITICAL) {
                    $OutputContent += "(CRITICAL) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: $veeam_state; Scheduled: $veeam_schedule; Runtime: $($veeam_jobruntime.Days | % tostring 00):$($veeam_jobruntime.Hours | % tostring 00):$($veeam_jobruntime.Minutes | % tostring 00):$($veeam_jobruntime.Seconds | % tostring 00)"
                    $OutputContent += "`n"
                    $OutputCount_CRITICAL = $OutputCount_CRITICAL + 1
                    $ExitCode = Set-ExitCode -code 2
                }
                else {
                    if (($veeam_jobhistory[1].Result -eq 'Failed') -or (($veeam_jobhistory[1].Result -eq 'Warning') -and ($veeam_jobhistory[2].Result -eq 'Failed'))) {
                        $OutputContent += "(CRITICAL) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: $veeam_state; Scheduled: $veeam_schedule; Runtime: $($veeam_jobruntime.Days | % tostring 00):$($veeam_jobruntime.Hours | % tostring 00):$($veeam_jobruntime.Minutes | % tostring 00):$($veeam_jobruntime.Seconds | % tostring 00)"
                        $OutputContent += "`n"
                        $OutputCount_CRITICAL = $OutputCount_CRITICAL + 1
                        $ExitCode = Set-ExitCode -code 2
                    }
                    elseif (($veeam_jobhistory[1].Result -eq 'Warning') -and ($veeam_jobhistory[2].Result -eq 'Warning')) {
                        $OutputContent += "(WARNING) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: $veeam_state; Scheduled: $veeam_schedule; Runtime: $($veeam_jobruntime.Days | % tostring 00):$($veeam_jobruntime.Hours | % tostring 00):$($veeam_jobruntime.Minutes | % tostring 00):$($veeam_jobruntime.Seconds | % tostring 00)"
                        $OutputContent += "`n"
                        $OutputCount_WARNING = $OutputCount_WARNING + 1
                        $ExitCode = Set-ExitCode -code 1
                    }
                    else {
                        $OutputContent += "(OK) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: $veeam_state; Scheduled: $veeam_schedule; Runtime: $($veeam_jobruntime.Days | % tostring 00):$($veeam_jobruntime.Hours | % tostring 00):$($veeam_jobruntime.Minutes | % tostring 00):$($veeam_jobruntime.Seconds | % tostring 00)"
                        $OutputContent += "`n"
                        $OutputCount_OK = $OutputCount_OK + 1
                    }
                }
            }
        }
        elseif (!($veeam_schedule)) {
            $OutputContent += "(OK) Job: $veeam_jobname; Scheduled: disabled"
            $OutputContent += "`n"
            $OutputCount_OK = $OutputCount_OK + 1
        }
        else {
            if ($veeam_result -eq 'Success') {
                $OutputContent += "(OK) Job: $veeam_jobname; Last Result: $veeam_result; State: $veeam_state; Scheduled: $veeam_schedule; Runtime: $($veeam_jobruntime.Days | % tostring 00):$($veeam_jobruntime.Hours | % tostring 00):$($veeam_jobruntime.Minutes | % tostring 00):$($veeam_jobruntime.Seconds | % tostring 00)"
                $OutputContent += "`n"
                $OutputCount_OK = $OutputCount_OK + 1
            }
            else {
                $OutputContent += "(WARNING) Job: $veeam_jobname; Last Result: $veeam_result; State: $veeam_state; Scheduled: $veeam_schedule; Runtime: $($veeam_jobruntime.Days | % tostring 00):$($veeam_jobruntime.Hours | % tostring 00):$($veeam_jobruntime.Minutes | % tostring 00):$($veeam_jobruntime.Seconds | % tostring 00)"
                $OutputContent += "`n"
                $OutputCount_WARNING = $OutputCount_WARNING + 1
                $ExitCode = Set-ExitCode -code 1
            }
        }
    }
}

$LicenseStatus = Get-VBRInstalledLicense

if ($LicenseStatus.Status -ne 'Valid') {
    $OutputContent += "`n"
    $OutputContent += "(CRITICAL) Veeam License Status is $($LicenseStatus.Status)"
    $ExitCode = Set-ExitCode -code 2
}
if ($LicenseStatus.Type -eq 'Perpetual'){
    $OutputContent += "`n"
    $OutputContent += "(OK) perpetual Veeam License"
}
else {
    $VeeamLicenseExpiration = New-TimeSpan -Start $timeNow -End $LicenseStatus.ExpirationDate
    if ($VeeamLicenseExpiration.TotalDays -gt 30) {
        $OutputContent += "`n"
        $OutputContent += "(OK) Veeam License expires in $([math]::Floor($VeeamLicenseExpiration.TotalDays)) days"
    }
    elseif (($VeeamLicenseExpiration.TotalDays -le 30) -and ($VeeamLicenseExpiration -gt 14)) {
        $OutputContent += "`n"
        $OutputContent += "(WARNING) Veeam License expires in $([math]::Floor($VeeamLicenseExpiration.TotalDays)) days"
        $ExitCode = Set-ExitCode -code 1    
    }
    else {
        $OutputContent += "`n"
        $OutputContent += "(CRITICAL) Veeam License expires in $([math]::Floor($VeeamLicenseExpiration.TotalDays)) days"
        $ExitCode = Set-ExitCode -code 2
    }
}

Write-Host "(OK): $OutputCount_OK; (WARNING): $OutputCount_WARNING; (CRITICAL): $OutputCount_CRITICAL; (PENDING): $OutputCount_PENDING; Jobs in Check: $OutputCount_Jobs"
Write-Host ""
Write-Host "Running Jobs Runtime Thresholds - WARNING at $runtime_WARNING minutes - CRITICAL at $runtime_CRITICAL minutes"
Write-Host $OutputContent

$LASTEXITCODE = $ExitCode
;exit ($ExitCode)
