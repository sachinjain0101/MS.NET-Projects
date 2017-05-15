CREATE  Procedure [dbo].[usp_APP_EMER_LunchRounding_SP]
(
  @Client varchar(4),
  @GroupCode int,
  @PPED datetime,
  @SSN int
)
AS

SET NOCOUNT ON
--*/

/*
DECLARE @Client varchar(4)
DECLARE @GroupCode int
DECLARE @PPED datetime
DECLARE @SSN int

set @Client = 'EMER'
Set @GroupCode = 722807
Set @PPED = '1/13/2007'
Set @SSN =  487780681 -- 004562543 --292587959

select o.ActualOutTime, o.RecordID, i.ActualInTime, i.RecordID, i.InTime, i.TransDate, i.MasterPayrollDate,
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


--return

*/

EXEC TimeHistory..usp_EmplCalc_OT_FixBrokenPunch @Client, @GroupCode, @PPED, @SSN

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
DECLARE @MinutesHH Numeric(5,2)
DECLARE @MPD datetime
DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 03Aug2016 >--
DECLARE @oRecordID BIGINT  --< @oRecordId data type is changed from  INT to BIGINT by Srinsoft on 03Aug2016 >--
DECLARE @iRecordID BIGINT  --< @iRecordId data type is changed from  INT to BIGINT by Srinsoft on 03Aug2016 >--
DECLARE @RoundMins int
DECLARE @SiteNo int
DECLARE @DeptNo int
DECLARE @Comments varchar(500)
DECLARE @TotHours numeric(9,2)
DECLARE @iTotHours int
DECLARE @remTotHours int


OPEN cPunch

