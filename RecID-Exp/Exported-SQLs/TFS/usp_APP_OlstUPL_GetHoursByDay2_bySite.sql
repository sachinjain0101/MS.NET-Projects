Create PROCEDURE [dbo].[usp_APP_OlstUPL_GetHoursByDay2_bySite]
( 
  @Client char(4),
  @GroupCode int,
  @PPED DateTime,
  @RecordType char(1) = '' 
) 
AS

SET NOCOUNT ON

/*
DECLARE  @Client char(4)
DECLARE  @GroupCode int
DECLARE  @PPED DateTime
DECLARE  @RecordType char(1)

SET @Client = 'OLST'
SET @GroupCode = 153
SET @PPED = '12/26/2010'
Set @RecordType = 'F'

DROP TABLE #tmpSSNs
DROP TABLE #tmpDailyHrs
DROP TABLE #tmpTotHrs
DROP TABLE #tmpDailyHrs1
DROP TABLE #tmpWorkedSummary
DROP TABLE #tmpProjectSummary
*/

-- Temp reroute for Adecco Canada to test pay files.
IF @Client = 'ADCA'
BEGIN

  EXECUTE TimeHistory.[dbo].[usp_APP_OlstUPL_GetHoursByDay2_bySite_ADCA] @Client,@GroupCode,@PPED,@RecordType
  Return

END

DECLARE @ShiftZeroCount int
DECLARE @CalcBalanceCnt int
DECLARE @UseDeptName char(1)
DECLARE @OpenDepts char(1)
DECLARE @UsePFP char(1)
DECLARE @ClientGroupID1 varchar(200)
DECLARE @grpOTMult numeric(15,10) 
DECLARE @prOTMult numeric(15,10)
DECLARE @OTMult numeric(15,10)

-- Project Related
DECLARE @SSN INT
DECLARE @AssignmentNo VARCHAR(32)
DECLARE @TransDate DATETIME
DECLARE @ProjectNum VARCHAR(60)
DECLARE @Hours NUMERIC(7,2)
DECLARE @WorkedHours NUMERIC(7,2)
DECLARE @RecordId INT
DECLARE @TotalRegHours NUMERIC(7,2)
DECLARE @TotalOT_Hours NUMERIC(7,2)
DECLARE @TotalDT_Hours NUMERIC(7,2)
DECLARE @TotalProjectLines INT 
DECLARE @LoopCounter INT 
DECLARE @MinProjectId INT 
DECLARE @ProjectHours NUMERIC(7,2)
DECLARE @RegBalance NUMERIC(7,2)
DECLARE @OTBalance NUMERIC(7,2)
DECLARE @DTBalance NUMERIC(7,2)
DECLARE @RegAvailable NUMERIC(7,2)
DECLARE @OTAvailable NUMERIC(7,2)
DECLARE @DTAvailable NUMERIC(7,2)
DECLARE @ProjectRemaining NUMERIC(7,2)
DECLARE @TimeSheetLevel VARCHAR(1)
------------------------------------------------------
DECLARE @FaxApprover INT
SET @FaxApprover = (SELECT UserID FROM TimeCurrent..tblUser WHERE JobDesc = 'FAXAROO_DEFAULT_APPROVER' AND Client = @Client)
----------------------------------------------------
Set @UseDeptName = '0'
Set @OpenDepts = '0'
Set @UsePFP = '0'

SELECT @ClientGroupID1 = isnull(ClientGroupID1, ''), 
			 @grpOTMult = BillingOvertimeCalcFactor 
FROM TimeCurrent..tblClientGroups 
WHERE Client = @Client 
AND GroupCode = @GroupCode

IF @ClientGroupID1 like '%UseDeptName%'
  Set @UseDeptName = '1'

IF @ClientGroupID1 like '%UseOpenDepts%'
  Set @OpenDepts = '1'

IF @ClientGroupID1 like '%UsePFP%'
  Set @UsePFP = '1'



-- based on the RecordType get a list of employees.
--
Create Table #tmpSSNs
( 
	SSN INT, 
	TransCount INT, 
	ApprovedCount INT,
	PayRecordsSent datetime,
	AprvlStatus_Date DATETIME,
	IVR_Count INT, 
	WTE_Count INT, 
	Fax_Count INT, 
	FaxApprover_Count INT,  
	EmailClient_Count INT,
	EmailOther_Count INT, 
	Dispute_Count INT,
	OtherTxns_Count INT,
	AssignmentNo varchar(50),
	LateApprovals INT,
	SnapshotDateTime DATETIME,
	AssignmentTypeId INT,
	SendAsUnapproved BIT
)

CREATE TABLE #tmpWorkedSummary
(
	RecordId INT IDENTITY,
	Client VARCHAR(4),
	GroupCode INT,
	PayrollPeriodEndDate DATETIME,  
	TransDate datetime,  
	SSN int,  
	FileNo VARCHAR(100),
	AssignmentNo VARCHAR(100),  
	BranchID VARCHAR(100),
	DeptName VARCHAR(100),
	TotalRegHours NUMERIC(7,2),  
	TotalOT_Hours NUMERIC(7,2),  
	TotalDT_Hours NUMERIC(7,2), 
	TotalWeeklyHours NUMERIC(7,2),
	ApproverName VARCHAR(100),
	ApproverDateTime datetime,
	ApprovalID int,
	ApprovalStatus VARCHAR(100),
	DayWorked VARCHAR(100),
	FlatPay NUMERIC(7,2),
	FlatBill NUMERIC(7,2),
	EmplName VARCHAR(100),
	PFP_Flag VARCHAR(100),
	PayRate NUMERIC(7,2),
	BillRate NUMERIC(7,2),
	Source VARCHAR(1),
	SnapshotDateTime DATETIME
)

