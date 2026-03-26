# Avoid Certificate check. We use a self-signed cert

if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type) {
    $certCallback = @"
    using System;
    using System.Net;
    using System.Net.Security;
    using System.Security.Cryptography.X509Certificates;
    public class ServerCertificateValidationCallback {
        public static void Ignore() {
            if (ServicePointManager.ServerCertificateValidationCallback == null) {
                ServicePointManager.ServerCertificateValidationCallback += 
                    (obj, certificate, chain, errors) => true;
            }
        }
    }
"@
    Add-Type $certCallback
}
[ServerCertificateValidationCallback]::Ignore()

# Enable Server 2016 to establish a secure TLS channel
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12   

$LASTEXITCODE = 0
$version = "1.1.0" # determine sat and hostname from zones.conf to match Icinga hostname
$report = @()
$exec_time = (get-date).ToString("dd.MM.yyyy HH:mm:ss")
# Get last results of CU installation
$cus = Get-WUHistory -Last 30  | Where-Object { $_.Title -match 'umulative' } | Sort-Object -property "Date" -Descending  | Select-Object  Result, Date, Title
$cus | ForEach-Object{
if($_.Result -match "Succeeded"){
$_.Title = $_.Title -replace "ü","ue"
$_.Result = "(OK) Succeeded"
}

if($_.Result -match "InProgress"){
$_.Result = "(WARNING) InProgress"
}

if($_.Result -match "Failed"){
$_.Result = "(CRITICAL) Failed"
}

$report += $_
}

# Evaluate latest result and compile overall result
if($cus[0].Result -match "WARNING"){
$LASTEXITCODE = 1
}
if($cus[0].Result -match "CRITICAL"){
$LASTEXITCODE = 2
}

# Format Result json compliant
$plugin_output = "Installation status of latest CUs" + "\n" + "\n"
$plugin_output = $plugin_output + "Result" + "`t"+ "`t" + "Date/Time" + "`t" + "`t" + "Title" + "\n"
$plugin_output = $plugin_output + "------" + "`t"+ "`t" + "---------"  + "`t"+ "`t" + "-----" + "\n"
$report | ForEach-Object{
$plugin_output = $plugin_output + $_.result + "`t" + $($_.Date).tostring("dd.MM.yyyy HH:mm:ss") + "`t" + $_.Title + "\n"
}
$plugin_output = $plugin_output + "\n" + "\n" + "Check-version: " + $version + "\n" + "Last execution time: " + $exec_time + "\n" + "\n"
$plugin_output = $plugin_output + "This is a passive check. Check now does nothing! It runs once every hour by default."

# Send Output to Icinga2 passive check
$ICINGA_SERVER = ((((Get-Content "C:\ProgramData\icinga2\etc\icinga2\zones.conf" | Select-String "host" ) -split "=")[1]).trimstart(' \"')).trimend('\";')
$ICINGA_PORT = "5665"
$API_USER = "passive_checks"
$API_PASSWORD = "aibai7usahCahghi"
$HOST_NAME = ((((Get-Content "C:\ProgramData\icinga2\etc\icinga2\zones.conf" | Select-String "Object endpoint" ) -split " ")[2]).trimstart(' \"')).trimend('\";')
$SERVICE_NAME = "Patch Installation Status"
$STATUS_CODE = $LASTEXITCODE
$OUTPUT = $plugin_output
$headers = @{
    "Accept" = "application/json"
 }
$jsonBody = @{
    type = "Service"
    filter = "host.name==`"$HOST_NAME`" && service.name==`"$SERVICE_NAME`""
    exit_status = $STATUS_CODE
    plugin_output = $OUTPUT
} | ConvertTo-Json

$uri = "https://${ICINGA_SERVER}:$ICINGA_PORT/v1/actions/process-check-result"
$creds = New-Object System.Management.Automation.PSCredential($API_USER, (ConvertTo-SecureString $API_PASSWORD -AsPlainText -Force))

Invoke-RestMethod -Uri $uri -Method Post -Body $jsonBody -Headers $headers -Credential $creds