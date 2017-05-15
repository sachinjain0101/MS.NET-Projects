CREATE PROCEDURE [dbo].[usp_RPT_DuplicateHours]
(
	@Client 			char(4),
	@Group			 	int,
	@Date				  datetime,
	@Sites 				varchar(1024),
	@Dept 				varchar(512),
  @Ref1         int,       -- Worked Adjustment Threshold
  @Ref2         varchar(10),   -- Trigger on Adj
  @Ref3         varchar(10),    -- Trigger on Punch
  @REF7         varchar(80)   -- Division Filter
)

AS

--*/

/*
DECLARE	@Client			char(4)
DECLARE @Group			int
DECLARE @Date			  datetime
DECLARE @Sites			varchar(1024)
DECLARE @Dept			  varchar(512)
DECLARE @Ref1       int
DECLARE @Ref2       varchar(10)
DECLARE @Ref3       varchar(10)

SELECT @Client = 'DAVI'
SELECT @Group = 300800
--SELECT @Group = 308800
SELECT @Date = '8/27/05'
SELECT @Sites = 'ALL'
--SELECT @Sites = 'ALL'
SELECT @Dept = 'ALL'
SELECT @Ref1 = 1
SELECT @Ref2 = 'YES'
SELECT @Ref3 = 'YES'
*/

SET NOCOUNT ON

DECLARE	@pos		int

--Print getdate()
IF ISNULL(@REF7,'') = '' 
  Set @REF7 = 'ALL'

Select t.RecordID, t.SSN, t.TransDAte, t.Hours, t.UserCode
Into #tmpTHD2
from TimeHistory..tblTimeHistDetail as t with(nolock)
Inner Join TimeCurrent..tblSiteNames as sn with(nolock)
on sn.Client = t.Client 
and sn.GroupCode = t.GroupCode 
and sn.SiteNo = t.SiteNo 
where t.client = @Client
and t.groupcode = @Group
and t.PayrollPeriodenddate = @Date
and TimeCurrent.dbo.fn_InCSV(@Ref7,ltrim(str(sn.Division)),1) = 1

--Print getdate()

CREATE INDEX [ix_SSN2] ON #tmpTHD2([SSN]) 

SELECT thd.RecordID, thd.SSN, empls.FileNo, empls.LastName + ', ' + empls.FirstName AS EmplName, 
  thd.TransDate, thd.Siteno, thd.InDay, thd.InTime, thd.OutDay, thd.OutTime, thd.ClockAdjustmentNo, thd.Hours, 
  adjs.Worked, adjs.AdjustmentName, adjs.reportcol,
  thd2.RecordID AS x, thd2.Hours AS y
INTO #tmpTHD
FROM TimeHistory..tblTimeHistDetail AS thd WITH(NOLOCK)
INNER JOIN TimeCurrent..tblEmplNames AS empls WITH(NOLOCK)
ON empls.Client = thd.Client
  AND empls.GroupCode = thd.GroupCode
  AND empls.SSN = thd.SSN
INNER JOIN TimeCurrent..tblSiteNames AS sn WITH(NOLOCK)
ON sn.Client = thd.Client
  AND sn.GroupCode = thd.GroupCode
  AND sn.SiteNo = thd.SiteNo 
Left Join TimeCurrent..tblAdjCodes AS adjs WITH(NOLOCK)
ON adjs.Client = thd.Client
  AND adjs.GroupCode = thd.GroupCode
  AND adjs.ClockAdjustmentNo = thd.ClockAdjustmentNo
LEFT JOIN #tmpThd2 as thd2
ON thd2.SSN = thd.SSN
  AND thd2.TransDate = thd.TransDate
  AND thd2.Hours = (-1) * thd.Hours
	AND thd2.UserCode NOT IN ('GSA','GSR')
WHERE thd.Client = @Client
  AND thd.GroupCode = @Group
  AND thd.PayrollPeriodEndDate = @Date
