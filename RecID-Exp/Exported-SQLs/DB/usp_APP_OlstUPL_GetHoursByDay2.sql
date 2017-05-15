CREATE    Procedure [dbo].[usp_APP_OlstUPL_GetHoursByDay2]
( 
  @Client char(4),
  @GroupCode int,
  @PPED DATETIME,
  @RecordType char(1) = '' 
) 

AS


SET NOCOUNT ON


/*
DECLARE  @Client char(4)
DECLARE  @GroupCode int
DECLARE  @PPED DateTime

SET @Client = 'OLST'
SET @GroupCode = 877300
SET @PPED = '5/16/08' 

Drop Table #tmpTotHrs
Drop Table #tmpDailyHrs
Drop Table #tmpDailyHrs1
Drop Table #tmpNegHours
*/

DECLARE
 @ShiftZeroCount int
,@CalcBalanceCnt int
,@UseDeptName char(1) = '0'
,@OpenDepts char(1) = '0'
,@UsePFP char(1) = '0'
,@ClientGroupID1 varchar(200)
,@grpOTMult numeric(15,10)
,@prOTMult numeric(15,10)
,@OTMult numeric(15,10)
,@ApprovalModeBool VARCHAR(1)
,@RFR_ID VARCHAR(100)

CREATE TABLE #LateTimeEmpls (SSN INT)

IF (ISNULL(@RecordType, '') = 'L')
BEGIN
	INSERT INTO #LateTimeEmpls
	SELECT DISTINCT SSN
	FROM TimeCurrent.dbo.tblClosedPeriodAdjs
	WHERE Client = @Client
	AND GroupCode = @GroupCode
	AND PayrollPeriodEndDate = @PPED
	AND DateTimeProcessed IS NULL
END

Select 	@ClientGroupID1 = isnull(ClientGroupID1,''), 
				@grpOTMult = BillingOvertimeCalcFactor,
				@ApprovalModeBool = ISNULL(ApprovalModeBool, '0'),
				@RFR_ID = isnull(RFR_UniqueID,'')
from TimeCurrent..tblClientGroups 
where client = @Client 
and GroupCode = @GroupCode

IF @ClientGroupID1 like '%UseDeptName%'
  Set @UseDeptName = '1'

IF @ClientGroupID1 like '%UseOpenDepts%'
  Set @OpenDepts = '1'

IF @ClientGroupID1 like '%UsePFP%'
  Set @UsePFP = '1'

--This set command is needed when executing this stored procedure via ADO
--

--First Check to make sure that all employees got re-calced correctly.
--and do not have a zero shift number.


--
-- Check to see if there are any records for this cycle that have 0 shift numbers.
-- 

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
--
-- Make sure all records got calculated correctly for this cycle.
--

