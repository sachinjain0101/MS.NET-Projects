CREATE PROCEDURE [dbo].[usp_RPTClockDetailIndiv_T4ME]
(
	 @Client CHAR(4)
	,@Group INT
	,@Date DATETIME
) AS

SET NOCOUNT ON;

CREATE TABLE #tempT3ME
(
	PPED DATE
	,TransDate DATE
	,SSN INT
 ,RecordID BIGINT  --< RecordId data type is changed from  INT to BIGINT by Srinsoft on 01Sept2016 >--
	,Lunch_Mins TINYINT
);

SELECT EN.PrimaryDept, THD.PayrollPeriodEndDate as PPED, EN.SSN,EN.EmplPin EmployeeId,EN.LastName, 
EN.FirstName, EN.FileNo, EN.PrimaryJObCode, THD.ShiftNo,THD.ShiftDiffClass,
RIGHT('000'+LTRIM(STR(gd.deptno)),3) + '-' + GD.DeptName as DeptName, DeptNo = '',
LTRIM(STR(sn.SiteNo)) as SiteAlias, 
THD.TransDate, 
SrcAbrev1 = (CASE WHEN THD.InSrc = '3' AND THD.UserCode + '' <> '' Then THD.UserCode ELSE InSrc.SrcAbrev END), 
ActualInPunch = dbo.PunchDateTime(thd.transDate, thd.InDay, thd.InTime), 
InDay, 
InDayName = NDAY.DayAbrev,
InTime = CASE WHEN THD.InDay = 10 OR (THD.ActualInTime = '12/30/1899 00:00' and THD.ClockAdjustmentNo <> '') THEN NULL ELSE convert(varchar(8),IsNull(THD.ActualInTime,THD.InTime),108) END,
SrcAbrev2 = (CASE WHEN THD.OutSrc = '3' AND THD.outUserCode + '' <> '' Then THD.outUserCode ELSE OutSrc.SrcAbrev END), 
OutDay = CASE WHEN THD.OutDay = 10 THEN '0' ELSE THD.OutDay END, 
OutDayName = ODAY.DayAbrev,
OutTime = CASE WHEN THD.OutDay = 10 OR (THD.ActualOutTime = '12/30/1899 00:00' and THD.ClockAdjustmentNo <> '') THEN NULL ELSE convert(varchar(8),IsNull(THD.ActualOutTime,THD.OutTime),108) END,
ActualInTime = CASE WHEN THD.InDay = 10 OR (THD.ActualInTime = '12/30/1899 00:00' and THD.ClockAdjustmentNo <> '') THEN NULL ELSE THD.ActualInTime END, 
ActualOutTime = CASE WHEN THD.OutDay = 10 OR (THD.ActualOutTime = '12/30/1899 00:00' and THD.ClockAdjustmentNo > '') THEN NULL ELSE THD.ActualOutTime END, 
ADjustmentName = Thd.ClockAdjustmentNo + ' ' + THD.AdjustmentName,THD.Dollars, THD.Hours, THD.SiteNo, 
THD.RegHours, THD.OT_Hours, THD.DT_Hours, 
ARegHours = THD.AllocatedRegHours, AOT_Hours = THD.AllocatedOT_Hours, ADT_Hours = THD.AllocatedDT_Hours, 
THD.PayRate, THD.BillOTRate, PayAmount = THD.RegDollars4 + THD.OT_Dollars4 + THD.DT_Dollars4
, reasons.ReasonCodeID 
, CASE WHEN BackupApproval.RecordId IS NOT NULL THEN BackupApproval.FirstName + ' ' + BackupApproval.LastName 
	WHEN ISNull(cg.StaffingSetupType, '0') <> '0' THEN isnull(tblUser.Email, '') ELSE tblUser.FirstName + ' ' + tblUser.LastName END as ApproverName 
