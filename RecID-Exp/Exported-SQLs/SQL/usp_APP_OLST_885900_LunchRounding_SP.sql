USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_APP_OLST_885900_LunchRounding_SP]    Script Date: 3/31/2015 11:53:37 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_APP_OLST_885900_LunchRounding_SP]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_APP_OLST_885900_LunchRounding_SP] AS' 
END
GO



/*
Lunch Policy

Develop a Special Pay Rule for DeMet's Candy Company (same as Montpelier Nut)
Employees will punch out/in for a meal break once per day (12 hour shift).
The actual break time will be added back to the employees worked time up to a maximum of 30 minutes. 
If an employee has a break over 30 minutes, only 30 minutes will be credited.
If an employee takes less than 30 minutes for break, the actual break time is credited. (e.g. if an employee takes a 15 minute lunch break, they will be credited for 15 minutes)

*/

ALTER      Procedure [dbo].[usp_APP_OLST_885900_LunchRounding_SP]
(
  @Client varchar(4),
  @GroupCode int,
  @PPED datetime,
  @SSN int
)
AS
SET NOCOUNT ON


DECLARE cPunch CURSOR
READ_ONLY
FOR 
select o.ActualOutTime, o.RecordID, i.ActualInTime, i.OutTime, i.SiteNo, i.DeptNo, i.RecordID, i.TransDate, i.MasterPayrollDate,
DiffInMinutes = datediff(minute, dbo.PunchDateTime2(o.TransDate, o.OutDay, o.OutTime), dbo.PunchDateTime2(i.TransDate, i.InDay, i.InTime) )
from TimeHistory..tblTimeHistDetail as o
Inner Join TimeHistory..tblTimeHistDetail as i
on i.Client = o.Client
and i.Groupcode = o.GroupCode
and i.PayrollPeriodEndDate = o.PayrollPeriodEndDate
and i.SSN = o.SSN
and i.InClass = o.OutClass  
and datediff(minute, dbo.PunchDateTime2(o.TransDate, o.OutDay, o.OutTime), dbo.PunchDateTime2(i.TransDate, i.InDay, i.InTime)) between 1 and 97
where o.Client = @Client
and o.Groupcode = @GroupCode
and o.Payrollperiodenddate = @PPED
and o.SSN = @ssn


DECLARE @OutTime datetime
DECLARE @iOutTime datetime
DECLARE @InTime DateTime
DECLARE @NewInTime DateTime
DECLARE @NewInDay int
DECLARE @TransDate datetime
DECLARE @Minutes int
DECLARE @MPD datetime
DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 16Aug2016 >--
DECLARE @oRecordID BIGINT  --< @oRecordId data type is changed from  INT to BIGINT by Srinsoft on 16Aug2016 >--
DECLARE @iRecordID BIGINT  --< @iRecordId data type is changed from  INT to BIGINT by Srinsoft on 16Aug2016 >--
DECLARE @SiteNo int
DECLARE @DeptNo int
DECLARE @TotHours numeric(9,2)

OPEN cPunch

FETCH NEXT FROM cPunch INTO @OutTime, @oRecordID, @InTime, @iOutTime, @SiteNo, @Deptno,  @iRecordID, @TransDate, @MPD, @Minutes
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
    -- If the Lunch Break is 30 mins or more than add 30 mins back.  Under 30 mins, add back actual
    Set @TotHours = case when @Minutes > 30 then 0.50 else round(@Minutes/60.0,2) end
    Set @RecordID = NULL
    Set @RecordID = (Select TOP 1 RecordID from TimeHistory..tblTimeHistDetail
                      where client = @Client 
                        and groupcode = @GroupCode
                        and Payrollperiodenddate = @PPED 
                        and SSN = @SSN
                        and Transdate = @TransDate
                        and ClockAdjustmentNo = '1'
                        and AdjustmentName = 'LUNCHBREAK'
                        and (Hours = @TotHours or (TransType = 7 and Hours = 0.00))
                        and InSrc = '3'
                        and isnull(UserCode,'') = 'SYS' )


    IF @RecordID IS NULL 
      -- The Adjustment does not exist so add it.
      EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, @SiteNo, @DeptNo, '1', 'LUNCHBREAK', @TotHours, 0.00, @TransDate, @MPD, 'SYS'
      --Print 'About to insert transaction for ' + convert(varchar(12), @TransDate,101) + ' - ' + str(@MinutesHH, 6,2) + ' hours '
    
	END
	FETCH NEXT FROM cPunch INTO @OutTime, @oRecordID, @InTime, @iOutTime, @SiteNo, @Deptno, @iRecordID, @TransDate, @MPD, @Minutes
END

CLOSE cPunch
DEALLOCATE cPunch









GO
