IF #%1# == ## Exit
IF NOT EXIST %1 Exit
rem icacls %1 /remove BUILTIN\Пользователи
icacls %1 /remove *S-1-5-32-545
rem icacls %1 /remove СОЗДАТЕЛЬ-ВЛАДЕЛЕЦ
icacls %1 /remove *S-1-3-0

MD %1\MSSQL

icacls %1\MSSQL /grant "NT SERVICE\MSSQLSERVER":(OI)(CI)F
icacls %1\MSSQL /grant "NT SERVICE\SQLSERVERAGENT":(OI)(CI)M
