/*
Копирует конфигурацию базы данных 1С, сохраняя наименования объектов на сервере SQL
Работает в том числе через связанный сервер.
Запускать на принимающем сервере.
После выполнения запустить тестирование и исправление, выбрать как минимум два пункта - реиндексацию и реструктуризацию.

Version:	0.9 beta
Modified:	2021.05.27
Author:		Fedor Kubanets AKA Teddy, St.-Petersburg
Company:	HappyLook (Счастливый Взгляд)
(c) 2021
*/


USE master
SET NOEXEC OFF
DECLARE @SOURCE_SERVER sysname = 'SRV201'
DECLARE @SOURCE_DB sysname = 'RM_TEST'

--DECLARE @SOURCE_SERVER sysname = NULL
--DECLARE @SOURCE_DB sysname = 'RM_CONFIG_5'
DECLARE @SOURCE_DB_OWNER nvarchar(128)
DECLARE @DEST_DB sysname = 'RM_CONFIG_7'
DECLARE @DEST_DB_ID bigint
DECLARE @USERS_TABLE sysname = '_Reference20'
DECLARE @SQL nvarchar(max)
DECLARE @SQL_SOURCE_SERVER_ADDON nvarchar(max) = ''

DECLARE @EXECUTE_STRING nvarchar(260)


--SELECT @SOURCE_DB_ID = SD.database_id,@SOURCE_DB_OWNER = SUSER_SNAME(SD.owner_sid) from [master].sys.databases SD WHERE SD.name = @SOURCE_DB
IF @SOURCE_SERVER IS NULL BEGIN -- One server execution
  SET @EXECUTE_STRING = 'sp_executesql'
  --SET @SQL_SOURCE_SERVER_ADDON = ''
END
ELSE BEGIN
  SET @SQL_SOURCE_SERVER_ADDON = @SOURCE_SERVER + '].['
END
SET @EXECUTE_STRING = '['+@SQL_SOURCE_SERVER_ADDON+'master].[sys].[sp_executesql]'

SET @SQL = N'
SELECT @DB_OWNER = SUSER_SNAME(SD.owner_sid) FROM [master].[sys].[databases] SD WHERE SD.name='''+@SOURCE_DB+'''
--SELECT @DB_OWNER
'
--PRINT @SQL
EXEC @EXECUTE_STRING @SQL, N'@DB_OWNER nvarchar(128) OUTPUT', @DB_OWNER=@SOURCE_DB_OWNER OUTPUT
--PRINT @SOURCE_DB_OWNER

IF @SOURCE_DB_OWNER IS NULL BEGIN
  PRINT 'Source database not found or no database owner defined!'
  SET NOEXEC ON
END

SET @SQL = N'
USE [master]
SELECT @DB_ID = SD.Database_ID FROM [master].[sys].[databases] SD WHERE SD.name='''+@DEST_DB+'''
--SELECT @DB_ID
'
--PRINT @SQL
EXEC sp_executesql @SQL, N'@DB_ID bigint OUTPUT', @DB_ID=@DEST_DB_ID OUTPUT
--PRINT @DEST_DB_ID
IF @DEST_DB_ID IS NULL BEGIN
  PRINT 'Destination database not found.'
END
ELSE BEGIN
  SET @SQL = N'ALTER DATABASE [' + @DEST_DB + '] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;DROP DATABASE [' + @DEST_DB + '];'
  EXEC (@SQL)
END

--DBCC CLONEDATABASE (@SOURCE_DB, @DEST_DB) WITH NO_STATISTICS, NO_QUERYSTORE, NO_INFOMSGS
--SET @SQL = N'ALTER DATABASE [' + @DEST_DB + '] SET READ_WRITE WITH NO_WAIT;ALTER AUTHORIZATION ON DATABASE::[' + @DEST_DB + '] TO [' + @SOURCE_DB_OWNER + '];'
SET @SQL = N'CREATE DATABASE [' + @DEST_DB + ']; ALTER AUTHORIZATION ON DATABASE::[' + @DEST_DB + '] TO [' + @SOURCE_DB_OWNER + '];'
EXEC (@SQL)

SET @SQL = N'SET NOCOUNT ON
USE [' + @DEST_DB + ']
DROP TABLE IF EXISTS __tmp__tablelist
SELECT [NAME] INTO __tmp__tablelist
FROM ['+@SQL_SOURCE_SERVER_ADDON+@SOURCE_DB+'].[sys].[all_objects]
WHERE ( (type=''U'') AND (is_ms_shipped=0) )
'
EXEC (@SQL)

SET @SQL = N'SET NOCOUNT ON
DECLARE @gettable CURSOR
DECLARE @SQL2 nvarchar(max)
DECLARE @TABLE_NAME sysname
DECLARE @SOURCE_TABLE_NAME sysname
DECLARE @COPY_METHOD tinyint
DECLARE @HAS_PREDEFINED tinyint

USE [' + @DEST_DB + ']
SET @gettable = CURSOR FOR
SELECT name as TABLE_NAME
FROM __tmp__tablelist

