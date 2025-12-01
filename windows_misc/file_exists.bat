@echo off
set file=%1
IF EXIST "%file%" (
   ECHO OK: %file% exists
   exit /b 0
) ELSE (
   ECHO CRITICAL: %file% does not exist
   exit /b 2
)
