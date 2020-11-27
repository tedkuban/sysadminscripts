# Prepare Windows Server 2016,2019 for the first use (mayby, also in Windows 10)
# Version 1.08
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

# Disable unnesessary services

$NameSalt = (Get-Service|Where Name -like "CDPUserSvc_*").Name.split("_")[1]

#$AffectedServices = "CDPUserSvc","OneSyncSvc","PimIndexMaintenanceSvc","UnistoreSvc","UserDataSvc","WpnUserService"

Get-Service|Where Name -like "*_$NameSalt"|Foreach-Object {
    $ServiceName = $_.Name.split("_")[0]
    Disable-Service -ServiceName $ServiceName
    Disable-Service -ServiceName $_.Name
}
#Get-Service|Where Name -like "*_$NameSalt"

Disable-Service -ServiceName "lfsvc"
Disable-Service -ServiceName "MapsBroker"

# Check the following list !!!
Disable-Service -ServiceName "spooler"
Disable-Service -ServiceName "WPDBusEnum"
Disable-Service -ServiceName "DiagTrack"
Disable-Service -ServiceName "dmwappushservice"

# Disable IPv6
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" -Name "DisabledComponents" -Value 0xFFFFFFFF

# Disable User Accout Control
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 0

# Disable Error Reporting
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" -Name "Disabled" -Value 1

# Set telemetry policy
# Values: -1 - Unknown; 0 - Security; 1 - Base level; 2 - Mid level; 3 - Full
#
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Value 0
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "DoNotShowFeedbackNotifications" -Value 1

# Disable Cortana
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Value 0

# Disable Microsoft tech support
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\ScriptedDiagnosticsProvider" -ErrorAction SilentlyContinue
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\ScriptedDiagnosticsProvider\Policy" -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\ScriptedDiagnosticsProvider\Policy" -Name "DisableQueryRemoteServer" -Value 0
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WDI" -ErrorAction SilentlyContinue
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WDI\{C295FBBA-FD47-46ac-8BEE-B1715EC634E5}" -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WDI\{C295FBBA-FD47-46ac-8BEE-B1715EC634E5}" -Name "ScenarioExecutionEnabled" -Value 0
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WDI\{C295FBBA-FD47-46ac-8BEE-B1715EC634E5}" -Name "DownloadToolsEnabled" -Value 0
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WDI\{C295FBBA-FD47-46ac-8BEE-B1715EC634E5}" -Name "DownloadToolsLevel" -ErrorAction SilentlyContinue

New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS

# Disable feedback requests
New-Item -Path "HKCU:\SOFTWARE\Microsoft\Siuf" -ErrorAction SilentlyContinue
Remove-Item -Path "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" -ErrorAction SilentlyContinue
New-Item -Path "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" -Name "NumberOfSIUFInPeriod" -Value 0
New-Item -Path "HKU:\.DEFAULT\SOFTWARE\Microsoft\Siuf" -ErrorAction SilentlyContinue
Remove-Item -Path "HKU:\.DEFAULT\SOFTWARE\Microsoft\Siuf\Rules" -ErrorAction SilentlyContinue
New-Item -Path "HKU:\.DEFAULT\SOFTWARE\Microsoft\Siuf\Rules" -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKU:\.DEFAULT\SOFTWARE\Microsoft\Siuf\Rules" -Name "NumberOfSIUFInPeriod" -Value 0

