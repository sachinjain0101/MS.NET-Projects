Create PROCEDURE [dbo].[usp_Web1_GetMissingPunches] (
  @UserID           int,
  @Client           varchar(4),
  @GroupCode        int,
  @PPED             datetime,
  @SiteNo           int,
  @ClusterID        int,
  @SSN              int = 0
) AS

SET NOCOUNT ON
--*/

/*
DECLARE  @UserID           int
DECLARE  @Client           varchar(4)
DECLARE  @GroupCode        int
DECLARE  @SiteNo           int
DECLARE  @PPED             datetime
DECLARE  @ClusterID        int
DECLARE  @SSN              int

SET @UserID           = 4
SET @Client           = 'CIG1'
SET @GroupCode        = 900000
SET @SiteNo           = 0
SET @PPED             = '11/12/05'
SET @ClusterID        = 4
SET @SSN              = 999001779
*/

CREATE TABLE #tmpMPs (
  RecordID  BIGINT,  --< RecordId data type is changed from  INT to BIGINT by Srinsoft on 08Sept2016 >--
  SSN       int, EmplRecordID  int,
  SiteNo    int, DeptNo        int, ShiftNo   int,
  InDayAbr  varchar(3), OutDayAbr   varchar(3),
  InSrcAbr  varchar(4), OutSrcAbr   varchar(4),
  InDateTime  datetime, OutDateTime datetime,
  TransDate datetime,
  InDay     smallint,   InTime      datetime,
  OutDay    smallint,   OutTime     datetime,
  UserCode  varchar(4), OutUserCode varchar(4),
  LastName  varchar(100), FirstName varchar(100),
  ShiftStart  datetime,   ShiftEnd  datetime
)

DECLARE @MissingPunchRange numeric(7,3)

Set @MissingPunchRange = (Select MissingPunchRangeInHours from Timecurrent..tblClientGroups where Client = @Client and groupcode = @Groupcode)
IF @MissingPunchRange is NULL
  Set @MissingPunchRange = 9.00

Set @MissingPunchRange = @MissingPunchRange * 60.00

