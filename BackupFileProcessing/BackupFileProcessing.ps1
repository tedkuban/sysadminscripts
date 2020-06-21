<#
.Synopsis
    Скрипт для раскладывания бэкапов БД SQL по схеме дед-отец-сын
.Component
    MS SQL Server
.Notes
    Version: 1.1
    Date modified: 2020.06.21
    Autor: Fedor Kubanets AKA Teddy
    Company: HappyLook
.Description
    Этот скрипт запускается из задания SQL Agent Job после выполнения резервного копирования
    SQL-Server делает бэкап, затем вызывает удаленное выполнение данного скрипта на сервере
    долговременного хранения. На этом сервере желательно запретить службу Server совсем для
    дополнительной защиты от шифраторов и прочей дряни.
    На сервере долговременного хранения необходимо выполнить команду powershell
        Set-PSSessionConfiguration Microsoft.PowerShell -ShowSecurityDescriptorUI
    и разрешить удаленное выполнение команд пользователю, от имени которого выполняется
    агент SQL Server

    Скрипт запускается и забирает файл с SQL-сервера себе, используя только клиент сетей Microsoft
    Получив в параметрах имя базы данных, находит папку для ее копий, ищет там файл настроек
    Пока в настройках предполагается три параметра - количество хранимых копий в каждой из трех папок

    Первым шагом задания на сервере SQL будет скрипт создания бэкапа в файл с определенным именем (пример ниже):
	DECLARE @DBName sysname = 'TESTDB'
	DECLARE @BackupPath nvarchar(128) = N'\\SERVER1\Backup'
	DECLARE @StartTime varchar(10) = SUBSTRING('$(ESCAPE_SQUOTE(STRTDT))',1,4) + '.' + SUBSTRING('$(ESCAPE_SQUOTE(STRTDT))',5,2) + '.' + SUBSTRING('$(ESCAPE_SQUOTE(STRTDT))',7,2)
	DECLARE @FileName nvarchar(256) = @BackupPath+'\'+@DBName+'\'+@DBName+'_'+@StartTime+'.bak'
	DECLARE @Descr nvarchar(256) = @DBName + ' Full Database Backup ' + @StartTime
	BACKUP DATABASE @DBName TO DISK = @FileName WITH NOFORMAT, NOINIT,  NAME = @Descr, SKIP, NOREWIND, NOUNLOAD, COMPRESSION

    Вторым шагом выполняется данный скрипт
        ##PowerShell -NonInteractive -NoProfile "Invoke-Command -ComputerName SERVER2 -ScriptBlock { D:\sqlagent\BackupFileProcessing.ps1 'TESTDB' '\\SERVER1\Backup' '$(ESCAPE_SQUOTE(STRTDT))' '$(ESCAPE_SQUOTE(MACH))' }"
        ##PowerShell -NonInteractive -NoProfile "$rs=Invoke-Command -ComputerName SERVER2 -ScriptBlock {&'D:\sqlagent\BackupFileProcessing.ps1' 'TESTDB' '\\SERVER1\Backup' '$(ESCAPE_SQUOTE(STRTDT))' '$(ESCAPE_SQUOTE(MACH))'};$Anchor='#Exit#Code#: ';$et=($rs|Where-Object {$_ -match ('\A'+$Anchor)}|Select-Object -Last 1);If($Null -eq $et){'Error: Unexpected output returned from remote host!";$ex=99}else{$ex=[int]($et.Replace($Anchor,''))};$rs|Foreach-Object{$_};$host.SetShouldExit($ex)"
        PowerShell -NonInteractive -NoProfile "$rs=Invoke-Command -ComputerName SERVER2 -ScriptBlock {&'D:\sqlagent\BackupFileProcessing.ps1' 'TESTDB' '\\SERVER1\Backup' '$(ESCAPE_SQUOTE(STRTDT))' '$(ESCAPE_SQUOTE(MACH))'};$host.SetShouldExit($rs)"

    Первый и второй параметры скрипта должны совпадать с первым и вторым параметрами кода T-SQL (@DBName и @BackupPath)

    Настройка глубины хранения находится в каталоге каждой базы данных в файле .settings.json. Настройки по умолчанию выглядят так:
        {
            "Level1Copies":  10,
            "Level2Copies":  5,
            "Level3Copies":  11,
            "Level1FolderName":  "__day",
            "Level2FolderName":  "_week",
            "Level3FolderName":  "month",
            "Level2Match":  "Days",
            "Level2Days":  "1,9,17,25",
            "Level3Day":  1
        }
    При каждом вызове скрипта имя компьютера, его вызвавшего, записывается в каталог базы данных в файл .lastsource
.Parameter DatabaseName
    Имя базы данных
.Parameter RemoteStoragePath
    Откуда брать бэкап
.Parameter JobStartDate
    Дата начала задания на сервере SQL (использум только ее, так как старт и финиш бэкапа могут быть в разных сутках,
    а нам нужно найти определенный файл, и дата модификации файла нам не подходит)
    На будущее - можно доработать, убрав вообще дату, пусть обрабатываются все файлы в каталоге первичного сервера,
    еще и задать параметр, сколько файлов там оставлять
