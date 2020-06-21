<#
.Synopsis
    Erase files in 1C Server cache and session data storage
.Description
    Erase files in 1C Server cache and session data storage
.Parameter ServerPath
    Specifies the 1C Server storage folder
.Parameter ProfilePath
    Specifies the path to profile of user running 1C Server
.Parameter $PFLPath
    Specifies the path to folder where 1C Server store .PFL files
.Parameter RebootHost
    Reboot host machine after cleaning all cache files
.Parameter NoRestart
    Do not start services after cache cleaning
.Example
    CleanCacheServer1C -ServerPath "D:\V8SRVDATA" -RebootHost
.Component
    1C:Enterprise v8
.Notes
    Version: 0.1
    Date modified: 2019.11.20
    Autor: Fedor Kubanets AKA Teddy
    Company: HappyLook
#>
[CmdletBinding(DefaultParameterSetName="All")]
Param(
#  [Parameter(Mandatory=$True,Position=1)]
  [Parameter(Position=1,Mandatory=$False)] [string]$ServerPath = "E:\V8SRVDATA",
  [Parameter(Position=2,Mandatory=$False)] [string]$ProfilePath = "C:\Users\server1c",
  [Parameter(Position=2,Mandatory=$False)] [string]$PFLPath = "C:\ProgramData\1C\1cv8",
  [Parameter()] [switch]$RebootHost,
  [Parameter()] [switch]$NoRestart
)

$ErrorActionPreference = "SilentlyContinue"

Get-Service -Name "1C:Enterprise 8.3 Remote Server" | Stop-Service
Get-Service -Name "1C:Enterprise 8.3 Server Agent (x86-64)" | Stop-Service

Get-Process | Where { $_.Name -eq "ras" } | Stop-Process -Force
Get-Process | Where { $_.Name -eq "rphost" } | Stop-Process -Force
Get-Process | Where { $_.Name -eq "rmngr" } | Stop-Process -Force
Get-Process | Where { $_.Name -eq "ragent" } | Stop-Process -Force

Start-Sleep 66

Write-Host "Deleting GUID database folders..."
Get-Item "$ProfilePath\AppData\Local\1C\1Cv8\*","$ProfilePath\AppData\Roaming\1C\1Cv8\*" | Where {$_.Name -as [guid]} | Remove-Item -Force -Recurse
Write-Host "Deleting TEMP folders..."
Get-Item "$ProfilePath\AppData\Local\Temp\*" | Remove-Item -Force -Recurse
Write-Host "Deleting .pfl files..."
Get-Item "$PFLPath\*.pfl" | Remove-Item -Force -Recurse
Write-Host "Deleting reg_* GUID folders..."
Get-Item "$ServerPath\reg_*\*" | Where PSIsContainer | Where {$_.Name -as [guid]} | Foreach-Object {
    Get-ChildItem -Path $_ | Where { !$_.PSIsContainer } | Remove-Item -Force
}
Write-Host "Deleting session temporary data..."
Get-Item "$ServerPath\reg_*\*" | Where PSIsContainer | Where {$_.Name -match "^snccntx"} | Where {$_.Name.Replace("snccntx","") -as [guid]} | Foreach-Object {
#    Get-ChildItem -Path $_ | Where { !$_.PSIsContainer } | Remove-Item -Force
    Get-ChildItem -Path $_ | Remove-Item -Force
}

If ($RebootHost) {
  Write-Host "Rebooting..."
  #shutdown -r -t 0
  #Restart-Computer
  Restart-Computer -Confirm:$False
  #Exit
}

If (!$NoRestart) {
  Write-Host "Starting services..."
  Start-Sleep 30
  Get-Service -Name "1C:Enterprise 8.3 Server Agent (x86-64)" | Start-Service
  Get-Service -Name "1C:Enterprise 8.3 Remote Server" | Start-Service
}