--  AND thd.SiteNo IN (SELECT SiteNo FROM #tmpSites)
--  AND thd.DeptNo IN (SELECT DeptNo FROM #tmpDept)
	AND thd.UserCode NOT IN ('GSA','GSR')
  AND empls.AgencyNo < (Case when @Client in('DAVI','DAVT','HCPA') then 5 else 99 end )
  AND thd2.RecordID IS NULL
  AND thd.Hours <> 0
  and TimeCurrent.dbo.fn_InCSV(@Ref7,ltrim(str(sn.Division)),1) = 1
--option(FORCE ORDER)

--CREATE INDEX [ix_SSN] ON #tmpTHD([SSN]) 
--CREATE INDEX [ix_recID] ON #tmpTHD([RecordID],[SSN]) 
--Print getdate()

SELECT DISTINCT
  'OVERLAP' AS DataType,
  Data1.TransDate AS TransDate,
  Data1.SSN AS SSN,
  Data1.FileNo as FileNo, 
  Data1.EmplName AS EmplName,
  Data1.SiteNo as SiteNo,
  Data2.SiteNo as SiteNo2,
  CONVERT(varchar(20), Data1.InTime, 8) + ' - ' + CONVERT(varchar(20), Data1.OutTime, 8) AS Trans1,
  CONVERT(varchar(20), Data2.InTime, 8) + ' - ' + CONVERT(varchar(20), Data2.OutTime, 8) AS Trans2
INTO #tmpOverlap
FROM #tmpTHD AS Data1
INNER JOIN #tmpTHD AS Data2
ON Data2.RecordID <> Data1.RecordID
  AND Data2.SSN = Data1.SSN
WHERE (((dbo.PunchDateTime(Data1.TransDate, Data1.InDay, Data1.InTime) BETWEEN
			  dateadd(mi,1,dbo.PunchDateTime(Data2.TransDate, Data2.InDay, Data2.InTime)) AND dateadd(mi,-1,dbo.PunchDateTime(Data2.TransDate, Data2.OutDay, Data2.OutTime))) OR
			 (dbo.PunchDateTime(Data1.TransDate, Data1.OutDay, Data1.OutTime) BETWEEN
			  dateadd(mi,1,dbo.PunchDateTime(Data2.TransDate, Data2.InDay, Data2.InTime)) AND dateadd(mi,-1,dbo.PunchDateTime(Data2.TransDate, Data2.OutDay, Data2.OutTime)))) OR
			(dbo.PunchDateTime(Data1.TransDate, Data1.InDay, Data1.InTime) = dbo.PunchDateTime(Data2.TransDate, Data2.InDay, Data2.InTime) AND
			dbo.PunchDateTime(Data1.TransDate, Data1.OutDay, Data1.OutTime) = dbo.PunchDateTime(Data2.TransDate, Data2.OutDay, Data2.OutTime) AND
			dbo.PunchDateTime(Data1.TransDate, Data1.InDay, Data1.InTime) <> dbo.PunchDateTime(Data1.TransDate, Data1.OutDay, Data1.OutTime)))
  AND Data1.ClockAdjustmentNo = ' '
  AND Data2.ClockAdjustmentNo = ' '

DECLARE @o_DataType as varchar(10)
DECLARE @o_TransDate as datetime
DECLARE @o_SSN as int
DECLARE @o_EmplName as varchar(100)
DECLARE @o_FileNo as varchar(20)
DECLARE @o_SiteNo as int
DECLARE @o_SiteNo2 as int
DECLARE @o_Trans1 as varchar(20)
DECLARE @o_Trans2 as varchar(20)

DECLARE @DupeCount as int

CREATE TABLE #tmpOverlapNoDupes (	DataType varchar(10),
																	TransDate datetime,
																	SSN int,
                                  FileNo varchar(20),
																	EmplName varchar(100),
																	SiteNo int,
																	SiteNo2 int,
																	Trans1 varchar(20),
																	Trans2 varchar(20))

DECLARE overlapCursor CURSOR
READ_ONLY
FOR SELECT *
		FROM #tmpOverlap

OPEN overlapCursor

FETCH NEXT FROM overlapCursor INTO @o_DataType, @o_TransDate, @o_SSN, @o_FileNo, @o_EmplName, @o_SiteNo, @o_SiteNo2, @o_Trans1, @o_Trans2
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN	

		SELECT @DupeCount = (	SELECT	Count(*)
													FROM 		#tmpOverlapNoDupes
													WHERE		DataType = @o_DataType
													AND			TransDate = @o_TransDate
													AND			SSN = @o_SSN
													AND			EmplName = @o_EmplName
													AND			Trans1 = @o_Trans2
													AND			Trans2 = @o_Trans1)

		IF (@DupeCount = 0)
		BEGIN
			INSERT INTO #tmpOverlapNoDupes (DataType,
																			TransDate,
																			SSN,
																			FileNo,
																			EmplName,
																			SiteNo,
																			SiteNo2,
																			Trans1,
																			Trans2)
			VALUES (@o_DataType,
							@o_TransDate, 
							@o_SSN, 
              @o_FileNo, 
							@o_EmplName, 
							@o_SiteNo, 
							@o_SiteNo2, 
							@o_Trans1, 
							@o_Trans2)
		END
	END
	FETCH NEXT FROM overlapCursor INTO @o_DataType, @o_TransDate, @o_SSN, @o_FileNo, @o_EmplName, @o_SiteNo, @o_SiteNo2, @o_Trans1, @o_Trans2
END
CLOSE overlapCursor
DEALLOCATE overlapCursor

-- Check for Duplicates...
--
--	

	Create table #tmpPunches
	(
		PPED date,
		GroupCode int,
		SSN int,
		Intime datetime,
		OutTime datetime,
		Hours numeric(7,2),
		ClkTransNo BIGINT  --< ClkTransNo data type is changed from  INT to BIGINT by Srinsoft on 11Oct2016 >--
	)

	Insert into #tmpPunches
	select PayrollPeriodenddate, 
	GroupCode, 
	SSN, 
	timehistory.dbo.PunchDateTime2(Transdate,inday,intime),  
	timehistory.dbo.PunchDateTime2(Transdate,Outday,Outtime),  
	Hours,
	ClkTransNo 
	from TimeHistory..tblTImeHistDetail with(nolock) 
	where client = @Client
	and groupcode = @Group
	and PayrollPeriodEndDate = @Date
	and clockadjustmentNo in('',' ')
	and TransType <> '7'
	and Inday < 8
	and outday < 8
	and hours <> 0

