-----------------------------------------------------
-- SQL Send to Slack install script
-- Author: Fedor Kubanets AKA Teddy
-- Company: HappyLook
-- Year: 2020
-- DO NOT FORGE TO CHANGE VERSION NUMBER AND MODIFICATION DATE !!!
DECLARE @ScriptVersion nvarchar(10) = '0.6'
DECLARE @ScriptDate datetime = '20200620'

-- You need to change this definitions!!!
DECLARE @ScriptFile nvarchar(40) = N'C:\sqlagent\SQLSendToSlack.ps1'
DECLARE @SlackUri nvarchar(100) = N''
------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------

SET NOCOUNT ON;
SET LANGUAGE us_english
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON

DECLARE @JobName sysname = 'dba_SendToSlack'
DECLARE @JobCategory nvarchar(50) = N'[Uncategorized (Local)]'
DECLARE @JobDescription nvarchar(100) = N'Created by SQLSendToSlack-Install.sql script version '+@ScriptVersion+' modified '+FORMAT(@ScriptDate,'dd.MM.yyyy','en-US' )
DECLARE @JobStepCommand nvarchar(max) = N'powershell -NoProfile -NoLogo -NonInteractive ' + @ScriptFile + N' -Computer ''$(ESCAPE_SQUOTE(MACH))'''
IF ( LEN(RTRIM(LTRIM(@SlackUri))) <> 0 ) SET @JobStepCommand = @JobStepCommand + ' -Uri ''' + @SlackUri + ''''

USE [msdb]

/****** Object:  Job [dba_SlackQueueProcessing]    Script Date: 20.06.2020 15:21:23 ******/
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

/****** Object:  Step [Step1]    Script Date: 20.06.2020 15:21:23 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Step1', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'CmdExec', 
		@command=@JobStepCommand, 
		@flags=32
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
	,@Text nvarchar(max)
AS
BEGIN
    SET NOCOUNT ON
    SET ANSI_NULLS ON
    SET QUOTED_IDENTIFIER ON

    DELETE FROM [msdb].[dbo].[dba_SendToSlackQueue] where DATEDIFF(s,timestamp,GETDATE()) > 86400
    INSERT INTO [msdb].[dbo].[dba_SendToSlackQueue] (message_id,timestamp,channel,message_text) VALUES (NEWID(),GETDATE(),@Channel,@Text)
    EXEC [msdb].[dbo].[sp_start_job] @job_name=''' + @JobName + '''
END'
EXEC dbo.sp_executesql @statement = @SQL
--GO




