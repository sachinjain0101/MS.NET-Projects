CREATE Procedure [dbo].[usp_APP_GenericDataExtract_CTC_CICO]
(
  @Client varchar(4),
  @GroupCode int,
  @PPED datetime
)
AS

SET NOCOUNT ON 


/*
Description	Adecco Extract Time
First Sign in – Shift 1	                              5:50 AM 
Any late Sign in for Shift 1 (including adjustments)	6:05 AM 
Shift 1 End. Shift 2 Start. Adjustments	              3:50 PM 
Late Sign in for Shift 2 (including adjustments)	    4:05 PM 
End of Shift 2 and adjustments	                      2:00 AM 

Record layout:
– FileNum (CTC Employee #), PrimSite, PrimDEPT, DivID, InTime, InSRC, OutTime, OutSRC

Select * from Scheduler..tblSysValues where Keyword like '%_PunchExtract'

*/

DECLARE @RecCount int
DECLARE @Now datetime
DECLARE @DayofWeek INT
Declare @Delim char(1)

Set @Delim = ','
Set @Now = getdate()
Set @DayofWeek = datepart(weekday,@now)
Set @PPED = DATEADD(day, -12, @PPED)

DECLARE @tmpRecs TABLE
(
  SSN int,
  FileNo varchar(20),
  LocationCode varchar(100),
  PrimaryDept int,
  DivisionID int,
  mInTime datetime,
  UserCode varchar(8),
  mOutTime datetime,
  OutUserCode varchar(8),
  fpTransDateTime datetime,
  RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 03Aug2016 >--
)
Insert into @tmpRecs
Select	en.SSN, 
		FileNo = CASE WHEN @Client = 'OLST' THEN CAST( case when isnumeric(isnull(en.FileNo,'0')) = 1 then en.FileNo else '0' end as int)
					  ELSE CAST(case when isnumeric(isnull(en.SubStatus6, '0')) = 1 then en.SubStatus6 else '0' end as int) END, 
		sn.LocationCode, 
		en.PrimaryDept, 
		DivisionID = isnull(en.DivisionID,0),
		mInTime = TimeHistory.dbo.PunchDateTime2(t.TransDate, t.InDay, t.InTime),
		t.UserCode,
		mOutTime = TimeHistory.dbo.PunchDateTime2(t.TransDate, t.OutDay, t.OutTime),
		t.OutUserCode,
		fpTransDateTime = fp.TransDateTime,
		t.RecordID  
--into #tmpRecs
from TimeHistory..tblTimeHistDetail as t with (nolock)
Inner Join TimeCurrent..tblEmplNames as EN  with (nolock)
On en.Client = t.Client and en.GroupCode = t.GroupCode and en.SSN = t.SSN
Inner Join TimeCurrent..tblSiteNames as sn with (nolock)
On sn.Client = t.Client and sn.GroupCode = t.GroupCode and sn.SiteNo = t.SiteNo 
Left Join TimeCurrent..tblFixedPunch as fp with (nolock)
on fp.origrecordid = t.RecordID 
where t.Client = @Client
and t.GroupCode = @GroupCode
and t.PayrollPeriodEndDate >= @PPED 
and t.ClockAdjustmentNo in('',' ')



Declare @tmpExtract TABLE
(
	[GroupCode] [int] NULL,
	[DateCreated] [datetime] NULL,
	[ThisRun] [datetime] NULL,
	[LastRun] [datetime] NULL,
	[LineOut] [varchar](300) NULL
)

Declare @tmpExtractFinal TABLE
(
	[GroupCode] [int] NULL,
	[DateCreated] [datetime] NULL,
	[ThisRun] [datetime] NULL,
	[LastRun] [datetime] NULL,
	[LineOut] [varchar](300) NULL
)


Insert into @tmpExtract(GroupCode, DateCreated, ThisRun, LastRun, 
						Lineout )
Select	@GroupCode, @Now, NULL, NULL,
		LineOut =	CASE WHEN @Client = 'OLST' THEN 'Adecco' WHEN @Client = 'MPOW' THEN 'Manpower' ELSE '' END + @Delim +
					right('000000000' + ltrim(str(FileNo)), 9) + @Delim +
					LocationCode + @Delim +
					ltrim(str(PrimaryDept)) + @Delim +
					LTRIM(str(DivisionID)) + @Delim + 
					case when isnull(mInTime,'1/1/1970') = '1/1/1970' then '' else convert(varchar(20), mInTime, 120) end + @Delim +
					isnull(UserCode,'') + @Delim +
					case when isnull(mOutTime,'1/1/1970') = '1/1/1970' then '' else convert(varchar(20), mOutTime,120) end + @Delim +
					isnull(OutUserCode,'')
from @tmpRecs 


insert into @tmpExtractFinal(GroupCode, DateCreated, ThisRun, LastRun, Lineout )
select x.GroupCode, x.DateCreated, NULL, NULL, x.LineOut 
from @tmpExtract as X
left Join refreshwork.[dbo].[tmpOLST_CTCExtract] as w
on w.groupcode = x.groupcode
and w.LineOut = x.lineout
where isnull(w.lineout, '') = ''

Set @RecCount = (select count(*) from @tmpExtractFinal )

IF @RecCount = 0
BEGIN
  Insert into refreshwork.[dbo].[tmpOLST_CTCExtract] (GroupCode, DateCreated, ThisRun, LastRun, Lineout )
  Values(@GroupCode, @Now, NULL, NULL, '')

  select Lineout = '' where 1 = 0
END
ELSE
BEGIN
  -- for archive,research and comparison
  --
  Insert into refreshwork.[dbo].[tmpOLST_CTCExtract] (GroupCode, DateCreated, ThisRun, LastRun, Lineout )
  Select GroupCode, DateCreated, NULL, NULL, Lineout from @tmpExtractFinal 

  Select GroupCode, DateCreated, ThisRun, LastRun, Lineout from @tmpExtractFinal 
 
END


IF @dayofweek = 7
BEGIN
  -- Every Saturday - delete any records older than 60 days
  --
  Set @Now = dateadd(day,-60,@now)
  delete from refreshwork.[dbo].[tmpOLST_CTCExtract] where datecreated <= @Now 

END
