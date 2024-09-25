$activeConfig = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication\DatabaseConfigurations' -Name 'SqlActiveConfiguration').SqlActiveConfiguration
if ($activeConfig -eq "MsSql") {
    $sqlServerName = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication\DatabaseConfigurations\MsSql' -Name 'SqlServerName').SqlServerName
    $sqlInstanceName = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication\DatabaseConfigurations\MsSql' -Name 'SqlInstanceName').SqlInstanceName
    $sqlDatabaseName = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication\DatabaseConfigurations\MsSql' -Name 'SqlDatabaseName').SqlDatabaseName
    Write-Host " Database Engine: $($activeConfig) "
    Write-Output "Connection Settings: $($sqlServerName)\$($sqlInstanceName)"
    Write-Output "Database Name: $($sqlDatabaseName)"
    } elseif ($activeConfig -eq "PostgreSql") {
    $pgServerName = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication\DatabaseConfigurations\PostgreSql' -Name 'SqlHostName').SqlHostName
    $pgPortNumber = (Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication\DatabaseConfigurations\PostgreSql' -Name 'SqlHostPort')
    $pgDatabaseName = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication\DatabaseConfigurations\PostgreSql' -Name 'SqlDatabaseName').SqlDatabaseName
    $pgUser = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication\DatabaseConfigurations\PostgreSql' -Name 'PostgresUserForWindowsAuth').PostgresUserForWindowsAuth
    Write-Host "Database Engine: $($activeConfig)"
    Write-Output "Connection Settings: $($pgServerName):$($pgPortNumber)"
    Write-Output "Database Name: $($pgDatabaseName)"
    Write-Output "PostgreSQL User: $($pgUser)"
}

https://www.veeam.com/kb1471
https://search.brave.com/search?q=conect+sql+express+powershell&source=desktop&summary=1&summary_og=be9e996c8ba5d51bc2be07
