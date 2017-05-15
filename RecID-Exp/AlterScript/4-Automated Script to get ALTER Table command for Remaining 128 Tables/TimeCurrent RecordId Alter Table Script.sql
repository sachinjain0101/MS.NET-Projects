
use TimeCurrent

DECLARE @tablename VARCHAR(256) /*table name*/
DECLARE @colname VARCHAR(256) /*column name*/
DECLARE @inputcolname VARCHAR(256) /*column name*/
DECLARE @PrevDataType VARCHAR(256)
DECLARE @command VARCHAR(4000)

Create Table #outputAlterCmdTable(No INT IDENTITY(1,1), TableName varchar(500), ColumnName VARCHAR(500), 
OldDataType VARCHAR(100),AlterCommand VARCHAR(4000))

Create Table #InputTables(Id INT IDENTITY(1,1),
	ColumnName VARCHAR(100),
	TableName VARCHAR(100))

--Inserting TimeCurrent Tables	
INSERT INTO #InputTables(ColumnName, TableName) 
Values 	
('OrigRecordID',	'tblFixedPunch'),
('THDRecordID',	'tblAdjustments'),
('THDRecordID',	'tblCigTransLog'),
('THDRecordID',	'tblEmplMissingPunchAlert'),
('THDRecordID',	'tblNotificationMessage'),
('THDRecordID',	'tblPATETxn'),
('OrigRecord_No',	'tblAdjustments'),
('NewJobId',	'tblFixedPunch'),
('OldJobId',	'tblFixedPunch')
	
		
	----------------



DECLARE db_cursor CURSOR FOR

--SELECT name from SYS.TABLES

select TableName,ColumnName from #InputTables

OPEN db_cursor  
FETCH NEXT FROM db_cursor INTO @tablename,@inputcolname 
WHILE @@FETCH_STATUS = 0  

BEGIN
	DECLARE table_cursor CURSOR FOR 
	
	SELECT COLUMN_NAME,Data_Type FROM INFORMATION_SCHEMA.COLUMNS
	WHERE TABLE_NAME = @tablename and (DATA_TYPE = 'int') and   column_Name = @inputcolname
                    -- column_Name in ('OrigRecordID','THDRecordID','OrigRecord_No','NewJobId','OldJobId')
			
	OPEN table_cursor  
	FETCH NEXT FROM table_cursor INTO @colname,@PrevDataType  
		WHILE @@FETCH_STATUS = 0  
	BEGIN
	
	
			SET @command = 'ALTER TABLE ' + @tablename + ' ' + 'ALTER COLUMN ' + @colname + ' BIGINT;'
	INSERT INTO #outputAlterCmdTable(TableName,COlumnName, OldDataType, AlterCommand)
	VALUES(@tablename,@colname,@PrevDataType,@command)
			
	--PRINT 'Running: ' + @command
	
	--EXEC (@command)
	  FETCH NEXT FROM table_cursor INTO @colname,@PrevDataType 
	END  
			CLOSE table_cursor  
			DEALLOCATE table_cursor  

FETCH NEXT FROM db_cursor INTO @tablename,@inputcolname

END

CLOSE db_cursor  
DEALLOCATE db_cursor
select DISTINCT TableName,COlumnName, OldDataType, AlterCommand from #outputAlterCmdTable  order by 1,2
DROP TABLE #outputAlterCmdTable
DROP TABLE #InputTables