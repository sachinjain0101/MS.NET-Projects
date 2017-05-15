Create PROCEDURE [dbo].[usp_GambroMthlyAccUpl_FixSalary]
(
  @Client varchar(4),
	@GroupCode int,
	@PPED DateTime,
  @StartDate datetime,
  @EndDate datetime,
  @PayrollFreq char(1)
)

As

/*
drop table #AverageRateWork
drop table #AverageRates
drop table #Payroll_THD
drop table #FinalPayRollRecs
drop table #PayrollSum 

DECLARE @Client varchar(4)
DECLARE @GroupCode int
DECLARE @PPED DateTime
DECLARE @StartDate datetime
DECLARE @EndDate Datetime
DECLARE @PayrollFreq char(1)
DECLARE @SSN int

SELECT @Client = 'GAMB'
SELECT @GroupCode = 610300
SELECT @PPED = '8/2/2003'
SELECT @PayrollFreq = 'B'
Select @StartDate = '7/20/03'
Select @EndDate = '7/31/03'
SELECT @SSN = 136845901
--EXEC @RC = [TimeHistory].[dbo].[usp_GambroMthlyAccUpl] 'GAMB', 610300, '8/2/03', '7/20/03', '7/31/03', 'B'

*/

SET NOCOUNT ON
set ANSI_WARNINGS OFF


DECLARE @PPED2 datetime
DECLARE @AccrualID varchar(12)
DECLARE @SalAccrualPercent numeric(9,6)
DECLARE @NoWeeks int

SET @PPED2 = dateadd(day, -7, @PPED)
SET @AccrualID = ltrim(str(month(@StartDate))) + '/' + ltrim(str(year(@StartDate)))
SET @NoWeeks = 2

if @PayrollFreq = 'W'
BEGIN
  SET @NoWeeks = 1
END

---------------------------------------------------------------------------------------------------
--Create Average Rate table for weeks within payroll period
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
-- Generate Salary records based on the percentage set up for the monthly accrual
-- 
---------------------------------------------------------------------------------------------------

  SELECT t.Client, t.GroupCode, t.SSN, t.SiteNo, t.DeptNo, t.TransDate, Holiday = '0', en.PayRate,
	   AvgPayRate = 0,
	   ShiftDiffClass = '0', 
	   ClockAdjustmentNo = 'S',
	   BreakAdj = '0',
	   RegHours = sum(t.RegHours),
	   OT_Hours = 0,
	   DT_Hours = 0,
	   Dollars = 0,
	   Hours = sum(t.RegHours),
	   PayrollPeriodEndDate = @PPED,
     NonShiftDiffHours = 0.00,
     ShiftDiffHours = 0,
     MissingPunch = '0',
     en.BaseHours
  into #payroll_thd
	FROM tblTimeHistDetail as t
  Inner join timecurrent..tblEmplNames as en
    on en.client = t.client
    and en.groupcode = t.groupcode
    and en.ssn = t.ssn
	WHERE t.Client = @Client
	  AND t.GroupCode = @GroupCode
	  AND en.PayType = '1'
    and t.payrollperiodenddate = @pped
    and t.ClockadjustmentNo not in('1','S','8')
  Group By t.Client, t.GroupCode, t.SSN, t.SiteNo, t.DeptNo, t.TransDate, en.PayRate,
     en.BaseHours

  Update #payroll_thd Set RegHours = BaseHours, Hours = BaseHours
    where RegHours > BaseHours


---------------------------------------------------------------------------------------------------
-- Initiate prelim summary table for Payroll upload.
-- Then populate with Regular, OT & DT summary records by calling a subordinate stored procedure
---------------------------------------------------------------------------------------------------

