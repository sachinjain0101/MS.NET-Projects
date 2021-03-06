USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_APP_RAND_45_30_Lunch_Rule]    Script Date: 3/31/2015 11:53:37 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_APP_RAND_45_30_Lunch_Rule]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_APP_RAND_45_30_Lunch_Rule] AS' 
END
GO



/*
Lunch Policy
The programming will add time back for any employee that takes a break in excess of 30-minutes, but no more that 15-minutes will be added.

Examples: 
-if the employee takes a 42 minute break 12-minutes will be added back.
-If the employee takes a 50-minute break 15-minutes will be added back
-If an employee takes a 27-minute break there will be no action taken

Notes:
CIBA has a minimum of 30 minute lunch break, so all lunch punches are guaranteed to be at least 30, therefore we don't have to worry about that case

INSERT INTO [TimeCurrent].[dbo].[tblPayRules]([Client], [GroupCode], [PrimaryState], [PrimarySite], [PrimaryDept], [AgencyNo], [SSN], [DailyHrsBefore_OT], [DailyHrsBefore_DT], [WklyHrsBefore_OT], [WklyHrsBefore_DT], [DailyHrsBeforeNthDayMin], [Enable5thDayMin], [WklyHrsBefore5thDayMin], [DailyHrsBefore5thDay_DT], [WklyHrsBefore5thDay_DT], [Enable6thDayMin], [WklyHrsBefore6thDayMin], [DailyHrsBefore6thDay_DT], [WklyHrsBefore6thDay_DT], [Enable7thDayMin], [WklyHrsBefore7thDayMin], [DailyHrsBefore7thDay_DT], [WklyHrsBefore7thDay_DT], [BillingOvertimeCalcFactor], [DailyOTCountsTowardWeeklyOT], [WhenToRunSpecialPay], [SpecialPay_ProgName], [CalcShiftDiff], [StoredProcedureName], [CalcDailyOT_ByDept], [BeforeStoredProc], [AfterStoredProc], [EightAnd80Rule], [RecordStatus], [MaintUserName], [MaintUserID], [MaintDateTime], [PayRuleID], [PayRuleDesc])
SELECT [Client], 334000, [PrimaryState], [PrimarySite], [PrimaryDept], [AgencyNo], [SSN], [DailyHrsBefore_OT], [DailyHrsBefore_DT], [WklyHrsBefore_OT], [WklyHrsBefore_DT], [DailyHrsBeforeNthDayMin], [Enable5thDayMin], [WklyHrsBefore5thDayMin], [DailyHrsBefore5thDay_DT], [WklyHrsBefore5thDay_DT], [Enable6thDayMin], [WklyHrsBefore6thDayMin], [DailyHrsBefore6thDay_DT], [WklyHrsBefore6thDay_DT], [Enable7thDayMin], [WklyHrsBefore7thDayMin], [DailyHrsBefore7thDay_DT], [WklyHrsBefore7thDay_DT], [BillingOvertimeCalcFactor], [DailyOTCountsTowardWeeklyOT], [WhenToRunSpecialPay], [SpecialPay_ProgName], [CalcShiftDiff], [StoredProcedureName], [CalcDailyOT_ByDept], 'usp_APP_RAND_45_30_Lunch_Rule', '', [EightAnd80Rule], [RecordStatus], [MaintUserName], [MaintUserID], [MaintDateTime], [PayRuleID], [PayRuleDesc]
FROM [TimeCurrent].[dbo].[tblPayRules]
WHERE Client = 'RAND' and groupcode = 607300

UPDATE TimeCurrent..tblClientGroups SET UsePayRulesTable = '1' WHERE Client = 'RAND' and GroupCode = 334000

*/

ALTER   Procedure [dbo].[usp_APP_RAND_45_30_Lunch_Rule]
(
  @Client varchar(4),
  @GroupCode int,
  @PPED datetime,
  @SSN int
)
AS

SET NOCOUNT ON

DECLARE @OutTime datetime
DECLARE @iOutTime datetime
DECLARE @InTime DateTime
DECLARE @NewInTime DateTime
DECLARE @NewInDay int
DECLARE @TransDate datetime
DECLARE @Minutes numeric(7,2)
DECLARE @MPD datetime
DECLARE @RecordID int
DECLARE @oRecordID BIGINT  --< @oRecordId data type is changed from  INT to BIGINT by Srinsoft on 17Aug2016 >--
DECLARE @iRecordID BIGINT  --< @iRecordId data type is changed from  INT to BIGINT by Srinsoft on 17Aug2016 >--
DECLARE @SiteNo int
DECLARE @DeptNo int
DECLARE @TotHours numeric(9,2)

