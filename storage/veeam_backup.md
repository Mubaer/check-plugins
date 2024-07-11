# Veeam Backup and Replication - Backup Status via REST API

## Veeam API Reference
https://helpcenter.veeam.com/docs/backup/vbr_rest/rest_api_reference.html?ver=120

## Voraussetzungen
pip3 install requests

## Aufruf Checks 

### Backup Check
python3 main.py --check backup --host 'localhost' --username 'username' --password 'password'

### Job added/removed Check
python3 main.py --check jobs --host 'localhost' --username 'username' --password 'password'