<#
# Setup keyboard (English first and Ctrl-Shift toggle)
Set-ItemProperty -Path "HKCU:\Keyboard Layout\Preload" -Name "1" -Value "00000409"
Set-ItemProperty -Path "HKCU:\Keyboard Layout\Preload" -Name "2" -Value "00000419"
Set-ItemProperty -Path "HKCU:\Keyboard Layout\Toggle" -Name "Hotkey" -Value "2"
Set-ItemProperty -Path "HKCU:\Keyboard Layout\Toggle" -Name "Language Hotkey" -Value "2"
Set-ItemProperty -Path "HKCU:\Keyboard Layout\Toggle" -Name "Layout Hotkey" -Value "1"
New-Item -Path "HKLM:\SYSTEM\Keyboard Layout\Preload" -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKLM:\SYSTEM\Keyboard Layout\Preload" -Name "1" -Value "00000409"
Set-ItemProperty -Path "HKLM:\SYSTEM\Keyboard Layout\Preload" -Name "2" -Value "00000419"
New-Item -Path "HKLM:\SYSTEM\Keyboard Layout\Toggle" -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKLM:\SYSTEM\Keyboard Layout\Toggle" -Name "Hotkey" -Value "2"
Set-ItemProperty -Path "HKLM:\SYSTEM\Keyboard Layout\Toggle" -Name "Language Hotkey" -Value "2"
Set-ItemProperty -Path "HKLM:\SYSTEM\Keyboard Layout\Toggle" -Name "Layout Hotkey" -Value "1"
Set-ItemProperty -Path "HKU:\.DEFAULT\Keyboard Layout\Preload" -Name "1" -Value "00000409"
Set-ItemProperty -Path "HKU:\.DEFAULT\Keyboard Layout\Preload" -Name "2" -Value "00000419"
Set-ItemProperty -Path "HKU:\.DEFAULT\Keyboard Layout\Toggle" -Name "Hotkey" -Value "2"
Set-ItemProperty -Path "HKU:\.DEFAULT\Keyboard Layout\Toggle" -Name "Language Hotkey" -Value "2"
Set-ItemProperty -Path "HKU:\.DEFAULT\Keyboard Layout\Toggle" -Name "Layout Hotkey" -Value "1"
#>

<#
Reg load "HKU\DefUser" "C:\Users\Default\NTUSER.DAT"
# Настройка клавиатуры для новых пользователей
Reg add "HKU\DefUser\Keyboard Layout\Preload" /v 1 /t REG_SZ /d 00000409 /f
Reg add "HKU\DefUser\Keyboard Layout\Preload" /v 2 /t REG_SZ /d 00000419 /f
Reg add "HKU\DefUser\Keyboard Layout\Toggle" /v "Hotkey" /t REG_SZ /d "2" /f
Reg add "HKU\DefUser\Keyboard Layout\Toggle" /v "Language Hotkey" /t REG_SZ /d "2" /f
Reg add "HKU\DefUser\Keyboard Layout\Toggle" /v "Layout Hotkey" /t REG_SZ /d "1" /f
#Set-ItemProperty -Path "HKU:\DefUser\Keyboard Layout\Preload" -Name "1" -Value "00000409"
#Set-ItemProperty -Path "HKU:\DefUser\Keyboard Layout\Preload" -Name "2" -Value "00000419"
#Set-ItemProperty -Path "HKU:\DefUser\Keyboard Layout\Toggle" -Name "Hotkey" -Value "2"
#Set-ItemProperty -Path "HKU:\DefUser\Keyboard Layout\Toggle" -Name "Language Hotkey" -Value "2"
#Set-ItemProperty -Path "HKU:\DefUser\Keyboard Layout\Toggle" -Name "Layout Hotkey" -Value "1"
Reg add "HKU\DefUser\Control Panel\Colors" /v "Background" /t REG_SZ /d "45 125 154" /f
Reg add "HKU\DefUser\Control Panel\Desktop" /v "WallPaper" /t REG_SZ /d "" /f
Reg unload "HKU\DefUser"
#>

# Set "High Performance" power plan
### !! $FullPower = Get-CimInstance -Name root\cimv2\power -Class win32_PowerPlan -Filter "InstanceID = 'Microsoft:PowerPlan\\{8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c}'"
### !! Invoke-CimMethod -InputObject $FullPower -MethodName Activate
powercfg /S 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

# Solve RDP keyboard layout bug
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout" -Name "IgnoreRemoteKeyboardLayout" -Value 1


# Detecting hardware or virtual platform
# $ComputerModel = (Get-CimInstance -ClassName CIM_ComputerSystem).Model
IF ( (Get-CimInstance -ClassName CIM_ComputerSystem).Model -ne "Virtual Machine" ) {
  Write-Host "Trying to install Windows Server Backup and Hyper-V"
  IF ( (Get-WindowsFeature Windows-Server-Backup).InstallState -ne "Installed" ) {
    Install-WindowsFeature -Name Windows-Server-Backup -IncludeManagementTools
  }
  IF ( (Get-WindowsFeature Hyper-V).InstallState -ne "Installed" ) {
    Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Restart
  }
} else {
  Write-Host "Do not try to instal Windows Server Backup and Hyper-V on virtual machine"
}
