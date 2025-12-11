###  Icinga Veeam BackupJob Check   ###
###   (c) MR-Daten - Charly Kupke   ###
###   Erweiterung: Peter Ziegler    ###
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

param(
    [String[]]$exclusivejob,
    [String[]]$ignorejob,
    [Switch]$runtime,
    [Int]$runtime_WARNING = 1440,
    [Int]$runtime_CRITICAL = 2880,
    $veeamdbuser,
    $veeamdbpass
    )
$version = "3.5.0" # umgestellt DB-Credentials kommen von Icinga Engine
$ErrorActionPreference = "SilentlyContinue"
$WarningPreference = "SilentlyContinue"
$Transscript_path = "C:\mr_managed_it\Logs\check_VeeamBackupJob." + (Get-Date).ToString("yyyy-MM-dd_HH-mm-ss") + ".txt"

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
    $veeamPSModule = Get-Module -ListAvailable | Where-Object{$_.Name -match "Veeam.Backup.Powershell"}
    Import-Module $veeamPSModule.Path -DisableNameChecking
} catch {
    #Write-Host "Import Module failed, trying hardlink"
    try {
        import-module "C:\Program Files\Veeam\Backup and Replication\Console\Veeam.Backup.PowerShell.dll"
    }catch{
    Write-Host "(CRITICAL) Failed to import Veeam PS Module."
    ;exit (3)
    }
}

Import-Module SQLPS

$timeNow = Get-Date
$OutputContent = @()
$OutputContent = "`n"
$OutputCount_OK = 0
$OutputCount_WARNING = 0
$OutputCount_CRITICAL = 0
$OutputCount_PENDING = 0
$OutputCount_UNKNOWN = 0
$OutputCount_Jobs = 0

$veeam_no_copyjobs = Get-VBRJob

if($veeam_no_copyjobs){
$veeamjobs = @()
foreach ($veeam_no_copyjob in $veeam_no_copyjobs) {
    if (-not $veeam_no_copyjob.LinkedJobs -and -not $veeam_no_copyjob.LinkedRepositories) {
        $veeamjobs += $veeam_no_copyjob
    }
}
}else{
    "(CRITCAL) Failed to connect to Veeam Service." | Out-File -FilePath $Transscript_path -Append
    $ExitCode = Set-ExitCode -code 2
}
"Veeam-Jobs w/o Copyjobs: " | Out-File -FilePath $Transscript_path -Append
$veeamjobs | Out-File -FilePath $Transscript_path -Append
$agentjobs = Get-VBREPJob | Select-Object name
"Agent-Jobs: " | Out-File -FilePath $Transscript_path -Append
$agentjobs | Out-File -FilePath $Transscript_path -Append
$tapejobs = Get-VBRTapeJob | Select-Object name
"Tape-Jobs: " | Out-File -FilePath $Transscript_path -Append
$tapejobs | Out-File -FilePath $Transscript_path -Append
$veeamjobs += $agentjobs
$veeamjobs += $tapejobs
$sqlServerName = $env:COMPUTERNAME
$sqlInstanceName = "VeeamSQL2016"
$sqlDatabaseName = "VeeamBackup"

if($veeamdbuser -and $veeamdbpass){
$username = $veeamdbuser
$password = $veeamdbpass
}else{
$username = get-content -Path "C:\MRDaten\temp.txt" | Select-Object -index 0
$password = get-content -Path "C:\MRDaten\temp.txt" | Select-Object -index 1
}
# Check Database type
$sql_result = ""
$sql_result = Invoke-SqlCmd -Query "SELECT GETDATE() AS TimeOfQuery" -ServerInstance "$sqlServerName\$sqlInstanceName" -Database $sqlDatabaseName -Username $username -Password $password
if (!$sql_result){
Set-Location 'C:\Program Files\PostgreSQL\15\bin\';
$env:PGPASSWORD = $password
$cmd = "\l"
$psql_result = @(.\psql -h 127.0.0.1 -U $username -w -d VeeamBackup -c "$cmd")}
if($sql_result){
$activeConfig = "MSSQL"
}elseif($psql_result){
$activeConfig = "PSQL"
}else{

Write-Host "(CRITICAL) Failed to connect to database."
$ExitCode = Set-ExitCode -code 2
;Exit (3)
}