CREATE TABLE #PayrollSum (
	[SSN] [int] NOT NULL ,
	[SiteWorkedAt] [INT] NOT NULL ,  --< SiteWorkedAt data type is changed from  SMALLINT to INT by Srinsoft on 24Aug2016 >--
	[DeptNo] [INT] NOT NULL ,  --< DeptNo data type is changed from  SMALLINT to INT by Srinsoft on 24Aug2016 >--
	[PayRate] [numeric](7, 4) NULL ,
	[AvgPayRate] [float] NULL ,
	[AssignmentNo] [varchar] (12) NULL ,
	[HomeSite] [INT] NULL ,  --< HomeSite data type is changed from  SMALLINT to INT by Srinsoft on 24Aug2016 >--
	[PayType] [tinyint] NULL ,
	[PrimaryJobCode] [varchar] (20) NULL ,
	[FileNo] [varchar] (10) NULL ,
	[ClockAdjustmentNo] [varchar] (3) NULL ,  --< Srinsoft 08/28/2015 Changed [ClockAdjustmentNo] [char] (1) to varchar(3) >--
	[AdjustmentCode] [varchar] (3) NULL ,
	[SpecialHandling] [varchar] (5) NULL ,
	[AdjustmentType] [char] (1) NULL ,
	[UploadAsSiteNo] [int] NULL ,
	[HoursType] [varchar] (3) NULL ,
	[ShiftDiffClass] [char] (1) NULL ,
	[SumOfRegHours] [numeric](20, 2) NULL ,
	[SumOfOT_Hours] [numeric](20, 2) NULL ,
	[SumOfDT_Hours] [numeric](20, 2) NULL ,
	[SumOfDollars] [numeric](20, 2) NULL ,
	[SumOfHours] [numeric](20, 2) NULL ,
  [MissingPunch] [char] (1) NULL,
	[ExceptionError] [varchar] (50) NULL ,
	[ExceptionType] [char] (1) NULL)

EXEC usp_GambroMthlyAccSum_Work @Client, @GroupCode, @PPED, '1RG', 'PAY'
EXEC usp_GambroMthlyAccSum_Work @Client, @GroupCode, @PPED, '2OT', 'PAY'
EXEC usp_GambroMthlyAccSum_Work @Client, @GroupCode, @PPED, '3DT', 'PAY'

---------------------------------------------------------------------------------------------------
-- Override the Weighted OT rate for Holiday Hours, They should only get 1.5 x Base Rate.
---------------------------------------------------------------------------------------------------
Update #PayrollSum Set AvgPayRate = PayRate where AdjustmentCode = '140'
Update #PayrollSum Set AdjustmentCode = '109' where MissingPunch = '1'

SELECT  #PayrollSum.SSN, #PayrollSum.SiteWorkedAt, #PayrollSum.DeptNo, #PayrollSum.PayRate, convert(numeric(7,2), AvgPayRate) as nAvgPayRate,
		#PayrollSum.AssignmentNo, #PayrollSum.HomeSite, #PayrollSum.PayType, #PayrollSum.PrimaryJobCode, #PayrollSum.FileNo, #PayrollSum.ClockAdjustmentNo,
		#PayrollSum.AdjustmentCode, 
		AdjustmentName = CASE WHEN #PayrollSum.ClockAdjustmentNo = 'S' THEN 'SALARY' WHEN #PayrollSum.ClockAdjustmentNo = '' THEN '' ELSE tblAdjCodes.AdjustmentName END,
		#PayrollSum.SpecialHandling, #PayrollSum.AdjustmentType, #PayrollSum.UploadAsSiteNo,
		sum(SumOfRegHours) AS SumOfRegHours,
		sum(SumOfOT_Hours) AS SumOfOT_Hours,
		sum(SumOfDT_Hours) AS SumOfDT_Hours,
		sum(SumOfDollars) AS SumOfDollars,
		sum(SumOfHours) AS SumOfHours,
		ExceptionError,
		ExceptionType,
		tblEmplNames.AgencyNo,
		tblEmplNames.LastName,
		tblEmplNames.FirstName,
		tblSiteNames.DivisionID,
		tblSiteNames.Client,
		tblSiteNames.VirtualSite,
    AllocationFlag = '0',
    BaseHours = cast(0.00 as numeric(7,2))