OPEN @gettable
WHILE 1=1 BEGIN
  FETCH NEXT
  FROM @gettable INTO @TABLE_NAME
  IF @@FETCH_STATUS <> 0 BREAK

  PRINT (''Table name = "'' + @TABLE_NAME + ''"'')
  SET @SOURCE_TABLE_NAME = ''['+@SQL_SOURCE_SERVER_ADDON+@SOURCE_DB+'].[dbo].[''+@TABLE_NAME+'']''

  SET @COPY_METHOD=2;
  
  --PRINT CHARINDEX(''_'',@TABLE_NAME)
  IF CHARINDEX(''_Document'',@TABLE_NAME) = 1 SET @COPY_METHOD=0
  IF CHARINDEX(''_Reference'',@TABLE_NAME) = 1 SET @COPY_METHOD=0
  IF CHARINDEX(''_AccumRg'',@TABLE_NAME) = 1 SET @COPY_METHOD=0
  IF CHARINDEX(''_InfoRg'',@TABLE_NAME) = 1 SET @COPY_METHOD=0
  IF CHARINDEX(''_DataHistory'',@TABLE_NAME) = 1 SET @COPY_METHOD=0
  IF CHARINDEX(''_SystemSettings'',@TABLE_NAME) = 1 SET @COPY_METHOD=0
  IF CHARINDEX(''_UsersWorkHistory'',@TABLE_NAME) = 1 SET @COPY_METHOD=0
  IF CHARINDEX(''_BPr'',@TABLE_NAME) = 1 SET @COPY_METHOD=0
  IF CHARINDEX(''_Task'',@TABLE_NAME) = 1 SET @COPY_METHOD=0
  IF CHARINDEX(''_'',@TABLE_NAME) = 1 BEGIN
    --IF COLUMNPROPERTY( OBJECT_ID(@TABLE_NAME),''_PredefinedID'',''AllowsNull'') IS NOT NULL SET @COPY_METHOD=1
    SET @SQL2 = ''DECLARE @TMP_VALUE bigint; SELECT TOP(0) @TMP_VALUE=_PredefinedID from ''+@SOURCE_TABLE_NAME
    --PRINT @SQL2
    BEGIN TRY
      exec sp_executesql @SQL2
      SET @HAS_PREDEFINED = 1
    END TRY
    BEGIN CATCH
      --THROW 50001, ''No predefined ID column found'', 0;
      SET @HAS_PREDEFINED = 0
    END CATCH
    --PRINT @HAS_PREDEFINED
    IF @HAS_PREDEFINED=1 SET @COPY_METHOD=1
	
	IF (CHARINDEX('''+@USERS_TABLE+''',@TABLE_NAME) = 1) SET @COPY_METHOD=2

	-- Эти таблицы добавлены вручную
	IF (CHARINDEX(''_Reference683'',@TABLE_NAME) = 1) SET @COPY_METHOD=2
	IF (CHARINDEX(''_Reference712'',@TABLE_NAME) = 1) SET @COPY_METHOD=2
	-- Вот досюда
	
	-- Если нужны константы - раскомментировать, но тогда в целевую БД попадет и история изменения констант (_ConstChngR....)
	--IF (CHARINDEX(''.[_Const'',@TABLE_NAME) = 1) SET @COPY_METHOD=2
	IF (CHARINDEX(''.[_Enum'',@TABLE_NAME) = 1) SET @COPY_METHOD=2
  END
  --ELSE SET @COPY_METHOD=2;
  --PRINT @COPY_METHOD;

  -- @CopyMethod:
  --     0 - copy structure only
  --     1 - copy predefined elements only
  --     0 - copy full table (structure and data)

  IF @COPY_METHOD = 0 BEGIN
    PRINT (''Processing empty copy table "'' + @TABLE_NAME + ''"'')
	SET @SQL2 = ''SELECT TOP(0) * INTO ''+@TABLE_NAME+'' FROM ''+@SOURCE_TABLE_NAME+'';''
	exec sp_executesql @SQL2
  END
  IF @COPY_METHOD = 1 BEGIN
    PRINT (''Processing copy table "'' + @TABLE_NAME + ''"'')
	SET @SQL2 = ''SELECT * INTO ''+@TABLE_NAME+'' FROM ''+@SOURCE_TABLE_NAME+'' WHERE _PredefinedID <> 0;''
	exec sp_executesql @SQL2
  END
  IF @COPY_METHOD = 2 BEGIN
    PRINT (''Processing full copy table "'' + @TABLE_NAME + ''"'')
	SET @SQL2 = ''SELECT * INTO ''+@TABLE_NAME+'' FROM ''+@SOURCE_TABLE_NAME+'';''
	exec sp_executesql @SQL2
  END
END

CLOSE @gettable
DEALLOCATE @gettable

DROP TABLE __tmp__tablelist
'
EXEC (@SQL)


--SET @SQL=N'
--'
--SET @EXECUTE_STRING = '['+@DEST_DB+'].[sys].[sp_MSforeachtable]'
--exec @EXECUTE_STRING @SQL

--SET @SQL = 'DBCC SHRINKDATABASE(DB_ID('+@DEST_DB+',0) WITH NO_INFOMSGS'
SET @SQL = 'DBCC SHRINKDATABASE("'+@DEST_DB+'",0) WITH NO_INFOMSGS'
EXEC (@SQL)

PRINT 'Shrink database completed.'

use master

SET NOEXEC OFF
