CREATE  PROCEDURE [dbo].[usp_WTE_GetSummaryCard_Hilton] (
  @Client       varchar(4),
  @GroupCode    int,
  @SSN          int,
  @PPED         datetime
)
AS

--*/

/*
DECLARE  @Client       varchar(4)
DECLARE  @GroupCode    int
DECLARE  @SSN          int
DECLARE  @PPED         datetime

SET @Client       = 'HILT'
SET @GroupCode    = 632101
SET @SSN          = 1149825
SET @PPED         = '12/28/07'
*/

DECLARE @Date1  datetime
DECLARE @Date2  datetime
DECLARE @Date3  datetime
DECLARE @Date4  datetime
DECLARE @Date5  datetime
DECLARE @Date6  datetime
DECLARE @Date7  datetime
DECLARE @PPSD 	datetime
DECLARE @StaffingSetupType CHAR(1)

SET @Date1 = DATEADD(d, -6, @PPED)
SET @Date2 = DATEADD(d, -5, @PPED)
SET @Date3 = DATEADD(d, -4, @PPED)
SET @Date4 = DATEADD(d, -3, @PPED)
SET @Date5 = DATEADD(d, -2, @PPED)
SET @Date6 = DATEADD(d, -1, @PPED)
SET @Date7 = @PPED
SET @PPSD = DATEADD(d, -6, @PPED)

DECLARE @MPMinDateTime  datetime
DECLARE @MPMinTransDate datetime
DECLARE @MPMinRecordID  BIGINT  --< @MPMinRecordId data type is changed from  INT to BIGINT by Srinsoft on 16Sept2016 >--

SET @MPMinDateTime = DATEADD(hour, -16, TimeHistory.dbo.SiteDateTime(@Client, @GroupCode, 1, GETUTCDATE()))
SET @MPMinTransDate = DATEADD(d, -1, @MPMinDateTime)

--/*
SET @MPMinRecordID = (
  SELECT ISNULL(MAX(thd.RecordID), 0)
  FROM TimeHistory.dbo.tblTimeHistDetail thd
  WHERE thd.Client = @Client
    AND thd.GroupCode = @GroupCode
    AND thd.SSN = @SSN
    AND thd.PayrollPeriodEndDate = @PPED
    AND thd.TransDate > @MPMinTransDate
    AND thd.ClockAdjustmentNo IN ('', ' ')
    AND thd.InDay NOT IN (10, 11)
    AND thd.OutDay IN (10, 11)
    AND TimeHistory.dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime) > @MPMinDateTime
)  
--*/
IF (@Client IN ('HILT','HLT1'))
BEGIN
	SELECT 	thd.SiteNo, thd.SiteName,
				  thd.DeptNo, thd.DeptName,
				  MAX(CASE WHEN TransDate = @Date1 THEN ClockAdjustmentNo ELSE '' END) AS Adj1,
				  MAX(CASE WHEN TransDate = @Date2 THEN ClockAdjustmentNo ELSE '' END) AS Adj2,
				  MAX(CASE WHEN TransDate = @Date3 THEN ClockAdjustmentNo ELSE '' END) AS Adj3,
				  MAX(CASE WHEN TransDate = @Date4 THEN ClockAdjustmentNo ELSE '' END) AS Adj4,
				  MAX(CASE WHEN TransDate = @Date5 THEN ClockAdjustmentNo ELSE '' END) AS Adj5,
				  MAX(CASE WHEN TransDate = @Date6 THEN ClockAdjustmentNo ELSE '' END) AS Adj6,
				  MAX(CASE WHEN TransDate = @Date7 THEN ClockAdjustmentNo ELSE '' END) AS Adj7,
				  MAX(CASE WHEN thd.RecordID = @MPMinRecordID THEN thd.TransDate ELSE NULL END) AS CurrentPunchDate,
					MAX(thd.TransDate) AS MaxPunchDate
	FROM (SELECT 	thd.SiteNo, 
								sites.SiteName,
							  thd.DeptNo, 
							  CASE ISNULL(depts.DeptName_Long, '') WHEN '' THEN depts.DeptName ELSE depts.DeptName_Long END AS DeptName,
								thd.ClockAdjustmentNo, 
								thd.TransDate, 
								thd.RecordID
				FROM TimeHistory.dbo.tblTimeHistDetail thd
				LEFT JOIN TimeCurrent.dbo.tblSiteNames sites
				ON sites.Client = thd.Client
				  AND sites.GroupCode = thd.GroupCode
				  AND sites.SiteNo = thd.SiteNo
				LEFT JOIN TimeCurrent.dbo.tblGroupDepts depts
				ON depts.Client = thd.Client
				  AND depts.GroupCode = thd.GroupCode
				  AND depts.DeptNo = thd.DeptNo
				INNER JOIN TimeCurrent.dbo.tblAdjCodes adjs
				ON adjs.Client = thd.Client
					AND adjs.GroupCode = thd.GroupCode
					AND adjs.ClockAdjustmentNo = thd.ClockAdjustmentNo
				WHERE thd.Client = @Client
				  AND thd.GroupCode = @GroupCode
				  AND thd.SSN = @SSN
				  AND thd.PayrollPeriodEndDate = @PPED
			) thd
	GROUP BY 	thd.SiteNo, 
						thd.SiteName, 
						thd.DeptNo, 
						thd.DeptName