CREATE TABLE #tmpProjectSummary
(
	RecordId INT IDENTITY,
	SSN INT, 
	AssignmentNo VARCHAR(100), 
	TransDate DATETIME, 
	ProjectNum VARCHAR(60), 
	Hours NUMERIC(7,2)
)

/*
A = All Approved
F = Full (Approved and Unapproved)
L = Late Time
P = Late Approval
*/

IF (@RecordType IN ('A', 'L', 'F'))
BEGIN
	Insert into #tmpSSNs (SSN, PayRecordsSent, AssignmentNo, TransCount, ApprovedCount, AprvlStatus_Date,
												IVR_Count, WTE_Count, Fax_Count, FaxApprover_Count, EmailClient_Count, EmailOther_Count, Dispute_Count, OtherTxns_Count, LateApprovals, SnapshotDateTime, AssignmentTypeId, SendAsUnapproved)
	select 	t.SSN, 
				  PayRecordsSent = ISNULL(ISNULL(th_esds.PayRecordsSent, en.PayRecordsSent), '1/1/1970'), 
				  ea.AssignmentNo,
				  TransCount = SUM(1),
				  ApprovedCount = SUM(CASE WHEN t.AprvlStatus IN ('A', 'L') THEN 1 ELSE 0 END),
				  AprvlStatus_Date = MAX(isnull(t.AprvlStatus_Date,'1/2/1970')),
				  IVR_Count = SUM(CASE WHEN t.UserCode = 'IVR' THEN 1 ELSE 0 END),
				  WTE_Count = SUM(CASE WHEN t.UserCode IN ('WTE', 'VTS') THEN 1 ELSE 0 END),
				  Fax_Count =  SUM(CASE WHEN t.UserCode = 'FAX' THEN 1 ELSE 0 END),
				  FaxApprover_Count =  SUM(CASE WHEN ISNULL(t.AprvlStatus_UserID, 0) = @FaxApprover THEN 1 ELSE 0 END), 
				  EmailClient_Count =  SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode = 'CLI') THEN 1 ELSE 0 END),  
				  EmailOther_Count =  SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode in ('BRA', 'COR', 'AGE')) THEN 1 ELSE 0 END),   
				  Dispute_Count = SUM(CASE WHEN t.ClockAdjustmentNo IN ('$', '@') THEN 1 ELSE 0 END),
				  OtherTxns_Count = SUM(CASE WHEN t.ClockAdjustmentNo NOT IN ('$', '@', '') AND ISNULL(t.UserCode, '') NOT IN ('WTE','COR', 'FAX', 'EML', 'SYS') AND ISNULL(t.OutUserCode, '') NOT in ('CLI', 'BRA', 'COR', 'AGE') THEN 1 ELSE 0 END),
				  LateApprovals = 0,
				  SnapshotDateTime = GetDate(),
				  ISNULL(ea.AssignmentTypeId,0),
				  0
	FROM TimeHistory..tblTimeHistDetail as t
	INNER JOIN TimeHistory..tblEmplNames as en
	ON en.Client = t.Client 
	AND en.GroupCode = t.GroupCode 
	AND en.SSN = t.SSN
	AND en.PayrollPeriodenddate = t.PayrollPeriodenddate
  INNER JOIN TimeCurrent..tblEmplAssignments as ea
  ON ea.Client = t.Client
  AND ea.Groupcode = t.Groupcode
  AND ea.SSN = t.SSN
  AND ea.DeptNo =  t.DeptNo
  INNER JOIN TimeHistory.dbo.tblEmplSites_Depts th_esds
  ON th_esds.Client = t.Client
  AND th_esds.GroupCode = t.GroupCode
  AND th_esds.SSN = t.SSN
  AND th_esds.PayrollPeriodEndDate = t.PayrollPeriodEndDate
  AND th_esds.SiteNo = t.SiteNo
  AND th_esds.DeptNo = t.DeptNo
  AND ISNULL(ISNULL(th_esds.PayRecordsSent, en.PayRecordsSent), '1/1/1970') = '1/1/1970'
	WHERE t.Client = @Client
	AND t.Groupcode = @GroupCode
	AND t.PayrollPeriodEndDate = @PPED
	AND t.Hours <> 0
	GROUP BY t.SSN, ISNULL(ISNULL(th_esds.PayRecordsSent, en.PayRecordsSent), '1/1/1970'), ea.AssignmentNo,ea.AssignmentTypeId
	
	-- Remove assignments that do not have fully approved cards - at the ASSIGNMENT LEVEL
	IF (@RecordType = 'A')
	BEGIN	  
		UPDATE ssn
		SET SendAsUnapproved = cat.SendAsUnapprovedInPayfile
		FROM #tmpSSNs ssn
		INNER JOIN TimeCurrent..tblClients_AssignmentType cat
		ON cat.Client = @Client
		AND cat.AssignmentTypeID = ssn.AssignmentTypeID

	    DELETE FROM #tmpSSNs WHERE TransCount <> ApprovedCount AND SendAsUnapproved = 0
	END