, CASE WHEN thd.AprvlStatus IN ('A','L') THEN 'Approved' ELSE '' END as ApprovalStatus 
, AprvlStatus_Date 
,THD.RecordID,THD.InClass,THD.OutClass
INTO #T3METempTable 
FROM tblTimeHistDetail AS THD WITH(NOLOCK) 
INNER JOIN TimeCurrent..tblClientGroups cg  WITH(NOLOCK) 
ON cg.Client = thd.Client 
AND cg.GroupCode = thd.GroupCode
Left JOIN TimeCurrent..tblEmplNames as EN WITH (INDEX(ssn_key), NOLOCK) ON 
THD.Client = EN.Client AND THD.GroupCode = EN.GroupCode 
AND THD.SSN = EN.SSN 
LEFT JOIN TimeCurrent..tblGroupDepts as GD  WITH(NOLOCK) ON 
THD.Client = GD.Client AND THD.GroupCode = GD.GroupCode 
AND THD.DeptNo = GD.DeptNo 
LEFT JOIN TimeCurrent..tblInOutSrc AS OutSrc  WITH(NOLOCK) ON 
THD.OutSrc = OutSrc.Src 
LEFT JOIN TimeCurrent..tblInOutSrc AS InSrc  WITH(NOLOCK) ON 
THD.InSrc = InSrc.Src 
LEFT JOIN TimeCurrent..tblDayDef AS NDAY  WITH(NOLOCK) ON 
THD.InDay = NDAY.DayNo 
LEFT JOIN TimeCurrent..tblDayDef AS ODAY  WITH(NOLOCK) ON 
THD.OutDay = ODAY.DayNo 
LEFT JOIN TimeCurrent..tblAdjCodes AS AC  WITH(NOLOCK) ON
THD.Client = AC.Client AND THD.GroupCode = AC.GroupCode 
AND THD.ClockAdjustmentNo = AC.ClockAdjustmentNo 
LEFT JOIN tblTimeHistDetail_Reasons AS reasons  WITH(NOLOCK) 
ON reasons.Client = thd.Client 
AND reasons.GroupCode = thd.GroupCode 
AND reasons.SSN = thd.SSN 
AND reasons.PPED = thd.PayrollPeriodEndDate 
AND ((InTime IS NULL AND reasons.AdjustmentRecordID = thd.RecordID) OR (NOT (InTime IS NULL) AND reasons.AdjustmentRecordID = 0 AND reasons.InPunchDateTime = dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime))) 
LEFT JOIN TimeCurrent..tblSiteNames as SN WITH(NOLOCK) 
ON SN.Client = thd.Client 
AND SN.GroupCode = thd.GroupCode 
AND SN.SiteNo = thd.SiteNo 
Left Join TimeCurrent..tblUser as tblUser  WITH(NOLOCK) ON 
tblUser.UserID = THD.AprvlStatus_UserID 
Left Join TimeHistory..tblTimeHistDetail_BackupApproval as BackupApproval  WITH(NOLOCK) ON 
BackupApproval.THDRecordId = THD.RecordId 
LEFT JOIN TimeCurrent..tblReasonCodes AS reasoncodes  WITH(NOLOCK) 
ON reasoncodes.Client = reasons.Client 
AND reasoncodes.GroupCode = reasons.GroupCode 
AND reasoncodes.ReasonCodeID = reasons.ReasonCodeID 
WHERE
THD.Client = @Client
AND THD.GroupCode = @Group
AND THD.PayrollPeriodEndDate = @Date
ORDER BY THD.SSN,THD.PayrollPeriodEndDate,THD.TransDate,THD.ClockAdjustmentNo,ActualInPunch,THD.InDay,THD.InTime,THD.OutTime 

UPDATE X SET
InClass = Y.InClass
,OutClass = Y.OutClass
FROM
#T3METempTable X
INNER JOIN
(
 SELECT
 thd.RecordID
 ,InClass = CASE WHEN thd.InClass = '' THEN 'S' ELSE thd.InClass END
 ,OutClass = 'L'
 FROM TimeHistory.dbo.tblTimeHistDetail thd
 INNER JOIN TimeHistory.dbo.tblTimeHistDetail thd2
 ON thd.Client = thd2.Client
 AND thd.GroupCode = thd2.GroupCode
 AND thd.SSN = thd2.SSN
 AND thd.SiteNo = thd2.SiteNo
 AND thd.DeptNo = thd2.DeptNo
 AND thd.PayrollPeriodEndDate = thd2.PayrollPeriodEndDate
 AND thd.TransDate = thd2.TransDate
 AND thd.ActualOutTime < thd2.ActualInTime
 AND ABS(DATEDIFF(MI,thd.ActualOutTime,thd2.ActualInTime)) <= 90
 AND thd.ClockAdjustmentNo IN ('',' ')
 AND thd2.ClockAdjustmentNo IN ('',' ')
 AND thd.Hours <> 0
 AND thd2.Hours <> 0
 AND thd.OutClass IN ('','S')
 AND thd2.InClass IN ('','S')
 INNER JOIN #T3METempTable T
 ON T.RecordID = thd.RecordID
 UNION
 SELECT
 thd2.RecordID
 ,InClass = 'L'
 ,OutClass = CASE WHEN thd2.OutClass = '' THEN 'S' ELSE thd2.OutClass END
 FROM TimeHistory.dbo.tblTimeHistDetail thd
 INNER JOIN TimeHistory.dbo.tblTimeHistDetail thd2
 ON thd.Client = thd2.Client
 AND thd.GroupCode = thd2.GroupCode
 AND thd.SSN = thd2.SSN
 AND thd.SiteNo = thd2.SiteNo
 AND thd.DeptNo = thd2.DeptNo
 AND thd.PayrollPeriodEndDate = thd2.PayrollPeriodEndDate
 AND thd.TransDate = thd2.TransDate
 AND thd.ActualOutTime < thd2.ActualInTime
 AND ABS(DATEDIFF(MI,thd.ActualOutTime,thd2.ActualInTime)) <= 90
 AND thd.ClockAdjustmentNo IN ('',' ')
 AND thd2.ClockAdjustmentNo IN ('',' ')
 AND thd.Hours <> 0
 AND thd2.Hours <> 0
 AND thd.OutClass IN ('','S')
 AND thd2.InClass IN ('','S')
 INNER JOIN #T3METempTable T2
 ON T2.RecordID = thd2.RecordID
) Y
  ON Y.RecordID = X.RecordID;

