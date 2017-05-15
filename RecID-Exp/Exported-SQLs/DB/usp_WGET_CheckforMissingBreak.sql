CREATE Procedure [dbo].[usp_WGET_CheckforMissingBreak]
(
  @Client varchar(4),
  @Groupcode int,
  @SSN int,
  @ThisPunch varchar(20),
  @PunchType varchar(20),
  @Errorcode varchar(80),
  @ActualOutPunch DateTime = '1/1/1970',
  @SiteNo int = 0,
  @SiteState varchar(2) = '',
  @MaxExceptionID int = 0,
  @thdRecordID BIGINT = 0,  --< @thdRecordId data type is changed from  INT to BIGINT by Srinsoft on 16Sept2016 >--
  @Version varchar(8) = ''
)
AS


SET NOCOUNT ON

IF @Version = '' or left(@Version,2) = '12'
BEGIN
  -- Call the old stored proc.
  --
  Exec TimeHistory..usp_WGET_CheckforMissingBreak_v12xx
      @Client,
      @Groupcode,
      @SSN,
      @ThisPunch,
      @PunchType,
      @Errorcode,
      @ActualOutPunch
  return 
END


if @Errorcode not in('0','')
BEGIN
  INSERT INTO Audit.[dbo].[tblSimpleAuditLog]([DateTimeAdded],[LogSource],[LogID1],[LogID2],[LogID3],[LogID4],[LogID5],[LogMessage])
  select getdate(),'usp_WGET_CheckforMissingBreak', 
    @Client + ',' + ltrim(str(@groupcode)) + ',' + ltrim(str(@SiteNo)),
    ltrim(str(@SSN)),
    @thisPunch,
    @Errorcode,
    ltrim(str(@thdRecordID)),
    'Punch did not process - cigtrans returned code = ' + @errorcode 

END

-- This SPROC will check to see if the last punch processed created any Missing Break Penalties on the time card.

-- First get the transaction date of the punch.
-- 
DECLARE @CompareDate datetime
DECLARE @RestCount int
DECLARE @ActualOutTimeStamp bigint

Set @ActualOutTimeStamp = cast(@thispunch+'000' as bigint)

Set @CompareDate = convert(varchar(12),@ActualOutPunch, 101)
Set @CompareDate = dateadd(day,-2,@CompareDate)

--Print @CompareDate

-- Get the rest breaks required.
-- NOTE:  
--  The BillOTRate contains the number of rest breaks that should be taken.  The Special pay determined that value based on rest break rules.
--  
select 
    @RestCount = BillOTRate
from TimeHistory..tblTimeHistDetail with (nolock)
where client = @Client 
and groupcode = @Groupcode 
and SSN = @SSN 
and PayrollPeriodEndDate >= @CompareDate 
and RecordID >= @thdRecordID 
--and outTimestamp = @ActualOutTimeStamp 
and ActualOutTime = @ActualOutPunch 
and clockadjustmentNo in('',' ')


Set @RestCount = isnull(@RestCount,0)
Set @CompareDate = dateadd(day,-4,@CompareDate)

Declare @tmpResults as table
(
	ParmName varchar(50),
	ParmVal int,
	ClockPrompt varchar(50)
)

--Print @CompareDate

-- See if there are any exceptions that were added after the punch was processed.
-- the @MaxExceptionID was loaded prior to the punch being processed and passed into this SPROC from the web page.
--
IF @SiteState = 'CA'
BEGIN
	insert into @tmpResults (ParmName, ParmVal, ClockPrompt )
  Select top 1 
    ParmName = 'MISSINGBREAK',
    ParmVal = RecordID,
    ClockPrompt = ''
  from TimeHistory.[dbo].[tblWTE_Spreadsheet_Breaks]
  where client = @Client 
  and groupcode = @Groupcode 
  and SSN = @SSN 
  and PayrollPeriodEndDate >= @CompareDate
  and RecordID > @MaxExceptionID
  union ALL
  select ParmName = 'RESTBREAKCNT',
         ParmVal = @RestCount,
         ClockPrompt = ''
  union ALL
  select ParmName = 'PEREXCEPTION',
         ParmVal = 0,
         ClockPrompt = ''
  --return
END

IF @SiteState = 'WA'
BEGIN
	insert into @tmpResults (ParmName, ParmVal, ClockPrompt )
  Select ParmName = 'MISSINGBREAK',
    ParmVal = count(*),
    ClockPrompt = ''
  from TimeHistory.dbo.tblWTE_Spreadsheet_Breaks WITH (NOLOCK, INDEX (IX_tblWTE_Spreadsheet_Breaks_CliGrpCdSSNPPEDSIteDeptPosTransDtRecID))  
  where client = @Client 
  and groupcode = @Groupcode 
  and SSN = @SSN 
  and PayrollPeriodEndDate >= @CompareDate
  and RecordID > @MaxExceptionID
  and left(BreakType,1) <> 'S'
  union ALL
  Select 
    ParmName = 'MISSINGBREAK' + substring(BreakType,2,1),
    ParmVal = RecordID,
    ClockPrompt = case when left(BreakType,1) = 'N' then 'Miss'
                       when left(BreakType,1) = 'L' then 'Late' 
                       when left(BreakType,1) = 'E' then 'Erly' 
                       when left(BreakType,1) = 'S' then 'Shrt' else 'Miss' end
  from TimeHistory.dbo.tblWTE_Spreadsheet_Breaks WITH (NOLOCK, INDEX (IX_tblWTE_Spreadsheet_Breaks_CliGrpCdSSNPPEDSIteDeptPosTransDtRecID))  
  where client = @Client 
  and groupcode = @Groupcode 
  and SSN = @SSN 
  and PayrollPeriodEndDate >= @CompareDate
  and RecordID > @MaxExceptionID
  and left(BreakType,1) <> 'S'
  union ALL
  select ParmName = 'RESTBREAKCNT',
          ParmVal = @RestCount,
          ClockPrompt = ''
  union ALL
  select ParmName = 'PEREXCEPTION',
          ParmVal = 1,
          ClockPrompt = ''
  order by ParmName
  --return
END

DECLARE @XMLOUT VARCHAR(8000)

select @XMLOUT = (
		select   Client = @Client,
			Groupcode = @Groupcode,
			SSN = @SSN,
			ThisPunch = @ThisPunch,
			PunchType = @PunchType,
			Errocode = @Errorcode,
			ActualOutPunch = @ActualOutPunch,
			SiteNo = @SiteNo,
			SiteState = @SiteState,
			MaxExceptionID = @MaxExceptionID,
			thdRecordID = @thdRecordID,
			ClockVersion = @Version,
			ParmName,
			ParmVal,
			ClockPrompt
			from @tmpResults 
		FOR XML path('CHECKMEALEXCEPTIONS')
)

--Print @XMLOUT

Declare @TermID varchar(20)
Declare @MsgLen int
Set @TermID = (select exportmailbox from TimeCurrent..tblSiteNames with(nolock) where client = @Client and groupcode = @groupcode and siteno = @Siteno )
Set @MsgLen = len(@XMLOUT)
exec timecurrent..[usp_WGET_Add_Message] @TermID, 'Rest-MealExceptionResponse', @MsgLen , @XMLOUT, '', 'N'

Select * from @tmpResults order by ParmName
