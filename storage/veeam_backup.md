# Veeam Backup and Replication - Backup Status via REST API

## Veeam API Reference
https://helpcenter.veeam.com/docs/backup/vbr_rest/rest_api_reference.html?ver=120

## Voraussetzungen
pip3 install requests

## Aufruf Checks 

### Backup Check
python3 veeam_backup.py --check backup --host 'localhost' --username 'username' --password 'password'

### Job added/removed Check
python3 veeam_backup.py --check jobs --host 'localhost' --username 'username' --password 'password'

### Veeam Version Check
python3 veeam_backup.py --check version --host 'localhost' --username 'username' --password 'password'

### Repository Check
python3 veeam_backup.py --check repository --host 'localhost' --username 'username' --password 'password'


# Versionsstand
09/24
REST API Version 1.1-rev2 (Veeam 12.2.0.334)

## Not supported:

### check: backup
CustomPlatform (Backup Copy Job)
WindowsPhysical (Windows Agent Backup)

### general
Veeam License
