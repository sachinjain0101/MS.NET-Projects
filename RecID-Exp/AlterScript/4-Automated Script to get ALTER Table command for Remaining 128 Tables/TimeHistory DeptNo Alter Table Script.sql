
use TimeHistory

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
--('DeptNo',	'tblTimeHistDetail'),
('DeptNo',	'zzJimResearch_TimeHistDetail'),
('DeptNo',	'tblEmplShifts'),
('DeptNo',	'tblDeptShifts'),
('DeptNo',	'tblGambroUploads'),
('DeptNo',	'tblAdjustments'),
('DeptNo',	'tblTimeHistDetail_ZeroSite'),
--('DeptNo',	'tblDeptNames'),
--('DeptNo',	'tblEmplSites_Depts'),
('deptno',	'tblCOAS_Screwup'),
('deptno',	'tblCOAS_Screwup2'),
('DeptNo',	'tblWork_TimeHistDetail'),
--('Department',	'tblEmplNames_Depts'),
('PrimaryDept',	'OLSTLegal'),
('DeptNo',	'OLSTLegal'),
('DeptNo',	'tblPunchImport'),
('DeptNo',	'tblTimeHistDetail_Orig'),
('DeptNo',	'tblBudgetData'),
('DeptNo',	'tblTimeHistDetail_backup'),
('DeptNo',	'tblTimeHistDetail_COAS_pre'),
('PrimaryDept',	'VANGlegal'),
('DeptNo',	'VANGlegal'),
('DeptNo',	'tblTimeHistDetail_Partial'),
('DeptNo',	'tblWork_TimeHistDetail2'),
('DeptNo',	'tblFixPunchAudit'),
('deptno',	'STFMCompassBank'),
('newdept',	'STFMCompassBank'),
('DeptNo',	'tblStdJobs'),
('DeptNo',	'tblStdJobs_Audit'),
('DeptNo',	'tblTimeHistDetail_DELETED'),
('PrimaryDept',	'ADVOlegal'),
('DeptNo',	'ADVOlegal'),
('DeptNo',	'tblTimeHistDetail_COAS_post'),
('DeptNo',	'tblExpenseLineItems'),
('DeptNo', 'tblTimeCards_Control_DELETE'),
('DeptNo', 'tblTimeCards_DELETE')




	
	
	----------------



DECLARE db_cursor CURSOR FOR

--SELECT name from SYS.TABLES

select TableName,ColumnName from #InputTables

OPEN db_cursor  
FETCH NEXT FROM db_cursor INTO @tablename,@inputcolname 
WHILE @@FETCH_STATUS = 0  

BEGIN
	DECLARE table_cursor CURSOR FOR 
	--SELECT COLUMN_NAME,Data_Type FROM INFORMATION_SCHEMA.COLUMNS
	--WHERE TABLE_NAME = @tablename and (DATA_TYPE = 'smallint' or DATA_TYPE = 'tinyint') and
	--		 column_Name in ('SiteNo','ActualSiteNo','HomeSite','InSite','NewSiteNo','OldSiteNo','OutSite','PrimarySite','WorkedSiteNo','UploadAsSiteNo',
	--							'PrimarySiteNo','SiteChargedTo','SiteWorkedAt')

	SELECT COLUMN_NAME,Data_Type FROM INFORMATION_SCHEMA.COLUMNS
	WHERE TABLE_NAME = @tablename and (DATA_TYPE = 'smallint' or DATA_TYPE = 'tinyint') and COLUMN_NAME = @inputcolname
                    -- column_Name in ('Department','DefaultDeptNo','DeptNo','newDept','NewDeptNo','OldDeptNo','PrimaryDept')
			
	OPEN table_cursor  
	FETCH NEXT FROM table_cursor INTO @colname,@PrevDataType  
		WHILE @@FETCH_STATUS = 0  
	BEGIN
	
	
			SET @command = 'ALTER TABLE ' + @tablename + ' ' + 'ALTER COLUMN ' + @colname + ' INT;'
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