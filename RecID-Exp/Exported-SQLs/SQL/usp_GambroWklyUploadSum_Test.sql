USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_GambroWklyUploadSum_Test]    Script Date: 3/31/2015 11:53:38 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_GambroWklyUploadSum_Test]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_GambroWklyUploadSum_Test] AS' 
END
GO








/*
***********************************************************************************
 $Archive: /SQLServer/StoredProcs/TimeHistory/usp_APP_GenNetSalaryRecs_GAMB.PRC $
 $Author: Dale Humphries $
 $Date: 4/26/02 4:02p $
 $Modtime: 4/26/02 4:00p $
 $Workfile: usp_APP_GenNetSalaryRecs_GAMB.PRC $
 $Revision: 3 $

 OWNER      :     (C) Copyright 2002 by Cignify Corporation
 PRODUCT    :     PeopleNet
 DESCRIPTION:     

This procedure generates net salary records for client - groups that have salary generation
turned on. 

***********************************************************************************
 Copyright (c) Cignify Corporation, as an unpublished work first licensed in
 2002.  This program is a confidential, unpublished work of authorship created
 in 2002.  It is a trade secret which is the property of Cignify Corporation.

 All use, disclosure, and/or reproduction not specifically authorized by
 Cignify Corporation, is prohibited.  This program is protected by
 domestic and international copyright and/or trade secret laws.
 All rights reserved.

***********************************************************************************
                               REVISION HISTORY
$History: usp_APP_GenNetSalaryRecs_GAMB.PRC $
-- 

***********************************************************************************
*/

--/*
ALTER  Procedure [dbo].[usp_GambroWklyUploadSum_Test](
@Client varchar(4),
@GroupCode int,
@WeekEndDate DateTime,
@DataClass varchar(10))

AS
--*/
/*
drop table #AverageRateWork
drop table #AverageRates
drop table #WeekEndDates
drop table #Payroll_THD
drop table #PayrollSum 
drop table #FinalPayRollRecs

DECLARE @Client varchar(4)
DECLARE @GroupCode int
DECLARE @WeekEndDate DateTime
DECLARE @DataClass varchar(10)

SELECT @Client = 'GAMB'
SELECT @GroupCode = 914200
SELECT @WeekEndDate = '7/20/02'
SELECT @DataClass = 'PAY'
*/

SET NOCOUNT ON

DECLARE @AllocateSalaryRecs char(1)

if @groupcode <> 914200
Begin
  -- Allocate Salary hours based on tblEmplAllocations if Client/Group is turned on.
  -- Need to allocate for each week.
  --
  SELECT @AllocateSalaryRecs = (Select AllocateSalaryRecs from TimeCurrent..tblClientGroups where client = @Client and Groupcode = @Groupcode)
  if @AllocateSalaryRecs = '1'
  Begin
    EXEC usp_APP_ReAllocateSalaryHours @Client, @GroupCode, @WeekEndDate, @WeekEndDate
    if @@Error <> 0 
    begin
      RAISERROR ('Failed in Re-Allocate Salary Hours for first week', 16, 1) 
      return --@@Error
    end
  End
End  
---------------------------------------------------------------------------------------------------
--Create Average Rate table for week
---------------------------------------------------------------------------------------------------
--Create a work table by employee and week for calculating average rate.
SELECT THD.Client, 
	THD.GroupCode, 
	THD.SiteNo,
	THD.SSN, 
	ShiftDiffHours = sum(CASE WHEN THD.ShiftDiffClass IN(' ', '0') or THD.DeptNo IN(2,4,8) THEN 0 ELSE THD.hours END),
	PreceptorHours = sum(CASE WHEN THD.DeptNo IN(2,4,8) and THD.ShiftDiffClass IN(' ', '0') THEN THD.hours ELSE 0 END),
	ShiftDiffPreceptorHours = sum(CASE WHEN THD.DeptNo IN(2,4,8) AND THD.ShiftDiffClass NOT IN(' ', '0') THEN THD.hours ELSE 0 END),
	NormalHours = sum(CASE WHEN THD.ShiftDiffClass IN(' ', '0') AND THD.DeptNo NOT IN(2,4,8) THEN THD.hours ELSE 0 END),
	-- If adjustment flagged with 'pay1', use alternate pay rate
	PayRate = CASE WHEN AdjCd.ADP_EarningsCode = 'pay1' and EN.AltPayRate1 > 0.00 THEN EN.altPayRate1 ELSE EN.PayRate END, -->>>>>
	ShiftDiffPct = CASE WHEN THD.ShiftDiffClass IN(' ', '0') THEN 0 
						ELSE (SELECT TOP 1 SDC.ShiftDiffPct FROM TimeCurrent..tblShiftDiffClasses AS SDC
							  WHERE SDC.Client = THD.Client
							    AND SDC.GroupCode IN(0, THD.GroupCode)
							    AND SDC.SiteNo IN(0, THD.SiteNo)
							    AND SDC.ShiftDiffClass = EN.ShiftDiffClass
							    AND SDC.RecordStatus = '1'
							  ORDER BY SDC.SiteNo DESC, SDC.GroupCode DESC) END,
	ShiftDiffDollars = convert(float, 0),
	PreceptorDollars = convert(float, 0),
	ShiftDiffPreceptorDollars = convert(float, 0),
	NormalDollars = convert(float, 0)