INSERT INTO #tmpMPs
  SELECT thd.RecordID,
    thd.SSN,
    TCempls.RecordID AS EmplRecordID, 
    thd.SiteNo, thd.DeptNo, thd.ShiftNo,
    InDayDef.DayAbrev AS InDayAbr, 
    OutDayDef.DayAbrev AS OutDayAbr,
    CASE ISNULL(InSrc.SrcAbrev, '') WHEN '' THEN thd.UserCode ELSE InSrc.SrcAbrev END AS InSrcAbr, 
    CASE ISNULL(OutSrc.SrcAbrev, '') WHEN '' THEN thd.UserCode ELSE OutSrc.SrcAbrev END AS OutSrcAbr, 
    dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime) AS InDateTime,
    dbo.PunchDateTime2(thd.TransDate, thd.OutDay, thd.OutTime) AS OutDateTime,
    thd.TransDate, thd.InDay, thd.InTime, thd.OutDay, thd.OutTime, 
    thd.UserCode, CASE ISNULL(thd.OutUserCode, '') WHEN '' THEN thd.UserCode ELSE thd.OutUserCode END AS OutUserCode,
    TCempls.LastName, TCempls.FirstName,
    NULL, NULL
  FROM TimeHistory..tblEmplNames empls
  INNER JOIN TimeHistory..tblTimeHistDetail thd
  ON thd.Client = empls.Client
    AND thd.GroupCode = empls.GroupCode
    AND thd.PayrollPeriodEndDate = empls.PayrollPeriodEndDate
    AND thd.SSN = empls.SSN
    AND (
      thd.InDay IN (10, 11) OR (
        thd.OutDay IN (10, 11)
        AND (
          DATEDIFF("n", dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime), GETDATE()) >= @MissingPunchRange
          OR dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime) <> (SELECT MAX(dbo.PunchDateTime2(TransDate, InDay, InTime)) FROM tblTimeHistDetail WHERE Client = thd.Client AND GroupCode = thd.GroupCode AND SSN = thd.SSN AND PayrollPeriodEndDate = thd.PayrollPeriodEndDate)
					OR @PPED < (SELECT MAX(PayrollPeriodEndDate) from tblPeriodEndDates WHERE Client = @Client and GroupCode = @GroupCode)				
--          OR (SELECT ClockType FROM TimeCurrent..tblSiteNames WHERE Client = thd.Client AND GroupCode = thd.GroupCode AND SiteNo = thd.SiteNo) <> 'T'
        )
      )
    )
  INNER JOIN TimeCurrent..tblEmplNames AS TCempls
  ON TCempls.Client = empls.Client
    AND TCempls.GroupCode = empls.GroupCode
    AND TCempls.SSN = empls.SSN
  LEFT JOIN tblDayDef InDayDef ON InDayDef.DayNo = thd.InDay
  LEFT JOIN tblDayDef OutDayDef 
  ON OutDayDef.DayNo = (
    CASE WHEN thd.OutDay IN (10, 11) AND thd.OutTime <> '1899-12-30 00:00:00.000'
    THEN
      CASE WHEN thd.OutTime >= thd.InTime THEN thd.InDay ELSE (thd.InDay + 1) % 7 END
    ELSE thd.OutDay END
  )
  LEFT JOIN TimeCurrent.dbo.tblInOutSrc InSrc ON InSrc.Src = thd.InSrc
  LEFT JOIN TimeCurrent.dbo.tblInOutSrc OutSrc ON OutSrc.Src = thd.OutSrc
  
  WHERE empls.Client = @Client
    AND empls.GroupCode = @GroupCode
    AND empls.PayrollPeriodEndDate = @PPED
    AND empls.MissingPunch > 0
    AND (empls.SSN IN (SELECT SSN FROM tblEmplSites WHERE Client = @Client AND GroupCode = @GroupCode AND SSN = empls.SSN AND PayrollPeriodEndDate = @PPED AND SiteNo = @SiteNo) OR @SiteNo = 0)
  	AND	dbo.usp_GetTimeHistoryClusterDefAsFn (
							empls.GroupCode,
							thd.SiteNo,
							thd.DeptNo,
							thd.AgencyNo,
							empls.ssn,
							empls.DivisionID,
							thd.ShiftNo,
							@ClusterID) = 1
    AND (empls.SSN = @SSN OR @SSN = 0)
  ORDER BY empls.SSN, thd.TransDate, 
    ISNULL(dbo.PunchDateTime(thd.TransDate, thd.InDay, thd.InTime), dbo.PunchDateTime(thd.TransDate, thd.OutDay, thd.OutTime))

UPDATE #tmpMPs SET
InTime = CAST(CONVERT(varchar(5), InTime, 8) as datetime),
OutTime = CAST(CONVERT(varchar(5), OutTime, 8) as datetime)

--SELECT * FROM #tmpMPs

DECLARE csrMPs CURSOR READ_ONLY
FOR 
  SELECT RecordID, SSN, SiteNo, DeptNo, TransDate FROM #tmpMPs

DECLARE @tmpRecordID      BIGINT  --< @tmpRecordId data type is changed from  INT to BIGINT by Srinsoft on 08Sept2016 >--
DECLARE @tmpSSN           int
DECLARE @tmpSiteNo        int
DECLARE @tmpDeptNo        int
DECLARE @tmpTransDate     datetime

OPEN csrMPs

