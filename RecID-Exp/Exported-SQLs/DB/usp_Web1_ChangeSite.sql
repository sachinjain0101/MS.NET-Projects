CREATE      PROCEDURE [dbo].[usp_Web1_ChangeSite] 
(
  @RecordID        BIGINT,  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 06Sept2016 >--
  @NewSiteNo       int,
  @UserName        varchar(20),
  @UserID          int,
  @IPAddr          varchar(15),
  @UpdateSpan      char(1) = 'T',
	@SelectedDept 	 int = 0
)
AS

--*/

-- UpdateSpan: T = Transaction; D = TransDate; W = Week

SET NOCOUNT ON

-- Build a table of the RecordIDs that MUST be processed
-- Punches should be sorted in order with breaks at the top of each day
DECLARE @TransDate    datetime
DECLARE @PPED         datetime
DECLARE @Group				int
DECLARE @Client				VARCHAR(4)
DECLARE @Audit				CHAR(1)
DECLARE @User					VARCHAR(50)

SELECT @TransDate = TransDate, 
			 @PPED = PayrollPeriodEndDate,
			 @Client = Client,
			 @Group = GroupCode
FROM tblTimeHistDetail WHERE RecordID = @RecordID

SET @Audit = (SELECT AuditSiteChange FROM timecurrent..tblClientGroups WHERE Client = @Client AND GroupCode = @Group)
IF @Audit = '1'
	SET @User = (SELECT FirstName + ' ' + LastName FROM timecurrent..tblUser WHERE LogonName = @UserName)

SELECT DISTINCT thd2.RecordID, thd2.SiteNo, thd2.ShiftNo, thd2.Hours, thd2.TransDate, thd2.ClockAdjustmentNo,
  thd2.InSrc, thd2.InTime, dbo.PunchDateTime(thd2.TransDate, thd2.InDay, thd2.InTime) AS InDateTime, thd2.Changed_InPunch,
  thd2.OutSrc, thd2.OutTime, dbo.PunchDateTime(thd2.TransDate, thd2.OutDay, thd2.OutTime) AS OutDateTime, thd2.Changed_OutPunch,
  CASE WHEN 
    (@UpdateSpan = 'T' AND thd2.RecordID = @RecordID)
    OR (@UpdateSpan = 'D' AND thd2.TransDate = @TransDate)
    OR (@UpdateSpan = 'W' AND thd2.PayrollPeriodEndDate = @PPED)
  THEN 1
  ELSE 0
  END AS MustProcess
INTO #tmpRecords
FROM tblTimeHistDetail AS thd
INNER JOIN tblTimeHistDetail AS thd2
ON thd2.Client = thd.Client
  AND thd2.GroupCode = thd.GroupCode
  AND thd2.SSN = thd.SSN
  AND thd2.PayrollPeriodEndDate = thd.PayrollPeriodEndDate
WHERE thd.RecordID = @RecordID
--  AND thd2.InDay <> 10 AND thd2.OutDay <> 10
ORDER BY InDateTime ASC

--SELECT * FROM #tmpRecords

-- #tmpTrans - Stores all the transactions that make up a single "punch."  Used for recombining punches that were split in tblTimeHistDetail
CREATE TABLE #tmpTrans (
  RecordID    BIGINT,  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 06Sept2016 >--
  SiteNo      INT,  --< @SiteNo data type is changed from  SMALLINT to INT by Srinsoft on 06Sept2016 >--
  ShiftNo     smallint,
  InSrc       char(1),
  OutSrc      char(1),
  InTime      datetime,
  OutTime     datetime,
  Hours       numeric(5,2),
  InDateTime  datetime,
  OutDateTime datetime
)

BEGIN TRANSACTION

/*
  SELECT DeptNo, ShiftNo, *
  FROM TimeHistory..tblTimeHistDetail
  WHERE RecordID IN (SELECT DISTINCT RecordID FROM #tmpRecords)

  SELECT TransDateTime, OldDeptNo, NewDeptNo, *
  FROM TimeCurrent..tblFixedPunch
  WHERE OrigRecordID IN (SELECT DISTINCT RecordID FROM #tmpRecords)
  ORDER BY TransDateTime
*/

  DECLARE @Current         BIGINT  --< @current data type is changed from  INT to BIGINT by Srinsoft on 06Sept2016 >--
  DECLARE @InDateTime      datetime
  DECLARE @OutDateTime     datetime
  DECLARE @InSrc           char(1)
  DECLARE @InTime          datetime
  DECLARE @OutSrc          char(1)
  DECLARE @OutTime         datetime
  DECLARE @Hours           numeric(5,2)
  
