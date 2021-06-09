<#
.Synopsis
    Скрипт для очистки журналов регистрации баз 1С в последовательном формате
.Component
    1C:Enterprise
.Notes
    Version: 1.0
    Date modified: 2021.06.08
    Autor: Fedor Kubanets AKA Teddy
    Company: HappyLook
.Description
    Этот скрипт находит в реестре все записи служб сервера 1С, находит в каждом рабочем каталоге 
    все папки кластеров, в каждой папке кластера выбирает все папки информационных баз и удаляет все файлы журналов регистрации
    в текстовом (последовательном) формате старше заданного в полных днях возраста. Возраст по умолчанию - 2 недели (14 суток).
    Даты файлов получаем из имени файла, не из даты создания или модификации.

.Parameter MaxAge
    Максимальный возраст файла в днях
.Example
    PowerShell .\Truncate1CDatabaseLogs -MaxAge 21
       - Удалить все журналы регистрации старше трех недель
    PowerShell .\Truncate1CDatabaseLogs 31
       - Удалить все журналы регистрации старше одного месяца
#>
[CmdletBinding(DefaultParameterSetName="All")]
Param(
#  [Parameter(Mandatory=$True,Position=1)]
  [Parameter(Mandatory=$False,Position=1)] [int]$MaxAge = 14
)

#$ParsePathScriptBlock = 'Param([string]$d) $d'

# Получим список всех служб сервера 1С
Get-ChildItem 'HKLM:\System\CurrentControlSet\Services'|Where-Object { $_.GetValue('ImagePath') -Match '.*\\ragent\.exe.*' } | Foreach-Object {
  $ImagePath = $_.GetValue('ImagePath')

  $SrvInfoPath = &([ScriptBlock]::Create('Function ParsePath {Param([string]$d) $d} ParsePath '+$ImagePath))
  #Get-Item -Path $SrvInfoPath | Get-Member
  $ServerDir = (Get-Item -Path $SrvInfoPath).FullName
  Write-Host ( 'Processing 1C Server instance directory ' + $ServerDir )
  # Получим все каталоги кластеров
  Get-ChildItem -Path $ServerDir -Attributes Directory | Where { $_.Name -match '^reg_\d?' } | Foreach-Object {
    $ClusterDir = $_.FullName
    #Get-Item $_.Get-Type
   Write-Host ( 'Processing cluster directory ' + $_.FullName )
    #  Get-Item '$ProfilePath\AppData\Local\1C\1Cv8\*','$ProfilePath\AppData\Roaming\1C\1Cv8\*' | Where {$_.Name -as [guid]} | Remove-Item -Force -Recurse
    Get-ChildItem -Path $ClusterDir -Attributes Directory | Where { $_.Name -as [guid] } | Foreach-Object {
      Write-Host ( 'Processing database directory ' + $_.FullName )
      $LogDir = $_.FullName + '\1Cv8Log'
      If ( Test-Path $LogDir ) {
        Get-ChildItem -Path $LogDir -Attributes !Directory | Where-Object { $_.Extension -in ('.lgp','.lgx') } | Foreach-Object {
          $Fullname = $_.FullName
          Write-Host ( 'Processing file ' + $FullName )
          $FileDateString = ($_.BaseName).Substring(0,12)
          $FileDate = Get-Date
          # Разберем дату файла
            #[DateTime]::TryParseExact( $StartDate, $DateFormat, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref] $FileDate )
          If ( $FileDate::TryParseExact( $FileDateString, 'yyyyMMddmmss', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref] $FileDate ) ) {
            #$FileDate
            $DateDiff = New-TimeSpan -Start $FileDate -End (Get-Date)
            If ( $DateDiff.Days -gt $MaxAge ) {
              Try {
                $_.Delete()
                Write-Host ( 'File "' + $FullName + '" deleted.')
              }
              Catch { 
                Write-Host ( 'Warning: Cannot delete file "' + $FullName + '"!')
                Write-Host ( $Error[0].ToString() )
              }
            }
          } Else {
            Write-Host ( 'Warning: Cannot get date from filename "' + $_.Name + '"!')
          }
        }
      } Else {
        Write-Host 'Cannot find log directory!'
      }
    }
  }
}

exit 0