END
ELSE IF (@RecordType = 'P')
BEGIN
	INSERT INTO #tmpSSNs (SSN, PayRecordsSent, AssignmentNo, TransCount, ApprovedCount, AprvlStatus_Date,
												IVR_Count, WTE_Count,Fax_Count, FaxApprover_Count, EmailClient_Count, EmailOther_Count, Dispute_Count, OtherTxns_Count, LateApprovals, SnapshotDateTime)
	SELECT 	t.SSN, 
				  PayRecordsSent = ISNULL(ISNULL(th_esds.PayRecordsSent, en.PayRecordsSent), '1/1/1970'), 
				  ea.AssignmentNo,
				  TransCount = SUM(1),
				  ApprovedCount = SUM(CASE WHEN t.AprvlStatus IN ('A', 'L') THEN 1 ELSE 0 END),
				  AprvlStatus_Date = MAX(isnull(t.AprvlStatus_Date, '1/2/1970')),
				  IVR_Count = SUM(CASE WHEN t.UserCode = 'IVR' THEN 1 ELSE 0 END),
				  WTE_Count = SUM(CASE WHEN t.UserCode IN ('WTE', 'VTS') THEN 1 ELSE 0 END),
				  Fax_Count =  SUM(CASE WHEN t.UserCode = 'FAX' THEN 1 ELSE 0 END),
				  FaxApprover_Count =  SUM(CASE WHEN t.AprvlStatus_UserID = @FaxApprover THEN 1 ELSE 0 END),  
				  EmailClient_Count =  SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode = 'CLI') THEN 1 ELSE 0 END),  
				  EmailOther_Count =  SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode in ('BRA', 'COR', 'AGE')) THEN 1 ELSE 0 END),  
				  Dispute_Count = SUM(CASE WHEN t.ClockAdjustmentNo IN ('$', '@') THEN 1 ELSE 0 END),
				  OtherTxns_Count = SUM(CASE WHEN t.ClockAdjustmentNo NOT IN ('$', '@', '') AND ISNULL(t.UserCode, '') NOT IN ('WTE','COR', 'FAX', 'EML', 'SYS') AND ISNULL(t.OutUserCode, '') NOT in ('CLI', 'BRA', 'COR', 'AGE') THEN 1 ELSE 0 END),
				  LateApprovals = SUM(CASE WHEN t.AprvlStatus_Date > ISNULL(ISNULL(th_esds.PayRecordsSent, en.PayRecordsSent), '1/1/2050') THEN 1 ELSE 0 END),
				SnapshotDateTime = GetDate()
	FROM TimeHistory.dbo.tblEmplNames as en
	INNER JOIN TimeHistory.dbo.tblTimeHistDetail t
	ON t.Client = en.Client
	AND t.GroupCode = en.GroupCode
	AND t.SSN = en.SSN
	AND t.PayrollPeriodEndDate = en.PayrollPeriodEndDate
	AND t.Hours <> 0
  INNER JOIN TimeCurrent..tblEmplAssignments as ea
  ON ea.Client = t.Client
  AND ea.Groupcode = t.Groupcode
  AND ea.SSN = t.SSN
  AND ea.DeptNo =  t.DeptNo
  INNER JOIN TimeHistory.dbo.tblEmplSites_Depts th_esds
  ON th_esds.Client = t.Client
  AND th_esds.GroupCode = t.GroupCode
  AND th_esds.SSN = t.SSN
  AND th_esds.PayrollPeriodEndDate = t.PayrollPeriodEndDate
  AND th_esds.SiteNo = t.SiteNo
  AND th_esds.DeptNo = t.DeptNo      
	WHERE en.Client = @Client
	AND en.Groupcode = @GroupCode
	AND en.PayrollPeriodEndDate = @PPED
	AND en.PayrollPeriodEndDate >= '1/2/2011'
	AND ISNULL(ISNULL(th_esds.PayRecordsSent, en.PayRecordsSent), '1/1/1970') <> '1/1/1970'
	GROUP BY t.SSN, ISNULL(ISNULL(th_esds.PayRecordsSent, en.PayRecordsSent), '1/1/1970'), ea.AssignmentNo

	-- Delete all non-late approvals
	DELETE FROM #tmpSSNs WHERE LateApprovals = 0

	-- Only late approvals left at this point, delete if all records are not approved
	DELETE FROM #tmpSSNs WHERE ApprovedCount <> TransCount

END
ELSE
BEGIN
	RETURN
END

--select * from #tmpSSNs 
--DROP TABLE #tmpSSNs
--RETURN

--
-- Make sure all records got calculated correctly for this cycle.
--
Select t.GroupCode, t.PayrollPeriodEndDate, t.SSN,
       TotHours = Sum(t.Hours), TotCalcHrs = Sum(t.RegHours + t.OT_Hours + t.DT_Hours)
