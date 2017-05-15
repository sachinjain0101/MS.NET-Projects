--TimeCurrent-Indexes create/delete related script

/*******************************************************************
The Below Script is Responsible for generating the 
CREATE INDEX Scripts based on the required column name,table name and 
database name across environments
*******************************************************************/
Use TimeCurrent
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
	
