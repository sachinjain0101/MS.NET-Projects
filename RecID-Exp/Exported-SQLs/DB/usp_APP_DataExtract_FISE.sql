CREATE Procedure [dbo].[usp_APP_DataExtract_FISE]
(
	@MinIncrement INT = 60, 
  @Client varchar(4) = 'FISE',
  @GroupCode INT = 12201,
  @PPED DATETIME = '4/1/2016'
)

AS

SET NOCOUNT ON 

DECLARE @LastRun datetime
DECLARE @LastRunRounded datetime
DECLARE @ThisRun DATETIME
DECLARE @Keyword varchar(25)
DECLARE @RecCount int
DECLARE @YesterdayMinus1 datetime
DECLARE @Now datetime
DECLARE @DayofWeek INT
DECLARE @sLiveDate VARCHAR(20)
DECLARE @LiveDate DATETIME 
Declare @Delim char(1)
Set @Delim = ','

Set @Now = getdate()
Set @DayofWeek = datepart(weekday,@now)
Set @YesterdayMinus1 = convert(varchar(12),getdate(),101)
Set @YesterdayMinus1 = dateadd(day,-2,@YesterdayMinus1)
Set @PPED = DATEADD(day, -8, @PPED)
Set @Thisrun = dateadd(day,-3,@Now)

DECLARE @tmpRecs TABLE
(
  GroupCode INT,
  SSN int,
  FileNo varchar(20),
	SiteNo INT,
	TimeZone VARCHAR(5),
  DeptNo int,
  mInTime datetime,
  mOutTime datetime,
  thdRecordID BIGINT  --< thdRecordID data type is converted from INT to BIGINT by Srinsoft on 29July2016 >--
)

Declare @tmpExtract TABLE
(
  GroupCode INT,
	EmplID VARCHAR(20),
	PunchDateTime DATETIME,
	Offset INT,
	DeptCode VARCHAR(50),
	PunchType VARCHAR(5),
	thdRecordID BIGINT,  --< thdRecordID data type is converted from INT to BIGINT by Srinsoft on 29July2016 >--
	LineOut VARCHAR(1000)
)

Declare @tmpExtractFinal TABLE
(
	[GroupCode] [int] NULL,
	[DateCreated] [datetime] NULL,
	[ThisRun] [datetime] NULL,
	[LastRun] [datetime] NULL,
	[LineOut] [varchar](300) NULL,
	thdRecordID BIGINT  --< thdRecordID data type is converted from INT to BIGINT by Srinsoft on 29July2016 >--
)


DECLARE cGroups CURSOR
READ_ONLY
FOR 
SELECT GroupCode, 
LiveDAte = RIGHT(ClientGroupID1,16)  
FROM TimeCurrent.dbo.tblClientGroups 
WHERE client = @Client 
AND RecordStatus = '1' 
AND IncludeInUpload = '1'
AND ClientGroupID1 <> ''

OPEN cGroups