.Parameter $ComputerName
    Имя вызывающего компьютера (пока не знаю, как его получить изнутри скрипта)
.Parameter Override
    Use settings from command line rather then stored in .settings.json file
.Parameter SaveSettings
    Save new or default parameters in .settings.json file
.Parameter Level1Copies
    Сколько копий хранить в каталоге первого уровня
.Parameter Level1FolderName
    Имя каталога первого уровня (по умолчанию __day)
.Parameter Level2Copies
    Сколько копий хранить в каталоге второго уровня
.Parameter Level2FolderName
    Имя каталога второго уровня (по умолчанию _week)
.Parameter Level2Match
    По какой методике переносить файлы в каталог второго уровня
    Варианты - "Days" или "DayOfWeek"
.Parameter Level2Days
    Если Level2Match установлено в DayOfWeek, здесь пишем день недели, в который храним недельные копии ( 0 - воскресенье, 6 - суббота )
    Если Level2Match установлено в Days, здесь пишем список чисел месяцадень недели, в который храним недельные копии ( 0 - воскресенье, 6 - суббота )
    Варианты - "Days" или "DayOfWeek"
.Parameter Level3Copies
    Сколько копий хранить в каталоге третьего уровня
.Parameter Level3FolderName
    Имя каталога третьего уровня (по умолчанию month)
.Parameter Level3Day
    Здесь пишем число месяца, на которое храним месячные копии
    Если Level2Match установлено в DayOfWeek, возможен вариант, что файл попадет сразу в третий уровень хранения, минуя второй
    Так что здесь может появиться еще вариант для третьего уровня, например, если второй уровень пишем каждую среду, то третий уровень - каждую 5-ю среду, например
.Example
    PowerShell .\BackupFileProcessing.ps1 'TESTDB' '\\backup01.technical\SQLBACKUP\' '20200512' SRV001 -Level1Copies 0 -Level2Copies 0 -Level3Copies 0
       - Скопировать файл бэкапа базы TESTDB, не оставляя никаких дополнительных копий
    PowerShell .\BackupFileProcessing.ps1 UT '\\backup01.technical\SQLBACKUP\' 20200612 SRV001
       - Скопировать файл бэкапа базы UT, взяв параметры из настроек каталога, 
    PowerShell .\BackupFileProcessing.ps1 'ESB' -Level1Copies 8 -Level2Copies 5 -Level3Copies 5 -SaveSettings
       - Записать новые параметры глубины хранения в каталог базы данных ESB и выйти
#>
[CmdletBinding(DefaultParameterSetName="All")]
Param(
#  [Parameter(Mandatory=$True,Position=1)]
  [Parameter(Position=1,Mandatory=$False)] [string]$DatabaseName
  ,[Parameter(Position=2,Mandatory=$False)] [string]$RemoteStoragePath
  ,[Parameter(Position=3,Mandatory=$False)] [string]$JobStartDate
  ,[Parameter(Position=4,Mandatory=$False)] [string]$ComputerName
  ,[Parameter(Mandatory=$False)] [int]$Level1Copies = 10
  ,[Parameter(Mandatory=$False)] [int]$Level2Copies = 5
  ,[Parameter(Mandatory=$False)] [int]$Level3Copies = 11
  ,[Parameter(Mandatory=$False)] [string]$LocalStoragePath = "E:\SQLBACKUP"
  ,[Parameter(Mandatory=$False)] [switch]$Override = $false
  ,[Parameter(Mandatory=$False)] [switch]$SaveSettings = $false
  ,[Parameter(Mandatory=$False)] [string]$Level1FolderName = '__day'
  ,[Parameter(Mandatory=$False)] [string]$Level2FolderName = '_week'
  ,[Parameter(Mandatory=$False)] [string]$Level3FolderName = 'month'
  ,[Parameter(Mandatory=$False)] [string]$Level2Match = 'Days' # ['Days'|'DayOfWeek'] - сохраняем второй уровень либо в определенный день недели, либо по определенным числам месяца
  ,[Parameter(Mandatory=$False)] [string]$Level2Days = '1,9,17,25' # 
  #,[Parameter(Mandatory=$False)] [string]$Level2Days = 0 # Воскресенье
  ,[Parameter(Mandatory=$False)] [string]$Level3Day = 1 # 1-го числа каждого месяца
)

function Exit-WithCode
{
  param ( $exitcode )
  ## !ВАЖНО! Строка ниже является якорем, по которому мы получим код возврата
  ## в Invoke-Command, так как при удаленном выполнении скрипта возвращается
  ## только текстовый вывод, больше ничего.
  #Write-Output ('#Exit#Code#: ' + $exitcode)
  Write-Output ($exitcode)
  $host.SetShouldExit($exitcode)
  exit $exitcode
}

