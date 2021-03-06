USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_APP_SpecPay_Paid_Break]    Script Date: 3/31/2015 11:53:38 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_APP_SpecPay_Paid_Break]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_APP_SpecPay_Paid_Break] AS' 
END
GO

/*
Break Policy
-Add break time back in if break is paid.
*/

ALTER Procedure [dbo].[usp_APP_SpecPay_Paid_Break]
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
and datediff(minute, isnull(o.ActualOutTime,dbo.PunchDateTime2(o.TransDate, o.OutDay, o.OutTime)), isnull(i.ActualInTime,dbo.PunchDateTime2(i.TransDate, i.InDay, i.InTime)) ) between 1 and 97
where o.Client = @Client
and o.Groupcode = @GroupCode
and o.Payrollperiodenddate = @PPED
and o.SSN = @ssn
and o.Outclass in('L','2')

DECLARE @OutTime datetime
DECLARE @iOutTime datetime
DECLARE @InTime DateTime
DECLARE @NewInTime DateTime
DECLARE @NewInDay int
DECLARE @TransDate datetime
DECLARE @Minutes int
DECLARE @MPD datetime
DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 18Aug2016 >--
DECLARE @oRecordID BIGINT  --< @oRecordId data type is changed from  INT to BIGINT by Srinsoft on 18Aug2016 >--
DECLARE @iRecordID BIGINT  --< @iRecordId data type is changed from  INT to BIGINT by Srinsoft on 18Aug2016 >--
DECLARE @SiteNo int
DECLARE @DeptNo int
DECLARE @TotHours numeric(9,2)

OPEN cPunch

FETCH NEXT FROM cPunch INTO @OutTime, @oRecordID, @InTime, @iOutTime, @SiteNo, @Deptno,  @iRecordID, @TransDate, @MPD, @Minutes
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
    -- If the Lunch Break is 45 or less then add that time back in as a PD Break.
    IF @Minutes <= 90 
    BEGIN
      IF @Minutes > 30
        Set @Minutes = 30

      Set @TotHours = round( (@Minutes / 60.00), 2)
      Set @RecordID = NULL
      Set @RecordID = (Select TOP 1 RecordID from TimeHistory..tblTimeHistDetail
                        where client = @Client 
                          and groupcode = @GroupCode
                          and Payrollperiodenddate = @PPED 
                          and SSN = @SSN
                          and Transdate = @TransDate
                          and ClockAdjustmentNo = '1'
                          and AdjustmentName = 'PD_BREAK'
                          and (Hours = @TotHours or (TransType = 7 and Hours = 0.00))
                          and InSrc = '3'
                          and isnull(UserCode,'') = 'SYS' )


      IF isNULL(@RecordID,0) = 0 
      BEGIN
				-- Make Sure User didn't add a Break Adjustment.
	      Set @RecordID = NULL
	      Set @RecordID = (Select TOP 1 RecordID from TimeHistory..tblTimeHistDetail
	                        where client = @Client 
	                          and groupcode = @GroupCode
	                          and Payrollperiodenddate = @PPED 
	                          and SSN = @SSN
	                          and Transdate = @TransDate
	                          and ClockAdjustmentNo = '8'
	                          and AdjustmentName = 'BREAK'
	                          and Hours = @TotHours
	                          and InSrc = '3'
	                          and isnull(UserCode,'') <> 'SYS' )
	
	      IF isNULL(@RecordID,0) = 0 
				BEGIN
	        -- The Adjustment does not exist so add it.
	        EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, @SiteNo, @DeptNo, '1', 'PD_BREAK', @TotHours, 0.00, @TransDate, @MPD, 'SYS'
	        --Print 'About to insert transaction for ' + convert(varchar(12), @TransDate,101) + ' - ' + str(@MinutesHH, 6,2) + ' hours '
	      END
      END
    END
	END
	FETCH NEXT FROM cPunch INTO @OutTime, @oRecordID, @InTime, @iOutTime, @SiteNo, @Deptno, @iRecordID, @TransDate, @MPD, @Minutes
END

CLOSE cPunch
DEALLOCATE cPunch



GO
