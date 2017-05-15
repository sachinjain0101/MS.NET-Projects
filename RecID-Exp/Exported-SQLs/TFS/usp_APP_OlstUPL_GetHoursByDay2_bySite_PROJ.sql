Create PROCEDURE [dbo].[usp_APP_OlstUPL_GetHoursByDay2_bySite_PROJ]
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
SET @GroupCode = 100
SET @PPED = '10/05/08'
Set @RecordType = 'A'

Drop Table #tmpTotHrs
Drop Table #tmpDailyHrs
Drop Table #tmpDailyHrs1
Drop Table #tmpNegHours
Drop Table #tmpSSNs
*/

DECLARE @ShiftZeroCount int
DECLARE @CalcBalanceCnt int
DECLARE @UseDeptName char(1)
DECLARE @OpenDepts char(1)
DECLARE @UsePFP char(1)
DECLARE @ClientGroupID1 varchar(200)
DECLARE @grpOTMult numeric(5,3)
DECLARE @prOTMult numeric(5,3)
DECLARE @OTMult numeric(5,3)

-- Project Related
DECLARE @SSN INT
DECLARE @AssignmentNo VARCHAR(32)
DECLARE @TransDate DATETIME
DECLARE @ProjectNum VARCHAR(200)
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

/*
Select @ShiftZeroCount = (Select Count(*) from tblTimeHistDetail 
                            Where Client = @Client
                              and GroupCode = @GroupCode
                              AND PayrollperiodEndDate = @PPED 
                              and ShiftNo = 0 )
if @ShiftZeroCount > 0
begin
  Update tblTimehistdetail Set ShiftNo = 1 
                            Where Client = @Client
                              and GroupCode = @GroupCode
                              AND PayrollperiodEndDate = @PPED 
                              and ShiftNo = 0 
end
*/
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
  Dispute_Count INT,
  OtherTxns_Count INT 
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
	Source VARCHAR(1)
)

CREATE TABLE #tmpProjectSummary
(
	RecordId INT IDENTITY,
	SSN INT, 
	AssignmentNo VARCHAR(100), 
	TransDate DATETIME, 
	ProjectNum VARCHAR(100), 
	Hours NUMERIC(7,2)
)

Insert into #tmpSSNs (SSN, TransCount, ApprovedCount, PayRecordsSent, AprvlStatus_Date,
											IVR_Count, WTE_Count, Dispute_Count, OtherTxns_Count)
select 	t.SSN, 
			  TransCount = SUM(1),
			  ApprovedCount = SUM(CASE WHEN t.AprvlStatus IN ('A', 'L') THEN 1 ELSE 0 END),
			  PayRecordsSent = ISNULL(en.PayRecordsSent,'1/1/1970'), 
			  AprvlStatus_Date = MAX(isnull(t.AprvlStatus_Date,'1/2/1970')),
			  IVR_Count = SUM(CASE WHEN t.UserCode = 'IVR' THEN 1 ELSE 0 END),
			  WTE_Count = SUM(CASE WHEN t.UserCode IN ('WTE', 'VTS') THEN 1 ELSE 0 END),
			  Dispute_Count = SUM(CASE WHEN t.ClockAdjustmentNo IN ('$', '@') THEN 1 ELSE 0 END),
			  OtherTxns_Count = SUM(CASE WHEN t.ClockAdjustmentNo NOT IN ('$', '@', '') AND ISNULL(t.UserCode, '') NOT IN ('WTE','COR') THEN 1 ELSE 0 END)
from TimeHistory..tblTimeHistDetail as t
Inner Join TimeHistory..tblEmplNames as en
on en.Client = t.Client 
and en.GroupCode = t.GroupCode 
and en.SSN = t.SSN
and en.PayrollPeriodenddate = t.PayrollPeriodenddate
where t.Client = @Client
and t.Groupcode = @GroupCode
and t.PayrollPeriodEndDate = @PPED
group By t.SSN, en.PayRecordsSent

--select * from #tmpSSNs

IF (@RecordType = 'A')
BEGIN
  -- Remove employees that do not have fully approved cards.
  Delete from #tmpSSNs where Transcount <> ApprovedCount 
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
From tblTimeHistDetail as t
Inner Join #tmpSSNs as s
on s.SSN = t.SSN
Where t.Client = @Client
  and t.groupCode = @GroupCode
  and t.PayrollPeriodEnddate = @PPED
Group By t.GroupCode, t.PayrollPeriodEndDate, t.SSN
order By t.groupCode, t.PayrollPeriodEndDate, t.SSN