Function Write-Log {
  Param( [Parameter(Mandatory=$false, ValueFromPipeline=$true)] [String[]] $OutString = "`r`n" )
  Write-Host $OutString
  Try {  # Если нет возможности записать лог - вылетаем с ошибкой
    $OutString | Out-File -Append -FilePath ($script:LocalStorage.FullName+'\BackupFileProcessing.log')
  }
  Catch {
    Write-Host ("Error: Cannot write to log file - exiting!")
    Write-Host ("Error: " + $Error[0].ToString() )
    Exit-WithCode 3
  }
}

Function Get-EndpointByDNS {
  Param(
  #  [Parameter(Mandatory=$True,Position=1)]
    [Parameter(Position=1,Mandatory=$True)] [string]$NameToResolve
  )

$NameToResolve
  Try {
    #$AddressList = Resolve-DnsName -Name $NameToResolve
    $AddressList = ( Resolve-DnsName -Name $NameToResolve | Where-Object { $_.Type -in ('A','AAAA') } )
  } Catch {
    $AddressList = @()
  }
  If ( $AddressList.Count -eq 0 ) { Return $False }

  $NamesList = @()
  $AddressList | Foreach-Object { 
    Try {
      Resolve-DnsName -Name $_.IPAddress -Type 'PTR' | Where-Object { $_.Type -in ('PTR') } | Foreach-Object { $NamesList += $_.NameHost }
    } Catch {
      $NamesList = @()
    }
  }
  If ( $NamesList.Count -eq 0 ) {
    Return $False
  } Else {
    Return $NamesList[0]
  }
}

Function Get-FileDate {
  Param( [Parameter(Mandatory=$True,ValueFromPipeline=$True)] [Object] $File )
  # Удалим расширение (.bak) и будем считать, что дата в указанном формате содержится в конце имени
  $FileDateString = ($File.Name).Substring($File.Name.Length-($script:DateFormat.Length+('.bak').Length),$script:DateFormat.Length)
  $FileDate = Get-Date
  # Разберем дату архива вычислим год, месяц, день и день недели этой даты
    #[DateTime]::TryParseExact( $StartDate, $DateFormat, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref] $FileDate )
  If ( $FileDate::TryParseExact( $FileDateString, $script:DateFormat, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref] $FileDate ) ) {
    $FileDayOfWeek = [int]$FileDate.DayOfWeek # 0-Sunday ... 6-Saturday
    $FileYear = [int]$FileDate.Year
    $FileMonth = [int]$FileDate.Month
    $FileDay = [int]$FileDate.Day
    #Write-Log ( "Info: Got date parts from file `"" + $File.Name + "`" - Year $FileYear, Month $FileMonth, Day $FileDay, DoW $FileDayOfWeek")
    Return $FileDate
  } Else {
    Write-Log ( 'Warning: Cannot get backup date from filename "' + $File.Name + '"!')
    Return $False
  }
}

# Условие для уровня 2 - определенный день недели, переданный в параметрах скрипта или каталога базы данных
# Условие для уровня 2 - определенные дни месяца, переданные в параметрах скрипта или каталога базы данных
Function Level2Condition {
  Param( [Parameter(Mandatory=$True,ValueFromPipeline=$True)] [Object] $File )
  $FileDate = Get-FileDate ( $File )
  $Match = $False
  If ( $FileDate ) {
    If ( $script:Level2Match -match "\ADays\z" ) {
      Try { $L2Days = ( $script:Level2Days -split ',' ) } Catch { Write-Log 'Warning: Level 2 days is empty of misformatted!'; $L2Days = @() }
      Return ( $L2Days -contains $FileDate.Day )
      #$Match = ( $L2Days -contains $FileDate.Day )
    } ElseIf ( $script:Level2Match -match "\ADayOfWeek\z" ) {
      Return ( [int]$FileDate.DayOfWeek -eq $script:Level2Days )
      #$Match = ( [int]$FileDate.DayOfWeek -eq $script:Level2Days )
    } Else {
      Write-Log ( 'Warning: Unknown level 2 condition type given!')
    }
  }
  #If ( $Match ) {
  #  Write-Log ( 'Info: File "' + $File.Name + '" matches the condition of level 2')
  #} Else {
  #  Write-Log ( 'Info: File "' + $File.Name + '" does not match the condition of level 2')
  #} 
  Return $Match
}

# Условие для уровня 3 - определенное число месяца, переданное в параметрах скрипта или каталога базы данных
Function Level3Condition {
  Param( [Parameter(Mandatory=$True,ValueFromPipeline=$True)] [Object] $File )
  $FileDate = Get-FileDate ( $File )
  If ( $FileDate ) { 
    Return ( $FileDate.Day -eq $script:Level3Day )
    #If ( $FileDate.Day -eq $script:Level3Day ) {
    #  Write-Log ( 'Info: File "' + $File.Name + '" matches the condition of level 3')
    #  Return $True
    #} Else {
    #  Write-Log ( 'Info: File "' + $File.Name + '" does not match the condition of level 3')
    #  Return $False
    #}
  } Else {
    Return $False
  }
}

