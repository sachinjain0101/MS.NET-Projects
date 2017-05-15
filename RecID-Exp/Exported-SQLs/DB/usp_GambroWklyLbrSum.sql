CREATE  Procedure [dbo].[usp_GambroWklyLbrSum]
(
  @Client varchar(4),
  @GroupCode int,
  @WeekEndDate DateTime
)
AS

--*/
/*
DECLARE @Client varchar(4)
DECLARE @GroupCode int
DECLARE @WeekEndDate DateTime

SELECT @Client = 'GAMB'
SELECT @GroupCode = 914200
Select @WeekEndDate = '9/14/02'

drop table #AverageRateWork
drop table #AverageRates
drop table #Payroll_THD
drop table #PayrollSum
drop table #FinalPayrollRecs 

*/


DECLARE @ErrDescription varchar(2000)

SET NOCOUNT ON

-- Delete the '' (blank ) adj code from the adjustment table if it exist. 
-- this will cause bad problems for OT calc if it exist.
--
delete from timecurrent..tblAdjCodes where client = @Client and groupcode = @Groupcode and clockadjustmentno = ''

---------------------------------------------------------------------------------------------------
--Create Average Rate table for week
---------------------------------------------------------------------------------------------------
--Print 'Step 1'
DECLARE @DAVIClient varchar(4)

SET @DAVIClient = 'DAVI'

Create Table #AverageRateWork
(
  Client varchar(4),
  GroupCode int,
  SiteNo int,
  SSN int,
  PayrollPeriodEndDate datetime,
  ShiftDiffHours numeric(8,2),
  PreceptorHours numeric(8,2),
  ShiftDiffPreceptorHours numeric(8,2),
  NormalHours numeric(8,2),
  PayRate numeric(10,4),
  ShiftDiffPct numeric(8,2),
  ShiftDiffDollars numeric(10,2),
  PreceptorDollars numeric(10,2),
  ShiftDiffPreceptorDollars numeric(10,2),
  NormalDollars numeric(10,2),
  DollarAdjs numeric(10,2) ,
  DavitaFlag char(1)
)

---------------------------------------------------------------------------------------------------
--Create Average Rate table for weeks within payroll period
---------------------------------------------------------------------------------------------------
--Create a work table by employee and week for calculating average rate.
insert into #AverageRateWork(Client,GroupCode,SiteNo,SSN,PayrollPeriodEndDate,ShiftDiffHours,PreceptorHours,ShiftDiffPreceptorHours,NormalHours,PayRate,ShiftDiffPct,ShiftDiffDollars,PreceptorDollars,ShiftDiffPreceptorDollars,NormalDollars,DollarAdjs,DavitaFlag )
SELECT THD.Client, 
	THD.GroupCode, 
	THD.SiteNo,
	THD.SSN, 
	THD.PayrollPeriodEndDate,
