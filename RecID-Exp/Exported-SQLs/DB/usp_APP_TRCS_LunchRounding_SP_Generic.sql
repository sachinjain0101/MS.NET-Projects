CREATE Procedure [dbo].[usp_APP_TRCS_LunchRounding_SP_Generic]
(
	@AddlLunchMin INT, -- 15
	@AddlLunchDec NUMERIC(5,2), -- -0.25
	@CreditLunchMin INT, -- 45
	@CreditLunchAmtDec NUMERIC(5,2), -- 0.25
	@LunchPunchMin INT,  -- 1
	@LunchPunchMax INT,  -- 97
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
DECLARE @Minutes int
DECLARE @MPD datetime
DECLARE @RecordID BIGINT
DECLARE @oRecordID BIGINT
DECLARE @iRecordID BIGINT
DECLARE @SiteNo int
DECLARE @DeptNo int
DECLARE @TotHours numeric(9,2)

IF (@LunchPunchMin = 0)
	SET @LunchPunchMin = 1
	
IF (@LunchPunchMax = 0)
	SET @LunchPunchMax = 97
	
	
DECLARE cPunch CURSOR READ_ONLY
FOR select 	o.ActualOutTime, o.RecordID, i.ActualInTime, i.OutTime, i.SiteNo, i.DeptNo, i.RecordID, i.TransDate, i.MasterPayrollDate,
						DiffInMinutes = datediff(minute, dbo.PunchDateTime2(o.TransDate, o.OutDay, o.OutTime), dbo.PunchDateTime2(i.TransDate, i.InDay, i.InTime) )
		from TimeHistory..tblTimeHistDetail as o
		Inner Join TimeHistory..tblTimeHistDetail as i
		on i.Client = o.Client
		and i.Groupcode = o.GroupCode
		and i.PayrollPeriodEndDate = o.PayrollPeriodEndDate
		and i.SSN = o.SSN
		and i.InClass = o.OutClass  
		and datediff(minute, dbo.PunchDateTime2(o.TransDate, o.OutDay, o.OutTime), dbo.PunchDateTime2(i.TransDate, i.InDay, i.InTime)) between @LunchPunchMin and @LunchPunchMax
		where o.Client = @Client
		and o.Groupcode = @GroupCode
		and o.Payrollperiodenddate = @PPED
		and o.SSN = @ssn

OPEN cPunch

FETCH NEXT FROM cPunch INTO @OutTime, @oRecordID, @InTime, @iOutTime, @SiteNo, @Deptno,  @iRecordID, @TransDate, @MPD, @Minutes
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
    -- If the Lunch Break is @AddlLunchMin (15) or less then add in an addition @AddlLunchDec (15) minutes for lunch break.
    IF (@Minutes <= @AddlLunchMin AND @AddlLunchMin <> 0)
    BEGIN
      Set @TotHours = @AddlLunchDec
      Set @RecordID = NULL
      Set @RecordID = (	Select TOP 1 RecordID 
      									from TimeHistory..tblTimeHistDetail
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


      IF isNULL(@RecordID,0) = 0 
      BEGIN
				-- Make Sure User didn't add a Break Adjustment.
	      Set @RecordID = NULL
	      Set @RecordID = (	Select TOP 1 RecordID 
	      									from TimeHistory..tblTimeHistDetail
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
	        EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, @SiteNo, @DeptNo, '1', 'LUNCHBREAK', @TotHours, 0.00, @TransDate, @MPD, 'SYS'
	        --Print 'About to insert transaction for ' + convert(varchar(12), @TransDate,101) + ' - ' + str(@MinutesHH, 6,2) + ' hours '
	      END
      END
    END
    
    IF (@Minutes >= @CreditLunchMin AND @CreditLunchMin <> 0)
    BEGIN
      Set @TotHours = @CreditLunchAmtDec
      Set @RecordID = NULL
      Set @RecordID = (	Select TOP 1 RecordID 
      									from TimeHistory..tblTimeHistDetail
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


      IF isNULL(@RecordID,0) = 0 
      BEGIN
				-- Make Sure User didn't add a Break Adjustment.
	      Set @RecordID = NULL
	      Set @RecordID = (	Select TOP 1 RecordID 
	      									from TimeHistory..tblTimeHistDetail
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
	        EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, @SiteNo, @DeptNo, '1', 'LUNCHBREAK', @TotHours, 0.00, @TransDate, @MPD, 'SYS'
	        --Print 'About to insert transaction for ' + convert(varchar(12), @TransDate,101) + ' - ' + str(@MinutesHH, 6,2) + ' hours '
	      END
      END
    END
	END
	FETCH NEXT FROM cPunch INTO @OutTime, @oRecordID, @InTime, @iOutTime, @SiteNo, @Deptno, @iRecordID, @TransDate, @MPD, @Minutes
END

CLOSE cPunch
DEALLOCATE cPunch


