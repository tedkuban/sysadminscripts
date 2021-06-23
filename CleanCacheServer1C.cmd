@Echo OFF
REM powershell -ExecutionPolicy Bypass -File CleanCacheServer1C.ps1 -ServerPath "E:\V8SRVDATA" ProfilePath "C:\Users\server1c" -PFLPath "C:\ProgramData\1C\1cv8" -Pause1 20 -Pause2 5 -RebootHost
REM powershell -ExecutionPolicy Bypass -File CleanCacheServer1C.ps1 -ServerPath "E:\V8SRVDATA" ProfilePath "C:\Users\server1c" -PFLPath "C:\ProgramData\1C\1cv8" -Pause1 20 -Pause2 5 -NoRestart
REM powershell -ExecutionPolicy Bypass -File CleanCacheServer1C.ps1 -ServerPath "E:\V8SRVDATA" ProfilePath "C:\Users\server1c" -PFLPath "C:\ProgramData\1C\1cv8" -Pause1 20 -Pause2 5
powershell -ExecutionPolicy Bypass -File %~dp0CleanCacheServer1C.ps1 -ServerPath "D:\V8SRVDATA" -Pause1 30 -Pause2 5 %*