INTO #AverageRateWork
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
  --Ignore adjustments that are not subject to overtime
  AND (AdjCd.CountOTPay IS NULL OR AdjCd.CountOTPay = 'Y')
GROUP BY THD.Client, THD.GroupCode, THD.SiteNo, THD.SSN, THD.ShiftDiffClass, EN.PayRate, EN.AltPayRate1, EN.ShiftDiffClass, AdjCd.ADP_EarningsCode, THD.SiteNo

--Update Average Rate work table with extended dollars
UPDATE #AverageRateWork SET 
	NormalDollars = NormalHours * Payrate,
	PreceptorDollars = PreceptorHours * (Payrate + 2.00),
	ShiftDiffDollars = CASE WHEN ShiftDiffHours = 0 THEN 0.00
					   ELSE ShiftDiffHours * (((ShiftDiffPct / 100) + 1) * Payrate) END,
	ShiftDiffPreceptorDollars = CASE WHEN ShiftDiffPreceptorHours = 0 THEN 0.00
							    ELSE ShiftDiffPreceptorHours * (((ShiftDiffPct / 100) + 1) * (Payrate + 2.00)) END

--Create Average Rate Table by employee
--Also include a count of the number of sites.  This will be used to determine whether 
--to use Allocated hours (Multi site) or actual hours (single site).
SELECT Client, 
	GroupCode, 
	SSN, 
	AverageRate = CASE WHEN sum(NormalHours + ShiftDiffHours + PreceptorHours + ShiftDiffPreceptorHours) = 0 THEN 0
				  ELSE sum(NormalDollars + ShiftDiffDollars + PreceptorDollars + ShiftDiffPreceptorDollars) / sum(NormalHours + ShiftDiffHours + PreceptorHours + ShiftDiffPreceptorHours) END,
	SiteCount = COUNT(DISTINCT SiteNo),
	ShiftDiffHours = sum(ShiftDiffHours),
	PreceptorHours = sum(PreceptorHours), 
	ShiftDiffPreceptorHours = sum(ShiftDiffPreceptorHours) 
INTO #AverageRates
FROM #AverageRateWork
GROUP BY Client, GroupCode, SSN


---------------------------------------------------------------------------------------------------
-- Select tblTimeHistDetail data for specified week
---------------------------------------------------------------------------------------------------

SELECT THD.Client, THD.GroupCode, THD.SSN, THD.SiteNo, THD.DeptNo, THD.TransDate, THD.Holiday,
	   -- If adjustment flagged with 'pay1', use alternate pay rate
	   PayRate = CASE WHEN AdjCd.ADP_EarningsCode = 'pay1' and EN.AltPayRate1 > 0.00 THEN convert(numeric(7,4), EN.AltPayRate1) 
					  ELSE convert(numeric(7,4), EN.PayRate) END, -->>>>>
	   --If no Shift Diff hours, use Pay Rate as Avg
	   CASE WHEN #AverageRates.ShiftDiffHours = 0 AND #AverageRates.PreceptorHours = 0 
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
	   CASE WHEN #AverageRates.SiteCount = 1 or @Client in('GTS') or @GroupCode in(405000) THEN THD.RegHours ELSE THD.AllocatedRegHours END AS RegHours, 
	   CASE WHEN #AverageRates.SiteCount = 1 or @Client in('GTS') or @GroupCode in(405000) THEN THD.OT_Hours ELSE THD.AllocatedOT_Hours END AS OT_Hours, 
	   CASE WHEN #AverageRates.SiteCount = 1 or @Client in('GTS') or @GroupCode in(405000) THEN THD.DT_Hours ELSE THD.AllocatedDT_Hours END AS DT_Hours, 
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

