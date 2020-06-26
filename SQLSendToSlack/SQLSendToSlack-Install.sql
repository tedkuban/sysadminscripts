-----------------------------------------------------
-- SQL Send to Slack install script
-- Author: Fedor Kubanets AKA Teddy
-- Company: HappyLook
-- Year: 2020
-- DO NOT FORGE TO CHANGE VERSION NUMBER AND MODIFICATION DATE !!!
DECLARE @ScriptVersion nvarchar(10) = '0.8'
DECLARE @ScriptDate datetime = '20200626'

-- You need to change this definitions!!!
DECLARE @SlackUri nvarchar(100) = N''
DECLARE @JobType nvarchar(20) = N'PowerShell'
DECLARE @ScriptFile nvarchar(40) = N''
--DECLARE @JobType nvarchar(20) = N'CmdExec'
--DECLARE @ScriptFile nvarchar(40) = N'C:\sqlagent\SQLSendToSlack.ps1'
------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------

SET NOCOUNT ON;
SET LANGUAGE us_english
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON

DECLARE @JobName sysname = 'dba_SendToSlack'
DECLARE @JobCategory nvarchar(50) = N'[Uncategorized (Local)]'
DECLARE @JobDescription nvarchar(100) = N'Created by SQLSendToSlack-Install.sql script version '+@ScriptVersion+' modified '+FORMAT(@ScriptDate,'dd.MM.yyyy','en-US' )
DECLARE @JobStepCommand nvarchar(max)