into #tmpCalcHrs
From TimeHistory.dbo.tblTimeHistDetail as t
Where t.Client = @Client
  and t.groupCode = @GroupCode
  and t.PayrollPeriodEnddate = @PPED
	and t.SSN IN (SELECT SSN FROM #tmpSSNs)
Group By t.GroupCode, t.PayrollPeriodEndDate, t.SSN
order By t.groupCode, t.PayrollPeriodEndDate, t.SSN

SELECT @CalcBalanceCnt = (Select count(*) from #tmpCalcHrs where TotHours <> TotCalcHrs)

Drop Table #tmpCalcHrs

if @CalcBalanceCnt > 0
begin
  RAISERROR ('Employees exist that are out of balance between worked and calculated.', 16, 1) 
  return
end


Create Table #tmpDailyHrs1
(
	Client varchar(4),
	GroupCode int,
	PayrollPeriodenddate Datetime,
	TransDate datetime,
	SSN int,
	DeptName varchar(50),
	AssignmentNo varchar(50),
	BranchID varchar(32),
	TotalRegHours numeric(9,2),
	TotalOT_Hours numeric(9,2),
	TotalDT_Hours numeric(9,2),
	PayRate numeric(5,2),
	BillRate numeric(5,2),
	PFP_FLag char(1),
	ApproverName varchar(100),
	ApprovalStatus char(1),
	ApproverDateTime datetime,
	MaxRecordID BIGINT  --< MaxRecordId data type is changed from  INT to BIGINT by Srinsoft on 17Aug2016 >--
)


Create Table #tmpDailyHrs
(
	RecordID [int] IDENTITY (1, 1) NOT NULL ,
	Client varchar(4),
	GroupCode int,
	PayrollPeriodenddate Datetime,
	TransDate datetime,
	SSN int,
	DeptName varchar(50),
	AssignmentNo varchar(50),
	BranchID varchar(32),
	TotalRegHours numeric(9,2),
	TotalOT_Hours numeric(9,2),
	TotalDT_Hours numeric(9,2),
	PayRate numeric(5,2),
	BillRate numeric(5,2),
	PFP_FLag char(1),
	ApproverName varchar(100),
	ApprovalStatus char(1),
	ApproverDateTime datetime,
	MaxRecordID BIGINT  --< MaxRecordId data type is changed from  INT to BIGINT by Srinsoft on 17Aug2016 >--
)

	--
	--Get the Daily totals for each SSN, display the weekly total as one of the columns.
	-- 

	INSERT INTO #tmpDailyHrs1
	SELECT   thd.Client,
		       thd.GroupCode,
	         thd.PayrollPeriodEndDate,  
	         thd.TransDate,  
	         thd.SSN,  
	         deptName = '', --CASE WHEN @UseDeptName = '1' THEN (case when isnull(gd.ClientDeptCode2,'') <> '' then gd.CLientDeptCode2 else '' end) ELSE 'N/A' END,
	         AssignmentNo = isnull(ea.AssignmentNo,'MISSING'),
	         BranchID = isnull(ea.JobOrderNo,'Missing'),
	         TotalRegHours = Sum(thd.RegHours),
	         TotalOT_Hours = Sum(thd.OT_Hours),
	         TotalDT_Hours = Sum(thd.DT_Hours),
					 PayRate = isnull(ea.PayRate,0.00),
					 BillRate = isnull(ea.BillRate,0.00),
					 PFP_Flag = @UsePFP,
				   ApproverName = cast('' as varchar(40)), 
					 ApprovalStatus = cast('' as char(1)),	
				   ApproverDateTime = max( isnull(thd.AprvlStatus_Date, GetDate())),
				   MaxRecordID = Max(thd.recordID)
	FROM TimeHistory..tblTimeHistDetail as thd
  INNER JOIN TimeCurrent..tblEmplAssignments as ea
  ON ea.Client = thd.Client
  AND ea.Groupcode = thd.Groupcode
  AND ea.SSN = thd.SSN
  AND ea.DeptNo =  thd.DeptNo
  INNER JOIN #tmpSSNs as S
  ON S.SSN = thd.SSN
  AND ea.AssignmentNo = s.AssignmentNo
  INNER JOIN TimeHistory..tblEmplSites_Depts as esd
  ON esd.Client = thd.Client
  AND esd.Groupcode = thd.Groupcode
  AND esd.PayrollPeriodenddate = thd.PayrollPeriodenddate
  AND esd.SSN = thd.SSN
  AND esd.SiteNo = thd.SiteNo
  AND esd.DeptNo =  thd.DeptNo
  INNER JOIN TimeCurrent..tblGroupDepts gd
  ON gd.Client = thd.Client
  AND gd.GroupCode = thd.GroupCode     
  AND gd.DeptNo = thd.DeptNo         
  LEFT JOIN TimeCurrent..tblAgencies ag
  ON  ag.Client = thd.Client
  AND ag.GroupCode = thd.GroupCode
  AND ag.Agency = thd.AgencyNo
  WHERE thd.Client = @Client  
  AND thd.PayrollPeriodEndDate = @PPED  
  AND thd.GroupCode = @GroupCode  
  AND IsNull(ag.ExcludeFromPayFile,'0') <> '1'
  --      and isnull(esd.ExcludeFromUpload,'0') <> '1'
	GROUP BY thd.Client,  
	         thd.GroupCode,  
	         thd.SSN,  
	         thd.PayrollPeriodEndDate,  
	         thd.TransDate,  
					 isnull(ea.PayRate, 0.00),
					 isnull(ea.BillRate, 0.00),	
--	         CASE WHEN @UseDeptName = '1' THEN (case when isnull(gd.ClientDeptCode2,'') <> '' then gd.CLientDeptCode2 else '' end) ELSE 'N/A' END,
	         isnull(ea.AssignmentNo, 'MISSING'),
	         isnull(ea.JobOrderNo, 'Missing')

	-- Second select is used to combine transaction dates that could not be combined in the prior select 
	-- This helps reduce negative hours processing.

	INSERT INTO #tmpDailyHrs
	Select 	Client, GroupCode, PayrollPeriodenddate, TransDate, SSN, DeptName, AssignmentNo, BranchID,
					Sum(TotalRegHours), Sum(TotalOT_Hours), Sum(TotalDT_Hours), PayRate, BillRate, PFP_Flag, ApproverName, 
					ApprovalStatus, max(ApproverDateTime), Max(MaxRecordID)
	from #tmpDailyHrs1
	group By 	Client, GroupCode, PayrollPeriodenddate, TransDate, SSN, DeptName, AssignmentNo, BranchID,
						PayRate, BillRate, PFP_Flag, ApproverName, ApprovalStatus	
	         
-- Remove zero hours transactions
delete from #tmpDailyHrs where TotalRegHours = 0.00 and TotalOT_Hours = 0.00 and TotalDT_Hours = 0.00

Update #tmpDailyHrs
  Set #tmpDailyHrs.ApproverName = CASE WHEN bkp.RecordId IS NOT NULL THEN bkp.Email
  																																	 ELSE CASE WHEN isnull(usr.Email,'') = '' THEN (CASE WHEN isnull(usr.LastName,'') = '' THEN isnull(usr.LogonName,'') 
																					  																																																							 ELSE left(usr.LastName + ',' + isnull(usr.FirstName,''),50) 
																					  																																																							 END)
																																								 															ELSE left(usr.Email,50) 
																																								 															END
																																		 END/*,	
		  #tmpDailyHrs.ApprovalStatus = thd.AprvlStatus*/
from #tmpDailyHrs
INNER JOIN TimeHistory..tblTimeHistDetail as thd
on thd.RecordID = #tmpDailyHrs.MaxRecordID
LEFT JOIN TimeHistory..tblTimeHistDetail_BackupApproval bkp
ON bkp.THDRecordId = #tmpDailyHrs.MaxRecordID
LEFT JOIN TimeCurrent..tblUser as Usr
ON usr.UserID = isnull(thd.AprvlStatus_UserID,0)


-- Create Weekly Total File.
Create Table #tmpTotHrs
(
	Client varchar(4),
	GroupCode int,
	SSN int,
	DeptName varchar(50),
	Assignmentno varchar(50),
	BranchID varchar(32),
	PayrollPeriodendDate datetime,
	TotalWeeklyHours numeric(9,2)
)

Insert into #tmpTotHrs
Select Client, GroupCode, SSN, DeptName, AssignmentNo, BranchID, PayrollPeriodenddate, sum(TotalRegHours + TotalOT_Hours + TotalDT_Hours)
from #tmpDailyHrs
Group By Client, GroupCode, SSN, DeptName, AssignmentNo, BranchID, PayrollPeriodenddate


INSERT INTO #tmpWorkedSummary(Client, GroupCode, PayrollPeriodEndDate, TransDate, SSN, FileNo, AssignmentNo, BranchID, DeptName,
															TotalRegHours, TotalOT_Hours, TotalDT_Hours, TotalWeeklyHours,
															ApproverName, ApproverDateTime, ApprovalID, 
															ApprovalStatus,
															DayWorked, FlatPay, FlatBill, 
															EmplName, 
															PFP_Flag, PayRate, BillRate,
															Source)
SELECT	TTD.Client, TTD.GroupCode, TTD.PayrollPeriodEndDate, TTD.TransDate, TTD.SSN, EN.FileNo, TTD.AssignmentNo, TTD.BranchID, TTD.DeptName,
				TTD.TotalRegHours, TTD.TotalOT_Hours, TTD.TotalDT_Hours, TTH.TotalWeeklyHours,
				CASE WHEN tmpSSN.ApprovedCount = tmpSSN.TransCount THEN TTD.ApproverName ELSE '' END, 
				CASE WHEN tmpSSN.ApprovedCount = tmpSSN.TransCount THEN TTD.ApproverDateTime ELSE NULL END, 
				CASE WHEN tmpSSN.ApprovedCount = tmpSSN.TransCount THEN TTD.MaxRecordID ELSE 0 END AS ApprovalID ,
				CASE WHEN tmpSSN.ApprovedCount = tmpSSN.TransCount AND (tmpSSN.OtherTxns_Count + tmpSSN.Dispute_Count = 0) THEN '1'
						 WHEN tmpSSN.ApprovedCount = tmpSSN.TransCount AND (tmpSSN.OtherTxns_Count + tmpSSN.Dispute_Count > 0) THEN '2'
						 ELSE '0' END,
				CAST('' AS VARCHAR) AS DayWorked, 0.00 AS FlatPay, 0.00 AS FlastBill, 
				en.LastName + '; ' + en.FirstName AS EmplName,
				TTD.PFP_Flag, TTD.PayRate, TTD.BillRate,
				'H'
FROM #tmpDailyHrs as TTD
INNER JOIN #tmpTotHrs as TTH
ON TTD.Client = TTH.Client
and TTD.GroupCode = TTH.GroupCode
and TTD.SSN = TTH.SSN
and isnull(TTD.AssignmentNo, '') = isnull(TTH.AssignmentNo, '')
and TTD.PayrollPeriodEndDate = TTH.PayrollPeriodEndDate
and TTD.DeptName = TTH.DeptName
INNER JOIN TimeCurrent..tblEmplNames as en
on EN.Client = TTD.Client
and en.Groupcode = TTD.GroupCode
and en.SSN = TTD.SSN
INNER JOIN #tmpSSNs as tmpSSN
ON tmpSSN.SSN = TTD.SSN
AND tmpSSN.AssignmentNo = TTD.AssignmentNo
ORDER BY TTD.SSN,  
         TTD.BranchID,  
         TTD.AssignmentNo,  
         TTD.DeptName,
         TTD.PayrollPeriodEndDate,  
         TTD.TransDate

-- Multiple Assignments 101, 1/2/2011
-- select * from  #tmpWorkedSummary where ssn in (709791,1184023,1810380,2042293,6130005,6460667,6509261,7202478,8055961)
      
-- Summarize the project information incase it has duplicates         
INSERT INTO #tmpProjectSummary(SSN, AssignmentNo, TransDate, ProjectNum, Hours)
SELECT pr.SSN, ea.AssignmentNo, pr.TransDate, LEFT(pr.ProjectNum, 60), SUM(pr.Hours) AS Hours
FROM TimeHistory.dbo.tblWTE_Spreadsheet_Project pr
INNER JOIN TimeCurrent.dbo.tblEmplAssignments ea
ON ea.Client = pr.Client
AND ea.GroupCode = pr.GroupCode
AND ea.SSN = pr.SSN
AND ea.SiteNo = pr.SiteNo
AND ea.DeptNo = pr.DeptNo
Inner Join #tmpSSNs as S
on S.SSN = pr.SSN
AND S.AssignmentNo = ea.AssignmentNo
WHERE pr.Client = @Client
AND pr.GroupCode = @GroupCode
AND pr.PayrollPeriodEndDate = @PPED
GROUP BY pr.SSN, ea.AssignmentNo, pr.TransDate, pr.ProjectNum

IF EXISTS(SELECT 1 FROM #tmpProjectSummary)
BEGIN 
	-- Process the projects and merge it in with the time data
	DECLARE workedCursor CURSOR READ_ONLY
	FOR SELECT 	RecordId, TotalRegHours, TotalOT_Hours, TotalDT_Hours,
							SSN, AssignmentNo, TransDate
			FROM #tmpWorkedSummary
			ORDER BY SSN, TransDate, AssignmentNo
	
	OPEN workedCursor
	
	FETCH NEXT FROM workedCursor INTO @RecordId, @TotalRegHours, @TotalOT_Hours, @TotalDT_Hours, @SSN, @AssignmentNo, @TransDate
	WHILE (@@fetch_status <> -1)
	BEGIN
		IF (@@fetch_status <> -2)
		BEGIN
		
			--PRINT ''
			--PRINT 'Start'
			SELECT @LoopCounter = 1
			SELECT @MinProjectId = 0
			SELECT @RegBalance = @TotalRegHours
			SELECT @OTBalance = @TotalOT_Hours
			SELECT @DTBalance = @TotalDT_Hours
			--PRINT 'Trans Date: ' + CAST(@TransDate AS VARCHAR)
			--PRINT 'Reg Balance: ' + CAST(@RegBalance AS VARCHAR)
			--PRINT 'OT Balance: ' + CAST(@OTBalance AS VARCHAR)
			--PRINT 'DT Balance: ' + CAST(@DTBalance AS VARCHAR)
			
			SELECT @TotalProjectLines = COUNT(*)
			FROM #tmpProjectSummary
			WHERE SSN = @SSN
			AND TransDate = @TransDate
			AND AssignmentNo = @AssignmentNo
			AND Hours <> 0		
			--PRINT 'Total Project Lines: ' + CAST(@TotalProjectLines AS VARCHAR)
			
			IF (@TotalProjectLines > 0)
			BEGIN 
							
				SELECT @MinProjectId = MIN(RecordId)
				FROM #tmpProjectSummary
				WHERE SSN = @SSN
				AND TransDate = @TransDate
				AND AssignmentNo = @AssignmentNo
				AND Hours <> 0
				AND RecordId > @MinProjectId
	
				SELECT @ProjectNum = ProjectNum,
							 @ProjectHours = Hours
				FROM #tmpProjectSummary
				WHERE recordid = @MinProjectId
				--PRINT 'Found project ' + @ProjectNum + ' for ' + CAST(@projecthours AS VARCHAR) + ' hours'
				
				-- BEGIN Balance Calculator						
				SELECT @RegAvailable = CASE WHEN @ProjectHours > @RegBalance THEN @RegBalance ELSE @ProjectHours END
				SELECT @ProjectRemaining = @ProjectHours - @RegAvailable
				SELECT @OTAvailable = CASE WHEN @ProjectRemaining > @OTBalance THEN @OTBalance ELSE @ProjectRemaining END
				SELECT @ProjectRemaining = @ProjectHours - @RegAvailable - @OTAvailable			
				SELECT @DTAvailable = CASE WHEN @ProjectRemaining > @DTBalance THEN @DTBalance ELSE @ProjectRemaining END
				--PRINT 'Reg available: ' + CAST(@RegAvailable AS VARCHAR)
				--PRINT 'OT available: ' + CAST(@OTAvailable AS VARCHAR)
				--PRINT 'DT available: ' + CAST(@DTAvailable AS VARCHAR)			
					
				SET @RegBalance = @RegBalance - @RegAvailable
				SET @OTBalance = @OTBalance - @OTAvailable
				SET @DTBalance = @DTBalance - @DTAvailable			
				--PRINT 'Reg balance: ' + CAST(@RegBalance AS VARCHAR)
				--PRINT 'OT balance: ' + CAST(@OTBalance AS VARCHAR)
				--PRINT 'DT balance: ' + CAST(@DTBalance AS VARCHAR)			
				-- END Balance Calculator		
							
				UPDATE #tmpWorkedSummary
				SET TotalRegHours = @RegAvailable,
						TotalOT_Hours = @OTAvailable,
						TotalDT_Hours = @DTAvailable,
						DeptName = @ProjectNum
				WHERE RecordId = @RecordId
										
				-- Create additional pay file transactions that we will assign the project numbers too
				--PRINT '@LoopCounter: ' + CAST(@LoopCounter AS VARCHAR)
				--PRINT '@TotalProjectLines: ' + CAST(@TotalProjectLines AS VARCHAR)
				
				WHILE (@LoopCounter <= @TotalProjectLines - 1)
				BEGIN
					--PRINT 'IN WHILE LOOP'
					SELECT @MinProjectId = MIN(RecordId)
					FROM #tmpProjectSummary
					WHERE SSN = @SSN
					AND TransDate = @TransDate
					AND AssignmentNo = @AssignmentNo
					AND Hours <> 0
					AND RecordId > @MinProjectId
					
					SELECT @ProjectNum = ProjectNum,
							 	 @ProjectHours = Hours
					FROM #tmpProjectSummary
					WHERE recordid = @MinProjectId				
					--PRINT 'Found project ' + @ProjectNum + ' for ' + CAST(@projecthours AS VARCHAR) + ' hours'
					
					-- BEGIN Balance Calculator						
					SELECT @RegAvailable = CASE WHEN @ProjectHours > @RegBalance THEN @RegBalance ELSE @ProjectHours END
					SELECT @ProjectRemaining = @ProjectHours - @RegAvailable
					SELECT @OTAvailable = CASE WHEN @ProjectRemaining > @OTBalance THEN @OTBalance ELSE @ProjectRemaining END
					SELECT @ProjectRemaining = @ProjectHours - @RegAvailable - @OTAvailable			
					SELECT @DTAvailable = CASE WHEN @ProjectRemaining > @DTBalance THEN @DTBalance ELSE @ProjectRemaining END
					--PRINT 'Reg available: ' + CAST(@RegAvailable AS VARCHAR)
					--PRINT 'OT available: ' + CAST(@OTAvailable AS VARCHAR)
					--PRINT 'DT available: ' + CAST(@DTAvailable AS VARCHAR)			
						
					SET @RegBalance = @RegBalance - @RegAvailable
					SET @OTBalance = @OTBalance - @OTAvailable
					SET @DTBalance = @DTBalance - @DTAvailable			
					--PRINT 'Reg balance: ' + CAST(@RegBalance AS VARCHAR)
					--PRINT 'OT balance: ' + CAST(@OTBalance AS VARCHAR)
					--PRINT 'DT balance: ' + CAST(@DTBalance AS VARCHAR)					
					-- END Balance Calculator				
								
					INSERT INTO #tmpWorkedSummary(Client, GroupCode, PayrollPeriodEndDate, TransDate, SSN, FileNo, AssignmentNo, BranchID, DeptName,
																				TotalRegHours, TotalOT_Hours, TotalDT_Hours, TotalWeeklyHours, ApproverName, ApproverDateTime, ApprovalID, ApprovalStatus,
																				DayWorked, FlatPay, FlatBill, EmplName, PFP_Flag, PayRate, BillRate, Source)
					SELECT 	Client, GroupCode, PayrollPeriodEndDate, TransDate, SSN, FileNo, AssignmentNo, BranchID, @ProjectNum,
									@RegAvailable, @OTAvailable, @DTAvailable, TotalWeeklyHours, ApproverName, ApproverDateTime, ApprovalID, ApprovalStatus,
									DayWorked, FlatPay, FlatBill, EmplName, PFP_Flag, PayRate, BillRate, 'O'
					FROM #tmpWorkedSummary
					WHERE RecordId = @RecordId
				
					SELECT @LoopCounter = @LoopCounter + 1
					--PRINT 'Reg balance: ' + CAST(@RegBalance AS VARCHAR)
					--PRINT 'OT balance: ' + CAST(@OTBalance AS VARCHAR)				
					--PRINT 'DT balance: ' + CAST(@DTBalance AS VARCHAR)				
				END 

				--PRINT 'AFTER LOOP....'					
				--PRINT 'Reg available: ' + CAST(@RegAvailable AS VARCHAR)
				--PRINT 'OT available: ' + CAST(@OTAvailable AS VARCHAR)
				--PRINT 'DT available: ' + CAST(@DTAvailable AS VARCHAR)	
				
				--PRINT 'Reg balance: ' + CAST(@RegBalance AS VARCHAR)
				--PRINT 'OT balance: ' + CAST(@OTBalance AS VARCHAR)
				--PRINT 'DT balance: ' + CAST(@DTBalance AS VARCHAR)					
				
				IF (@RegBalance > 0 OR @OTBalance > 0 OR @DTBalance > 0)
				BEGIN
					INSERT INTO #tmpWorkedSummary(Client, GroupCode, PayrollPeriodEndDate, TransDate, SSN, FileNo, AssignmentNo, BranchID, DeptName,
																				TotalRegHours, TotalOT_Hours, TotalDT_Hours, TotalWeeklyHours, ApproverName, ApproverDateTime, ApprovalID, ApprovalStatus,
																				DayWorked, FlatPay, FlatBill, EmplName, PFP_Flag, PayRate, BillRate, Source)
					SELECT 	Client, GroupCode, PayrollPeriodEndDate, TransDate, SSN, FileNo, AssignmentNo, BranchID, '',
									@RegBalance, @OTBalance, @DTBalance, TotalWeeklyHours, ApproverName, ApproverDateTime, ApprovalID, ApprovalStatus,
									DayWorked, FlatPay, FlatBill, EmplName, PFP_Flag, PayRate, BillRate, 'O'
					FROM #tmpWorkedSummary
					WHERE RecordId = @RecordId				
				END
			END
			
		END
		FETCH NEXT FROM workedCursor INTO @RecordId, @TotalRegHours, @TotalOT_Hours, @TotalDT_Hours, @SSN, @AssignmentNo, @TransDate
	END
	CLOSE workedCursor
	DEALLOCATE workedCursor
