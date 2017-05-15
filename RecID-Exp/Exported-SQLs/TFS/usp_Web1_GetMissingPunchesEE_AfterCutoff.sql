Create PROCEDURE [dbo].[usp_Web1_GetMissingPunchesEE_AfterCutoff] (
  @UserID           int,
  @Client           varchar(4),
  @GroupCode        int,
  @PPED             datetime,
  @SiteNo           int,
  @ClusterID        int,
  @SSN              INT,
  @THDRecordId      BIGINT = 0  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 08Sept2016 >--
) AS

SET NOCOUNT ON

DECLARE  @ProcUserID           int
DECLARE  @ProcClient           varchar(4)
DECLARE  @ProcGroupCode        int
DECLARE  @ProcPPED             datetime
DECLARE  @ProcSiteNo           int
DECLARE  @ProcClusterID        int
DECLARE  @ProcSSN              int

IF @THDRecordId <> 0
BEGIN
	SELECT *
	FROM TimeHistory..tblTimeHistDetail
	WHERE RecordID = @THDRecordId

	RETURN
END

SELECT	@ProcUserID = @UserID,
		@ProcClient = @Client,
		@ProcGroupCode = @GroupCode,
		@ProcPPED = @PPED,
		@ProcSiteNo = @SiteNo, 
		@ProcClusterID = @ClusterID,
		@ProcSSN = @SSN

DECLARE @tmpMPs TABLE
(
  RecordID  BIGINT,  --< RecordId data type is changed from  INT to BIGINT by Srinsoft on 08Sept2016 >--
  SSN       int, EmplRecordID  int,
  SiteNo    int, DeptNo        int, ShiftNo   int,
  DeptName VARCHAR(50), AssignmentNo VARCHAR(50),
  InDayAbr  varchar(3), OutDayAbr   varchar(3),
  InSrcAbr  varchar(4), OutSrcAbr   varchar(4),
  InDateTime  datetime, OutDateTime datetime,
  InDateTimeFix datetime, OutDateTimeFix datetime,
  TransDate datetime,
  InDay     smallint,   InTime      datetime,
  OutDay    smallint,   OutTime     datetime,
  UserCode  varchar(4), OutUserCode varchar(4),
  LastName  varchar(100), FirstName varchar(100),
  ShiftStart  datetime,   ShiftEnd  datetime,
  IsEmplInput char(1),
  MissingPunch CHAR(1),
  PrefillInPunch CHAR(1),
  PrefillOutPunch CHAR(1)
)


DECLARE @tmpMPDs TABLE
(
  SSN       int, 
  MaxPunchDateTime  datetime
)

IF @ProcSSN <> 0 
BEGIN
  INSERT INTO @tmpMPDs
  SELECT thd.SSN, MAX(dbo.PunchDateTime2(TransDate, InDay, InTime))
  FROM timehistory..tblemplnames en
  inner join tblTimeHistDetail thd WITH (NOLOCK) 
  ON thd.client = en.client
  AND thd.groupcode = en.groupcode
  AND thd.ssn = en.ssn
  AND thd.PayrollPeriodEndDate = en.PayrollPeriodEndDate
  AND (thd.inday IN (10,11) OR thd.outday IN (10,11))
  WHERE en.Client = @ProcClient
  AND en.GroupCode = @ProcGroupCode 
  AND en.PayrollPeriodEndDate = @ProcPPED
  and en.SSN = @ProcSSN 
  AND en.MissingPunch > 0
  GROUP BY thd.SSN
END
ELSE
BEGIN
  INSERT INTO @tmpMPDs
  SELECT thd.SSN, MAX(dbo.PunchDateTime2(TransDate, InDay, InTime))
  FROM timehistory..tblemplnames en
  inner join tblTimeHistDetail thd WITH (NOLOCK) 
  ON thd.client = en.client
  AND thd.groupcode = en.groupcode
  AND thd.ssn = en.ssn
  AND thd.PayrollPeriodEndDate = en.PayrollPeriodEndDate
  AND (thd.inday IN (10,11) OR thd.outday IN (10,11))
  WHERE en.Client = @ProcClient
  AND en.GroupCode = @ProcGroupCode 
  AND en.PayrollPeriodEndDate = @ProcPPED
  AND en.MissingPunch > 0
  GROUP BY thd.SSN
