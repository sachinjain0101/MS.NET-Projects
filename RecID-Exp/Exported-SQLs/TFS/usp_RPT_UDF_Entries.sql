Create PROCEDURE [dbo].[usp_RPT_UDF_Entries]
 (
  @Client varchar(4),
  @Group  int,
  @Sites varchar(1024),
  @Dept varchar(1024),
  @DateFrom datetime,
  @DateTo datetime,
  @Date datetime,
  @ClusterId integer,
  @Report varchar(4),
	@ReptType varchar(10) = 'Both'
) AS
SET NOCOUNT ON;

CREATE TABLE #tmpEmpl
(
  THDRecordId BIGINT,  --< THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 31Aug2016 >--
  SSN int,
  FirstName varchar(20),
  LastName varchar(20),
  SiteName varchar(60),
  DeptName varchar(50),
  TransDate datetime,
  InTime datetime,
  OutTime datetime,
  [Hours] numeric(5,2),
  Dollars numeric(7,2),
  UDF_Field_1 varchar(20),
  UDF_Field_2 varchar(20),
  UDF_Field_3 varchar(20),
  UDF_Field_4 varchar(20),
  UDF_Field_5 varchar(20),
  ReptType varchar(10)
 ,Client VARCHAR(4)
 ,GroupCode INT
 ,SiteNo INT
 ,DeptNo INT
 ,PayrollPeriodEndDate DATE
 ,SpreadsheetAssignmentId INT
)

IF @ReptType <> 'Saved'
	BEGIN
		GOTO Submitted;
	END

IF @ReptType = 'Saved' 
	BEGIN
		GOTO Saved;
	END

Submitted:
BEGIN
	INSERT INTO #tmpEmpl
	(
  THDRecordId,SSN,FirstName,LastName,SiteName,DeptName
	,TransDate,InTime,OutTime,[Hours],Dollars,ReptType
 ,Client,GroupCode,SiteNo,DeptNo,PayrollPeriodEndDate,SpreadsheetAssignmentId
 )
	SELECT DISTINCT
  thd.RecordID, en.SSN,en.FirstName,en.LastName,sn.SiteName,gd.DeptName
	,thd.TransDate,thd.InTime,thd.OutTime,thd.[Hours],thd.Dollars,ReptType = 'Submitted'
 ,thd.Client,thd.GroupCode,thd.SiteNo,thd.DeptNo,thd.PayrollPeriodEndDate,NULL
	FROM TimeHistory.dbo.tblTimeHistDetail thd WITH (NOLOCK)
	INNER JOIN TimeCurrent.dbo.tblEmplNames en WITH (NOLOCK)
	ON thd.Client = en.Client
	AND thd.GroupCode = en.GroupCode
	AND thd.SSN = en.SSN
	INNER JOIN TimeCurrent.dbo.tblSiteNames sn WITH (NOLOCK)
	ON thd.Client = sn.Client
	AND thd.GroupCode = sn.GroupCode
	AND thd.SiteNo = sn.SiteNo
	INNER JOIN TimeCurrent.dbo.tblGroupDepts gd WITH (NOLOCK)
	ON thd.Client = gd.Client
	AND thd.GroupCode = gd.GroupCode
	AND thd.DeptNo = gd.DeptNo
		LEFT JOIN TimeHistory.dbo.tblWTE_Spreadsheet ss WITH (NOLOCK)
		ON ss.Client = thd.Client
		AND ss.GroupCode = thd.GroupCode
		AND ss.PayrollPeriodEndDate = thd.PayrollPeriodEndDate
		AND ss.SSN = thd.SSN
		AND ss.SiteNo = thd.SiteNo
		AND ss.DeptNo = thd.DeptNo
	WHERE thd.Client = @Client
	AND thd.GroupCode = @Group
	AND TimeCurrent.dbo.fn_InCSV(IsNull(@Sites,'ALL'),thd.SiteNo, 1) = 1
	AND TimeCurrent.dbo.fn_InCSV(@Dept,thd.DeptNo, 1) = 1
	AND thd.PayrollPeriodEndDate = @Date
	AND EXISTS(SELECT 1 FROM TimeHistory.dbo.tvf_GetTimeHistoryClusterDefAsFn
  (thd.GroupCode,thd.SiteNo,thd.DeptNo,0,0,0,0,@ClusterId));

	IF @ReptType = 'Both'
			GOTO Saved;
	ELSE
		GOTO Finish;
