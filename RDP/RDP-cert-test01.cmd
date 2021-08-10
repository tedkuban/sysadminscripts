wmic /namespace:\\root\cimv2\TerminalServices PATH Win32_TSGeneralSetting Set SSLCertificateSHA1Hash="0cc9e1139fca4f609626902c88459f3f5137aed2"
net stop UmRdpService
net stop TermService
net start TermService
net start UmRdpService



REM wmic /namespace:\\root\cimv2\TerminalServices
REM wmic /namespace:\\root\cimv2\TerminalServices PATH Win32_TSGatewaySetting Get SSLCertificateSHA1Hash="a3a49017b19614ca66cbdcdd95b5e0e7ab0cc22a"

