###   Icinga Check Script Updater   ###
###   (c) MR-Daten - Charly Kupke   ###
###           Version 1.0           ###
### ### ### ### ### ### ### ### ### ###

### Usage ###

# Execute from Icinga 
# Example: .\update_IcingaChecks.ps1 -satellite 192.168.1.1

param([String[]]$satellite)

$WorkPath = "C:\ProgramData\icinga2"
if (! (Test-Path $WorkPath)) {
    Write-Host "ProgramData\icinga2 Folder doesn't exists"
    $LASTEXITCODE = 2
    ;exit (2)
}


if (-not $satellite) {
    try {
        $icinga_config = Get-Content "C:\ProgramData\icinga2\etc\icinga2\zones.conf"
    }
    catch {
        $icinga_config = $false
    }
    if ($icinga_config) {
        $regex = 'host = "(.*?)"'
        $satellite = [RegEx]::Matches($icinga_config,$regex).groups[1].value
    }
    else {
        Write-Host "No Satellite IP provided and not able to read it from icinga2\zones.conf file"
        $LASTEXITCODE = 2
        ;exit (2)
    }
}
$download_URL = "http://" + $satellite + "/downloads/winCheckPlugins.zip"
$ZipFile = $WorkPath+"/winCheckPlugins.zip"
try {
    Invoke-WebRequest $download_URL -OutFile $ZipFile
}
catch {
    Write-Host "Download failed"
    $LASTEXITCODE = 2
    ;exit (2)
}

$ExtractionPath = $WorkPath + "\bin\MRDaten"

if (!(Test-Path $ExtractionPath)) {
    New-Item -ItemType Directory -Path $ExtractionPath
}
try {
    Expand-Archive -LiteralPath $ZipFile -DestinationPath $ExtractionPath -Force
}
catch {
    Write-Host "Extraction failed"
    $LASTEXITCODE = 2
    ;exit (2)
}
Write-Host "OK"
$LASTEXITCODE = 0
;exit (0)