INTO #FinalPayrollRecs
FROM #PayrollSum
LEFT JOIN TimeCurrent..tblEmplNames AS tblEmplNames ON tblEmplNames.Client = @Client
													AND tblEmplNames.GroupCode = @GroupCode
													AND tblEmplNames.SSN = #PayrollSum.SSN
LEFT JOIN TimeCurrent..tblAdjCodes AS tblAdjCodes ON tblAdjCodes.Client = @Client
													AND tblAdjCodes.GroupCode = @GroupCode
													AND tblAdjCodes.ClockAdjustmentNo = #PayrollSum.ClockAdjustmentNo
LEFT JOIN TimeCurrent..tblSiteNames As tblSiteNames On tblSiteNames.Client = @Client
													AND tblSiteNames.GroupCode = @GroupCode
													AND tblSiteNames.SiteNo = #PayrollSum.SiteWorkedAt
WHERE (SumOfRegHours <> 0
   OR SumOfOT_Hours <> 0
   OR SumOfDT_Hours <> 0
   OR SumOfDollars <> 0
   OR SumOfHours <> 0
   OR ExceptionError <> '')
--	AND #PayrollSum.PayType = '1'
GROUP BY #PayrollSum.SSN, #PayrollSum.SiteWorkedAt, #PayrollSum.DeptNo, #PayrollSum.PayRate, #PayrollSum.AvgPayRate, #PayrollSum.ShiftDiffClass,
		 #PayrollSum.AssignmentNo, #PayrollSum.HomeSite, #PayrollSum.PayType, #PayrollSum.PrimaryJobCode, #PayrollSum.FileNo, #PayrollSum.ClockAdjustmentNo,
		 #PayrollSum.AdjustmentCode, tblAdjCodes.AdjustmentName, #PayrollSum.SpecialHandling, #PayrollSum.AdjustmentType, #PayrollSum.UploadAsSiteNo, 
		 #PayrollSum.HoursType, ExceptionError, ExceptionType, 
     tblEmplNames.AgencyNo, tblEmplNames.FirstName, tblEmplNames.LastName, tblSiteNames.DivisionID,tblSiteNames.Client,tblSiteNames.VirtualSite


--=============================================================================================
-- The following code will allocate hourly/salary employees based on allocations established in
-- timecurrent..tblEmplAllocation. 
-- The True UploadCode and JobCode will be used from allocation table.
--=============================================================================================
DECLARE @tmpSSN int
DECLARE @PayRate numeric(9,4)
DECLARE @AvgPayRate numeric(12,6)
DECLARE @AdjCode varchar(3)
DECLARE @SpecHandling varchar(20)
DECLARE @JobCode varchar(32)
DECLARE @UploadCode varchar(32)
DECLARE @SumRG numeric(9,2)
DECLARE @SumOT numeric(9,2)
DECLARE @SumDT numeric(9,2)
DECLARE @DivisionID varchar(6)
DECLARE @VirtualSite char(1)