--------------------------------------------------------------------------------------------------
-- Classify breaks as shift diff if not enough non shift diff hours to cover it
-- Always assign break to the advantage of the employee (Per George Swing 5/12/01)
--------------------------------------------------------------------------------------------------
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
	   OT_Hours = 0,
	   DT_Hours = 0,
	   Dollars = 0,
	   Hours = sum(Hours),
	   PayrollPeriodEndDate,
	   InSrc = ''
FROM #Payroll_THD	   	   
WHERE ShiftDiffClass IS NOT NULL
  AND ShiftDiffClass NOT IN('', ' ', '0')
  AND GroupCode NOT IN(610100, 610300, 610700, 900000)  --Exclude GTS and Corp
GROUP BY Client, GroupCode, SSN, SiteNo, DeptNo, TransDate, ShiftDiffClass, PayRate, PayrollPeriodEndDate

--select * from #payroll_thd where ssn = 559956979

---------------------------------------------------------------------------------------------------
-- Add in Preceptor Adjustments for total Preceptor Hours per employee, site & dept
---------------------------------------------------------------------------------------------------

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
WHERE DeptNo IN(2,4,8)
  -- eliminate shift diff adjustments just now generated
  and ClockAdjustmentNo <> 'V'
GROUP BY Client, GroupCode, SSN, SiteNo, DeptNo, TransDate, ShiftDiffClass, PayRate, PayrollPeriodEndDate