--Drop Table #tmpDups 
--Drop Table #tmpAllDups 

Create Table #tmpAllDups
(
	PPED date,
	GroupCode int,
	SSN int,
	InTIme datetime,
	Hours numeric(7,2),
	ClkTransNo BIGINT,  --< ClkTransNo data type is changed from  INT to BIGINT by Srinsoft on 11Oct2016 >--
	DupCount int
)

Insert into #tmpAllDups 
select PPED, GroupCode, SSN, InTIme, Hours, 0 , sum(1) 
from #tmpPunches 
group by PPED, GroupCOde, SSN, Intime , Hours
having sum(1) > 1 

Drop table #tmpPunches

--Print getdate()

SELECT 	DataType,
				TransDate,
				SSN,
        FileNo,
				EmplName,
				SiteNo,
				SiteNo2,
				Trans1,
				Trans2
FROM #tmpOverlapNoDupes

UNION ALL

SELECT DISTINCT
  'EXCESS ADJUSTMENT' AS DataType,
  Data1.TransDate AS TransDate,
  Data1.SSN AS SSN,
  Data1.FileNo as FileNo,
  Data1.EmplName AS EmplName,
  Data1.SiteNo as SiteNo,
  Data2.SiteNo as SiteNo2,
  '(' + LTRIM(RTRIM(Data1.AdjustmentName)) + ') ' + CAST(Data1.Hours AS varchar(20)) + ' hrs' AS Trans1,
  '(' + LTRIM(RTRIM(Data2.AdjustmentName)) + ') ' + CAST(Data2.Hours AS varchar(20)) + ' hrs' AS Trans2
FROM #tmpTHD AS Data1
INNER JOIN #tmpTHD AS Data2
ON Data2.RecordID > Data1.RecordID
  AND Data2.SSN = Data1.SSN
WHERE
  Data1.TransDate = Data2.TransDate
  AND (
    ((Data1.Hours >= @Ref1 AND Data2.Hours > 0) OR (Data1.Hours > 0 AND Data2.Hours >= @Ref1)) --OR
--    ((Data1.Hours <= (-1) * @Ref1 AND Data2.Hours <= (-1) * @Ref1) OR (Data1.Hours <= (-1) * @Ref1 AND Data2.Hours <= (-1) * @Ref1))
  )
  AND (Data1.Worked = 'Y' OR (Data1.reportcol IN('M','J','P') and @Client in ('DAVT','HCPA')))
  AND (Data2.Worked = 'Y' OR (Data2.reportcol IN('M','J','P') AND @Client IN ('DAVT','HCPA')))
  AND @Ref2 = 'YES'

UNION ALL

SELECT DISTINCT
  'EXCESS PUNCH' AS DataType,
  Data1.TransDate AS TransDate,
  Data1.SSN AS SSN,
  Data1.FileNo as FileNo,
  Data1.EmplName AS EmplName,
  Data1.SiteNo as SiteNo,
  Data2.SiteNo as SiteNo2,
  '(' + LTRIM(RTRIM(Data1.AdjustmentName)) + ') ' + CAST(Data1.Hours AS varchar(20)) + ' hrs' AS Trans1,
  CONVERT(varchar(20), Data2.InTime, 8) + ' - ' + CONVERT(varchar(20), Data2.OutTime, 8) AS Trans2
FROM #tmpTHD AS Data1
INNER JOIN #tmpTHD AS Data2
ON Data2.RecordID <> Data1.RecordID
  AND Data2.SSN = Data1.SSN
WHERE
  Data1.TransDate = Data2.TransDate
  AND Data1.Hours >= @Ref1 
  AND Data1.Worked = 'Y' 
  AND Data2.ClockAdjustmentNo = ' '
  AND @Ref3 = 'YES'
UNION ALL

Select 'DUPLICATE PUNCH' as DataType,
t.TransDate,
d.SSN,
en.FileNo,
EmplName = en.LastName + ',' + en.FirstName,
t.SiteNo,
t.SiteNo,
Trans1 = convert(varchar(5),t.InTime,108) + ' - ' + convert(varchar(5),t.OutTime,108),
Trans2 = ''
from #tmpAllDups as d
inner Join TImeCurrent..tblEmplNames as en with(nolock)
on en.client = @Client
and en.groupcode = d.groupcode
and en.ssn = d.ssn
Inner Join Timehistory..tblTimeHistDetail as t with(nolock)
on t.client = @Client
and t.groupcode = d.groupcode
and t.ssn = d.ssn
and t.payrollperiodenddate = d.PPED
and timehistory.dbo.PunchDateTime2(t.Transdate,t.inday,t.intime) = d.Intime

ORDER BY SSN, TransDate, DataType, Trans1

--DROP TABLE #tmpSites
--DROP TABLE #tmpDept
DROP TABLE #tmpTHD2
DROP TABLE #tmpTHD
DROP TABLE #tmpOverlap
DROP TABLE #tmpOverlapNoDupes


--Print getdate()


