USE [msdb]
GO

SET NOCOUNT ON
BEGIN TRANSACTION

-----------------------------------------------------
-- DO NOT FORGE TO CHANGE VERSION NUMBER AND MODIFICATION DATE !!!
DECLARE @ScriptVersion nvarchar(10) = '3.0'
DECLARE @ScriptDate datetime = '20210830'

-- You need to change this definitions!!!
DECLARE @DBName sysname = 'RMAnalytics'
--DECLARE @DBType sysname = 'SSDE' -- SQL Server Database Engine
--DECLARE @SecondaryStoragePath nvarchar(100) = 'E:\SQLBACKUP'
DECLARE @DBType sysname = 'SSAS' -- SQL Server Analysis Services
DECLARE @SecondaryStoragePath nvarchar(100) = 'E:\SSASBACKUP'
DECLARE @StartTime varchar(5) = '04:47'
-- If LocalBackupPath is not defined, database will be backed up to PrimaryBackupPath
DECLARE @LocalBackupPath nvarchar(260) = N''
-- If LocalBackupPath is defined, database will be backed up to LocalBackupPath, then backup file will be copied to PrimaryBackupPath
--DECLARE @LocalBackupPath nvarchar(260) = N'G:\SQLBackup'
DECLARE @PrimaryBackupPath nvarchar(260) = N'\\backup-latest.technical\SQLBACKUP\_OLAP'
DECLARE @SecondaryBackupServer nvarchar(260) = 'backup.technical'
DECLARE @ScriptFile nvarchar(260) = N'C:\sqlagent\BackupFileProcessing.ps1'
DECLARE @PSRemotingConfiguration nvarchar(128) = N'SQLAgent'
-- If @OperatorName is defined, created job must notify given operator if job fail
--DECLARE @OperatorName nvarchar(50) = N''
DECLARE @OperatorName nvarchar(50) = N'SQLAlert'
DECLARE @DateFormat nvarchar(10) = 'yyyy.MM.dd' -- also can be used 'yyyyMMdd'
DECLARE @FileExtension nvarchar(3) = 'bak'
-----------------------------------------------------
-- This code add daily scheduled job to backup one database to specified folder
-----------------------------------------------------

SET @DBType = UPPER(@DBType)
DECLARE @BackupStepSubsystem nvarchar(20)
SET @BackupStepSubsystem = CASE @DBType
  WHEN ('SSDE') THEN N'TSQL'
  WHEN ('SSAS') THEN N'ANALYSISCOMMAND'
  ELSE ''
END
IF (LEN(@BackupStepSubsystem)=0) BEGIN
  Print 'Unknown database type!'
  GOTO QuitWithRollback
END
IF (@DBType='SSAS') BEGIN 
  SET @DateFormat = 'yyyyMMdd'
  SET @FileExtension = 'abf'
END

DECLARE @DateSubstitution nvarchar(100)
IF (@DateFormat = 'yyyy.MM.dd') BEGIN
  SET @DateSubstitution = 'SUBSTRING(''$(ESCAPE_SQUOTE(STRTDT))'',1,4) + ''.'' + SUBSTRING(''$(ESCAPE_SQUOTE(STRTDT))'',5,2) + ''.'' + SUBSTRING(''$(ESCAPE_SQUOTE(STRTDT))'',7,2)'
END
ELSE BEGIN -- 'yyyyMMdd'
  SET @DateSubstitution = '$(ESCAPE_SQUOTE(STRTDT))'
END

-- if a job is found by name, all its steps will be recreated and the schedule will not be changed
DECLARE @JobName nvarchar(200) = N'Backup (v3) '+@DBType+' DB '+@DBName
DECLARE @JobDescription nvarchar(100) = N'Created by AddDailyBackupJobV3.sql script version '+@ScriptVersion+' modified '+FORMAT(@ScriptDate,'dd.MM.yyyy','en-US' )
DECLARE @JobCategory nvarchar(50) = N'Database Maintenance'

IF (LTRIM(RTRIM(@LocalBackupPath))='') BEGIN 
  SET @LocalBackupPath = @PrimaryBackupPath
END
  
DECLARE @Step1SQL nvarchar(max) = N'IF NOT EXIST '+@LocalBackupPath+'\' +@DBName+' mkdir '+@LocalBackupPath+'\'+@DBName

DECLARE @Step2SQL nvarchar(max)
IF (@DBType='SSDE') BEGIN 
  SET @Step2SQL = N'DECLARE @DBName sysname = '''+@DBName+'''
  DECLARE @BackupPath nvarchar(260) = N'''+@LocalBackupPath+'''
  DECLARE @StartDate varchar(10) = ' + @DateSubstitution + '
  DECLARE @FileName nvarchar(256) = @BackupPath+''\''+@DBName+''\''+@DBName+''_''+@StartDate+''.'+@FileExtension+'''
  DECLARE @Descr nvarchar(256) = @DBName + '' Full Database Backup '' + @StartDate
  BACKUP DATABASE @DBName TO DISK = @FileName WITH FORMAT, INIT,  NAME = @Descr, SKIP, NOREWIND, NOUNLOAD, COMPRESSION'
