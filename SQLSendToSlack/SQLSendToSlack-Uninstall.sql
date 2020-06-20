-----------------------------------------------------
-- SQL Send to Slack uninstall script
-- Author: Fedor Kubanets AKA Teddy
-- Company: HappyLook
-- Year: 2020
-- DO NOT FORGE TO CHANGE VERSION NUMBER AND MODIFICATION DATE !!!
DECLARE @ScriptVersion nvarchar(10) = '0.3'
DECLARE @ScriptDate datetime = '20200620'

------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------
DECLARE @JobName sysname = 'dba_SendToSlack'

SET LANGUAGE us_english
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON

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
  EXEC @ReturnCode = msdb.dbo.sp_delete_job @job_id = @JobID
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
END

EXEC @ReturnCode = dbo.sp_executesql @statement = N'DROP PROCEDURE IF EXISTS [dbo].[dba_SendToSlack]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = dbo.sp_executesql @statement = N'DROP TABLE IF EXISTS [dbo].[dba_SendToSlackQueue]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

GOTO EndSave

QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
COMMIT TRANSACTION
GO
