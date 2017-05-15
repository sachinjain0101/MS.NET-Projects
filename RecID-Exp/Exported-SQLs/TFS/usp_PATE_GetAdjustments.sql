Create PROCEDURE [dbo].[usp_PATE_GetAdjustments] (
  @Client      char(4),
	@GroupCode 	 int,
  @PPED        datetime,
  @SSN         int,
  @ClusterID   int,
	@THDRecordId BIGINT = NULL,  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 25Aug2016 >--
	@FilterGroup CHAR(1) = '0'
)
AS
--*/

/*
DECLARE  @Client      char(4)
DECLARE  @PPED        datetime
DECLARE  @SSN         int
DECLARE  @ClusterID   int
DECLARE  @THDRecordId int

SET @Client = 'PATE'
SET @PPED		= '4/22/07'
SET @SSN 		= 1638
SET @ClusterID = 18935
SET @THDRecordID = NULL
*/

-- Per request of Mark Buss (4/24/07), the ability to see ANY transactions outside of the user's cluster has been removed
IF @ClusterID = 0
BEGIN
	SELECT thd.RecordID, thd.GroupCode, thd.AprvlStatus, thd.AprvlStatus_UserId, thd.AprvlStatus_Date,
	  thd.SSN, thd.PayrollPeriodEndDate, thd.SiteNo, thd.DeptNo, 
	  CAST(Month(thd.TransDate) AS varchar(2)) + '/' + CAST(Day(thd.TransDate) AS varchar(2)) + '/' + CAST(Year(thd.TransDate) AS varchar(4)) AS TransDate,
	  thd.Hours, thd.RegHours, thd.OT_Hours, thd.DT_Hours, 
	  depts.ClientDeptCode, depts.DeptName, groupdepts.DeptName_Long,
	  ISNULL(adjs.Sales, 0) AS Sales, adjs.Record_No AS AdjRecordNo,
	  thd.PayRate, thd.BillRate, thd.JobID, thd.UserCode,
	  pate.Brand,
	  pate.COOP,
	  pate.Event,
	  pate.Season,
	  pate.Share
	--  dbo.usp_GetTimeHistoryClusterDefAsFn(thd.GroupCode, thd.SiteNo, thd.DeptNo, thd.AgencyNo, thd.SSN, 0, 0, @ClusterID) AS InCluster
	FROM tblTimeHistDetail thd
	LEFT JOIN TimeCurrent..tblAdjustments adjs
	  ON adjs.Client = thd.Client
	  AND adjs.GroupCode = thd.GroupCode
	  AND adjs.SSN = thd.SSN
	  AND adjs.PayrollPeriodEndDate = thd.PayrollPeriodEndDate
	  AND adjs.SiteNo = thd.SiteNo
	  AND adjs.DeptNo = thd.DeptNo
	  AND CASE DATEPART(dw, thd.TransDate)
	      WHEN 1 THEN adjs.SunVal
	      WHEN 2 THEN adjs.MonVal
	      WHEN 3 THEN adjs.TueVal
	      WHEN 4 THEN adjs.WedVal
	      WHEN 5 THEN adjs.ThuVal
	      WHEN 6 THEN adjs.FriVal
	      WHEN 7 THEN adjs.SatVal
	      END = thd.Hours
	LEFT JOIN tblTimeHistDetail_PATE pate
	ON pate.THDRecordID = thd.RecordID
	INNER JOIN TimeCurrent..tblDeptNames depts
		ON depts.Client = thd.Client
		AND depts.GroupCode = thd.GroupCode
		AND depts.SiteNo = thd.SiteNo
		AND depts.DeptNo = thd.DeptNo
	INNER JOIN TimeCurrent..tblGroupDepts groupdepts
		ON groupdepts.Client = thd.Client
		AND groupdepts.GroupCode = thd.GroupCode
		AND groupdepts.DeptNo = thd.DeptNo
	INNER JOIN TimeCurrent..tblEmplNames empls
	  ON empls.Client = thd.Client
	  AND empls.GroupCode = thd.GroupCode
	  AND empls.SSN = thd.SSN
	WHERE thd.Client = @Client
	  AND (@FilterGroup = 0 OR thd.GroupCode = @GroupCode)
		AND thd.SSN = @SSN
		AND thd.PayrollPeriodEndDate = @PPED
	  AND thd.ClockAdjustmentNo = '1'
	  AND (
	    thd.Hours <> 0 OR 
	    (adjs.SunVal = 0 AND adjs.MonVal = 0 AND adjs.TueVal = 0 AND adjs.WedVal = 0 AND adjs.ThuVal = 0 AND adjs.FriVal = 0 AND adjs.SatVal = 0)
	  )
		AND thd.RecordId = IsNull(@THDRecordId, thd.RecordId)
	ORDER BY thd.SSN, thd.PayrollPeriodEndDate, TransDate, thd.DeptNo ASC
