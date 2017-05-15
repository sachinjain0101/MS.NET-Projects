CREATE  PROCEDURE [dbo].[usp_APP_AutomatedPTO_ProcessTrans] (
  @RecordID    int
) AS

--*/

/*
DECLARE @RecordID  int

SET @RecordID = 52
*/

SET NOCOUNT ON

BEGIN TRANSACTION

  DECLARE @ErrorMsg        AS varchar(8000)

  DECLARE @Client          AS char(4)
  DECLARE @PrimarySite     AS int
  DECLARE @RecordType      AS char(1)
  DECLARE @SSN             AS int
  DECLARE @FileNo          AS varchar(10)
  DECLARE @TransDate       AS datetime
  DECLARE @ClockAdjustmentNo  AS varchar(3) --< Srinsoft 08/06/2015 Changed @ClockAdjustmentNo AS char(1) to varchar(3) >--
  DECLARE @Hours           AS numeric(7,2)

  DECLARE @GroupCode          AS int
  DECLARE @SiteNo             AS int
  DECLARE @DeptNo             AS int
  DECLARE @AdjustmentCode     AS varchar(3)
  DECLARE @AdjustmentName     AS varchar(50)
  DECLARE @PPED               AS datetime
  DECLARE @MasterPPED         AS datetime
  DECLARE @GroupType          AS varchar(50)

  SELECT @Client = Client, @GroupCode = GroupCode, @RecordType = RecordType, @PrimarySite = PrimarySite, @SSN = SSN, @FileNo = FileNo, 
         @TransDate = TransDate, @ClockAdjustmentNo = ClockAdjustmentNo, @Hours = Hours
  FROM tblAutomatedPTO 
  WHERE RecordID = @RecordID

  -- Guess the GroupCode based on SSN and PrimarySite
  IF @GroupCode = 0
  BEGIN
    SET @GroupCode = (
      SELECT TOP 1 emplsites.GroupCode 
      FROM TimeCurrent..tblEmplSites AS emplsites
      INNER JOIN TimeCurrent..tblEmplNames AS empls
      ON empls.Client = emplsites.Client
        AND empls.GroupCode = emplsites.GroupCode
        AND empls.SSN = emplsites.SSN
        AND empls.RecordStatus = '1'
        AND empls.Status <> '9'
      INNER JOIN TimeCurrent..tblSiteNames AS sites
      ON sites.Client = emplsites.Client
        AND sites.GroupCode = emplsites.GroupCode
        AND sites.SiteNo = emplsites.SiteNo
        AND sites.RecordStatus = '1'
      WHERE emplsites.Client = @Client
        AND emplsites.SSN = @SSN
        AND emplsites.RecordStatus = '1'
        AND emplsites.Status <> '9'
      ORDER BY CASE WHEN emplsites.SiteNo = @PrimarySite THEN 0 ELSE 1 END
    )
  END

  IF @GroupCode IS NULL
  BEGIN
    SET @GroupCode = 0
    SET @ErrorMsg = 'Employee is not active on any site'
    GOTO ErrHandler
  END

  -- Get the PPED
  SELECT TOP 1 @PPED = PayrollPeriodEndDate, @MasterPPED = MasterPayrollDate
  FROM tblPeriodEndDates
  WHERE Client = @Client AND GroupCode = @GroupCode 
    AND PayrollPeriodEndDate >= @TransDate AND PayrollPeriodEndDate < DATEADD(day, 7, @TransDate)
  ORDER BY PayrollPeriodEndDate DESC

  IF @PPED IS NULL
  BEGIN
    ROLLBACK TRANSACTION
    UPDATE tblAutomatedPTO SET GroupCode = @GroupCode, ErrorMsg = 'Future Transaction' WHERE RecordID = @RecordID
    RETURN
  END

  -- Check PPED Status
  IF (
    SELECT Status 
    FROM tblPeriodEndDates
    WHERE Client = @Client AND GroupCode = @GroupCode AND PayrollPeriodEndDate = @PPED
  ) = 'C'
  BEGIN
    SET @ErrorMsg = 'Payroll period for this transaction is closed'
    GOTO ErrHandler
  END

  -- Guess the SiteNo
  IF @Client = 'GAMB' OR @Client = 'GTS'
  BEGIN
    -- If the group is NON-Clinical use the siteno from tblEmplsites else use the one passed in
    --
    SET @GroupType = (SELECT ClientGroupID1 FROM TimeCurrent..tblClientGroups WHERE client = @Client and groupcode = @GroupCode )
    IF @GroupType = 'NON-CLINIC'
    BEGIN
      SET @SiteNo = (
        SELECT TOP 1 emplsites.SiteNo
        FROM TimeCurrent..tblEmplSites AS emplsites
        INNER JOIN TimeCurrent..tblEmplNames AS empls
        ON empls.Client = emplsites.Client
          AND empls.GroupCode = emplsites.GroupCode
          AND empls.SSN = emplsites.SSN
          AND empls.RecordStatus = '1'
          AND empls.Status <> '9'
        INNER JOIN TimeCurrent..tblSiteNames AS sites
        ON sites.Client = emplsites.Client
          AND sites.GroupCode = emplsites.GroupCode
          AND sites.SiteNo = emplsites.SiteNo
          AND sites.RecordStatus = '1'
        WHERE emplsites.Client = @Client
          AND emplsites.SSN = @SSN
          AND emplsites.GroupCode = @GroupCode
          AND emplsites.RecordStatus = '1'
          AND emplsites.Status <> '9'
        ORDER BY CASE WHEN emplsites.SiteNo = @PrimarySite THEN 0 ELSE 1 END)

      IF @SiteNo is NULL
        SET @SiteNo = @PrimarySite
    END
    ELSE
    BEGIN
      SET @SiteNo = @PrimarySite
    END
  END
  ELSE
  BEGIN
    SET @SiteNo = (
      SELECT TOP 1 emplsites.SiteNo 
      FROM TimeCurrent..tblEmplSites AS emplsites
      INNER JOIN TimeCurrent..tblSiteNames AS sites
      ON sites.Client = emplsites.Client
        AND sites.GroupCode = emplsites.GroupCode
        AND sites.SiteNo = emplsites.SiteNo
        AND sites.RecordStatus = '1'
      WHERE emplsites.Client = @Client
        AND emplsites.SSN = @SSN
        AND emplsites.RecordStatus = '1'
        AND emplsites.Status <> '9'
      ORDER BY CASE WHEN emplsites.SiteNo = @PrimarySite THEN 0 ELSE 1 END
    )
  
    IF @SiteNo IS NULL
    BEGIN
      SET @SiteNo = 0
      SET @ErrorMsg = 'Employee is not active on any site'
      GOTO ErrHandler
    END
  END

  -- Get the DeptNo
  SET @DeptNo = (
    SELECT PrimaryDept
    FROM TimeCurrent..tblEmplNames
    WHERE Client = @Client
      AND GroupCode = @GroupCode
      AND SSN = @SSN
      AND RecordStatus = '1'
  )

  IF @DeptNo IS NULL
  BEGIN
    SET @ErrorMsg = 'Employee has no primary dept'
    GOTO ErrHandler
  END

  SELECT TOP 1 @AdjustmentCode = AdjustmentCode, @AdjustmentName = AdjustmentName
  FROM TimeCurrent..tblAdjCodes
  WHERE Client = @Client AND GroupCode = @GroupCode AND ClockAdjustmentNo = @ClockAdjustmentNo AND RecordStatus = '1'

  IF @ClockAdjustmentNo IS NULL
  BEGIN
    SET @ErrorMsg = 'Hours Type does not exist'
    GOTO ErrHandler
  END

  IF @RecordType <> 'A'
  BEGIN
    SET @ErrorMsg = 'RecordType of ' + @RecordType + ' not recognized'
    GOTO ErrHandler
  END

  IF (
    SELECT COUNT(*)
    FROM tblTimeHistDetail 
    WHERE Client = @Client 
      AND GroupCode = @GroupCode 
      AND SiteNo = @SiteNo
      AND SSN = @SSN
      AND PayrollPeriodEndDate = @PPED
      AND TransDate = @TransDate
      AND ClockAdjustmentNo = @ClockAdjustmentNo
  ) > 0
  BEGIN
    SET @ErrorMsg = 'Transaction(s) already exist for this Date and Hours Type'
    GOTO ErrHandler
  END
  ELSE
  BEGIN
    DECLARE @THDRecordID    AS BIGINT  --< @thdRecordID data type is converted from INT to BIGINT by Srinsoft on 29July2016 >--

    INSERT INTO tblTimeHistDetail (
      Client, GroupCode, SSN, PayrollPeriodEndDate, MasterPayrollDate, SiteNo, DeptNo, JobID,
      TransDate, EmpStatus, BillRate, BillOTRate, BillOTRateOverride, PayRate, ShiftNo,
      InDay, InTime, OutDay, OutTime, 
      Hours, Dollars, TransType, AgencyNo, InSrc, OutSrc,
      ClockAdjustmentNo, AdjustmentCode, AdjustmentName, DaylightSavTime, Holiday, HandledByImporter, ClkTransNo, UserCode
    ) VALUES (
      @Client, @GroupCode, @SSN, @PPED, @MasterPPED, @SiteNo, @DeptNo, 0,
      CONVERT(char(10), @TransDate, 101), 1, 0.00, 0.00, 0.00, 0.00, 1,
      DATEPART(weekday, @TransDate), '12/30/1899 00:00:00', DATEPART(weekday, @TransDate), '12/30/1899 00:00:00',
      @Hours, 0.00, 0, 0, '3', '3',
      @ClockAdjustmentNo, '', @AdjustmentName, 0, 0, 'V', 9800, 'PRO'
    )
     
    IF @@error <> 0
    BEGIN
      SET @ErrorMsg = @@error
      GOTO ErrHandler
    END
    SET @THDRecordID = SCOPE_IDENTITY()

    INSERT INTO TimeCurrent..tblAdjustments (
      ReverseFlag, OrigRecord_No, Client, GroupCode, PayrollPeriodEndDate, SSN, SiteNo, DeptNo,
      ClockAdjustmentNo, AdjustmentCode, AdjustmentName, HoursDollars,
      MonVal, TueVal, WedVal, ThuVal, FriVal, SatVal, SunVal, WeekVal, TotalVal,
      AgencyNo, UserName, UserID, TransDateTime, 
      DeletedDateTime, DeletedByUserName, DeletedByUserID, SweptDateTime, RecordStatus, IPAddr, ShiftNo
    ) VALUES (
      '', @THDRecordID, @Client, @GroupCode, @PPED, @SSN, @SiteNo, @DeptNo,
      @ClockAdjustmentNo, @AdjustmentCode, @AdjustmentName, 'H',
      CASE WHEN DATEPART(weekday, @TransDate) = 2 THEN @Hours ELSE 0 END,
      CASE WHEN DATEPART(weekday, @TransDate) = 3 THEN @Hours ELSE 0 END,
      CASE WHEN DATEPART(weekday, @TransDate) = 4 THEN @Hours ELSE 0 END,
      CASE WHEN DATEPART(weekday, @TransDate) = 5 THEN @Hours ELSE 0 END,
      CASE WHEN DATEPART(weekday, @TransDate) = 6 THEN @Hours ELSE 0 END,
      CASE WHEN DATEPART(weekday, @TransDate) = 7 THEN @Hours ELSE 0 END,
      CASE WHEN DATEPART(weekday, @TransDate) = 1 THEN @Hours ELSE 0 END,
      0, @Hours,
      0, 'PRO', 0, GETDATE(),
      NULL, NULL, NULL, NULL, '1', NULL, 1
    )

    IF @@error <> 0
    BEGIN
      SET @ErrorMsg = @@error
      GOTO ErrHandler
    END

    UPDATE tblAutomatedPTO 
    SET GroupCode = ISNULL(@GroupCode, 0), UsedSite = ISNULL(@SiteNo, 0), PPED = @PPED, TimeProcessed = GETDATE() 
    WHERE RecordID = @RecordID
  END

/*
SELECT * FROM tblAutomatedPTO WHERE RecordID = @RecordID
SELECT * FROM tblTimeHistDetail WHERE RecordID = @THDRecordID
SELECT * FROM TimeCurrent..tblAdjustments WHERE OrigRecord_No = @THDRecordID
*/

COMMIT TRANSACTION

RETURN

ErrHandler:
  ROLLBACK TRANSACTION
  UPDATE tblAutomatedPTO SET GroupCode = ISNULL(@GroupCode, 0), UsedSite = ISNULL(@SiteNo, 0), TimeProcessed = GETDATE(), ErrorMsg = @ErrorMsg WHERE RecordID = @RecordID