-- Process all the transactions that make up the punch containing the @Current record
  WHILE (SELECT Count(RecordID) FROM #tmpRecords WHERE MustProcess = 1) > 0
  BEGIN
    -- Notes:
    -- Status comes from tblEmplNames
    -- ShiftNo comes from tblDeptShifts if In/OutSrc = '3' and Change_In/OutPunch <> '1'
    
    SET @Current = (SELECT TOP 1 RecordID FROM #tmpRecords WHERE MustProcess = 1)

    INSERT INTO #tmpTrans (RecordID, SiteNo, ShiftNo, InSrc, OutSrc, InTime, OutTime, Hours, InDateTime, OutDateTime)
      SELECT RecordID, SiteNo, ShiftNo, InSrc, OutSrc, InTime, OutTime, Hours, InDateTime, OutDateTime
      FROM #tmpRecords
      WHERE RecordID = @Current

    DECLARE @TransCount      int

    SET @TransCount = 1

    -- Build a list of RecordIDs that this punch "connects" with
    WHILE @TransCount <= (SELECT COUNT(RecordID) FROM #tmpRecords)
    BEGIN
      INSERT INTO #tmpTrans (RecordID, SiteNo, ShiftNo, InSrc, OutSrc, InTime, OutTime, Hours, InDateTime, OutDateTime)
      SELECT DISTINCT 
        thd2.RecordID,
        thd.SiteNo, thd.ShiftNo,
        thd2.InSrc, thd2.OutSrc, thd2.InTime, thd2.OutTime, thd2.Hours,
        thd2.InDateTime, 
        thd2.OutDateTime
      FROM #tmpRecords AS thd
      INNER JOIN #tmpRecords AS thd2
      ON thd2.TransDate = thd.TransDate
        AND thd2.ClockAdjustmentNo = thd.ClockAdjustmentNo
      WHERE thd.RecordID IN (SELECT DISTINCT RecordID FROM #tmpTrans)
        AND thd2.RecordID NOT IN (SELECT DISTINCT RecordID FROM #tmpTrans)
        AND (
          (thd.InSrc = '3' 
            AND thd2.OutSrc = '3' 
            AND thd.Changed_InPunch <> '1'
            AND thd2.Changed_OutPunch <> '1'
            AND thd.InDateTime = thd2.OutDateTime)
          OR
          (thd2.InSrc = '3' 
            AND thd.OutSrc = '3' 
            AND thd2.Changed_InPunch <> '1'
            AND thd.Changed_OutPunch <> '1'
            AND thd2.InDateTime = thd.OutDateTime)
        )
        IF (SELECT COUNT(RecordID) FROM #tmpTrans) = @TransCount
          BREAK
        ELSE
          SET @TransCount = (SELECT COUNT(RecordID) FROM #tmpTrans)
    END

    IF @TransCount > (SELECT COUNT(RecordID) FROM #tmpRecords)
    BEGIN
      RAISERROR ('ERROR: More transactions than records in tblTimeHistDetail.  Rolling back request.', 1, 1)
      ROLLBACK TRANSACTION
      RETURN
    END

		IF @Audit = '1'
		BEGIN
		-- need to log the change to comments
			INSERT INTO tblTimeHistDetail_Comments(Client, GroupCode, PayrollPeriodEndDate, SSN, CreateDate, Comments, UserID, UserName)
			SELECT thd.Client, thd.GroupCode, thd.PayrollPeriodEndDate, thd.SSN, GetDate(),
						 'Site changed from ' + Replace(str(thd.SiteNo, 4), ' ', '0') + ' to ' + Replace(str(@NewSiteNo, 4), ' ', '0') + 
						 ' for ' + CONVERT(varchar(8), thd.TransDate, 1) + ' with ' + str(thd.Hours,5,2) + ' hours', @userID, @User
			FROM tblTimeHistDetail thd
			WHERE RecordID IN  (SELECT DISTINCT RecordID FROM #tmpTrans)
			IF @SelectedDept <> 0
			BEGIN
				INSERT INTO tblTimeHistDetail_Comments(Client, GroupCode, PayrollPeriodEndDate, SSN, CreateDate, Comments, UserID, UserName)
				SELECT thd.Client, thd.GroupCode, thd.PayrollPeriodEndDate, thd.SSN, GetDate(),
							 'Dept changed from ' + Replace(str(thd.DeptNo, 3), ' ', '0') + ' to ' + Replace(str(@SelectedDept, 3), ' ', '0') + 
							 ' for ' + CONVERT(varchar(8), thd.TransDate, 1) + ' with ' + str(thd.Hours,5,2) + ' hours', @userID, @User
				FROM tblTimeHistDetail thd
				WHERE thd.RecordID IN  (SELECT DISTINCT RecordID FROM #tmpTrans)
					and thd.DeptNo <> @SelectedDept
			END
		END
    
    -- Update tblTimeHistDetail with change.  This update is performed here so we can get the OldDeptNo and OldShiftNo before changing it.
    UPDATE tblTimeHistDetail
    SET SiteNo = @NewSiteNo, DeptNo = case when @SelectedDept <> 0 then @SelectedDept else DeptNo end,
      ShiftNo = CASE WHEN ClockAdjustmentNo IN ('', ' ') THEN 0 ELSE ShiftNo END, -- Tells EmplCalc to ReCalc this Shift ( for punches only )
      Changed_DeptNo = '1'
    WHERE RecordID IN (SELECT DISTINCT RecordID FROM #tmpTrans)

--    SELECT * FROM #tmpTrans

    SET @InDateTime = (SELECT MIN(InDateTime) FROM #tmpTrans)
    SET @OutDateTime = (SELECT MAX(OutDateTime) FROM #tmpTrans)
    SET @InSrc = (SELECT TOP 1 CASE WHEN InSrc = '' OR InSrc IS NULL THEN '0' ELSE InSrc END FROM #tmpTrans WHERE ISNULL(InDateTime, '') = ISNULL(@InDateTime, ''))
    SET @OutSrc = (SELECT TOP 1 CASE WHEN OutSrc = '' OR OutSrc IS NULL THEN '0' ELSE OutSrc END FROM #tmpTrans WHERE ISNULL(OutDateTime, '') = ISNULL(@OutDateTime, ''))
    SET @InTime = (SELECT TOP 1 CASE WHEN InTime IS NULL THEN '12:00am' ELSE InTime END FROM #tmpTrans WHERE InDateTime = @InDateTime)
    SET @OutTime = (SELECT TOP 1 CASE WHEN OutTime IS NULL THEN '12:00am' ELSE OutTime END FROM #tmpTrans WHERE OutDateTime = @OutDateTime)
    SET @Hours = (SELECT SUM(Hours) FROM #tmpTrans)

    INSERT INTO TimeCurrent..tblFixedPunch (
      OrigRecordID, Client, GroupCode, SSN, PayrollPeriodEndDate, MasterPayrollDate,
      OldSiteNo, OldDeptNo, OldJobID, OldTransDate, OldEmpStatus, OldBillRate,
      OldBillOTRate, OldBillOTRateOverride, OldPayRate, OldShiftNo, 
      OldInDay, OldInTime, OldInSrc, 
      OldOutDay, OldOutTime, OldOutSrc, OldHours, OldDollars, 
      OldClockAdjustmentNo, OldAdjustmentCode, OldAdjustmentName, OldTransType,
      NewSiteNo, NewDeptNo, NewJobID, NewTransDate, NewEmpStatus, NewBillRate,
      NewBillOTRate, NewBillOTRateOverride, NewPayRate, NewShiftNo, 
      NewInDay, NewInTime, NewInSrc, 
      NewOutDay, NewOutTime, NewOutSrc, NewHours, NewDollars, 
      NewClockAdjustmentNo, NewAdjustmentCode, NewAdjustmentName, NewTransType,
      UserName, UserID, TransDateTime, IPAddr
    ) SELECT
    	thd.RecordID, thd.Client, thd.GroupCode, thd.SSN, thd.PayrollperiodEndDate, thd.MasterPayrollDate,
      tmp.SiteNo, thd.DeptNo, thd.JobID, thd.TransDate, empls.Status, thd.BillRate,
      thd.BillOTRate, thd.BillOTRateOverride, thd.PayRate, tmp.ShiftNo, 
      DATEPART(dw, @InDateTime), @InTime, @InSrc, 
      DATEPART(dw, @OutDateTime), @OutTime, @OutSrc, @Hours, thd.Dollars, 
      thd.ClockAdjustmentNo, thd.AdjustmentCode,  thd.AdjustmentName, thd.TransType,
      @NewSiteNo, case when @SelectedDept = 0 then thd.DeptNo else @SelectedDept end, thd.JobID, thd.TransDate, empls.Status, thd.BillRate,
      thd.BillOTRate, thd.BillOTRateOverride, thd.PayRate, 0,
      DATEPART(dw, @InDateTime), @InTime, @InSrc,
      DATEPART(dw, @OutDateTime), @OutTime, @OutSrc, @Hours, thd.Dollars, 
      thd.ClockAdjustmentNo, thd.AdjustmentCode, thd.AdjustmentName, thd.TransType,
      @UserName, @UserID, GETDATE(), @IPAddr
      FROM tblTimeHistDetail AS thd
      INNER JOIN TimeCurrent..tblEmplNames AS empls
      ON empls.Client = thd.Client
        AND empls.GroupCode = thd.GroupCode
        AND empls.SSN = thd.SSN
      INNER JOIN #tmpTrans AS tmp
      ON tmp.RecordID = thd.RecordID
      WHERE thd.RecordID = @Current
  
    UPDATE #tmpRecords SET MustProcess = 0 WHERE RecordID IN (SELECT RecordID FROM #tmpTrans)
    DELETE FROM #tmpTrans
  END
  
/*
  SELECT DeptNo, ShiftNo, *
  FROM TimeHistory..tblTimeHistDetail
  WHERE RecordID IN (SELECT DISTINCT RecordID FROM #tmpRecords)

  SELECT TransDateTime, OldDeptNo, NewDeptNo, *
  FROM TimeCurrent..tblFixedPunch
  WHERE OrigRecordID IN (SELECT DISTINCT RecordID FROM #tmpRecords)
  ORDER BY TransDateTime
*/
  
COMMIT TRANSACTION

DROP TABLE #tmpTrans
DROP TABLE #tmpRecords