##
##
## MAIN PROCEDURE
##
$ErrorActionPreference = "Stop"
#$VerbosePreference = "continue"
#$ErrorActionPreference = "SilentlyContinue"

#
# I want receive all messages in English
#
$currentThread = [System.Threading.Thread]::CurrentThread
$culture = [System.Globalization.CultureInfo]::InvariantCulture
$currentThread.CurrentCulture = $culture
$currentThread.CurrentUICulture = $culture


$DateFormat = 'yyyy.MM.dd'
$DateMask = '\d{4}.\d\d.\d\d'
#$DateFormat = 'yyyyMMdd'
#$DateMask = '\d{8}'


# Проверим путь локального хранилища - если он доступен, будем писать туда лог
# 
Try {
  $LocalStorage = Get-Item -Path $LocalStoragePath
  If ( ! $LocalStorage.PSISContainer ) {
    Write-Host ("Error: Local storage is not a directory!")
    Exit-WithCode 1
  }
}
Catch {
  Write-Host ("Error: Local storage directory not found or no access!")
  Write-Host ("Error: " + $Error[0].ToString())
  Exit-WithCode 2
}
Write-Log ''
Write-Log ('Info: Starting ' + (Get-Date -Format "yyyy.MM.dd HH:mm") )
#Write-Log ('Info: Processing local storage "' + $LocalStorage.FullName + '"')

# Manipulating parameters
#Write-Log ('Info: Parameters given:')
#Write-Log ('Info: Database name:       '+ $DatabaseName )
#Write-Log ('Info: Remote storage path: '+ $RemoteStoragePath )
#Write-Log ('Info: Job start date:      '+ $JobStartDate )
#Write-Log ('Info: Computer name:       '+ $ComputerName )
#Write-Log ('Info: Local storage path:  '+ $LocalStorage.FullName )
#Write-Log ('Info: Level 1 copies:      '+ [int]$Level1Copies )
#Write-Log ('Info: Level 2 copies:      '+ [int]$Level2Copies )
#Write-Log ('Info: Level 3 copies:      '+ [int]$Level3Copies )

# Проверим локальный каталог базы данных, потом поработаем с настройками, а потом проверим остальные обязательные параметры
If ( ! $DatabaseName ) { 
  Write-Log 'Error: No database name given!'
  Write-Log 'Usage: Get-Help <this script filename>'
  Exit-WithCode 4
}

# Проверим каталог базы данных, при отсутствии - создадим его
Try {
  $DatabaseDirectory = $LocalStorage.CreateSubdirectory($DatabaseName)
  $DatabaseDirectoryName = $DatabaseDirectory.FullName.ToString()
  Write-Log ('Info: Processing local directory "' + $DatabaseDirectoryName + '"')
}
Catch {
  Write-Log ("Error: Cannot get or create database subdirectory!")
  Write-Log ("Error: " + $Error[0].ToString())
  Exit-WithCode 5
}

# Работа с параметрами базы данных (глубина хранения, названия папок и дни перехода с уровня на уровень)
# Параметры хранения копий могут быть прочитаны из файла, могут быть получены в параметрах скрипта.
# Мы должны иметь возможность переопределить параметрами запуска те значения, которые хранятся в файле
# Мы также должны иметь возможность работать вообще без файла настроек, пользуясь параметрами по умолчанию
# или параметрами командной строки, при этом не создавая файл настроек.
# Предположение спорное, не исключено, что мы придем к желанию всегда иметь файл настроек и будем создавать его при отсутствии
# Параметры из файла могут быть неполными, например, если мы добавим новые в процессе развития функционала
# Но у нас есть еще и параметры по умолчанию, так что при старте скрипта параметры всегда имеют значение
# Думаю, лучшим способом будет использовать параметры из файла, а параметры командной строки
# применять только при наличии отдельного ключа, например, -Override,
# и отдельный ключ для сохранения новых параметров в файл, например, -SaveSettings
  
$SettingsFileName = $DatabaseDirectoryName+'\.settings.json'
$DirectorySettings = Get-Content $SettingsFileName -ErrorAction SilentlyContinue | ConvertFrom-Json

If ( $DirectorySettings ) {
  # Список параметров запуска будем предполагать более полным и корректным, поэтому берем его за основу
  # Если мы получили список параметров из файла, заменяем параметры запуска при отсутствии ключа -Override
  If ( ! $Override ) {
    If ( $DirectorySettings.Level1Copies ) { $Level1Copies = [Int]$DirectorySettings.Level1Copies }
    If ( $DirectorySettings.Level1FolderName ) { $Level1FolderName = [String]$DirectorySettings.Level1FolderName }
    If ( $DirectorySettings.Level2Copies ) { $Level2Copies = [Int]$DirectorySettings.Level2Copies }
    If ( $DirectorySettings.Level2FolderName ) { $Level2FolderName = [String]$DirectorySettings.Level2FolderName }
    If ( $DirectorySettings.Level2Match ) { $Level2Match = [String]$DirectorySettings.Level2Match }
    If ( $DirectorySettings.Level2Days ) { $Level2Days = [String]$DirectorySettings.Level2Days }
    If ( $DirectorySettings.Level3Copies ) { $Level3Copies = [Int]$DirectorySettings.Level3Copies }
    If ( $DirectorySettings.Level3FolderName ) { $Level3FolderName = [String]$DirectorySettings.Level3FolderName }
    If ( $DirectorySettings.Level3Day ) { $Level3Day = [Int]$DirectorySettings.Level3Day }
  }
}

