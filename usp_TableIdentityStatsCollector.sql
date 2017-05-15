USE [Metrics];
GO

SET ANSI_NULLS ON;
GO

SET QUOTED_IDENTIFIER ON;
GO

IF NOT EXISTS
(
	SELECT *
	FROM sys.Objects
	WHERE object_id = OBJECT_ID(N'[dbo].[usp_TableIdentityStatsCollector]') AND 
		  Type IN( N'P', N'PC' )
)
BEGIN
	EXEC Dbo.Sp_Executesql @statement = N'CREATE PROCEDURE [dbo].[usp_TableIdentityStatsCollector] AS';
END;
GO

--********************************************************************************************************************
--This stored proc get the latest counts of every identity column in all Application Databases
--The data populates in roughly 1sec
--This proc captures identity column current count for all user tables from all the databases
--After the data is captured, it is stored in tbl_TableIdentityStats table with epoch timestamp in Metrics database
--The tbl_TableIdentityStats table creation script is embedded inside the SP code
--The proc runs without any parameter
--To execute - EXEC Metrics.dbo.usp_TableIdentityStatsCollector
--********************************************************************************************************************

ALTER PROCEDURE dbo.usp_TableIdentityStatsCollector
AS
SET NOCOUNT ON;
DECLARE @dbName VARCHAR(20);
DECLARE @destTable NVARCHAR(100) = N'tbl_TableIdentityStats';
DECLARE @rowsProcessed INT = 0;
IF OBJECT_ID(@destTable) IS NULL
BEGIN TRY
    CREATE TABLE tbl_TableIdentityStats
    (
	   EpochTime BIGINT
	   ,DbName VARCHAR(100)
	   ,SchName VARCHAR(100)
	   ,TblName VARCHAR(100)
	   ,ColName VARCHAR(100)
	   ,TypName VARCHAR(100)
	   ,MaxCount BIGINT
	   ,CurrCount BIGINT
    )
    CREATE INDEX idx_TableIdentityStats_TblName ON tbl_TableIdentityStats (TblName);
END TRY  
BEGIN CATCH  
    PRINT ERROR_NUMBER() + ' | ' + ERROR_SEVERITY() + ' | ' + ERROR_STATE() + ' | ' + ERROR_PROCEDURE() + ' | ' + ERROR_LINE() + ' | ' + ERROR_MESSAGE()  
END CATCH; 
DECLARE dbCur CURSOR LOCAL
FOR SELECT name AS DbName
    FROM sys.databases
    WHERE name not in ('master', 'model', 'msdb', 'tempdb', 'Resource', 'distribution' , 'reportserver', 'reportservertempdb')
BEGIN TRY
    PRINT '---> START';
    OPEN dbCur
    PRINT '---> OPEN CURSOR';
    FETCH NEXT FROM dbCur INTO @dbName
    WHILE @@FETCH_STATUS = 0   
    BEGIN
	   PRINT '*******************************************';
	   DECLARE @mainQry NVARCHAR(MAX) = '';
	   SET @mainQry = ''
	   SET @mainQry = @mainQry + ' SELECT '
	   SET @mainQry = @mainQry + ' CAST(DATEDIFF(S, ''19700101'', CAST(CURRENT_TIMESTAMP + 5000 AS datetime)) AS bigint)*1000 AS EpochTime'
	   SET @mainQry = @mainQry + ' , '''+@dbName+''' AS DbName	'
	   SET @mainQry = @mainQry + ' , SCHEMA_NAME(U.Schema_Id) AS SchName	'
	   SET @mainQry = @mainQry + ' , U.Name AS Tblname 	'
	   SET @mainQry = @mainQry + ' , C.Name AS Colname 	'
	   SET @mainQry = @mainQry + ' , T.Name AS Typname 	'
	   SET @mainQry = @mainQry + ' , CASE WHEN T.Name = ''bigint'' THEN ''9223372036854775807''	'
	   SET @mainQry = @mainQry + '	   WHEN T.Name = ''int'' THEN ''2147483648''	'
	   SET @mainQry = @mainQry + ' 	   WHEN T.Name = ''smallint'' THEN ''32768''	'
	   SET @mainQry = @mainQry + ' 	   WHEN T.Name = ''tinyint'' THEN ''128''	'
	   SET @mainQry = @mainQry + '        ELSE ''0''	'
	   SET @mainQry = @mainQry + '   END AS Maxcount	'
	   SET @mainQry = @mainQry + ' , IDENT_CURRENT('''+@dbName+'.''+SCHEMA_NAME(U.Schema_Id)+''.''+U.Name) AS CurrCount	'
	   SET @mainQry = @mainQry + ' FROM '+@dbName+'.Sys.Columns AS C JOIN '+@dbName+'.Sys.Tables AS U ON C.Object_Id = U.Object_Id AND U.Type = ''U''	'
	   SET @mainQry = @mainQry + '							JOIN '+@dbName+'.Sys.Types AS T ON C.User_Type_Id = T.User_Type_Id	'
	   SET @mainQry = @mainQry + ' WHERE Is_Identity = 1 ORDER BY IDENT_CURRENT('''+@dbName+'.''+SCHEMA_NAME(U.Schema_Id)+''.''+U.Name) DESC'

	   PRINT '---> Prepared Stmt : '+@mainQry
	   PRINT '*******************************************';
	   DECLARE @execQry NVARCHAR(MAX) = '';
	   SET @execQry= N'INSERT INTO '+@destTable+' '+ @mainQry + ' ' + ' SET @rows = @@ROWCOUNT'
	   EXEC sp_executesql @execQry, N'@rows INT OUTPUT', @rows = @rowsProcessed OUTPUT;
	   PRINT '---> Prepared Stmt : '+@execQry
	   PRINT '---> Rows Processed : '+CONVERT(VARCHAR,@rowsProcessed);
	   PRINT '*******************************************';
    FETCH NEXT FROM dbCur INTO @dbName   
    END;
    PRINT '---> INSERTED DATA INTO '+ @destTable;
    CLOSE dbCur;
    PRINT '---> DATA LOADED, CURSOR CLOSED';
    PRINT '---> END';
END TRY  
BEGIN CATCH  
    PRINT ERROR_NUMBER() + ' | ' + ERROR_SEVERITY() + ' | ' + ERROR_STATE() + ' | ' + ERROR_PROCEDURE() + ' | ' + ERROR_LINE() + ' | ' + ERROR_MESSAGE()  
END CATCH; 

GO