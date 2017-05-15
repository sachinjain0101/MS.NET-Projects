Create PROCEDURE [dbo].[usp_GambroMthlyAccUpl]
(
  @Client varchar(4),
	@GroupCode int,
	@PPED DateTime,
  @StartDate datetime,
  @EndDate datetime,
  @PayrollFreq char(1)
)

As

SET NOCOUNT ON
set ANSI_WARNINGS OFF

--*/
/*
drop table #AverageRateWork
drop table #AverageRates
drop table #Payroll_THD
drop table #FinalPayRollRecs
drop table #PayrollSum 
drop table #tmpSSN

DECLARE @Client varchar(4)
DECLARE @GroupCode int
DECLARE @PPED DateTime
DECLARE @StartDate datetime
DECLARE @EndDate Datetime
DECLARE @PayrollFreq char(1)
DECLARE @SSN int

SELECT @Client = 'GAMB'
SELECT @GroupCode = 101000
SELECT @PPED = '11/5/2005'
SELECT @PayrollFreq = 'B'
Select @StartDate = '10/23/05'
Select @EndDate = '10/31/05'
SELECT @SSN = 136845901
--EXEC @RC = [TimeHistory].[dbo].[usp_GambroMthlyAccUpl] 'GAMB', 610300, '8/2/03', '7/20/03', '7/31/03', 'B'
--EXEC [TimeHistory].[dbo].[usp_APP_GambroMnthlyAccrualGetGroups] 'GAMB', '11/01/2003', 'B'
*/

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
  AND thd.PayrollPeriodEndDate in(@PPED, @PPED2)
  --Ignore missing punches, they can throw off the site count
  AND (THD.InDay <10 OR THD.InDay >10)
  AND (THD.OutDay <10 OR THD.OutDay >10)
  and NOT(THD.aprvlstatus = '2' and THD.AprvlAdjOrigClkAdjNo = 'D')
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
  AND thd.PayrollPeriodEndDate in(@PPED, @PPED2)
  --Ignore missing punches, they can throw off the site count
  AND (THD.InDay <10 OR THD.InDay >10)
  AND (THD.OutDay <10 OR THD.OutDay >10)
  and (THD.aprvlstatus = '2' and THD.AprvlAdjOrigClkAdjNo = 'D')
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

