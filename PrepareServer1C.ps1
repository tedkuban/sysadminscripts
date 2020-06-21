# Prepare Server 1C
# Version 1.00
# 
# Author: Fedor Kubanets, Saint-Petersburg
#
#$ValueName = "Start"
#$Value = "4"

# Set TCP/IP dynamic ports
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "MaxUserPort"
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "MaxFreeTcbs"
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TcpTimedWaitDelay"
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "StrictTimeWaitSeqCheck"

Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "MaxUserPort" -Value 65534
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "MaxFreeTcbs" -Value 100000
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TcpTimedWaitDelay" -Value 30
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "StrictTimeWaitSeqCheck" -Value 1

netsh int ipv4 set dynamicport tcp start=10000 num=54510
netsh int ipv4 set dynamicport udp start=10000 num=54510
netsh int ipv6 set dynamicport tcp start=10000 num=54510
netsh int ipv6 set dynamicport udp start=10000 num=54510