---------------------------------------------------------------------------------------------------
-- If group is semi monthly, remove all recurring adjustments including "S" salary adjustments.
-- Retrieve all recurring adjustments from latest closed semi monthly payroll period and convert
-- values to a single week basis (*24/52)
-- Convert the Salary records to contain "Net" salary hours
---------------------------------------------------------------------------------------------------
If (SELECT PayrollFreq FROM TimeCurrent..tblClientGroups 
	WHERE Client = @Client
	  AND GroupCode = @GroupCode) = 'S'
	
	BEGIN
		
		-- Delete any recurring adjustments including "Salary" record
		DELETE #Payroll_THD WHERE InSrc = 'R' OR ClockAdjustmentNo = 'S'
		
		--Determine latest closed Semi Monthly Payroll for group
		DECLARE @LatestClosedMasterPayrollDate DateTime
		SELECT @LatestClosedMasterPayrollDate = (SELECT TOP 1 MasterPayrollDate FROM tblMasterPayrollDates
												 WHERE Client = @Client
												   AND GroupCode = @GroupCode
												   AND Status = 'C'
												 ORDER BY MasterPayrollDate DESC)
		
		IF @LatestClosedMasterPayrollDate IS NOT NULL
			BEGIN

				-- Append recurring adjustments from tblTimeHistDetail
				-- (Exclude Salary record since this will be generated later)
				INSERT INTO #Payroll_THD
				SELECT THD.Client, THD.GroupCode, THD.SSN, THD.SiteNo, THD.DeptNo, THD.TransDate, '0',
					   convert(numeric(7,4), EN.PayRate) AS PayRate,
					   --If no Shift Diff hours, use Pay Rate as Avg
					   EN.PayRate AS AvgPayRate,
					   THD.ShiftDiffClass, 
					   --Treat breaks (Clk Adj 8) as not an adjustment
					   CASE WHEN THD.ClockAdjustmentNo IS NULL OR THD.ClockAdjustmentNo IN('',' ','1','8') THEN '' ELSE THD.ClockAdjustmentNo END AS ClockAdjustmentNo,
					   CASE WHEN ClockAdjustmentNo = '8' THEN '1' ELSE '0' END AS BreakAdj,
					   --If Single Site for employee in a given week, use unallocated hours.  If multi site, use allocated hours
					   RegHours = (THD.Hours * 24) / 52, 
					   OT_Hours = 0, 
					   DT_Hours = 0, 
					   Dollars = (THD.Dollars * 24) / 52, 
					   Hours = (THD.Hours * 24) / 52, 
					   THD.PayrollPeriodEndDate,
					   THD.InSrc
				FROM tblTimeHistDetail AS THD
				INNER JOIN TimeCurrent..tblEmplNames AS EN ON EN.Client = THD.Client
									   AND EN.GroupCode = THD.GroupCode
									   AND EN.SSN = THD.SSN
									   AND EN.PayType = '1'	  -- Salaried
									   AND EN.Selected = '1'  -- In latest refresh
				WHERE THD.Client = @Client
				  AND THD.GroupCode = @GroupCode
				  AND THD.MasterPayrollDate= @LatestClosedMasterPayrollDate
				  AND THD.InSrc = 'R'
				  AND THD.ClockAdjustmentNo <> 'S'

				-- Append recurring adjustments from tblTimeHistDetail_Partial
				INSERT INTO #Payroll_THD
				SELECT THD.Client, THD.GroupCode, THD.SSN, THD.SiteNo, THD.DeptNo, THD.TransDate, '0',
					   convert(numeric(7,4), EN.PayRate) AS PayRate,
					   --If no Shift Diff hours, use Pay Rate as Avg
					   EN.PayRate AS AvgPayRate,
					   THD.ShiftDiffClass, 
					   --Treat breaks (Clk Adj 8) as not an adjustment
					   CASE WHEN THD.ClockAdjustmentNo IS NULL OR THD.ClockAdjustmentNo IN('',' ','1','8') THEN '' ELSE THD.ClockAdjustmentNo END AS ClockAdjustmentNo,
					   CASE WHEN ClockAdjustmentNo = '8' THEN '1' ELSE '0' END AS BreakAdj,
					   --If Single Site for employee in a given week, use unallocated hours.  If multi site, use allocated hours
					   RegHours = (THD.Hours * 24) / 52, 
					   OT_Hours = 0, 
					   DT_Hours = 0, 
					   Dollars = (THD.Dollars * 24) / 52, 
					   Hours = (THD.Hours * 24) / 52, 
					   THD.PayrollPeriodEndDate,
					   THD.InSrc
				FROM tblTimeHistDetail_Partial AS THD
				INNER JOIN TimeCurrent..tblEmplNames AS EN ON EN.Client = THD.Client
									   AND EN.GroupCode = THD.GroupCode
									   AND EN.SSN = THD.SSN
									   AND EN.PayType = '1'	  -- Salaried
									   AND EN.Selected = '1'  -- In latest refresh
				WHERE THD.Client = @Client
				  AND THD.GroupCode = @GroupCode
				  AND THD.MasterPayrollDate= @LatestClosedMasterPayrollDate
				  AND THD.InSrc = 'R'
				  AND THD.ClockAdjustmentNo <> 'S'

			END


		------------------------------------------------
		-- Generate Net Salary records
		------------------------------------------------

		DELETE #Payroll_THD WHERE ClockAdjustmentNo = 'S'

		-- Generate 'S' salary records if Primary Site is an active site
		----------------------------------------------------------------
		INSERT INTO #Payroll_THD
		SELECT EN.Client, EN.GroupCode, EN.SSN, EN.PrimarySite, 
			   DeptNo = EN.PrimaryDept, 
			   TransDate = @WeekEndDate,
         Holiday = '0',
			   PayRate = EN.PayRate,
			   AvgPayRate = EN.PayRate,
			   ShiftDiffClass = '0', 
			   ClockAdjustmentNo = 'S',  
			   BreakAdj = '0',
			   RegHours = (EN.BaseHours * 24) / 52,
			   OT_Hours = 0,
			   DT_Hours = 0,
			   Dollars = 0,
			   Hours = (EN.BaseHours * 24) / 52,
			   PayrollPeriodEndDate = @WeekEndDate,
			   InSrc = ''
		FROM TimeCurrent..tblEmplNames AS EN	   	   
		WHERE EN.Client = @Client
		  AND EN.GroupCode = @GroupCode
		  AND EN.PayType = '1'	  -- Salaried
		  AND EN.Selected = '1'  -- In latest refresh
		  AND EN.RecordStatus = '1'
		  AND EN.Status <> '9'   -- Not Terminated
		  AND EN.PrimarySite <> 0
		  AND EN.PrimarySite IN(SELECT SiteNo FROM TimeCurrent..tblSiteNames AS SN
									WHERE SN.Client = EN.Client
									  AND SN.GroupCode = EN.GroupCode
									  AND SN.SiteNo = EN.PrimarySite
									  AND SN.RecordStatus = '1')

		-- If Gambro/GTS, generate salary records where Primary Site is not an active site
		-- but can be found on active site in tblSiteNames.UploadAsSiteNo
		----------------------------------------------------------------------------------
		INSERT INTO #Payroll_THD
		SELECT EN.Client, EN.GroupCode, EN.SSN, EN.PrimarySite, 
			   DeptNo = EN.PrimaryDept, 
			   TransDate = @WeekEndDate,
         Holiday = '0',
			   PayRate = EN.PayRate,
			   AvgPayRate = EN.PayRate,
			   ShiftDiffClass = '0', 
			   ClockAdjustmentNo = 'S',  
			   BreakAdj = '0',
			   RegHours = (EN.BaseHours * 24) / 52,
			   OT_Hours = 0,
			   DT_Hours = 0,
			   Dollars = 0,
			   Hours = (EN.BaseHours * 24) / 52,
			   PayrollPeriodEndDate = @WeekEndDate,
			   InSrc = ''
		FROM TimeCurrent..tblEmplNames AS EN	   	   
		WHERE EN.Client = @Client
		  AND EN.GroupCode = @GroupCode
		  AND EN.PayType = '1'	  -- Salaried
		  AND EN.Selected = '1'  -- In latest refresh
		  AND EN.RecordStatus = '1'
		  AND EN.Status <> '9'   -- Not Terminated
		  AND EN.PrimarySite <> 0
		  AND EN.PrimarySite NOT IN(SELECT SiteNo FROM TimeCurrent..tblSiteNames AS SN
									WHERE SN.Client = EN.Client
									  AND SN.GroupCode = EN.GroupCode
								      AND SN.SiteNo = EN.PrimarySite
								      AND SN.RecordStatus = '1')
		  AND EN.PrimarySite IN(SELECT SN.UploadAsSiteNo FROM TimeCurrent..tblSiteNames AS SN
								WHERE SN.Client = EN.Client
								  AND SN.GroupCode = EN.GroupCode
			                      AND SN.UploadAsSiteNo = EN.PrimarySite
								  AND SN.RecordStatus = '1')

		-- Deduct any non "S" hours from 'S' salary records
		-- Note: Pull non "S" hours from both tblTimeHistDetail & tblTimeHistDetail_Partial
		-----------------------------------------------------------------------------------
		UPDATE #Payroll_THD
		SET RegHours = RegHours - (SELECT CASE WHEN sum(Hours) IS NULL THEN 0 ELSE sum(Hours) END 
								   FROM #Payroll_THD AS THD
								   WHERE THD.SSN = #Payroll_THD.SSN
									 AND ClockAdjustmentNo <> 'S'),
			Hours = Hours - (SELECT CASE WHEN sum(Hours) IS NULL THEN 0 ELSE sum(Hours) END 
							 FROM #Payroll_THD AS THD
							 WHERE THD.SSN = #Payroll_THD.SSN
							   AND ClockAdjustmentNo <> 'S')
		WHERE ClockAdjustmentNo = 'S'  

		-- If any negative "Salaried" records: 
		--		- Remove all other distribution records for the employee
		--      - Reset to full salary
		---------------------------------------------------------------------------------------------------
		DELETE #Payroll_THD
		WHERE SSN IN(SELECT SSN FROM #Payroll_THD
					 WHERE ClockAdjustmentNo = 'S' and Hours < 0)
		  AND ClockAdjustmentNo <> 'S'

		UPDATE #Payroll_THD SET RegHours = (SELECT (BaseHours * 24) / 52
											FROM TimeCurrent..tblEmplNames 
											WHERE Client = #Payroll_THD.Client
											  AND GroupCode = #Payroll_THD.GroupCode
											  AND SSN = #Payroll_THD.SSN),
								OT_Hours = 0, DT_Hours = 0, 
								Hours = (SELECT (BaseHours * 24) / 52
										 FROM TimeCurrent..tblEmplNames 
										 WHERE Client = #Payroll_THD.Client
										   AND GroupCode = #Payroll_THD.GroupCode
										   AND SSN = #Payroll_THD.SSN)
		WHERE ClockAdjustmentNo = 'S' and Hours < 0

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
	[ClockAdjustmentNo] [varchar] (3) NULL , --< Srinsoft 08/28/2015 Changed [ClockAdjustmentNo] [char] (1) to varchar(3) >--
	[AdjustmentCode] [varchar] (3) NULL ,
	[SpecialHandling] [varchar] (5) NULL ,
	[AdjustmentType] [char] (1) NULL ,
	[UploadAsSiteNo] [int] NULL ,
	[HoursType] [varchar] (3) NULL ,
	[ShiftDiffClass] [char] (1) NULL ,
	[InSrc] [char] (1) NULL,
	[SumOfRegHours] [numeric](20, 2) NULL ,
	[SumOfOT_Hours] [numeric](20, 2) NULL ,
	[SumOfDT_Hours] [numeric](20, 2) NULL ,
	[SumOfDollars] [numeric](20, 2) NULL ,
	[SumOfHours] [numeric](20, 2) NULL ,
	[ExceptionError] [varchar] (50) NULL ,
	[ExceptionType] [char] (1) NULL)