END

Update #tmpWorkedSummary
  Set #tmpWorkedSummary.Source = CASE WHEN tmpSSNs.IVR_Count > 0 AND tmpSSNs.FaxApprover_Count > 0 THEN 'X'
  														  WHEN tmpSSNs.WTE_Count > 0 AND tmpSSNs.FaxApprover_Count > 0 THEN 'Y'
  														  WHEN tmpSSNs.IVR_Count > 0 THEN 'F'
  														  WHEN tmpSSNs.WTE_Count > 0 THEN 'H' 
  														  WHEN tmpSSNs.Fax_Count > 0 THEN 'Q' 
  														  WHEN tmpSSNs.EmailClient_Count > 0 THEN 'D'
  														  WHEN tmpSSNs.EmailOther_Count > 0 THEN 'J'  
  														  ELSE #tmpWorkedSummary.Source
  													 END,
			#tmpWorkedSummary.SnapshotDateTime = tmpSSNs.SnapshotDateTime/*,
  		#tmpWorkedSummary.ApprovalStatus = CASE WHEN (tmpSSNs.OtherTxns_Count + tmpSSNs.Dispute_Count) > 0 AND #tmpWorkedSummary.ApprovalStatus = '1' THEN '2'
  																						ELSE #tmpWorkedSummary.ApprovalStatus
  																			 END*/