FETCH NEXT FROM cGroups INTO @GroupCode, @sLiveDate 
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

    IF ISDATE(@sLiveDate) = 1
      SET @LiveDate = CAST(@sLiveDate AS DATETIME)
    ELSE
      SET @LiveDate = @LastRun

    DELETE FROM @tmpExtract
    DELETE FROM @tmpRecs

    Insert into @tmpRecs
    Select 
    t.GroupCode,
    en.SSN, 
    en.FileNo,
    t.SiteNo,
    sn.Timezone, 
    t.DeptNo, 
    mInTime = TimeHistory.dbo.PunchDateTime2(t.TransDate, t.InDay, t.InTime),
    mOutTime = TimeHistory.dbo.PunchDateTime2(t.TransDate, t.OutDay, t.OutTime),
    t.RecordID  
    from TimeHistory..tblTimeHistDetail as t with (nolock)
    Inner Join TimeCurrent..tblEmplNames as EN  with (nolock)
    On en.Client = t.Client 
    AND en.GroupCode = t.GroupCode 
    AND en.SSN = t.SSN
    INNER JOIN TimeCurrent..tblSiteNames AS sn WITH(NOLOCK)
    ON sn.client = t.Client
    AND sn.groupcode = t.GroupCode
    AND sn.siteno = t.siteno 
    where t.Client = @Client
    and t.GroupCode = @GroupCode
    and t.PayrollPeriodEndDate >= @PPED 
    AND t.transdate >= @thisRun
    and t.ClockAdjustmentNo in('',' ')

    Insert into @tmpExtract(GroupCode,EmplID,PunchDateTime,Offset,DeptCode,PunchType,thdRecordID,LineOut)
    Select 
    r.Groupcode
    ,r.FileNo
    ,r.mInTime
    ,CASE WHEN mIntime BETWEEN DATEADD(HOUR,z.offset2,z.GMTDstON) AND DATEADD(HOUR,z.offset1,z.GMTDstOFF) THEN z.Offset1 ELSE z.Offset2 END
    ,gd.ClientDeptCode2
    ,'In'
    ,thdRecordID
    ,''
    from @tmpRecs AS r
    INNER JOIN TimeCurrent..tblTimeZones AS Z (NOLOCK)
    ON z.Timezone = r.TimeZone
    INNER JOIN TimeCurrent..tblGroupDepts AS gd (NOLOCK)
    ON gd.client = @Client
    AND gd.groupcode = r.GroupCode
    AND gd.deptno = r.DeptNo
    where ISNULL(mInTime,'1/1/1970') >= @ThisRun 
    AND r.FileNo <> ''
    AND ISNULL(mInTime,'1/1/1970') >= @LiveDate
    UNION ALL 
    Select 
    r.Groupcode
    ,r.FileNo
    ,r.mOutTime
    ,CASE WHEN mOuttime BETWEEN DATEADD(HOUR,z.offset2,z.GMTDstON) AND DATEADD(HOUR,z.offset1,z.GMTDstOFF) THEN z.Offset1 ELSE z.Offset2 END
    ,gd.ClientDeptCode2
    ,'Out'
    ,thdRecordID
    ,''
    from @tmpRecs AS r
    INNER JOIN TimeCurrent..tblTimeZones AS Z (NOLOCK)
    ON z.Timezone = r.TimeZone
    INNER JOIN TimeCurrent..tblGroupDepts AS gd (NOLOCK)
    ON gd.client = @Client
    AND gd.groupcode = r.GroupCode
    AND gd.deptno = r.DeptNo
    where ISNULL(mOutTime,'1/1/1970') >= @ThisRun 
    AND r.FileNo <> ''
    AND ISNULL(mOutTime,'1/1/1970') >= @LiveDate 

    UPDATE @tmpExtract
	    SET Lineout = EmplID + @Delim + 
								    CONVERT(VARCHAR(32),PunchDateTime,126) + '-' + RIGHT('00' + LTRIM(STR(offset*-1)),2) + ':00' + @Delim + 
								    DeptCode + @Delim + 
								    PunchType

    insert into @tmpExtractFinal(GroupCode, DateCreated, ThisRun, LastRun, Lineout, thdRecordID )
    select x.GroupCode, @Now, @ThisRun, @LastRun, x.LineOut, x.thdRecordID 
    FROM @tmpExtract as X
    left Join (SELECT LineOut FROM refreshwork.[dbo].[tblPunchExtract] as w (NOLOCK) 
                WHERE w.Client = @Client 
                  AND w.GroupCode = @GroupCode 
                  AND w.DateCreated > @YesterdayMinus1) AS rw
    on rw.LineOut = x.lineout
    where isnull(rw.lineout,'') = ''

	END
	FETCH NEXT FROM cGroups INTO @GroupCode, @sLiveDate 
END

CLOSE cGroups
DEALLOCATE cGroups

--EMPLID,PUNCHDATETIME,TIMEENTRYCODE,PUNCHTYPE
--10049952	2015-08-02T23:00:00-05:00	Worked Time	Out


Set @RecCount = (select count(*) from @tmpExtractFinal )

IF @RecCount = 0
BEGIN
  Insert into refreshwork.[dbo].[tblPunchExtract](Client,Groupcode,DateCreated,ThisRun,LastRun,LineOut,thdRecordID)
  Values(@Client, @GroupCode, @Now, @ThisRun, @LastRun, '', 0)

  select Lineout = '' where 1 = 0
END
ELSE
BEGIN
  -- for archive,research and comparison
  --
  Insert into refreshwork.[dbo].[tblPunchExtract](Client,Groupcode,DateCreated,ThisRun,LastRun,LineOut,thdRecordID)
  Select @Client, GroupCode, DateCreated, ThisRun, LastRun, Lineout, thdRecordID from @tmpExtractFinal 

  Select SortID = 2, GroupCode, DateCreated, ThisRun, LastRun, Lineout from @tmpExtractFinal 
	UNION ALL
	SELECT Sortid = 0, GroupCode = @groupcode, DateCreated = @Now, ThisRun = @ThisRun, LastRun = @LastRun, LineOut = 'EMPLID,PUNCHDATETIME,TIMEENTRYCODE,PUNCHTYPE'
	ORDER BY SortID, LineOut

END