EXEC usp_GambroWklyUploadSum_Work @Client, @GroupCode, @WeekEndDate, '1RG', @DataClass		 
EXEC usp_GambroWklyUploadSum_Work @Client, @GroupCode, @WeekEndDate, '2OT', @DataClass		 
EXEC usp_GambroWklyUploadSum_Work @Client, @GroupCode, @WeekEndDate, '3DT', @DataClass		 

-- Override the Weighted OT rate for Holiday Hours, They should only get 1.5 x Base Rate.
--
Update #PayrollSum Set AvgPayRate = PayRate where AdjustmentCode = '140'


SELECT  #PayrollSum.SSN, #PayrollSum.SiteWorkedAt, #PayrollSum.DeptNo, #PayrollSum.PayRate, AvgPayRate,
		#PayrollSum.AssignmentNo, #PayrollSum.HomeSite, #PayrollSum.PayType, #PayrollSum.PrimaryJobCode, #PayrollSum.FileNo, 
		#PayrollSum.ClockAdjustmentNo, #PayrollSum.AdjustmentCode, 
		AdjustmentName = CASE WHEN #PayrollSum.ClockAdjustmentNo = 'S' THEN 'SALARY' WHEN #PayrollSum.ClockAdjustmentNo = '' THEN '' ELSE tblAdjCodes.AdjustmentName END,
		#PayrollSum.SpecialHandling, #PayrollSum.AdjustmentType, #PayrollSum.UploadAsSiteNo,
		#PayrollSum.InSrc,
		sum(SumOfRegHours) AS SumOfRegHours,
		sum(SumOfOT_Hours) AS SumOfOT_Hours,
		sum(SumOfDT_Hours) AS SumOfDT_Hours,
		sum(SumOfDollars) AS SumOfDollars,
		sum(SumOfHours) AS SumOfHours,
		ExceptionError,
		ExceptionType,
    tblEmplNames.AgencyNo,
		tblEmplNames.LastName + ' ' + tblEmplNames.FirstName AS EmplName,
    AllocationFlag = '0'
