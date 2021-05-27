@Echo OFF
IF ## == ##%1 GoTo END
SetLocal EnableExtensions EnableDelayedExpansion
For /F "usebackq tokens=1,2,3 delims=. " %%I In (`date /t`) Do Set STRTDT=%%~K%%~J%%~I
rem ECHO !STRTDT!
IF NOT EXIST %2\%1 MKDIR %2\%1
rem sqlcmd -e -S localhost\SQLEXPRESS -i SQLBackup.sql -v STRTDT=!STRTDT! DBNAME=%1 BCKPATH=%2
sqlcmd -S localhost\SQLEXPRESS -i SQLBackup.sql -v STRTDT=!STRTDT! DBNAME=%1 BCKPATH=%2
PowerShell -NonInteractive -NoProfile "$CN='backup.technical';$P=(Resolve-DnsName -DnsOnly -Name $CN -Type PTR -ErrorAction SilentlyContinue);If ($P -ne $NULL){$CN=$P[-1].NameHost};$rs=Invoke-Command -ComputerName $CN -ConfigurationName SQLAgent -ScriptBlock {&'C:\sqlagent\BackupFileProcessing.ps1' '%1' '%2' '!STRTDT!' '%COMPUTERNAME%'};$host.SetShouldExit($rs)"
:END