IF EXISTS
(
 SELECT 1 FROM TimeHistory.dbo.tblTimeHistDetail
 WHERE Client = @Client AND GroupCode = @GroupCode
 AND PayrollPeriodEndDate = @PPED
 AND
  (
   (ISNULL(@RecordType, '') <> 'L') 
   OR 
   (ISNULL(@RecordType, '') = 'L' AND SSN IN (SELECT DISTINCT SSN FROM #LateTimeEmpls))
  ) 
 GROUP BY GroupCode,PayrollPeriodEndDate,SSN
 HAVING SUM([Hours]) <> SUM(RegHours + OT_Hours + DT_Hours)
)
BEGIN
  RAISERROR ('Employees exists that are out of balance between worked and calculated.', 16, 1) 
  RETURN
END


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
	ApprovalStatus varchar(1),
	ApproverDateTime datetime,
	MaxRecordID BIGINT,  --< MaxRecordId data type is changed from  INT to BIGINT by Srinsoft on 17Aug2016 >--
	ADP_ClockAdjustmentNo VARCHAR(50)
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
	ApprovalStatus varchar(1),
	ApproverDateTime datetime,
	MaxRecordID BIGINT,  --< MaxRecordId data type is changed from  INT to BIGINT by Srinsoft on 17Aug2016 >--
	ADP_ClockAdjustmentNo VARCHAR(50)
)

IF @OpenDepts = '1' 
BEGIN
	-- IF OPEN DEPARTMENTS are ON then a special pay will store the assignment Number in the cost ID field.
	-- Load from the cost ID field
	--
	--
	--Get the Daily totals for each SSN, display the weekly total as one of the columns.
	-- 
	INSERT INTO #tmpDailyHrs1
	SELECT   thd.Client,
		       thd.GroupCode,
	         thd.PayrollPeriodEndDate,  
	         thd.TransDate,  
	         thd.SSN,  
	         CASE WHEN @UseDeptName = '1' THEN (case when isnull(gd.ClientDeptCode,'') <> '' then gd.CLientDeptCode else gd.DeptName end) ELSE '' END as DeptName,
	         AssignmentNo = case when ltrim(isnull(hed.AssignmentNo,'')) = '' then (CASE WHEN isnull(curED.AssignmentNo,'') = '' THEN CASE WHEN @RFR_ID <> '' THEN substring(thd.CostID,8,24) ELSE ISNULL(thd.CostID, '') END ELSE curED.AssignmentNo END) else hed.AssignmentNo end,	       
	         BranchID = case WHEN ltrim(isnull(hed.PurchOrderNo,'')) = '' 
	         								 THEN (CASE WHEN isnull(curED.PurchOrderNo,'') = '' 
	         								 						THEN (CASE WHEN ISNULL(en.AssignmentNo, '') = ''
																								 THEN ltrim(substring(thd.CostID,1,6)) 
																								 ELSE en.AssignmentNo
																								 END)
																			ELSE curED.PurchOrderNo 
	         														END) 	         														
	         								 ELSE 
	         								 			hed.PurchOrderNo 
	         								 END,	         								 
	         TotalRegHours = Case when @GroupCode in(865600,867300) Then
	            Sum(thd.RegHours + thd.OT_Hours + thd.DT_Hours) 
	            ELSE Sum(thd.RegHours) END,
	         TotalOT_Hours = Case when @GroupCode in(865600,867300) Then 0
	            ELSE Sum(thd.OT_Hours) END,
	         TotalDT_Hours = Case when @GroupCode IN(865600,867300) Then 0
	            ELSE Sum(thd.DT_Hours) END,
					 PayRate = case when @UsePFP = '1' then thd.PayRate else 0.00 end,
					 BillRate = case when @UsePFP = '1' then thd.BillRate else 0.00 end,
					 PFP_Flag = @UsePFP,
				   ApproverName = cast('' as varchar(40)), 
					 ApprovalStatus = cast('' as char(1)),	
				   ApproverDateTime = max( isnull(thd.AprvlStatus_Date, getdate()) ),
				   MaxRecordID = Min(thd.recordID),
				   ADP_ClockAdjustmentNo = CASE WHEN thd.ClockAdjustmentNo IN ('','1','$','@','8') THEN '' ELSE thd.ClockAdjustmentNo END
	FROM TimeHistory..tblTimeHistDetail as thd
	  INNER JOIN TimeCurrent.dbo.tblSiteNames as sn
	    ON thd.SiteNo = sn.SiteNo  
	         AND thd.GroupCode = sn.GroupCode  
	         AND thd.Client = sn.Client  
	         AND sn.IncludeInUpload = '1' 
	  LEFT JOIN TimeHistory..tblEmplNames_Depts as hed
	    ON thd.PayrollPeriodEndDate =  hed.PayrollPeriodEndDate  
	         AND thd.GroupCode = hed.GroupCode  
	         AND thd.Client = hed.Client  
	         AND thd.SSN = hed.SSN  
	         AND thd.DeptNo = hed.Department                   
	  INNER JOIN TimeCurrent..tblGroupDepts gd
	    ON gd.Client = thd.Client
	         AND gd.GroupCode = thd.GroupCode     
	         AND gd.DeptNo = thd.DeptNo         
	  LEFT JOIN TimeCurrent.dbo.tblEmplNames as EN 
	    ON   thd.SSN = EN.SSN  
	         AND thd.GroupCode = EN.GroupCode  
	         AND thd.Client = EN.Client 
	  LEFT JOIN TimeCurrent..tblAgencies ag
	    ON  en.Client = ag.Client
	         AND en.GroupCode = ag.GroupCode
	         AND en.AgencyNo = ag.Agency
	  LEFT JOIN TimeCurrent.dbo.tblEmplNames_Depts as curED
	    ON thd.SSN = curED.SSN  
	         AND thd.GroupCode = curED.GroupCode  
	         AND thd.Client = curED.Client  
	         AND case when @groupCode in(864700,868900,875700) then en.primaryDept else thd.DeptNo end = curED.Department  
					 --AND curED.RecordStatus = case when @UseDeptName = '1' then '1' else curED.RecordStatus end
		WHERE thd.Client = @Client  
	         AND thd.PayrollPeriodEndDate = @PPED  
	         AND thd.GroupCode = @GroupCode  
	         AND IsNull(ag.ExcludeFromPayFile,'0') <> '1'
	         AND IsNull(hed.ExcludeFromUpload, '0') <> '1' 
					 AND ((ISNULL(@RecordType, '') <> 'L') OR 
					  		(ISNULL(@RecordType, '') = 'L' AND thd.SSN IN ( SELECT DISTINCT SSN 
																								  					FROM #LateTimeEmpls
																								  				 )
								 )
							 )
					 AND thd.Hours <> 0	         
	GROUP BY thd.Client,  
	         thd.GroupCode,  
	         thd.SSN,  
	         thd.PayrollPeriodEndDate,  
	         thd.TransDate,  
					 case when @UsePFP = '1' then thd.PayRate else 0.00 end,
					 case when @UsePFP = '1' then thd.BillRate else 0.00 end,	
	         CASE WHEN @UseDeptName = '1' THEN (case when isnull(gd.ClientDeptCode,'') <> '' then gd.CLientDeptCode else gd.DeptName end) ELSE '' END,
	         case when ltrim(isnull(hed.AssignmentNo,'')) = '' then (CASE WHEN isnull(curED.AssignmentNo,'') = '' THEN CASE WHEN @RFR_ID <> '' THEN substring(thd.CostID,8,24) ELSE ISNULL(thd.CostID, '') END ELSE curED.AssignmentNo END) else hed.AssignmentNo end,
	         case WHEN ltrim(isnull(hed.PurchOrderNo,'')) = '' 
	         								 THEN (CASE WHEN isnull(curED.PurchOrderNo,'') = '' 
	         								 						THEN (CASE WHEN ISNULL(en.AssignmentNo, '') = ''
																								 THEN ltrim(substring(thd.CostID,1,6)) 
																								 ELSE en.AssignmentNo
																								 END)
																			ELSE curED.PurchOrderNo 
	         														END) 	         														
	         								 ELSE 
	         								 			hed.PurchOrderNo 
	         								 END,
	         CASE WHEN thd.ClockAdjustmentNo IN ('','1','$','@','8') THEN '' ELSE thd.ClockAdjustmentNo END

	-- Second select is used to combine transaction dates that could not be combined in the prior select 
	-- This helps reduce negative hours processing.
	--
	INSERT INTO #tmpDailyHrs
	Select Client, GroupCode, PayrollPeriodenddate, TransDate, SSN, DeptName, AssignmentNo, BranchID,
			Sum(TotalRegHours), Sum(TotalOT_Hours), Sum(TotalDT_Hours), PayRate, BillRate, PFP_Flag, ApproverName, 
			ApprovalStatus, max(ApproverDateTime), Max(MaxRecordID), ADP_ClockAdjustmentNo
	from #tmpDailyHrs1
	group By 
		Client, GroupCode, PayrollPeriodenddate, TransDate, SSN, DeptName, AssignmentNo, BranchID,
		PayRate, BillRate, PFP_Flag, ApproverName, ApprovalStatus, ADP_ClockAdjustmentNo
	
END
ELSE
BEGIN
	--Get the Daily totals for each SSN, display the weekly total as one of the columns.
	--
	INSERT INTO #tmpDailyHrs1
	SELECT   thd.Client,
		       thd.GroupCode,
	         thd.PayrollPeriodEndDate,  
	         thd.TransDate,  
	         thd.SSN,  
	         CASE WHEN @UseDeptName = '1' THEN (case when isnull(gd.ClientDeptCode,'') <> '' then gd.CLientDeptCode else gd.DeptName end) ELSE '' END as DeptName,
	         AssignmentNo = case when ltrim(isnull(hed.AssignmentNo,'')) = '' then curED.AssignmentNo else hed.AssignmentNo end ,
	         --curED.AssignmentNo,  
	         --hed.AssignmentNo,  
	         BranchID = case WHEN ltrim(isnull(curED.PurchOrderNo,'')) = '' 
	         								 THEN en.AssignmentNo     														
	         								 ELSE 
	         								 			curED.PurchOrderNo 
	         								 END,	 
	         TotalRegHours = Case when @GroupCode in(865600,867300) Then
	            Sum(thd.RegHours + thd.OT_Hours + thd.DT_Hours) 
	            ELSE Sum(thd.RegHours) END,
	         TotalOT_Hours = Case when @GroupCode in(865600,867300) Then 0
	            ELSE Sum(thd.OT_Hours) END,
	         TotalDT_Hours = Case when @GroupCode IN(865600,867300) Then 0
	            ELSE Sum(thd.DT_Hours) END,
					 PayRate = case when @UsePFP = '1' then thd.PayRate else 0.00 end,
					 BillRate = case when @UsePFP = '1' then thd.BillRate else 0.00 end,	
					 PFP_Flag = @UsePFP,
				   ApproverName = cast('' as varchar(40)), 
					 ApprovalStatus = cast('' as char(1)),	
				   ApproverDateTime = max( isnull(thd.AprvlStatus_Date, getdate()) ),
				   MaxRecordID = MIN(thd.recordID),
				   ADP_ClockAdjustmentNo = CASE WHEN thd.ClockAdjustmentNo IN ('','1','$','@','8') THEN '' ELSE thd.ClockAdjustmentNo END
	FROM tblTimeHistDetail as thd
	  INNER JOIN TimeCurrent.dbo.tblSiteNames as sn
	    ON thd.SiteNo = sn.SiteNo  
	         AND thd.GroupCode = sn.GroupCode  
	         AND thd.Client = sn.Client  
	         AND sn.IncludeInUpload = '1' 
	  LEFT JOIN TimeHistory..tblEmplNames_Depts as hed
	    ON thd.PayrollPeriodEndDate =  hed.PayrollPeriodEndDate  
	         AND thd.GroupCode = hed.GroupCode  
	         AND thd.Client = hed.Client  
	         AND thd.SSN = hed.SSN  
	         AND thd.DeptNo = hed.Department           
					 --AND ISNULL(hed.RecordStatus, '1') = case when @UseDeptName = '1' then '1' else ISNULL(hed.RecordStatus, '1') end
	  INNER JOIN TimeCurrent..tblGroupDepts gd
	    ON gd.Client = thd.Client
	         AND gd.GroupCode = thd.GroupCode     
	         AND gd.DeptNo = thd.DeptNo         
	  LEFT JOIN TimeCurrent.dbo.tblEmplNames as EN 
	    ON   thd.SSN = EN.SSN  
	         AND thd.GroupCode = EN.GroupCode  
	         AND thd.Client = EN.Client 
	  INNER JOIN TimeCurrent..tblAgencies ag
	    ON  en.Client = ag.Client
	         AND en.GroupCode = ag.GroupCode
	         AND en.AgencyNo = ag.Agency
	  LEFT JOIN TimeCurrent.dbo.tblEmplNames_Depts as curED
	    ON thd.SSN = curED.SSN  
	         AND thd.GroupCode = curED.GroupCode  
	         AND thd.Client = curED.Client  
	         AND case when @groupCode in(864700,868900,875700) then en.primaryDept else thd.DeptNo end = curED.Department  
	WHERE    thd.Client = @Client  
	         AND thd.PayrollPeriodEndDate = @PPED  
	         AND thd.GroupCode = @GroupCode  
	         AND IsNull(ag.ExcludeFromPayFile,'0') <> '1'
	         AND IsNull(hed.ExcludeFromUpload, '0') <> '1' 
					 AND ((ISNULL(@RecordType, '') <> 'L') OR 
					  		(ISNULL(@RecordType, '') = 'L' AND thd.SSN IN ( SELECT DISTINCT SSN 
																								  					FROM #LateTimeEmpls
																								  				 )
								 )
							 )
					 AND thd.Hours <> 0	         
	GROUP BY thd.Client,
	         thd.GroupCode,
	         thd.SSN,
	         thd.PayrollPeriodEndDate,
	         thd.TransDate,
					 case when @UsePFP = '1' then thd.PayRate else 0.00 end,
					 case when @UsePFP = '1' then thd.BillRate else 0.00 end,
	         CASE WHEN @UseDeptName = '1' THEN (case when isnull(gd.ClientDeptCode,'') <> '' then gd.CLientDeptCode else gd.DeptName end) ELSE '' END,
	         case when ltrim(isnull(hed.AssignmentNo,'')) = '' then curED.AssignmentNo else hed.AssignmentNo end ,
	         case WHEN ltrim(isnull(curED.PurchOrderNo,'')) = '' 
	         								 THEN en.AssignmentNo     														
	         								 ELSE 
	         								 			curED.PurchOrderNo 
	         								 END,
	         CASE WHEN thd.ClockAdjustmentNo IN ('','1','$','@','8') THEN '' ELSE thd.ClockAdjustmentNo END

	-- Second select is used to combine transaction dates that could not be combined in the prior select 
	-- This helps reduce negative hours processing.
	--
	INSERT INTO #tmpDailyHrs (Client, GroupCode, PayrollPeriodenddate, TransDate, SSN, DeptName, AssignmentNo, BranchID,
			TotalRegHours, TotalOT_Hours, TotalDT_Hours, PayRate, BillRate, PFP_Flag, ApproverName, 
			ApprovalStatus, ApproverDateTime, MaxRecordID, ADP_ClockAdjustmentNo )
	Select Client, GroupCode, PayrollPeriodenddate, TransDate, SSN, DeptName, AssignmentNo, BranchID,
			Sum(TotalRegHours), Sum(TotalOT_Hours), Sum(TotalDT_Hours), PayRate, BillRate, PFP_Flag, ApproverName, 
			ApprovalStatus, max(ApproverDateTime), Max(MaxRecordID), ADP_ClockAdjustmentNo
	from #tmpDailyHrs1
	group By 
		Client, GroupCode, PayrollPeriodenddate, TransDate, SSN, DeptName, AssignmentNo, BranchID,
		PayRate, BillRate, PFP_Flag, ApproverName, ApprovalStatus, ADP_ClockAdjustmentNo
	
	         
	-- For Fuji and Canadian Tire(CTC) the txns with departments that don't exist in EmplNames_Depts need to
	-- have the AssignmentNo populated.  AssignmentNo is the same for all departments.
	--IF @UseDeptName = '1'
	IF (@GroupCode in(864700,865800,865700,868900) )
	BEGIN
	  UPDATE #tmpDailyHrs
	  SET AssignmentNo = (SELECT TOP 1 AssignmentNo
	                      FROM #tmpDailyHrs tmp2
	                      WHERE tmp2.SSN = #tmpDailyHrs.SSN
	                      AND ltrim(isnull(tmp2.AssignmentNo,'')) <> '')
	  WHERE ltrim(isnull(AssignmentNo,'')) = ''
	  /*
	  UPDATE #tmpTotHrs
	  SET AssignmentNo = (SELECT TOP 1 AssignmentNo
	                      FROM #tmpTotHrs tmp2
	                      WHERE tmp2.SSN = #tmpTotHrs.SSN
	                      AND ltrim(isnull(tmp2.AssignmentNo,'')) <> '' )
	  WHERE ltrim(isnull(AssignmentNo,'')) = ''
	*/
		-- May be a case where the employee doesn't have any time in a department that has
		-- an AssignmentNo, therefore look in TimeCurrent
	
	  UPDATE #tmpDailyHrs
	  SET AssignmentNo = (SELECT TOP 1 AssignmentNo
	                      FROM TimeCurrent..tblEmplNames_Depts ends
	                      WHERE ends.Client = @Client
												AND ends.GroupCode = @GroupCode
												AND ends.SSN = #tmpDailyHrs.SSN
												AND ends.RecordStatus = '1'
	                      AND ltrim(isnull(ends.AssignmentNo,'')) <> '')
	  WHERE ltrim(isnull(AssignmentNo,'')) = ''
	  /*
	  UPDATE #tmpTotHrs
	  SET AssignmentNo = (SELECT TOP 1 AssignmentNo
	                      FROM TimeCurrent..tblEmplNames_Depts ends
	                      WHERE ends.Client = @Client
	
												AND ends.GroupCode = @GroupCode
												AND ends.SSN = #tmpTotHrs.SSN
												AND ends.RecordStatus = '1'
	                      AND ltrim(isnull(ends.AssignmentNo,'')) <> '')
	  WHERE ltrim(isnull(AssignmentNo,'')) = ''
	*/
		-- Just incase there are no active ones, look for inactive ones too so at least
		-- it will find something
	  UPDATE #tmpDailyHrs
	  SET AssignmentNo = (SELECT TOP 1 AssignmentNo
	                      FROM TimeCurrent..tblEmplNames_Depts ends
	                      WHERE ends.Client = @Client
												AND ends.GroupCode = @GroupCode
												AND ends.SSN = #tmpDailyHrs.SSN
	                      AND ltrim(isnull(ends.AssignmentNo,'')) <> '')
	  WHERE ltrim(isnull(AssignmentNo,'')) = ''
	  /*
	  UPDATE #tmpTotHrs
	  SET AssignmentNo = (SELECT TOP 1 AssignmentNo
	                      FROM TimeCurrent..tblEmplNames_Depts ends
	                      WHERE ends.Client = @Client
												AND ends.GroupCode = @GroupCode
												AND ends.SSN = #tmpTotHrs.SSN
	                      AND ltrim(isnull(ends.AssignmentNo,'')) <> '')
	  WHERE ltrim(isnull(AssignmentNo,'')) = ''
	  */
	END