SELECT @CalcBalanceCnt = (Select count(*) from #tmpCalcHrs where TotHours <> TotCalcHrs)

Drop Table #tmpCalcHrs

if @CalcBalanceCnt > 0
begin
  RAISERROR ('Employees exists that are out of balance between worked and calculated.', 16, 1) 
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
				   ApproverDateTime = max( isnull(thd.AprvlStatus_Date, '1/1/1900') ),
				   MaxRecordID = Max(thd.recordID)
	FROM TimeHistory..tblTimeHistDetail as thd
    Inner Join #tmpSSNs as S
      on S.SSN = thd.SSN
    LEFT JOIN TimeCurrent..tblEmplAssignments as ea
      on ea.Client = thd.Client
      and ea.Groupcode = thd.Groupcode
      and ea.SSN = thd.SSN
      and ea.DeptNo =  thd.DeptNo
    LEFT JOIN TimeHistory..tblEmplSites_Depts as esd
      on esd.Client = thd.Client
      and esd.Groupcode = thd.Groupcode
      and esd.PayrollPeriodenddate = thd.PayrollPeriodenddate
      and esd.SSN = thd.SSN
      and esd.SiteNo = thd.SiteNo
      and esd.DeptNo =  thd.DeptNo
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
					 isnull(ea.PayRate,0.00),
					 isnull(ea.BillRate,0.00),	
--	         CASE WHEN @UseDeptName = '1' THEN (case when isnull(gd.ClientDeptCode2,'') <> '' then gd.CLientDeptCode2 else '' end) ELSE 'N/A' END,
	         isnull(ea.AssignmentNo,'MISSING'),
	         isnull(ea.JobOrderNo,'Missing')

	-- Second select is used to combine transaction dates that could not be combined in the prior select 
	-- This helps reduce negative hours processing.
	--
	
	INSERT INTO #tmpDailyHrs
	Select 	Client, GroupCode, PayrollPeriodenddate, TransDate, SSN, DeptName, AssignmentNo, BranchID,
					Sum(TotalRegHours), Sum(TotalOT_Hours), Sum(TotalDT_Hours), PayRate, BillRate, PFP_Flag, ApproverName, 
					ApprovalStatus, max(ApproverDateTime), Max(MaxRecordID)
	from #tmpDailyHrs1
	group By 	Client, GroupCode, PayrollPeriodenddate, TransDate, SSN, DeptName, AssignmentNo, BranchID,
						PayRate, BillRate, PFP_Flag, ApproverName, ApprovalStatus	
	         
LOADPAYFILE:	

-- Create negative table to report from
--select SSN, TotHrs = sum(TotalRegHours + totalOT_Hours + TotalDT_Hours) 
--into #tmpNegHours from #tmpDailyHrs group by SSN having sum(TotalRegHours + totalOT_Hours + TotalDT_Hours) <= 0.00


-- remove zero hours transactions;
delete from #tmpDailyHrs where TotalRegHours = 0.00 and TotalOT_Hours = 0.00 and TotalDT_Hours = 0.00

Update #tmpDailyHrs
  Set #tmpDailyHrs.ApproverName = CASE WHEN bkp.RecordId IS NOT NULL THEN bkp.Email
  																																	 ELSE CASE WHEN isnull(usr.Email,'') = '' THEN (CASE WHEN isnull(usr.LastName,'') = '' THEN isnull(usr.LogonName,'') 
																					  																																																							 ELSE left(usr.LastName + ',' + isnull(usr.FirstName,''),50) 
																					  																																																							 END)
																																								 															ELSE left(usr.Email,50) 
																																								 															END
																																		 END,	
		  #tmpDailyHrs.ApprovalStatus = thd.AprvlStatus
from #tmpDailyHrs
INNER JOIN TimeHistory..tblTimeHistDetail as thd
on thd.RecordID = #tmpDailyHrs.MaxRecordID
LEFT JOIN TimeHistory..tblTimeHistDetail_BackupApproval bkp
ON bkp.THDRecordId = #tmpDailyHrs.MaxRecordID
LEFT JOIN TimeCurrent..tblUser as Usr
ON usr.Client = thd.Client
AND usr.UserID = isnull(thd.AprvlStatus_UserID,0)

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
				TTD.ApproverName, TTD.ApproverDateTime, str(TTD.MaxRecordID,9) AS ApprovalID,
				case when isnull(TTD.ApprovalStatus,'') IN ('A', 'L') then '1'
						when isnull(TTD.ApprovalStatus,'') IN('', ' ') then '0'
						when isnull(TTD.ApprovalStatus,'') IN('D') then '3'
						else '0' END AS ApprovalStatus,
				CAST('' AS VARCHAR) AS DayWorked, 0.00 AS FlatPay, 0.00 AS FlastBill, 
				en.LastName + '; ' + en.FirstName AS EmplName,
				TTD.PFP_Flag, TTD.PayRate, TTD.BillRate,
				'O'
FROM #tmpDailyHrs as TTD
INNER JOIN #tmpTotHrs as TTH
 ON TTD.Client = TTH.Client
    and TTD.GroupCode = TTH.GroupCode
    and TTD.SSN = TTH.SSN
    and isnull(TTD.AssignmentNo,'') = isnull(TTH.AssignmentNo,'')
    and TTD.PayrollPeriodEndDate = TTH.PayrollPeriodEndDate
    and TTD.DeptName = TTH.DeptName
INNER JOIN TimeCurrent..tblEmplNames as en
	on EN.Client = TTD.Client
	and en.Groupcode = TTD.GroupCode
	and en.SSN = TTD.SSN
ORDER BY TTD.SSN,  
         TTD.BranchID,  
         TTD.AssignmentNo,  
         TTD.DeptName,
         TTD.PayrollPeriodEndDate,  
         TTD.TransDate
         
-- Summarize the project information incase it has duplicates         
INSERT INTO #tmpProjectSummary(SSN, AssignmentNo, TransDate, ProjectNum, Hours)
SELECT pr.SSN, ea.AssignmentNo, pr.TransDate, pr.ProjectNum, SUM(pr.Hours) AS Hours
FROM TimeHistory.dbo.tblWTE_Spreadsheet_Project pr
INNER JOIN TimeCurrent.dbo.tblEmplAssignments ea
ON ea.Client = pr.Client
AND ea.GroupCode = pr.GroupCode
AND ea.SSN = pr.SSN
AND ea.SiteNo = pr.SiteNo
AND ea.DeptNo = pr.DeptNo
Inner Join #tmpSSNs as S
on S.SSN = pr.SSN
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
		
			PRINT ''
			PRINT 'Start'
			SELECT @LoopCounter = 1
			SELECT @MinProjectId = 0
			SELECT @RegBalance = @TotalRegHours
			SELECT @OTBalance = @TotalOT_Hours
			SELECT @DTBalance = @TotalDT_Hours
			PRINT 'Trans Date: ' + CAST(@TransDate AS VARCHAR)
			PRINT 'Reg Balance: ' + CAST(@RegBalance AS VARCHAR)
			PRINT 'OT Balance: ' + CAST(@OTBalance AS VARCHAR)
			PRINT 'DT Balance: ' + CAST(@DTBalance AS VARCHAR)
			
			SELECT @TotalProjectLines = COUNT(*)
			FROM #tmpProjectSummary
			WHERE SSN = @SSN
			AND TransDate = @TransDate
			AND AssignmentNo = @AssignmentNo
			AND Hours <> 0		
			PRINT 'Total Project Lines: ' + CAST(@TotalProjectLines AS VARCHAR)
			
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
				PRINT 'Found project ' + @ProjectNum + ' for ' + CAST(@projecthours AS VARCHAR) + ' hours'
				
				-- BEGIN Balance Calculator						
				SELECT @RegAvailable = CASE WHEN @ProjectHours > @RegBalance THEN @RegBalance ELSE @ProjectHours END
				SELECT @ProjectRemaining = @ProjectHours - @RegAvailable
				SELECT @OTAvailable = CASE WHEN @ProjectRemaining > @OTBalance THEN @OTBalance ELSE @ProjectRemaining END
				SELECT @ProjectRemaining = @ProjectHours - @RegAvailable - @OTAvailable			
				SELECT @DTAvailable = CASE WHEN @ProjectRemaining > @DTBalance THEN @DTBalance ELSE @ProjectRemaining END
				PRINT 'Reg available: ' + CAST(@RegAvailable AS VARCHAR)
				PRINT 'OT available: ' + CAST(@OTAvailable AS VARCHAR)
				PRINT 'DT available: ' + CAST(@DTAvailable AS VARCHAR)			
					
				SET @RegBalance = @RegBalance - @RegAvailable
				SET @OTBalance = @OTBalance - @OTAvailable
				SET @DTBalance = @DTBalance - @DTAvailable			
				PRINT 'Reg balance: ' + CAST(@RegBalance AS VARCHAR)
				PRINT 'OT balance: ' + CAST(@OTBalance AS VARCHAR)
				PRINT 'DT balance: ' + CAST(@DTBalance AS VARCHAR)			
				-- END Balance Calculator		
							
				UPDATE #tmpWorkedSummary
				SET TotalRegHours = @RegAvailable,
						TotalOT_Hours = @OTAvailable,
						TotalDT_Hours = @DTAvailable,
						DeptName = @ProjectNum
				WHERE RecordId = @RecordId
										
				-- Create additional pay file transactions that we will assign the project numbers too
				PRINT '@LoopCounter: ' + CAST(@LoopCounter AS VARCHAR)
				PRINT '@TotalProjectLines: ' + CAST(@TotalProjectLines AS VARCHAR)
				
				WHILE (@LoopCounter <= @TotalProjectLines - 1)
				BEGIN
					PRINT 'IN WHILE LOOP'
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
					PRINT 'Found project ' + @ProjectNum + ' for ' + CAST(@projecthours AS VARCHAR) + ' hours'
					
					-- BEGIN Balance Calculator						
					SELECT @RegAvailable = CASE WHEN @ProjectHours > @RegBalance THEN @RegBalance ELSE @ProjectHours END
					SELECT @ProjectRemaining = @ProjectHours - @RegAvailable
					SELECT @OTAvailable = CASE WHEN @ProjectRemaining > @OTBalance THEN @OTBalance ELSE @ProjectRemaining END
					SELECT @ProjectRemaining = @ProjectHours - @RegAvailable - @OTAvailable			
					SELECT @DTAvailable = CASE WHEN @ProjectRemaining > @DTBalance THEN @DTBalance ELSE @ProjectRemaining END
					PRINT 'Reg available: ' + CAST(@RegAvailable AS VARCHAR)
					PRINT 'OT available: ' + CAST(@OTAvailable AS VARCHAR)
					PRINT 'DT available: ' + CAST(@DTAvailable AS VARCHAR)			
						
					SET @RegBalance = @RegBalance - @RegAvailable
					SET @OTBalance = @OTBalance - @OTAvailable
					SET @DTBalance = @DTBalance - @DTAvailable			
					PRINT 'Reg balance: ' + CAST(@RegBalance AS VARCHAR)
					PRINT 'OT balance: ' + CAST(@OTBalance AS VARCHAR)
					PRINT 'DT balance: ' + CAST(@DTBalance AS VARCHAR)					
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
					PRINT 'Reg balance: ' + CAST(@RegBalance AS VARCHAR)
					PRINT 'OT balance: ' + CAST(@OTBalance AS VARCHAR)				
					PRINT 'DT balance: ' + CAST(@DTBalance AS VARCHAR)				
				END 

				PRINT 'AFTER LOOP....'					
				PRINT 'Reg available: ' + CAST(@RegAvailable AS VARCHAR)
				PRINT 'OT available: ' + CAST(@OTAvailable AS VARCHAR)
				PRINT 'DT available: ' + CAST(@DTAvailable AS VARCHAR)	
				
				PRINT 'Reg balance: ' + CAST(@RegBalance AS VARCHAR)
				PRINT 'OT balance: ' + CAST(@OTBalance AS VARCHAR)
				PRINT 'DT balance: ' + CAST(@DTBalance AS VARCHAR)					
				
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
  Set #tmpWorkedSummary.Source = CASE WHEN tmpSSNs.IVR_Count > 0 THEN 'F'
  																		WHEN tmpSSNs.WTE_Count > 0 THEN 'H'
  																		ELSE #tmpWorkedSummary.Source
  															 END,
  		#tmpWorkedSummary.ApprovalStatus = CASE WHEN (tmpSSNs.OtherTxns_Count + tmpSSNs.Dispute_Count) > 0 AND #tmpWorkedSummary.ApprovalStatus = '1' THEN '2'
  																						ELSE #tmpWorkedSummary.ApprovalStatus
  																			 END
from #tmpWorkedSummary 
INNER JOIN #tmpSSNs AS tmpSSNs
ON tmpSSNs.SSN = #tmpWorkedSummary.SSN

SELECT 	Client, GroupCode, PayrollPeriodEndDate, TransDate, SSN, FileNo,
				AssignmentNo, BranchID, DeptName,
				TotalRegHours, TotalOT_Hours, TotalDT_Hours, TotalWeeklyHours,
				ApproverName, ApproverDateTime, ApprovalID, ApprovalStatus,
				DayWorked, FlatPay, FlatBill, EmplName, PFP_Flag, PayRate, BillRate, Source
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






