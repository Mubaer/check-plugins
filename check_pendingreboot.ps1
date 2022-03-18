###############################################################################
# Check-PendingReboot.ps1
# Andres Bohren / www.icewolf.ch / blog.icewolf.ch / a.bohren@icewolf.ch
# Version 1.0 / 03.06.202020 - Initial Version
###############################################################################
<#
.SYNOPSIS
    This Script checks diffrent Registry Keys and Values do determine if a Reboot is pending.
 
.DESCRIPTION
 I found this Table on the Internet and decided to Write a Powershell Script to check if a Reboot is pending.
 Not all Keys are checked. But feel free to extend the Script.
 
 https://adamtheautomator.com/pending-reboot-registry-windows/
 KEY VALUE CONDITION
 HKLM:\SOFTWARE\Microsoft\Updates UpdateExeVolatile Value is anything other than 0
 HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager PendingFileRenameOperations value exists
 HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager PendingFileRenameOperations2 value exists
 HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired NA key exists
 HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Services\Pending NA Any GUID subkeys exist
 HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\PostRebootReporting NA key exists
 HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce DVDRebootSignal value exists
 HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending NA key exists
 HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootInProgress NA key exists
 HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\PackagesPending NA key exists
 HKLM:\SOFTWARE\Microsoft\ServerManager\CurrentRebootAttempts NA key exists
 HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon JoinDomain value exists
 HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon AvoidSpnSet value exists
 HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName ComputerName Value ComputerName in HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName is different
 
.EXAMPLE
 ./Check-PendingReboot.ps1

#>

$PendingReboot = "(OK): No reboot required"
$exitcode = 0

#Check for Keys
If ((Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") -eq $true)
{
 $PendingReboot = "(WARNING): Reboot Required"
 $exitcode = 1
}

If ((Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\PostRebootReporting") -eq $true)
{
 $PendingReboot = "(WARNING): Reboot Required"
 $exitcode = 1
}

If ((Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") -eq $true)
{
 $PendingReboot = "(WARNING): Reboot Required"
 $exitcode = 1
}

If ((Test-Path -Path "HKLM:\SOFTWARE\Microsoft\ServerManager\CurrentRebootAttempts") -eq $true)
{
 $PendingReboot = "(WARNING): Reboot Required"
 $exitcode = 1
}

Write-Host $PendingReboot

$host.SetShouldExit($exitcode)
exit