END

LOADPAYFILE:	

-- Create negative table to report from
--select SSN, TotHrs = sum(TotalRegHours + totalOT_Hours + TotalDT_Hours) into #tmpNegHours from #tmpDailyHrs group by SSN having sum(TotalRegHours + totalOT_Hours + TotalDT_Hours) <= 0.00


-- remove zero hours transactions;
delete from #tmpDailyHrs where TotalRegHours = 0.00 and TotalOT_Hours = 0.00 and TotalDT_Hours = 0.00
-- And Records for empls that have zero or less hours for the week
--delete from #tmpDailyHrs where SSN in(Select SSN from #tmpNegHours)

Update #tmpDailyHrs
  Set #tmpDailyHrs.ApproverName = case when isnull(usr.Email,'') = '' 
																			 then case when isnull(usr.LastName,'') = '' then isnull(usr.LogonName,'') else left(usr.LastName + ',' + isnull(usr.FirstName,''),50) end
																			 else left(usr.Email,50) end,	
		  #tmpDailyHrs.ApprovalStatus = thd.AprvlStatus
from #tmpDailyHrs
  inner join TimeHistory..tblTimeHistDetail as thd
  on thd.RecordID = #tmpDailyHrs.MaxRecordID
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


INSERT INTO TimeHistory..tblOlstenUploadWork2(
	Client,
	GroupCode,
	PayrollPeriodEndDate,
	TransDate,
	SSN,
  EmplID,
	AssignmentNo,
	BranchID,
	DeptName,
	TotalRegHours,
	TotalOT_Hours,
	TotalDT_Hours,
	TRCCode,
	TRC_Hours,
	TotalWeeklyHours,
	ApproverName,
	ApproverDateTime,
	ApprovalID,
	ApprovalStatus,
	DayWorked,
	FlatPay,
	FlatBill,
	EmplName,
	PFP_Flag,
	PayRate,
	BillRate,
	Source
	)
