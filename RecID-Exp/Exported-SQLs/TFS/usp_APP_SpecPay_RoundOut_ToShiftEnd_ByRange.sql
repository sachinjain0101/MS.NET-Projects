Create PROCEDURE [dbo].[usp_APP_SpecPay_RoundOut_ToShiftEnd_ByRange]
(
  @StartRange int,
  @EndRange int,
  @Client varchar(4),
  @GroupCode int,
  @PPED datetime,
  @SSN int
)
as 

SET NOCOUNT ON


DECLARE cCard CURSOR
READ_ONLY
FOR 
select Distinct t.RecordID,
OutMins = ((datepart(hour,t.OutTime) * 60) + DATEPART(minute,t.Outtime)),
ActOutMins = ((datepart(hour,t.ActualOutTime) * 60) + DATEPART(minute,t.actualOuttime)), 
ShiftOutMins = ((datepart(hour,isnull(d.shiftEnd,d99.shiftend)) * 60) + DATEPART(minute,isnull(d.ShiftEnd,d99.ShiftEnd))),
ShiftEndDate = isnull(d.ShiftEnd,d99.ShiftEnd), t.Hours
from TimeHistory..tblTimeHistDetail as t with(nolock)
left join TimeCurrent..tblDeptShifts as d with(nolock)
on d.Client = t.Client
and d.GroupCode = t.GroupCode 
and d.SiteNo  = t.SiteNo 
and d.DeptNo = t.Deptno
and d.ShiftNo = t.ShiftNo 
and d.recordstatus = '1'
left join TimeCurrent..tblDeptShifts as d99 with(nolock)
on d99.Client = t.Client
and d99.GroupCode = t.GroupCode 
and d99.SiteNo  = t.SiteNo 
and d99.DeptNo = 99
and d99.ShiftNo = t.ShiftNo 
and d99.recordstatus = '1'
where t.Client = @Client
and t.GroupCode = @GroupCode
and t.PayrollPeriodEndDate = @PPED
and t.ClockAdjustmentNo = ''
and t.ShiftNo >= 1
and t.Transtype <> 7
and t.Hours > 0
and t.SSN = @SSN


DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 18Aug2016 >--
DECLARE @OutMins int
DECLARE @ActOutMins int
DECLARE @ShiftOutMins int
DECLARE @ShiftEndDate datetime
DECLARE @Hours numeric(7,2)
DECLARE @Addmins BIGINT  --< @Addmins data type is changed from  INT to BIGINT by Srinsoft on 29Sept2016 >--

OPEN cCard

FETCH NEXT FROM cCard into @RecordID, @OutMins, @ActOutMins, @ShiftOutMins, @ShiftEndDate, @Hours
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
    if (@ShiftOutMins - @ActOutMins) between @StartRange and @EndRange 
    BEGIN
        -- Need to round this punch up to shift end time
        --
        
        -- Get minutes to add to existing outtime and to the hours total
        --
        Set @AddMins = @ShiftOutMins - @OutMins 
        Update TimeHistory..tblTImeHistDetail 
          Set Hours = Hours + round(@Addmins / 60.00,2),
              OutTime = dateadd(minute,@addmins,OutTime),
              JobID = @Addmins 
        where recordid = @RecordID 

    END
	END
	FETCH NEXT FROM cCard into @RecordID, @OutMins, @ActOutMins, @ShiftOutMins, @ShiftEndDate, @Hours
END

CLOSE cCard
DEALLOCATE cCard