--return
CREATE  INDEX [IX_Rates2clim] ON [#AverageRates]([ssn], [payrollPeriodEndDate])

--TimeHistDetail
SELECT THD.Client, THD.GroupCode, THD.SSN, THD.SiteNo, THD.DeptNo, THD.TransDate, THD.Holiday,
	   -- If adjustment flagged with 'pay1', use alternate pay rate
	   PayRate = CASE WHEN AdjCd.ADP_EarningsCode = 'pay1' and EN.AltPayRate1 > 0.00 THEN convert(numeric(7,4), EN.AltPayRate1) 
					  ELSE convert(numeric(7,4), EN.PayRate) END, -->>>>>
	   --If no Shift Diff hours, use Pay Rate as Avg
	   CASE WHEN #AverageRates.ShiftDiffHours = 0 AND #AverageRates.PreceptorHours = 0 and #AverageRates.DollarAdjs = 0
			THEN (CASE WHEN AdjCd.ADP_EarningsCode = 'pay1' and EN.AltPayRate1 > 0.00 THEN EN.altPayRate1 ELSE EN.PayRate END) -->>>>>
			ELSE #AverageRates.AverageRate END AS AvgPayRate,
	   --ShiftDiffClass in detail record is forced to a 1 or 2, by the clock, simply indicating
	   --that the line is subject to shift diff.  The actual ShiftDiffClass code should then be
	   --retrieved from the employee master table.
	   ShiftDiffClass = CASE WHEN THD.ShiftDiffClass IN(' ', '0') THEN '0'
							 ELSE EN.ShiftDiffClass END, 
	   --Treat breaks (Clk Adj 8) as not an adjustment
     ClockAdjustmentNo = 
    	   CASE WHEN THD.ClockAdjustmentNo IS NULL OR THD.ClockAdjustmentNo IN('',' ','1','8') THEN '' 
           		WHEN THD.ClockAdjustmentNo IN ('3','4','9','A','B','C','D') THEN '2'
              ELSE THD.ClockAdjustmentNo END,
	   CASE WHEN THD.ClockAdjustmentNo = '8' and THD.InSrc in('8','3') THEN '1' ELSE '0' END AS BreakAdj,
	   --If Single Site for employee in a given week, use unallocated hours.  If multi site, use allocated hours
	   --If GTS or Calif Acutes(4050), always use unallocated hours
	   --CASE WHEN #AverageRates.SiteCount = 1 or @Client in('GTS') or @GroupCode in(405000) THEN THD.RegHours ELSE THD.AllocatedRegHours END AS RegHours, 
	   --CASE WHEN #AverageRates.SiteCount = 1 or @Client in('GTS') or @GroupCode in(405000) THEN THD.OT_Hours ELSE THD.AllocatedOT_Hours END AS OT_Hours, 
	   --CASE WHEN #AverageRates.SiteCount = 1 or @Client in('GTS') or @GroupCode in(405000) THEN THD.DT_Hours ELSE THD.AllocatedDT_Hours END AS DT_Hours, 
     THD.RegHours,
 	   WeeklyOTHours = case when thd.Holiday = '1' then THD.OT_Hours else (THD.OT_Hours - THD.AllocatedOT_Hours) end, 
 	   DailyOTHours = case when thd.Holiday = '1' then 0.00 else THD.AllocatedOT_Hours end,  
     THD.DT_Hours,
	   Dollars, Hours, THD.PayrollPeriodEndDate,
     NonShiftDiffHours = cast(0.00 as numeric(9,2)), 
     ShiftDiffHours = cast(0.00 as numeric(9,2)),
     MissingPunch = case when Inday = 10 or OutDay = 10 then '1' else '0' end,
     DualEmpl = '0' 
INTO #Payroll_THD
FROM tblTimeHistDetail AS THD
LEFT JOIN #AverageRates ON #AverageRates.Client = THD.Client
					   AND #AverageRates.GroupCode = THD.GroupCode
					   AND #AverageRates.SSN = THD.SSN
					   AND #AverageRates.PayrollPeriodEndDate = THD.PayrollPeriodEndDate
LEFT JOIN TimeCurrent..tblEmplNames AS EN ON EN.Client = THD.Client
					   AND EN.GroupCode = THD.GroupCode
					   AND EN.SSN = THD.SSN
LEFT JOIN TimeCurrent..tblAdjCodes AS AdjCd ON THD.Client = AdjCd.Client
										   AND THD.GroupCode = AdjCd.GroupCode
										   AND THD.ClockAdjustmentNo = AdjCd.ClockAdjustmentNo
Left JOIN TimeCurrent..tblSiteNames AS SN ON SN.Client = THD.Client
					   AND SN.GroupCode = THD.GroupCode
					   AND SN.SiteNo = THD.SiteNo
WHERE THD.Client = @Client
  AND THD.GroupCode = @GroupCode
  AND THD.PayrollPeriodEndDate In(@PPED, @PPED2)
  and THD.TransDate >= @StartDate
  and THD.TransDate <= @EndDate
  AND NOT(THD.aprvlstatus = '2' and THD.AprvlAdjOrigClkAdjNo = 'D')
  AND (SN.IncludeInUpload = '1' or SN.IncludeInUpload is NULL)


--select * from #Payroll_THD where ssn = 573863363 and payrollperiodenddate = '8/24/02' order by TransDate
--select * from #Payroll_THD where ssn = 564179707 and payrollperiodenddate = '8/24/02' order by TransDate

--return
CREATE  INDEX [IX_1clim] ON [#Payroll_THD]([DeptNo], [ClockAdjustmentNo])
CREATE  INDEX [IX_2clim] ON [#Payroll_THD]([ShiftDiffClass])
CREATE  INDEX [IX_3clim] ON [#Payroll_THD]([BreakAdj], [SSN])
CREATE  INDEX [IX_4clim] ON [#Payroll_THD]([TransDate], [BreakAdj])
CREATE  INDEX [IX_6clim] ON [#Payroll_THD]([DT_Hours])

------------------------------------------------------------------------------------------------
---  Update the dual empls.
---
------------------------------------------------------------------------------------------------
Select Distinct PPED = PayrollPeriodenddate, SSN
into #tmpSSN
from TimeHistory..tblTimeHistDetail
where Client = @Client
and groupcode = @GroupCode
and isnull(AprvlStatus,'') = '2' and isnull(AprvlAdjOrigClkAdjNo,'') = 'D'
and Payrollperiodenddate IN(@PPED, @PPED2)

Update #Payroll_THD
  Set #Payroll_THD.DualEmpl = '1'
from #Payroll_THD
Inner Join #tmpSSN
ON #Payroll_THD.SSN = #tmpSSN.SSN
AND #Payroll_THD.PayrollPeriodEndDate = #tmpSSN.PPED


--------------------------------------------------------------------------------------------------
-- Determine the number of shift diff and non-shift diff hours 
-- that could be associated with each break
-- We need this to determine if the break should be classified as shift diff or not.
--------------------------------------------------------------------------------------------------
update #Payroll_Thd
  Set NonShiftDiffHours = isnull((Select Sum(pth.Hours) from #Payroll_THD as pth where pth.SSN = #payroll_thd.SSN and ShiftDiffClass in ('',' ','0') and pth.TransDate = #payroll_thd.TransDate),0),
     ShiftDiffHours = isnull((Select Sum(pth.Hours) from #Payroll_THD as pth where pth.SSN = #payroll_thd.SSN and ShiftDiffClass  not in ('',' ','0') and pth.TransDate = #payroll_thd.TransDate),0)
where BreakAdj = '1'

--------------------------------------------------------------------------------------------------
-- Classify breaks as shift diff if not enough non shift diff hours to cover it
-- Always assign break to the advantage of the employee (Per George Swing 5/12/01)

-- The reason we check both shift diff hours and non-shift diff is because there could be a break
-- adjustment entered(by the end user) with no other hours to offset against (shift diff or non-shift diff )
-- Refer to Empl - 410023032 for the 1/15/03 pay roll. CAR 2966

--------------------------------------------------------------------------------------------------
UPDATE #Payroll_THD 
  SET ShiftDiffClass = 1
WHERE BreakAdj = '1'
  and (NonShiftDiffHours - Hours) < 0       -- There are no positive Non-Shift Hours to cover the break
  and (ShiftDiffHours - Hours) > 0          -- There are positive Shift Diff Hours to cover the break
  
---------------------------------------------------------------------------------------------------
-- Add in Shift Diff Adjustments for total Shift Diff Hours per employee, site & dept
---------------------------------------------------------------------------------------------------

INSERT INTO #Payroll_THD
SELECT Client, GroupCode, SSN, SiteNo, DeptNo, TransDate, '0',
	   PayRate = convert(numeric(7,4), PayRate * 
							isnull(((SELECT TOP 1 ShiftDiffPct FROM TimeCurrent..tblShiftDiffClasses AS SDC
							 WHERE Client = #Payroll_THD.Client
							   AND GroupCode IN(0, #Payroll_THD.GroupCode)
							   AND SiteNo IN(0, #Payroll_THD.SiteNo)
							   AND ShiftDiffClass = #Payroll_THD.ShiftDiffClass
							   AND RecordStatus = '1'
							ORDER BY SiteNo DESC, GroupCode DESC) / 100),0) ),
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
	   PayrollPeriodEndDate,0,0,'0',DualEmpl
FROM #Payroll_THD	   	   
WHERE ShiftDiffClass IS NOT NULL
  AND ShiftDiffClass NOT IN('', ' ', '0')
--  AND GroupCode NOT IN(610100, 610300, 610700, 900000)  --Exclude GTS and Corp
  AND GroupCode NOT IN(900000)  --Exclude GTS
GROUP BY Client, GroupCode, SSN, SiteNo, DeptNo, TransDate, ShiftDiffClass, PayRate, PayrollPeriodEndDate, DualEmpl

---------------------------------------------------------------------------------------------------
-- Remove any shift diff where the rate is 0.00, because they are not valid.
-- 
---------------------------------------------------------------------------------------------------
delete from #payroll_Thd where PayRate = 0.00 and ClockAdjustmentNo in('V','W')

---------------------------------------------------------------------------------------------------
-- Generate Salary records based on the percentage set up for the monthly accrual
-- 
---------------------------------------------------------------------------------------------------

SELECT @SalAccrualPercent = (Select cast(XrefValue as numeric(9,6))
                              from timecurrent..tblClientXref 
                              where Client = 'GAMB'
                                and XrefID = @AccrualID
                                and XrefType = 10) / 100

/*
select * from tblTimeHistDetail where client = 'GAMB'
and groupcode = 610300
and payrollperiodenddate in('7/26/03','8/2/03')
and ssn in(241496760,401841913)
order by ssn, payrollperiodenddate
*/

if @SalAccrualPercent > 0.00
BEGIN
-----------------------------------------------------------------------------------
-- Remove any existing 'S' salary records for Client / Group for the partial week.
-----------------------------------------------------------------------------------
  DELETE from #Payroll_THD
  WHERE Client = @Client
    AND GroupCode = @GroupCode
    AND PayrollPeriodEndDate = @PPED
    AND ClockAdjustmentNo = 'S'  

	INSERT INTO #payroll_THD
  SELECT Client, GroupCode, SSN, PrimarySite, PrimaryDept, @EndDate, '0',PayRate,
	   AvgPayRate = 0,
	   ShiftDiffClass = '0', 
	   ClockAdjustmentNo = 'S',
	   BreakAdj = '0',
	   RegHours = Round(isnull(BaseHours,0) * @SalAccrualPercent, 2),
	   WeeklyOTHours = 0,
	   DailyOTHours = 0,
	   DT_Hours = 0,
	   Dollars = 0,
	   Hours = Round(isnull(BaseHours,0) * @SalAccrualPercent, 2),

	   @PPED,0,0,'0','0'
	FROM TimeCurrent..tblEmplNames
	WHERE Client = @Client
	  AND GroupCode = @GroupCode
	  AND PayType = '1'
	  AND RecordStatus = '1'
	  AND Status <> '9'
	  AND PrimarySite <> 0
	  AND PrimaryDept <> 0

-- 3. Deduct any non "S" hours from 'S' salary records
-- 
-----------------------------------------------------------------------------------

  UPDATE #payroll_THD
  SET Hours = Hours - (SELECT isnull(sum(Hours),0)
  					 FROM #Payroll_THD AS THD
  					 WHERE THD.Client = @Client
  					   AND THD.GroupCode = @GroupCode
  					   AND THD.SSN = #Payroll_THD.SSN
    				   AND ClockAdjustmentNo <> 'S' and THD.PayrollPeriodEndDate = @PPED),

  RegHours = RegHours - (SELECT isnull(sum(Hours),0)
  					 FROM #Payroll_THD AS THD
  					 WHERE THD.Client = @Client
  					   AND THD.GroupCode = @GroupCode
  					   AND THD.SSN = #Payroll_THD.SSN
    				   AND ClockAdjustmentNo <> 'S' and THD.PayrollPeriodEndDate = @PPED)
  WHERE Client = @Client
    AND GroupCode = @GroupCode
    AND ClockAdjustmentNo = 'S'  
    and Payrollperiodenddate = @PPED


  -- 4. Remove any negative 'S' salary records for Client / Group
  ------------------------------------------------------------
  DELETE #Payroll_THD
  WHERE Client = @Client
    AND GroupCode = @GroupCode
    AND ClockAdjustmentNo = 'S'  
    AND Hours <= 0

END

---------------------------------------------------------------------------------------------------
-- Initiate prelim summary table for Payroll upload.
-- Then populate with Regular, OT & DT summary records by calling a subordinate stored procedure
---------------------------------------------------------------------------------------------------

CREATE TABLE #PayrollSum (
	[SSN] [int] NOT NULL ,
	[SiteWorkedAt] [INT] NOT NULL ,  --< SiteWorkedAt data type is changed from  SMALLINT to INT by Srinsoft on 24Aug2016 >--
	[DeptNo] [INT] NOT NULL ,  --< @DeptNo data type is changed from  SMALLINT to INT by Srinsoft on 24Aug2016 >--
	[PayRate] [numeric](7, 4) NULL ,
	[AvgPayRate] [float] NULL ,
	[AssignmentNo] [varchar] (12) NULL ,
	[HomeSite] [INT] NULL ,  --< HomeSite data type is changed from  SMALLINT to INT by Srinsoft on 24Aug2016 >--
	[PayType] [tinyint] NULL ,
	[PrimaryJobCode] [varchar] (20) NULL ,
	[FileNo] [varchar] (10) NULL ,
	[ClockAdjustmentNo] [varchar] (3) NULL , --< Srinsoft 08/28/2015 Changed [ClockAdjustmentNo] [char] (1) to [varchar] (3) >--
	[AdjustmentCode] [varchar] (3) NULL ,
	[SpecialHandling] [varchar] (5) NULL ,
	[AdjustmentType] [char] (1) NULL ,
	[UploadAsSiteNo] [int] NULL ,
	[HoursType] [varchar] (3) NULL ,
	[ShiftDiffClass] [char] (1) NULL ,
	[SumOfRegHours] [numeric](20, 2) NULL ,
	[SumOfWeeklyOT] [numeric](20, 2) NULL ,
	[SumOfDailyOT] [numeric](20, 2) NULL ,
	[SumOfDT_Hours] [numeric](20, 2) NULL ,
	[SumOfDollars] [numeric](20, 2) NULL ,
	[SumOfHours] [numeric](20, 2) NULL ,
  [MissingPunch] [char] (1) NULL,
	[ExceptionError] [varchar] (50) NULL ,
	[ExceptionType] [char] (1) NULL,
  [DualEmpl] [char] (1) NULL)

EXEC usp_GambroMthlyAccSum_Work @Client, @GroupCode, @PPED, '1RG', 'PAY'
EXEC usp_GambroMthlyAccSum_Work @Client, @GroupCode, @PPED, '2OT', 'PAY'
EXEC usp_GambroMthlyAccSum_Work @Client, @GroupCode, @PPED, '3DT', 'PAY'
EXEC usp_GambroMthlyAccSum_Work @Client, @GroupCode, @PPED, '4OT', 'PAY'

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
		tblSiteNames.DivisionID,
		tblSiteNames.Client,
		tblSiteNames.VirtualSite,
    AllocationFlag = '0',
    BaseHours = cast(0.00 as numeric(7,2)),
    #PayrollSum.DualEmpl
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
   OR SumOfWeeklyOT <> 0
   OR SumOfDailyOT <> 0
   OR SumOfDT_Hours <> 0
   OR SumOfDollars <> 0
   OR SumOfHours <> 0
   OR ExceptionError <> '')
--	AND #PayrollSum.PayType = '1'
GROUP BY #PayrollSum.SSN, #PayrollSum.SiteWorkedAt, #PayrollSum.DeptNo, #PayrollSum.PayRate, #PayrollSum.AvgPayRate, #PayrollSum.ShiftDiffClass,
		 #PayrollSum.AssignmentNo, #PayrollSum.HomeSite, #PayrollSum.PayType, #PayrollSum.PrimaryJobCode, #PayrollSum.FileNo, #PayrollSum.ClockAdjustmentNo,
		 #PayrollSum.AdjustmentCode, tblAdjCodes.AdjustmentName, #PayrollSum.SpecialHandling, #PayrollSum.AdjustmentType, #PayrollSum.UploadAsSiteNo, 
		 #PayrollSum.HoursType, ExceptionError, ExceptionType, 
     tblEmplNames.AgencyNo, tblEmplNames.FirstName, tblEmplNames.LastName, tblSiteNames.DivisionID,tblSiteNames.Client,tblSiteNames.VirtualSite,
     #PayrollSum.DualEmpl


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
DECLARE @SumDT numeric(9,2)
DECLARE @DivisionID varchar(6)
DECLARE @VirtualSite char(1)
DECLARE @DualEmpl char(1)
DECLARE @SumWkOT numeric(9,2)
DECLARE @SumDayOT numeric(9,2)

-- ======================================================================================
-- Build a cursor from the employees that have allocations for this client/Group
-- ======================================================================================
DECLARE csrThd CURSOR
READ_ONLY
FOR 
Select fp.SSN, round(fp.PayRate,4), round(fp.nAvgPayRate,4), fp.AdjustmentCode, fp.SpecialHandling, ea.UploadCode, ea.JobCode,fp.DivisionID,fp.VirtualSite,fp.DualEmpl,
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
group by fp.SSN, fp.PayRate, fp.nAvgPayRate, fp.AdjustmentCode, fp.SpecialHandling, ea.UploadCode, ea.JobCode, fp.DivisionID, fp.VirtualSite, fp.DualEmpl


OPEN csrThd


FETCH NEXT FROM csrThd INTO @tmpSSN, @PayRate, @AvgPayRate, @AdjCode, @SpecHandling, @UploadCode, @JobCode, @DivisionID, @VirtualSite, @DualEmpl, @SumRG, @SumWkOT, @SumDayOT, @SumDT
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


    Insert into #FinalPayRollRecs (SSN, SiteWorkedAt, DeptNo, PayRate, nAvgpayRate, AssignmentNo, HomeSite, PayType, PrimaryJobCode, FileNo, ClockAdjustmentNo, AdjustmentCode, AdjustmentName, SpecialHandling, AdjustmentType, UploadAsSiteNo, SumOfRegHours, SumOfWeeklyOT, SumOfDailyOT, SumOfDT_Hours, SumOfDollars, SumOfHours, ExceptionError, ExceptionType, AgencyNo, lastName, FirstName, DivisionID, Client, VirtualSite, AllocationFlag,BaseHours, DualEmpl )
    (Select en.SSN, en.primarySite, en.primarydept, @payRate, @AvgPayRate, en.AssignmentNo, en.PrimarySite, en.PayType, @JobCode, substring(@UploadCode,1,4) + '0' + substring(@UploadCode,5,1), '', @AdjCode, '', @SpecHandling, 'H', 0, @SumRG, @SumWkOT, @SumDayOT, @SumDT, 0.00, (@SumRG + @SumDT + @SumWkOT + @SumDayOT), '', '', en.AgencyNo, en.LastName, en.FirstName, @DivisionID, @Client, @VirtualSite, '1', en.BaseHours, @DualEmpl
      from timeCurrent..tblEmplNames as en
      where en.client = @Client
        and en.Groupcode = @GroupCode
        and en.SSN = @tmpSSN)

	END
	FETCH NEXT FROM csrThd INTO @tmpSSN, @PayRate, @AvgPayRate, @AdjCode, @SpecHandling, @UploadCode, @JobCode, @DivisionID, @VirtualSite, @DualEmpl, @SumRG, @SumWkOT, @SumDayOT, @SumDT
END


CLOSE csrTHD
DEALLOCATE csrThd

select * from #FinalPayRollRecs 
where AssignmentNo <> ''
and AdjustmentCode <> '335' 
Order By SiteWorkedAt, SSN, DeptNo


--select sum(sumofreghours) from #FinalPayRollRecs where adjustmentcode <> 'SH2'

/*
  where ssn in(select SSN from TimeCurrent..tblWork_RecalcEmployees where Client = 'GAMB' and recalc = 'm')
  AND adjustmentCode = '101'

select * from TimeCurrent..tblWork_RecalcEmployees where Client = 'GAMB' and recalc = 'm'
drop table #AverageRateWork
drop table #AverageRates
drop table #WeekEndDates
drop table #AverageRateWork_Partial
drop table #AverageRates_Partial
drop table #Payroll_THD
drop table #PayrollSum 
drop table #FinalPayRollRecs
*/





