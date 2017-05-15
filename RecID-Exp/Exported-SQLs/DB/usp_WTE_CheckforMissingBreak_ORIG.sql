CREATE Procedure [dbo].[usp_WTE_CheckforMissingBreak_ORIG]
(
  @Client varchar(4),
  @Groupcode int,
  @SSN int,
  @ActualOutPunch DateTime
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
DECLARE @AdjCode char(1)
DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 16Sept2016 >--
DECLARE @PromptDesc varchar(100) 

Set @AdjCode = 'N'
Set @CompareDate = convert(varchar(12),@ActualOutPunch, 101)
Set @EndDate = dateadd(minute,5,getdate())
Set @StartDate = dateadd(minute,-23,getdate())

select @TransDate0 = TransDate
from TimeHistory..tblTimeHistDetail with (nolock)
where client = @Client 
and groupcode = @Groupcode 
and SSN = @SSN 
and PayrollPeriodEndDate >= @CompareDate 
AND ActualOutTime = @ActualOutPunch 


INSERT INTO [Audit].[dbo].[tblSimpleAuditLog] ([DateTimeAdded],[LogSource],[LogID1],[LogID2],[LogID3],[LogID4],[LogID5],[LogMessage])
VALUES(getdate(),'usp_WTE_CheckforMissingBreak',@Client, ltrim(str(@GroupCode)), ltrim(str(@SSN)), convert(varchar(40),@ActualOutPunch,120),
        convert(varchar(12),@TransDate0,101), 'Checking for Meal Exception')

--Set @TransdateMinus1 = dateadd(day,-1,@TransDate0)

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
  --and TransDate in(@TransDate0 , @TransdateMinus1 )
  and TransDate = @TransDate0
  and InSrc = '3' 
  and UserCode = 'SYS' 
  and ClockADjustmentNo = 'N'
  --and AdjustmentName in('NMR_2B','NMR_NB')
  and TransType <> 7 
--  and ActualInTime between @StartDate and @EndDate 

--Print @PPED
--Print @TransDate
--Print @RecordID

IF isnull(@recordID,0) > 0 
BEGIN
    INSERT INTO [Audit].[dbo].[tblSimpleAuditLog] ([DateTimeAdded],[LogSource],[LogID1],[LogID2],[LogID3],[LogID4],[LogID5],[LogMessage])
    VALUES(getdate(),'usp_WTE_CheckforMissingBreak',@Client, ltrim(str(@GroupCode)), ltrim(str(@SSN)), convert(varchar(40),@ActualOutPunch,120),
            ltrim(str(@RecordID)), 'Meal Exception Found.')

  -- This means there is a break penalty on the time card. 
  -- Get the RecordID from the Break Exception Created by the Penalty Break Special Pay and return it.
  --

  Set @PromptDesc = (select LookUpDescription from TimeCurrent..tblValidLookup where LookupType = 'BreakExceptionWTC' + '-' + @Client and LookupValue = 'NoBreak' )
  if isnull(@PromptDesc,'') = ''
    Set @PromptDesc = ' * What is the reason you were delayed to or missed a meal period? * '

  Select 
    MissingBreak = isnull(RecordID,0), 
    PromptDesc = @PromptDesc,
    BreakExceptionRecordID = ISNULL(RecordId, 0) ,
    SiteState = 'CA',
    InOutId AS THDRecordID ,
    [In] ,
    [Out],
    ChoicePrefix = 'NL',
    MealExceptionType = 'Missed meal'
  from TimeHistory.[dbo].[tblWTE_Spreadsheet_Breaks]
  where client = @Client 
  and groupcode = @Groupcode 
  and SSN = @SSN 
  and PayrollPeriodEndDate = @PPED 
  and TransDate = @TransDate
END
ELSE
BEGIN
  Select MissingBreak = '0' where 1 = 0     -- force no records back
END

