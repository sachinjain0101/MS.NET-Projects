
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
('DeptNo',	'tblDeptShiftDiffs'),
('DeptNo',	'tbl_DAVT_GroupDeptsPre802011'),
('PrimaryDept',	'zz_tblEmplNames'),
('Deptno',	'tblendava'),
('DeptNo',	'tblGroupDepts'),
('PrimaryDept',	'tblPayRules'),
('DeptNo',	'tblEmplAssignments_SESSION'),
('DeptNo',	'tblAdjustments'),
('PrimaryDept',	'tblEmplNames_Audit'),
('DeptNo',	'tblClusterDef'),
('DeptNo',	'tblSaliBudgetHoursTemp'),
('Department',	'tblEmplNames_Depts_Duplicates'),
('DeptNo',	'tblMCRequestDetail'),
('DeptNo',	'tblDeptShifts_DAVT'),
('OldDeptNo',	'tblFixedPunch'),
('NewDeptNo',	'tblFixedPunch'),
('DeptNo',	'tblWORK_DeptShiftDiffs'),
('DeptNo',	'tblEmplAllocation_Session'),
('Department',	'tblEmplNames_Depts_SESSION'),
('Department',	'tblEmplNames_Depts_Template'),
('PrimaryDept',	'tblEmplNames_SESSION'),
('DeptNo',	'tblRedirEmpDepts'),
--('DeptNo',	'tblDeptNames'),
('DeptNo',	'tblEmplSites_Depts_Template'),
('DeptNo',	'tblEmplSites_Depts_SESSION'),
--('DeptNo',	'tblEmplSites_Depts'),
('DeptNo',	'tblStdJobTemplates'),
--('Department',	'tblEmplNames_Depts'),
('DeptNo',	'tblDeptShiftDiffs_DAVT'),
--('DeptNo',	'tblEmplAssignments'),
('DefaultDeptNo',	'tblSiteNames'),
('PrimaryDept',	'tblEmplNames_Audit2'),
('Department',	'tblEmplNames_Depts_Audit2'),
('DeptNo',	'clim_coas_back'),
('DeptNo',	'tblClientDeptXref'),
('DeptNo',	'clim_coas_back2'),
('DeptNo',	'tblEmplSites_Depts_Audit2'),
('DeptNo',	'tblEmplAllocation'),
('DeptNo',	'tblDeptShifts_Audit2'),
('DeptNo',	'tblDeptShifts'),
('DeptNo',	'tblDeptShifts_DAVT2'),
('Department',	'diff_tblEmplNames_Depts'),
('DeptNo',	'diff_tblEmplSites_Depts'),
('DeptNo',	'tblOrderTemplates'),
('DeptNo',	'tblEmplAllocation_WORK'),
('Department',	'tblEmplNames_Depts_Audit'),
('PrimaryDept',	'tblEmplNames'),
('DeptNo',	'tblDeptShiftDiffs_DAVT2'),
('DeptNo',	'tblEmplSites_Depts_Audit'),
('PrimaryDept',	'tblEmplNames2'),
('DeptNo',	'tblJobOrders'),
('DeptNo','tblSaliBudgetHours')



	
	
	----------------



DECLARE db_cursor CURSOR FOR

--SELECT name from SYS.TABLES

select TableName,ColumnName from #InputTables

OPEN db_cursor  
FETCH NEXT FROM db_cursor INTO @tablename, @inputcolname 
WHILE @@FETCH_STATUS = 0  

BEGIN
	DECLARE table_cursor CURSOR FOR 
	--SELECT COLUMN_NAME,Data_Type FROM INFORMATION_SCHEMA.COLUMNS
	--WHERE TABLE_NAME = @tablename and (DATA_TYPE = 'smallint' or DATA_TYPE = 'tinyint') and
	--		 column_Name in ('SiteNo','ActualSiteNo','HomeSite','InSite','NewSiteNo','OldSiteNo','OutSite','PrimarySite','WorkedSiteNo','UploadAsSiteNo',
	--							'PrimarySiteNo','SiteChargedTo','SiteWorkedAt')

	SELECT COLUMN_NAME,Data_Type FROM INFORMATION_SCHEMA.COLUMNS
	WHERE TABLE_NAME = @tablename and (DATA_TYPE = 'smallint' or DATA_TYPE = 'tinyint') and COLUMN_NAME = @inputcolname
                     --column_Name in ('Department','DefaultDeptNo','DeptNo','newDept','NewDeptNo','OldDeptNo','PrimaryDept')
			
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