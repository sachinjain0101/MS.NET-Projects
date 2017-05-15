Create PROCEDURE [dbo].[usp_WTE_GetSummaryCard] (
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

SET @Client       = 'CIG3'
SET @GroupCode    = 900100
SET @SSN          = 888001779
SET @PPED         = '2/17/07'

SET @Client       = 'CIG1'
SET @GroupCode    = 900000
SET @SSN          = 999001777
SET @PPED         = '2/10/07'
*/

DECLARE @Date1  datetime
DECLARE @Date2  datetime
DECLARE @Date3  datetime
DECLARE @Date4  datetime
DECLARE @Date5  datetime
DECLARE @Date6  datetime
DECLARE @Date7  datetime

SET @Date1 = DATEADD(d, -6, @PPED)
SET @Date2 = DATEADD(d, -5, @PPED)
SET @Date3 = DATEADD(d, -4, @PPED)
SET @Date4 = DATEADD(d, -3, @PPED)
SET @Date5 = DATEADD(d, -2, @PPED)
SET @Date6 = DATEADD(d, -1, @PPED)
SET @Date7 = @PPED

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

PRINT @Date1

--/*
-- This method is almost 3 times as fast.
SELECT 
  thd.SiteNo, thd.SiteName,
  thd.DeptNo, thd.DeptName,
  SUM(CASE WHEN TransDate = @Date1 THEN Hours ELSE 0 END) AS Hours1,
  SUM(CASE WHEN TransDate = @Date2 THEN Hours ELSE 0 END) AS Hours2,
  SUM(CASE WHEN TransDate = @Date3 THEN Hours ELSE 0 END) AS Hours3,
  SUM(CASE WHEN TransDate = @Date4 THEN Hours ELSE 0 END) AS Hours4,
  SUM(CASE WHEN TransDate = @Date5 THEN Hours ELSE 0 END) AS Hours5,
  SUM(CASE WHEN TransDate = @Date6 THEN Hours ELSE 0 END) AS Hours6,
  SUM(CASE WHEN TransDate = @Date7 THEN Hours ELSE 0 END) AS Hours7,
  SUM(thd.Hours) AS TotalHours,
  SUM(CASE WHEN TransDate = @Date1 THEN Dollars ELSE 0 END) AS Dollars1,
  SUM(CASE WHEN TransDate = @Date2 THEN Dollars ELSE 0 END) AS Dollars2,
  SUM(CASE WHEN TransDate = @Date3 THEN Dollars ELSE 0 END) AS Dollars3,
  SUM(CASE WHEN TransDate = @Date4 THEN Dollars ELSE 0 END) AS Dollars4,
  SUM(CASE WHEN TransDate = @Date5 THEN Dollars ELSE 0 END) AS Dollars5,
  SUM(CASE WHEN TransDate = @Date6 THEN Dollars ELSE 0 END) AS Dollars6,
  SUM(CASE WHEN TransDate = @Date7 THEN Dollars ELSE 0 END) AS Dollars7,
  SUM(thd.Dollars) AS TotalDollars,
  SUM(CASE WHEN TransDate = @Date1 AND (thd.InDay IN (10, 11) OR thd.OutDay IN (10, 11) AND thd.RecordID <> @MPMinRecordID) THEN 1 ELSE 0 END) AS MP1,
  SUM(CASE WHEN TransDate = @Date2 AND (thd.InDay IN (10, 11) OR thd.OutDay IN (10, 11) AND thd.RecordID <> @MPMinRecordID) THEN 1 ELSE 0 END) AS MP2,
  SUM(CASE WHEN TransDate = @Date3 AND (thd.InDay IN (10, 11) OR thd.OutDay IN (10, 11) AND thd.RecordID <> @MPMinRecordID) THEN 1 ELSE 0 END) AS MP3,
  SUM(CASE WHEN TransDate = @Date4 AND (thd.InDay IN (10, 11) OR thd.OutDay IN (10, 11) AND thd.RecordID <> @MPMinRecordID) THEN 1 ELSE 0 END) AS MP4,
  SUM(CASE WHEN TransDate = @Date5 AND (thd.InDay IN (10, 11) OR thd.OutDay IN (10, 11) AND thd.RecordID <> @MPMinRecordID) THEN 1 ELSE 0 END) AS MP5,
  SUM(CASE WHEN TransDate = @Date6 AND (thd.InDay IN (10, 11) OR thd.OutDay IN (10, 11) AND thd.RecordID <> @MPMinRecordID) THEN 1 ELSE 0 END) AS MP6,
  SUM(CASE WHEN TransDate = @Date7 AND (thd.InDay IN (10, 11) OR thd.OutDay IN (10, 11) AND thd.RecordID <> @MPMinRecordID) THEN 1 ELSE 0 END) AS MP7,
  MAX(CASE WHEN thd.RecordID = @MPMinRecordID THEN thd.TransDate ELSE NULL END) AS CurrentPunchDate,
	MAX(thd.TransDate) AS MaxPunchDate
FROM (
	SELECT 
	  thd.SiteNo, sites.SiteName,
	  thd.DeptNo, 
	  CASE ISNULL(depts.DeptName_Long, '') WHEN '' THEN depts.DeptName ELSE depts.DeptName_Long END AS DeptName,
		thd.Hours, thd.Dollars,	thd.InDay, thd.OutDay, thd.TransDate, thd.RecordID
	FROM TimeHistory.dbo.tblTimeHistDetail thd
	LEFT JOIN TimeCurrent.dbo.tblSiteNames sites
	ON sites.Client = thd.Client
	  AND sites.GroupCode = thd.GroupCode
	  AND sites.SiteNo = thd.SiteNo
	LEFT JOIN TimeCurrent.dbo.tblGroupDepts depts
	ON depts.Client = thd.Client
	  AND depts.GroupCode = thd.GroupCode
	--  AND depts.SiteNo = thd.SiteNo
	  AND depts.DeptNo = thd.DeptNo
  Inner Join TimeCurrent.dbo.tblAdjCodes as adj
  on adj.Client = thd.Client
  and adj.groupcode = thd.Groupcode
  and adj.ClockAdjustmentNo = case when thd.clockadjustmentno in('',' ') then '1' else thd.Clockadjustmentno end
  and isnull(adj.SpecialHandling,'') <> 'EXCL'
	WHERE thd.Client = @Client
	  AND thd.GroupCode = @GroupCode
	  AND thd.SSN = @SSN
	  AND thd.PayrollPeriodEndDate = @PPED
) thd
GROUP BY thd.SiteNo, thd.SiteName, thd.DeptNo, thd.DeptName
--*/

/*
SELECT 
  thd.SiteNo, sites.SiteName,
  thd.DeptNo, 
  CASE ISNULL(depts.DeptName_Long, '') WHEN '' THEN depts.DeptName ELSE depts.DeptName_Long END AS DeptName,
  SUM(CASE WHEN TransDate = @Date1 THEN Hours ELSE 0 END) AS Hours1,
  SUM(CASE WHEN TransDate = @Date2 THEN Hours ELSE 0 END) AS Hours2,
  SUM(CASE WHEN TransDate = @Date3 THEN Hours ELSE 0 END) AS Hours3,
  SUM(CASE WHEN TransDate = @Date4 THEN Hours ELSE 0 END) AS Hours4,
  SUM(CASE WHEN TransDate = @Date5 THEN Hours ELSE 0 END) AS Hours5,
  SUM(CASE WHEN TransDate = @Date6 THEN Hours ELSE 0 END) AS Hours6,
  SUM(CASE WHEN TransDate = @Date7 THEN Hours ELSE 0 END) AS Hours7,
  SUM(thd.Hours) AS TotalHours,
  SUM(CASE WHEN TransDate = @Date1 THEN Dollars ELSE 0 END) AS Dollars1,
  SUM(CASE WHEN TransDate = @Date2 THEN Dollars ELSE 0 END) AS Dollars2,
  SUM(CASE WHEN TransDate = @Date3 THEN Dollars ELSE 0 END) AS Dollars3,
  SUM(CASE WHEN TransDate = @Date4 THEN Dollars ELSE 0 END) AS Dollars4,
  SUM(CASE WHEN TransDate = @Date5 THEN Dollars ELSE 0 END) AS Dollars5,
  SUM(CASE WHEN TransDate = @Date6 THEN Dollars ELSE 0 END) AS Dollars6,
  SUM(CASE WHEN TransDate = @Date7 THEN Dollars ELSE 0 END) AS Dollars7,
  SUM(thd.Dollars) AS TotalDollars,
  SUM(CASE WHEN TransDate = @Date1 AND (thd.InDay IN (10, 11) OR thd.OutDay IN (10, 11) AND thd.RecordID <> @MPMinRecordID) THEN 1 ELSE 0 END) AS MP1,
  SUM(CASE WHEN TransDate = @Date2 AND (thd.InDay IN (10, 11) OR thd.OutDay IN (10, 11) AND thd.RecordID <> @MPMinRecordID) THEN 1 ELSE 0 END) AS MP2,
  SUM(CASE WHEN TransDate = @Date3 AND (thd.InDay IN (10, 11) OR thd.OutDay IN (10, 11) AND thd.RecordID <> @MPMinRecordID) THEN 1 ELSE 0 END) AS MP3,
  SUM(CASE WHEN TransDate = @Date4 AND (thd.InDay IN (10, 11) OR thd.OutDay IN (10, 11) AND thd.RecordID <> @MPMinRecordID) THEN 1 ELSE 0 END) AS MP4,
  SUM(CASE WHEN TransDate = @Date5 AND (thd.InDay IN (10, 11) OR thd.OutDay IN (10, 11) AND thd.RecordID <> @MPMinRecordID) THEN 1 ELSE 0 END) AS MP5,
  SUM(CASE WHEN TransDate = @Date6 AND (thd.InDay IN (10, 11) OR thd.OutDay IN (10, 11) AND thd.RecordID <> @MPMinRecordID) THEN 1 ELSE 0 END) AS MP6,
  SUM(CASE WHEN TransDate = @Date7 AND (thd.InDay IN (10, 11) OR thd.OutDay IN (10, 11) AND thd.RecordID <> @MPMinRecordID) THEN 1 ELSE 0 END) AS MP7,
  MAX(CASE WHEN thd.RecordID = @MPMinRecordID THEN thd.TransDate ELSE NULL END) AS CurrentPunchDate
FROM TimeHistory.dbo.tblTimeHistDetail thd
LEFT JOIN TimeCurrent.dbo.tblSiteNames sites
ON sites.Client = thd.Client
  AND sites.GroupCode = thd.GroupCode
  AND sites.SiteNo = thd.SiteNo
LEFT JOIN TimeCurrent.dbo.tblGroupDepts depts
ON depts.Client = thd.Client
  AND depts.GroupCode = thd.GroupCode
--  AND depts.SiteNo = thd.SiteNo
  AND depts.DeptNo = thd.DeptNo
WHERE thd.Client = @Client
  AND thd.GroupCode = @GroupCode
  AND thd.SSN = @SSN
  AND thd.PayrollPeriodEndDate = @PPED
GROUP BY thd.SiteNo, sites.SiteName, thd.DeptNo, depts.DeptName, depts.DeptName_Long
ORDER BY thd.SiteNo, thd.DeptNo
*/




