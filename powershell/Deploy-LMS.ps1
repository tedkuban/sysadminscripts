#
#
#
$MySwitch = 'VM-SWITCH'

$MyVMName = 'lms-master'
$MyVM = New-VM -Name $MyVMName -MemoryStartupBytes 4GB -NewVHDSizeBytes 30GB -SwitchName $MySwitch -Generation 2 -NewVHDPath ('E:\VHD\'+$MyVMName+'.vhdx')
Add-VMDvdDrive -VM $MyVM -Path 'V:\ISO\ubuntu-18.04.6-live-server-amd64.iso'
Set-VMFirmware -VM $MyVM -BootOrder $(Get-VMDVDDrive -VM $MyVM),  $(Get-VMHardDiskDrive -VM $MyVM) -EnableSecureBoot 'On' -SecureBootTemplate 'MicrosoftUEFICertificateAuthority'
Set-VM -VM $MyVM -ProcessorCount 2
Set-VM -VM $MyVM -AutomaticStopAction Shutdown -AutomaticStartAction Nothing # Nothing, StartIfRunning, and Start.

$MyVMName = 'lms-ingress'
$MyVM = New-VM -Name $MyVMName -MemoryStartupBytes 4GB -NewVHDSizeBytes 30GB -SwitchName $MySwitch -Generation 2 -NewVHDPath ('E:\VHD\'+$MyVMName+'.vhdx')
Add-VMDvdDrive -VM $MyVM -Path 'V:\ISO\ubuntu-18.04.6-live-server-amd64.iso'
Set-VMFirmware -VM $MyVM -BootOrder $(Get-VMDVDDrive -VM $MyVM),  $(Get-VMHardDiskDrive -VM $MyVM) -EnableSecureBoot 'On' -SecureBootTemplate 'MicrosoftUEFICertificateAuthority'
Set-VM -VM $MyVM -ProcessorCount 2
Set-VM -VM $MyVM -AutomaticStopAction Shutdown -AutomaticStartAction Nothing # Nothing, StartIfRunning, and Start.

$MyVMName = 'lms-worker0'
$MyVM = New-VM -Name $MyVMName -MemoryStartupBytes 16GB -NewVHDSizeBytes 50GB -SwitchName $MySwitch -Generation 2 -NewVHDPath ('E:\VHD\'+$MyVMName+'.vhdx')
Add-VMDvdDrive -VM $MyVM -Path 'V:\ISO\ubuntu-18.04.6-live-server-amd64.iso'
Set-VMFirmware -VM $MyVM -BootOrder $(Get-VMDVDDrive -VM $MyVM),  $(Get-VMHardDiskDrive -VM $MyVM) -EnableSecureBoot 'On' -SecureBootTemplate 'MicrosoftUEFICertificateAuthority'
Set-VM -VM $MyVM -ProcessorCount 8
Set-VM -VM $MyVM -AutomaticStopAction Shutdown -AutomaticStartAction Nothing # Nothing, StartIfRunning, and Start.

$MyVMName = 'lms-nfs'
$MyVM = New-VM -Name $MyVMName -MemoryStartupBytes 8GB -NewVHDSizeBytes 150GB -SwitchName $MySwitch -Generation 2 -NewVHDPath ('E:\VHD\'+$MyVMName+'.vhdx')
Add-VMDvdDrive -VM $MyVM -Path 'V:\ISO\ubuntu-18.04.6-live-server-amd64.iso'
Set-VMFirmware -VM $MyVM -BootOrder $(Get-VMDVDDrive -VM $MyVM),  $(Get-VMHardDiskDrive -VM $MyVM) -EnableSecureBoot 'On' -SecureBootTemplate 'MicrosoftUEFICertificateAuthority'
Set-VM -VM $MyVM -ProcessorCount 4
Set-VM -VM $MyVM -AutomaticStopAction Shutdown -AutomaticStartAction Nothing # Nothing, StartIfRunning, and Start.

$MyVMName = 'lms-database'
$MyVM = New-VM -Name $MyVMName -MemoryStartupBytes 8GB -NewVHDSizeBytes 50GB -SwitchName $MySwitch -Generation 2 -NewVHDPath ('E:\VHD\'+$MyVMName+'.vhdx')
Add-VMDvdDrive -VM $MyVM -Path 'V:\ISO\ubuntu-18.04.6-live-server-amd64.iso'
Set-VMFirmware -VM $MyVM -BootOrder $(Get-VMDVDDrive -VM $MyVM),  $(Get-VMHardDiskDrive -VM $MyVM) -EnableSecureBoot 'On' -SecureBootTemplate 'MicrosoftUEFICertificateAuthority'
Set-VM -VM $MyVM -ProcessorCount 4
Set-VM -VM $MyVM -AutomaticStopAction Shutdown -AutomaticStartAction Nothing # Nothing, StartIfRunning, and Start.