# Сделаем так - если -SaveSettings передано без -Override, никакие операции с файлами не выполняем,
# только записываем все параметры в .settings.json

If ( $SaveSettings ) {
  #If ( $Level2Match -match "\ADays\z" ) { $SaveL2Days = ( $Level2Days -join ',' ) } else { $SaveL2Days = [string]$Level2Days }
  $DirectorySettings = "{`"Level1Copies`":$Level1Copies,`"Level2Copies`":$Level2Copies,`"Level3Copies`":$Level3Copies,`"Level1FolderName`":`"$Level1FolderName`",`"Level2FolderName`":`"$Level2FolderName`",`"Level3FolderName`":`"$Level3FolderName`",`"Level2Match`":`"$Level2Match`",`"Level2Days`":`"$Level2Days`",`"Level3Day`":$Level3Day}"|ConvertFrom-Json
  $DirectorySettings | ConvertTo-JSON | Out-File -Encoding "UTF8" -FilePath $SettingsFileName
  If ( ! $Override ) {
    #Write-Log ("Warning: Cannot save settings without -Override switch!")
    Write-Log ("Info: Database settings saved to "+$SettingsFileName)
    Write-Log ("Info: File operations skipped.")
    Exit-WithCode 0
  }
}

#Write-Log ('Info: Database settings used:')
#Write-Log ('Info: Level 1 copies:      ' + $Level1Copies + ', directory name: ' + $Level1FolderName )
#Write-Log ('Info: Level 2 copies:      ' + $Level2Copies + ', directory name: ' + $Level2FolderName + ', match: ' + $Level2Match + ', days: ' + $Level2Days )
#Write-Log ('Info: Level 3 copies:      ' + $Level3Copies + ', directory name: ' + $Level3FolderName + ', day: ' + $Level3Day )

# Проверим остальные обязательные параметры
$ParametersError = $false
If ( ! $RemoteStoragePath ) { Write-Log 'Error: No remote storage path given!'; $ParametersError = $true }
If ( ! $JobStartDate ) { Write-Log 'Error: No job start date given!'; $ParametersError = $true }
# SQL Server передаст Job Start Date всегда в одном формате (yyyyMMdd без разделителей)
If ( $JobStartDate -notmatch '\A\d{8}\z' )  { Write-Log 'Error: Job start date must be a 8-digits string!'; $ParametersError = $true }
If ( ! $ComputerName ) { Write-Log 'Error: No computer name given!'; $ParametersError = $true }
If ( $ParametersError ) {
  Write-Log 'Usage: Get-Help <this script filename>'
  Exit-WithCode 4
}

# Проверим хранилище с оперативным бэкапом и поищем там файл
Try {
  #$RemoteBackupDirectory = Get-Item -Path ((Get-Item -Path $RemoteStoragePath).ToString() + '\' + $DatabaseName )
  $RemoteBackupDirectory = ( $RemoteStoragePath | Get-ChildItem -Filter $DatabaseName -Directory)
  $RemoteBackupPath = $RemoteBackupDirectory.FullName.ToString()
  Write-Log ('Info: Processing remote directory "' + $RemoteBackupPath + '"')
}
Catch {
  Write-Log ("Error: Cannot get remote backup directory!")
  Write-Log ("Error: " + $Error[0].ToString())
  Exit-WithCode 6
}

If ( ! $RemoteBackupDirectory.PSISContainer ) {
  Write-Log ("Error: Cannot remote backup path is not a directory!")
  Exit-WithCode 7
}

# Пока работаем с одним файлом - с тем, дату которого нам передали в параметрах
# Возможно, позже вынесу это в функцию, чтобы обрабатывать несколько файлов
# на случай, если предыдущая операция копирования не удалась, и в каталоге 
# оперативного бэкапа осталось больше одного файла
#
Try {
  $FileDate = Get-Date 
  If ( $FileDate::TryParseExact( $JobStartDate, 'yyyyMMdd', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref] $FileDate ) ) {
    $FileDateString = $FileDate.ToString( $DateFormat )
    $FileDayOfWeek = [int]$FileDate.DayOfWeek # 0-Sunday ... 6-Saturday
    $FileYear = [int]$FileDate.Year
    $FileMonth = [int]$FileDate.Month
    $FileDay = [int]$FileDate.Day
    #Write-Log ( "Info: Got date parts from JobStartDate - Year $FileYear, Month $FileMonth, Day $FileDay, DoW $FileDayOfWeek")
  } Else {
    Write-Log ( 'Error: Cannot get backup date from JobStartDate parameter!' )
    Exit-WithCode 8
  }
} Catch {
  Write-Log ( 'Error: Cannot get backup date from JobStartDate parameter!' )
    Write-Log ("Error: " + $Error[0].ToString())
    Exit-WithCode 8
}


