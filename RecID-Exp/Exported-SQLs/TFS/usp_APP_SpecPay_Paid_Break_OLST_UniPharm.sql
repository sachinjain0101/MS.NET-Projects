Create PROCEDURE [dbo].[usp_APP_SpecPay_Paid_Break_OLST_UniPharm]
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
order by i.TransDate, i.ActualInTime

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
DECLARE @Over29Count int
DECLARE @PaidBreakCount int
DECLARE @savTransDate datetime
DECLARE @savPriorOut datetime

SET @Over29Count = 0
SET @PaidBreakCount = 0
SET @savTransDate = '1/1/2000'

OPEN cPunch

FETCH NEXT FROM cPunch INTO @OutTime, @oRecordID, @InTime, @iOutTime, @SiteNo, @Deptno,  @iRecordID, @TransDate, @MPD, @Minutes
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
    IF @savTransDate <> @TransDate
    BEGIN
      Set @savTransDate = @TransDate
			Set @PaidBreakCount = 0 
    END
    
    -- Paid Break is the first break of the day.
		-- 
    IF @PaidBreakCount = 0 
    BEGIN
      SET @PaidBreakCount = @PaidBreakCount + 1
			Set @savPriorOut = @OutTime
      IF @Minutes > 15
        Set @Minutes = 15

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
				-- 
	      Set @RecordID = NULL
				-- Make Sure User didn't add a Break Adjustment Or the user has not added a worked adjustment
	      Set @RecordID = (Select TOP 1 RecordID from TimeHistory..tblTimeHistDetail
	                        where client = @Client 
	                          and groupcode = @GroupCode
	                          and Payrollperiodenddate = @PPED 
	                          and SSN = @SSN
	                          and Transdate = @TransDate
	                          and ClockAdjustmentNo in('1','8')
	                          and Hours >= @TotHours
	                          and InSrc = '3'
	                          and isnull(UserCode,'') <> 'SYS' )
	
	      IF isNULL(@RecordID,0) = 0 
				BEGIN
          Delete from Timehistory..tblTimeHistDetail where client = @client and groupcode = @Groupcode and ssn = @SSN
            and TransDate = @TransDate and PayrollPeriodenddate = @PPED
            and ClockAdjustmentNo = '1' and isnull(UserCode,'') = 'SYS' and ADjustmentName = 'PD_BREAK'
	        -- The Adjustment does not exist so add it.
	        EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, @SiteNo, @DeptNo, '1', 'PD_BREAK', @TotHours, 0.00, @TransDate, @MPD, 'SYS'
	        --Print 'About to insert transaction for ' + convert(varchar(12), @TransDate,101) + ' - ' + str(@MinutesHH, 6,2) + ' hours '
	      END
      END
    END
    ELSE
    BEGIN
      -- Force the break to 30 minutes.
			-- need to adjust the rounded intime.
			--
			IF @Minutes <= 30
			BEGIN
				Set @Minutes = 30 - @Minutes 
				Update TimeHistory..tblTimeHistDetail
					Set InTime = dateadd(minute, @Minutes, InTime)
				where RecordID = @iRecordID

				Update TimeHistory..tblTimeHistDetail
					Set Hours = round( (datediff(minute, timehistory.dbo.PunchDateTime2(TransDate,InDay,InTime), TimeHistory.dbo.PunchDateTime2(TransDate,OutDay,OutTime) ) / 60.00), 2)
				where RecordID = @iRecordID
			END

    END
	END
	FETCH NEXT FROM cPunch INTO @OutTime, @oRecordID, @InTime, @iOutTime, @SiteNo, @Deptno, @iRecordID, @TransDate, @MPD, @Minutes
END

CLOSE cPunch
DEALLOCATE cPunch





