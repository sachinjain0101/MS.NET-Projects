Create PROCEDURE [dbo].[usp_WGET_CheckforMissingBreak_v12xx]
(
  @Client varchar(4),
  @Groupcode int,
  @SSN int,
  @ThisPunch varchar(20),
  @PunchType varchar(20),
  @Errorcode varchar(80),
  @ActualOutPunch DateTime = '1/1/1970'
)
AS

SET NOCOUNT ON

-- This SPROC will check to see if the last punch processed created a Missing Break Penalty on the time card.

-- First get the transaction date of the punch.
-- 
Declare @Transdate datetime
Declare @Transdate0 datetime
DECLARE @TransdateMinus1 datetime
DECLARE @CompareDate datetime
DECLARE @StartDate datetime
DECLARE @EndDate datetime
DECLARE @PPED datetime
DECLARE @AdjCode varchar(3) --< Srinsoft 09/09/2015 Changed @AdjCode char(1) to varchar(3) for ClockAdjustmentno >--
DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 16Sept2016 >--

Set @AdjCode = 'N'
Set @CompareDate = convert(varchar(12),@ActualOutPunch, 101)
Set @EndDate = dateadd(minute,1,getdate())
Set @StartDate = dateadd(minute,-23,getdate())

Print @CompareDate

select @TransDate0 = TransDate
from TimeHistory..tblTimeHistDetail with (nolock)
where client = @Client 
and groupcode = @Groupcode 
and SSN = @SSN 
and PayrollPeriodEndDate >= @CompareDate 
AND ActualOutTime = @ActualOutPunch 


Set @TransdateMinus1 = dateadd(day,-1,@TransDate0)

--Print @Transdate0
--Print @TransDateMinus1

-- See if there is an adjustment code for a no Break.
--  This logic is funky because it handles the fact that the OUT punch may have caused the punch to be split at end of
--  day and therefore the actual Penalty adjustment may be on the prior transdate.
-- NOTE: the actual IN time on the Penalty break transaction is when it was inserted into the database. This is used to know if
--       the penalty adjustment is the one we are looking for ( if it's within 5 minutes of the current date/time )
--
Select 
  @PPED = PayrollPeriodEndDate,
  @TransDate = TransDate,
  @RecordID = RecordID
from TimeHistory..tblTimeHistDetail with (nolock)
where client = @Client 
  and groupcode = @Groupcode 
  and SSN = @SSN 
  and PayrollPeriodEndDate >= @CompareDate 
  and TransDate in(@TransDate0 , @TransdateMinus1 )
  and ClockAdjustmentNo = @AdjCode
  and InSrc = '3' 
  and UserCode = 'SYS' 
  and ClockAdjustmentNo = 'N'
  --and AdjustmentName in('NMR_2B','NMR_NB')
  and TransType <> 7 
  and ActualInTime between @StartDate and @EndDate 

--Print @PPED
--Print @TransDate
--Print @RecordID

IF isnull(@recordID,0) > 0 
BEGIN
  -- This means there is a break penalty on the time card. 
  -- Get the RecordID from the Break Exception Created by the Penalty Break Special Pay and return it.
  --
  Select MissingBreak = isnull(RecordID,0)
  from TimeHistory.[dbo].[tblWTE_Spreadsheet_Breaks]
  where client = @Client 
  and groupcode = @Groupcode 
  and SSN = @SSN 
  and PayrollPeriodEndDate = @PPED 
  and TransDate = @TransDate
  order by RecordID Desc
END
ELSE
BEGIN
  Select MissingBreak = '0' where 1 = 0     -- force no records back
END

