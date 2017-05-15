
USE TimeHistory
GO

--SET NOCOUNT ON

DECLARE @Database NVARCHAR(100)
DECLARE @tblname NVARCHAR(100) 
DECLARE @DBSchema NVARCHAR(1000)

SET @Database = 'TimeHistory'

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
 Values (@Database,'ADVOlegal','SiteNo','PrimaryDept','DeptNo',NULL,NULL,NULL,NULL)
	   ,(@Database,'Extract_Hashbytes_MatchingTable','RecordId',NULL,NULL,NULL,NULL,NULL,NULL)
	   ,(@Database,'OLSTLegal','SiteNo','PrimaryDept','DeptNo',NULL,NULL,NULL,NULL)
	   ,(@Database,'STFMCompassBank','SiteNo','NewDept','DeptNo',NULL,NULL,NULL,NULL)
	   ,(@Database,'tblAdjustments','SiteNo',NULL,'DeptNo',NULL,NULL,NULL,NULL)
	   ,(@Database,'tblBudgetData',NULL,NULL,NULL,NULL,'DeptNo',NULL,NULL)
	   ,(@Database,'tblCIAHistory_DAVT','PrimarySiteNo','WorkedSiteNo',NULL,NULL,NULL,NULL,NULL)
	   ,(@Database,'tblCOAS_Screwup',NULL,NULL,'DeptNo',NULL,NULL,NULL,NULL)
	   ,(@Database,'tblCOAS_Screwup2','DeptNo',NULL,NULL,NULL,NULL,NULL,NULL)
	   ,(@Database,'tblDataFormStatus','SiteNo',NULL,NULL,NULL,NULL,NULL,NULL)
	   ,(@Database,'tblDataFormValues','SiteNo',NULL,NULL,NULL,NULL,NULL,NULL)
	   ,(@Database,'tblDeptShifts','DeptNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblEmplClass','SiteNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblEmplMissingPuncgReceipt','RecordId',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblEmplNames','PrimarySite',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblEmplShifts','DeptNo','SiteNo',NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblExpenseLineItems','DeptNo','SiteNo',NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblFixedPunchByEE','RecordId',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblFixPunchAudit','SiteNo','DeptNo','OrigRecordId',NULL,NULL,NULL,NULL)
		,(@Database,'tblGambroUploads','SiteWorkedAt','HomeSite','SiteChargedTo','DeptNo',NULL,NULL,NULL)
		,(@Database,'tblImportLog','SiteNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblKronosPunchExport',NULL,'THDRecordId',NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblKronosPunchExport_Audit','THDRecordId',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblPunchImport','InSite','DeptNo','OutSite',NULL,NULL,NULL,NULL)
		,(@Database,'tblStaffingApproval_THD','THDRecordId',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblSTAFRevman_Extract','RecordId',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblStdJobCellEmployees','SiteNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblStdJobs','SiteNo','DeptNo',NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblStdJobs_Audit','SiteNo','DeptNo',NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblTimeCards_Control_DELETE','SiteNo','DeptNo',NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblTimeCards_DELETE','SiteNo','DeptNo',NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblTimeHistDetail_backup','SiteNo','DeptNo',NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblTimeHistDetail_BackupApproval','THDRecordId',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblTimeHistDetail_COAS_post','SiteNo','DeptNo',NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblTimeHistDetail_COAS_pre','SiteNo','DeptNo',NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblTimeHistDetail_Crossover','FromRecordId','ToRecordId',NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblTimeHistDetail_DELETED','SiteNo','DeptNo',NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblTimeHistDetail_Disputes','DetailRecordId',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblTimeHistDetail_Faxaroo','THD_RecordId',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblTimeHistDetail_GeoLocation','SiteNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblTimeHistDetail_Orig','SiteNo',NULL,'DeptNo',NULL,NULL,NULL,NULL)
		,(@Database,'tblTimeHistDetail_Partial','DeptNo','SiteNo','RecordId','AprvlAdjOrigRecID','ClkTransNo','DivisionId',NULL)
		,(@Database,'tblTimeHistDetail_PATE','THDRecordId',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblTimeHistDetail_Reasons','AdjustmentRecordID',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblTimeHistDetail_UDF','THDRecordID',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblTimeHistDetail_ZeroSite','SiteNo','DeptNo',NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblTimeHistSum','SiteNo','DeptNo',NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblTimeHistSum_BreakDown','SiteNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblWork_KronosExport','THDRecordID',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblWork_TimeHistDetail','SiteNo','DeptNo','RecordId',NULL,NULL,NULL,NULL)
		,(@Database,'tblWork_TimeHistDetail2','SiteNo','DeptNo',NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblWTE_Project_Archive','SiteNo',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'tblWTE_Spreadsheet_Breaks','InOutId',NULL,NULL,NULL,NULL,NULL,NULL)
		,(@Database,'VANGlegal','SiteNo','DeptNo','PrimaryDept',NULL,NULL,NULL,NULL)
		,(@Database,'zzJimResearch_TimeHistDetail','SiteNo','DeptNo',NULL,NULL,NULL,NULL,NULL)

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