END
ELSE BEGIN
  SET @Step2SQL = N'
  <Backup xmlns="http://schemas.microsoft.com/analysisservices/2003/engine">
    <Object>
      <DatabaseID>' + @DBName + '</DatabaseID>
    </Object>
    <File>' + @LocalBackupPath+'\'+@DBName+'\'+@DBName+'_'+@DateSubstitution+'.'+@FileExtension + '</File>
    <AllowOverwrite>true</AllowOverwrite>
    <ApplyCompression>true</ApplyCompression>
  </Backup>'
END

DECLARE @Step3SQL nvarchar(max) = N''
IF ( @LocalBackupPath <> @PrimaryBackupPath ) BEGIN
  SET @Step3SQL = N'CMD /U /V:ON /C "CHCP 437 && SET DT='+@DateSubstitution+' && ROBOCOPY ^"'+@LocalBackupPath+'\'+@DBName+'^" ^"'+@PrimaryBackupPath+'\'+@DBName+'^" /NP /NJS /NJS /R:3 /W:3 /IF '+@DBName+'_!DT!.'+@FileExtension+' & IF NOT ERRORLEVEL 7 EXIT 0"'
END

DECLARE @Step4SQL nvarchar(max)
DECLARE @Step4SQLpart1 nvarchar(max) = N'PowerShell -NonInteractive -NoProfile "'
DECLARE @Step4SQLpart2 nvarchar(max) = N'$CN='''+@SecondaryBackupServer+''';$P=(Resolve-DnsName -DnsOnly -Name $CN -Type A_AAAA -ErrorAction SilentlyContinue);If($P.Count){If($P[-1].Name){$CN=$P[-1].Name}};'
DECLARE @Step4SQLpart3 nvarchar(max) = N'$rs=Invoke-Command -ComputerName $CN -ConfigurationName '+@PSRemotingConfiguration+' -ScriptBlock {&'''+@ScriptFile+''' '''+@DBName+''' '''+@PrimaryBackupPath+''' ''$(ESCAPE_SQUOTE(STRTDT))'' ''$(ESCAPE_SQUOTE(MACH))'' -LocalStoragePath '''+@SecondaryStoragePath+''' -DateFormat '''+@DateFormat+''' -FileExtension '''+@FileExtension+'''}'
DECLARE @Step4SQLpart4 nvarchar(max) = N';$host.SetShouldExit($rs)"'
SET @Step4SQL = @Step4SQLpart1 + @Step4SQLpart2 + @Step4SQLpart3 + @Step4SQLpart4

DECLARE @ScheduleName nvarchar(max) = N'Daily at '+@StartTime
--DECLARE @ActiveStartDate varchar(8) = FORMAT(CONVERT(date,SYSDATETIME()),'yyyyddMM')
DECLARE @ActiveStartTime varchar(6) = FORMAT(CONVERT(time,@StartTime),'hmmss')
DECLARE @SystemUser nchar(256) = SYSTEM_USER
DECLARE @schedule_id int

DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1) BEGIN
  EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
END

DECLARE @jobID BINARY(16)
DECLARE @JobFound int
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
		@notify_level_email=2, 
		@notify_level_page=2, 
		@delete_level=0, 
		@category_name=@JobCategory, 
		@job_id = @jobId OUTPUT
   IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
   --select @jobId
   EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id=@JobID, @server_name = N'(LOCAL)'
   IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
END

IF (@OperatorName <> '')
  EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id=@JobID,
		@notify_level_email=2, 
		@notify_level_page=2, 
		@notify_email_operator_name=@OperatorName,
		@notify_page_operator_name=@OperatorName
  ;
ELSE
  EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id=@JobID,
		@notify_email_operator_name='',
		@notify_page_operator_name=''
  ;
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

DECLARE @StepIDD INT = 1
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'CreateDir', 
		@step_id=@StepIDD, 
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
SET @StepIDD = @StepIDD + 1
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@JobID, @step_name=N'BackupDB', 
		@step_id=@StepIDD, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_fail_action=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=@BackupStepSubsystem, 
		@command=@Step2SQL, 
		@server=N'localhost', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
IF (@Step3SQL <> '') BEGIN
  SET @StepIDD = @StepIDD + 1
  EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'CopyLocalToPrimary', 
		@step_id=@StepIDD, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'CmdExec', 
		@command=@Step3SQL, 
		@flags=32
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
END
SET @StepIDD = @StepIDD + 1
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@JobID, @step_name=N'FileProcessing', 
		@step_id=@StepIDD, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_fail_action=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'CmdExec', 
		@command=@Step4SQL, 
		@database_name=N'master', 
		@flags=32
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1, @description=@JobDescription
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

IF (@JobFound = 0) BEGIN
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
END
--select @schedule_id
SELECT 1 - (SELECT COUNT([job_id]) FROM [msdb].[dbo].[sysjobs] WHERE job_id=@JobID)
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO
