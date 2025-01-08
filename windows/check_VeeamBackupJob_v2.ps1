###  Icinga Veeam BackupJob Check   ###
###   (c) MR-Daten - Charly Kupke   ###
###           Version 2.4           ###
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

$ErrorActionPreference = "SilentlyContinue"
$WarningPreference = "SilentlyContinue"

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
        if ($result -eq '0') {
            $resultstring += 'Success, '
        }
        elseif ($result -eq '1') {
            $resultstring += 'Warning, '
        }
        elseif ($result -eq '2') {
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

Import-Module SQLPS

$timeNow = Get-Date
$OutputContent = "`n"
$OutputCount_OK = 0
$OutputCount_WARNING = 0
$OutputCount_CRITICAL = 0
$OutputCount_PENDING = 0
$OutputCount_UNKNOWN = 0
$OutputCount_Jobs = 0

$veeamjobs = Get-VBRJob | select name | Sort LogNameMainPart
$sqlServerName = $env:COMPUTERNAME
$sqlInstanceName = "VeeamSQL2016"
$sqlDatabaseName = "VeeamBackup"

# Check Database type
$sql_result = Invoke-SqlCmd -Query "SELECT GETDATE() AS TimeOfQuery" -ServerInstance "$sqlServerName\$sqlInstanceName" -Database $sqlDatabaseName -Username "Veeam" -Password "pass4MRstaging"

Set-Location 'C:\Program Files\PostgreSQL\15\bin\';
$env:PGPASSWORD = 'cv1C6cjoM32y4m67paW';
$cmd = "\l"
$psql_result = @(.\psql  -U postgres -w -d VeeamBackup -c "$cmd")

if($sql_result){
$activeConfig = "MSSQL"
}elseif($psql_result){
$activeConfig = "PSQL"
}else{

Write-host "Keine Datenbank-Anmeldung möglich"

}


# Find S3 Offload Jobs
# Achtung: falls keine Jobs exisieren wird ein leerer Eintrag erzeugt, der nur stört. Vorher prüfen!
if ($activeConfig -eq "MSSQL") {
$s3repos = "SELECT name, type FROM [VeeamBackup].[dbo].[BackupRepositories] where type like '10';"
$resultRepos = @(Invoke-SqlCmd -Query $s3repos -ServerInstance "$sqlServerName\$sqlInstanceName" -Database $sqlDatabaseName -Username "Veeam" -Password "pass4MRstaging")
$repo_name = $resultRepos[0].name
$sqlS3Job = "SELECT TOP (1) job_name, job_type FROM [VeeamBackup].[dbo].[Backup.Model.JobSessions] where (job_name like '$repo_name%' and job_type like '18000') order by creation_time desc"
$veeam_S3Jobresult = @(Invoke-SqlCmd -Query $sqlS3Job -ServerInstance "$sqlServerName\$sqlInstanceName" -Database $sqlDatabaseName -Username "Veeam" -Password "pass4MRstaging")
$veeamjobs = $veeamjobs + $veeam_S3Jobresult.job_name
}elseif($activeConfig -eq "PSQL"){
# hier muss noch PSQL eingefügt werden
Set-Location 'C:\Program Files\PostgreSQL\15\bin\';
$env:PGPASSWORD = 'cv1C6cjoM32y4m67paW';
$s3repos = "SELECT name, type FROM public.\""backuprepositories\"" where type = '10';"
$resultRepos = @(.\psql  -U postgres -w -d VeeamBackup -c "$s3repos")
$repo_name = ($resultRepos[2]  -split "\|",2)[0]
$sqlS3Job = "SELECT job_name, job_type FROM  public.\""backup.model.jobsessions\"" where (job_name like '$repo_name%' and job_type like '18000') order by creation_time desc limit 1"
$veeam_S3Jobresult = @(.\psql  -U postgres -w -d VeeamBackup -c "$sqls3job")
$veeamjobs = $veeamjobs + $veeam_S3Jobresult.job_name #stimmt evt. noch nicht
}else{
Write-Host "Keine Verbindung zur DB"
}

# Find Tape-Jobs

# Find Agent-Jobs


# Check each Job

Foreach ($veeamjob in $veeamjobs) {
    if($veeamjob.name -like ""){
    $veeam_jobname = $veeamjob}
    else{
    $veeam_jobname = $veeamjob.name}
    if (($exclusivejob -and $exclusivejob -contains $veeam_jobname) -or ($ignorejob -and $ignorejob -notcontains $veeam_jobname) -or (!$exclusivejob -and !$ignorejob)) {
        $OutputCount_Jobs = $OutputCount_Jobs + 1
        
        if  ($activeConfig -eq "MSSQL") {
            $sqlQueryResults = "SELECT TOP (3) job_name, job_type, job_id, creation_time, end_time, result, state FROM [VeeamBackup].[dbo].[Backup.Model.JobSessions] where (job_name like '$veeam_jobname') order by creation_time desc"
            $veeam_jobhistory = @(Invoke-SqlCmd -Query $sqlQueryResults -ServerInstance "$sqlServerName\$sqlInstanceName" -Database $sqlDatabaseName -Username "Veeam" -Password "pass4MRstaging")
            $sqlQueryResults = "SELECT schedule_enabled  FROM [VeeamBackup].[dbo].[BJobs] where (name like '$veeam_jobname')"
            $veeam_jobenabled = Invoke-SqlCmd -Query $sqlQueryResults -ServerInstance "$sqlServerName\$sqlInstanceName" -Database $sqlDatabaseName -Username "Veeam" -Password "pass4MRstaging"
            }elseif($activeConfig -eq "PSQL"){
            $veeam_jobhistory =
            @([pscustomobject]@{job_name="";creation_time="";end_time="";result="";state=""},
              [pscustomobject]@{job_name="";creation_time="";end_time="";result="";state=""},
              [pscustomobject]@{job_name="";creation_time="";end_time="";result="";state=""})

            Set-Location 'C:\Program Files\PostgreSQL\15\bin\';
            $env:PGPASSWORD = 'cv1C6cjoM32y4m67paW';
            $cmd = "SELECT job_name, job_type, state, creation_time, end_time, result FROM public.\""backup.model.jobsessions\"" where (job_name like '$veeam_jobname') ORDER BY creation_time DESC LIMIT 3;"

            $result = @(.\psql  -U postgres -w -d VeeamBackup -c "$cmd")
            
            $veeam_jobhistory[0].job_name = ($result[2] -split "\|",6)[0]
            $veeam_jobhistory[0].creation_time = [datetime]::ParseExact($((($result[2] -split "\| ",6)[3]) -split "\.",2)[0],'yyyy-MM-dd HH:mm:ss',$null)
            $veeam_jobhistory[0].end_time = [datetime]::ParseExact($((($result[2] -split "\| ",6)[4]) -split "\.",2)[0],'yyyy-MM-dd HH:mm:ss',$null)
            $veeam_jobhistory[0].Result = [int]($result[2] -split "\|",6)[5]
            $veeam_jobhistory[0].state = [int]($result[2] -split "\|",6)[2]

            $veeam_jobhistory[1].job_name = ($result[3] -split "\|",6)[0]
            $veeam_jobhistory[1].creation_time = [datetime]::ParseExact($((($result[3] -split "\| ",6)[3]) -split "\.",2)[0],'yyyy-MM-dd HH:mm:ss',$null)
            $veeam_jobhistory[1].end_time = [datetime]::ParseExact($((($result[3] -split "\| ",6)[4]) -split "\.",2)[0],'yyyy-MM-dd HH:mm:ss',$null)
            $veeam_jobhistory[1].Result = [int]($result[3] -split "\|",6)[5]
            $veeam_jobhistory[1].state = [int]($result[2] -split "\|",6)[2]
            
            $veeam_jobhistory[2].job_name = ($result[4] -split "\|",6)[0]
            $veeam_jobhistory[2].creation_time = [datetime]::ParseExact($((($result[4] -split "\| ",6)[3]) -split "\.",2)[0],'yyyy-MM-dd HH:mm:ss',$null)
            $veeam_jobhistory[2].end_time = [datetime]::ParseExact($((($result[4] -split "\| ",6)[4]) -split "\.",2)[0],'yyyy-MM-dd HH:mm:ss',$null)
            $veeam_jobhistory[2].Result = [int]($result[4] -split "\|",6)[5]
            $veeam_jobhistory[2].state = [int]($result[2] -split "\|",6)[2]


            $sqlQueryResults = "SELECT name, schedule_enabled FROM public.\""bjobs\"" where (name like '$veeam_jobname');"
            $result = @(.\psql  -U postgres -w -d VeeamBackup -c "$sqlQueryResults")
            $veeam_jobenabled = ($result[2] -split "\|",2 )[1]

            }else{
            Write-Host "Keine Verbindung zur DB"
            }

            switch ($veeam_jobhistory[0].state){
            -1 {$veeam_state = "Stopped"}
            5  {$veeam_state = "Waiting/Running"}
            default {$veeam_state = "unknown"}
            }

            if ($veeam_jobenabled.schedule_enabled -like "True" -or $veeam_jobenabled -like " t" -or $veeam_jobhistory[0].job_type -eq "18000" -or $veeam_jobhistory[0].job_type -eq "18004") { # job_type 18000/18004 are S3-Offload-Jobs
            if ($veeam_jobhistory[0].end_time -notlike '*1900*') {
                $veeam_jobruntime = New-TimeSpan -Start $veeam_jobhistory[0].Creation_Time -End $veeam_jobhistory[0].End_Time
                if ($veeam_jobhistory[0].Result -eq '0') {
                    $OutputContent += "(OK) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: $veeam_state; Scheduled: enabled ; Runtime: $($veeam_jobruntime.Days | % tostring 00):$($veeam_jobruntime.Hours | % tostring 00):$($veeam_jobruntime.Minutes | % tostring 00):$($veeam_jobruntime.Seconds | % tostring 00)"
                    $OutputContent += "`n"
                    $OutputCount_OK = $OutputCount_OK + 1
                }
                elseif ($veeam_jobhistory[0].Result -eq '1') {
                    if ($veeam_jobhistory[1].Result -eq '0') {
                        $OutputContent += "(OK) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: $veeam_state; Scheduled: enabled; Runtime: $($veeam_jobruntime.Days | % tostring 00):$($veeam_jobruntime.Hours | % tostring 00):$($veeam_jobruntime.Minutes | % tostring 00):$($veeam_jobruntime.Seconds | % tostring 00)"
                        $OutputContent += "`n"
                        $OutputCount_OK = $OutputCount_OK + 1
                    }
                    elseif ($veeam_jobhistory[1].Result -eq '1') {
                        if ($veeam_jobhistory[2].Result -eq '0') {
                            $OutputContent += "(WARNING) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: $veeam_state; Scheduled: enabled; Runtime: $($veeam_jobruntime.Days | % tostring 00):$($veeam_jobruntime.Hours | % tostring 00):$($veeam_jobruntime.Minutes | % tostring 00):$($veeam_jobruntime.Seconds | % tostring 00)"
                            $OutputContent += "`n"
                            $OutputCount_WARNING = $OutputCount_WARNING + 1
                            $ExitCode = Set-ExitCode -code 1
                        }
                        else {
                            $OutputContent += "(CRITICAL) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: $veeam_state; Scheduled: enabled; Runtime: $($veeam_jobruntime.Days | % tostring 00):$($veeam_jobruntime.Hours | % tostring 00):$($veeam_jobruntime.Minutes | % tostring 00):$($veeam_jobruntime.Seconds | % tostring 00)"
                            $OutputContent += "`n"
                            $OutputCount_CRITICAL = $OutputCount_CRITICAL + 1
                            $ExitCode = Set-ExitCode -code 2
                        }
                    }
                    else {
                        $OutputContent += "(CRITICAL) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: $veeam_state; Scheduled: enabled; Runtime: $($veeam_jobruntime.Days | % tostring 00):$($veeam_jobruntime.Hours | % tostring 00):$($veeam_jobruntime.Minutes | % tostring 00):$($veeam_jobruntime.Seconds | % tostring 00)"
                        $OutputContent += "`n"
                        $OutputCount_CRITICAL = $OutputCount_CRITICAL + 1
                        $ExitCode = Set-ExitCode -code 2
                    }
                }
                else {
                    if ($veeam_jobhistory[1].Result -eq '0') {
                        $OutputContent += "(OK) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: $veeam_state; Scheduled: enabled; Runtime: $($veeam_jobruntime.Days | % tostring 00):$($veeam_jobruntime.Hours | % tostring 00):$($veeam_jobruntime.Minutes | % tostring 00):$($veeam_jobruntime.Seconds | % tostring 00)"
                        $OutputContent += "`n"
                        $OutputCount_OK = $OutputCount_OK + 1
                    }
                    elseif ($veeam_jobhistory[1].Result -eq '1') {
                        $OutputContent += "(WARNING) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: $veeam_state; Scheduled: enabled; Runtime: $($veeam_jobruntime.Days | % tostring 00):$($veeam_jobruntime.Hours | % tostring 00):$($veeam_jobruntime.Minutes | % tostring 00):$($veeam_jobruntime.Seconds | % tostring 00)"
                        $OutputContent += "`n"
                        $OutputCount_WARNING = $OutputCount_WARNING + 1
                        $ExitCode = Set-ExitCode -code 1
                    }
                    else {
                        $OutputContent += "(CRITICAL) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: $veeam_state; Scheduled: enabled; Runtime: $($veeam_jobruntime.Days | % tostring 00):$($veeam_jobruntime.Hours | % tostring 00):$($veeam_jobruntime.Minutes | % tostring 00):$($veeam_jobruntime.Seconds | % tostring 00)"
                        $OutputContent += "`n"
                        $OutputCount_CRITICAL = $OutputCount_CRITICAL + 1
                        $ExitCode = Set-ExitCode -code 2
                    }
                }
            }
            else {
                $veeam_jobruntime = New-TimeSpan -Start $veeam_jobhistory[0].creation_time -End $timeNow
                if (($veeam_jobruntime.TotalMinutes -ge $runtime_WARNING) -and ($veeam_jobruntime.TotalMinutes -lt $runtime_CRITICAL)) {
                    if (($veeam_jobhistory[1].Result -eq '2') -or (($veeam_jobhistory[1].Result -eq '1') -and ($veeam_jobhistory[2].Result -eq '2'))) {
                        $OutputContent += "(CRITICAL) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: running; Scheduled: enabled; Runtime: $($veeam_jobruntime.Days | % tostring 00):$($veeam_jobruntime.Hours | % tostring 00):$($veeam_jobruntime.Minutes | % tostring 00):$($veeam_jobruntime.Seconds | % tostring 00)"
                        $OutputContent += "`n"
                        $OutputCount_CRITICAL = $OutputCount_CRITICAL + 1
                        $ExitCode = Set-ExitCode -code 2

                    }
                    else {
                        $OutputContent += "(WARNING) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: running; Scheduled: enabled; Runtime: $($veeam_jobruntime.Days | % tostring 00):$($veeam_jobruntime.Hours | % tostring 00):$($veeam_jobruntime.Minutes | % tostring 00):$($veeam_jobruntime.Seconds | % tostring 00)"
                        $OutputContent += "`n"
                        $OutputCount_WARNING = $OutputCount_WARNING + 1
                        $ExitCode = Set-ExitCode -code 1
                    }
                }
                elseif ($veeam_jobruntime.TotalMinutes -ge $runtime_CRITICAL) {
                    $OutputContent += "(CRITICAL) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: running; Scheduled: enabled; Runtime: $($veeam_jobruntime.Days | % tostring 00):$($veeam_jobruntime.Hours | % tostring 00):$($veeam_jobruntime.Minutes | % tostring 00):$($veeam_jobruntime.Seconds | % tostring 00)"
                    $OutputContent += "`n"
                    $OutputCount_CRITICAL = $OutputCount_CRITICAL + 1
                    $ExitCode = Set-ExitCode -code 2
                }
                else {
                    if (($veeam_jobhistory[1].Result -eq '2') -or (($veeam_jobhistory[1].Result -eq '1') -and ($veeam_jobhistory[2].Result -eq '2'))) {
                        $OutputContent += "(CRITICAL) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: running; Scheduled: enabled; Runtime: $($veeam_jobruntime.Days | % tostring 00):$($veeam_jobruntime.Hours | % tostring 00):$($veeam_jobruntime.Minutes | % tostring 00):$($veeam_jobruntime.Seconds | % tostring 00)"
                        $OutputContent += "`n"
                        $OutputCount_CRITICAL = $OutputCount_CRITICAL + 1
                        $ExitCode = Set-ExitCode -code 2
                    }
                    elseif (($veeam_jobhistory[1].Result -eq '1') -and ($veeam_jobhistory[2].Result -eq '1')) {
                        $OutputContent += "(WARNING) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: running; Scheduled: enabled; Runtime: $($veeam_jobruntime.Days | % tostring 00):$($veeam_jobruntime.Hours | % tostring 00):$($veeam_jobruntime.Minutes | % tostring 00):$($veeam_jobruntime.Seconds | % tostring 00)"
                        $OutputContent += "`n"
                        $OutputCount_WARNING = $OutputCount_WARNING + 1
                        $ExitCode = Set-ExitCode -code 1
                    }
                    else {
                        $OutputContent += "(OK) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: running; Scheduled: enabled; Runtime: $($veeam_jobruntime.Days | % tostring 00):$($veeam_jobruntime.Hours | % tostring 00):$($veeam_jobruntime.Minutes | % tostring 00):$($veeam_jobruntime.Seconds | % tostring 00)"
                        $OutputContent += "`n"
                        $OutputCount_OK = $OutputCount_OK + 1
                    }
                }
            }
        }
        elseif (!($veeam_jobenabled.schedule_enabled)) {
            $OutputContent += "(OK) Job: $veeam_jobname; Scheduled: disabled"
            $OutputContent += "`n"
            $OutputCount_OK = $OutputCount_OK + 1
        }
        else {
            if ($veeam_jobhistory[0].Result -eq '0' -or $veeam_state -eq 'Idle') {
                $OutputContent += "(OK) Job: $veeam_jobname; Last Result: $veeam_jobhistory[0].Result; State: $veeam_state; Scheduled: $veeam_jobenabled.schedule_enabled; Runtime: $($veeam_jobruntime.Days | % tostring 00):$($veeam_jobruntime.Hours | % tostring 00):$($veeam_jobruntime.Minutes | % tostring 00):$($veeam_jobruntime.Seconds | % tostring 00)"
                $OutputContent += "`n"
                $OutputCount_OK = $OutputCount_OK + 1
            }
            else {
                $OutputContent += "(WARNING) Job: $veeam_jobname; Last Result: $veeam_jobhistory[0].Result; State: $veeam_state; Scheduled: $veeam_jobenabled.schedule_enabled; Runtime: $($veeam_jobruntime.Days | % tostring 00):$($veeam_jobruntime.Hours | % tostring 00):$($veeam_jobruntime.Minutes | % tostring 00):$($veeam_jobruntime.Seconds | % tostring 00)"
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

try {
    $VeeamCoreDll = (Get-Item "C:\Program Files\Veeam\Backup and Replication\Console\veeam.backup.core.dll").VersionInfo.ProductVersion
    $VeeamBackupShell = (Get-Item "C:\Program Files\Veeam\Backup and Replication\Console\veeam.backup.shell.exe").VersionInfo.ProductVersion
}
catch {
    $VeeamCoreDll = "n/a"
    $VeeamBackupShell = "n/a"
}
$OutputContent += "`n"
$OutputContent += "Veeam.Backup.Core=$VeeamCoreDll"
$OutputContent += "`n"
$OutputContent += "Veeam.Backup.Shell=$VeeamBackupShell"
$OutputContent += "`n"
$OutputContent += "Database Type: " + $activeConfig

Write-Host "(OK): $OutputCount_OK; (WARNING): $OutputCount_WARNING; (CRITICAL): $OutputCount_CRITICAL; (PENDING): $OutputCount_PENDING; Jobs in Check: $OutputCount_Jobs"
Write-Host ""
Write-Host "Running Jobs Runtime Thresholds - WARNING at $runtime_WARNING minutes - CRITICAL at $runtime_CRITICAL minutes"
Write-Host $OutputContent

$LASTEXITCODE = $ExitCode
;exit ($ExitCode)