END

Saved:
INSERT INTO #tmpEmpl
(
  THDRecordId,SSN,FirstName,LastName,SiteName,DeptName
 ,TransDate,InTime,OutTime,[Hours],Dollars,ReptType
 ,Client,GroupCode,SiteNo,DeptNo,PayrollPeriodEndDate,SpreadsheetAssignmentId
)
SELECT DISTINCT
 ss.RecordID, en.SSN,en.FirstName,en.LastName,sn.SiteName,gd.DeptName
,ss.TransDate,InTime = ss.[In],OutTime = ss.[Out],ss.[Hours],Dollars=0.00,ReptType = 'Saved'
,ss.Client,ss.GroupCode,ss.SiteNo,ss.DeptNo,ss.PayrollPeriodEndDate,ss.SpreadsheetAssignmentId
FROM TimeHistory.dbo.tblWTE_Spreadsheet ss WITH (NOLOCK)
INNER JOIN TimeCurrent.dbo.tblEmplNames en WITH (NOLOCK)
ON ss.Client = en.Client
AND ss.GroupCode = en.GroupCode
AND ss.SSN = en.SSN
INNER JOIN TimeCurrent.dbo.tblSiteNames sn WITH (NOLOCK)
ON ss.Client = sn.Client
AND ss.GroupCode = sn.GroupCode
AND ss.SiteNo = sn.SiteNo
INNER JOIN TimeCurrent.dbo.tblGroupDepts gd WITH (NOLOCK)
ON ss.Client = gd.Client
AND ss.GroupCode = gd.GroupCode
AND ss.DeptNo = gd.DeptNo
LEFT JOIN TimeHistory.dbo.tblTimeHistDetail thd WITH (NOLOCK)
ON thd.Client = ss.Client
AND thd.GroupCode = ss.GroupCode
AND thd.PayrollPeriodEndDate = ss.PayrollPeriodEndDate
AND thd.SSN = ss.SSN
AND thd.SiteNo = ss.SiteNo
AND thd.DeptNo = ss.DeptNo
WHERE ss.Client = @Client
AND ss.GroupCode = @Group
AND TimeCurrent.dbo.fn_InCSV(IsNull(@Sites,'ALL'),ss.SiteNo, 1) = 1
AND TimeCurrent.dbo.fn_InCSV(@Dept,ss.DeptNo, 1) = 1
AND ss.PayrollPeriodEndDate = @Date
AND EXISTS(SELECT ClusterID FROM dbo.tvf_GetTimeHistoryClusterDefAsFn
 (ss.GroupCode,ss.SiteNo,ss.DeptNo,0,0,0,0,@ClusterId));

