CREATE         Procedure [dbo].[usp_RPT_WAFF_XMAS] 
(
	@Client		varchar(4),
  @Date     datetime,
	@Group		int,
	@Ref1		  int,
	@Sites 		varchar(1024),
	@Dept 		varchar(512),
	@Shift 		varchar(64)
)

AS

--*/
/*
--DEBUG STUFF...
DECLARE	@Client		varchar(4)
DECLARE	@Group		int
DECLARE	@Ref1		int
DECLARE	@Sites 		varchar(1024)
DECLARE	@Dept 		varchar(512)
DECLARE	@Shift 		varchar(64)

SELECT	@Client = 'WAFF'
SELECT	@Group = 750000
SELECT	@Ref1 = 2004
SELECT	@Sites = '78'
SELECT	@Dept = 'ALL'
SELECT	@Shift = 'ALL'

DROP TABLE #tmpDept
DROP TABLE #tmpSites
DROP TABLE #tmpTHD

*/

SET NOCOUNT ON

DECLARE	@PPED		datetime
DECLARE	@PPED2	datetime
DECLARE	@StartDate	datetime
DECLARE @StartTime	datetime
DECLARE @StartDateTime  datetime
DECLARE	@EndDate	datetime
DECLARE	@EndTime	datetime
DECLARE @EndDateTime    datetime
DECLARE @MidDate	datetime


IF @Ref1 = 2000
BEGIN
	SELECT @PPED = '12/27/00'
  SET @PPED2 = @PPED
	SELECT @StartDate = '12/24/00'
	SELECT @StartTime = '12/30/1899 21:00:00'
	SELECT @EndDate = '12/26/00'
	SELECT @EndTime = '12/30/1899 01:00:00'
	SELECT @MidDate = '12/25/00'
END
IF @Ref1 = 2001
BEGIN
	SELECT @PPED = '12/26/01'
  SET @PPED2 = @PPED
	SELECT @StartDate = '12/24/01'
	SELECT @StartTime = '12/30/1899 21:00:00'
	SELECT @EndDate = '12/26/01'
	SELECT @EndTime = '12/30/1899 01:00:00'
	SELECT @MidDate = '12/25/01'
END
IF @Ref1 = 2002
BEGIN
	SELECT @PPED = '12/25/02'
  SET @PPED2 = @PPED
	SELECT @StartDate = '12/24/02'
	SELECT @StartTime = '12/30/1899 21:00:00'
	SELECT @EndDate = '12/26/02'
	SELECT @EndTime = '12/30/1899 01:00:00'
	SELECT @MidDate = '12/25/02'
END
IF @Ref1 = 2004
BEGIN
	SELECT @PPED = '12/29/04'
  SET @PPED2 = @PPED
	SELECT @StartDate = '12/24/04'
	SELECT @StartTime = '12/30/1899 21:00:00'
  SET @StartDateTime = '12/24/04 21:00:00'
	SELECT @EndDate = '12/26/04'
	SELECT @EndTime = '12/30/1899 01:00:00'
  SET @EndDateTime = '12/26/04 01:00:00'
	SELECT @MidDate = '12/25/04'
END

IF @Ref1 = 2005
BEGIN
	SELECT @PPED = '12/28/05'
  SET @PPED2 = @PPED
	SELECT @StartDate = '12/24/05'
	SELECT @StartTime = '12/30/1899 21:00:00'
  SET @StartDateTime = '12/24/05 21:00:00'
	SELECT @EndDate = '12/26/05'
	SELECT @EndTime = '12/30/1899 01:00:00'
  SET @EndDateTime = '12/26/05 01:00:00'
	SELECT @MidDate = '12/25/05'
END

IF @Ref1 = 2006
BEGIN
	SELECT @PPED = '12/27/06'
  SET @PPED2 = @PPED
	SELECT @StartDate = '12/24/06'
	SELECT @StartTime = '12/30/1899 21:00:00'
  SET @StartDateTime = '12/24/06 21:00:00'
	SELECT @EndDate = '12/26/06'
	SELECT @EndTime = '12/30/1899 01:00:00'
  SET @EndDateTime = '12/26/06 01:00:00'
	SELECT @MidDate = '12/25/06'
END

IF @Ref1 = 2007
BEGIN
	SELECT @PPED = '12/26/07'
  SET @PPED2 = @PPED
	SELECT @StartDate = '12/24/07'
	SELECT @StartTime = '12/30/1899 21:00:00'
  SET @StartDateTime = '12/24/07 21:00:00'
	SELECT @EndDate = '12/26/07'
	SELECT @EndTime = '12/30/1899 01:00:00'
  SET @EndDateTime = '12/26/07 01:00:00'
	SELECT @MidDate = '12/25/07'
END

