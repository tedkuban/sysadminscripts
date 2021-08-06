IF #%1# == ## Exit
IF NOT EXIST %1 Exit

rem icacls %1 /remove Everyone
icacls %1 /remove *S-1-1-0
rem icacls %1 /grant Everyone
icacls %1 /grant *S-1-1-0:F

rem icacls %1 /remove BUILTIN\Пользователи
icacls %1 /remove *S-1-5-32-545
rem icacls %1 /remove СОЗДАТЕЛЬ-ВЛАДЕЛЕЦ
icacls %1 /remove *S-1-3-0
