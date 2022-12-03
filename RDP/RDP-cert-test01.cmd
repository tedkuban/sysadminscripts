REM This problem can be solved by assigning the certificate via PowerShell. With the following command you can assign the certificate:
REM
REM    $path = (Get-WmiObject "Win32_TSGeneralSetting" -ComputerName "<RDS Server Name>" -Namespace root\cimv2\terminalservices -Filter "TerminalName='RDP-tcp'").__path Set-WmiInstance -Path $path -argument @{SSLCertificateSHA1Hash="<Thumbprint>"}
REM
REM Adjust the values between <>.
REM 
REM Pay attention: The certificate must be installed in the Personal folder in the MMC.
REM
REM 
REM If the command fails, you can also assign the certificate via the command line. For this you use the command:
REM 
REM     wmic /namespace:\\root\cimv2\TerminalServices PATH Win32_TSGeneralSetting Set SSLCertificateSHA1Hash="<THUMBPRINT>"
REM 
REM
wmic /namespace:\\root\cimv2\TerminalServices PATH Win32_TSGeneralSetting Set SSLCertificateSHA1Hash="0cc9e1139fca4f609626902c88459f3f5137aed2"
net stop UmRdpService
net stop TermService
net start TermService
net start UmRdpService

REM wmic /namespace:\\root\cimv2\TerminalServices
REM wmic /namespace:\\root\cimv2\TerminalServices PATH Win32_TSGatewaySetting Get SSLCertificateSHA1Hash="a3a49017b19614ca66cbdcdd95b5e0e7ab0cc22a"