FETCH NEXT FROM cPunch INTO @OutTime, @oRecordID, @InTime, @iOutTime, @SiteNo, @Deptno,  @iRecordID, @TransDate, @MPD, @Minutes
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
    -- If the Minutes are less than 23 then this is a paid break so add time back to card.
    IF @Minutes < 23 
    BEGIN
      Set @MinutesHH = round( (@Minutes / 60.00), 2)

      Set @RecordID = NULL
      Set @RecordID = (Select RecordID from TimeHistory..tblTimeHistDetail
                        where client = @Client 
                          and groupcode = @GroupCode
                          and Payrollperiodenddate = @PPED 
                          and SSN = @SSN
                          and Transdate = @TransDate
                          and ClockAdjustmentNo = '1'
                          and AdjustmentName = 'PD BRK'
                          and Hours between (@MinutesHH - 0.01) and (@MinutesHH + 0.01)
                          and InSrc = '3'
                          and isnull(UserCode,'') = 'SYS' )


      IF isNULL(@RecordID,0) = 0 
      BEGIN
  
        -- get the total for this day, we need to make sure that the paid break that is added back will make the daily total
        -- land a 1/4 hour total ( example 8.00, 8.25, 8.50, etc.) NOT - 8.01, 8.24, 8.26, etc.
        Set @TotHours = (Select sum(Hours) from TimeHistory..tblTimeHistDetail
                        where client = @Client 
                          and groupcode = @GroupCode
                          and Payrollperiodenddate = @PPED 
                          and SSN = @SSN
                          and Transdate = @TransDate)

        Set @TotHours = @TotHours + @MinutesHH
        Set @iTotHours = (@TotHours * 100)
        Set @remTotHours = (@iTotHours % 25 )
        IF @remTotHours in(1,2)
        BEGIN
          Set @remTotHours = -1 * @remTotHours
        END
        ELSE IF @remTotHours in(23,24)
        BEGIN
          Set @remTotHours = 25 - @remTotHours
        END
        ELSE
        BEGIN
          Set @remTotHours = 0
        END

        Set @MinutesHH = @MinutesHH + ( @remTotHours / 100.00)
        
        -- The Adjustment does not exist so add it.
        EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, @SiteNo, @DeptNo, '1', 'PD BRK', @MinutesHH, 0.00, @TransDate, @MPD, 'SYS'
        --Print 'About to insert transaction for ' + convert(varchar(12), @TransDate,101) + ' - ' + str(@MinutesHH, 6,2) + ' hours '

      END
      ELSE
      BEGIN
        -- get the total for this day, we need to make sure that the paid break that is added back will make the daily total
        -- land a 1/4 hour total ( example 8.00, 8.25, 8.50, etc.) NOT - 8.01, 8.24, 8.26, etc.
        -- This will include the PD Break.
        --
        Set @TotHours = (Select sum(Hours) from TimeHistory..tblTimeHistDetail
                        where client = @Client 
                          and groupcode = @GroupCode
                          and Payrollperiodenddate = @PPED 
                          and SSN = @SSN
                          and Transdate = @TransDate)

        Set @TotHours = @TotHours
        Set @iTotHours = (@TotHours * 100)
        Set @remTotHours = (@iTotHours % 25 )
        IF @remTotHours in(1,2)
        BEGIN
          Set @remTotHours = -1 * @remTotHours
        END
        ELSE IF @remTotHours in(23,24)
        BEGIN
          Set @remTotHours = 25 - @remTotHours
        END
        ELSE
        BEGIN
          Set @remTotHours = 0
        END

        IF @remTotHours <> 0
        BEGIN
          Set @MinutesHH = @MinutesHH + ( @remTotHours / 100.00)
          Update TimeHistory..tblTimeHistDetail Set Hours = @MinutesHH where RecordID = @RecordID
        END
        
      END
    END
    
    Set @RoundMins = 0
    IF @Minutes >= 23 and @Minutes <= 37
    BEGIN
      -- ROUND to 30 Minutes.
      Set @RoundMins = (30 - @Minutes)
    END
    IF @Minutes >= 38 and @Minutes <= 52
    BEGIN
      -- ROUND to 45 Minutes.
      Set @RoundMins = (45 - @Minutes)
    END
    IF @Minutes >= 53 and @Minutes <= 67
    BEGIN
      -- ROUND to 60 Minutes.
      Set @RoundMins = (60 - @Minutes)
    END
    IF @Minutes >= 68 and @Minutes <= 82
    BEGIN
      -- ROUND to 75 Minutes.
      Set @RoundMins = (75 - @Minutes)
    END
    IF @Minutes >= 83 and @Minutes <= 97
    BEGIN
      -- ROUND to 90 Minutes.
      Set @RoundMins = (90 - @Minutes)
    END
    IF @RoundMins <> 0
    BEGIN
      Set @NewInTime = dateadd(minute,@RoundMins,@InTime)
      Set @NewInDay = datepart(weekday,@NewInTime)
      Set @Comments = 'LUNCH RULE: IN Punch <' + convert(varchar(8),@InTime,1) + ' ' + convert(varchar(5),@InTime,108) + '> was changed to <' + convert(varchar(8),@NewInTime,1) + ' ' + convert(varchar(5),@NewInTime,108) + '> and hour amount changed to ' 
      Set @NewInTime = '12/30/1899 ' + convert(varchar(5), @NewInTime, 108)
      Set @MinutesHH = round( (datediff(minute,@NewInTime,@iOutTime) / 60.00), 2 )
      IF @MinutesHH < 0
        Set @MinutesHH = 24.00 - (@MinutesHH * -1)
      Set @Comments = @Comments + ltrim(str(@MinutesHH,6,2))
      
      --Print @RoundMins
      --Print @NewInTime
      --Print @NewInDay

      Update TimeHistory..tblTimeHistDetail
        Set InTime = @NewInTime,
            InDay = @NewInDay,
            Hours = @MinutesHH
      where RecordID = @iRecordID

      INSERT INTO [TimeHistory].[dbo].[tblTimeHistDetail_Comments]([Client], [GroupCode], [PayrollPeriodEndDate], [SSN], [CreateDate], [Comments], [UserID], [UserName], [ManuallyAdded])
      VALUES(@Client, @GroupCode, @PPED, @SSN, getdate(), @Comments, 7584, 'System', '0')

    END
	END
	FETCH NEXT FROM cPunch INTO @OutTime, @oRecordID, @InTime, @iOutTime, @SiteNo, @Deptno, @iRecordID, @TransDate, @MPD, @Minutes
END

CLOSE cPunch
DEALLOCATE cPunch