FETCH NEXT FROM csrMPs INTO @tmpRecordID, @tmpSSN, @tmpSiteNo, @tmpDeptNo, @tmpTransDate
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
    IF (
      SELECT COUNT(RecordID)
      FROM TimeCurrent..tblDeptShifts
      WHERE Client = @Client
        AND GroupCode = @GroupCode
        AND SiteNo = @tmpSiteNo
        AND DeptNo = @tmpDeptNo
        AND RecordStatus = '1'
    ) = 0
    BEGIN
      SET @tmpDeptNo = 99
    END

    DECLARE @ShiftRecordID    int

    SET @ShiftRecordID = ISNULL((
      SELECT TOP 1 shifts.RecordID
  /*  
        SELECT shifts.RecordID,
        shifts.ShiftStart, shifts.ShiftEnd, sites.ShiftInWindow, sites.ShiftOutWindow, 
        DATEADD(minute, sites.ShiftInWindow * (-1), shifts.ShiftStart),
        DATEADD(minute, sites.ShiftInWindow, shifts.ShiftStart),
        DATEADD(minute, sites.ShiftOutWindow * (-1), shifts.ShiftEnd),
        DATEADD(minute, sites.ShiftOutWindow, shifts.ShiftEnd),
      *
  */
      FROM #tmpMPs AS mps
      INNER JOIN TimeCurrent..tblDeptShifts AS shifts
      ON shifts.Client = @Client
        AND shifts.GroupCode = @GroupCode
        AND shifts.SiteNo = @tmpSiteNo
        AND shifts.DeptNo = @tmpDeptNo
        AND shifts.RecordStatus = '1'
      INNER JOIN TimeCurrent..tblSiteNames AS sites
      ON sites.Client = @Client
        AND sites.GroupCode = @GroupCode
        AND sites.SiteNo = @tmpSiteNo
      WHERE mps.RecordID = @tmpRecordID AND (
        (
          mps.InDay BETWEEN 1 AND 7
          AND mps.InTime
            BETWEEN DATEADD(minute, sites.ShiftInWindow * (-1), CAST(CONVERT(varchar(5), shifts.ShiftStart, 8) as datetime))
                AND DATEADD(minute, sites.ShiftInWindow, CAST(CONVERT(varchar(5), shifts.ShiftStart, 8) as datetime))
        ) OR (
          mps.OutDay BETWEEN 1 AND 7
          AND mps.OutTime
            BETWEEN DATEADD(minute, sites.ShiftOutWindow * (-1), CAST(CONVERT(varchar(5), shifts.ShiftEnd, 8) as datetime))
                AND DATEADD(minute, sites.ShiftOutWindow, CAST(CONVERT(varchar(5), shifts.ShiftEnd, 8) as datetime))
        )
      )
    ), 0)

    IF @ShiftRecordID <> 0
    BEGIN