--	ShiftDiffHours = sum(CASE WHEN THD.ShiftDiffClass IN(' ', '0') or THD.DeptNo IN(2,4,8) THEN 0 ELSE THD.hours END),
	ShiftDiffHours = sum(CASE WHEN THD.ShiftDiffClass IN(' ', '0') THEN 0 ELSE THD.hours END),
	PreceptorHours = 0.00, --sum(CASE WHEN THD.DeptNo IN(2,4,8) and THD.ShiftDiffClass IN(' ', '0') THEN THD.hours ELSE 0 END),
	ShiftDiffPreceptorHours = 0.00, --sum(CASE WHEN THD.DeptNo IN(2,4,8) AND THD.ShiftDiffClass NOT IN(' ', '0') THEN THD.hours ELSE 0 END),
	NormalHours = sum(CASE WHEN THD.ShiftDiffClass IN(' ', '0') AND 
                              --THD.DeptNo NOT IN(2,4,8) AND
                              THD.ClockAdjustmentNo <> 'F'  --Only want Dollars for this code(GTS On CALL - 135).
                         THEN THD.hours ELSE 0 END),
	-- If adjustment flagged with 'pay1', use alternate pay rate
	PayRate = CASE WHEN AdjCd.ADP_EarningsCode = 'pay1' and EN.AltPayRate1 > 0.00
                 THEN EN.altPayRate1
                 ELSE EN.PayRate END, -->>>>>
	ShiftDiffPct = ( CASE WHEN THD.ShiftDiffClass IN(' ', '0') THEN 0 
						ELSE (SELECT TOP 1 SDC.ShiftDiffPct FROM TimeCurrent..tblShiftDiffClasses AS SDC
							  WHERE SDC.Client = THD.Client
							    AND SDC.GroupCode IN(0, THD.GroupCode)
							    AND SDC.SiteNo IN(0, THD.SiteNo)

							    AND SDC.ShiftDiffClass = EN.ShiftDiffClass
							    AND SDC.RecordStatus = '1'
							  ORDER BY SDC.SiteNo DESC, SDC.GroupCode DESC) END ) / 100.00,
	ShiftDiffDollars = 0,
	PreceptorDollars = 0,
	ShiftDiffPreceptorDollars = 0,
	NormalDollars = 0,
  DollarAdjs = sum(CASE WHEN THD.ClockAdjustmentNo = 'F'  --Only want Dollars for this code(GTS On CALL - 135).
                        THEN (THD.Hours * EN.PayRate) 
                        ELSE THD.Dollars END),
  DavitaFlag = ' '
FROM tblTimeHistDetail AS THD
LEFT JOIN TimeCurrent..tblAdjCodes AS AdjCd ON THD.Client = AdjCd.Client
										   AND THD.GroupCode = AdjCd.GroupCode
										   AND THD.ClockAdjustmentNo = AdjCd.ClockAdjustmentNo
LEFT JOIN TimeCurrent..tblEmplNames AS EN ON THD.Client = EN.Client
										 AND THD.GroupCode = EN.GroupCode
										 AND THD.SSN = EN.SSN
WHERE THD.Client = @Client
  AND THD.GroupCode = @GroupCode
  AND THD.PayrollPeriodEndDate = @WeekEndDate 
  --Ignore missing punches, they can throw off the site count
  AND (THD.InDay <10 OR THD.InDay >10)
  AND (THD.OutDay <10 OR THD.OutDay >10)
  and NOT(aprvlstatus = '2' and AprvlAdjOrigClkAdjNo = 'D')
  --Ignore adjustments that are not subject to overtime(exception is GTS ON CALL)
  AND (AdjCd.CountOTPay IS NULL OR AdjCd.CountOTPay = 'Y'  OR THD.ClockAdjustmentNo = 'F')
GROUP BY THD.Client, THD.GroupCode, THD.SiteNo, THD.SSN, THD.PayrollPeriodEndDate, THD.ShiftDiffClass, EN.PayRate, EN.AltPayRate1, EN.ShiftDiffClass, AdjCd.ADP_EarningsCode, THD.SiteNo

insert into #AverageRateWork(Client,GroupCode,SiteNo,SSN,PayrollPeriodEndDate,ShiftDiffHours,PreceptorHours,ShiftDiffPreceptorHours,NormalHours,PayRate,ShiftDiffPct,ShiftDiffDollars,PreceptorDollars,ShiftDiffPreceptorDollars,NormalDollars,DollarAdjs,DavitaFlag )
SELECT THD.Client, 
	THD.GroupCode, 
	THD.SiteNo,
	THD.SSN, 
	THD.PayrollPeriodEndDate,
	ShiftDiffHours = sum(CASE WHEN THD.ShiftNo IN(0,1,5) THEN 0 ELSE THD.hours END),
	PreceptorHours = 0.00,
	ShiftDiffPreceptorHours = 0.00,
	NormalHours = sum(CASE WHEN THD.ShiftNo IN(0,1,5)
                         THEN THD.hours ELSE 0 END),
	-- If adjustment flagged with 'pay1', use alternate pay rate
	PayRate = CASE WHEN AdjCd.Worked = 'N' and EN.AltPayRate1 > 0.00
                 THEN EN.altPayRate1
                 ELSE EN.PayRate END,
	ShiftDiffPct = CASE WHEN THD.ShiftNo IN(0,1,5) THEN 0.00
						ELSE (Select Top 1 ShiftDiffPct from timecurrent..tblDavitaUploadCodes_Parallel where siteno in(0, thd.siteno) and groupcode in(0, thd.AprvlStatus_UserID) and shiftno = thd.ShiftNo order by groupcode desc, siteno desc ) END,
	ShiftDiffDollars = 0.00,
	PreceptorDollars = 0.00,
	ShiftDiffPreceptorDollars = 0.00,
	NormalDollars = 0.00,
  DollarAdjs = sum(THD.Dollars),
  DavitaFlag = 'D'
