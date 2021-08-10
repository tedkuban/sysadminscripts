
$obj = gwmi -namespace "Root/CIMV2/TerminalServices" Win32_TerminalServiceSetting
#$obj.ChangeMode(2) # Per device
$obj.ChangeMode(4) # Per user

$obj.SetSpecifiedLicenseServerList("localhost")
$obj.GetSpecifiedLicenseServerList()