IF @Ref1 = 2008
BEGIN
  IF @Date = '12/24/08'
  BEGIN
  	SELECT @PPED = '12/24/08'
    SET @PPED2 = '12/24/08'
  	SELECT @StartDate = '12/24/08'
  	SELECT @StartTime = '12/30/1899 21:00:00'
    SET @StartDateTime = '12/24/08 21:00:00'
  	SELECT @EndDate = '12/25/08'
  	SELECT @EndTime = '12/30/1899 07:00:00'
    SET @EndDateTime = '12/25/08 07:00:00'
  	SELECT @MidDate = '12/25/08'
  END
  ELSE IF @Date = '12/31/08'
  BEGIN
  	SELECT @PPED = '12/31/08'
    SET @PPED2 = '12/31/08'
  	SELECT @StartDate = '12/25/08'
  	SELECT @StartTime = '12/30/1899 07:00:00'
    SET @StartDateTime = '12/25/08 07:00:00'
  	SELECT @EndDate = '12/26/08'
  	SELECT @EndTime = '12/30/1899 07:00:00'
    SET @EndDateTime = '12/26/08 07:00:00'
  	SELECT @MidDate = '12/25/08'
  END
  ELSE
  BEGIN
  	SELECT @PPED = '12/24/08'
    SET @PPED2 = '12/31/08'
  	SELECT @StartDate = '12/24/08'
  	SELECT @StartTime = '12/30/1899 21:00:00'
    SET @StartDateTime = '12/24/08 21:00:00'
  	SELECT @EndDate = '12/26/08'
  	SELECT @EndTime = '12/30/1899 09:00:00'
    SET @EndDateTime = '12/26/08 09:00:00'
  	SELECT @MidDate = '12/25/08'
  END
END

CREATE TABLE #tmpSites ([SiteNo] [int] NOT NULL)

DECLARE	@pos		int

IF @Sites = 'ALL' OR @Sites = '' OR @Sites IS NULL
BEGIN
	INSERT INTO #tmpSites (SiteNo) 
		SELECT DISTINCT SiteNo
		FROM tblTimeHistDetail 
		WHERE Client = @Client AND GroupCode = @Group AND PayrollPeriodEndDate >= dateadd(day, -7, getdate())
END
ELSE
BEGIN
	SELECT @pos = CharIndex(',', @Sites, 0)
	WHILE @pos > 0
	BEGIN
		INSERT INTO #tmpSites (SiteNo) VALUES (CAST (Substring(@Sites, 1, @pos - 1) AS int))
		SELECT @Sites = Substring(@Sites, @pos + 1, Len(@Sites) - @pos)
		SELECT @pos = CharIndex(',', @Sites, 0)
	END
	INSERT INTO #tmpSites (SiteNo) VALUES (CAST (@Sites AS int))
END

CREATE TABLE #tmpDept ([DeptNo] [int] NOT NULL)

IF @Dept = 'ALL' OR @Dept = '' OR @Dept IS NULL
BEGIN
	INSERT INTO #tmpDept (DeptNo) 
		SELECT DISTINCT DeptNo
		FROM tblTimeHistDetail 
		WHERE Client = @Client AND GroupCode = @Group  AND PayrollPeriodEndDate >= dateadd(day, -7, getdate())
END
ELSE
BEGIN
	SELECT @pos = CharIndex(',', @Dept, 0)
	WHILE @pos > 0
	BEGIN
		INSERT INTO #tmpDept (DeptNo) VALUES (CAST (Substring(@Dept, 1, @pos - 1) AS int))
		SELECT @Dept = Substring(@Dept, @pos + 1, Len(@Dept) - @pos)
		SELECT @pos = CharIndex(',', @Dept, 0)
	END
	INSERT INTO #tmpDept (DeptNo) VALUES (CAST (@Dept AS int))
END

SELECT thd.RecordID, thd.SSN, empls.Lastname, empls.Firstname, thd.SiteNo, xref.ClientDeptCode as PayCode, thd.DeptNo, thd.ShiftNo, 
	Inday = case when thd.Inday < 10 
               then dbo.PunchDateTime2(TransDate, InDay, '00:00:00.000') 
               Else dbo.PunchDateTime2(TransDate, OutDay, '00:00:00.000')      
               End,
  InTime = case when thd.InDay < 10 then thd.InTime else thd.OutTime end,
	OutDay = case when thd.OutDay < 10
                Then dbo.PunchDateTime2(TransDate, OutDay, '00:00:00.000')
                Else dbo.PunchDateTime2(TransDate, InDay, '00:00:00.000') 
                End,
  OutTime = case when thd.OutDay < 10 then thd.OutTime else thd.InTime end,
	RegHours as Hours, thd.PayRate as Rate, (RegHours * thd.PayRate) as Total_Pay, empls.FileNo,
	22 as Xmas_Code, (RegHours * thd.PayRate)*(0.5) as Xmas_Pay