FROM tblTimeHistDetail AS THD
LEFT JOIN TimeCurrent..tblAdjCodes AS AdjCd 
  ON  AdjCd.Client = @DaviClient
  AND THD.AprvlStatus_UserID = AdjCd.GroupCode
	AND THD.ClockAdjustmentNo = AdjCd.ClockAdjustmentNo
LEFT JOIN TimeCurrent..tblEmplNames AS EN 
  ON  THD.Client = EN.Client
	AND THD.GroupCode = EN.GroupCode
	AND THD.SSN = EN.SSN
WHERE THD.Client = @Client
  AND THD.GroupCode = @GroupCode
  AND THD.PayrollPeriodEndDate = @WeekEndDate 
  --Ignore missing punches, they can throw off the site count
  AND (THD.InDay <10 OR THD.InDay >10)
  AND (THD.OutDay <10 OR THD.OutDay >10)
  and (aprvlstatus = '2' and AprvlAdjOrigClkAdjNo = 'D')
  AND (AdjCd.CountOTPay IS NULL OR AdjCd.CountOTPay = 'Y')
GROUP BY THD.Client, THD.GroupCode, THD.SiteNo, THD.SSN, THD.PayrollPeriodEndDate, THD.AprvlStatus_UserID, THD.ShiftNo, EN.PayRate, EN.AltPayRate1, AdjCd.Worked, THD.SiteNo

--Update Average Rate work table with extended dollars
UPDATE #AverageRateWork SET 
	NormalDollars = (NormalHours * Payrate),
	PreceptorDollars = 0.00,
	ShiftDiffDollars = CASE WHEN (ShiftDiffPct is NULL or ShiftDiffPct = 0.00) and ShiftDiffHours <> 0  
                          THEN (ShiftDiffHours * PayRate) 
                          ELSE (CASE WHEN ShiftDiffHours = 0 
                                     THEN 0.00
                        					   ELSE ShiftDiffHours * ((ShiftDiffPct + 1) * Payrate) 
                                END)
                     END,
	ShiftDiffPreceptorDollars = 0.00

delete from #averageRateWork where PayRate is NULL

--Create Average Rate Table by employee and week
--Also include a count of the number of sites.  This will be used to determine whether 
--to use Allocated hours (Multi site) or actual hours (single site).
SELECT Client, 
	GroupCode, 
	SSN, 
	PayrollPeriodEndDate,
	AverageRate = CASE WHEN sum(NormalHours + ShiftDiffHours + PreceptorHours + ShiftDiffPreceptorHours) = 0 THEN 0
				  ELSE sum(DollarAdjs + NormalDollars + ShiftDiffDollars + PreceptorDollars + ShiftDiffPreceptorDollars) / sum(NormalHours + ShiftDiffHours + PreceptorHours + ShiftDiffPreceptorHours) END,
	SiteCount = COUNT(DISTINCT SiteNo),
	ShiftDiffHours = sum(ShiftDiffHours),
	PreceptorHours = sum(PreceptorHours), 
	ShiftDiffPreceptorHours = sum(ShiftDiffPreceptorHours),
  DollarAdjs = Sum(DollarAdjs) 
