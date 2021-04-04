/*
Сжатие таблиц и индексов базы данных
Автор: Кубанец Федор
Дата: 2021.01.12

Версия: 0.8
Дата: 2021.04.04

Список таблиц и индексов получаем одним запросом по индексам.
Если у таблицы есть кластеризованный индекс, он всегда будет иметь [index_id] = 1, если же кластеризованного индекса нет, 
то сама таблица будет иметь [index_id] = 0, а имя индекса будет NULL. 
Одновременно для одной таблицы наличие [index_id] 0 и 1 невозможно.

Для таблицы с кластеризованным индексом выполнение инструкций 
ALTER TABLE <Table_Name> REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = ...);
и 
ALTER INDEX <Clustered_Index_Name> ON <Table_Name> REBUILD WITH (DATA_COMPRESSION = ...);

дает эквивалентный результат, поэтому таблицы с [index_id] 0 и 1 можно обрабатывать одинаково, как таблицы


Алгоритм кратко:
- Получаем список индексов для всех таблиц, суммируя количество строк по секциям, получая общее количество строк на индекс/таблицу, во временную таблицу
- Устанавливаем необходимость сжатия/разжатия и статус во временной таблице
- 
*/

-- Здесь описываем параметры

-- Количество строк в таблице, ниже которого оставляем несжатыми (или разжимаем, если уже сжато)
-- Если указать 0 - сжимаем все, даже пустые таблицы
-- Если указать отрицательное значение, разжимаем все.
DECLARE @CompressThreshold bigint = -1;

-- Режим перестроения (ONLINE/OFFLINE)
DECLARE @OnlineRebuild nvarchar(3) = 'OFF'

DECLARE @TimedateFormat nvarchar(19) = 'yyyy.MM.dd HH:mm:ss'

DECLARE @TableName sysname
DECLARE @IndexName sysname
DECLARE @IndexID int
DECLARE @TargetCompression nvarchar(20)
DECLARE @RowID bigint
DECLARE @Rows bigint
DECLARE @Query nvarchar(max)
DECLARE @ResultCode int
DECLARE @InfoMessage nvarchar(max)
DECLARE @GlobalStartTime datetime
DECLARE @StepStartTime datetime
DECLARE @CurrentTime datetime

--USE myDatabase

SET @GlobalStartTime = SYSDATETIME()
SET @StepStartTime = SYSDATETIME()
PRINT ('Starting at ' + FORMAT(@GlobalStartTime,@TimedateFormat))

SET @Query = N'exec sp_helpdb ' + DB_NAME()
EXEC @ResultCode = sp_executesql @Query

SET NOCOUNT ON
DROP TABLE IF EXISTS #compress_temptable

SELECT [t].[name] AS [Table], [i].[name] AS [Index], [p].[index_id] AS [Index_ID], SUM([p].[rows]) as [Rows],  
    [p].[partition_number] AS [Partition],
    [p].[data_compression_desc] AS [Compression], [p].[data_compression_desc] AS [Target_Compression]
INTO #compress_temptable
FROM [sys].[partitions] AS [p]
INNER JOIN sys.tables AS [t] ON [t].[object_id] = [p].[object_id]
INNER JOIN sys.indexes AS [i] ON [i].[object_id] = [p].[object_id] AND [i].[index_id] = [p].[index_id]
--WHERE ([p].[index_id] > 1) AND ([p].[rows] >= @CompressThreshold)
--WHERE [p].[rows] >= @CompressThreshold
--WHERE ([p].[rows] = 500020)
GROUP BY [t].[name], [i].[name], [p].[index_id], [p].[partition_number], [p].[data_compression_desc]
--ORDER BY Rows DESC, Index_ID

--ALTER TABLE #compress_temptable ADD Status NVARCHAR(60) NOT NULL DEFAULT 'NONE' WITH VALUES, RowID bigint IDENTITY CONSTRAINT compress_temptable_rowid PRIMARY KEY;
ALTER TABLE #compress_temptable ADD Status NVARCHAR(60) NOT NULL DEFAULT 'NONE' WITH VALUES, RowID bigint IDENTITY PRIMARY KEY;

IF ( @CompressThreshold < 0 ) BEGIN
  UPDATE #compress_temptable SET Target_Compression = 'NONE'
END
ELSE BEGIN
  UPDATE #compress_temptable SET Target_Compression = 'PAGE' WHERE Rows >= @CompressThreshold
  UPDATE #compress_temptable SET Target_Compression = 'NONE' WHERE Rows < @CompressThreshold
END
UPDATE #compress_temptable SET Status = 'WAITING' WHERE Compression != Target_Compression

SELECT * from #compress_temptable AS c ORDER BY Rows DESC, Index_ID

