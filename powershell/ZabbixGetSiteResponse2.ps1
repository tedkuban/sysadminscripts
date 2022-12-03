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
$GlobalStatus=0
$(
#    Here is your current script

#Start-Transcript -Path "C:\zabbix\ZabbixGetSiteResponse.log" -Append -IncludeInvocationHeader -Encoding UTF8

Write-Host ""
Get-Date -Format s | Write-Host
Write-Host ""

$CultureENUS = New-Object System.Globalization.CultureInfo("en-US")
Write-Verbose $uri
Write-Verbose $user
Write-Verbose $pass

# ѕри любых ошибках возвращаем 10 секунд - заведомо больше любого приемлемого таймаута
# ƒругое значение установим только при получении от сервиса кода 200, и установим врем€ получени€ запроса
$Status = 10

$secpasswd = ConvertTo-SecureString $pass -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential($user, $secpasswd)

#$response = Invoke-WebRequest -Uri $uri -Method Get -ContentType "text/json; charset=utf-8" -TimeoutSec 3 -DisableKeepAlive

$watch = [System.Diagnostics.Stopwatch]::StartNew()
#$response = Invoke-WebRequest -Uri ("https://"+$uri) -Method Get -ContentType "text/json; charset=utf-8" -TimeoutSec 3 -DisableKeepAlive -Credential $Credential
$ResponseCode = -1
#Write-Host $ResponseCode
try
{
    $Response = Invoke-WebRequest -Uri $uri -Method Get -ContentType "text/json; charset=utf-8" -TimeoutSec 5 -DisableKeepAlive -Credential $Credential -UseBasicParsing
    # This will only execute if the Invoke-WebRequest is successful.
    $ResponseCode = $Response.StatusCode
    Write-Host ("Success code: " + $ResponseCode)
}
catch
{
    Write-Host "Exception during web request invocation!"
    Write-Host $_.Exception.Message
    Write-Host ("HResult: " + $_.Exception.HResult)
    $ResponseCode = $_.Exception.HResult
    If ($_.Exception.Response) {
      #Write-Host ("HResult: " + $_.Exception.HResult)
      $ResponseCode = $_.Exception.Response.StatusCode.value__
    }
    Write-Host ("Exception code: " + $ResponseCode)
}
$watch.Stop()
$ResponseTime = $watch.ElapsedMilliseconds/1000

Write-Host ("Response code = " + $ResponseCode)
Write-Host ("Content = " + $response.Content)
Write-Host ("JSON.Code = " + ($response.Content|ConvertFrom-JSON).Code)
Write-Host ("Response time = " + $ResponseTime + "s")

#If ( [int]$response.StatusCode -eq 200 ) {
If ( $ResponseCode -eq 200 ) {
  $Status = $ResponseTime
}
$GlobalStatus = $Status.toString("0.000", $CultureENUS)
Write-Host ("Returned value = "+$GlobalStatus)
##) *>&1 >> "C:\zabbix\ZabbixGetSiteResponse.log"
) *>&1 | Out-File -Append -Encoding UTF8 "C:\zabbix\ZabbixGetSiteResponse.log"
$GlobalStatus
$(
$LogFile = Get-Item -Path "C:\zabbix\ZabbixGetSiteResponse.log" -ErrorAction SilentlyContinue
If ($LogFile) {
  If ($LogFile.length -gt 1Mb) {
    Remove-Item  -Force -Path "C:\zabbix\ZabbixGetSiteResponse0.log"
    Rename-Item  -Force -Path $LogFile -NewName "ZabbixGetSiteResponse0.log"
  }
}
) *>&1 | Out-Null
#) *>&1