END
ELSE
BEGIN
	SELECT @StaffingSetupType = ISNULL(StaffingSetupType,0)
	FROM TimeCurrent..tblClientGroups
	WHERE Client = @Client
	AND GroupCode = @GroupCode
	
	IF @StaffingSetupType = '1'
	BEGIN
		SELECT 	tmp.SiteNo, tmp.SiteName,
					  tmp.DeptNo, tmp.DeptName,
					  tmp.AssignmentStartDate, tmp.AssignmentEndDate,
					  MAX(CASE WHEN TransDate = @Date1 THEN ClockAdjustmentNo ELSE '' END) AS Adj1,
					  MAX(CASE WHEN TransDate = @Date2 THEN ClockAdjustmentNo ELSE '' END) AS Adj2,
					  MAX(CASE WHEN TransDate = @Date3 THEN ClockAdjustmentNo ELSE '' END) AS Adj3,
					  MAX(CASE WHEN TransDate = @Date4 THEN ClockAdjustmentNo ELSE '' END) AS Adj4,
					  MAX(CASE WHEN TransDate = @Date5 THEN ClockAdjustmentNo ELSE '' END) AS Adj5,
					  MAX(CASE WHEN TransDate = @Date6 THEN ClockAdjustmentNo ELSE '' END) AS Adj6,
					  MAX(CASE WHEN TransDate = @Date7 THEN ClockAdjustmentNo ELSE '' END) AS Adj7,
					  MAX(CASE WHEN tmp.RecordID = @MPMinRecordID THEN tmp.TransDate ELSE NULL END) AS CurrentPunchDate,
						MAX(tmp.TransDate) AS MaxPunchDate
		FROM (SELECT 	esd.SiteNo, 
									sites.SiteName,
								  esd.DeptNo, 
								  CASE ISNULL(depts.DeptName_Long, '') WHEN '' THEN depts.DeptName ELSE depts.DeptName_Long END AS DeptName,
									thd.ClockAdjustmentNo, 
									thd.TransDate, 
									thd.RecordID,
									ea.StartDate AssignmentStartDate,
									ea.EndDate AssignmentEndDate
					FROM TimeCurrent..tblEmplSites_Depts esd
					INNER JOIN TimeCurrent..tblEmplAssignments ea
					ON ea.Client = esd.Client
					AND ea.GroupCode = esd.GroupCode
					AND ea.SSN = esd.SSN
				  AND ea.DeptNo = esd.DeptNo
					AND IsNull(ea.SiteNo, esd.SiteNo) = esd.SiteNo
					AND ((@PPSD between ea.StartDate AND CASE WHEN ISNULL(ea.EndDate, '01/01/1900') = '01/01/1900' THEN @PPSD ELSE ea.EndDate END) OR 
				       (@PPED between ea.StartDate AND CASE WHEN ISNULL(ea.EndDate, '01/01/1900') = '01/01/1900' THEN @PPED ELSE ea.EndDate END) OR
			 				((ea.StartDate BETWEEN @PPSD AND @PPED) AND (ea.EndDate BETWEEN @PPSD AND @PPED)))
					LEFT JOIN TimeHistory.dbo.tblTimeHistDetail thd
					ON thd.Client = esd.Client
					AND thd.GroupCode = esd.GroupCode
					AND thd.SSN = esd.SSN
					AND thd.SiteNo = esd.SiteNo
					AND thd.DeptNo = esd.DeptNo
				  AND thd.PayrollPeriodEndDate = @PPED
					INNER JOIN TimeCurrent.dbo.tblSiteNames sites
					ON sites.Client = esd.Client
				  AND sites.GroupCode = esd.GroupCode
				  AND sites.SiteNo = esd.SiteNo
					INNER JOIN TimeCurrent.dbo.tblGroupDepts depts
					ON depts.Client = esd.Client
				  AND depts.GroupCode = esd.GroupCode
				  AND depts.DeptNo = esd.DeptNo
					LEFT JOIN TimeCurrent.dbo.tblAdjCodes adjs
					ON adjs.Client = esd.Client
					AND adjs.GroupCode = esd.GroupCode
					AND adjs.ClockAdjustmentNo = thd.ClockAdjustmentNo
					WHERE esd.Client = @Client
				  AND esd.GroupCode = @GroupCode
				  AND esd.SSN = @SSN
					AND esd.RecordStatus = '1'
	
				) tmp
		GROUP BY 	tmp.SiteNo, 
							tmp.SiteName, 
							tmp.DeptNo, 
							tmp.DeptName,
							tmp.AssignmentStartDate,
							tmp.AssignmentEndDate
	END
	ELSE
	BEGIN 
		SELECT 	tmp.SiteNo, tmp.SiteName,
					  tmp.DeptNo, tmp.DeptName,
					  MAX(CASE WHEN TransDate = @Date1 THEN ClockAdjustmentNo ELSE '' END) AS Adj1,
					  MAX(CASE WHEN TransDate = @Date2 THEN ClockAdjustmentNo ELSE '' END) AS Adj2,
					  MAX(CASE WHEN TransDate = @Date3 THEN ClockAdjustmentNo ELSE '' END) AS Adj3,
					  MAX(CASE WHEN TransDate = @Date4 THEN ClockAdjustmentNo ELSE '' END) AS Adj4,
					  MAX(CASE WHEN TransDate = @Date5 THEN ClockAdjustmentNo ELSE '' END) AS Adj5,
					  MAX(CASE WHEN TransDate = @Date6 THEN ClockAdjustmentNo ELSE '' END) AS Adj6,
					  MAX(CASE WHEN TransDate = @Date7 THEN ClockAdjustmentNo ELSE '' END) AS Adj7,
					  MAX(CASE WHEN tmp.RecordID = @MPMinRecordID THEN tmp.TransDate ELSE NULL END) AS CurrentPunchDate,
						MAX(tmp.TransDate) AS MaxPunchDate
		FROM (SELECT 	esd.SiteNo, 
									sites.SiteName,
								  esd.DeptNo, 
								  CASE ISNULL(depts.DeptName_Long, '') WHEN '' THEN depts.DeptName ELSE depts.DeptName_Long END AS DeptName,
									thd.ClockAdjustmentNo, 
									thd.TransDate, 
									thd.RecordID
					FROM TimeCurrent..tblEmplSites_Depts esd
					LEFT JOIN TimeCurrent..tblEmplAssignments ea
					ON ea.Client = esd.Client
					AND ea.GroupCode = esd.GroupCode
					AND ea.SSN = esd.SSN
				  AND ea.DeptNo = esd.DeptNo
					AND IsNull(ea.SiteNo, esd.SiteNo) = esd.SiteNo
					AND ((@PPSD between ea.StartDate AND CASE WHEN ISNULL(ea.EndDate, '01/01/1900') = '01/01/1900' THEN @PPSD ELSE ea.EndDate END) OR 
				       (@PPED between ea.StartDate AND CASE WHEN ISNULL(ea.EndDate, '01/01/1900') = '01/01/1900' THEN @PPED ELSE ea.EndDate END) OR
			 				((ea.StartDate BETWEEN @PPSD AND @PPED) AND (ea.EndDate BETWEEN @PPSD AND @PPED)))
					LEFT JOIN TimeHistory.dbo.tblTimeHistDetail thd
					ON thd.Client = esd.Client
					AND thd.GroupCode = esd.GroupCode
					AND thd.SSN = esd.SSN
					AND thd.SiteNo = esd.SiteNo
					AND thd.DeptNo = esd.DeptNo
				  AND thd.PayrollPeriodEndDate = @PPED
					LEFT JOIN TimeCurrent.dbo.tblSiteNames sites
					ON sites.Client = esd.Client
				  AND sites.GroupCode = esd.GroupCode
				  AND sites.SiteNo = esd.SiteNo
					LEFT JOIN TimeCurrent.dbo.tblGroupDepts depts
					ON depts.Client = esd.Client
				  AND depts.GroupCode = esd.GroupCode
				  AND depts.DeptNo = esd.DeptNo
					LEFT JOIN TimeCurrent.dbo.tblAdjCodes adjs
					ON adjs.Client = esd.Client
					AND adjs.GroupCode = esd.GroupCode
					AND adjs.ClockAdjustmentNo = thd.ClockAdjustmentNo
					WHERE esd.Client = @Client
				  AND esd.GroupCode = @GroupCode
				  AND esd.SSN = @SSN
					AND esd.RecordStatus = '1'
	
				) tmp
		GROUP BY 	tmp.SiteNo, 
							tmp.SiteName, 
							tmp.DeptNo, 
							tmp.DeptName
	END
END


