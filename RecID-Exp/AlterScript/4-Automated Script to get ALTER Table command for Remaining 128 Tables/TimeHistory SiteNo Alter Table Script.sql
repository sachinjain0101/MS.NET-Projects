--The below SQL Script is giving ALTER Script based on the Given TimeHistory Tables and columns list
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

--Inserting TimeHistory Tables	
INSERT INTO #InputTables(ColumnName, TableName) 
Values 	
--('SiteNo',	'tblTimeHistDetail'),
('SiteNo',	'zzJimResearch_TimeHistDetail'),
('SiteNo',	'tblEmplShifts'),
('SiteNo',	'tblTimeCards_Control_DELETE'),
('SiteWorkedAt',	'tblGambroUploads'),
('HomeSite',	'tblGambroUploads'),
('SiteChargedTo',	'tblGambroUploads'),
('SiteNo',	'tblAdjustments'),
('SiteNo',	'tblTimeHistDetail_ZeroSite'),
--('SiteNo',	'tblDeptNames'),
--('SiteNo',	'tblEmplSites_Depts'),
('SiteNo',	'tblEmplClass'),
('SiteNo',	'tblWork_TimeHistDetail'),
--('SiteNo',	'tblEmplSites'),
('SiteNo',	'tblWTE_Project_Archive'),
('SiteNo'	,'OLSTLegal'),
('InSite',	'tblPunchImport'),
('OutSite',	'tblPunchImport'),
('SiteNo',	'tblImportLog'),
('SiteNo',	'tblTimeHistDetail_Orig'),
('SiteNo',	'tblTimeHistDetail_GeoLocation'),
--('SiteNo',	'tblSiteNames'),
('SiteNo',	'tblTimeHistDetail_backup'),
('SiteNo',	'tblTimeHistDetail_COAS_pre'),
('SiteNo',	'tblDataFormStatus'),
('SiteNo',	'VANGlegal'),
('SiteNo',	'tblTimeHistDetail_Partial'),
('SiteNo',	'tblDataFormValues'),
('SiteNo',	'tblWork_TimeHistDetail2'),
('PrimarySite',	'tblEmplNames'),
('SiteNo',	'tblFixPunchAudit'),
('siteno',	'STFMCompassBank'),
('WorkedSiteNo',	'tblCIAHistory_DAVT'),
('PrimarySiteNo',	'tblCIAHistory_DAVT'),
('SiteNo',	'tblStdJobs'),
('SiteNo',	'tblStdJobs_Audit'),
('SiteNo',	'tblTimeHistDetail_DELETED'),
('SiteNo',	'ADVOlegal'),
('SiteNo',	'tblTimeCards_DELETE'),
('SiteNo',	'tblStdJobCellEmployees'),
('SiteNo',	'tblTimeHistDetail_COAS_post'),
('SiteNo',	'tblExpenseLineItems')


	
	
	----------------



DECLARE db_cursor CURSOR FOR

--SELECT name from SYS.TABLES

select TableName, ColumnName from #InputTables

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
	WHERE TABLE_NAME = @tablename and (DATA_TYPE = 'smallint' or DATA_TYPE = 'tinyint') and COLUMN_NAME=@inputcolname
			 --column_Name in ('SiteNo','ActualSiteNo','HomeSite','InSite','NewSiteNo','OldSiteNo','OutSite','PrimarySite','WorkedSiteNo','UploadAsSiteNo',
				--				'PrimarySiteNo','SiteChargedTo','SiteWorkedAt')
			
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
select DISTINCT TableName,COlumnName, OldDataType, AlterCommand from #outputAlterCmdTable order by 1
DROP TABLE #outputAlterCmdTable
DROP TABLE #InputTables