INSERT INTO #tempT3ME
(PPED,TransDate,SSN,RecordID,Lunch_Mins)
SELECT
 THDa.PPED
,THDa.TransDate
,THDa.SSN
,THDb.RecordID
,Lunch_Mins = DATEDIFF(MI,THDa.ActualOutTime,THDb.ActualInTime)
FROM
#T3METempTable THDa WITH (NOLOCK)
INNER JOIN
#T3METempTable THDb WITH (NOLOCK)
ON THDb.PPED = THDa.PPED
AND THDb.TransDate = THDa.TransDate
AND THDb.SSN = THDa.SSN
AND THDb.SiteNo = THDa.SiteNo
WHERE
 (THDa.OutDay <> 10 AND THDa.ActualOutTime <> '12/30/1899 00:00')
AND THDa.OutClass = 'L'
AND (THDb.InDay <> 10 AND THDb.ActualInTime <> '12/30/1899 00:00')
AND THDb.InClass = 'L'
AND ABS(DATEDIFF(MI,THDa.ActualOutTime,THDb.ActualInTime)) <= 90;

SELECT DISTINCT
GroupName = CAST(cCG.GroupCode AS VARCHAR(10)) + ' - ' + cCG.GroupName
,Employee = A.LastName + ', ' + A.FirstName
,EmployeeID = A.SSN
,WeekEnding = CONVERT(CHAR(10),A.PPED,101)
,[Site] = A.SiteAlias
,Dept = A.DeptName
,[Shift] = A.ShiftNo
,ShiftClass = A.ShiftDiffClass
,[Date] = CONVERT(CHAR(10),A.TransDate,101)
,InSrc = A.SrcAbrev1
,InDay = CASE A.InDayName WHEN 'UNK' THEN '' ELSE A.InDayName END
,InTime = LEFT(CAST(A.InTime AS TIME),5)
,Lunch_Mins =
	CASE
		WHEN A.OutClass IN ('L','S') AND A.InClass = 'L' AND A.[Hours] <> 0.00 
				THEN CAST(B.Lunch_Mins AS VARCHAR(5))
		ELSE ''
	END
,OutSrc = A.SrcAbrev2
,OutDay = CASE A.OutDayName WHEN 'UNK' THEN '' ELSE A.OutDayName END
,OutTime = LEFT(CAST(A.OutTime AS TIME),5)
,Adjust = LTRIM(RTRIM(A.AdjustmentName))
,TotHrs = A.[Hours]
,A.RegHours
,A.OT_Hours
,A.DT_Hours
,A.Dollars
FROM #T3METempTable A
LEFT JOIN
#tempT3ME B
ON B.PPED = A.PPED
AND B.TransDate = A.TransDate
AND B.SSN = A.SSN
AND B.RecordID = A.RecordID
INNER JOIN
TimeCurrent.dbo.tblClientGroups cCG
ON cCG.Client = @Client
AND cCG.GroupCode = @Group
ORDER BY
GroupName
,Employee
,[Date];

DROP TABLE #T3METempTable;
DROP TABLE #tempT3ME;

