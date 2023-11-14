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
function Get-InstalledSoftware {
        <#
        .SYNOPSIS
            Retrieves a list of all software installed on a Windows computer.
        .EXAMPLE
            PS> Get-InstalledSoftware
            
            This example retrieves all software installed on the local computer.
        .PARAMETER ComputerName
            If querying a remote computer, use the computer name here.
        
        .PARAMETER Name
            The software title you'd like to limit the query to.
        
        .PARAMETER Guid
            The software GUID you'e like to limit the query to
        #>
        [CmdletBinding()]
        param (
            
            [Parameter()]
            [ValidateNotNullOrEmpty()]
            [string]$ComputerName = $env:COMPUTERNAME,
            
            [Parameter()]
            [ValidateNotNullOrEmpty()]
            [string]$Name,
            
            [Parameter()]
            [guid]$Guid
        )
        process {
            try {
                $scriptBlock = {
                    $args[0].GetEnumerator() | ForEach-Object { New-Variable -Name $_.Key -Value $_.Value }
                    
                    $UninstallKeys = @(
                        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
                        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
                    )
                    New-PSDrive -Name HKU -PSProvider Registry -Root Registry::HKEY_USERS | Out-Null
                    $UninstallKeys += Get-ChildItem HKU: | Where-Object{ $_.Name -match 'S-\d-\d+-(\d+-){1,14}\d+$' } | ForEach-Object {
                        "HKU:\$($_.PSChildName)\Software\Microsoft\Windows\CurrentVersion\Uninstall"
                    }
                    if (-not $UninstallKeys) {
                        Write-Warning -Message 'No software registry keys found'
                    } else {
                        ForEach ($UninstallKey in $UninstallKeys) {
                            $friendlyNames = @{
                                'DisplayName'    = 'Name'
                                'DisplayVersion' = 'Version'
                            }
                            Write-Verbose -Message "Checking uninstall key [$($UninstallKey)]"
                            if ($Name) {
                                $WhereBlock = { $_.GetValue('DisplayName') -like "$Name*" }
                            } elseif ($GUID) {
                                $WhereBlock = { $_.PsChildName -eq $Guid.Guid }
                            } else {
                                $WhereBlock = { $_.GetValue('DisplayName') }
                            }
                            $SwKeys = Get-ChildItem -Path $UninstallKey -ErrorAction SilentlyContinue | Where-Object $WhereBlock
                            if (-not $SwKeys) {
                                Write-Verbose -Message "No software keys in uninstall key $UninstallKey"
                            } else {
                                foreach ($SwKey in $SwKeys) {
                                    $output = @{ }
                                    foreach ($ValName in $SwKey.GetValueNames()) {
                                        if ($ValName -ne 'Version') {
                                            $output.InstallLocation = ''
                                            if ($ValName -eq 'InstallLocation' -and 
                                                ($SwKey.GetValue($ValName)) -and 
                                                (@('C:', 'C:\Windows', 'C:\Windows\System32', 'C:\Windows\SysWOW64') -notcontains $SwKey.GetValue($ValName).TrimEnd('\'))) {
                                                $output.InstallLocation = $SwKey.GetValue($ValName).TrimEnd('\')
                                            }
                                            [string]$ValData = $SwKey.GetValue($ValName)
                                            if ($friendlyNames[$ValName]) {
                                                $output[$friendlyNames[$ValName]] = $ValData.Trim() ## Some registry values have trailing spaces.
                                            } else {
                                                $output[$ValName] = $ValData.Trim() ## Some registry values trailing spaces
                                            }
                                        }
                                    }
                                    $output.GUID = ''
                                    if ($SwKey.PSChildName -match '\b[A-F0-9]{8}(?:-[A-F0-9]{4}){3}-[A-F0-9]{12}\b') {
                                        $output.GUID = $SwKey.PSChildName
                                    }
                                    New-Object -TypeName PSObject -Prop $output
                                }
                            }
                        }
                    }
                }
                
                if ($ComputerName -eq $env:COMPUTERNAME) {
                    & $scriptBlock $PSBoundParameters
                } else {
                    Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock -ArgumentList $PSBoundParameters
                }
            } catch {
                Write-Error -Message "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
            }
        }
    
    }
function Test-PendingReboot {
        if (Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -EA Ignore) { return $true }
        if (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -EA Ignore) { return $true }
        if (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -EA Ignore) { return $true }
        try { 
            $util = [wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities"
            $status = $util.DetermineIfRebootPending()
            if (($null -ne $status) -and $status.RebootPending) {
                return $true
            }
        }
        catch { }
    
        return $false
    }
Clear-Host
    
    
$CPUS = ""
$RAM = ""
$diskfree = ""
$licensed = ""
$buildnumber = ""
$trp = ""
$Sophos = ""
$Forti = ""
$Defender = ""
$AVInstalled = ""
$exitcode = 0

# CPUs in Cores
$CPUS = wmic cpu get NumberOfCores,NumberOfLogicalProcessors
 
$CPUS = $CPUS[2]
    
$CPUS = $CPUS.Substring(3)
$CPUS = $CPUS.TrimStart()
$CPUS = $CPUS.TrimEnd()
    
    
#RAM in GB
$memory = Get-WMIObject -Class Win32_Computersystem -ErrorAction SilentlyContinue | Select-Object TotalPhysicalMemory
$RAM = [Math]::Round($memory.TotalPhysicalMemory/ 1GB)
    
    
# Diskfree in %
$disk = Get-CimInstance -ClassName Win32_LogicalDisk
$diskfree = [Math]::Round($disk[0].Freespace / $disk[0].Size * 100)
    
# Windows activated?
$licensed = $(Get-ActivationStatus).Status
if($licensed -like "Licensed"){
$licensed = $true}
    
#Buildnumber
$version     = (Get-itemproperty -path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -name CurrentBuildNumber).CurrentBuildNumber
$patchlevel  = (Get-itemproperty -path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -name UBR).UBR
$buildnumber = $version + "." + $patchlevel
    
#Rebbot required?
$trp = Test-PendingReboot
    
#AV installed?
$Sophos   = Get-InstalledSoftware -Name "Sophos Endpoint Agent"
$Forti    = Get-InstalledSoftware -Name "FortiClient"
$Defender = $(Get-MpComputerStatus).AntivirusEnabled
    
if($Sophos -or $Forti -or ($Defender -eq "Running")){
    
$AVInstalled = $True
    
}
$result =  "Compliance check plugin"               + "`r`n"  + "`r`n"
$result += "CPUs (Cores)        : " + $CPUS        + "`r`n"
$result += "RAM (GB)            : " + $RAM         + "`r`n"
$result += "Diskfree (%)        : " + $diskfree    + "`r`n"
$result += "Activated (OS)      : " + $Licensed    + "`r`n"
$result += "Buildnumber (OS)    : " + $buildnumber + "`r`n"
$result += "Reboot Pending (OS) : " + $trp         + "`r`n"
$result += "AntiVirus installed : " + $AVInstalled + "`r`n"
    
    
Write-Host $result

$host.SetShouldExit($exitcode)
exit