function Make-SystemVolumeCopy
{
<#
    .SYNOPSIS
        Retrieves the history of backup operations on the local or any number of remote computers.

    .DESCRIPTION
        The Get-MyWBSummary cmdlet retrieves the history of backup operations on the local or any number of remote computers with remoting enabled. This information includes backuptime, backuplocation, bersion identifier and recovery information.  
        To use this cmdlet, you must be a member of the Administrators group or Backup Operators group on the local or remote computer, or supply credentials that are.

    .PARAMETER ComputerName
        Retrives backup results on the specified computers. The default is the local computer.
        Type the NetBIOS name, an IP address, or a fully qualified domain name of one or more computers. To specify the local computer ignore the ComputerName parameter.
        This parameter rely on Windows PowerShell remoting, so your computer has to be configured to run remote commands.

    .PARAMETER Credential
        Specifies a user account that has permission to perform this action. The default is the current user. Type a user name, such as "User01", "Domain01\User01", or User@Contoso.com. Or, enter a PSCredential object, such as an object that is returned by the Get-Credential cmdlet. When you type a user name, you are prompted for a password.

    .PARAMETER Last
        Specifies the last (newest/latest) backup versions.

    .EXAMPLE 
        Get-MyWBSummary
        Retrieves all Windows Server backupversions from the local computer

    .EXAMPLE 
        Get-MyWBSummary | Where BackupTime -gt (Get-Date).AddDays(-7)
        Retrieves all Windows Server backupversions from the local computer within the last week    

    .EXAMPLE 
        Get-MyWBSummary -ComputerName $server1, $server2 -Last 1 -Credential $credential -ErrorAction SilentlyContinue -ErrorVariable sessionErrors         
        Retrieves the last (newest) Windows Server Backup backupversion from remote servers $server1 and $server2

    .NOTES
        Written by Fedor Kubanets AKA Teddy (St.-Petersburg, Russia)
        Version 1.0 (2019-11-23)

ѕредположим, у нас делаетс€ регул€рный бэкап по расписанию средствами Windows Backup,
в который входит системный раздел (C:)
“акже у нас на другом диске имеетс€ резервный загрузчик, который указывает по умолчанию на другой том, размер которого равен системному
Ќам необходимо восстановить системный том (C:) в этот резервный системный том, загрузчик при этом продолжит нормально работать, и тогда мы сможем
пережить потерю диска с системным томом

ƒл€ начала получим список всех томов в системе:

PS C:\> Get-WBvolume -AllVolumes


VolumeLabel : DRIVERS
MountPath   : D:
MountPoint  : \\?\Volume{e08eeca3-0000-0000-0000-100000000000}
FileSystem  : NTFS
Property    : ValidSource
FreeSpace   : 1621647360
TotalSpace  : 8489271296

VolumeLabel : srv201-boot
MountPath   :
MountPoint  : \\?\Volume{12ec4a91-0000-0000-0000-100000000000}
FileSystem  : NTFS
Property    : Critical, ValidSource, IsOnDiskWithCriticalVolume
FreeSpace   : 157995008
TotalSpace  : 524288000

VolumeLabel : srv201-boot-bak
MountPath   : H:
MountPoint  : \\?\Volume{7c5d1603-0000-0000-0000-100000000000}
FileSystem  : NTFS
Property    : ValidSource
FreeSpace   : 155246592
TotalSpace  : 524288000

VolumeLabel : srv201 2019_10_18 11:29 DISK_01
MountPath   :
MountPoint  : \\?\Volume{ce46b90d-0cf7-4965-b437-6bd4fd0acbf3}
FileSystem  : NTFS
Property    : ValidSource
FreeSpace   : 1792798126080
TotalSpace  : 2000243744768

VolumeLabel : SRV201-SQLDATA
MountPath   : E:
MountPoint  : \\?\Volume{e08eeca3-0000-0000-0000-10fa01000000}
FileSystem  : NTFS
Property    : ValidSource
FreeSpace   : 928923713536
TotalSpace  : 1099511627776

VolumeLabel : SRV201-SQLBACKUP
MountPath   : F:
MountPoint  : \\?\Volume{e08eeca3-0000-0000-0000-10fa01010000}
FileSystem  : NTFS
Property    : ValidSource
FreeSpace   : 395817451520
TotalSpace  : 450971566080

VolumeLabel : SRV201-SYS
MountPath   : C:
MountPoint  : \\?\Volume{12ec4a91-0000-0000-0000-501f00000000}
FileSystem  : NTFS
Property    : Critical, ValidSource, IsOnDiskWithCriticalVolume
FreeSpace   : 23562350592
TotalSpace  : 107374182400

VolumeLabel : SRV201-SSD
MountPath   : M:
MountPoint  : \\?\Volume{12ec4a91-0000-0000-0000-501f19000000}
FileSystem  : NTFS
Property    : ValidSource, IsOnDiskWithCriticalVolume
FreeSpace   : 354102259712
TotalSpace  : 354334801920

VolumeLabel : SRV201-SYS-BAK
MountPath   :
MountPoint  : \\?\Volume{7c5d1603-0000-0000-0000-501f00000000}
FileSystem  : NTFS
Property    : ValidSource
FreeSpace   : 59389841408
TotalSpace  : 107374182400

VolumeLabel : recovery
MountPath   :
MountPoint  : \\?\Volume{7c5d1603-0000-0000-0000-501f19000000}
FileSystem  : NTFS
Property    : ValidSource
FreeSpace   : 87118712832
TotalSpace  : 107374182400

VolumeLabel : SRV201-BACKUP
MountPath   : G:
MountPoint  : \\?\Volume{7c5d1603-0000-0000-0000-501f32000000}
FileSystem  : NTFS
Property    : ValidSource
FreeSpace   : 1719703568384
TotalSpace  : 1785124093952

Ќас интересуют эти два:

VolumeLabel : SRV201-SYS
MountPath   : C:
MountPoint  : \\?\Volume{12ec4a91-0000-0000-0000-501f00000000}
FileSystem  : NTFS
Property    : Critical, ValidSource, IsOnDiskWithCriticalVolume

VolumeLabel : SRV201-SYS-BAK
MountPath   :
MountPoint  : \\?\Volume{7c5d1603-0000-0000-0000-501f00000000}
FileSystem  : NTFS
Property    : ValidSource

Ќам нужно сформировать такую команду:

Start-WBVolumeRecovery [-BackupSet] <WBBackupSet> [-VolumeInBackup] <WBVolume> [[-RecoveryTargetVolume] <WBVolume>]
     [[-SkipBadClusterCheck]] [[-Async]] [[-Force]] [<CommonParameters>]

ѕолучим последний набор архивации и оба тома (MountPoint придетс€ подставить вручную, так как надежного способа пр€мо в скрипте
выбрать исходный том и том назначени€ € не придумал, и немного страшно затереть основной системный том

$BackupSet = Get-WBBackupSet | Sort-Object BackupTime | Select-Object -Last 1

“ом назначени€ берем из общего списка томов WB, а вот исходный том из набора архивации

$SysVolume = $BackupSet.Volume|where {$_.MountPoint -eq "\\?\Volume{12ec4a91-0000-0000-0000-501f00000000}"}
$TargetVolume = Get-WBVolume -AllVolumes|where {$_.MountPoint -eq "\\?\Volume{7c5d1603-0000-0000-0000-501f00000000}"}

«апомним метку тома назначени€. ƒл€ этого получим том OS (не нашел способа св€зать тома WB и OS напр€мую,
поэтому берем MountPoit и добавл€ем \ (иначе не работает)

$OldLabel = $TargetVolume.VolumeLabel
$TargetOSVolume = Get-Volume -Path ($TargetVolume.MountPoint + "\")
Set-Volume -InputObject $TargetOSVolume -NewFileSystemLabel $OldLabel
 ¬ариант2
Get-Volume -Path ($TargetVolume.MountPoint + "\") | Set-Volume -NewFileSystemLabel $OldLabel

#>

#$BackupVersion = Get-WBBackupSet | Sort-Object BackupTime | Select-Object -Last 1 -ExpandProperty VersionId
#$BackupSet = Get-WBBackupSet | Sort-Object BackupTime | Select-Object -Last 1


$BackupSet = Get-WBBackupSet | Sort-Object BackupTime | Select-Object -Last 1
$SysVolume = $BackupSet.Volume|where {$_.MountPoint -eq "\\?\Volume{fa4638b2-0000-0000-0000-501f00000000}"}

$TargetVolume = Get-WBVolume -AllVolumes|where {$_.MountPoint -eq "\\?\Volume{553bd166-0000-0000-0000-501f00000000}"}
$OldLabel = $TargetVolume.VolumeLabel
$TargetOSVolume = Get-Volume -Path ($TargetVolume.MountPoint + "\")

Get-Volume -Path ($TargetVolume.MountPoint + "\") | fl
Start-WBVolumeRecovery -BackupSet $BackupSet -VolumeInBackup $SysVolume -RecoveryTargetVolume $TargetVolume -Force
#     [[-SkipBadClusterCheck]] [[-Async]] [[-Force]] [<CommonParameters>]
Get-Volume -Path ($TargetVolume.MountPoint + "\") | Set-Volume -NewFileSystemLabel $OldLabel
Get-Volume -Path ($TargetVolume.MountPoint + "\") | fl
}

Make-SystemVolumeCopy
