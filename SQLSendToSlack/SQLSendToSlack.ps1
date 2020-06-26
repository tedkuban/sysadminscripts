<#
.Synopsis
    Скрипт для отправки сообщений в Slack из SQL-Server
.Description
    Этот скрипт запускается из задания SQL Agent Job, которое, в свою очередь, запускается
    хранимой процедурой SQL-Server. Почему так сложно? Потому что мы не можем передать в Job
    параметры, а из T-SQL не можем вызвать WEB-Hook или внешнюю программу.
    Поэтому в хранимой процедуре мы делаем запись в таблицу [msdb].[dbo].[dba_SendToSlackQueue],
    а в этом скрипте читаем таблицу и отправляем все, что там нашли. Хранимой процедуре наплевать
    на результат выполнения задания, она добавила запись в таблицу и вернула успех.
    Есть некоторый шанс, что у нерадивого админа таблица когда-нибудь достигнет гигантского размера,
    так что я предполагаю записывать в таблицу время создания записи и при каждой попытке отправить
    сообщение чистить все записи старше суток, например.

    Первым и единственным шагом задания выполняется данный скрипт
    Существует два варианта запуска, с типом шага задания CmdExec или PowerShell
    В первом случае скрипт в виде файла лежит в каталоге, доступном агенту SQL для чтения, и запускается так:
        PowerShell -NonInteractive -NoProfile -NoLogo 'C:\sqlagent\SQLSendToSlack.ps1' -Uri 'https://hooks.slack.com/services/T00000000/B00000000/AAAAAAAAAAAAAAAAAAAAAAAA'
    во втором случае весь скрипт целиком копируется в тело шага задания.
    Добавил параметр -Uri
    Теперь этот скрипт без изменений можно использовать из шага задания типа CMDEXEC в виде файла
    и в шаге задания типа PowerShell, куда нужно скопировать текст скрипта целиком и вписать $Uri
.Parameter Uri
    Строка подключения к Slack API (WebHook)
.Example
    PowerShell .\SQLSendToSlack.ps1 -Uri 'https://hooks.slack.com/services/T00000000/B00000000/AAAAAAAAAAAAAAAAAAAAAAAA'
.Component
    MS SQL Server
.Notes
    Version: 1.0
    Date modified: 2020.06.26
    Autor: Fedor Kubanets AKA Teddy
    Company: HappyLook
#>
[CmdletBinding(DefaultParameterSetName="All")]
Param(
#  [Parameter(Mandatory=$True,Position=1)]
  [Parameter(Mandatory=$False)] [string]$Uri = 'https://hooks.slack.com/services/T00000000/B00000000/AAAAAAAAAAAAAAAAAAAAAAAA'
)

function Exit-WithCode
{
  param ( $exitcode )
  #Write-Output ($exitcode)
  $host.SetShouldExit($exitcode)
  exit $exitcode
}

#
# I want receive all messages in English
#
$currentThread = [System.Threading.Thread]::CurrentThread
$culture = [System.Globalization.CultureInfo]::InvariantCulture
$currentThread.CurrentCulture = $culture
$currentThread.CurrentUICulture = $culture

$Computer = $env:COMPUTERNAME
$BotName = $Computer + ' SQL Server'
# Generates POST message to be sent to the slack channel. 

$server = "localhost"
$database = "msdb"
Try {
  $sql = 'SET LANGUAGE us_english; SELECT message_id,timestamp,RTRIM(channel) channel,RTRIM(message_text) text FROM dba_SendToSlackQueue'
  $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
  $SqlConnection.ConnectionString = "Server=$server;Database=$database;Integrated Security=True"
  $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
  $SqlCmd.CommandText = $sql
  $SqlCmd.Connection = $SqlConnection
  $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
  $SqlAdapter.SelectCommand = $SqlCmd
  $DataSet = New-Object System.Data.DataSet
  $rowsAffected = $SqlAdapter.Fill($DataSet)
  #"ROWS Affected: $rowsAffected" 
  $SqlConnection.Close()
  #$DataSet.Tables[0]
} # Try 
Catch {
  Write-Output ( "Error: Exeption during SQL select query!" )
  Write-Output ( "Error: " + $Error[0].ToString() )
  Exit-WithCode 1
} # Catch 

Try {
  $SqlConnection.Open()
} # Try 
Catch {
  Write-Output ( "Error: Exeption during reopen SQL connection!" )
  Write-Output ( "Error: " + $Error[0].ToString() )
  Exit-WithCode 2
} # Catch 
#$SQLResult = $DataSet.Tables[0]
#$SQLResult.Rows = $DataSet.Tables[0]
$DataSet.Tables[0]|Foreach-Object {
  $PostMessage = @{channel='';text='';username="$BotName";icon_emoji=":robot_face:"}
  $PostMessage.channel = $_.channel
  $PostMessage.text = $_.text
  #ConvertTo-JSON $PostMessage

  Try {
    # Sends HTTPS request to the Slack Web API service. 
    [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
    $WebRequest = Invoke-WebRequest -UseBasicParsing -Uri $Uri -ContentType "application/json; charset=utf-8" -Method Post -Body (ConvertTo-JSON $PostMessage)
    # Conditional logic to generate custom error message if JSON object response contains a top-level error property. 
    #$WebRequest.Content
    If ($WebRequest.Content -like '*"ok":false*') {
      # Terminates with error if the response contains an error property, parses the error code and stops processing of the command. 
      #Throw ( $WebRequest.Content -split '"error":"') [1] -replace '"}',''
      Write-Output ( "Error: Error sending Slack web request!" )
      #Write-Output ( "Error: " + $Error[0].ToString() )
      Write-Output ( "Error: " + (( $WebRequest.Content -split '"error":"')[1] -replace '"}','') )
      Continue
    } # If 
  } # Try 
  Catch {
    # Terminates with error and stops processing of the command. 
    #Throw ("Unable to send request to the web service with the following exception: " + $Error[0].Exception.Message )
    Write-Output ( "Error: Exeption during sending Slack web request!" )
    Write-Output ( "Error: " + $Error[0].ToString() )
    #Write-Output ( "Error: " + $Error[0].Exception.Message )
    #Exit-WithCode 2
    Continue
  } # Catch 
  Try { # Success - can delete message record
    $sql = "SET LANGUAGE us_english; DELETE FROM msdb.dbo.dba_SendToSlackQueue where message_id='"+$_.message_id+"'"
    $SqlCmd.CommandText = $sql
    #$SqlConnection.Open()
    $rowsAffected = $SqlCmd.ExecuteNonQuery();
  } # Try 
  Catch {
    Write-Output ( "Error: Exeption during SQL delete query!" )
    Write-Output ( "Error: " + $Error[0].ToString() )
  } # Catch 
} # Foreach-Object
Try {
  $SqlConnection.Close()
} # Try 
Catch {
  Write-Output ( "Error: Exeption during closing SQL connection!" )
  Write-Output ( "Error: " + $Error[0].ToString() )
  Exit-WithCode 4
} # Catch 

Exit-WithCode 0
