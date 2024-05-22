Windows check-plugins der MR-Datentechnik
=========================================

Diese Check-plugins sind von MR entwickelt oder von externen Quellen
übernommen. Sie werden ausschließlich auf Windows-Systemen verwendet
und dort i.d.R. vom Icinga-Agent für Windows gestartet.

Dateien in diesem Verzechnis werden beim Abspielen der ansible-Rolle
"icinga\_satellit" automatisch auf die Satelliten zum Download verteilt.
Die Dateien sind dann unter [http(s)://\<satellit\>/downloads/windowsCheckPlugins/](http(s)://\<satellit\>/downloads/windowsCheckPlugins/) 
zu finden.

Zum Verteilen der Änderungen auf alle Satelliten reicht es, die Rolle für
Icinga-Satelliten zu starten:

```
0:sysop@mgmnt:~$ cd ~/automation/ansible/
0:sysop@mgmnt:~/automation/ansible$ ansible-playbook appNode_icingaSatellite.yaml
```

Powershell mit Icinga
https://community.icinga.com/t/windows-powershell-checks-with-icinga2/712