--      PRINT @ShiftRecordID

      DECLARE @ShiftStart     datetime
      DECLARE @ShiftEnd       datetime
      DECLARE @ApplyString    char(7)
      DECLARE @PunchDate      datetime
      DECLARE @ShiftNo        int

      SELECT @ShiftStart = ShiftStart, @ShiftEnd = ShiftEnd, @ShiftNo = ShiftNo,
        @ApplyString = ApplyDay1 + ApplyDay2 + ApplyDay3 + ApplyDay4 + ApplyDay5 + ApplyDay6 + ApplyDay7
      FROM TimeCurrent..tblDeptShifts
      WHERE RecordID = @ShiftRecordID

      IF @ShiftStart > @ShiftEnd
        SET @PunchDate = DATEADD(day, 1, @tmpTransDate)
      ELSE
        SET @PunchDate = @tmpTransDate

      IF SUBSTRING(@ApplyString, DATEPART(weekday, @PunchDate), 1) = '1'
      BEGIN
        IF (
          SELECT COUNT(RecordID)
          FROM tblTimeHistDetail
          WHERE Client = @Client
            AND GroupCode = @GroupCode
            AND PayrollPeriodEndDate = @PPED
            AND SSN = @tmpSSN
            AND TransDate = @tmpTransDate
            AND RecordID <> @tmpRecordID
            AND dbo.PunchDateTime2(@PunchDate, DATEPART(weekday, @PunchDate), @ShiftStart)
              <= dbo.PunchDateTime2(TransDate, OutDay, OutTime)
            AND (SELECT dbo.PunchDateTime2(TransDate, OutDay, OutTime) FROM #tmpMPs WHERE RecordID = @tmpRecordID)
              >= dbo.PunchDateTime2(TransDate, OutDay, OutTime)
            AND dbo.PunchDateTime2(TransDate, OutDay, OutTime) <> dbo.PunchDateTime2(TransDate, InDay, InTime)
        ) = 0
        BEGIN
          UPDATE #tmpMPs SET 
            ShiftNo = @ShiftNo, ShiftStart = @ShiftStart, ShiftEnd = @ShiftEnd,
            InDateTime = (
              CASE WHEN InDay BETWEEN 1 AND 7 THEN InDateTime 
              ELSE dbo.PunchDateTime2(@PunchDate, DATEPART(weekday, @PunchDate), @ShiftStart)
              END
            )
          WHERE RecordID = @tmpRecordID
        END

        IF (
          SELECT COUNT(RecordID)
          FROM tblTimeHistDetail
          WHERE Client = @Client
            AND GroupCode = @GroupCode
            AND PayrollPeriodEndDate = @PPED
            AND SSN = @tmpSSN
            AND TransDate = @tmpTransDate
            AND RecordID <> @tmpRecordID
            AND dbo.PunchDateTime2(@PunchDate, DATEPART(weekday, @PunchDate), @ShiftEnd)
              >= dbo.PunchDateTime2(TransDate, InDay, InTime)
            AND (SELECT dbo.PunchDateTime2(TransDate, InDay, InTime) FROM #tmpMPs WHERE RecordID = @tmpRecordID)
              <= dbo.PunchDateTime2(TransDate, InDay, InTime)
            AND dbo.PunchDateTime2(TransDate, OutDay, OutTime) <> dbo.PunchDateTime2(TransDate, InDay, InTime)
        ) = 0
          UPDATE #tmpMPs SET 
            ShiftNo = @ShiftNo, ShiftStart = @ShiftStart, ShiftEnd = @ShiftEnd,
            OutDateTime = (
              CASE WHEN OutDay BETWEEN 1 AND 7 THEN OutDateTime 
              ELSE dbo.PunchDateTime2(@PunchDate, DATEPART(weekday, @PunchDate), @ShiftEnd)
              END
            )
        WHERE RecordID = @tmpRecordID
      END
    END
	END
  FETCH NEXT FROM csrMPs INTO @tmpRecordID, @tmpSSN, @tmpSiteNo, @tmpDeptNo, @tmpTransDate
END

CLOSE csrMPs
DEALLOCATE csrMPs

SELECT * FROM (
  SELECT MP = 1, *, 
    (CAST(
      CASE WHEN mps.InTime <> '1900-01-01 00:00:00.000' AND mps.OutTime <> '1900-01-01 00:00:00.000'
      THEN
        CASE WHEN mps.OutTime >= mps.InTime 
        THEN 
          DATEDIFF(minute, mps.InTime, mps.OutTime)
        ELSE 
          (24 - DATEDIFF(minute, mps.OutTime, mps.InTime))
        END
      ELSE
        DATEDIFF(minute, mps.InDateTime, mps.OutDateTime)
      END
    AS numeric(7,2)) / 60) AS Hours
  FROM #tmpMPs mps
  
  UNION ALL
  
  SELECT DISTINCT 
    CASE WHEN (
      DATEDIFF("n", dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime), GETDATE()) < @MissingPunchRange
      AND dbo.PunchDateTime2(thd.TransDate, thd.OutDay, thd.OutTime) IS NULL
      AND dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime) = (SELECT MAX(dbo.PunchDateTime2(TransDate, InDay, InTime)) FROM tblTimeHistDetail WHERE Client = thd.Client AND GroupCode = thd.GroupCode AND SSN = thd.SSN AND PayrollPeriodEndDate = thd.PayrollPeriodEndDate)
      --AND (SELECT ClockType FROM TimeCurrent..tblSiteNames WHERE Client = thd.Client AND GroupCode = thd.GroupCode AND SiteNo = thd.SiteNo) = 'T'
    )
    THEN 2
    ELSE 0
    END AS MP,
    thd.RecordID, thd.SSN, TCempls.RecordID AS EmplRecordID,
    thd.SiteNo, thd.DeptNo, thd.ShiftNo,
    InDayDef.DayAbrev AS InDayAbr, 
    OutDayDef.DayAbrev AS OutDayAbr,
    CASE ISNULL(InSrc.SrcAbrev, '') WHEN '' THEN thd.UserCode ELSE InSrc.SrcAbrev END AS InSrcAbr, 
    CASE ISNULL(OutSrc.SrcAbrev, '') WHEN '' THEN thd.UserCode ELSE OutSrc.SrcAbrev END AS OutSrcAbr, 
    dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime) AS InDateTime,
    dbo.PunchDateTime2(thd.TransDate, thd.OutDay, thd.OutTime) AS OutDateTime,
    thd.TransDate, thd.InDay, thd.InTime, thd.OutDay, thd.OutTime, 
    thd.UserCode, CASE ISNULL(thd.OutUserCode, '') WHEN '' THEN thd.UserCode ELSE thd.OutUserCode END AS OutUserCode,