END

DECLARE @MissingPunchRange numeric(7,3)

Set @MissingPunchRange = (Select MissingPunchRangeInHours from Timecurrent..tblClientGroups WITH (NOLOCK) where Client = @ProcClient and groupcode = @ProcGroupCode)
IF @MissingPunchRange is NULL
  Set @MissingPunchRange = 9.00

Set @MissingPunchRange = @MissingPunchRange * 60.00

INSERT INTO @tmpMPs
  SELECT thd.RecordID,
    thd.SSN,
    TCempls.RecordID AS EmplRecordID, 
    thd.SiteNo, thd.DeptNo, thd.ShiftNo,
	gd.DeptName,ed.AssignmentNo,
    InDayDef.DayAbrev AS InDayAbr, 
    OutDayDef.DayAbrev AS OutDayAbr,
    CASE ISNULL(InSrc.SrcAbrev, '') WHEN '' THEN thd.UserCode ELSE InSrc.SrcAbrev END AS InSrcAbr, 
    CASE ISNULL(OutSrc.SrcAbrev, '') WHEN '' THEN thd.UserCode ELSE OutSrc.SrcAbrev END AS OutSrcAbr, 
    dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime) AS InDateTime,
    dbo.PunchDateTime2(thd.TransDate, thd.OutDay, thd.OutTime) AS OutDateTime,
    null,null,
    thd.TransDate, thd.InDay, thd.InTime, thd.OutDay, thd.OutTime, 
    thd.UserCode, CASE ISNULL(thd.OutUserCode, '') WHEN '' THEN thd.UserCode ELSE thd.OutUserCode END AS OutUserCode,
    TCempls.LastName, TCempls.FirstName,
    NULL, NULL, NULL, empls.MissingPunch,'1','1'
  FROM TimeHistory..tblEmplNames empls WITH (NOLOCK)
  /*INNER JOIN TimeHistory..tblEmplSites th_es WITH (NOLOCK) 
  ON th_es.Client = empls.Client 
  AND th_es.GroupCode = empls.GroupCode 
  AND th_es.SSN = empls.SSN 
  AND th_es.PayrollPeriodEndDate = empls.PayrollPeriodEndDate 
  AND (th_es.SiteNo = @ProcSiteNo OR @ProcSiteNo = 0)*/
  INNER JOIN TimeHistory..tblTimeHistDetail thd WITH (NOLOCK)
  ON thd.Client = empls.Client
    AND thd.GroupCode = empls.GroupCode
    AND thd.PayrollPeriodEndDate = empls.PayrollPeriodEndDate
    AND thd.SSN = empls.SSN
    AND (
      thd.InDay IN (10, 11) OR (
        thd.OutDay IN (10, 11)
        AND (
          DATEDIFF("n", dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime), GETDATE()) >= @MissingPunchRange
          OR dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime) <> (SELECT MaxPunchDateTime FROM @tmpMPDs WHERE SSN = thd.SSN)
					OR @ProcPPED < (SELECT MAX(PayrollPeriodEndDate) from tblPeriodEndDates WITH (NOLOCK) WHERE Client = @ProcClient and GroupCode = @ProcGroupCode)				
          OR (SELECT ClockType FROM TimeCurrent..tblSiteNames WHERE Client = thd.Client AND GroupCode = thd.GroupCode AND SiteNo = thd.SiteNo) <> 'T'
       )
      )
    )
  INNER JOIN TimeCurrent..tblEmplNames AS TCempls WITH (NOLOCK)
  ON TCempls.Client = empls.Client
    AND TCempls.GroupCode = empls.GroupCode
    AND TCempls.SSN = empls.SSN
  INNER JOIN TimeCurrent..tblGroupDepts gd
  ON thd.Client = gd.Client
  AND thd.GroupCode = gd.GroupCode
  AND thd.DeptNo = gd.DeptNo
  LEFT JOIN TimeHistory..tblEmplNames_Depts ed
  ON thd.Client = ed.Client
  AND thd.GroupCode = ed.GroupCode
  AND thd.SSN = ed.SSN
  AND thd.DeptNo = ed.Department
  AND thd.PayrollPeriodEndDate = ed.PayrollPeriodEndDate
  LEFT JOIN tblDayDef InDayDef  WITH (NOLOCK) ON InDayDef.DayNo = thd.InDay
  LEFT JOIN tblDayDef OutDayDef  WITH (NOLOCK)
  ON OutDayDef.DayNo = (
    CASE WHEN thd.OutDay IN (10, 11) AND thd.OutTime <> '1899-12-30 00:00:00.000'
    THEN
      CASE WHEN thd.OutTime >= thd.InTime THEN thd.InDay ELSE (thd.InDay + 1) % 7 END
    ELSE thd.OutDay END
  )
  LEFT JOIN TimeCurrent.dbo.tblInOutSrc InSrc WITH (NOLOCK) ON InSrc.Src = thd.InSrc
  LEFT JOIN TimeCurrent.dbo.tblInOutSrc OutSrc WITH (NOLOCK) ON OutSrc.Src = thd.OutSrc
  
  WHERE empls.Client = @ProcClient
    AND empls.GroupCode = @ProcGroupCode
    AND empls.PayrollPeriodEndDate = @ProcPPED
    AND empls.MissingPunch > 0
    AND (empls.SSN IN (SELECT SSN FROM tblEmplSites WITH (NOLOCK) WHERE Client = @ProcClient AND GroupCode = @ProcGroupCode AND SSN = empls.SSN AND PayrollPeriodEndDate = @ProcPPED AND SiteNo = @ProcSiteNo) OR @ProcSiteNo = 0)
	AND EXISTS(SELECT ClusterID FROM dbo.tvf_GetTimeHistoryClusterDefAsFn(
  							empls.GroupCode,
							thd.SiteNo,
							thd.DeptNo,
							thd.AgencyNo,
							empls.ssn,
							TCempls.DivisionID,
							thd.ShiftNo,
							@ProcClusterID))
    AND (empls.SSN = @ProcSSN OR @ProcSSN = 0)
    ORDER BY empls.SSN, thd.TransDate, 
    ISNULL(dbo.PunchDateTime(thd.TransDate, thd.InDay, thd.InTime), dbo.PunchDateTime(thd.TransDate, thd.OutDay, thd.OutTime))