-- I want to release this now, but only apply to next week going forward - GG
IF (@PPED < '2/10/2008')
BEGIN
	RETURN
END

DECLARE cPunch CURSOR READ_ONLY FOR 
SELECT o.ActualOutTime, o.RecordID, i.ActualInTime, i.OutTime, i.SiteNo, i.DeptNo, i.RecordID, i.TransDate, i.MasterPayrollDate,
			 DiffInMinutes = datediff(minute, dbo.PunchDateTime2(o.TransDate, o.OutDay, o.OutTime), dbo.PunchDateTime2(i.TransDate, i.InDay, i.InTime) )
FROM TimeHistory..tblTimeHistDetail as o
INNER JOIN TimeHistory..tblTimeHistDetail as i
ON i.Client = o.Client
AND i.Groupcode = o.GroupCode
AND i.PayrollPeriodEndDate = o.PayrollPeriodEndDate
AND i.SSN = o.SSN
AND datediff(minute, isnull(o.ActualOutTime,dbo.PunchDateTime2(o.TransDate, o.OutDay, o.OutTime)), 
										 isnull(i.ActualInTime,dbo.PunchDateTime2(i.TransDate, i.InDay, i.InTime)) ) between 31 and 90
-- ApplyToRoutine1 on tblGroupDepts determines whether or not the department applies to this rule.
-- They said that it should be driven by the department that they punch out from when going to lunch.
INNER JOIN TimeCurrent.dbo.tblGroupDepts gd
ON gd.Client = o.Client
AND gd.GroupCode = o.GroupCode
AND gd.DeptNo = o.DeptNo
AND gd.ApplyToRoutine1 = '1'
WHERE o.Client = @Client
AND o.Groupcode = @GroupCode
AND o.Payrollperiodenddate = @PPED
AND o.SSN = @SSN
AND o.OutDay NOT IN (10, 11)
AND i.INDay NOT IN (10, 11)
AND i.ClockAdjustmentNo IN ('', ' ')
AND o.ClockAdjustmentNo IN ('', ' ')
AND NOT EXISTS (SELECT 1
								FROM TimeHistory..tblTimeHistDetail thd1
								WHERE thd1.Client = @Client
								AND thd1.GroupCode = @GroupCode
								AND thd1.PayrollPeriodEndDate = @PPED
								AND thd1.SSN = @SSN
								AND thd1.TransDate = o.TransDate
								AND thd1.ClockAdjustmentNo = '8')

OPEN cPunch

FETCH NEXT FROM cPunch INTO @OutTime, @oRecordID, @InTime, @iOutTime, @SiteNo, @Deptno,  @iRecordID, @TransDate, @MPD, @Minutes
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		IF (@Minutes <= 45)
		BEGIN
			SELECT @Minutes = @Minutes - 30
		END
		ELSE IF (@Minutes > 45)
		BEGIN
			SELECT @Minutes = 15
		END

		SELECT @TotHours = @Minutes / 60

    -- The Adjustment does not exist so add it.

		DELETE FROM TimeHistory..tblTimeHistDetail
		WHERE Client = @Client
		AND GroupCode = @GroupCode
		AND SSN = @SSN
		AND TransDate = @TransDate
		AND SiteNo = @SiteNo	
		AND DeptNo = @DeptNo
		AND ClockAdjustmentNo = '1'
		AND AdjustmentName = 'LUNCHBREAK'
		AND UserCode = 'SYS'
		AND Hours <> @TotHours

    EXEC TimeHistory.dbo.usp_APP_XLSImport_Adjustment_Insert_THD 	@Client, @GroupCode, @PPED, @SSN, @SiteNo, @DeptNo, '1', 'LUNCHBREAK', 
																																	@TotHours, 0, @TransDate, @MPD, 'SYS'
	END
	FETCH NEXT FROM cPunch INTO @OutTime, @oRecordID, @InTime, @iOutTime, @SiteNo, @Deptno, @iRecordID, @TransDate, @MPD, @Minutes
END

CLOSE cPunch
DEALLOCATE cPunch




GO