-- ======================================================================================
-- Build a cursor from the employees that have allocations for this client/Group
-- ======================================================================================
DECLARE csrThd CURSOR
READ_ONLY
FOR 
Select fp.SSN, round(fp.PayRate,4), round(fp.nAvgPayRate,4), fp.AdjustmentCode, fp.SpecialHandling, ea.UploadCode, ea.JobCode,fp.DivisionID,fp.VirtualSite,
SumRg = round(Sum(fp.SumofRegHours * (EA.Percentage / 100 )),2), SumOT = Round(Sum(fp.SumofOT_Hours * (EA.Percentage / 100 )),2) , SumDT = round(Sum(fp.SumOfDT_Hours * (EA.Percentage / 100 )),2)
from #FinalPayRollRecs as fp
inner join TimeCurrent..tblEmplAllocation as EA
on EA.Client = @Client
and EA.Groupcode = @GroupCode
and EA.SSN = fp.SSN
and EA.UploadCode is not NULL    -- Only want allocations that have an upload code and Job Code
and EA.JobCode is not NULL
and EA.RecordStatus = '1'        -- Must be an active allocation
where AdjustmentType = 'H'       -- Only Allocate for hours (no dollars)
and SumofDollars = 0.00
and ClockAdjustmentNo not IN('2','3','4') -- Skip PTO Adjustments.
group by fp.SSN, fp.PayRate, fp.nAvgPayRate, fp.AdjustmentCode, fp.SpecialHandling, ea.UploadCode, ea.JobCode, fp.DivisionID, fp.VirtualSite


OPEN csrThd


FETCH NEXT FROM csrThd INTO @tmpSSN, @PayRate, @AvgPayRate, @AdjCode, @SpecHandling, @UploadCode, @JobCode, @DivisionID, @VirtualSite, @SumRG, @SumOT, @SumDT
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
    -- ======================================================================================
    -- Delete the records from the Payroll Recs Temp Table.
    -- ======================================================================================
    delete from #FinalPayrollRecs 
        where SSN = @tmpSSN
          and round(PayRate,4) = @PayRate
          and round(nAvgPayRate,4) = @AvgPayRate
          and AdjustmentCode = @AdjCode
          and SpecialHandling = @SpecHandling
          and AdjustmentType = 'H'
          and SumofDollars = 0.00
          and AllocationFlag = '0'
          and ClockAdjustmentNo not IN('2','3','4') -- Skip PTO Adjustments.


    Insert into #FinalPayRollRecs (SSN, SiteWorkedAt, DeptNo, PayRate, nAvgpayRate, AssignmentNo, HomeSite, PayType, PrimaryJobCode, FileNo, ClockAdjustmentNo, AdjustmentCode, AdjustmentName, SpecialHandling, AdjustmentType, UploadAsSiteNo, SumOfRegHours, SumOfOT_Hours, SumOfDT_Hours, SumOfDollars, SumOfHours, ExceptionError, ExceptionType, AgencyNo, lastName, FirstName, DivisionID, Client, VirtualSite, AllocationFlag,BaseHours )
    (Select en.SSN, en.primarySite, en.primarydept, @payRate, @AvgPayRate, en.AssignmentNo, en.PrimarySite, en.PayType, @JobCode, substring(@UploadCode,1,4) + '0' + substring(@UploadCode,5,1), '', @AdjCode, '', @SpecHandling, 'H', 0, @SumRG, @SumOT, @SumDT, 0.00, (@SumRG + @SumDT + @SumOT), '', '', en.AgencyNo, en.LastName, en.FirstName, @DivisionID, @Client, @VirtualSite, '1', en.BaseHours
      from timeCurrent..tblEmplNames as en
      where en.client = @Client
        and en.Groupcode = @GroupCode
        and en.SSN = @tmpSSN)

	END
	FETCH NEXT FROM csrThd INTO @tmpSSN, @PayRate, @AvgPayRate, @AdjCode, @SpecHandling, @UploadCode, @JobCode, @DivisionID, @VirtualSite, @SumRG, @SumOT, @SumDT
END


CLOSE csrTHD
DEALLOCATE csrThd

select * from #FinalPayRollRecs Order By SiteWorkedAt, SSN, DeptNo

--select sum(sumofreghours) from #FinalPayRollRecs where adjustmentcode <> 'SH2'

/*
drop table #AverageRateWork
drop table #AverageRates
drop table #WeekEndDates
drop table #AverageRateWork_Partial
drop table #AverageRates_Partial
drop table #Payroll_THD
drop table #PayrollSum 
drop table #FinalPayRollRecs
*/
