Try {
  $RemoteBackupFileName = $DatabaseName + '_' + $FileDateString + '.bak'
  $RemoteBackupFile = ( $RemoteBackupDirectory | Get-ChildItem -Filter $RemoteBackupFileName -File)
  If ( -Not $RemoteBackupFile ) {
    Write-Log ( 'Error: Cannot find remote backup file or no access!' )
    Exit-WithCode 9
  }
  # Получим имя файла с точностью до регистра символов и заодно проверим, найден ли файл (если не найден, у нас тут NULL и мы вылетим в Catch)
  $RemoteBackupFileName = $RemoteBackupFile.Name.ToString()
  Write-Log ( 'Info: Processing remote backup file "' + $RemoteBackupFile.FullName + '"' )
}
Catch {
  Write-Log ( 'Error: Cannot find remote backup file or no access!' )
  Write-Log ( 'Error: ' + $Error[0].ToString() )
  Exit-WithCode 9
}

### Разберем дату архива вычислим год, месяц, день и день недели этой даты
##$FileDate = Get-Date
###[DateTime]::TryParseExact( $StartDate, $DateFormat, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref] $FileDate )
##If ( $FileDate::TryParseExact( $JobStartDate, $DateFormat, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref] $FileDate ) ) {

# Копируем файл в корень папки
Write-Log ('Info: Copying file from remote to local storage')
Try {
  $RemoteBackupFile | Copy-Item -Destination $DatabaseDirectory -Force #-Verbose
  # Сразу после копирования файла запишем имя компьютера, нас вызвавшего, чтобы в случае чего
  # быстро узнать, на каком сервере искать эту базу данных
  $ComputerName | Out-File -Encoding "UTF8" -FilePath ($DatabaseDirectoryName+'\.lastsource')
}
Catch {
  Write-Log ("Error: Cannot copy file!")
  Write-Log ("Error: " + $Error[0].ToString())
  Exit-WithCode 10
}

$BackupFileMask = '\A' + $DatabaseName + '_' + $DateMask + '.bak\z'

# Для универсальности пришлось оставить процедуры перемещения даже в случае нулевого количества копий
# Возможна ситуация, когда хранилось определенное количество копий, а мы хотим его уменьшить, для этого нам в любом случае нужно пробежать
# по каталогам всех уровней и проверить количество файлов в них, лишние сразу удалить

# Переместим лишние файлы в уровень 1, оставляя только один, самый новый (формат даты должен сортироваться по имени правильно)
# Перемещаем файл только в том случае, если количество хранимых копий больше нуля
# Ключ -Filter поддерживает только знаки подстановки "*" и "?", если хотим более точного совпадения, придется перебирать по одному, проверяя имя по регулярному выражению
#$L0Files = Get-ChildItem -Path $DatabaseDirectory -File -Filter $BackupFileMask | Sort-Object -Property 'Name' | Select-Object -SkipLast 1
$ProcessedFiles = $DatabaseDirectory | Get-ChildItem -File | Where-Object { $_.Name -Match $BackupFileMask } | Sort-Object -Property 'Name' | Select-Object -SkipLast 1
#$ProcessedFiles | Select-Object -Property 'FullName'
#$ProcessedFiles | Move-Item -Destination $Level1Directory
If ( $Level1Copies -gt 0 ) {
  # Проверим каталог первого уровня
  Try { $Level1Directory = $DatabaseDirectory.CreateSubdirectory($Level1FolderName)
    Write-Log ('Info: Processing level 1 directory "' + $Level1Directory.ToString() + '"')
  } Catch { Write-Log ("Error: Cannot create level 1 directory!"); Write-Log ("Error: " + $Error[0].ToString()); Exit-WithCode 11 }
  $ProcessedFiles | Foreach-Object {
    Try { 
      $_ | Move-Item -Destination $Level1Directory -Force
      Write-Log ('Info: File "' + $_.FullName + '" moved to directory "' + $Level1Directory.FullName + '"')
    } Catch {
      Write-Log ("Error: Cannot move files to level 1 directory!")
      Write-Log ("Error: " + $Error[0].ToString())
      Exit-WithCode 14
    }
  }
} Else {
  # Если каталог уровня 1 существует, запомним его
  $Level1Directory = $DatabaseDirectory | Get-ChildItem -Directory -Filter $Level1FolderName -ErrorAction SilentlyContinue
}