INTO #tmpTHD
FROM tblTimeHistDetail as thd
INNER JOIN TimeCurrent..tblEmplNames as empls
ON thd.SSN = empls.SSN AND thd.Client = empls.Client AND thd.GroupCode = empls.GroupCode
INNER JOIN TimeCurrent..tblClientDeptXRef as xref
ON thd.Client = xref.Client AND thd.DeptNo = xref.DeptNo
WHERE thd.Client = @Client AND thd.GroupCode = @Group --AND thd.SSN = 422066146
	AND PayrollPeriodEndDate in(@PPED, @PPED2)
  AND dbo.PunchDateTime2(TransDate, OutDay, OutTime) > @StartDateTime
  AND dbo.PunchDateTime2(TransDate, InDay, InTime) < @EndDateTime
/*
	AND
	(
		(DateAdd(Day, (thd.InDay - DatePart(dw, thd.PayrollPeriodEndDate)), thd.PayrollPeriodEndDate) = @MidDate) OR
		(DateAdd(Day, (thd.OutDay - DatePart(dw, thd.PayrollPeriodEndDate)), thd.PayrollPeriodEndDate) = @MidDate) OR
		(
			(DateAdd(Day, (thd.OutDay - DatePart(dw, thd.PayrollPeriodEndDate)), thd.PayrollPeriodEndDate) = @StartDate) AND
			(thd.OutTime > @StartTime)
		) OR
		(
			(DateAdd(Day, (thd.InDay - DatePart(dw, thd.PayrollPeriodEndDate)), thd.PayrollPeriodEndDate) = @EndDate) AND
			(thd.InTime < @EndTime)
		)
	)
*/
	AND thd.SiteNo IN (SELECT SiteNo FROM #tmpSites)
	AND thd.DeptNo IN (SELECT DeptNo FROM #tmpDept)
ORDER BY thd.SiteNo ASC, empls.Lastname ASC, thd.SSN ASC

DECLARE @RecordID	BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 01Sept2016 >--
DECLARE @SSN		int
DECLARE @Lastname	varchar(100)
DECLARE @Firstname	varchar(100)
DECLARE @SiteNo		int
DECLARE @PayCode	varchar(3)
DECLARE @DeptNo		int
DECLARE @ShiftNo	int
DECLARE @InDay		datetime
DECLARE @InTime		datetime
DECLARE @OutDay		datetime
DECLARE @OutTime	datetime
DECLARE @Hours		Numeric(5,2)
DECLARE @Rate		Numeric(7,2)
DECLARE @Total_Pay	Numeric(7,2)
DECLARE @FileNo		int
DECLARE @Xmas_Code	int
DECLARE @Xmas_Pay	Numeric(7,2)
DECLARE @NeedsRecalc  tinyint

--SELECT * FROM #tmpTHD

DECLARE curTHD CURSOR FOR 
SELECT * FROM #tmpTHD

OPEN curTHD
FETCH NEXT FROM curTHD
INTO @RecordID, @SSN, @Lastname, @Firstname, @SiteNo, @PayCode, @DeptNo, @ShiftNo, @InDay, @InTime, @OutDay, @OutTime, @Hours, @Rate, @Total_Pay, @FileNo, @Xmas_Code, @Xmas_Pay
WHILE @@FETCH_STATUS = 0
BEGIN
  SET @NeedsRecalc = 0

	IF @InDay = @StartDate AND @InTime < @StartTime
	BEGIN
		SELECT @InTime = @StartTime
    SET @NeedsRecalc = 1
	END
	IF @OutDay = @EndDate AND @OutTime > @EndTime
	BEGIN
		SELECT @OutTime = @EndTime
    SET @NeedsRecalc = 1
	END
	SELECT @Hours = DateDiff(
		minute, 
		DateAdd(hour, DatePart(hour, @InTime), DateAdd(minute, DatePart(minute, @InTime), @InDay)),
		DateAdd(hour, DatePart(hour, @OutTime), DateAdd(minute, DatePart(minute, @OutTime), @OutDay))
	) / 60.00
	SELECT @Total_Pay = (@Hours * @Rate)
	SELECT @Xmas_Pay = (0.5)*@Total_Pay
	
	UPDATE #tmpTHD SET 
		InTime = @InTime, 
		OutTime = @OutTime, 
		Hours = CASE @NeedsRecalc WHEN 1 THEN @Hours ELSE Hours END,
		Total_Pay = @Total_Pay,
		Xmas_Pay = @Xmas_Pay
	WHERE RecordID = @RecordID

	FETCH NEXT FROM curTHD
	INTO @RecordID, @SSN, @Lastname, @Firstname, @SiteNo, @PayCode, @DeptNo, @ShiftNo, @InDay, @InTime, @OutDay, @OutTime, @Hours, @Rate, @Total_Pay, @FileNo, @Xmas_Code, @Xmas_Pay
END
CLOSE curTHD

DEALLOCATE curTHD

SELECT * FROM #tmpTHD
ORDER BY SiteNo ASC, Lastname ASC, SSN ASC