DECLARE Progress CURSOR LOCAL FORWARD_ONLY
FOR 
  SELECT [c].[Table], [c].[Index], [c].[Index_ID], [c].[Target_Compression], [c].[RowID], [c].[Rows]
  FROM #compress_temptable AS c
  WHERE Status = 'WAITING'
  --WHERE Compression != Target_Compression
  ORDER BY Rows DESC, Index_ID
FOR UPDATE OF Status

SET @CurrentTime = SYSDATETIME()
PRINT ('    Preparation steps completed at ' + FORMAT(@CurrentTime,@TimedateFormat) + ' in ' + CAST(DATEDIFF(minute, @StepStartTime, @CurrentTime) AS nvarchar) + ' minutes')
SET @StepStartTime = SYSDATETIME()
PRINT '    BEGIN COMPRESSION'
OPEN Progress
WHILE 1 = 1
  BEGIN
    --PRINT '4'
    FETCH NEXT 
	FROM Progress INTO @TableName, @IndexName, @IndexID, @TargetCompression, @RowID, @Rows
	IF NOT (@@FETCH_STATUS = 0) BREAK
    UPDATE #compress_temptable SET Status = 'PROGRESS' WHERE CURRENT OF Progress
--	SET @InfoMessage = '      ' + (CASE @TargetCompression WHEN 'NONE' THEN 'Decompressing' ELSE 'Compressing' END) + ' table ' + @TableName + ' index ' + CAST(@IndexID as nvarchar(max))
--    PRINT @InfoMessage
    PRINT ('      ' + (CASE @TargetCompression WHEN 'NONE' THEN 'Decompressing' ELSE 'Compressing' END) + ' table ' + @TableName + ' index ' + CAST(@IndexID as nvarchar(max)) + ', rows count = ' + CAST(@Rows as nvarchar(max)))
	IF ( @IndexID in (0,1) ) BEGIN
	  SET @Query = N'ALTER TABLE ' + @TableName + ' REBUILD PARTITION = ALL WITH (ONLINE = ' + @OnlineRebuild + ', DATA_COMPRESSION = ' + @TargetCompression + ');'
	END
	ELSE BEGIN
      SET @Query = N'ALTER INDEX ' + @IndexName + ' ON ' + @TableName + ' REBUILD WITH (ONLINE = ' + @OnlineRebuild + ', DATA_COMPRESSION = ' + @TargetCompression + ');'
	END
    --PRINT @Query
    BEGIN TRY
    	EXEC @ResultCode = sp_executesql @Query
        UPDATE #compress_temptable SET Status = 'DONE' WHERE CURRENT OF Progress
    END TRY
    BEGIN CATCH
        PRINT ('      ' + (CASE @TargetCompression WHEN 'NONE' THEN 'Decompression' ELSE 'Compression' END) + ' of  table ' + @TableName + ' index ' + CAST(@IndexID as nvarchar(max)) + ' failed, returned code ' + CAST(@ResultCode as nvarchar(max)))
        --ERROR_PROCEDURE() AS ErrorProcedure  
        --ERROR_LINE() AS ErrorLine  
        PRINT ('      ErrorState: ' + ERROR_STATE() + '; ErrorNumber: ' + ERROR_NUMBER() + '; ErrorSeverity: ' + ERROR_SEVERITY() + '; ErrorMessage: ' + ERROR_MESSAGE())
	END CATCH
    UPDATE #compress_temptable SET Status = 'DONE' WHERE CURRENT OF Progress
  END
CLOSE Progress
DEALLOCATE Progress

SET @CurrentTime = SYSDATETIME()
PRINT ('    Compression/decompression completed at ' + FORMAT(@CurrentTime,@TimedateFormat) + ' in ' + CAST(DATEDIFF(minute, @StepStartTime, @CurrentTime) AS nvarchar) + ' minutes')
SET @StepStartTime = SYSDATETIME()

SELECT * from #compress_temptable AS c WHERE Status != 'NONE' ORDER BY Rows DESC, Index_ID
DROP TABLE IF EXISTS #compress_temptable

PRINT '    BEGIN DATABASE SHRINKING'
DBCC SHRINKDATABASE(0)

SET @CurrentTime = SYSDATETIME()
PRINT ('    Shrinking completed at ' + FORMAT(@CurrentTime,@TimedateFormat) + ' in ' + CAST(DATEDIFF(minute, @StepStartTime, @CurrentTime) AS nvarchar) + ' minutes')
SET @StepStartTime = SYSDATETIME()

SET @Query = N'exec sp_helpdb ' + DB_NAME()
EXEC @ResultCode = sp_executesql @Query

SET @CurrentTime = SYSDATETIME()
PRINT ('    All operations completed at ' + FORMAT(@CurrentTime,@TimedateFormat) + ' in ' + CAST(DATEDIFF(minute, @GlobalStartTime, @CurrentTime) AS nvarchar) + ' minutes')
