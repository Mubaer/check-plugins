$ExitCode = 0
function Set-ExitCode {
    param ($code)
    if ($ExitCode -lt $code) {
        $ExitCode = $code
    }
    return $ExitCode
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
    Write-Host "(UNKNOWN) Failed to import Veeam PS Module"
    ;exit (3)
    }
}

Import-Module SQLPS -ErrorAction SilentlyContinue
$sqlServerName = $env:COMPUTERNAME
$sqlInstanceName = "VeeamSQL2016"
$sqlDatabaseName = "VeeamBackup"
$username = get-content -Path "C:\MRDaten\temp.txt" | Select-Object -index 0
$password = get-content -Path "C:\MRDaten\temp.txt" | Select-Object -index 1
$timeNow = Get-Date
$version = "2.5.0" # 
$OutputContent = "`n"
$ErrorActionPreference= 'silentlycontinue'



# Check Database type
try{$sql_result = Invoke-SqlCmd -Query "SELECT GETDATE() AS TimeOfQuery" -ServerInstance "$sqlServerName\$sqlInstanceName" -Database $sqlDatabaseName -Username $username -Password $password}catch{}
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

Write-host "(UNKNOWN) Keine Datenbank-Anmeldung m�glich"

}


$LicenseStatus = Get-VBRInstalledLicense

if ($LicenseStatus.Status -ne 'Valid') {
    $OutputContent += "`n"
    $OutputContent += "(CRITICAL) Veeam License Status is $($LicenseStatus.Status)"
    $ExitCode = Set-ExitCode -code 2
}
if ($LicenseStatus.Type -eq 'Perpetual'){
    $OutputContent += "`n"
    $OutputContent += "(OK) Veeam License perpetual"
}
else {
    $VeeamLicenseExpiration = New-TimeSpan -Start $timeNow -End $LicenseStatus.ExpirationDate
    if ($VeeamLicenseExpiration.TotalDays -gt 65) {
        $OutputContent += "`n"
        $OutputContent += "(OK) Veeam License expires in $([math]::Floor($VeeamLicenseExpiration.TotalDays)) days"
    }
    elseif (($VeeamLicenseExpiration.TotalDays -le 65) -and ($VeeamLicenseExpiration -gt 35)) {
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
$OutputContent += "`n"
$OutputContent += "Check version: " + $version

$OutputContent

$LASTEXITCODE = $ExitCode
exit ($ExitCode)