--SELECT * FROM @tmpMPs
--RETURN


UPDATE @tmpMPs SET
InTime = CAST(CONVERT(varchar(5), InTime, 8) as datetime),
OutTime = CAST(CONVERT(varchar(5), OutTime, 8) as datetime)

DECLARE csrMPs CURSOR READ_ONLY
FOR 
  SELECT RecordID, SSN, SiteNo, DeptNo, TransDate FROM @tmpMPs

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
     --IF (@Client <> 'DAVT')
     --BEGIN
          IF (
          SELECT COUNT(RecordID)
          FROM TimeCurrent..tblDeptShifts WITH (NOLOCK)
          WHERE Client = @ProcClient
          AND GroupCode = @ProcGroupCode
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
          FROM @tmpMPs AS mps
          INNER JOIN TimeCurrent..tblDeptShifts AS shifts WITH (NOLOCK)
          ON shifts.Client = @ProcClient
          AND shifts.GroupCode = @ProcGroupCode
          AND shifts.SiteNo = @tmpSiteNo
          AND shifts.DeptNo = @tmpDeptNo
          AND shifts.RecordStatus = '1'
          INNER JOIN TimeCurrent..tblSiteNames AS sites WITH (NOLOCK)
          ON sites.Client = @ProcClient
          AND sites.GroupCode = @ProcGroupCode
          AND sites.SiteNo = @tmpSiteNo
          WHERE mps.RecordID = @tmpRecordID AND (
          (
              mps.InDay BETWEEN 1 AND 7
              AND mps.InTime
              BETWEEN DATEADD(minute, sites.ShiftInWindow * (-1), CAST(CONVERT(varchar(5), shifts.ShiftStart, 8) as datetime))
              AND DATEADD(minute, sites.ShiftInWindow, CAST(CONVERT(varchar(5), shifts.ShiftStart, 8) as datetime))
          ) OR 
          (
              mps.OutDay BETWEEN 1 AND 7
              AND mps.OutTime
              BETWEEN DATEADD(minute, sites.ShiftOutWindow * (-1), CAST(CONVERT(varchar(5), shifts.ShiftEnd, 8) as datetime))
              AND DATEADD(minute, sites.ShiftOutWindow, CAST(CONVERT(varchar(5), shifts.ShiftEnd, 8) as datetime))
          )
          )), 0)

	  DECLARE @FixedInDateTime datetime
	  DECLARE @FixedOutDateTime datetime
	  DECLARE @cntFixPunch BIGINT  --< @cntFixPunch data type is changed from  INT to BIGINT by Srinsoft on 08Sept2016 >--
	  SET @cntFixPunch = ISNULL((SELECT RecordID FROM Timehistory..tblFixedPunchByEe WITH (NOLOCK) where recordID = @tmpRecordID),0)
	  IF (@cntFixPunch <> 0)
          BEGIN
             SELECT @FixedInDateTime = InDateTime
                   ,@FixedOutDateTime = OutDateTime
             FROM Timehistory..tblFixedPunchByEe WITH (NOLOCK)
             WHERE recordID = @tmpRecordID 
             
             IF @FixedInDateTime IS NOT NULL
             BEGIN
               UPDATE @tmpMPs 
               SET InDateTimeFix = @FixedInDateTime
	       WHERE RecordID = @tmpRecordID
             END
             ELSE IF @FixedOutDateTime IS NOT NULL
             BEGIN
                UPDATE @tmpMPs 
                SET OutDateTimeFix = @FixedOutDateTime
                WHERE RecordID = @tmpRecordID
             END    
          END 
	
          IF @ShiftRecordID <> 0
          BEGIN
             DECLARE @ShiftStart     datetime
             DECLARE @ShiftEnd       datetime
             DECLARE @ApplyString    char(7)
             DECLARE @PunchDate      datetime
             DECLARE @ShiftNo        int

             SELECT @ShiftStart = ShiftStart, @ShiftEnd = ShiftEnd, @ShiftNo = ShiftNo,
             @ApplyString = ApplyDay1 + ApplyDay2 + ApplyDay3 + ApplyDay4 + ApplyDay5 + ApplyDay6 + ApplyDay7
             FROM TimeCurrent..tblDeptShifts WITH (NOLOCK)
             WHERE RecordID = @ShiftRecordID
          
             IF @ShiftStart > @ShiftEnd
                SET @PunchDate = DATEADD(day, 1, @tmpTransDate)
             ELSE
                SET @PunchDate = @tmpTransDate
             IF SUBSTRING(@ApplyString, DATEPART(weekday, @PunchDate), 1) = '1'
             BEGIN   
                IF (
                SELECT COUNT(RecordID)
                FROM tblTimeHistDetail WITH (NOLOCK)
                WHERE Client = @ProcClient
                AND GroupCode = @ProcGroupCode
                AND PayrollPeriodEndDate = @ProcPPED
                AND SSN = @tmpSSN
                AND TransDate = @tmpTransDate
                AND RecordID <> @tmpRecordID
                AND dbo.PunchDateTime2(@PunchDate, DATEPART(weekday, @PunchDate), @ShiftStart)
                <= dbo.PunchDateTime2(TransDate, OutDay, OutTime)
                AND (SELECT dbo.PunchDateTime2(TransDate, OutDay, OutTime) FROM @tmpMPs WHERE RecordID = @tmpRecordID)
                >= dbo.PunchDateTime2(TransDate, OutDay, OutTime)
                AND dbo.PunchDateTime2(TransDate, OutDay, OutTime) <> dbo.PunchDateTime2(TransDate, InDay, InTime)
                ) = 0
                BEGIN
                   UPDATE @tmpMPs SET 
                   ShiftNo = @ShiftNo, ShiftStart = @ShiftStart, ShiftEnd = @ShiftEnd,
                   InDateTime = (
                   CASE WHEN InDay BETWEEN 1 AND 7 THEN InDateTime 
                   ELSE dbo.PunchDateTime2(@PunchDate, DATEPART(weekday, @PunchDate), @ShiftStart)
                   END )
                   WHERE RecordID = @tmpRecordID
                END
                IF (
                SELECT COUNT(RecordID)
                FROM tblTimeHistDetail WITH (NOLOCK)
                WHERE Client = @ProcClient
                AND GroupCode = @ProcGroupCode
                AND PayrollPeriodEndDate = @ProcPPED
                AND SSN = @tmpSSN
                AND TransDate = @tmpTransDate
                AND RecordID <> @tmpRecordID
                AND dbo.PunchDateTime2(@PunchDate, DATEPART(weekday, @PunchDate), @ShiftEnd)
                >= dbo.PunchDateTime2(TransDate, InDay, InTime)
                AND (SELECT dbo.PunchDateTime2(TransDate, InDay, InTime) FROM @tmpMPs WHERE RecordID = @tmpRecordID)
                <= dbo.PunchDateTime2(TransDate, InDay, InTime)
                AND dbo.PunchDateTime2(TransDate, OutDay, OutTime) <> dbo.PunchDateTime2(TransDate, InDay, InTime)
                ) = 0
                UPDATE @tmpMPs SET 
                ShiftNo = @ShiftNo, ShiftStart = @ShiftStart, ShiftEnd = @ShiftEnd,
                OutDateTime = (
                CASE WHEN OutDay BETWEEN 1 AND 7 THEN OutDateTime 
                ELSE dbo.PunchDateTime2(@PunchDate, DATEPART(weekday, @PunchDate), @ShiftEnd)
                END  )
                WHERE RecordID = @tmpRecordID
             END  --SUBSTRING(@ApplyString, DATEPART(weekday, @PunchDate), 1) = '1'
          END --@ShiftRecordID <> 0
          
           
      --END
     END --(@@fetch_status <> -2)
     FETCH NEXT FROM csrMPs INTO @tmpRecordID, @tmpSSN, @tmpSiteNo, @tmpDeptNo, @tmpTransDate