# Find S3 Offload Jobs
if ($activeConfig -eq "MSSQL") {
$s3repos = "SELECT name, type FROM [VeeamBackup].[dbo].[BackupRepositories] where type like '10';"
$resultRepos = @(Invoke-SqlCmd -Query $s3repos -ServerInstance "$sqlServerName\$sqlInstanceName" -Database $sqlDatabaseName -Username $username -Password $password)
$repo_name = $resultRepos[0].name
$sqlS3Job = "SELECT TOP (1) job_name, job_type FROM [VeeamBackup].[dbo].[Backup.Model.JobSessions] where (job_name like '$repo_name%' and job_type like '18000') order by creation_time desc"
$veeam_S3Jobresult = @(Invoke-SqlCmd -Query $sqlS3Job -ServerInstance "$sqlServerName\$sqlInstanceName" -Database $sqlDatabaseName -Username $username -Password $password)
if ($veeam_S3Jobresult){
$veeamjobs = $veeamjobs + $veeam_S3Jobresult.job_name
"S3-Jobs: " | Out-File -FilePath $Transscript_path -Append
$veeam_S3Jobresult.job_name | Out-File -FilePath $Transscript_path -Append
}
}elseif($activeConfig -eq "PSQL"){
Set-Location 'C:\Program Files\PostgreSQL\15\bin\';
$env:PGPASSWORD = $password
$s3repos = "SELECT name, type FROM public.\""backuprepositories\"" where type = '10';"
$resultRepos = @(.\psql -h 127.0.0.1  -U $username -w -d VeeamBackup -c "$s3repos")
$numberofrepos = ($resultRepos | Measure-Object -Line).lines
if($numberofrepos -ge 4){
$numberofrepos--
$numberofrepos--
For ($i = 2; $i -le $numberofrepos; $i++) { 
$repo_name = ($resultRepos[$i]  -split "\|",2)[0]
$repo_name = (($repo_name).TrimEnd(" ")).TrimStart(" ")
if ($repo_name -ne "(0 Zeilen)"){$sqlS3Job = "SELECT job_name, job_type FROM  public.\""backup.model.jobsessions\"" where (job_name like '$repo_name Offload') order by creation_time desc limit 1"
$veeam_S3Jobresult = @(.\psql -h 127.0.0.1 -U $username -w -d VeeamBackup -c "$sqls3job")}
if ($veeam_S3Jobresult[2] -notlike "(0 Zeilen)"){
$veeamS3Job = ($veeam_S3Jobresult[2]  -split "\|",2)[0]
$veeamS3Job = (($veeamS3Job).TrimEnd(" ")).TrimStart(" ")
$veeamjobs = $veeamjobs + $veeamS3Job
"S3-Jobs: " | Out-File -FilePath $Transscript_path -Append
$veeamS3Job | Out-File -FilePath $Transscript_path -Append
}
}
}
}else{
Write-Host "(CRITICAL) Failed to connect to database."
$ExitCode = Set-ExitCode -code 2
;Exit (3)
}

# Find Copy jobs

$veeamcopyjobs = Get-vbrbackupcopyjob
"CopyJobs: "  | Out-File -FilePath $Transscript_path -Append
foreach ($veeamcopyjob in $veeamcopyjobs){
$veeamcopybackupjobs = $veeamcopyjob.BackupJob
$veeamcopyjob.Name | Out-File -FilePath $Transscript_path -Append
foreach ($veeamcopybackupjob in $veeamcopybackupjobs){
if($activeConfig -eq "PSQL"){
$veeam_jobname = $veeamcopyjob.name + "%\" + $veeamcopybackupjob.name
}else{
$veeam_jobname = $veeamcopyjob.name + "\" + $veeamcopybackupjob.name
}
$veeamjobs = $veeamjobs + $veeam_jobname
}
}

# Find SurebackupJobs

$veeamsbjobs = Get-VBRSureBackupJob
foreach ($veeamsbjob in $veeamsbjobs){
$veeamjobs = $veeamjobs + $veeamsbjob.Name
}

