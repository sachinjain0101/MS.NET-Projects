
--Adding newly identified tables/fields to the SQL Script										
--USE TimeCurrent										


USE TimeHistory;										
--Creating the Temp table with Table and Column Names										


CREATE TABLE #temp
(SlNo       INT IDENTITY(1, 1),
 ColumnName VARCHAR(500),
 TableName  VARCHAR(500)
);									
--Inserting the dependent Table and Column names into temp table									
------Inserting TimeCurrent Tables									


INSERT INTO #temp
(ColumnName,
 TableName
)
VALUES
('%NewJobId%',
 '%tblFixedPunch%'
);
INSERT INTO #temp
(ColumnName,
 TableName
)
VALUES
('%OldJobId%',
 '%tblFixedPunch%'
);

INSERT INTO #temp
(ColumnName,
 TableName
)
VALUES
('%ClkTransNo%',
 '%tblTimeHistDetail_Partial%'
);
INSERT INTO #temp
(ColumnName,
 TableName
)
VALUES
('%DivisionId%',
 '%tblTimeHistDetail%'
);

							
-------------------------------------------------									
--Createing a temp table to store the SP's list, which uses The mentioned TableName/ColumnName										
--Create table #output(SlNo int Identity(1,1), StoredProcName VARCHAR(1000))										
--Declaration of Temp Variables										


DECLARE @tableCount INT;
DECLARE @intFlag INT;
DECLARE @TableName VARCHAR(500);
DECLARE @ColumnName VARCHAR(500);
SET @tableCount =
(
    SELECT COUNT(1)
    FROM #temp
);
SET @intFlag = 1;							


SELECT DISTINCT
       s.name,
       c.text
INTO #TempCode
FROM syscomments AS c
     INNER JOIN sysobjects AS s ON c.id = s.id
WHERE s.type = 'p'
      AND s.name NOT LIKE '%_GG'
      AND s.name NOT LIKE '%_GG1'
      AND s.name NOT LIKE '%_GG2'
      AND s.name NOT LIKE '%_GG3'
      AND s.name NOT LIKE '%_GG4'
      AND s.name NOT LIKE '%_GG5'
      AND s.name NOT LIKE '%_GG6'
      AND s.name NOT LIKE '%_deh'
      AND s.name NOT LIKE '%_deh2'
      AND s.name NOT LIKE '%_jb'
      AND s.name NOT LIKE '%_jlb'
      AND s.name NOT LIKE '%_ss'
      AND s.name NOT LIKE '%_clim'
      AND s.name NOT LIKE '%_mk'
      AND s.name NOT LIKE '%_mk1'
      AND s.name NOT LIKE '%_mk2'
      AND s.name NOT LIKE '%_mk3'
      AND s.name NOT LIKE '%usp_WTE_GetUnapprovedTimeEntries_%';
SELECT *
FROM #TempCode;
SELECT *
FROM #temp;								
--RETURN								
------DataType and Field combinations	Temp Variable Declaration Starts	-----						


DECLARE @ClkTransNoLike VARCHAR(100)= '%int%ClkTransNo%';
DECLARE @ClkTransNoLikeReverse VARCHAR(100)= '%ClkTransNo%int%';


DECLARE @JobIdLike VARCHAR(100)= '%int%JobId%';
DECLARE @JobIdLikeReverse VARCHAR(100)= '%JobId%int%';	

DECLARE @DivIdLike VARCHAR(100)= '%int%DivisionId%';
DECLARE @DivIdLikeReverse VARCHAR(100)= '%DivisionId%int%';	

							
------DataType and Field combinations	Ends	-----						


SELECT DISTINCT
       c.name,
       SUM(CASE
               WHEN(
			   ((c.text LIKE @JobIdLike
                      OR c.text LIKE @JobIdLikeReverse)
                     AND (c.text LIKE '%tblFixedPunch%'))
                    OR 
					 ((c.text LIKE @ClkTransNoLike
                         OR c.text LIKE @ClkTransNoLikeReverse)
                        AND c.text LIKE '%tblTimeHistDetail_Partial%')

					OR ((c.text LIKE @DivIdLike
                         OR c.text LIKE @DivIdLikeReverse)
                        AND c.text LIKE '%tblTimeHistDetail%'))
               THEN 1
               ELSE 0
           END) AS tblTimeHistDetail_RecordID_Related
INTO #output
FROM #TempCode AS c
     INNER JOIN #temp AS tmp ON c.text LIKE tmp.TableName
                                AND c.text LIKE tmp.ColumnName
GROUP BY c.name
UNION
SELECT DISTINCT
       c.name,
         SUM(CASE
               WHEN(
			   ((c.text LIKE @JobIdLike
                      OR c.text LIKE @JobIdLikeReverse)
                     AND (c.text LIKE '%tblFixedPunch%'))
                    OR 
					 ((c.text LIKE @ClkTransNoLike
                         OR c.text LIKE @ClkTransNoLikeReverse)
                        AND c.text LIKE '%tblTimeHistDetail_Partial%')

					OR ((c.text LIKE @DivIdLike
                         OR c.text LIKE @DivIdLikeReverse)
                        AND c.text LIKE '%tblTimeHistDetail%'))
               THEN 1
               ELSE 0
           END) AS tblTimeHistDetail_RecordID_Related
FROM #TempCode AS c
     INNER JOIN #temp AS tmp ON 1 = 1
WHERE(
((c.text LIKE @JobIdLike
                      OR c.text LIKE @JobIdLikeReverse)
                     AND (c.text LIKE '%tblFixedPunch%'))
                    OR 
					 ((c.text LIKE @ClkTransNoLike
                         OR c.text LIKE @ClkTransNoLikeReverse)
                        AND c.text LIKE '%tblTimeHistDetail_Partial%')

					OR ((c.text LIKE @DivIdLike
                         OR c.text LIKE @DivIdLikeReverse)
                        AND c.text LIKE '%tblTimeHistDetail%'))
GROUP BY c.name;								
--SET @intFlag = @intFlag + 1								
--END									


DROP TABLE #temp;
DROP TABLE #TempCode;
SELECT name,
       CASE
           WHEN tblTimeHistDetail_RecordID_Related > 0
           THEN 'Y'
           ELSE ''
       END AS tblTimeHistDetail_RecordID_Related									
-- CASE WHEN SiteNo_SMALLINT > 0 THEN 'Y' ELSE '' END AS SiteNo_SMALLINT,									
--  CASE WHEN DeptNo_SMALLINT > 0 THEN 'Y' ELSE '' END AS DeptNo_SMALLINT									
FROM
(
    SELECT DISTINCT
           name,
           SUM(tblTimeHistDetail_RecordID_Related) AS tblTimeHistDetail_RecordID_Related				
    --	SUM(SiteNo_SMALLINT) AS SiteNo_SMALLINT,				
    --SUM(DeptNo_SMALLINT) AS DeptNo_SMALLINT				
    FROM #output
    GROUP BY name
) AS tmp 								
--where tmp.DeptNo_SMALLINT>0 or tmp.SiteNo_SMALLINT>0 or tmp.tblTimeHistDetail_RecordID_Related>0								
WHERE tmp.tblTimeHistDetail_RecordID_Related > 0
ORDER BY 1;										
--select * from #output										


DROP TABLE #output;