INTO #AverageRates
FROM #AverageRateWork
GROUP BY Client, GroupCode, SSN, PayrollPeriodEndDate

---------------------------------------------------------------------------------------------------
-- Select tblTimeHistDetail data for specified week
---------------------------------------------------------------------------------------------------
--Print 'Step 4'
SELECT THD.Client, THD.GroupCode, THD.SSN, THD.SiteNo, THD.DeptNo, THD.TransDate, THD.Holiday,
	   -- If adjustment flagged with 'pay1', use alternate pay rate
	   PayRate = CASE WHEN AdjCd.ADP_EarningsCode = 'pay1' and EN.AltPayRate1 > 0.00 THEN convert(numeric(7,4), EN.AltPayRate1) 
					  ELSE convert(numeric(7,4), EN.PayRate) END, -->>>>>
	   --If no Shift Diff hours, use Pay Rate as Avg
	   CASE WHEN #AverageRates.ShiftDiffHours = 0 AND #AverageRates.PreceptorHours = 0 AND #AverageRates.DollarAdjs = 0 
			THEN (CASE WHEN AdjCd.ADP_EarningsCode = 'pay1' and EN.AltPayRate1 > 0.00 THEN EN.altPayRate1 ELSE EN.PayRate END) -->>>>>
			ELSE #AverageRates.AverageRate END AS AvgPayRate,
	   --ShiftDiffClass in detail record is forced to a 1 or 2, by the clock, simply indicating
	   --that the line is subject to shift diff.  The actual ShiftDiffClass code should then be
	   --retrieved from the employee master table.
	   ShiftDiffClass = CASE WHEN THD.ShiftDiffClass IN(' ', '0') THEN '0'
							 ELSE EN.ShiftDiffClass END, 
	   --Treat breaks (Clk Adj 8) as not an adjustment
	   CASE WHEN THD.ClockAdjustmentNo IS NULL OR THD.ClockAdjustmentNo IN('',' ','1','8') THEN '' ELSE THD.ClockAdjustmentNo END AS ClockAdjustmentNo,
	   CASE WHEN THD.ClockAdjustmentNo = '8' THEN '1' ELSE '0' END AS BreakAdj,
	   --If Single Site for employee in a given week, use unallocated hours.  If multi site, use allocated hours
	   --CASE WHEN #AverageRates.SiteCount = 1 or @Client in('GTS') or @GroupCode in(405000) THEN THD.RegHours ELSE THD.AllocatedRegHours END AS RegHours, 
	   --CASE WHEN #AverageRates.SiteCount = 1 or @Client in('GTS') or @GroupCode in(405000) THEN THD.OT_Hours ELSE THD.AllocatedOT_Hours END AS OT_Hours, 
	   --CASE WHEN #AverageRates.SiteCount = 1 or @Client in('GTS') or @GroupCode in(405000) THEN THD.DT_Hours ELSE THD.AllocatedDT_Hours END AS DT_Hours, 
     THD.RegHours,
 	   WeeklyOTHours = case when thd.Holiday = '1' then THD.OT_Hours else (THD.OT_Hours - THD.AllocatedOT_Hours) end, 
 	   DailyOTHours = case when thd.Holiday = '1' then 0.00 else THD.AllocatedOT_Hours end,  
     THD.DT_Hours,
	   Dollars, Hours, THD.PayrollPeriodEndDate, THD.InSrc
INTO #Payroll_THD
FROM tblTimeHistDetail AS THD
LEFT JOIN #AverageRates ON #AverageRates.Client = THD.Client
					   AND #AverageRates.GroupCode = THD.GroupCode
					   AND #AverageRates.SSN = THD.SSN
LEFT JOIN TimeCurrent..tblEmplNames AS EN ON EN.Client = THD.Client
					   AND EN.GroupCode = THD.GroupCode
					   AND EN.SSN = THD.SSN
LEFT JOIN TimeCurrent..tblAdjCodes AS AdjCd ON THD.Client = AdjCd.Client
										   AND THD.GroupCode = AdjCd.GroupCode
										   AND THD.ClockAdjustmentNo = AdjCd.ClockAdjustmentNo