SELECT   
	TTD.Client,
	TTD.GroupCode,
	TTD.PayrollPeriodEndDate,  
	TTD.TransDate,  
	TTD.SSN,  
  EN.FileNo,
	TTD.AssignmentNo,  
	TTD.BranchID,
	TTD.DeptName,
	TotalRegHours = CASE WHEN TTD.ADP_ClockAdjustmentNo = '' THEN TTD.TotalRegHours ELSE 0 END,
	TTD.TotalOT_Hours,  
	TTD.TotalDT_Hours,  
 TRCCode = tcAC.ADP_HoursCode,
 TRC_Hours = CASE WHEN tcAC.ADP_HoursCode > '' THEN TTD.TotalRegHours ELSE 0 END,
	TTH.TotalWeeklyHours,
	TTD.ApproverName,
	TTD.ApproverDateTime,
	TTD.MaxRecordID,
	CASE WHEN @ApprovalModeBool = '0' THEN '' ELSE (CASE 	when isnull(TTD.ApprovalStatus,'') IN ('L','A') then '1'
																												when isnull(TTD.ApprovalStatus,'') IN('',' ') then '0'
																												when isnull(TTD.ApprovalStatus,'') IN('D') then '3'
																												else '0' END) END,
	'', --Datepart(weekday,TTD.TransDate),
	0.00,
	0.00,
	en.LastName + '; ' + en.FirstName,
	TTD.PFP_Flag,
	TTD.PayRate,
	TTD.BillRate,
	'O'
