<#
.Synopsis
    Get and parse one http page for zabbix
.Description
    Get and parse one http page for zabbix
.Parameter uri
    Specifies the page address
.Example
    ZabbixGetSiteResponse -uri "https://test.happylook.local/CV/ghwq/iamalive"
.Component
    Zabbix Monitoring
.Notes
    Version: 0.1
    Date modified: 2020.02.19
    Autor: Fedor Kubanets AKA Teddy
    Company: HappyLook
#>
[CmdletBinding(DefaultParameterSetName="All")]
Param(
#  [Parameter(Mandatory=$True,Position=1)]
  [Parameter(Position=1,Mandatory=$True)] [string]$uri
,  [Parameter(Position=2,Mandatory=$True)] [string]$user
,  [Parameter(Position=3,Mandatory=$True)] [string]$pass
)

$ErrorActionPreference = "SilentlyContinue"
# При любых ошибках возвращаем 10 секунд - заведомо больше любого приемлемого таймаута
$Status = 10
# Другое значение установим только при получении от сервиса кода 200, и установим время получения запроса

#$user = "username"
#$pass= "password"
$secpasswd = ConvertTo-SecureString $pass -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential($user, $secpasswd)

#$response = Invoke-WebRequest -Uri $uri -Method Get -ContentType "text/json; charset=utf-8" -TimeoutSec 3 -DisableKeepAlive

$watch = [System.Diagnostics.Stopwatch]::StartNew()
$response = Invoke-WebRequest -Uri $uri -Method Get -ContentType "text/json; charset=utf-8" -TimeoutSec 3 -DisableKeepAlive -Credential $Credential
$watch.Stop()

Write-Host ("Status = " + $response.StatusCode)
Write-Host ("Content = " + $response.Content)
Write-Host ("JSON.Code = " + ($response.Content|ConvertFrom-JSON).Code)
Write-Host ("Response time = " + $watch.ElapsedMilliseconds/1000 + "s")

If ( [int]$response.StatusCode -eq 200 ) {
  $Status = $watch.ElapsedMilliseconds/1000
}
$Status