END --(@@fetch_status <> -1)

CLOSE csrMPs
DEALLOCATE csrMPs

UPDATE @tmpMPs
SET PrefillInPunch = '0'
WHERE InDay IN (10,11)
AND DATEDIFF("n", InDateTime, GETDATE()) < @MissingPunchRange

UPDATE @tmpMPs
SET PrefillOutPunch = '0'
WHERE OutDay IN (10,11)
AND DATEDIFF("n", InDateTime, GETDATE()) < @MissingPunchRange

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
  FROM @tmpMPs mps
 
  UNION ALL
  
  SELECT DISTINCT 
    CASE WHEN (
      DATEDIFF("n", dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime), GETDATE()) < @MissingPunchRange
      AND dbo.PunchDateTime2(thd.TransDate, thd.OutDay, thd.OutTime) IS NULL
      AND dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime) = (SELECT MaxPunchDateTime FROM @tmpMPDs WHERE SSN = thd.SSN)
      --AND (SELECT ClockType FROM TimeCurrent..tblSiteNames WHERE Client = thd.Client AND GroupCode = thd.GroupCode AND SiteNo = thd.SiteNo) = 'T'
    )
    THEN 2
    ELSE 0
    END AS MP,
    thd.RecordID, thd.SSN, TCempls.RecordID AS EmplRecordID,
    thd.SiteNo, thd.DeptNo, thd.ShiftNo,
	gd.DeptName,ed.AssignmentNo,
    InDayDef.DayAbrev AS InDayAbr, 
    OutDayDef.DayAbrev AS OutDayAbr,
    CASE ISNULL(InSrc.SrcAbrev, '') WHEN '' THEN thd.UserCode ELSE InSrc.SrcAbrev END AS InSrcAbr, 
    CASE ISNULL(OutSrc.SrcAbrev, '') WHEN '' THEN thd.UserCode ELSE OutSrc.SrcAbrev END AS OutSrcAbr, 
    dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime) AS InDateTime,
    dbo.PunchDateTime2(thd.TransDate, thd.OutDay, thd.OutTime) AS OutDateTime,
    null,null,
    thd.TransDate, thd.InDay, thd.InTime, thd.OutDay, thd.OutTime, 
    thd.UserCode, CASE ISNULL(thd.OutUserCode, '') WHEN '' THEN thd.UserCode ELSE thd.OutUserCode END AS OutUserCode,
