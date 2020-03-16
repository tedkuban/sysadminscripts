# Prepare Windows 7 for use as server for small service (ex. MultiKey)
# Version 1.00
# 
# Author: Fedor Kubanets, Saint-Petersburg
#
#$ValueName = "Start"
#$Value = "4"

Function Disable-Service ($ServiceName) {
    #$Value = "0x00000004"
    #New-ItemProperty -Path $RegistryPath -Name $ValueName -Value $Value `
    #    -PropertyType DWORD -Force | Out-Null
    $RegistryPath = "HKLM:\System\CurrentControlSet\Services\"+$ServiceName
#    $RegistryPath
    #Set-Service $ServiceName -StartupType Disabled
    Set-ItemProperty -Path $RegistryPath -Name "Start" -Value 4
    If ((Get-Service $ServiceName).Status -NE "Stopped") {
        Stop-Service $ServiceName
    }
    Get-Service $ServiceName|Select Name,Status,StartType
}

Disable-Service -ServiceName "DiagTrack"
Disable-Service -ServiceName "spooler"
Disable-Service -ServiceName "QWAVE"
Disable-Service -ServiceName "Audiosrv"
Disable-Service -ServiceName "WSearch"
Disable-Service -ServiceName "CscService"
Disable-Service -ServiceName "SSDPSRV"
Disable-Service -ServiceName "HomeGroupListener"
Disable-Service -ServiceName "FDResPub"
Disable-Service -ServiceName "LanmanWorkstation"
Disable-Service -ServiceName "LanmanServer"
Disable-Service -ServiceName "WMPNetworkSvc"
Disable-Service -ServiceName "DPS"
Disable-Service -ServiceName "Themes"

# Check the following list !!!
Disable-Service -ServiceName "wscsvc"
Disable-Service -ServiceName "wuauserv"











