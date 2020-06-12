USE [msdb]
GO

SET NOCOUNT ON
BEGIN TRANSACTION

-----------------------------------------------------
-- You need to change this definitions!!!
DECLARE @DBName sysname = 'UPPBU'
DECLARE @StartTime varchar(5) = '3:00'
DECLARE @PrimaryBackupPath nvarchar(260) = N'\\backup01.technical\SQLBACKUP'
DECLARE @SecondaryBackupServer nvarchar(260) = 'backup02.technical'
DECLARE @ScriptFile nvarchar(260) = N'C:\sqlagent\BackupFileProcessing.ps1'
DECLARE @PSRemotingConfiguration nvarchar(128) = N'SQLAgent'
-----------------------------------------------------
-- This code add daily scheduled job to backup one database to specified folder
-----------------------------------------------------
DECLARE @JobName nvarchar(200) = N'Backup database (v2) '+@DBName
DECLARE @Step1SQL nvarchar(max) = N'IF NOT EXIST '+@PrimaryBackupPath+'\'+@DBName+' mkdir '+@PrimaryBackupPath+'\'+@DBName
DECLARE @Step2SQL nvarchar(max) = N'DECLARE @DBName sysname = '''+@DBName+'''
DECLARE @BackupPath nvarchar(260) = N'''+@PrimaryBackupPath+'''
DECLARE @StartDate varchar(10) = SUBSTRING(''$(ESCAPE_SQUOTE(STRTDT))'',1,4) + ''.'' + SUBSTRING(''$(ESCAPE_SQUOTE(STRTDT))'',5,2) + ''.'' + SUBSTRING(''$(ESCAPE_SQUOTE(STRTDT))'',7,2)
DECLARE @FileName nvarchar(256) = @BackupPath+''\''+@DBName+''\''+@DBName+''_''+@StartDate+''.bak''
DECLARE @Descr nvarchar(256) = @DBName + '' Full Database Backup '' + @StartDate
BACKUP DATABASE @DBName TO DISK = @FileName WITH FORMAT, INIT,  NAME = @Descr, SKIP, NOREWIND, NOUNLOAD, COMPRESSION'

DECLARE @Step3SQL nvarchar(max)
DECLARE @Step3SQLpart1 nvarchar(max) = N'PowerShell -NonInteractive -NoProfile "'
DECLARE @Step3SQLpart2 nvarchar(max) = N'$CN='''+@SecondaryBackupServer+''';$P=(Resolve-DnsName -DnsOnly -Name $CN -Type PTR -ErrorAction SilentlyContinue);If ($P -ne $NULL){$CN=$P[-1].NameHost};'
DECLARE @Step3SQLpart3 nvarchar(max) = N'$rs=Invoke-Command -ComputerName $CN -ConfigurationName '+@PSRemotingConfiguration+' -ScriptBlock {&'''+@ScriptFile+''' '''+@DBName+''' '''+@PrimaryBackupPath+''' ''$(ESCAPE_SQUOTE(STRTDT))'' ''$(ESCAPE_SQUOTE(MACH))''}'
DECLARE @Step3SQLpart4 nvarchar(max) = N';$host.SetShouldExit($rs)"'
SET @Step3SQL = @Step3SQLpart1 + @Step3SQLpart2 + @Step3SQLpart3 + @Step3SQLpart4

DECLARE @ScheduleName nvarchar(max) = N'Daily at '+@StartTime
--DECLARE @ActiveStartDate varchar(8) = FORMAT(CONVERT(date,SYSDATETIME()),'yyyyddMM')
DECLARE @ActiveStartTime varchar(6) = FORMAT(CONVERT(time,@StartTime),'hmmss')
DECLARE @SystemUser nchar(256) = SYSTEM_USER
DECLARE @schedule_id int

DECLARE @JobFound int
SET @JobFound = (SELECT COUNT([name]) FROM [msdb].[dbo].[sysjobs] WHERE name=@JobName)
IF (@JobFound > 0) BEGIN DECLARE @ErrorMessage nvarchar(max) = 'Already has job named "'+@JobName+'"!'; PRINT @ErrorMessage; RETURN; END

DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode = msdb.dbo.sp_add_job @job_name=@JobName, 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_page=2, 
		@delete_level=0, 
		@category_name=N'Database Maintenance', 
		@job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
--select @jobId
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id=@JobID, @server_name = N'(LOCAL)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'CreateDir', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'CmdExec', 
		@command=@Step1SQL, 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@JobID, @step_name=N'BackupDB', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_fail_action=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=@Step2SQL, 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@JobID, @step_name=N'FileProcessing', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_fail_action=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'CmdExec', 
		@command=@Step3SQL, 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@JobID, @name=@ScheduleName, 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20190101,
		@active_end_date=99991231, 
		@active_start_time=@ActiveStartTime, 
		@active_end_time=235959, @schedule_id = @schedule_id OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
--select @schedule_id
SELECT 1 - (SELECT COUNT([job_id]) FROM [msdb].[dbo].[sysjobs] WHERE job_id=@JobID)
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO
