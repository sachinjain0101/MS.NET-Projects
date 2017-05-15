--TimeHistory-Indexes create/delete related script

/*******************************************************************
The Below Script is Responsible for generating the 
CREATE INDEX Scripts based on the required column name,table name and 
database name across environments
*******************************************************************/
Use TimeHistory
GO


DECLARE @Database NVARCHAR(100)
DECLARE @tblname NVARCHAR(100) 
DECLARE @tblcolname1 NVARCHAR(100)
DECLARE @tblcolname2 NVARCHAR(100)
DECLARE @tblcolname3 NVARCHAR(100)
DECLARE @tblcolname4 NVARCHAR(100)
DECLARE @tblcolname5 NVARCHAR(100)
DECLARE @tblcolname6 NVARCHAR(100)
DECLARE @tblcolname7 NVARCHAR(100)

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

/*** CREATE TEMP TABLE to Accumulate neccessary Tables ***/
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
	IndexName NVARCHAR(1000),
	CreateIndexScript NVARCHAR(MAX),
	DropIndexScript NVARCHAR(MAX)
)

/*** INSERT the required Tables to get the Indexes ***/


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
		
		

    


/*** CURSOR DECLARATION for Supplying the Table Names to generate Index Scripts ***/
DECLARE gettblnames CURSOR FOR

SELECT DatabaseName,TableName,columnname1,columnname2,columnname3,columnname4,columnname5,columnname6,columnname7 From #tmptbl1

OPEN gettblnames 
FETCH NEXT FROM gettblnames INTO @Database,@tblname,@tblcolname1,@tblcolname2,@tblcolname3,@tblcolname4,@tblcolname5,@tblcolname6,@tblcolname7

PRINT @@FETCH_STATUS

WHILE @@FETCH_STATUS=0

BEGIN
DECLARE @ClusterRecordCount INT

SELECT @ClusterRecordCount = (Select Count(st1.ClusteredIndexName) from (
SELECT
    TableName = t.name, 
    ClusteredIndexName = i.name,
    ColumnName = c.Name
FROM
    sys.tables t
INNER JOIN 
    sys.indexes i ON t.object_id = i.object_id
INNER JOIN 
    sys.index_columns ic ON i.index_id = ic.index_id AND i.object_id = ic.object_id
INNER JOIN 
    sys.columns c ON ic.column_id = c.column_id AND ic.object_id = c.object_id
WHERE
    i.index_id = 1  -- clustered index
    AND c.is_identity = 0 AND t.name =@tblname --AND c.name = @tblcolname  --t.name = @tblname 
) AS st1 )

IF @ClusterRecordCount >= 1 

BEGIN

INSERT INTO #OutPut( DatabaseName,TableName,IndexName,CreateIndexScript,DropIndexScript) (SELECT * FROM (

SELECT @Database as DatabaseName,T.name As TableName,I.name As IndexName, ' CREATE ' +
       CASE 
            WHEN I.is_unique = 1 THEN ' UNIQUE '
            ELSE ''
       END +
       I.type_desc COLLATE DATABASE_DEFAULT + ' INDEX ' +
       I.name + ' ON ' +
       SCHEMA_NAME(T.schema_id) + '.' + T.name + ' ( ' +
       KeyColumns + ' )  ' +
       ISNULL(' INCLUDE (' + IncludedColumns + ' ) ', '') +
       ISNULL(' WHERE  ' + I.filter_definition, '') + ' WITH ( ' +
       CASE 
            WHEN I.is_padded = 1 THEN ' PAD_INDEX = ON '
            ELSE ' PAD_INDEX = OFF '
       END + ',' +
       'FILLFACTOR = ' + CONVERT(
           CHAR(5),
           CASE 
                WHEN I.fill_factor = 0 THEN 100
                ELSE I.fill_factor
           END
       ) + ',' +
       -- default value 
       'SORT_IN_TEMPDB = OFF ' + ',' +
       CASE 
            WHEN I.ignore_dup_key = 1 THEN ' IGNORE_DUP_KEY = ON '
            ELSE ' IGNORE_DUP_KEY = OFF '
       END + ',' +
       CASE 
            WHEN ST.no_recompute = 0 THEN ' STATISTICS_NORECOMPUTE = OFF '
            ELSE ' STATISTICS_NORECOMPUTE = ON '
       END + ',' +
       ' ONLINE = OFF ' + ',' +
       CASE 
            WHEN I.allow_row_locks = 1 THEN ' ALLOW_ROW_LOCKS = ON '
            ELSE ' ALLOW_ROW_LOCKS = OFF '
       END + ',' +
       CASE 
            WHEN I.allow_page_locks = 1 THEN ' ALLOW_PAGE_LOCKS = ON '
            ELSE ' ALLOW_PAGE_LOCKS = OFF '
       END + ' ) GO' [CreateIndexScript], N'DROP INDEX '+QUOTENAME(I.name) + ' ON [dbo].' + '['+@tblname+']' AS DropIndexScript
FROM   sys.indexes I
       JOIN sys.tables T
            ON  T.object_id = I.object_id
       JOIN sys.sysindexes SI
            ON  I.object_id = SI.id
            AND I.index_id = SI.indid
       JOIN (
                SELECT *
                FROM   (
                           SELECT IC2.object_id,
                                  IC2.index_id,
                                  STUFF(
                                      (
                                          SELECT ' , '+'['+ C.name +']' + CASE 
                                                                       WHEN MAX(CONVERT(INT, IC1.is_descending_key)) 
                                                                            = 1 THEN 
                                                                            ' DESC '
                                                                       ELSE 
                                                                            ' ASC '
                                                                  END
                                          FROM   sys.index_columns IC1
                                                 JOIN sys.columns C
                                                      ON  C.object_id = IC1.object_id
                                                      AND C.column_id = IC1.column_id
                                                      AND IC1.is_included_column = 
                                                       0
                                          WHERE  IC1.object_id = IC2.object_id --AND c.name in (@tblcolname)
                                                 AND IC1.index_id = IC2.index_id
                                          GROUP BY
                                                 IC1.object_id,
                                                 C.name,
                                                 index_id
                                          ORDER BY
                                                 MAX(IC1.key_ordinal) 
                                                 FOR XML PATH('')
                                      ),
                                      1,
                                      2,
                                      ''
                                  ) KeyColumns
                           FROM   sys.index_columns IC2 
                                 WHERE IC2.Object_id = object_id(@tblname) --Comment for all tables
                           GROUP BY
                                  IC2.object_id,
                                  IC2.index_id
                       ) tmp3
            )tmp4
            ON  I.object_id = tmp4.object_id
            AND I.Index_id = tmp4.index_id
       JOIN sys.stats ST
            ON  ST.object_id = I.object_id
            AND ST.stats_id = I.index_id
       JOIN sys.data_spaces DS
            ON  I.data_space_id = DS.data_space_id
       JOIN sys.filegroups FG
            ON  I.data_space_id = FG.data_space_id
       LEFT JOIN (
                SELECT *
                FROM   (
                           SELECT IC2.object_id,
                                  IC2.index_id,
                                  STUFF(
                                      (
                                            SELECT ' , '+'['+ C.name +']' 
                                          FROM   sys.index_columns IC1
                                                 JOIN sys.columns C
                                                      ON  C.object_id = IC1.object_id
                                                      AND C.column_id = IC1.column_id
                                                      AND IC1.is_included_column = 
                                                          1
                                          WHERE   IC1.object_id = IC2.object_id --AND c.name in (@tblcolname)
                                                 AND IC1.index_id = IC2.index_id
                                          GROUP BY
                                                 IC1.object_id,
                                                 C.name,
                                                 index_id 
                                                 FOR XML PATH('')
                                      ),
                                      1,
                                      2,
                                      ''
                                  ) IncludedColumns
                           FROM   sys.index_columns IC2 
                                 WHERE IC2.Object_id = object_id(@tblname) --Comment for all tables
                           GROUP BY
                                  IC2.object_id,
                                  IC2.index_id
                       ) tmp1
                WHERE  IncludedColumns IS NOT NULL
            ) tmp2
            ON  tmp2.object_id = I.object_id
            AND tmp2.index_id = I.index_id
WHERE -- I.is_primary_key = 0
       --AND I.is_unique_constraint = 0
           --AND I.Object_id = object_id(@tblname) --Comment for all tables
		   I.Object_id = object_id(@tblname) 
           --AND I.name = 'IX_Address_PostalCode' --comment for all indexes 
) tblindexes 
WHERE 
tblindexes.CreateIndexScript LIKE '%'+@tblcolname1+'%' or tblindexes.CreateIndexScript LIKE '%'+@tblcolname2+'%' or tblindexes.CreateIndexScript LIKE '%'+@tblcolname3+'%' or tblindexes.CreateIndexScript LIKE '%'+@tblcolname4+'%' or tblindexes.CreateIndexScript LIKE '%'+@tblcolname5+'%' or tblindexes.CreateIndexScript LIKE '%'+@tblcolname6+'%' or tblindexes.CreateIndexScript LIKE '%'+@tblcolname7+'%' ) -- Getting the INDEX Scripts based on the required Column Name

--PRINT 'Execute for ' + @tblname
END
ELSE
/*********** GENERATE SCRIPT FOR CREATE INDEXES ************/
INSERT INTO #OutPut( DatabaseName,TableName,IndexName,CreateIndexScript,DropIndexScript) (SELECT * FROM (

SELECT @Database as DatabaseName,T.name As TableName,I.name As IndexName, ' CREATE ' +
       CASE 
            WHEN I.is_unique = 1 THEN ' UNIQUE '
            ELSE ''
       END +
       I.type_desc COLLATE DATABASE_DEFAULT + ' INDEX ' +
       I.name + ' ON ' +
       SCHEMA_NAME(T.schema_id) + '.' + T.name + ' ( ' +
       KeyColumns + ' )  ' +
       ISNULL(' INCLUDE (' + IncludedColumns + ' ) ', '') +
       ISNULL(' WHERE  ' + I.filter_definition, '') + ' WITH ( ' +
       CASE 
            WHEN I.is_padded = 1 THEN ' PAD_INDEX = ON '
            ELSE ' PAD_INDEX = OFF '
       END + ',' +
       'FILLFACTOR = ' + CONVERT(
           CHAR(5),
           CASE 
                WHEN I.fill_factor = 0 THEN 100
                ELSE I.fill_factor
           END
       ) + ',' +
       -- default value 
       'SORT_IN_TEMPDB = OFF ' + ',' +
       CASE 
            WHEN I.ignore_dup_key = 1 THEN ' IGNORE_DUP_KEY = ON '
            ELSE ' IGNORE_DUP_KEY = OFF '
       END + ',' +
       CASE 
            WHEN ST.no_recompute = 0 THEN ' STATISTICS_NORECOMPUTE = OFF '
            ELSE ' STATISTICS_NORECOMPUTE = ON '
       END + ',' +
       ' ONLINE = OFF ' + ',' +
       CASE 
            WHEN I.allow_row_locks = 1 THEN ' ALLOW_ROW_LOCKS = ON '
            ELSE ' ALLOW_ROW_LOCKS = OFF '
       END + ',' +
       CASE 
            WHEN I.allow_page_locks = 1 THEN ' ALLOW_PAGE_LOCKS = ON '
            ELSE ' ALLOW_PAGE_LOCKS = OFF '
       END + ' ) GO' [CreateIndexScript], N'DROP INDEX '+QUOTENAME(I.name) + ' ON [dbo].' + '['+@tblname+']' AS DropIndexScript
FROM   sys.indexes I
       JOIN sys.tables T
            ON  T.object_id = I.object_id
       JOIN sys.sysindexes SI
            ON  I.object_id = SI.id
            AND I.index_id = SI.indid
       JOIN (
                SELECT *
                FROM   (
                           SELECT IC2.object_id,
                                  IC2.index_id,
                                  STUFF(
                                      (
                                          SELECT ' , '+'['+ C.name +']' + CASE 
                                                                       WHEN MAX(CONVERT(INT, IC1.is_descending_key)) 
                                                                            = 1 THEN 
                                                                            ' DESC '
                                                                       ELSE 
                                                                            ' ASC '
                                                                  END
                                          FROM   sys.index_columns IC1
                                                 JOIN sys.columns C
                                                      ON  C.object_id = IC1.object_id
                                                      AND C.column_id = IC1.column_id
                                                      AND IC1.is_included_column = 
                                                       0
                                          WHERE  IC1.object_id = IC2.object_id --AND c.name in (@tblcolname)
                                                 AND IC1.index_id = IC2.index_id
                                          GROUP BY
                                                 IC1.object_id,
                                                 C.name,
                                                 index_id
                                          ORDER BY
                                                 MAX(IC1.key_ordinal) 
                                                 FOR XML PATH('')
                                      ),
                                      1,
                                      2,
                                      ''
                                  ) KeyColumns
                           FROM   sys.index_columns IC2 
                                 WHERE IC2.Object_id = object_id(@tblname) --Comment for all tables
                           GROUP BY
                                  IC2.object_id,
                                  IC2.index_id
                       ) tmp3
            )tmp4
            ON  I.object_id = tmp4.object_id
            AND I.Index_id = tmp4.index_id
       JOIN sys.stats ST
            ON  ST.object_id = I.object_id
            AND ST.stats_id = I.index_id
       JOIN sys.data_spaces DS
            ON  I.data_space_id = DS.data_space_id
       JOIN sys.filegroups FG
            ON  I.data_space_id = FG.data_space_id
       LEFT JOIN (
                SELECT *
                FROM   (
                           SELECT IC2.object_id,
                                  IC2.index_id,
                                  STUFF(
                                      (
                                            SELECT ' , '+'['+ C.name +']' 
                                          FROM   sys.index_columns IC1
                                                 JOIN sys.columns C
                                                      ON  C.object_id = IC1.object_id
                                                      AND C.column_id = IC1.column_id
                                                      AND IC1.is_included_column = 
                                                          1
                                          WHERE   IC1.object_id = IC2.object_id --AND c.name in (@tblcolname)
                                                 AND IC1.index_id = IC2.index_id
                                          GROUP BY
                                                 IC1.object_id,
                                                 C.name,
                                                 index_id 
                                                 FOR XML PATH('')
                                      ),
                                      1,
                                      2,
                                      ''
                                  ) IncludedColumns
                           FROM   sys.index_columns IC2 
                                 WHERE IC2.Object_id = object_id(@tblname) --Comment for all tables
                           GROUP BY
                                  IC2.object_id,
                                  IC2.index_id
                       ) tmp1
                WHERE  IncludedColumns IS NOT NULL
            ) tmp2
            ON  tmp2.object_id = I.object_id
            AND tmp2.index_id = I.index_id
WHERE -- I.is_primary_key = 0
       --AND I.is_unique_constraint = 0
         --  AND I.Object_id = object_id(@tblname) --Comment for all tables
		 I.Object_id = object_id(@tblname)
           --AND I.name = 'IX_Address_PostalCode' --comment for all indexes 
) tblindexes 

WHERE tblindexes.CreateIndexScript LIKE '%'+@tblcolname1+'%' or tblindexes.CreateIndexScript LIKE '%'+@tblcolname2+'%' or tblindexes.CreateIndexScript LIKE '%'+@tblcolname3+'%' or tblindexes.CreateIndexScript LIKE '%'+@tblcolname4+'%' or tblindexes.CreateIndexScript LIKE '%'+@tblcolname5+'%' or tblindexes.CreateIndexScript LIKE '%'+@tblcolname6+'%' or tblindexes.CreateIndexScript LIKE '%'+@tblcolname7+'%' ) -- Getting the INDEX Scripts based on the required Column Name

PRINT 'Successfully Processed for ' + @tblname

FETCH NEXT FROM gettblnames INTO @Database,@tblname,@tblcolname1,@tblcolname2,@tblcolname3,@tblcolname4,@tblcolname5,@tblcolname6,@tblcolname7

END

CLOSE gettblnames
DEALLOCATE gettblnames

--SELECT distinct tablename FROM #OutPut
SELECT * FROM #OutPut

--This Section can be uncommented for simultaneous CREATE & DROP Indexes

----/*** DROP INDEX SECTION ***/
----DECLARE @indxname NVARCHAR(1000)
----DECLARE @sql NVARCHAR(100)

----DECLARE drptbls CURSOR FOR

----SELECT DatabaseName,TableName,IndexName From #OutPut

----OPEN drptbls 
----FETCH NEXT FROM drptbls INTO @Database,@tblname,@indxname

----WHILE @@fetch_status = 0
----BEGIN
----	SET @sql = N'DROP INDEX '+QUOTENAME(@indxname)
----	PRINT @sql
				 
----FETCH NEXT FROM drptbls INTO @Database, @tblname, @indxname

----END

----CLOSE drptbls
----DEALLOCATE drptbls

DROP TABLE #tmptbl1
DROP TABLE #OutPut
	
