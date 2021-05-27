DECLARE @DBName sysname = '$(DBNAME)';
DECLARE @BackupPath nvarchar(260) = '$(BCKPATH)';
DECLARE @StartDate varchar(10) = SUBSTRING('$(ESCAPE_SQUOTE(STRTDT))',1,4) + '.' + SUBSTRING('$(ESCAPE_SQUOTE(STRTDT))',5,2) + '.' + SUBSTRING('$(ESCAPE_SQUOTE(STRTDT))',7,2);
DECLARE @FileName nvarchar(256) = @BackupPath+'\'+@DBName+'\'+@DBName+'_'+@StartDate+'.bak';
DECLARE @Descr nvarchar(256) = @DBName + ' Full Database Backup ' + @StartDate;
PRINT @DBName;
PRINT @BackupPath;
PRINT @StartDate;
PRINT @FileName;
--BACKUP DATABASE @DBName TO DISK = @FileName WITH FORMAT, INIT,  NAME = @Descr, SKIP, NOREWIND, NOUNLOAD, COMPRESSION;
BACKUP DATABASE @DBName TO DISK = @FileName WITH FORMAT, INIT,  NAME = @Descr, SKIP, NOREWIND, NOUNLOAD;
GO
EXIT
