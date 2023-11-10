# CPUs
wmic cpu get NumberOfCores,NumberOfLogicalProcessors

#RAM in GB
$memory = Get-WMIObject -Class Win32_Computersystem -ErrorAction SilentlyContinue | Select-Object TotalPhysicalMemory
$GB = [Math]::Round($memory.TotalPhysicalMemory/ 1GB)

# Diskfree
$disk = Get-CimInstance -ClassName Win32_LogicalDisk
$diskfree = [Math]::Round($disk[0].Freespace / $disk[0].Size * 100)

# Windows activated?
function Get-ActivationStatus {
[CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$DNSHostName = $Env:COMPUTERNAME
    )
    process {
        try {
            $wpa = Get-WmiObject SoftwareLicensingProduct -ComputerName $DNSHostName `
            -Filter "ApplicationID = '55c92734-d682-4d71-983e-d6ec3f16059f'" `
            -Property LicenseStatus -ErrorAction Stop
        } catch {
            $status = New-Object ComponentModel.Win32Exception ($_.Exception.ErrorCode)
            $wpa = $null    
        }
        $out = New-Object psobject -Property @{
            ComputerName = $DNSHostName;
            Status = [string]::Empty;
        }
        if ($wpa) {
            :outer foreach($item in $wpa) {
                switch ($item.LicenseStatus) {
                    0 {$out.Status = "Unlicensed"}
                    1 {$out.Status = "Licensed"; break outer}
                    2 {$out.Status = "Out-Of-Box Grace Period"; break outer}
                    3 {$out.Status = "Out-Of-Tolerance Grace Period"; break outer}
                    4 {$out.Status = "Non-Genuine Grace Period"; break outer}
                    5 {$out.Status = "Notification"; break outer}
                    6 {$out.Status = "Extended Grace"; break outer}
                    default {$out.Status = "Unknown value"}
                }
            }
        } else {$out.Status = $status.Message}
        $out
    }
}

$licensed = $(Get-ActivationStatus).Status

#Buildnumber
$version = (Get-itemproperty -path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -name CurrentBuildNumber).CurrentBuildNumber
$patchlevel = (Get-itemproperty -path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -name UBR).UBR
$buildnumber = $version + "." + $patchlevel 

#RebootRequired?
Set-ExecutionPolicy Unrestricted
install-module pendingreboot
Import-Module pendingreboot
Test-PendingReboot #-Detailed

#oder

function Test-PendingReboot {
    if (Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -EA Ignore) { return $true }
    if (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -EA Ignore) { return $true }
    if (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -EA Ignore) { return $true }
    try { 
        $util = [wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities"
        $status = $util.DetermineIfRebootPending()
        if (($status -ne $null) -and $status.RebootPending) {
            return $true
        }
    }
    catch { }

    return $false
}

Test-PendingReboot