# Переместим файлы из уровеня 1 в уровень 2, если они соответствуют условию для уровня 2 ( день недели совпадает с заданным для данного каталога )
# Если первый уровень не храним, вместо первого уровня работаем с нулевым уровнем
# Если файл не соответствует условию уровня 2, но соответствует условию уровня 3, сразу переместим его в уровень 3
If ( $Level1Directory ) {
  $ProcessedFiles = $Level1Directory | Get-ChildItem -File | Where-Object { $_.Name -Match $BackupFileMask } | Sort-Object -Property 'Name' | Select-Object -SkipLast $Level1Copies
}
If ( $Level2Copies -gt 0 ) {
  # Проверим каталог второго уровня.
  Try { $Level2Directory = $DatabaseDirectory.CreateSubdirectory($Level2FolderName)
    Write-Log ('Info: Processing level 2 directory "' + $Level2Directory.ToString() + '"')
  } Catch { Write-Log ("Error: Cannot create level 2 directory!"); Write-Log ("Error: " + $Error[0].ToString()); Exit-WithCode 12 }
  #$ProcessedFiles | Foreach-Object { $_.FullName | Write-Log }
  $ProcessedFiles | Foreach-Object {
    If ( Level2Condition $_ ) {
      Try {
        $_ | Move-Item -Destination $Level2Directory -Force
        Write-Log ('Info: File "' + $_.FullName + '" moved to directory "' + $Level2Directory.FullName + '"')
      } Catch {
        Write-Log ("Error: Cannot move files to level 2 directory!")
        Write-Log ("Error: " + $Error[0].ToString())
        Exit-WithCode 15
      }
    }
  }
} Else {
  # Если каталог уровня 2 существует, запомним его
  $Level2Directory = $DatabaseDirectory | Get-ChildItem -Directory -Filter $Level2FolderName -ErrorAction SilentlyContinue
}

# Переместим файлы из уровеня 2 в уровень 3, если они соответствуют условию для уровня 3 ( день совпадает с заданным для данного каталога )
If ( $Level2Directory ) {
  $ProcessedFiles = $Level2Directory | Get-ChildItem -File | Where-Object { $_.Name -Match $BackupFileMask } | Sort-Object -Property 'Name' | Select-Object -SkipLast $Level2Copies
}
If ( $Level3Copies -gt 0 ) {
  # Проверим каталог третьего уровня
  Try { $Level3Directory = $DatabaseDirectory.CreateSubdirectory($Level3FolderName)
    Write-Log ('Info: Processing level 3 directory "' + $Level3Directory.ToString() + '"')
  } Catch { Write-Log ("Error: Cannot create level 3 directory!"); Write-Log ("Error: " + $Error[0].ToString()); Exit-WithCode 13 }

  #$ProcessedFiles | Foreach-Object { $_.FullName | Write-Log }
  $ProcessedFiles | Foreach-Object {
    If ( Level3Condition $_  ) {
      Try {
        $_ | Move-Item -Destination $Level3Directory -Force
        Write-Log ('Info: File "' + $_.FullName + '" moved to directory "' + $Level3Directory.FullName + '"')
      } Catch {
        Write-Log ("Error: Cannot move files to level 3 directory!")
        Write-Log ("Error: " + $Error[0].ToString())
        Exit-WithCode 16
      }
    }
  }
  # На всякий случай еще раз проверим каталог первого (или нулевого) уровня
  # В нем могут остаться файлы, попадающие под условие уровня 3, но не попадающие под условие уровня 2
  If ( $L1Directory ) { $ProcessedFiles = $Level1Directory | Get-ChildItem -File | Where-Object { $_.Name -Match $BackupFileMask } | Sort-Object -Property 'Name' | Select-Object -SkipLast $Level1Copies }
  Else { $ProcessedFiles = $DatabaseDirectory | Get-ChildItem -File | Where-Object { $_.Name -Match $BackupFileMask } | Sort-Object -Property 'Name' | Select-Object -SkipLast 1 }
  $ProcessedFiles | Foreach-Object {
    If ( Level3Condition $_  ) {
      Try {
        $_ | Move-Item -Destination $Level3Directory -Force
        Write-Log ('Info: File "' + $_.FullName + '" moved to directory "' + $Level3Directory.FullName + '"')
      } Catch {
        Write-Log ("Error: Cannot move files to level 3 directory!")
        Write-Log ("Error: " + $Error[0].ToString())
        Exit-WithCode 16
      }
    }
  }
} Else {
  # Если каталог уровня 3 существует, запомним его
  $Level3Directory = $DatabaseDirectory | Get-ChildItem  -Directory -Filter $Level3FolderName -ErrorAction SilentlyContinue
}

