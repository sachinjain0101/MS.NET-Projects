Create PROCEDURE [dbo].[usp_APP_TAND_Bonerts_sp]
(
  @Client varchar(4),
  @GroupCode int,
  @PPED datetime,
  @SSN int
)
AS
SET NOCOUNT ON

/*
DECLARE @Client varchar(4)
DECLARE @GroupCode int
DECLARE @PPED datetime
DECLARE @SSN int

set @Client = 'TAND'
Set @GroupCode = 274400
Set @PPED = '5/28/06'
Set @SSN = 7238

select o.ActualOutTime, i.ActualInTime, i.TransDate, i.MasterPayrollDate,
DiffInMinutes = datediff(minute, dbo.PunchDateTime2(o.TransDate, o.OutDay, o.OutTime), dbo.PunchDateTime2(i.TransDate, i.InDay, i.InTime) )
from TimeHistory..tblTimeHistDetail as o
Inner Join TimeHistory..tblTimeHistDetail as i
on i.Client = o.Client
and i.Groupcode = o.GroupCode
and i.PayrollPeriodEndDate = o.PayrollPeriodEndDate
and i.SSN = o.SSN
and i.InClass = o.OutClass  -- Second Lunch In Punch
and datediff(minute, isnull(o.ActualOutTime,dbo.PunchDateTime2(o.TransDate, o.OutDay, o.OutTime)), isnull(i.ActualInTime,dbo.PunchDateTime2(i.TransDate, i.InDay, i.InTime)) ) between 1 and 22
where o.Client = @Client
and o.Groupcode = @GroupCode
and o.Payrollperiodenddate = @PPED
and o.SSN = @ssn
and o.Outclass = '2'
*/

EXEC TimeHistory..usp_EmplCalc_OT_FixBrokenPunch @Client, @GroupCode, @PPED, @SSN

DECLARE cPunch CURSOR
READ_ONLY
FOR 
select o.ActualOutTime, i.ActualInTime, i.TransDate, i.MasterPayrollDate,
DiffInMinutes = datediff(minute, dbo.PunchDateTime2(o.TransDate, o.OutDay, o.OutTime), dbo.PunchDateTime2(i.TransDate, i.InDay, i.InTime) )
from TimeHistory..tblTimeHistDetail as o
Inner Join TimeHistory..tblTimeHistDetail as i
on i.Client = o.Client
and i.Groupcode = o.GroupCode
and i.PayrollPeriodEndDate = o.PayrollPeriodEndDate
and i.SSN = o.SSN
and i.InClass = o.OutClass  -- Second Lunch In Punch
and datediff(minute, isnull(o.ActualOutTime,dbo.PunchDateTime2(o.TransDate, o.OutDay, o.OutTime)), isnull(i.ActualInTime,dbo.PunchDateTime2(i.TransDate, i.InDay, i.InTime)) ) between 1 and 240
where o.Client = @Client
and o.Groupcode = @GroupCode
and o.Payrollperiodenddate = @PPED
and o.SSN = @ssn
and o.Outclass = '2'


DECLARE @OutTime datetime
DECLARE @InTime DateTime
DECLARE @TransDate datetime
DECLARE @Minutes int
DECLARE @MinutesHH Numeric(5,2)
DECLARE @MPD datetime
DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 19Aug2016 >--

OPEN cPunch

FETCH NEXT FROM cPunch INTO @OutTime, @InTime, @TransDate, @MPD, @Minutes
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
    -- Each record in this cursor should have a corresponding positive adjustment 
    -- on this weeks time card for the amount of the difference (@Minutes ) or if over
    -- 22 minutes, then set to 20 minutes.
    --
    -- First check to see if the adjustment is on the card, if not then add it.

    IF @Minutes > 22 
      Set @Minutes = 22

    Set @MinutesHH = round( (@Minutes / 60.00), 2)

    Set @RecordID = NULL
    Set @RecordID = (Select RecordID from TimeHistory..tblTimeHistDetail
                      where client = @Client 
                        and groupcode = @GroupCode
                        and Payrollperiodenddate = @PPED 
                        and SSN = @SSN
                        and Transdate = @TransDate
                        and ClockAdjustmentNo = '1'
                        and Hours = @MinutesHH
                        and InSrc = '3'
                        and isnull(UserCode,'') = 'SYS' )


    IF isNULL(@RecordID,0) = 0 
    BEGIN
      -- The Adjustment does not exist so add it.
      EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 1, 0, '1', 'WORKED', @MinutesHH, 0.00, @TransDate, @MPD, 'SYS'
      --Print 'About to insert transaction for ' + convert(varchar(12), @TransDate,101) + ' - ' + str(@MinutesHH, 6,2) + ' hours '
    END
	END
	FETCH NEXT FROM cPunch INTO @OutTime, @InTime, @TransDate, @MPD, @Minutes
END

CLOSE cPunch
DEALLOCATE cPunch