Finish:
;WITH cteEmpl AS
(
 SELECT DISTINCT
  THDRecordId
 ,Client
 ,GroupCode
 ,PayrollPeriodEndDate
 ,SiteNo
 ,DeptNo
 ,SSN
 ,FirstName
 ,LastName
 ,SiteName
 ,DeptName
 ,TransDate
 ,InTime
 ,OutTime
 ,[Hours]
 ,Dollars
 ,ReptType
 ,RelRankByInTime = DENSE_RANK() OVER
  (PARTITION BY SSN,SiteNo,DeptNo,TransDate,ReptType ORDER BY InTime)
 ,RelRankByReptType = DENSE_RANK() OVER
  (PARTITION BY SSN,SiteNo,DeptNo,TransDate ORDER BY ReptType DESC)
 FROM #tmpEmpl
)
,cteUDFFields AS
(
 SELECT DISTINCT
 RowNum = DENSE_RANK() OVER
  (PARTITION BY thd_udf.Client,thd_udf.GroupCode
   ORDER BY CASE WHEN udf_fd.FieldID = udf_t.ValidationFieldId THEN 0 ELSE 1 END,udf_fd.FieldName)
 ,udf_fd.FieldName
 FROM TimeHistory.dbo.tblTimeHistDetail_UDF thd_udf WITH (NOLOCK)
 INNER JOIN TimeCurrent.dbo.tblUDF_FieldDefs udf_fd WITH (NOLOCK)
 ON udf_fd.FieldID = thd_udf.FieldID
 INNER JOIN TimeCurrent.dbo.tblUDF_Templates udf_t WITH (NOLOCK)
 ON udf_t.TemplateId = udf_fd.TemplateID
 WHERE
 thd_udf.Client = @Client
 AND thd_udf.GroupCode = @Group
 AND thd_udf.Payrollperiodenddate = @Date
 AND udf_fd.RecordStatus = '1'
 AND udf_t.RecordStatus = '1'
)
,cteUDFValues AS
(
 SELECT
 thd_udf.Client
 ,thd_udf.GroupCode
 ,thd_udf.PayrollPeriodEndDate
 ,thd_udf.SSN
 ,thd_udf.SiteNo
 ,thd_udf.DeptNo
 ,thd_udf.TransDate
 ,thd_udf.THDRecordID
 ,udf_fd.FieldName
 ,thd_udf.FieldValue
 ,RowNumByPosition = ROW_NUMBER() OVER
  (PARTITION BY thd_udf.SSN,thd_udf.SiteNo,thd_udf.DeptNo,thd_udf.TransDate,udf_fd.FieldName
   ORDER BY thd_udf.Position,udf_fd.FieldName,thd_udf.FieldValue)
 ,UDFRowNum = udfv.RowNum
 FROM TimeHistory.dbo.tblTimeHistDetail_UDF thd_udf WITH (NOLOCK)
 INNER JOIN TimeCurrent.dbo.tblUDF_FieldDefs udf_fd WITH (NOLOCK)
 ON udf_fd.FieldID = thd_udf.FieldID
 INNER JOIN TimeCurrent.dbo.tblUDF_Templates udf_t WITH (NOLOCK)
 ON udf_t.TemplateId = udf_fd.TemplateID
 INNER JOIN
 (
  SELECT DISTINCT
  RowNum = DENSE_RANK() OVER
   (PARTITION BY thd_udf.Client,thd_udf.GroupCode
    ORDER BY CASE WHEN udf_fd.FieldID = udf_t.ValidationFieldId THEN 0 ELSE 1 END,udf_fd.FieldName)
  ,udf_fd.FieldName
  FROM TimeHistory.dbo.tblTimeHistDetail_UDF thd_udf
  INNER JOIN TimeCurrent.dbo.tblUDF_FieldDefs udf_fd
  ON udf_fd.FieldID = thd_udf.FieldID
  INNER JOIN TimeCurrent.dbo.tblUDF_Templates udf_t
  ON udf_t.TemplateId = udf_fd.TemplateID
  WHERE
  thd_udf.Client = @Client
  AND thd_udf.GroupCode = @Group
  AND thd_udf.Payrollperiodenddate = @Date
  AND udf_fd.RecordStatus = '1'
  AND udf_t.RecordStatus = '1'
 ) udfv
 ON udfv.FieldName = udf_fd.FieldName
 WHERE
 thd_udf.Client =  @Client
 AND thd_udf.GroupCode = @Group
 AND thd_udf.Payrollperiodenddate = @Date
 AND udf_fd.RecordStatus = '1'
 AND udf_t.RecordStatus = '1'
)
SELECT THDRecordId=NULL,SSN=NULL,FirstName=NULL,LastName=NULL,SiteName=NULL,DeptName=NULL
,TransDate=NULL,InTime=NULL,OutTime=NULL,[Hours]=NULL,Dollars=NULL
,UDF_Field_1 = MAX(CASE WHEN RowNum = 1 THEN FieldName END)
,UDF_Field_2 = MAX(CASE WHEN RowNum = 2 THEN FieldName END)
,UDF_Field_3 = MAX(CASE WHEN RowNum = 3 THEN FieldName END)
,UDF_Field_4 = MAX(CASE WHEN RowNum = 4 THEN FieldName END)
,UDF_Field_5 = MAX(CASE WHEN RowNum = 5 THEN FieldName END)
,ReptType=NULL
FROM cteUDFFields
UNION
SELECT DISTINCT
X.THDRecordId
,X.SSN
,X.FirstName
,X.LastName
,X.SiteName
,X.DeptName
,TransDate = CONVERT(CHAR(10),X.TransDate,101)
,InTime = LEFT(CAST(X.InTime AS TIME),5)
,OutTime = LEFT(CAST(X.OutTime AS TIME),5)
,X.[Hours]
,X.Dollars
,UDF_Field_1 = MAX(CASE udf.UDFRowNum WHEN 1 THEN udf.FieldValue END)
,UDF_Field_2 = MAX(CASE udf.UDFRowNum WHEN 2 THEN udf.FieldValue END)
,UDF_Field_3 = MAX(CASE udf.UDFRowNum WHEN 3 THEN udf.FieldValue END)
,UDF_Field_4 = MAX(CASE udf.UDFRowNum WHEN 4 THEN udf.FieldValue END)
,UDF_Field_5 = MAX(CASE udf.UDFRowNum WHEN 5 THEN udf.FieldValue END)
,X.ReptType
FROM cteEmpl x
LEFT JOIN cteUDFValues udf
ON udf.Client = X.Client
AND udf.GroupCode = X.GroupCode
AND udf.SiteNo = X.SiteNo
AND udf.DeptNo = X.DeptNo
AND udf.SSN = X.SSN
AND udf.Payrollperiodenddate = X.PayrollPeriodEndDate
AND udf.TransDate = X.TransDate
AND udf.RowNumByPosition = X.RelRankByInTime
WHERE
X.RelRankByReptType = 1
GROUP BY
X.THDRecordId
,X.SSN
,X.FirstName
,X.LastName
,X.SiteName
,X.DeptName
,X.TransDate
,X.InTime
,X.OutTime
,X.[Hours]
,X.Dollars
,X.ReptType
UNION
SELECT DISTINCT
 X.THDRecordId