into #FinalPayRollRecs
FROM #PayrollSum
LEFT JOIN TimeCurrent..tblEmplNames AS tblEmplNames ON tblEmplNames.Client = @Client
													AND tblEmplNames.GroupCode = @GroupCode
													AND tblEmplNames.SSN = #PayrollSum.SSN
LEFT JOIN TimeCurrent..tblAdjCodes AS tblAdjCodes ON tblAdjCodes.Client = @Client
													AND tblAdjCodes.GroupCode = @GroupCode
													AND tblAdjCodes.ClockAdjustmentNo = #PayrollSum.ClockAdjustmentNo
WHERE SumOfRegHours <> 0
   OR SumOfOT_Hours <> 0
   OR SumOfDT_Hours <> 0
   OR SumOfDollars <> 0
   OR SumOfHours <> 0
   OR ExceptionError <> ''
GROUP BY #PayrollSum.SSN, #PayrollSum.SiteWorkedAt, #PayrollSum.DeptNo, #PayrollSum.PayRate, #PayrollSum.AvgPayRate, #PayrollSum.ShiftDiffClass,
		 #PayrollSum.AssignmentNo, #PayrollSum.HomeSite, #PayrollSum.PayType, #PayrollSum.PrimaryJobCode, #PayrollSum.FileNo, #PayrollSum.ClockAdjustmentNo,
		 #PayrollSum.AdjustmentCode, tblAdjCodes.AdjustmentName, #PayrollSum.SpecialHandling, #PayrollSum.AdjustmentType, #PayrollSum.UploadAsSiteNo, 
		 #PayrollSum.HoursType, ExceptionError, ExceptionType, tblEmplNames.AgencyNo, tblEmplNames.FirstName, tblEmplNames.LastName, #PayrollSum.InSrc
