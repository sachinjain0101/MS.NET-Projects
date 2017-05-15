
--The below SQL Script is giving ALTER Scriptbased on the Given TimeCurrent Tables and columns list


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
('SiteNo',	'tblDAVT_UploadCodes_Audit'),
('SiteNo',	'tblSaliBudgetHours'),
('SiteNo',	'tblEmplClass'),
('PrimarySite',	'zz_tblEmplNames'),
('SiteNo',	'tblShiftDiffClasses'),
('SiteNo',	'tblEmplSites_Audit2'),
('SiteNo','tblSiteNames_Messages'),
('PrimarySite','tblPayRules'),
--('SiteNo','tblEmplSites'),
('SiteNo','tblAdjustments'),
('PrimarySite','tblEmplNames_Audit'),
('SiteNo','tblClusterDef'),
('SiteNo',	'tblSiteNamesIPRestriction'),
('SiteNo',	'tblSaliBudgetHoursTemp'),
('SiteNo'	,'tblSiteParm_Values'),
('SiteNo',	'tblMCRequestDetail'),
('OldSiteNo',	'tblFixedPunch'),
('NewSiteNo',	'tblFixedPunch'),
('PrimarySite',	'tblEmplNames_SESSION'),
--('SiteNo',	'tblDeptNames'),
('SiteNo',	'tblEmplSites_Depts_Template'),
('SiteNo',	'tblEmplSites_SESSION'),
('SiteNo',	'tblEmplSites_Template'),
('SiteNo',	'tblEmplChange'),
('SiteNo',	'tblEmplSites_Depts_SESSION'),
--('SiteNo',	'tblEmplSites_Depts'),
('SiteNo',	'tblTempoDataLoadSnapShot'),
('SiteNo',	'tblStdJobTemplates'),
('SiteNo',	'tblSiteNames_GeoLocation'),
('SiteNo',	'tblEmplChangeSSN'),
('SiteNo',	'tblSiteNames'),
('UploadAsSiteNo',	'tblSiteNames'),
('PrimarySite',	'tblEmplNames_Audit2'),
('SiteNo',	'tblDeptShiftChange'),
('SiteNo',	'clim_coas_back'),
('SiteNo',	'tblClientDeptXref'),
('ActualSiteNo',	'tblClientDeptXref'),
('SiteNo',	'clim_coas_back2'),
('SiteNo',	'tblDAVT_UploadCodes2'),
('SiteNo',	'tblEmplSites_Depts_Audit2'),
('SiteNo','tblDavitaUploadCodes_Parallel'),
('SiteNo',	'tblWork_Waff'),
('SiteNo',	'tblDAVT_UploadCodes'),
('SiteNo',	'diff_tblEmplSites'),
('SiteNo',	'diff_tblEmplSites_Depts'),
('SiteNo',	'tblOrderTemplates'),
('PrimarySite',	'tblEmplNames'),
('SiteNo',	'tblEmplSites_Audit'),
('SiteNo',	'tblDavitaUploadCodes'),
('SiteNo',	'tblEmplSites_Depts_Audit'),
('PrimarySite',	'tblEmplNames2'),
('SiteNo',	'tblSiteNamesPhoneNumbers')

	
	
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