,X.SSN
,X.FirstName
,X.LastName
,X.SiteName
,X.DeptName
,TransDate = CONVERT(CHAR(10),X.TransDate,101)
,InTime = LEFT(CAST(X.InTime AS TIME),5)
,OutTime = LEFT(CAST(X.OutTime AS TIME),5)
,X.[Hours]
,X.Dollars
,UDF_Field_1 = MAX(CASE udf.UDFRowNum WHEN 1 THEN udf.FieldValue END)
,UDF_Field_2 = MAX(CASE udf.UDFRowNum WHEN 2 THEN udf.FieldValue END)
,UDF_Field_3 = MAX(CASE udf.UDFRowNum WHEN 3 THEN udf.FieldValue END)
,UDF_Field_4 = MAX(CASE udf.UDFRowNum WHEN 4 THEN udf.FieldValue END)
,UDF_Field_5 = MAX(CASE udf.UDFRowNum WHEN 5 THEN udf.FieldValue END)
,X.ReptType
FROM cteEmpl x
INNER JOIN cteUDFValues udf
ON udf.THDRecordID = X.THDRecordId
WHERE
X.RelRankByReptType = 1
GROUP BY
 X.THDRecordId
,X.SSN
,X.FirstName
,X.LastName
,X.SiteName
,X.DeptName
,X.TransDate
,X.InTime
,X.OutTime
,X.[Hours]
,X.Dollars
,X.ReptType
ORDER BY LastName,FirstName,TransDate;

DROP TABLE #tmpEmpl;