FROM #tmpDailyHrs as TTD
INNER JOIN #tmpTotHrs as TTH
 ON TTD.Client = TTH.Client
    and TTD.GroupCode = TTH.GroupCode
    and TTD.SSN = TTH.SSN
    and isnull(TTD.AssignmentNo,'') = isnull(TTH.AssignmentNo,'')
    and TTD.PayrollPeriodEndDate = TTH.PayrollPeriodEndDate
    and TTD.DeptName = TTH.DeptName
Inner Join TimeCurrent..tblEmplNames as en
	on EN.Client = TTD.Client
	and en.Groupcode = TTD.GroupCode
	and en.SSN = TTD.SSN
LEFT JOIN TimeCurrent.dbo.tblAdjCodes AS tcAC 
ON tcAC.Client = TTD.Client
AND tcAC.GroupCode = TTD.GroupCode
AND tcAC.ClockAdjustmentNo = TTD.ADP_ClockAdjustmentNo
WHERE
ISNULL(CASE WHEN TTD.ADP_ClockAdjustmentNo = '' THEN TTD.TotalRegHours ELSE 0 END,0) <> 0
OR ISNULL(TTD.TotalOT_Hours,0) <> 0
OR ISNULL(TTD.TotalDT_Hours,0) <> 0
OR ISNULL(CASE WHEN tcAC.ADP_HoursCode > '' THEN TTD.TotalRegHours ELSE 0 END,0) <> 0
ORDER BY TTD.SSN,  
         TTD.BranchID,  
         TTD.AssignmentNo,  
         TTD.DeptName,
         TTD.PayrollPeriodEndDate,  
         TTD.TransDate

IF @UsePFP = '1'
BEGIN
	-- Update the flat Bill, and Flat pay rates in the pay file table.
	
	-- First get the OT Multiplier and DT Multiplier
	--
	Select Distinct 
		@prOTMult = BillingOvertimeCalcFactor
	from TimeCurrent..tblPayRules where client = @Client and GroupCode = @GroupCode and Recordstatus = '1'
	
	Set @prOTMULT = isnull(@prOTMult,0)
	IF @prOTMult <> 0
		Set @OTMult = @prOTMult
	ELSE
		Set @OTMult = @grpOTMult
	
	if @OTMult = 0.00
		Set @OTMult = 1.50

	Update TimeHistory..tblOlstenUploadWork2
		Set FlatPay = (PayRate * TotalRegHours) + ( (PayRate * @OTMult) * TotalOT_Hours ) + ( (PayRate * 2.0) * TotalDT_Hours ),
				FlatBill = (BillRate * TotalRegHours) + ( (BillRate * @OTMult) * TotalOT_Hours ) + ( (BillRate * 2.0) * TotalDT_Hours )
	where PFP_Flag = '1'

END

