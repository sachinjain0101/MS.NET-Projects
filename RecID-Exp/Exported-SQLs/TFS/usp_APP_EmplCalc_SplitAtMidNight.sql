Create PROCEDURE [dbo].[usp_APP_EmplCalc_SplitAtMidNight]
(
  @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 03Aug2016 >--
)
as
Set nocount on

DECLARE @Client char(4)
DECLARE @GroupCode int
DECLARE @PPED datetime
DECLARE @SSN int
DECLARE @InDay int
DECLARE @OutDay int
DECLARE @InSrc char(1)
DECLARE @OutSrc char(1)
DECLARE @InTime datetime
DECLARE @OutTime datetime
DECLARE @Changed_InPunch char(1)
DECLARE @Changed_OutPunch char(1)
DECLARE @TransDate datetime
DECLARE @NewInTime datetime
DECLARE @NewOutTime datetime
DECLARE @NewInTime2 datetime
DECLARE @NewOutTime2 datetime
DECLARE @NewShiftNo int
DECLARE @ShiftDiffAmt numeric(5,2)
DECLARE @MinHours numeric(5,2)
DECLARE @UpdateFlag int


SET @InSrc = '3'
SET @OutSrc = '3'
SET @UpdateFlag = '0'

Select @Client = Client,
       @GroupCode = GroupCode,
       @PPED = PayrollPeriodenddate,
       @SSN = @SSN,
       @InDay = InDay,
       @OutDay = OutDay,
       @InTime = TimeHistory.dbo.PunchDateTime2(TransDate, InDay, InTime),
       @OutTime = TimeHistory.dbo.PunchDateTime2(TransDate, OutDay, OutTime),
       @Changed_InPunch = Changed_InPunch,
       @Changed_OutPunch = Changed_OutPunch,
       @TransDate = TransDate, 
       @NewInTime = TimeHistory.dbo.PunchDateTime2(TransDate, OutDay, '12/30/1899 00:00'),
       @NewOutTime = TimeHistory.dbo.PunchDateTime2(TransDate, OutDay, OutTime),
       @NewInTime2 = TimeHistory.dbo.PunchDateTime2(TransDate, InDay, InTime),
       @NewOutTime2 = TimeHistory.dbo.PunchDateTime2(TransDate, OutDay, '12/30/1899 00:00'),
       @NewShiftNo = ShiftNo,
       @ShiftDiffAmt = isnull(ShiftDiffAmt,0.00)
from TimeHistory..tblTimeHistDetail 
where recordid = @RecordID

EXEC [TimeHistory].[dbo].[usp_APP_ShiftDiff_AddSplitRec] @RecordID, @Client, @GroupCode, @PPED, @SSN, @InDay, @OutDay, @InSrc, @OutSrc, @InTime,@OUtTime,@Changed_InPunch, @Changed_OutPunch, @TransDate, @NewInTime, @NewOutTime,@NewShiftNo, @ShiftDiffAmt, @MinHours, @UpdateFlag

SET @UpdateFlag = '1'
SET @NewInTime = @NewInTime2
SET @NewOutTime = @NewOutTime2

EXEC [TimeHistory].[dbo].[usp_APP_ShiftDiff_AddSplitRec] @RecordID, @Client, @GroupCode, @PPED, @SSN, @InDay, @OutDay, @InSrc, @OutSrc, @InTime,@OUtTime,@Changed_InPunch, @Changed_OutPunch, @TransDate, @NewInTime, @NewOutTime,@NewShiftNo, @ShiftDiffAmt, @MinHours, @UpdateFlag


