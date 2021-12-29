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
.Parameter $Pause1
    Specifies the seconds to wait between services are stopped and all processes killed
.Parameter $Pause2
    Specifies the seconds to wait before starting services
.Parameter CleanConnectionProfile
    Also deletes .PFL files, located by default in C:\ProgramData\1C\1cv8
.Parameter RebootHost
    Reboot host machine after all cache files are cleared
.Parameter NoRestart
    Do not start services after cache cleaning
.Example
    CleanCacheServer1C -ServerPath "E:\V8SRVDATA" -RebootHost
.Component
    1C:Enterprise v8
.Notes
    Version: 0.9
    Date modified: 2021.06.22
    Autor: Fedor Kubanets AKA Teddy
    Company: HappyLook
#>
[CmdletBinding(DefaultParameterSetName="All")]
Param(
#  [Parameter(Mandatory=$True,Position=1)]
  [Parameter(Position=1,Mandatory=$False)] [string]$ServerPath = "E:\V8SRVDATA",
  [Parameter(Position=2,Mandatory=$False)] [string]$ProfilePath = "C:\Users\server1c",
  [Parameter(Position=3,Mandatory=$False)] [string]$PFLPath = "C:\ProgramData\1C\1cv8",
  [Parameter(Mandatory=$False)] [int]$Pause1 = 20,
  [Parameter(Mandatory=$False)] [int]$Pause2 = 5,
  [Parameter()] [switch]$CleanConnectionProfile,
  [Parameter()] [switch]$RebootHost,
  [Parameter()] [switch]$NoRestart
)

function Start-Sleep($seconds) {
    $doneDT = (Get-Date).AddSeconds($seconds)
    while($doneDT -gt (Get-Date)) {
        $secondsLeft = $doneDT.Subtract((Get-Date)).TotalSeconds
        $percent = ($seconds - $secondsLeft) / $seconds * 100
        Write-Progress -Activity "Sleeping" -Status "Sleeping..." -SecondsRemaining $secondsLeft -PercentComplete $percent
        [System.Threading.Thread]::Sleep(500)
    }
    Write-Progress -Activity "Sleeping" -Status "Sleeping..." -SecondsRemaining 0 -Completed
}

$ErrorActionPreference = "SilentlyContinue"

$NameService1C = "1C:Enterprise 8.3 Server Agent (x86-64)"
$NameServiceRAS = "1C:Enterprise 8.3 Remote Server (x86-64)"

Get-Service -Name $NameServiceRAS | Stop-Service
Get-Service -Name $NameService1C | Stop-Service

Start-Sleep $Pause1

Get-Process | Where { $_.Name -eq "ras" } | Stop-Process -Force
Get-Process | Where { $_.Name -eq "rphost" } | Stop-Process -Force
Get-Process | Where { $_.Name -eq "rmngr" } | Stop-Process -Force
Get-Process | Where { $_.Name -eq "ragent" } | Stop-Process -Force
$StillRunning = 0
$StillRunning = $StillRunning + (Get-Process | Where { $_.Name -eq "ras" }).Count
$StillRunning = $StillRunning + (Get-Process | Where { $_.Name -eq "rphost" }).Count
$StillRunning = $StillRunning + (Get-Process | Where { $_.Name -eq "rmngr" }).Count
$StillRunning = $StillRunning + (Get-Process | Where { $_.Name -eq "ragent" }).Count

If ( $StillRunning -gt 0 ) {
  Get-Process | Where { $_.Name -eq "ras" }
  Get-Process | Where { $_.Name -eq "rphost" }
  Get-Process | Where { $_.Name -eq "rmngr" }
  Get-Process | Where { $_.Name -eq "ragent" }
  Write-Host "Cannot stop all 1C processes!"
} Else {
  Write-Host "Deleting GUID database folders..."
  Get-Item "$ProfilePath\AppData\Local\1C\1Cv8\*","$ProfilePath\AppData\Roaming\1C\1Cv8\*" | Where {$_.Name -as [guid]} | Remove-Item -Force -Recurse
  Write-Host "Deleting TEMP folders..."
  Get-Item "$ProfilePath\AppData\Local\Temp\*" | Remove-Item -Force -Recurse
  If ( $CleanConnectionProfile ) {
    Write-Host "Deleting .pfl files..."
    Get-Item "$PFLPath\*.pfl" | Remove-Item -Force -Recurse
  }
  Write-Host "Deleting reg_* GUID folders..."
  Get-Item "$ServerPath\reg_*\*" | Where PSIsContainer | Where {$_.Name -as [guid]} | Foreach-Object {
    Get-ChildItem -Path $_ | Where { !$_.PSIsContainer } | Remove-Item -Force
  }
  Write-Host "Deleting session temporary data..."
  Get-Item "$ServerPath\reg_*\*" | Where PSIsContainer | Where {$_.Name -match "^snccntx"} | Where {$_.Name.Replace("snccntx","") -as [guid]} | Foreach-Object {
  #    Get-ChildItem -Path $_ | Where { !$_.PSIsContainer } | Remove-Item -Force
    Get-ChildItem -Path $_ | Remove-Item -Force
  }
}

If ($RebootHost) {
  Write-Host "Rebooting..."
  #shutdown -r -t 0
  #Restart-Computer
  Restart-Computer -Force -Confirm:$False
  #Exit
}

If (!$NoRestart) {
  Start-Sleep $Pause2
  Write-Host "Starting services..."
  Get-Service -Name $NameService1C | Start-Service
  Get-Service -Name $NameServiceRAS | Start-Service
}