from #tmpWorkedSummary 
INNER JOIN #tmpSSNs AS tmpSSNs
ON tmpSSNs.SSN = #tmpWorkedSummary.SSN
AND tmpSSNs.AssignmentNo = #tmpWorkedSummary.AssignmentNo


INSERT INTO TimeHistory..tblOlstenUploadWork2(Client, GroupCode, PayrollPeriodEndDate, TransDate, SSN, EmplID,
																							AssignmentNo, BranchID, DeptName,
																							TotalRegHours, TotalOT_Hours, TotalDT_Hours, TotalWeeklyHours,
																							ApproverName, ApproverDateTime, ApprovalID, ApprovalStatus,
																							DayWorked, FlatPay, FlatBill, EmplName, PFP_Flag, PayRate, BillRate, 
																							Source, SnapshotDateTime)
SELECT 	Client, GroupCode, PayrollPeriodEndDate, TransDate, SSN, FileNo,
				AssignmentNo, BranchID, DeptName,
				TotalRegHours, TotalOT_Hours, TotalDT_Hours, TotalWeeklyHours,
				ApproverName, ApproverDateTime, ApprovalID, ApprovalStatus,
				DayWorked, FlatPay, FlatBill, EmplName, PFP_Flag, PayRate, BillRate, 
				SOURCE, SnapshotDateTime
FROM #tmpWorkedSummary
ORDER BY SSN,  
         BranchID,  
         AssignmentNo,  
         TransDate,
         DeptName

DROP TABLE #tmpSSNs
DROP TABLE #tmpDailyHrs
DROP TABLE #tmpTotHrs
DROP TABLE #tmpDailyHrs1
DROP TABLE #tmpWorkedSummary
DROP TABLE #tmpProjectSummary

