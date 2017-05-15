
USE TimeCurrent
GO

--SET NOCOUNT ON

DECLARE @Database NVARCHAR(100)
DECLARE @tblname NVARCHAR(100) 
DECLARE @DBSchema NVARCHAR(1000)

SET @Database = 'TimeCurrent'

/*** DROP TEMP TABLE IF EXISTS ***/
IF OBJECT_ID('#tmptbl1') IS NOT NULL
BEGIN	
	DROP TABLE #tmptbl1
	PRINT 'Table #tmptbl1 Dropped Succesfully'
END
IF OBJECT_ID('#OutPut') IS NOT NULL
BEGIN
	DROP TABLE #OutPut
	PRINT 'Table #OutPut Dropped Succesfully'
END
IF OBJECT_ID('#tmpStats') IS NOT NULL
BEGIN
	DROP TABLE #tmpStats
	PRINT 'Table #tmpStats Dropped Succesfully'
END

CREATE TABLE #tmptbl1(
	RecordId INT IDENTITY(1,1),
	DatabaseName NVARCHAR(100),
	TableName NVARCHAR(100),
	ColumnName1 NVARCHAR(100),
	ColumnName2 NVARCHAR(100),
	ColumnName3 NVARCHAR(100),
	ColumnName4 NVARCHAR(100),
	ColumnName5 NVARCHAR(100),
	ColumnName6 NVARCHAR(100),
	ColumnName7 NVARCHAR(100)
)		

CREATE TABLE #OutPut(
	DatabaseName NVARCHAR(1000),
	TableName NVARCHAR(1000),
	StatsName NVARCHAR(1000),
	CreateStatsScript NVARCHAR(MAX),
	DropStatsScript NVARCHAR(MAX)
)

CREATE TABLE #tmpStats (
	TableName	NVARCHAR(1000),
	StatisticsName NVARCHAR(1000),
	StatsColumn NVARCHAR(1000),
	StatsColumnID NVARCHAR(1000)
)


