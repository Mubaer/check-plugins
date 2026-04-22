$version = "1.1.8" # added sync status
$LASTEXITCODE = 0
$warning = 0
$Port = 8530
$wsusserver = "localhost"

[void][reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")
$wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer($wsusserver,$False,$Port)
$CompSc = new-object Microsoft.UpdateServices.Administration.ComputerTargetScope
$updateScope = new-object Microsoft.UpdateServices.Administration.UpdateScope; 
$updateScope.UpdateApprovalActions = [Microsoft.UpdateServices.Administration.UpdateApprovalActions]::All

$report = @()
$treffer = 0
$i = 0
$output2016 = "Current"
$output2019 = "Current"
$output2022 = "Current"
$output2025 = "Current"

$request = Invoke-WebRequest "https://support.microsoft.com/en-gb/help/4000825" –UseBasicParsing
If ($request.StatusCode -eq 200) {
    $BuildNumber = [regex]::Matches($request.Content, 'href="([a-z0-9-\/]*)">([a-zA-Z]*) ([0-9]{1,2}), ([0-9]{4}).*?(KB[0-9]*) \(OS Build 14393.([0-9]*)\)(?: ([a-zA-Z-]*)<\/a>)?')
    if ($BuildNumber.Count -gt 0) {
 
        while ($treffer -eq 0 )
        {
        if ($buildnumber[$i].Groups[7].value -notlike "Out-of-Band") {
        $CurrentServer2016Raw = [PSCustomObject]@{
            'OS Name'      = "Windows Server 2016"
            'OS Version'   = "14393"
            'OS build'     = $BuildNumber[$i].Groups[6].Value
            'KB'           = $BuildNumber[$i].Groups[5].Value
            'Title'        = ""
            
            
        }
        $treffer = 1
            
        }
        $i++
        }

        while ($treffer -eq 1 )
        {
        if ($buildnumber[$i].Groups[7].value -notlike "Out-of-Band") {
        $LastServer2016Raw = [PSCustomObject]@{
            'OS Name'      = "Windows Server 2016"
            'OS Version'   = "14393"
            'OS build'     = $BuildNumber[$i].Groups[6].Value
            'KB'           = $BuildNumber[$i].Groups[5].Value
            'Title'        = ""
            
            
        }
        $treffer = 2
            
        }
        $i++
        }

    }
}
        $kb = $CurrentServer2016Raw.KB
        $updates = $wsus.GetUpdates($updateScope) | Where-Object{$_.Title -match $kb} #Getting every update where the title matches the $kbnumber
        if (-not $updates){$kb = $lastServer2016Raw.KB; $updates = $wsus.GetUpdates($updateScope) | Where-Object{$_.Title -match $kb};$output2016 = "Last"} #Getting every update where the title matches the $kbnumber}
          ForEach($update in $updates){ #Loop against the list of updates I stored in $updates in the previous step
          $update.GetUpdateInstallationInfoPerComputerTarget($CompSc) |  ForEach-Object {
          $Comp = $wsus.GetComputerTarget($_.ComputerTargetId)# using #Computer object ID to retrieve the computer object properties (Name, #IP address)
          $info = "" | Select-Object ICStatus, InstallationStatus, UpdateTitle, Computername, OS ,IpAddress,  UpdateApprovalAction
          $info.InstallationStatus = $_.UpdateInstallationState
          
          if($info.InstallationStatus -like "Installed"){
          $info.InstallationStatus = "Installed"
          $info.ICStatus = "(OK)"
          
          }elseif($info.InstallationStatus -like "Failed"){
          $info.InstallationStatus = "Failed"
          $info.ICStatus = "(CRITICAL)"
          $LASTEXITCODE = 2
          
          }elseif($info.InstallationStatus -like "InstalledPendingReboot"){
          $info.InstallationStatus = "     PendingReboot" + "      `t"
          $info.UpdateTitle = "`t" + $info.UpdateTitle
          $info.ICStatus = "(WARNING)"
          $warning = 1          
          
          }elseif($info.InstallationStatus -like "NotApplicable"){
          $info.InstallationStatus = "     NotApplicable" + "      `t"
          $info.UpdateTitle = "`t" + $info.UpdateTitle
          $info.ICStatus = "(UNKNOWN)"
          
          }elseif($info.InstallationStatus -like "NotInstalled"){
          $info.InstallationStatus = "     NotInstalled" + "      `t"
          $info.UpdateTitle = "`t" + $info.UpdateTitle
          $info.ICStatus = "(WARNING)"
          $warning = 1
          
          }elseif($info.InstallationStatus -like "Downloaded"){
          $info.InstallationStatus = "     Downloaded"
          $info.ICStatus = "(OK)"

          }elseif($info.InstallationStatus -like "Unknown"){
          $info.InstallationStatus = "     Unknown    " + "      `t"
          $info.ICStatus = "(UNKNOWN)"
          }        
          
          $info.UpdateTitle = $kb
          #$info.LegacyName = $update.LegacyName
          #$info.SecurityBulletins = ($update.SecurityBulletins -join ';')
          $info.Computername = "`t" + $Comp.FullDomainName
          $info.OS = "`t" + $Comp.OSDescription
          $info.IpAddress = "`t" + $Comp.IPAddress
          $info.UpdateApprovalAction = $_.UpdateApprovalAction
          if ($info.OS -match "Windows Server 2016"){
          $report+=$info # Storing the information into the $report variable 
          }
        }
     }

$treffer = 0
$i = 0
     $request = Invoke-WebRequest "https://support.microsoft.com/en-gb/help/4464619" –UseBasicParsing
If ($request.StatusCode -eq 200) {
       $BuildNumber = [regex]::Matches($request.Content, 'href="([a-z0-9-\/]*)">([a-zA-Z]*) ([0-9]{1,2}), ([0-9]{4}).*?(KB[0-9]*) \(OS Build 17763.([0-9]*)\)(?: ([a-zA-Z-]*)<\/a>)?')
    if ($BuildNumber.Count -gt 0) {
 
        while ($treffer -eq 0 )
        {
        if ($buildnumber[$i].Groups[7].value -notlike "Out-of-Band") {
        $CurrentServer2019Raw = [PSCustomObject]@{
            'OS Name'      = "Windows Server 2019"
            'OS Version'   = "17763"
            'OS build'     = $BuildNumber[$i].Groups[6].Value
            'KB'           = $BuildNumber[$i].Groups[5].Value
            'Title'        = ""
            
            
        }
        $treffer = 1
            
        }
        $i++
        }

        while ($treffer -eq 1 )
        {
        if ($buildnumber[$i].Groups[7].value -notlike "Out-of-Band") {
        $LastServer2019Raw = [PSCustomObject]@{
            'OS Name'      = "Windows Server 2019"
            'OS Version'   = "17763"
            'OS build'     = $BuildNumber[$i].Groups[6].Value
            'KB'           = $BuildNumber[$i].Groups[5].Value
            'Title'        = ""
            
            
        }
        $treffer = 2
            
        }
        $i++
        }

    }
}
        $kb = $CurrentServer2019Raw.KB
        $updates = $wsus.GetUpdates($updateScope) | Where-Object{$_.Title -match $kb} #Getting every update where the title matches the $kbnumber
        if (-not $updates){$kb = $lastServer2019Raw.KB; $updates = $wsus.GetUpdates($updateScope) | Where-Object{$_.Title -match $kb};$output2019 = "Last"} #Getting every update where the title matches the $kbnumber}
          ForEach($update in $updates){ #Loop against the list of updates I stored in $updates in the previous step
          $update.GetUpdateInstallationInfoPerComputerTarget($CompSc) |  ForEach-Object {
          $Comp = $wsus.GetComputerTarget($_.ComputerTargetId)# using #Computer object ID to retrieve the computer object properties (Name, #IP address)
          $info = "" | Select-Object ICStatus, InstallationStatus, UpdateTitle, Computername, OS ,IpAddress,  UpdateApprovalAction
          $info.InstallationStatus = $_.UpdateInstallationState
          
          if($info.InstallationStatus -like "Installed"){
          $info.InstallationStatus = "Installed"
          $info.ICStatus = "(OK)"
          
          }elseif($info.InstallationStatus -like "Failed"){
          $info.InstallationStatus = "Failed"
          $info.ICStatus = "(CRITICAL)"
          $LASTEXITCODE = 2
          
          }elseif($info.InstallationStatus -like "InstalledPendingReboot"){
          $info.InstallationStatus = "     PendingReboot" + "      `t"
          $info.UpdateTitle = "`t" + $info.UpdateTitle
          $info.ICStatus = "(WARNING)"
          $warning = 1          
          
          }elseif($info.InstallationStatus -like "NotApplicable"){
          $info.InstallationStatus = "     NotApplicable" + "      `t"
          $info.UpdateTitle = "`t" + $info.UpdateTitle
          $info.ICStatus = "(UNKNOWN)"

          }elseif($info.InstallationStatus -like "NotInstalled"){
          $info.InstallationStatus = "     NotInstalled" + "      `t"
          $info.UpdateTitle = "`t" + $info.UpdateTitle
          $info.ICStatus = "(WARNING)"
          $warning = 1
          
          }elseif($info.InstallationStatus -like "Downloaded"){
          $info.InstallationStatus = "Downloaded"
          $info.ICStatus = "(OK)"

          }elseif($info.InstallationStatus -like "Unknown"){
          $info.InstallationStatus = "     Unknown    " + "      `t"
          $info.ICStatus = "(UNKNOWN)"
          }        
          
          $info.UpdateTitle = $kb
          #$info.LegacyName = $update.LegacyName
          #$info.SecurityBulletins = ($update.SecurityBulletins -join ';')
          $info.Computername = "`t" + $Comp.FullDomainName
          $info.OS = "`t" + $Comp.OSDescription
          $info.IpAddress = "`t" + $Comp.IPAddress
          $info.UpdateApprovalAction = $_.UpdateApprovalAction
          if ($info.OS -match "Windows Server 2019"){
          $report+=$info # Storing the information into the $report variable 
          }
        }
     }

    
$treffer = 0
$i = 0
     $request = Invoke-WebRequest "https://support.microsoft.com/en-gb/help/5020032" –UseBasicParsing
If ($request.StatusCode -eq 200) {
    $BuildNumber = [regex]::Matches($request.Content, 'href="([a-z0-9-\/]*)">([a-zA-Z]*) ([0-9]{1,2}), ([0-9]{4}).*?(KB[0-9]*) \(OS Build 20348.([0-9]*)\)(?: ([a-zA-Z-]*)<\/a>)?')
    if ($BuildNumber.Count -gt 0) {
 
        while ($treffer -eq 0 )
        {
        if ($buildnumber[$i].Groups[7].value -notlike "Out-of-Band") {
        $CurrentServer2022Raw = [PSCustomObject]@{
            'OS Name'      = "Windows Server 2022"
            'OS Version'   = "20348"
            'OS build'     = $BuildNumber[$i].Groups[6].Value
            'KB'           = $BuildNumber[$i].Groups[5].Value
            'Title'        = ""
            
            
        }
        $treffer = 1
            
        }
        $i++
        }

        while ($treffer -eq 1 )
        {
        if ($buildnumber[$i].Groups[7].value -notlike "Out-of-Band") {
        $LastServer2022Raw = [PSCustomObject]@{
            'OS Name'      = "Windows Server 2022"
            'OS Version'   = "20348"
            'OS build'     = $BuildNumber[$i].Groups[6].Value
            'KB'           = $BuildNumber[$i].Groups[5].Value
            'Title'        = ""
            
            
        }
        $treffer = 2
            
        }
        $i++
        }

    }
}
        $kb = $CurrentServer2022Raw.KB
        $updates = $wsus.GetUpdates($updateScope) | Where-Object{$_.Title -match $kb} #Getting every update where the title matches the $kbnumber
        if (-not $updates){$kb = $lastServer2022Raw.KB; $updates = $wsus.GetUpdates($updateScope) | Where-Object{$_.Title -match $kb};$output2022 = "Last"} #Getting every update where the title matches the $kbnumber}
          ForEach($update in $updates){ #Loop against the list of updates I stored in $updates in the previous step
          $update.GetUpdateInstallationInfoPerComputerTarget($CompSc) |  ForEach-Object {
          $Comp = $wsus.GetComputerTarget($_.ComputerTargetId)# using #Computer object ID to retrieve the computer object properties (Name, #IP address)
          $info = "" | Select-Object ICStatus, InstallationStatus, UpdateTitle, Computername, OS ,IpAddress,  UpdateApprovalAction
          $info.InstallationStatus = $_.UpdateInstallationState
          
          if($info.InstallationStatus -like "Installed"){
          $info.InstallationStatus = "Installed"
          $info.ICStatus = "(OK)"
          
          }elseif($info.InstallationStatus -like "Failed"){
          $info.InstallationStatus = "Failed"
          $info.ICStatus = "(CRITICAL)"
          $LASTEXITCODE = 2
          
          }elseif($info.InstallationStatus -like "InstalledPendingReboot"){
          $info.InstallationStatus = "     PendingReboot" + "      `t"
          $info.UpdateTitle = "`t" + $info.UpdateTitle
          $info.ICStatus = "(WARNING)"
          $warning = 1          
          
          }elseif($info.InstallationStatus -like "NotApplicable"){
          $info.InstallationStatus = "     NotApplicable" + "      `t"
          $info.UpdateTitle = "`t" + $info.UpdateTitle
          $info.ICStatus = "(UNKNOWN)"

          
          }elseif($info.InstallationStatus -like "NotInstalled"){
          $info.InstallationStatus = "     NotInstalled" + "      `t"
          $info.UpdateTitle = "`t" + $info.UpdateTitle
          $info.ICStatus = "(WARNING)"
          $warning = 1
                    
          }elseif($info.InstallationStatus -like "Downloaded"){
          $info.InstallationStatus = "Downloaded"
          $info.ICStatus = "(OK)"

          }elseif($info.InstallationStatus -like "Unknown"){
          $info.InstallationStatus = "     Unknown    " + "      `t"
          $info.ICStatus = "(UNKNOWN)"
          }        

          $info.UpdateTitle = $kb
          #$info.LegacyName = $update.LegacyName
          #$info.SecurityBulletins = ($update.SecurityBulletins -join ';')
          $info.Computername = "`t" + $Comp.FullDomainName
          $info.OS = "`t" + $Comp.OSDescription
          $info.IpAddress = "`t" + $Comp.IPAddress
          $info.UpdateApprovalAction = $_.UpdateApprovalAction
          if ($info.OS -match "Windows Server 2022"){
          $report+=$info # Storing the information into the $report variable 
          }
        }
     }


$treffer = 0
$i = 0
     $request = Invoke-WebRequest "https://support.microsoft.com/en-gb/help/5047442" –UseBasicParsing
If ($request.StatusCode -eq 200) {
    $BuildNumber = [regex]::Matches($request.Content, 'href="([a-z0-9-\/]*)">([a-zA-Z]*) ([0-9]{1,2}), ([0-9]{4}).*?(KB[0-9]*)\(OS Build 26100.([0-9]*)\)(?: ([a-zA-Z-]*)<\/a>)?')
    if ($BuildNumber.Count -gt 0) {
 
        while ($treffer -eq 0 )
        {
        if ($buildnumber[$i].Groups[7].value -notlike "Out-of-Band") {
        $CurrentServer2025Raw = [PSCustomObject]@{
            'OS Name'      = "Windows Server 2025"
            'OS Version'   = "26100"
            'OS build'     = $BuildNumber[$i].Groups[6].Value
            'KB'           = $BuildNumber[$i].Groups[5].Value
            'Title'        = ""
            
            
        }
        $treffer = 1
            
        }
        $i++
        }

        while ($treffer -eq 1 )
        {
        if ($buildnumber[$i].Groups[7].value -notlike "Out-of-Band") {
        $LastServer2025Raw = [PSCustomObject]@{
            'OS Name'      = "Windows Server 2025"
            'OS Version'   = "26100"
            'OS build'     = $BuildNumber[$i].Groups[6].Value
            'KB'           = $BuildNumber[$i].Groups[5].Value
            'Title'        = ""
            
            
        }
        $treffer = 2
            
        }
        $i++
        }

    }
}
        $kb = $CurrentServer2025Raw.KB
        $updates = $wsus.GetUpdates($updateScope) | Where-Object{$_.Title -match $kb} #Getting every update where the title matches the $kbnumber
        if (-not $updates){$kb = $lastServer2025Raw.KB; $updates = $wsus.GetUpdates($updateScope) | Where-Object{$_.Title -match $kb};$output2025 = "Last"} #Getting every update where the title matches the $kbnumber}
          ForEach($update in $updates){ #Loop against the list of updates I stored in $updates in the previous step
          $update.GetUpdateInstallationInfoPerComputerTarget($CompSc) |  ForEach-Object {
          $Comp = $wsus.GetComputerTarget($_.ComputerTargetId)# using #Computer object ID to retrieve the computer object properties (Name, #IP address)
          $info = "" | Select-Object ICStatus, InstallationStatus, UpdateTitle, Computername, OS ,IpAddress,  UpdateApprovalAction
          $info.InstallationStatus = $_.UpdateInstallationState
          
          if($info.InstallationStatus -like "Installed"){
          $info.InstallationStatus = "Installed"
          $info.ICStatus = "(OK)"
          
          }elseif($info.InstallationStatus -like "Failed"){
          $info.InstallationStatus = "Failed"
          $info.ICStatus = "(CRITICAL)"
          $LASTEXITCODE = 2
          
          }elseif($info.InstallationStatus -like "InstalledPendingReboot"){
          $info.InstallationStatus = "     PendingReboot" + "      `t"
          $info.UpdateTitle = "`t" + $info.UpdateTitle
          $info.ICStatus = "(WARNING)"
          $warning = 1          
          
          }elseif($info.InstallationStatus -like "NotApplicable"){
          $info.InstallationStatus = "     NotApplicable" + "      `t"
          $info.UpdateTitle = "`t" + $info.UpdateTitle
          $info.ICStatus = "(UNKNOWN)"
          
          }elseif($info.InstallationStatus -like "NotInstalled"){
          $info.InstallationStatus = "     NotInstalled" + "      `t"
          $info.UpdateTitle = "`t" + $info.UpdateTitle
          $info.ICStatus = "(WARNING)"
          $warning = 1
                    
          }elseif($info.InstallationStatus -like "Downloaded"){
          $info.InstallationStatus = "Downloaded"
          $info.ICStatus = "(OK)"

          }elseif($info.InstallationStatus -like "Unknown"){
          $info.InstallationStatus = "     Unknown    " + "      `t"
          $info.ICStatus = "(UNKNOWN)"
          }        
          
          $info.UpdateTitle = $kb
          #$info.LegacyName = $update.LegacyName
          #$info.SecurityBulletins = ($update.SecurityBulletins -join ';')
          $info.Computername = "`t" + $Comp.FullDomainName
          $info.OS = "`t" + $Comp.OSDescription
          $info.IpAddress = "`t" + $Comp.IPAddress
          $info.UpdateApprovalAction = $_.UpdateApprovalAction
          if ($info.OS -match "Windows Server 2025"){
          $report+=$info # Storing the information into the $report variable 
          }
        }
     }

$CurrentServer2016Raw.Title = $($wsus.SearchUpdates($CurrentServer2016Raw.KB)).title
$CurrentServer2019Raw.Title = $($wsus.SearchUpdates($CurrentServer2019Raw.KB)).title
$CurrentServer2022Raw.Title = $($wsus.SearchUpdates($CurrentServer2022Raw.KB)).title
$CurrentServer2025Raw.Title = $($wsus.SearchUpdates($CurrentServer2025Raw.KB)).title
$LastServer2016Raw.Title = $($wsus.SearchUpdates($LastServer2016Raw.KB)).title
$LastServer2019Raw.Title = $($wsus.SearchUpdates($LastServer2019Raw.KB)).title
$LastServer2022Raw.Title = $($wsus.SearchUpdates($LastServer2022Raw.KB)).title
$LastServer2025Raw.Title = $($wsus.SearchUpdates($LastServer2025Raw.KB)).title

if($warning -eq 0 -and $LASTEXITCODE -eq 0){
$result = "(OK) Overall Status"
}

if ($warning -eq 1 -and $LASTEXITCODE -eq 0){
$result = "(WARNING) Overall Status"
$LASTEXITCODE = 1
}

if($LASTEXITCODE -eq 2){
$result = "(CRITICAL) Overall Status"
}


Write-host $result

$reportend = ($report | ft -HideTableHeaders | Out-String -Width 9999 -Stream) -replace "`r`n","`n"
$reportend

$sub = $wsus.GetSubscription()
$lastSyncInfo = $($sub.GetLastSynchronizationInfo()).Result
if($lastSyncInfo -like "Succeeded"){
$lastSyncInfo = "Succeeded " + "(OK)" 
}else{
$lastSyncInfo = "Warning " + "(WARNING)"
}
$lastSyncStart = $($($sub.GetLastSynchronizationInfo()).StartTime).ToString("dd.MM.yyyy HH:mm:ss")

Write-host "Last Sync date/time: " $lastSyncStart
Write-host "Last Sync status   : " $lastSyncInfo
Write-host
Write-host


if($output2016 -like "Current"){

Write-host "OS Name :" $CurrentServer2016Raw.'OS Name'
Write-host "OS Build:" $CurrentServer2016Raw.'OS Version'"."$CurrentServer2016Raw.'OS build'
Write-host "KB      :" $CurrentServer2016Raw.KB
Write-host "Title   :" $CurrentServer2016Raw.Title
Write-host
}else{
Write-host "OS Name :" $LastServer2016Raw.'OS Name'
Write-host "OS Build:" $LastServer2016Raw.'OS Version'"."$LastServer2016Raw.'OS build'
Write-host "KB      :" $LastServer2016Raw.KB
Write-host "Title   :" $LastServer2016Raw.Title
Write-host
}

if($output2019 -like "Current"){

Write-host "OS Name :" $CurrentServer2019Raw.'OS Name'
Write-host "OS Build:" $CurrentServer2019Raw.'OS Version'"."$CurrentServer2019Raw.'OS build'
Write-host "KB      :" $CurrentServer2019Raw.KB
Write-host "Title   :" $CurrentServer2019Raw.Title
Write-host
}else{
Write-host "OS Name :" $LastServer2019Raw.'OS Name'
Write-host "OS Build:" $LastServer2019Raw.'OS Version'"."$LastServer2019Raw.'OS build'
Write-host "KB      :" $LastServer2019Raw.KB
Write-host "Title   :" $LastServer2019Raw.Title
Write-host
}

if($output2022 -like "Current"){

Write-host "OS Name :" $CurrentServer2022Raw.'OS Name'
Write-host "OS Build:" $CurrentServer2022Raw.'OS Version'"."$CurrentServer2022Raw.'OS build'
Write-host "KB      :" $CurrentServer2022Raw.KB
Write-host "Title   :" $CurrentServer2022Raw.Title
Write-host
}else{
Write-host "OS Name :" $LastServer2022Raw.'OS Name'
Write-host "OS Build:" $LastServer2022Raw.'OS Version'"."$LastServer2022Raw.'OS build'
Write-host "KB      :" $LastServer2022Raw.KB
Write-host "Title   :" $LastServer2022Raw.Title
Write-host
}

if($output2025 -like "Current"){

Write-host "OS Name :" $CurrentServer2025Raw.'OS Name'
Write-host "OS Build:" $CurrentServer2025Raw.'OS Version'"."$CurrentServer2025Raw.'OS build'
Write-host "KB      :" $CurrentServer2025Raw.KB
Write-host "Title   :" $CurrentServer2025Raw.Title
Write-host
}else{
Write-host "OS Name :" $LastServer2025Raw.'OS Name'
Write-host "OS Build:" $LastServer2025Raw.'OS Version'"."$LastServer2025Raw.'OS build'
Write-host "KB      :" $LastServer2025Raw.KB
Write-host "Title   :" $LastServer2025Raw.Title
Write-host
}

Write-host "Check-version: " $version
;exit ($LASTEXITCODE)