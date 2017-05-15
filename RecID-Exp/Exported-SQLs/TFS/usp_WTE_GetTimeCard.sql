Create PROCEDURE [dbo].[usp_WTE_GetTimeCard] (
	@Client					varchar(4),
	@GroupCode			int,
	@SSN						int,
	@PPED						datetime
)
AS

SET NOCOUNT ON
--*/

/*
DECLARE	@Client					varchar(4)
DECLARE	@GroupCode			int
DECLARE	@SSN						int
DECLARE	@PPED						datetime

SET @Client							= 'CIG1'
SET @GroupCode					= 900000
SET @SSN								= 999001777
SET @PPED								= '1/27/07'
*/

DECLARE @MPMinDateTime  datetime
DECLARE @MPMinTransDate datetime
DECLARE @MPMinRecordID  BIGINT  --< @MPMinRecordId data type is changed from  INT to BIGINT by Srinsoft on 16Sept2016 >--

SET @MPMinDateTime = DATEADD(hour, -16, TimeHistory.dbo.SiteDateTime(@Client, @GroupCode, 1, GETUTCDATE()))
SET @MPMinTransDate = DATEADD(d, -1, @MPMinDateTime)

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

-- Site, Dept, Shift, Shift Class, Date, In, Out, Adjustment, Tot, Reg, OT, DT, $, Rsn

IF @Client IN ('DAVI', 'DVPC', 'DVPG', 'DAVI', 'HCPA')
	SELECT thd.SiteNo, s.SiteName, thd.DeptNo, CASE ISNULL(d.DeptName_Long, '') WHEN '' THEN d.DeptName ELSE d.DeptName_Long END AS DeptName,
		thd.ShiftNo, thd.ShiftDiffClass, thd.TransDate, s1.SrcAbrev AS InSrc, d1.DayAbrev AS InDay, thd.InTime,	s2.SrcAbrev AS OutSrc, d2.DayAbrev AS OutDay, thd.OutTime,
		thd.ClockAdjustmentNo, thd.AdjustmentName, 
		thd.Hours, thd.RegHours, thd.OT_Hours, thd.DT_Hours,	thd.Dollars, thd.UserCode, thd.OutUserCode,
		CASE WHEN thd.ClockAdjustmentNo IN ('$', '@') THEN thd.AprvlAdjOrigClkAdjNo ELSE thd.ClockAdjustmentNo END AS ClkAdjSeq,
		CASE WHEN thd.ClockAdjustmentNo IN ('$', '@') THEN thd.AprvlAdjOrigRecID ELSE thd.RecordID END AS RecordIDSeq,
	  CASE WHEN thd.InDay IN (10, 11) OR (thd.OutDay IN (10, 11) AND thd.RecordID <> @MPMinRecordID) THEN 1 ELSE 0 END AS MP
	FROM TimeHistory.dbo.tblTimeHistDetail thd
	LEFT JOIN TimeCurrent.dbo.tblSiteNames s ON s.Client = @Client AND s.GroupCode = @GroupCode	AND s.SiteNo = thd.SiteNo
	LEFT JOIN TimeCurrent.dbo.tblGroupDepts d ON d.Client = @Client	AND d.GroupCode = @GroupCode AND d.DeptNo = thd.DeptNo
	LEFT JOIN TimeHistory.dbo.tblDayDef d1 ON d1.DayNo = thd.InDay
	LEFT JOIN TimeHistory.dbo.tblDayDef d2 ON d2.DayNo = thd.OutDay
	LEFT JOIN TimeCurrent.dbo.tblInOutSrc s1 ON s1.Src = thd.InSrc
	LEFT JOIN TimeCurrent.dbo.tblInOutSrc s2 ON s2.Src = thd.OutSrc
	LEFT JOIN TimeCurrent.dbo.tblAdjCodes a ON a.Client = @Client AND a.GroupCode = @GroupCode AND a.ClockAdjustmentNo = thd.ClockAdjustmentNo
	WHERE thd.Client = @Client
		AND thd.GroupCode = @GroupCode
		AND thd.SSN = @SSN
		AND thd.PayrollPeriodEndDate = @PPED
 	ORDER BY thd.TransDate, ClkAdjSeq, thd.InTime, thd.ClkTransNo, RecordIDSeq, thd.RecordID
ELSE
	SELECT thd.SiteNo, s.SiteName, thd.DeptNo, CASE ISNULL(d.DeptName_Long, '') WHEN '' THEN d.DeptName ELSE d.DeptName_Long END AS DeptName,
		thd.ShiftNo, thd.ShiftDiffClass, thd.TransDate, s1.SrcAbrev AS InSrc, d1.DayAbrev AS InDay, thd.InTime,	s2.SrcAbrev AS OutSrc, d2.DayAbrev AS OutDay, thd.OutTime,
		thd.ClockAdjustmentNo, a.AdjustmentName, thd.Hours, thd.RegHours, thd.OT_Hours, thd.DT_Hours,	
		Dollars = (Case when @Client in('HILT', 'HLT1') THEN
									(CASE WHEN left(isnull(THD.CostID,''),1) = '1' THEN 1 WHEN left(isnull(THD.CostID,''),1) = '2' THEN 2 WHEN left(isnull(THD.CostID,''),1) = 'G' THEN 2 ELSE 0 end)
									ELSE thd.Dollars END), 
		thd.UserCode, thd.OutUserCode,
		ActualInPunch = TimeHistory.dbo.PunchDateTime(thd.TransDate, thd.InDay, thd.InTime),
		CASE WHEN thd.ClockAdjustmentNo IN ('$', '@') THEN thd.AprvlAdjOrigClkAdjNo ELSE thd.ClockAdjustmentNo END AS ClkAdjSeq,
		CASE WHEN thd.ClockAdjustmentNo IN ('$', '@') THEN thd.AprvlAdjOrigRecID ELSE thd.RecordID END AS RecordIDSeq,
	  CASE WHEN thd.InDay IN (10, 11) OR (thd.OutDay IN (10, 11) AND thd.RecordID <> @MPMinRecordID) THEN 1 ELSE 0 END AS MP
	FROM TimeHistory.dbo.tblTimeHistDetail thd
	LEFT JOIN TimeCurrent.dbo.tblSiteNames s ON s.Client = @Client AND s.GroupCode = @GroupCode	AND s.SiteNo = thd.SiteNo
	LEFT JOIN TimeCurrent.dbo.tblGroupDepts d ON d.Client = @Client	AND d.GroupCode = @GroupCode AND d.DeptNo = thd.DeptNo
	LEFT JOIN TimeHistory.dbo.tblDayDef d1 ON d1.DayNo = thd.InDay
	LEFT JOIN TimeHistory.dbo.tblDayDef d2 ON d2.DayNo = thd.OutDay
	LEFT JOIN TimeCurrent.dbo.tblInOutSrc s1 ON s1.Src = thd.InSrc
	LEFT JOIN TimeCurrent.dbo.tblInOutSrc s2 ON s2.Src = thd.OutSrc
	LEFT JOIN TimeCurrent.dbo.tblAdjCodes a ON a.Client = @Client AND a.GroupCode = @GroupCode AND a.ClockAdjustmentNo = thd.ClockAdjustmentNo
	WHERE thd.Client = @Client
		AND thd.GroupCode = @GroupCode
		AND thd.SSN = @SSN
		AND thd.PayrollPeriodEndDate = @PPED
	ORDER BY thd.TransDate, ClkAdjSeq, ActualInPunch, thd.ClkTransNo, RecordIDSeq, thd.RecordID


