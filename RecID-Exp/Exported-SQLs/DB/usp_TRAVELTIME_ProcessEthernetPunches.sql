CREATE procedure [dbo].[usp_TRAVELTIME_ProcessEthernetPunches]
(
  @Client varchar(4),
  @Groupcode int,
  @PPED datetime,
  @DeptNo int
)
AS

SET NOCOUNT ON

-- =============================================
-- Cursor to get all records for this group where the Travel department was auto clocked out from another location's in punch.
--
-- =============================================
DECLARE cPunches CURSOR
READ_ONLY
FOR 
select t1.recordid, t2.SiteNo, t1.SiteNo, t1.SSN, timehistory.dbo.PunchDateTime2(t1.TransDate, t1.InDay, t1.Intime)
from TimeHistory..tblTimeHistdetail as t1
Inner Join TimeHistory..tblTimeHistdetail as t2
on t2.client = t1.client
and t2.groupcode = t1.groupcode
and t2.Payrollperiodenddate = t1.payrollperiodenddate
and t2.ssn = t1.ssn
and t2.inday = t1.outday
and t2.intime = t1.outtime
and t2.SiteNo <> t1.SiteNo
and t2.Insrc in('0','V','C')
Inner Join TimeCurrent..tblSiteNames as s1
on s1.client = t1.client
and s1.groupcode = t1.groupcode
and s1.siteno = t1.siteno
Inner Join TimeCurrent..tblSiteNames as s2
on s2.client = t2.client
and s2.groupcode = t2.groupcode
and s2.siteno = t2.siteno
where t1.client = @Client
and t1.groupcode = @GroupCode
--and t1.ssn = 410274975
and t1.payrollperiodenddate = @PPED
and t1.clockadjustmentno in('',' ')
and s1.clocktype <> 'T'
and s2.clocktype <> 'T'
and t1.Deptno = @DeptNo
and t1.hours > 0.00
and isnull(t1.OutUsercode,'') <> 'TRVL'
and t1.InSrc in('0','V','C')
and t1.Outsrc = '3'
order by t1.transdate, t1.inday, t1.intime


DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 02Sept2016 >--
DECLARE @SiteNo int
DECLARE @OrigSiteNo int
DECLARE @SSN int
DECLARE @TravelInPunch datetime
DECLARE @Comment varchar(500)
DECLARE @Count int
Set @Count = 0

OPEN cPunches

FETCH NEXT FROM cPunches into @RecordID, @SiteNo, @OrigSiteNo, @SSN, @TravelInPunch
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
  
    -- Update the Travel Transaction to have the correct siteno 
    -- Save Original Site No in OutSiteNo field. 
    -- Set OutUserCode to indicate that the record has already been processed.

    Update TimeHistory..tblTimeHistdetail
      Set SiteNo = @SiteNo,
          OutSiteNo = @OrigSiteNo,
          OutUserCode = 'TRVL'
    where RecordID = @RecordID

    -- Set Empl for recalc.
    --
    Update TimeHistory..tblEmplnames 
      Set NeedsRecalc = '1'
    where client = @client and groupcode = @groupcode and ssn = @ssn and payrollperiodenddate = @PPED
    Set @Count = @Count + 1
    -- Add Comment to time card to indicate that the site number was changed 
    --
    Set @Comment = 'The Site Number for Travel transaction with in punch = ' + convert(varchar(12),@TravelInPunch,101) + ' ' + convert(varchar(5),@TravelInPunch,108) + ' was changed from ' + ltrim(str(@OrigSiteno)) + ' to ' + ltrim(str(@siteNo)) + ' by the travel processing routine.'
    INSERT INTO [TimeHistory].[dbo].[tblTimeHistDetail_Comments]([Client], [GroupCode], [PayrollPeriodEndDate], [SSN], [CreateDate], [Comments], [UserID], [UserName], [ManuallyAdded])
    VALUES(@Client, @GroupCode, @PPED, @SSN, getdate(), @Comment, 0, 'TravelProcessing', '0')

	END
	FETCH NEXT FROM cPunches into @RecordID, @SiteNo, @OrigSiteNo, @SSN, @TravelInPunch
END

CLOSE cPunches
DEALLOCATE cPunches

-- Kick off recalc job
--

DECLARE @JobId int

IF @Count > 0 
BEGIN
  INSERT INTO Scheduler..tbljobs (ProgramName, TimeRequested, TimeQued, RequestedBy, Client, GroupCode, PayrollPeriodEndDate)
  VALUES ('EMPLCALC', getDate(), NULL, 'TravelTime', @Client, @GroupCode, @PPED)
  
  SELECT @JobID = SCOPE_IDENTITY()
  
  INSERT INTO Scheduler..tbljobs_Parms(JobID, ParmKey, Parm)
  VALUES (@JobID, 'CLIENT', @Client)
  
  INSERT INTO Scheduler..tbljobs_Parms(JobID, ParmKey, Parm)
  VALUES (@JobID, 'GROUP', ltrim(str(@GroupCode)) )
  
  INSERT INTO Scheduler..tbljobs_Parms(JobID, ParmKey, Parm)
  VALUES (@JobID, 'DATE', convert(varchar(12), @PPED, 101) )
END  
  