--    empls.MissingPunch, 
    TCempls.LastName, TCempls.FirstName,
    NULL, NULL,
    thd.Hours
  FROM tblTimeHistDetail thd
  INNER JOIN TimeCurrent..tblEmplNames AS TCempls
  ON TCempls.Client = thd.Client
    AND TCempls.GroupCode = thd.GroupCode
    AND TCempls.SSN = thd.SSN
  INNER JOIN tblEmplNames AS empls
  ON empls.Client = thd.Client
    AND empls.GroupCode = thd.GroupCode
    AND empls.SSN = thd.SSN
    AND empls.PayrollPeriodEndDate = thd.PayrollPeriodEndDate
  INNER JOIN #tmpMPs mps
  ON mps.SSN = thd.SSN
    AND mps.TransDate = thd.TransDate
  LEFT JOIN tblDayDef InDayDef ON InDayDef.DayNo = thd.InDay
  LEFT JOIN tblDayDef OutDayDef ON OutDayDef.DayNo = thd.OutDay
  LEFT JOIN TimeCurrent.dbo.tblInOutSrc InSrc ON InSrc.Src = thd.InSrc
  LEFT JOIN TimeCurrent.dbo.tblInOutSrc OutSrc ON OutSrc.Src = thd.OutSrc
  
  WHERE thd.Client = @Client
    AND thd.GroupCode = @GroupCode
    AND thd.PayrollPeriodEndDate = @PPED
    AND thd.RecordID NOT IN (SELECT DISTINCT RecordID FROM #tmpMPs)
    AND thd.InDay BETWEEN 1 AND 7
    AND (
      thd.OutDay BETWEEN 1 AND 7 OR (
        DATEDIFF("n", dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime), GETDATE()) < @MissingPunchRange
        AND dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime) = (SELECT MAX(dbo.PunchDateTime2(TransDate, InDay, InTime)) FROM tblTimeHistDetail WHERE Client = thd.Client AND GroupCode = thd.GroupCode AND SSN = thd.SSN AND PayrollPeriodEndDate = thd.PayrollPeriodEndDate)
--        AND (SELECT ClockType FROM TimeCurrent..tblSiteNames WHERE Client = thd.Client AND GroupCode = thd.GroupCode AND SiteNo = thd.SiteNo) = 'T'
      )
    )
) tmp
ORDER BY LastName, FirstName, TransDate, 
  ISNULL(InDateTime, OutDateTime)
  

DROP TABLE #tmpMPs