WHERE THD.Client = @Client
  AND THD.GroupCode = @GroupCode
  AND THD.PayrollPeriodEndDate= @WeekEndDate
  and NOT(THD.aprvlstatus = '2' and THD.AprvlAdjOrigClkAdjNo = 'D')

--------------------------------------------------------------------------------------------------
-- Classify breaks as shift diff if not enough non shift diff hours to cover it
-- Always assign break to the advantage of the employee (Per George Swing 5/12/01)
--------------------------------------------------------------------------------------------------
--Print 'Step 5'
UPDATE #Payroll_THD SET ShiftDiffClass = 1
WHERE BreakAdj = '1'
  AND SSN IN(SELECT SSN FROM #Payroll_THD AS THD2
					WHERE THD2.TransDate = #Payroll_THD.TransDate
					  and BreakAdj <> '1'
					GROUP BY SSN
					HAVING THD2.SSN = #Payroll_THD.SSN
					  AND SUM(CASE WHEN THD2.ShiftDiffClass = 1 THEN 0 ELSE THD2.Hours END) < abs(#Payroll_THD.Hours))

---------------------------------------------------------------------------------------------------
-- Add in Shift Diff Adjustments for total Shift Diff Hours per employee, site & dept
---------------------------------------------------------------------------------------------------
--Print 'Step 6'

INSERT INTO #Payroll_THD
SELECT Client, GroupCode, SSN, SiteNo, DeptNo, TransDate, '0',
	   PayRate = convert(numeric(7,4), PayRate * 
							(SELECT TOP 1 ShiftDiffPct FROM TimeCurrent..tblShiftDiffClasses AS SDC
							 WHERE Client = #Payroll_THD.Client
							   AND GroupCode IN(0, #Payroll_THD.GroupCode)
							   AND SiteNo IN(0, #Payroll_THD.SiteNo)
							   AND ShiftDiffClass = #Payroll_THD.ShiftDiffClass
							   AND RecordStatus = '1'
							ORDER BY SiteNo DESC, GroupCode DESC) / 100),
	   AvgPayRate = 0,
	   ShiftDiffClass = '0', 
	   ClockAdjustmentNo = (SELECT TOP 1 CASE ShiftDiffMisc1 WHEN 1 THEN 'V' ELSE 'W' END
							FROM TimeCurrent..tblShiftDiffClasses AS SDC
							 WHERE Client = #Payroll_THD.Client
							   AND GroupCode IN(0, #Payroll_THD.GroupCode)
							   AND SiteNo IN(0, #Payroll_THD.SiteNo)
							   AND ShiftDiffClass = #Payroll_THD.ShiftDiffClass
							   AND RecordStatus = '1'
							ORDER BY SiteNo DESC, GroupCode DESC),
	   BreakAdj = '0',
	   RegHours = sum(Hours),
	   WeeklyOTHours = 0,
 	   DailyOTHours = 0,
	   DT_Hours = 0,
	   Dollars = 0,
	   Hours = sum(Hours),
	   PayrollPeriodEndDate,
	   InSrc = ''
FROM #Payroll_THD	   	   
WHERE ShiftDiffClass IS NOT NULL
  AND ShiftDiffClass NOT IN('', ' ', '0')
--  AND GroupCode NOT IN(610100, 610300, 610700, 900000)  --Exclude GTS and Corp
  AND GroupCode NOT IN(900000)  --Exclude GTS and Corp
GROUP BY Client, GroupCode, SSN, SiteNo, DeptNo, TransDate, ShiftDiffClass, PayRate, PayrollPeriodEndDate


--select * from #payroll_thd where ssn = 559956979

---------------------------------------------------------------------------------------------------
-- Add in Preceptor Adjustments for total Preceptor Hours per employee, site & dept
---------------------------------------------------------------------------------------------------
--Print 'Step 7'
/*
INSERT INTO #Payroll_THD
SELECT Client, GroupCode, SSN, SiteNo, DeptNo, TransDate, '0',
	   PayRate = convert(numeric(7,4), 2.00),
	   AvgPayRate = 0,
	   ShiftDiffClass = '0', 
	   ClockAdjustmentNo = 'Y',  -- Clock Adjustment No. for Preceptor  (Code '1T')
	   BreakAdj = '0',
	   RegHours = sum(Hours),
	   OT_Hours = 0,
	   DT_Hours = 0,
	   Dollars = 0,
	   Hours = sum(Hours),
	   PayrollPeriodEndDate,
	   InSrc = ''
FROM #Payroll_THD	   	   
WHERE DeptNo = 2 
  -- eliminate shift diff adjustments just now generated
  and ClockAdjustmentNo <> 'V'
GROUP BY Client, GroupCode, SSN, SiteNo, DeptNo, TransDate, ShiftDiffClass, PayRate, PayrollPeriodEndDate
*/

---------------------------------------------------------------------------------------------------
-- Initiate prelim summary table for Payroll upload.
-- Then populate with Regular, OT & DT summary records by calling a subordinate stored procedure
---------------------------------------------------------------------------------------------------

--Print 'Step 18'
CREATE TABLE #PayrollSum (
	[SSN] [int] NOT NULL ,
	[SiteWorkedAt] [INT] NOT NULL ,  --< @SiteWorked data type is changed from  SMALLINT to INT by Srinsoft on 24Aug2016 >--
	[DeptNo] [INT] NOT NULL ,  --< @DeptNo data type is changed from  SMALLINT to INT by Srinsoft on 24Aug2016 >--
	[PayRate] [numeric](7, 4) NULL ,
	[AvgPayRate] [float] NULL ,
	[AssignmentNo] [varchar] (12) NULL ,
	[HomeSite] [INT] NULL ,  --< HomeSite data type is changed from  SMALLINT to INT by Srinsoft on 24Aug2016 >--
	[PayType] [tinyint] NULL ,
	[PrimaryJobCode] [varchar] (20) NULL ,
	[FileNo] [varchar] (10) NULL ,
	[ClockAdjustmentNo] [char] (1) NULL ,
	[AdjustmentCode] [varchar] (3) NULL ,
	[SpecialHandling] [varchar] (5) NULL ,
	[AdjustmentType] [char] (1) NULL ,
	[UploadAsSiteNo] [int] NULL ,
	[HoursType] [varchar] (3) NULL ,
	[ShiftDiffClass] [char] (1) NULL ,
	[InSrc] [char] (1) NULL,
	[SumOfRegHours] [numeric](20, 2) NULL ,
	[SumOfWeeklyOT] [numeric](20, 2) NULL ,
	[SumOfDailyOT] [numeric](20, 2) NULL ,
	[SumOfDT_Hours] [numeric](20, 2) NULL ,
	[SumOfDollars] [numeric](20, 2) NULL ,
	[SumOfHours] [numeric](20, 2) NULL ,
	[ExceptionError] [varchar] (50) NULL ,
	[ExceptionType] [char] (1) NULL)

--Print 'Step 19'
EXEC usp_GambroWklyLbrSum_Work @Client, @GroupCode, @WeekEndDate, '1RG'		 
EXEC usp_GambroWklyLbrSum_Work @Client, @GroupCode, @WeekEndDate, '2OT'		 
EXEC usp_GambroWklyLbrSum_Work @Client, @GroupCode, @WeekEndDate, '3DT'		 
EXEC usp_GambroWklyLbrSum_Work @Client, @GroupCode, @WeekEndDate, '4OT'		 

-- Override the Weighted OT rate for Holiday Hours, They should only get 1.5 x Base Rate.
--
Update #PayrollSum Set AvgPayRate = PayRate where AdjustmentCode = '140'

---------------------------------------------------------------------------------------------------
-- Create final summary records for Payroll upload 
---------------------------------------------------------------------------------------------------
--Print 'Step 20'
SELECT  #PayrollSum.SSN, #PayrollSum.SiteWorkedAt, #PayrollSum.DeptNo, #PayrollSum.PayRate, AvgPayRate,
		#PayrollSum.AssignmentNo, #PayrollSum.HomeSite, #PayrollSum.PayType, #PayrollSum.PrimaryJobCode, #PayrollSum.FileNo, #PayrollSum.ClockAdjustmentNo,
		#PayrollSum.AdjustmentCode, 
		AdjustmentName = CASE WHEN #PayrollSum.ClockAdjustmentNo = 'S' THEN 'SALARY' WHEN #PayrollSum.ClockAdjustmentNo = '' THEN '' ELSE tblAdjCodes.AdjustmentName END,
		#PayrollSum.SpecialHandling, #PayrollSum.AdjustmentType, #PayrollSum.UploadAsSiteNo,
		#PayrollSum.InSrc,
		sum(SumOfRegHours) AS SumOfRegHours,
		sum(SumOfWeeklyOT) AS SumOfWeeklyOT,
		sum(SumOfDailyOT) AS SumOfDailyOT,
		sum(SumOfDT_Hours) AS SumOfDT_Hours,
		sum(SumOfDollars) AS SumOfDollars,
		sum(SumOfHours) AS SumOfHours,
		ExceptionError,
		ExceptionType,
		tblEmplNames.AgencyNo,
		tblEmplNames.LastName,
		tblEmplNames.FirstName,
    AllocationFlag = '0',
    DualEmpl = '0'
INTO #FinalPayrollRecs 
FROM #PayrollSum
LEFT JOIN TimeCurrent..tblEmplNames AS tblEmplNames ON tblEmplNames.Client = @Client
													AND tblEmplNames.GroupCode = @GroupCode
													AND tblEmplNames.SSN = #PayrollSum.SSN
LEFT JOIN TimeCurrent..tblAdjCodes AS tblAdjCodes ON tblAdjCodes.Client = @Client
													AND tblAdjCodes.GroupCode = @GroupCode
													AND tblAdjCodes.ClockAdjustmentNo = #PayrollSum.ClockAdjustmentNo
WHERE SumOfRegHours <> 0
   OR SumOfWeeklyOT <> 0
   OR SumOfDailyOT <> 0
   OR SumOfDT_Hours <> 0
   OR SumOfDollars <> 0
   OR SumOfHours <> 0
   OR ExceptionError <> ''
GROUP BY #PayrollSum.SSN, #PayrollSum.SiteWorkedAt, #PayrollSum.DeptNo, #PayrollSum.PayRate, #PayrollSum.AvgPayRate, #PayrollSum.ShiftDiffClass,
		 #PayrollSum.AssignmentNo, #PayrollSum.HomeSite, #PayrollSum.PayType, #PayrollSum.PrimaryJobCode, #PayrollSum.FileNo, #PayrollSum.ClockAdjustmentNo,
		 #PayrollSum.AdjustmentCode, tblAdjCodes.AdjustmentName, #PayrollSum.SpecialHandling, #PayrollSum.AdjustmentType, #PayrollSum.UploadAsSiteNo, 
		 #PayrollSum.HoursType, ExceptionError, ExceptionType, 
     tblEmplNames.AgencyNo, tblEmplNames.FirstName, tblEmplNames.LastName, #PayrollSum.InSrc
ORDER BY #PayrollSum.SiteWorkedAt, 
		 #PayrollSum.SSN, 
		 #PayrollSum.DeptNo,
		 --These case statements are simply to get the data into the same order as the old payroll system
     CASE WHEN #PayrollSum.ClockAdjustmentNo = 'S' THEN '' ELSE #PayrollSum.ClockAdjustmentNo END,
		 CASE WHEN #PayrollSum.ClockAdjustmentNo = '' THEN '' ELSE #PayrollSum.HoursType END DESC,
         #PayrollSum.HoursType,
         #PayrollSum.ShiftDiffClass,
		 #PayrollSum.AvgPayRate

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
DECLARE @SumWkOT numeric(9,2)
DECLARE @SumDayOT numeric(9,2)
DECLARE @SumDT numeric(9,2)

-- ======================================================================================
-- Build a cursor from the employees that have allocations for this client/Group
-- ======================================================================================
DECLARE csrThd CURSOR
READ_ONLY
FOR 
Select fp.SSN, round(fp.PayRate,4), round(fp.AvgPayRate,4), fp.AdjustmentCode, fp.SpecialHandling, ea.UploadCode, ea.JobCode,
SumRg = round(Sum(fp.SumofRegHours * (EA.Percentage / 100 )),2), 
SumWkOT = Round(Sum(fp.SumofWeeklyOT * (EA.Percentage / 100 )),2) , 
SumDayOT = Round(Sum(fp.SumofDailyOT * (EA.Percentage / 100 )),2) , 
SumDT = round(Sum(fp.SumOfDT_Hours * (EA.Percentage / 100 )),2)
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
group by fp.SSN, fp.PayRate, fp.AvgPayRate, fp.AdjustmentCode, fp.SpecialHandling, ea.UploadCode, ea.JobCode


OPEN csrThd


FETCH NEXT FROM csrThd INTO @tmpSSN, @PayRate, @AvgPayRate, @AdjCode, @SpecHandling, @UploadCode, @JobCode, @SumRG, @SumWkOT, @SumDayOT, @SumDT
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
          and round(AvgPayRate,4) = @AvgPayRate
          and AdjustmentCode = @AdjCode
          and SpecialHandling = @SpecHandling
          and AdjustmentType = 'H'
          and SumofDollars = 0.00

          and AllocationFlag = '0'
          and ClockAdjustmentNo not IN('2','3','4') -- Skip PTO Adjustments.


    Insert into #FinalPayRollRecs (SSN, SiteWorkedAt, DeptNo, PayRate, AvgpayRate, AssignmentNo, HomeSite, PayType, PrimaryJobCode, FileNo, ClockAdjustmentNo, AdjustmentCode, AdjustmentName, SpecialHandling, AdjustmentType, UploadAsSiteNo, SumOfRegHours, SumOfWeeklyOT, SumOfDailyOT, SumOfDT_Hours, SumOfDollars, SumOfHours, ExceptionError, ExceptionType, AgencyNo, lastName, FirstName, AllocationFlag, DualEmpl )
    (Select en.SSN, en.primarySite, en.primarydept, @payRate, @AvgPayRate, en.AssignmentNo, en.PrimarySite, en.PayType, @JobCode, substring(@UploadCode,1,4) + '0' + substring(@UploadCode,5,1), '', @AdjCode, '', @SpecHandling, 'H', 0, @SumRG, @SumWkOT, @SumDayOT, @SumDT, 0.00, (@SumRG + @SumDT + @SumDayOT + @SumWkOT), '', '', en.AgencyNo, en.LastName, en.FirstName, '1', '0'
      from timeCurrent..tblEmplNames as en
      where en.client = @Client
        and en.Groupcode = @GroupCode
        and en.SSN = @tmpSSN)


	END
	FETCH NEXT FROM csrThd INTO @tmpSSN, @PayRate, @AvgPayRate, @AdjCode, @SpecHandling, @UploadCode, @JobCode, @SumRG, @SumWkOT, @SumDayOT, @SumDT
END


CLOSE csrTHD
DEALLOCATE csrThd

Select Distinct SSN
into #tmpSSN
from TimeHistory..tblTimeHistDetail
where Client = @Client
and groupcode = @GroupCode
and isnull(AprvlStatus,'') = '2' and isnull(AprvlAdjOrigClkAdjNo,'') = 'D'
and Payrollperiodenddate = @WeekEndDate

Update #FinalPayRollRecs
  Set DualEmpl = '1'
where SSN in(Select SSN from #tmpSSN)

select * from #FinalPayRollRecs 
where 
AdjustmentCode <> '335'
Order By SiteWorkedAt, SSN, DeptNo