"Exclusive Jobs: " | Out-File -FilePath $Transscript_path -Append
$exclusivejob | Out-File -FilePath $Transscript_path -Append
"Ignore Jobs: "  | Out-File -FilePath $Transscript_path -Append
$ignorejob | Out-File -FilePath $Transscript_path -Append

# create array for output and sorting
$number_of_jobs = $veeamjobs.Count
[string[]]$OutputContent = New-Object string[] $number_of_jobs
$i = -1
# Check each Job

Foreach ($veeamjob in $veeamjobs) {
    $i = $i + 1
    if($veeamjob.name -like ""){
    $veeam_jobname = $veeamjob}
    else{
    $veeam_jobname = $veeamjob.name}
    if (($exclusivejob -and $exclusivejob -contains $veeam_jobname) -or ($ignorejob -and $ignorejob -notcontains $veeam_jobname) -or (!$exclusivejob -and !$ignorejob)) {
        $OutputCount_Jobs = $OutputCount_Jobs + 1
        
        if  ($activeConfig -eq "MSSQL") {
            $sqlQueryResults = "SELECT TOP (3) job_name, job_type, job_id, creation_time, end_time, result, state FROM [VeeamBackup].[dbo].[Backup.Model.JobSessions] where (job_name like '$veeam_jobname') order by creation_time desc"
            $veeam_jobhistory = @(Invoke-SqlCmd -Query $sqlQueryResults -ServerInstance "$sqlServerName\$sqlInstanceName" -Database $sqlDatabaseName -Username $username -Password $password)
            $sqlQueryResults = "SELECT schedule_enabled  FROM [VeeamBackup].[dbo].[BJobs] where (name like '$veeam_jobname')"
            $veeam_jobenabled = Invoke-SqlCmd -Query $sqlQueryResults -ServerInstance "$sqlServerName\$sqlInstanceName" -Database $sqlDatabaseName -Username $username -Password $password
            }elseif($activeConfig -eq "PSQL"){
            $veeam_jobhistory =
            @([pscustomobject]@{job_name="";job_type="";creation_time="";end_time="";result="";state=""},
              [pscustomobject]@{job_name="";creation_time="";end_time="";result="";state=""},
              [pscustomobject]@{job_name="";creation_time="";end_time="";result="";state=""})

            Set-Location 'C:\Program Files\PostgreSQL\15\bin\';
            $env:PGPASSWORD = $password
            #$cmd = "SELECT job_name, job_type, state, creation_time, end_time, result FROM public.\""backup.model.jobsessions\"" where (job_name like '$veeam_jobname') ORDER BY creation_time DESC LIMIT 3;"
            $cmd = "SELECT job_name, job_type, state, creation_time, end_time, result FROM (Select *,ROW_NUMBER() OVER (PARTITION BY orig_session_id ORDER BY creation_time DESC) As RowNum from public.\""backup.model.jobsessions\"" Where (job_name like '$veeam_jobname' and job_type != '65') )  AS SubQuery Where RowNum = 1 ORDER BY creation_time desc Limit 3;"
            $result = @(.\psql -h 127.0.0.1 -U $username -w -d VeeamBackup -c "$cmd")
            
            $veeam_jobhistory[0].job_name = ($result[2] -split "\|",6)[0]
            $veeam_jobhistory[0].job_type = ((($result[2] -split "\|",6)[1]).TrimStart(" ")).TrimEnd(" ")
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
            $result = @(.\psql -h 127.0.0.1 -U $username -w -d VeeamBackup -c "$sqlQueryResults")
            $veeam_jobenabled = ($result[2] -split "\|",2 )[1]

            }else{
            Write-Host "Failed to connect to database."
            $ExitCode = Set-ExitCode -code 2
            ;Exit (3)
            }

            switch ($veeam_jobhistory[0].state){
            -1 {$veeam_state = "Stopped"}
            5  {$veeam_state = "Waiting/Running"}
            default {$veeam_state = "unknown"}
            }
            $veeam_jobname = $veeam_jobname.Replace("%","")
            if ($veeam_jobenabled.schedule_enabled -like "True" -or $veeam_jobenabled -like " t" -or $veeam_jobhistory[0].job_type -eq "18000" -or $veeam_jobhistory[0].job_type -eq "18004") { # job_type 18000/18004 are S3-Offload-Jobs
            
            if ($veeam_jobhistory[0].job_name -like "(0 Zeilen)" -or !($veeam_jobhistory)){
            $OutputContent[$i] =  "3(UNKNOWN) Job: $veeam_jobname; Job never ran and/or no entries found in Database"
            $OutputCount_UNKNOWN = $OutputCount_UNKNOWN + 1
            }else{
            
            if ($veeam_jobhistory[0].end_time -notlike '*1900*') {
                $veeam_jobruntime = New-TimeSpan -Start $veeam_jobhistory[0].Creation_Time -End $veeam_jobhistory[0].End_Time
                if ($veeam_jobhistory[0].Result -eq '0') {
                    $OutputContent[$i] =   "4(OK) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: $veeam_state; Scheduled: enabled ; Runtime: $($veeam_jobruntime.Days | ForEach-Object tostring 00):$($veeam_jobruntime.Hours | ForEach-Object tostring 00):$($veeam_jobruntime.Minutes | ForEach-Object tostring 00):$($veeam_jobruntime.Seconds | ForEach-Object tostring 00)"
                    $OutputCount_OK = $OutputCount_OK + 1
                }
                elseif ($veeam_jobhistory[0].Result -eq '1') {
                    if ($veeam_jobhistory[1].Result -eq '0') {
                        $OutputContent[$i] =   "4(OK) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: $veeam_state; Scheduled: enabled ; Runtime: $($veeam_jobruntime.Days | ForEach-Object tostring 00):$($veeam_jobruntime.Hours | ForEach-Object tostring 00):$($veeam_jobruntime.Minutes | ForEach-Object tostring 00):$($veeam_jobruntime.Seconds | ForEach-Object tostring 00)"
                        $OutputCount_OK = $OutputCount_OK + 1
                    }
                    elseif ($veeam_jobhistory[1].Result -eq '1') {
                        if ($veeam_jobhistory[2].Result -eq '0') {
                            $OutputContent[$i] = "2(WARNING) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: $veeam_state; Scheduled: enabled; Runtime: $($veeam_jobruntime.Days | ForEach-Object tostring 00):$($veeam_jobruntime.Hours | ForEach-Object tostring 00):$($veeam_jobruntime.Minutes | ForEach-Object tostring 00):$($veeam_jobruntime.Seconds | ForEach-Object tostring 00)"
                            $OutputCount_WARNING = $OutputCount_WARNING + 1
                            $ExitCode = Set-ExitCode -code 1
                        }
                        else {
                            $OutputContent[$i] = "1(CRITICAL) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: $veeam_state; Scheduled: enabled; Runtime: $($veeam_jobruntime.Days | ForEach-Object tostring 00):$($veeam_jobruntime.Hours | ForEach-Object tostring 00):$($veeam_jobruntime.Minutes | ForEach-Object tostring 00):$($veeam_jobruntime.Seconds | ForEach-Object tostring 00)"
                            $OutputCount_CRITICAL = $OutputCount_CRITICAL + 1
                            $ExitCode = Set-ExitCode -code 2
                        }
                    }
                    else {
                        $OutputContent[$i] = "1(CRITICAL) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: $veeam_state; Scheduled: enabled; Runtime: $($veeam_jobruntime.Days | ForEach-Object tostring 00):$($veeam_jobruntime.Hours | ForEach-Object tostring 00):$($veeam_jobruntime.Minutes | ForEach-Object tostring 00):$($veeam_jobruntime.Seconds | ForEach-Object tostring 00)"
                        $OutputCount_CRITICAL = $OutputCount_CRITICAL + 1
                        $ExitCode = Set-ExitCode -code 2
                    }
                }
                else {
                    if ($veeam_jobhistory[1].Result -eq '0') {
                        $OutputContent[$i] = "4(OK) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: $veeam_state; Scheduled: enabled; Runtime: $($veeam_jobruntime.Days | ForEach-Object tostring 00):$($veeam_jobruntime.Hours | ForEach-Object tostring 00):$($veeam_jobruntime.Minutes | ForEach-Object tostring 00):$($veeam_jobruntime.Seconds | ForEach-Object tostring 00)"
                        $OutputCount_OK = $OutputCount_OK + 1
                    }
                    elseif ($veeam_jobhistory[1].Result -eq '1') {
                        $OutputContent[$i] = "2(WARNING) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: $veeam_state; Scheduled: enabled; Runtime: $($veeam_jobruntime.Days | ForEach-Object tostring 00):$($veeam_jobruntime.Hours | ForEach-Object tostring 00):$($veeam_jobruntime.Minutes | ForEach-Object tostring 00):$($veeam_jobruntime.Seconds | ForEach-Object tostring 00)"
                        $OutputCount_WARNING = $OutputCount_WARNING + 1
                        $ExitCode = Set-ExitCode -code 1
                    }
                    else {
                        $OutputContent[$i] = "1(CRITICAL) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: $veeam_state; Scheduled: enabled; Runtime: $($veeam_jobruntime.Days | ForEach-Object tostring 00):$($veeam_jobruntime.Hours | ForEach-Object tostring 00):$($veeam_jobruntime.Minutes | ForEach-Object tostring 00):$($veeam_jobruntime.Seconds | ForEach-Object tostring 00)"
                        $OutputCount_CRITICAL = $OutputCount_CRITICAL + 1
                        $ExitCode = Set-ExitCode -code 2
                    }
                }
            }
            else {
                $veeam_jobruntime = New-TimeSpan -Start $veeam_jobhistory[0].creation_time -End $timeNow
                if (($veeam_jobruntime.TotalMinutes -ge $runtime_WARNING) -and ($veeam_jobruntime.TotalMinutes -lt $runtime_CRITICAL)) {
                    if (($veeam_jobhistory[1].Result -eq '2') -or (($veeam_jobhistory[1].Result -eq '1') -and ($veeam_jobhistory[2].Result -eq '2'))) {
                        $OutputContent[$i] = "1(CRITICAL) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: running; Scheduled: enabled; Runtime: $($veeam_jobruntime.Days | ForEach-Object tostring 00):$($veeam_jobruntime.Hours | ForEach-Object tostring 00):$($veeam_jobruntime.Minutes | ForEach-Object tostring 00):$($veeam_jobruntime.Seconds | ForEach-Object tostring 00)"
                        $OutputCount_CRITICAL = $OutputCount_CRITICAL + 1
                        $ExitCode = Set-ExitCode -code 2

                    }
                    else {
                        $OutputContent[$i] = "2(WARNING) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: running; Scheduled: enabled; Runtime: $($veeam_jobruntime.Days | ForEach-Object tostring 00):$($veeam_jobruntime.Hours | ForEach-Object tostring 00):$($veeam_jobruntime.Minutes | ForEach-Object tostring 00):$($veeam_jobruntime.Seconds | ForEach-Object tostring 00)"
                        $OutputCount_WARNING = $OutputCount_WARNING + 1
                        $ExitCode = Set-ExitCode -code 1
                    }
                }
                elseif ($veeam_jobruntime.TotalMinutes -ge $runtime_CRITICAL) {
                    $OutputContent[$i] = "1(CRITICAL) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: running; Scheduled: enabled; Runtime: $($veeam_jobruntime.Days | ForEach-Object tostring 00):$($veeam_jobruntime.Hours | ForEach-Object tostring 00):$($veeam_jobruntime.Minutes | ForEach-Object tostring 00):$($veeam_jobruntime.Seconds | ForEach-Object tostring 00)"
                    $OutputCount_CRITICAL = $OutputCount_CRITICAL + 1
                    $ExitCode = Set-ExitCode -code 2
                }
                else {
                    if (($veeam_jobhistory[1].Result -eq '2') -or (($veeam_jobhistory[1].Result -eq '1') -and ($veeam_jobhistory[2].Result -eq '2'))) {
                        $OutputContent[$i] = "1(CRITICAL) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: running; Scheduled: enabled; Runtime: $($veeam_jobruntime.Days | ForEach-Object tostring 00):$($veeam_jobruntime.Hours | ForEach-Object tostring 00):$($veeam_jobruntime.Minutes | ForEach-Object tostring 00):$($veeam_jobruntime.Seconds | ForEach-Object tostring 00)"
                        $OutputCount_CRITICAL = $OutputCount_CRITICAL + 1
                        $ExitCode = Set-ExitCode -code 2
                    }
                    elseif (($veeam_jobhistory[1].Result -eq '1') -and ($veeam_jobhistory[2].Result -eq '1')) {
                        $OutputContent[$i] = "2(WARNING) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: running; Scheduled: enabled; Runtime: $($veeam_jobruntime.Days | ForEach-Object tostring 00):$($veeam_jobruntime.Hours | ForEach-Object tostring 00):$($veeam_jobruntime.Minutes | ForEach-Object tostring 00):$($veeam_jobruntime.Seconds | ForEach-Object tostring 00)"
                        $OutputCount_WARNING = $OutputCount_WARNING + 1
                        $ExitCode = Set-ExitCode -code 1
                    }
                    else {
                        $OutputContent[$i] = "4(OK) Job: $veeam_jobname; Last 3 Results: $(LastResultsString -result1 $veeam_jobhistory[0].Result -result2 $veeam_jobhistory[1].Result -result3 $veeam_jobhistory[2].Result); State: running; Scheduled: enabled; Runtime: $($veeam_jobruntime.Days | ForEach-Object tostring 00):$($veeam_jobruntime.Hours | ForEach-Object tostring 00):$($veeam_jobruntime.Minutes | ForEach-Object tostring 00):$($veeam_jobruntime.Seconds | ForEach-Object tostring 00)"
                        $OutputCount_OK = $OutputCount_OK + 1
                    }
                }
            }
        }
        }
        elseif (!($veeam_jobenabled.schedule_enabled)) {
            $OutputContent[$i] += "4(OK) Job: $veeam_jobname; Scheduled: disabled"
            $OutputCount_OK = $OutputCount_OK + 1
        }
        else {
            if ($veeam_jobhistory[0].Result -eq '0' -or $veeam_state -eq 'Idle') {
                $OutputContent[$i] = "4(OK) Job: $veeam_jobname; Last Result: $veeam_jobhistory[0].Result; State: $veeam_state; Scheduled: $veeam_jobenabled.schedule_enabled; Runtime: $($veeam_jobruntime.Days | ForEach-Object tostring 00):$($veeam_jobruntime.Hours | ForEach-Object tostring 00):$($veeam_jobruntime.Minutes | ForEach-Object tostring 00):$($veeam_jobruntime.Seconds | ForEach-Object tostring 00)"
                $OutputCount_OK = $OutputCount_OK + 1
            }
            else {
                $OutputContent[$i] = "2(WARNING) Job: $veeam_jobname; Last Result: $veeam_jobhistory[0].Result; State: $veeam_state; Scheduled: $veeam_jobenabled.schedule_enabled; Runtime: $($veeam_jobruntime.Days | ForEach-Object tostring 00):$($veeam_jobruntime.Hours | ForEach-Object tostring 00):$($veeam_jobruntime.Minutes | ForEach-Object tostring 00):$($veeam_jobruntime.Seconds | ForEach-Object tostring 00)"
                $OutputCount_WARNING = $OutputCount_WARNING + 1
                $ExitCode = Set-ExitCode -code 1
            }
        }
    }
}




Write-Host "(CRITICAL): $OutputCount_CRITICAL; (WARNING): $OutputCount_WARNING; (UNKNOWN): $OutputCount_UNKNOWN; (OK): $OutputCount_OK; (PENDING): $OutputCount_PENDING; Jobs in Check: $OutputCount_Jobs"
Write-Host ""
$OutputContent = $OutputContent | Sort-Object
$OutputContent = $OutputContent -replace "^[1234]", ""



foreach ($Output in $OutputContent){
write-host $Output}

Write-Host ""
Write-Host "Thresholds:"
Write-Host "  Running Jobs Runtime"
Write-Host "  (WARNING): $runtime_WARNING minutes"
Write-Host "  (CRITICAL): $runtime_CRITICAL minutes"
Write-Host ""
Write-Host "Check version: " $version


$LASTEXITCODE = $ExitCode
exit ($ExitCode)