--    empls.MissingPunch, 
    TCempls.LastName, TCempls.FirstName,
    NULL, NULL,NULL,
    mps.MissingPunch,mps.PrefillInPunch,mps.PrefillOutPunch, thd.Hours
  FROM tblTimeHistDetail thd WITH (NOLOCK)
  INNER JOIN TimeCurrent..tblEmplNames AS TCempls WITH (NOLOCK)
  ON TCempls.Client = thd.Client
    AND TCempls.GroupCode = thd.GroupCode
    AND TCempls.SSN = thd.SSN
  INNER JOIN tblEmplNames AS empls WITH (NOLOCK)
  ON empls.Client = thd.Client
    AND empls.GroupCode = thd.GroupCode
    AND empls.SSN = thd.SSN
    AND empls.PayrollPeriodEndDate = thd.PayrollPeriodEndDate
  INNER JOIN TimeCurrent..tblGroupDepts gd
  ON thd.Client = gd.Client
  AND thd.GroupCode = gd.GroupCode
  AND thd.DeptNo = gd.DeptNo
  LEFT JOIN TimeHistory..tblEmplNames_Depts ed
  ON thd.Client = ed.Client
  AND thd.GroupCode = ed.GroupCode
  AND thd.SSN = ed.SSN
  AND thd.DeptNo = ed.Department
  AND thd.PayrollPeriodEndDate = ed.PayrollPeriodEndDate
  INNER JOIN @tmpMPs mps
  ON mps.SSN = thd.SSN
    AND mps.TransDate = thd.TransDate
  LEFT JOIN tblDayDef InDayDef WITH (NOLOCK) ON InDayDef.DayNo = thd.InDay
  LEFT JOIN tblDayDef OutDayDef WITH (NOLOCK) ON OutDayDef.DayNo = thd.OutDay
  LEFT JOIN TimeCurrent.dbo.tblInOutSrc InSrc WITH (NOLOCK) ON InSrc.Src = thd.InSrc
  LEFT JOIN TimeCurrent.dbo.tblInOutSrc OutSrc WITH (NOLOCK) ON OutSrc.Src = thd.OutSrc
  
  WHERE thd.Client = @ProcClient
    AND thd.GroupCode = @ProcGroupCode
    AND thd.PayrollPeriodEndDate = @ProcPPED
    AND thd.RecordID NOT IN (SELECT DISTINCT RecordID FROM @tmpMPs)
    AND thd.InDay BETWEEN 1 AND 7
    AND (
      thd.OutDay BETWEEN 1 AND 7 OR (
--        DATEDIFF("n", dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime), GETDATE()) < @MissingPunchRange
          dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime) = (SELECT MaxPunchDateTime FROM @tmpMPDs WHERE SSN = thd.SSN)
--        AND (SELECT ClockType FROM TimeCurrent..tblSiteNames WHERE Client = thd.Client AND GroupCode = thd.GroupCode AND SiteNo = thd.SiteNo) = 'T'
      )
    )
--	AND @THDRecordId = 0 OR thd.RecordID = @THDRecordId
) tmp
ORDER BY MissingPunch,LastName, FirstName, TransDate, 
  ISNULL(InDateTime, OutDateTime)
  


