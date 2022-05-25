Windows check-plugins der MR-Datentechnik
=========================================

Diese Check-plugins sind von MR entwickelt oder von externen Quellen
übernommen. Sie werden ausschließlich auf Windows-Systemen verwendet
und dort i.d.R. vom Icinga-Agent für Windows gestartet.

Dateien in diesem Verzechnis werden beim Abspielen der ansible-Rolle
"icinga\_satellit" automatisch auf die Satelliten zum Download verteilt.
Die Dateien sind dann unter [http(s)://\<satellit\>/downloads/windowsCheckPlugins/](http(s)://\<satellit\>/downloads/windowsCheckPlugins/) 
zu finden.

Zum Verteilen der Änderungen auf alle Satelliten sind diese Schritte notwendig:

```
0:sysop@mgmnt:~$ cd ~/check_plugins/srcMR/windows
0:sysop@mgmnt:~/check_plugins/srcMR/windows$ git pull
0:sysop@mgmnt:~/check_plugins/srcMR/windows$ cd ~/ans/
0:sysop@mgmnt:~/ans$ ap pb_satellite.yaml
```
