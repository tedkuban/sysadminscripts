@Echo OFF
REM powershell -ExecutionPolicy Bypass -File CleanCacheServer1C.ps1 -RebootHost
REM powershell -ExecutionPolicy Bypass -File CleanCacheServer1C.ps1 -NoRestart
REM powershell -ExecutionPolicy Bypass -File CleanCacheServer1C.ps1
powershell -ExecutionPolicy Bypass -File CleanCacheServer1C.ps1 %*