END
ELSE
BEGIN
	SELECT thd.RecordID, thd.GroupCode, thd.AprvlStatus, thd.AprvlStatus_UserId, thd.AprvlStatus_Date,
	  thd.SSN, thd.PayrollPeriodEndDate, thd.SiteNo, thd.DeptNo, 
	  CAST(Month(thd.TransDate) AS varchar(2)) + '/' + CAST(Day(thd.TransDate) AS varchar(2)) + '/' + CAST(Year(thd.TransDate) AS varchar(4)) AS TransDate,
	  thd.Hours, thd.RegHours, thd.OT_Hours, thd.DT_Hours, 
	  depts.ClientDeptCode, depts.DeptName, groupdepts.DeptName_Long,
	  ISNULL(adjs.Sales, 0) AS Sales, adjs.Record_No AS AdjRecordNo,
	  thd.PayRate, thd.BillRate, thd.JobID, thd.UserCode,
	  pate.Brand,
	  pate.COOP,
	  pate.Event,
	  pate.Season,
	  pate.Share,
	--  dbo.usp_GetTimeHistoryClusterDefAsFn(thd.GroupCode, thd.SiteNo, thd.DeptNo, thd.AgencyNo, thd.SSN, 0, 0, @ClusterID) AS InCluster
	  CASE WHEN c.ClusterID IS NOT NULL THEN 1 ELSE 0 END AS InCluster
	FROM tblTimeHistDetail thd
	LEFT JOIN TimeCurrent..tblAdjustments adjs
	  ON adjs.Client = thd.Client
	  AND adjs.GroupCode = thd.GroupCode
	  AND adjs.SSN = thd.SSN
	  AND adjs.PayrollPeriodEndDate = thd.PayrollPeriodEndDate
	  AND adjs.SiteNo = thd.SiteNo
	  AND adjs.DeptNo = thd.DeptNo
	  AND CASE DATEPART(dw, thd.TransDate)
	      WHEN 1 THEN adjs.SunVal
	      WHEN 2 THEN adjs.MonVal
	      WHEN 3 THEN adjs.TueVal
	      WHEN 4 THEN adjs.WedVal
	      WHEN 5 THEN adjs.ThuVal
	      WHEN 6 THEN adjs.FriVal
	      WHEN 7 THEN adjs.SatVal
	      END = thd.Hours
	--LEFT JOIN TimeCurrent..tblClusterDef c
	INNER JOIN TimeCurrent..tblClusterDef c
	  ON c.ClusterID = @ClusterID
	  AND c.Client = thd.Client
	  AND c.GroupCode = thd.GroupCode
	  AND (c.DeptNo = thd.DeptNo OR c.DeptNo = 0)
	  AND c.RecordStatus = '1'
	LEFT JOIN tblTimeHistDetail_PATE pate
	ON pate.THDRecordID = thd.RecordID
	INNER JOIN TimeCurrent..tblDeptNames depts
		ON depts.Client = thd.Client
		AND depts.GroupCode = thd.GroupCode
		AND depts.SiteNo = thd.SiteNo
		AND depts.DeptNo = thd.DeptNo
	INNER JOIN TimeCurrent..tblGroupDepts groupdepts
		ON groupdepts.Client = thd.Client
		AND groupdepts.GroupCode = thd.GroupCode
		AND groupdepts.DeptNo = thd.DeptNo
	INNER JOIN TimeCurrent..tblEmplNames empls
	  ON empls.Client = thd.Client
	  AND empls.GroupCode = thd.GroupCode
	  AND empls.SSN = thd.SSN
	WHERE thd.Client = @Client
	  AND (@FilterGroup = 0 OR thd.GroupCode = @GroupCode)
		AND thd.SSN = @SSN
		AND thd.PayrollPeriodEndDate = @PPED
	  AND thd.ClockAdjustmentNo = '1'
	  AND (
	    thd.Hours <> 0 OR 
	    (adjs.SunVal = 0 AND adjs.MonVal = 0 AND adjs.TueVal = 0 AND adjs.WedVal = 0 AND adjs.ThuVal = 0 AND adjs.FriVal = 0 AND adjs.SatVal = 0)
	  )
		AND thd.RecordId = IsNull(@THDRecordId, thd.RecordId)
	ORDER BY thd.SSN, thd.PayrollPeriodEndDate, TransDate, thd.DeptNo ASC
END