# Удалим файлы из уровня 3 (оставив заданное количество для данного каталога )
# Изменения каталогов тут не проверяем, так как мы могли параметрами уменьшить глубину хранения
If ( $Level3Directory ) {
  $L3Files = $Level3Directory | Get-ChildItem -File | Where-Object { $_.Name -Match $BackupFileMask } | Sort-Object -Property 'Name' | Select-Object -SkipLast $Level3Copies
  $L3Files | Foreach-Object {
    Try {
      $_ | Remove-Item -Force
      Write-Log ('Info: File "' + $_.FullName + '" deleted from "' + $Level3Directory.FullName + '"')
    } Catch {
      Write-Log ("Error: Cannot delete file from level 3 directory!")
      Write-Log ("Error: " + $Error[0].ToString())
      Exit-WithCode 17
    }
  }
  # Удалим каталог, если он пуст
  If ( ($Level3Directory|Get-ChildItem).Count -eq 0 ) { $Level3Directory | Remove-Item -ErrorAction SilentlyContinue}
}
# Удалим файлы из уровня 2 (оставив заданное количество для данного каталога )
# Изменения каталогов тут не проверяем, так как мы могли параметрами уменьшить глубину хранения
If ( $Level2Directory ) {
  $L2Files = $Level2Directory | Get-ChildItem -File | Where-Object { $_.Name -Match $BackupFileMask } | Sort-Object -Property 'Name' | Select-Object -SkipLast $Level2Copies
  $L2Files | Foreach-Object {
    Try {
      $_ | Remove-Item -Force
      Write-Log ('Info: File "' + $_.FullName + '" deleted from "' + $Level2Directory.FullName + '"')
    } Catch {
      Write-Log ("Error: Cannot delete file from level 2 directory!")
      Write-Log ("Error: " + $Error[0].ToString())
      Exit-WithCode 18
    }
  }
  # Удалим каталог, если он пуст
  If ( ($Level2Directory|Get-ChildItem).Count -eq 0 ) { $Level2Directory | Remove-Item -ErrorAction SilentlyContinue }
}
# Удалим файлы из уровня 1 (оставив заданное количество для данного каталога )
# Изменения каталогов тут не проверяем, так как мы могли параметрами уменьшить глубину хранения
If ( $Level1Directory ) {
  $L1Files = $Level1Directory | Get-ChildItem -File | Where-Object { $_.Name -Match $BackupFileMask } | Sort-Object -Property 'Name' | Select-Object -SkipLast $Level1Copies
  $L1Files | Foreach-Object {
    Try {
      $_ | Remove-Item -Force
      Write-Log ('Info: File "' + $_.FullName + '" deleted from "' + $Level1Directory.FullName + '"')
    } Catch {
      Write-Log ("Error: Cannot delete file from level 1 directory!")
      Write-Log ("Error: " + $Error[0].ToString())
      Exit-WithCode 19
    }
  }
  # Удалим каталог, если он пуст
  If ( ($Level1Directory|Get-ChildItem).Count -eq 0 ) { $Level1Directory | Remove-Item -ErrorAction SilentlyContinue }
}
# Удалим файлы из уровня 0 (оставив заданное количество для данного каталога )
# Изменения каталогов тут не проверяем, так как мы могли параметрами уменьшить глубину хранения
$L0Files = $DatabaseDirectory | Get-ChildItem -File | Where-Object { $_.Name -Match $BackupFileMask } | Sort-Object -Property 'Name' | Select-Object -SkipLast 1
$L0Files | Foreach-Object {
  Try {
    $_ | Remove-Item -Force
    Write-Log ('Info: File "' + $_.FullName + '" deleted from "' + $DatabaseDirectory.FullName + '"')
  } Catch {
    Write-Log ("Error: Cannot delete file from database directory!")
    Write-Log ("Error: " + $Error[0].ToString())
    Exit-WithCode 20
  }
}

# Удалим все файлы, кроме последнего, из каталога оперативного бэкапа.
# Если мы сюда добрались, значит, все операции с долговременным хранилищем завершились успешно, можно чистить.
## Вариант 1 - выбираем ВСЕ файлы, соответствующие маске, отсортированные по имени, кроме последнего. Если ничего не напутано с именами, мы оставим ровно текущий бэкап.
#$RemoteBackupFiles = ( $RemoteBackupDirectory | Get-ChildItem -File | Where-Object { $_.Name -Match $BackupFileMask } | Sort-Object -Property 'Name' | Select-Object -SkipLast 1 )
# Вариант 2 - выбираем ВСЕ файлы, соответствующие маске, кроме файла, который мы изначально копировали из оперативного хранилища в долговременное
# В этом случае сортировка нам не нужна.
$RemoteBackupFiles = ( $RemoteBackupDirectory | Get-ChildItem -File | Where-Object { $_.Name -Match $BackupFileMask } | Where-Object { $_.Name -NotMatch $RemoteBackupFileName } )
# Выбран Вариант 2
$RemoteBackupFiles | Foreach-Object {
  Try {
    $_ | Remove-Item -Force
    Write-Log ('Info: File "' + $_.FullName + '" deleted from "' + $RemoteBackupDirectory.FullName + '"')
  } Catch {
    Write-Log ("Error: Cannot delete file from remote backup storage!")
    Write-Log ("Error: " + $Error[0].ToString())
    Exit-WithCode 21
  }
}

Write-Log ('Info: Copy backup operation complete ' + (Get-Date -Format "yyyy.MM.dd HH:mm") )
Exit-WithCode 0