ORDER BY #PayrollSum.SiteWorkedAt, 
		 #PayrollSum.SSN, 
		 #PayrollSum.DeptNo,
		 --These case statements are simply to get the data into the same order as the old payroll system
         CASE WHEN #PayrollSum.ClockAdjustmentNo = 'S' THEN '' ELSE #PayrollSum.ClockAdjustmentNo END,
		 CASE WHEN #PayrollSum.ClockAdjustmentNo = '' THEN '' ELSE #PayrollSum.HoursType END DESC,
         #PayrollSum.HoursType,
         #PayrollSum.ShiftDiffClass,
		 #PayrollSum.AvgPayRate






--Only do the allocation for 610100 for testing.
if @GroupCode = 914200
BEGIN
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

-- ======================================================================================
-- Build a cursor from the employees that have allocations for this client/Group
-- ======================================================================================
DECLARE csrThd CURSOR
READ_ONLY
FOR 
Select fp.SSN, round(fp.PayRate,4), round(fp.AvgPayRate,4), fp.AdjustmentCode, fp.SpecialHandling, ea.UploadCode, ea.JobCode,
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
group by fp.SSN, fp.PayRate, fp.AvgPayRate, fp.AdjustmentCode, fp.SpecialHandling, ea.UploadCode, ea.JobCode


OPEN csrThd


FETCH NEXT FROM csrThd INTO @tmpSSN, @PayRate, @AvgPayRate, @AdjCode, @SpecHandling, @UploadCode, @JobCode, @SumRG, @SumOT, @SumDT
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


    Insert into #FinalPayRollRecs (SSN, SiteWorkedAt, DeptNo, PayRate, AvgpayRate, AssignmentNo, HomeSite, PayType, PrimaryJobCode, FileNo, ClockAdjustmentNo, AdjustmentCode, AdjustmentName, SpecialHandling, AdjustmentType, UploadAsSiteNo, SumOfRegHours, SumOfOT_Hours, SumOfDT_Hours, SumOfDollars, SumOfHours, ExceptionError, ExceptionType, AgencyNo, EmplName, AllocationFlag )
    (Select en.SSN, en.primarySite, en.primarydept, @payRate, @AvgPayRate, en.AssignmentNo, en.PrimarySite, en.PayType, @JobCode, substring(@UploadCode,1,4) + '0' + substring(@UploadCode,5,1), '', @AdjCode, '', @SpecHandling, 'H', 0, @SumRG, @SumOT, @SumDT, 0.00, (@SumRG + @SumDT + @SumOT), '', '', en.AgencyNo, en.LastName + ' ' + en.FirstName, '1'
      from timeCurrent..tblEmplNames as en
      where en.client = @Client
        and en.Groupcode = @GroupCode
        and en.SSN = @tmpSSN)


	END
	FETCH NEXT FROM csrThd INTO @tmpSSN, @PayRate, @AvgPayRate, @AdjCode, @SpecHandling, @UploadCode, @JobCode, @SumRG, @SumOT, @SumDT
END


CLOSE csrTHD
DEALLOCATE csrThd

END

--select * from #FinalPayRollRecs Order By SiteWorkedAt, SSN, DeptNo

select * from #FinalPayRollRecs where SSn =10449674




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






GO