IF ( @JobType = N'CmdExec' ) BEGIN
  SET @JobStepCommand = N'powershell -NoProfile -NoLogo -NonInteractive ' + @ScriptFile
  IF ( LEN(RTRIM(LTRIM(@SlackUri))) <> 0 ) SET @JobStepCommand = @JobStepCommand + ' -Uri ''' + @SlackUri + ''''
END
ELSE BEGIN -- @JobType = 'PowerShell
SET @JobStepCommand = N'
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

    В первом случае скрипт в виде файла лежит в каталоге, доступном агенту SQL для чтения, и запускается так:
        PowerShell -NonInteractive -NoProfile -NoLogo ''C:\sqlagent\SQLSendToSlack.ps1'' -Uri ''https://hooks.slack.com/services/T00000000/B00000000/AAAAAAAAAAAAAAAAAAAAAAAA''
    во втором случае весь скрипт целиком копируется в тело шага задания.
    Добавил параметр -Uri
    Теперь этот скрипт без изменений можно использовать из шага задания типа CMDEXEC в виде файла
    и в шаге задания типа PowerShell, куда нужно скопировать текст скрипта целиком и вписать $Uri
.Parameter Uri
    Строка подключения к Slack API (WebHook)
.Example
    PowerShell .\SQLSendToSlack.ps1 -Uri ''https://hooks.slack.com/services/T00000000/B00000000/AAAAAAAAAAAAAAAAAAAAAAAA''
.Component
    MS SQL Server
.Notes
    Version: 0.8
    Date modified: 2020.06.20
    Autor: Fedor Kubanets AKA Teddy
    Company: HappyLook
#>
[CmdletBinding(DefaultParameterSetName="All")]
Param(
#  [Parameter(Mandatory=$True,Position=1)]
  [Parameter(Mandatory=$False)] [string]$Uri = ''' + @SlackUri + N'''
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
$BotName = $Computer + '' SQL Server''
# Generates POST message to be sent to the slack channel. 

$server = "localhost"
$database = "msdb"
Try {
  $sql = ''SET LANGUAGE us_english; SELECT message_id,timestamp,RTRIM(channel) channel,RTRIM(message_text) text FROM dba_SendToSlackQueue''
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
  $PostMessage = @{channel='''';text='''';username="$BotName";icon_emoji=":robot_face:"}
  $PostMessage.channel = $_.channel
  $PostMessage.text = $_.text
  #ConvertTo-JSON $PostMessage

  Try {
    # Sends HTTPS request to the Slack Web API service. 
    [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
    $WebRequest = Invoke-WebRequest -UseBasicParsing -Uri $Uri -ContentType "application/json; charset=utf-8" -Method Post -Body (ConvertTo-JSON $PostMessage)
    # Conditional logic to generate custom error message if JSON object response contains a top-level error property. 
    #$WebRequest.Content
    If ($WebRequest.Content -like ''*"ok":false*'') {
      # Terminates with error if the response contains an error property, parses the error code and stops processing of the command. 
      #Throw ( $WebRequest.Content -split ''"error":"'') [1] -replace ''"}'',''''
      Write-Output ( "Error: Error sending Slack web request!" )
      #Write-Output ( "Error: " + $Error[0].ToString() )
      Write-Output ( "Error: " + (( $WebRequest.Content -split ''"error":"'')[1] -replace ''"}'','''') )
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
    $sql = "SET LANGUAGE us_english; DELETE FROM msdb.dbo.dba_SendToSlackQueue where message_id=''"+$_.message_id+"''"
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
'
END

USE [msdb]

BEGIN TRANSACTION

DECLARE @ReturnCode INT
DECLARE @jobID BINARY(16)
DECLARE @JobFound int

SELECT @ReturnCode = 0
SET @JobFound = (SELECT COUNT([name]) FROM [msdb].[dbo].[sysjobs] WHERE name=@JobName)
IF (@JobFound > 0) BEGIN
   --DECLARE @ErrorMessage nvarchar(max) = 'Already has job named "'+@JobName+'"!'; PRINT @ErrorMessage; RETURN; END
   SET @JobID = (SELECT job_id FROM [msdb].[dbo].[sysjobs] WHERE name=@JobName)
   EXEC @ReturnCode = msdb.dbo.sp_delete_jobstep @job_id = @JobID, @step_id = 0
   IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
END
ELSE BEGIN
   IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=@JobCategory AND category_class=1)
   BEGIN
      EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=@JobCategory
      IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
   END
   EXEC @ReturnCode = msdb.dbo.sp_add_job @job_name=@JobName, 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@category_name=@JobCategory, 
		@job_id = @jobId OUTPUT
   IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
   --select @jobId
   EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id=@JobID, @server_name = N'(local)'
   IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
END

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Step1', 
		@step_id=1, @cmdexec_success_code=0, @on_success_action=1, 
		@on_success_step_id=0, @on_fail_action=2, @on_fail_step_id=0, 
		@retry_attempts=0, @retry_interval=0, @os_run_priority=0, 
		@flags=32,
		@subsystem=@JobType, 
		@command=@JobStepCommand
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id=@JobID, @description=@JobDescription, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

GOTO EndSave

QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
COMMIT TRANSACTION
--GO

-- Если структура таблицы изменится, нужно будет удалять ее и создавать заново
--EXEC @ReturnCode = dbo.sp_executesql @statement = N'DROP TABLE IF EXISTS [dbo].[dba_SendToSlackQueue]'
--IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
DECLARE @TableFound int = (SELECT COUNT(name) FROM [msdb].[sys].[tables] where name = 'dba_SendToSlackQueue')
IF @TableFound = 0 CREATE TABLE [msdb].[dbo].[dba_SendToSlackQueue](
  [message_id] [uniqueidentifier] NOT NULL,
  [timestamp] [datetime2] NOT NULL,
  [channel] [nchar](100) NOT NULL,
  [message_text] [nvarchar](max) NOT NULL
) ON [PRIMARY]

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[msdb].[dbo].[dba_SendToSlack]') AND type in (N'P', N'PC'))
--BEGIN
  EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[dba_SendToSlack] AS'
--END
--GO
DECLARE @SQL nvarchar(max) = N'
ALTER PROCEDURE [dbo].[dba_SendToSlack] 
	-- Add the parameters for the stored procedure here
	@Channel nvarchar(80)
	,@Message nvarchar(max)
AS
BEGIN
    SET NOCOUNT ON
    SET ANSI_NULLS ON
    SET QUOTED_IDENTIFIER ON

    DELETE FROM [msdb].[dbo].[dba_SendToSlackQueue] where DATEDIFF(s,timestamp,GETDATE()) > 86400
    INSERT INTO [msdb].[dbo].[dba_SendToSlackQueue] (message_id,timestamp,channel,message_text) VALUES (NEWID(),GETDATE(),@Channel,@Message)
    EXEC [msdb].[dbo].[sp_start_job] @job_name=''' + @JobName + '''
END'
EXEC dbo.sp_executesql @statement = @SQL
--GO