INSERT INTO #tmptbl1(DatabaseName,TableName,ColumnName1,columnname2,columnname3,columnname4,columnname5,columnname6,columnname7)
 Values (@Database,'clim_coas_back','SiteNo',NULL,'DeptNo',NULL,NULL,NULL,NULL)
	   ,(@Database,'clim_coas_back2','SiteNo',NULL,'DeptNo',NULL,NULL,NULL,NULL)
	   ,(@Database,'diff_tblEmplNames_Depts','Department',NULL,NULL,NULL,NULL,NULL,NULL)
	   ,(@Database,'diff_tblEmplSites','SiteNo',NULL,NULL,NULL,NULL,NULL,NULL)
	   ,(@Database,'diff_tblEmplSites_Depts','SiteNo',NULL,'DeptNo',NULL,NULL,NULL,NULL)
	   ,(@Database,'tbl_DAVT_GroupDeptsPre802011',NULL,NULL,'DeptNo',NULL,NULL,NULL,NULL)
	   ,(@Database,'tblAdjustments','SiteNo',NULL,'DeptNo',NULL,'THDRecordID','OrigRecord_No',NULL)
	   ,(@Database,'tblCigTransLog',NULL,NULL,NULL,NULL,'THDRecordID',NULL,NULL)
	   ,(@Database,'tblClientDeptXref','SiteNo','ActualSiteNo','DeptNo',NULL,NULL,NULL,NULL)
	   ,(@Database,'tblClusterDef','SiteNo',NULL,'DeptNo',NULL,NULL,NULL,NULL)
	   ,(@Database,'tblDavitaUploadCodes','SiteNo',NULL,NULL,NULL,NULL,NULL,NULL)
	   ,(@Database,'tblDavitaUploadCodes_Parallel','SiteNo',NULL,NULL,NULL,NULL,NULL,NULL)
	   ,(@Database,'tblDAVT_UploadCodes','SiteNo',NULL,NULL,NULL,NULL,NULL,NULL)
	   ,(@Database,'tblDAVT_UploadCodes_Audit','SiteNo',NULL,NULL,NULL,NULL,NULL,NULL)
	   ,(@Database,'tblDAVT_UploadCodes2','SiteNo',NULL,NULL,NULL,NULL,NULL,NULL)
	   --,(@Database,'tblDeptNames','SiteNo','DeptNo',NULL,NULL,NULL,NULL,NULL)--This table ALTERed through manual script by creating new table
		,(@Database,'tblDeptShiftChange','SiteNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblDeptShiftDiffs','DeptNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblDeptShiftDiffs_DAVT','DeptNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblDeptShiftDiffs_DAVT2','DeptNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblDeptShifts','DeptNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblDeptShifts_Audit2','DeptNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblDeptShifts_DAVT','DeptNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblDeptShifts_DAVT2','DeptNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblEmplAllocation','DeptNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblEmplAllocation_Session','DeptNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblEmplAllocation_WORK','DeptNo',NULL,NULL,NULL,NULL,NULL,NULL)
		--,(@Database,'tblEmplAssignments','DeptNo',NULL,NULL,NULL,NULL,NULL,NULL)--This table ALTERed through manual script by creating new table
		,(@Database,'tblEmplAssignments_SESSION','DeptNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblEmplChange','SiteNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblEmplChangeSSN','SiteNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblEmplClass','SiteNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblEmplMissingPunchAlert','THDRecordID',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblEmplNames','PrimarySite','PrimaryDept',NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblEmplNames_Audit','PrimarySite','PrimaryDept',NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblEmplNames_Audit2','PrimarySite','PrimaryDept',NULL,NULL,NULL,NULL,NULL)
		--,(@Database,'tblEmplNames_Depts','Department',NULL,NULL,NULL,NULL,NULL,NULL)--This table ALTERed through manual script by creating new table
		,(@Database,'tblEmplNames_Depts_Audit','Department',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblEmplNames_Depts_Audit2','Department',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblEmplNames_Depts_Duplicates','Department',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblEmplNames_Depts_SESSION','Department',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblEmplNames_Depts_Template','Department',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblEmplNames_SESSION','PrimarySite','PrimaryDept',NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblEmplNames2','PrimarySite','PrimaryDept',NULL,NULL,NULL,NULL,NULL)
		--,(@Database,'tblEmplSites','SiteNo',NULL,NULL,NULL,NULL,NULL,NULL)--This table ALTERed through manual script by creating new table
		,(@Database,'tblEmplSites_Audit','SiteNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblEmplSites_Audit2','SiteNo',NULL,NULL,NULL,NULL,NULL,NULL)
		--,(@Database,'tblEmplSites_Depts','SiteNo','DeptNo',NULL,NULL,NULL,NULL,NULL)--This table ALTERed through manual script by creating new table
		,(@Database,'tblEmplSites_Depts_Audit','SiteNo','DeptNo',NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblEmplSites_Depts_Audit2','SiteNo','DeptNo',NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblEmplSites_Depts_SESSION','SiteNo','DeptNo',NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblEmplSites_Depts_Template','SiteNo','DeptNo',NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblEmplSites_SESSION','SiteNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblEmplSites_Template','SiteNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblendava','DeptNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblFixedPunch','OldSiteNo','NewSiteNo','NewDeptNo','OldDeptNo','OrigRecordID','NewJobId','OldJobId')
		,(@Database,'tblGroupDepts','DeptNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblJobOrders','DeptNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblMCRequestDetail','SiteNo','DeptNo',NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblNotificationMessage','THDRecordID',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblOrderTemplates','SiteNo','DeptNo',NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblPATETxn','THDRecordID',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblPayRules','PrimarySite','PrimaryDept',NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblRedirEmpDepts','DeptNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblSaliBudgetHours','SiteNo','DeptNo',NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblSaliBudgetHoursTemp','SiteNo','DeptNo',NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblShiftDiffClasses','SiteNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblSiteNames','SiteNo','UploadAsSiteNo','DefaultDeptNo',NULL,NULL,NULL,NULL)
		,(@Database,'tblSiteNames_GeoLocation','SiteNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblSiteNames_Messages','SiteNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblSiteNamesIPRestriction','SiteNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblSiteNamesPhoneNumbers','SiteNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblSiteParm_Values','SiteNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblStdJobTemplates','SiteNo','DeptNo',NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblTempoDataLoadSnapShot','SiteNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblWORK_DeptShiftDiffs','DeptNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblWork_Waff','SiteNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'zz_tblEmplNames','PrimarySite','PrimaryDept',NULL,NULL,NULL,NULL,NULL)

--PRINT '#tmptbl1  inserted the tables list and cursor started for list of tables'

/*** CURSOR DECLARATION for Supplying the Table Names to generate Index Scripts ***/
DECLARE getstats CURSOR FOR

SELECT DatabaseName,TableName From #tmptbl1

OPEN getstats 
FETCH NEXT FROM getstats INTO @Database,@tblname

		WHILE @@FETCH_STATUS=0

		BEGIN
				--PRINT @tblname
				/**********************************/

				SET NOCOUNT ON
				--PRINT @DBSchema

				IF(SELECT COUNT(1) FROM #tmpStats) > 0
				BEGIN
					DELETE #tmpStats;
				END

				INSERT INTO #tmpStats

				SELECT 
						o.name AS Table_Name,
						s.name AS statistics_name,
						c.name AS column_name,
						sc.stats_column_id

				FROM sys.objects AS o 
				INNER JOIN sys.stats AS s on o.object_id = s.object_id 
				INNER JOIN sys.stats_columns AS sc 
					ON s.object_id = sc.object_id AND s.stats_id = sc.stats_id
				INNER JOIN sys.columns AS c 
					ON sc.object_id = c.object_id AND c.column_id = sc.column_id
				WHERE 
					--o.type = 'U' and o.name=@tblname
					s.user_created = 1 and o.name=@tblname

				DECLARE @StatsName NVARCHAR(1000)
				DECLARE @CreateStats NVARCHAR(2000)
				DECLARE @DropStats NVARCHAR(2000)

				--PRINT '#tmpStats inserted the tables list and cursor started for stats for the selected table'
				DECLARE statsdetails CURSOR FOR 

				SELECT DISTINCT StatisticsName From #tmpStats

				OPEN statsdetails 
				FETCH NEXT FROM statsdetails INTO @StatsName

				WHILE @@FETCH_STATUS=0

				BEGIN 

				--PRINT @StatsName
				 
				--SET @StatsName = (SELECT DISTINCT(StatisticsName) FROM #tmpStats where StatisticsName = @StatsName)
				--SET @DBSchema = (SELECT DISTINCT (TABLE_SCHEMA),TABLE_CATALOG  FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = @tblname AND TABLE_CATALOG = @Database)

				SET @CreateStats = (SELECT DISTINCT 'CREATE STATISTICS' +' ['+@StatsName+'] ON [dbo].['+@tblname+'] ('+ StatisticsColumns +')' AS CreateStatsScript
										FROM   (
											SELECT                                  
												  STUFF(
													  (
														SELECT ' , '+'['+ C.name +']' 
														  FROM sys.objects AS o 
																INNER JOIN sys.stats AS s on o.object_id = s.object_id
																INNER JOIN sys.stats_columns AS sc 
																	ON s.object_id = sc.object_id AND s.stats_id = sc.stats_id
																INNER JOIN sys.columns AS c 
																	ON sc.object_id = c.object_id AND c.column_id = sc.column_id
																WHERE 
																	s.user_created=1 and o.name = @tblname AND s.name = @StatsName

														  GROUP BY
																 s.name,
																 c.name
																 FOR XML PATH('')
													  ),
													  1,
													  2,
													  ''
												  ) StatisticsColumns
										   FROM   sys.objects AS os
													----			INNER JOIN sys.stats AS ss on os.object_id = ss.object_id
													----			INNER JOIN sys.stats_columns AS ssc 
													----				ON ss.object_id = ssc.object_id AND ss.stats_id = ssc.stats_id
													----			INNER JOIN sys.columns AS sc 
													----				ON sc.object_id = sc.object_id AND sc.column_id = ssc.column_id
													----			WHERE 
													----				os.type = 'U' and os.name = 'tbltimehistdetail' AND ss.name = 'tblTimeHistDetail_ClientGrpPPSSNEtc'-- and os.name=@tblname AND ss.name = @StatsName
						 ----                      --WHERE IC2.Object_id = object_id(@tblname) --Comment for all tables
						 ----                  GROUP BY
										   ----Ss.name,sc.column_id
                                 
					) tmp1 )


				SET @DropStats = (SELECT 'DROP STATISTICS' +' ['+@StatsName+'] ON [dbo].['+@tblname+']')


				INSERT INTO #OutPut(DatabaseName,TableName,StatsName,CreateStatsScript,DropStatsScript) Values (@Database,@tblname,@StatsName,@CreateStats,@DropStats)

				FETCH NEXT FROM statsdetails INTO @StatsName				
		END

		CLOSE statsdetails
		DEALLOCATE statsdetails

		FETCH NEXT FROM getstats INTO @Database,@tblname

END

CLOSE getstats
DEALLOCATE getstats

SELECT * FROM #OutPut ORDER BY 2

DROP TABLE #tmptbl1
DROP TABLE #OutPut
DROP TABLE #tmpStats
				    
--WHERE  StatisticsColumns IS NOT NULL