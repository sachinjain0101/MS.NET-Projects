Create PROCEDURE [dbo].[usp_PATE_AddAdjustment] (
  @Client      char(4),
  @GroupCode   int,
  @SiteNo      int,
  @SSN         int,
  @DeptNo      int,
  @ShiftNo     int,
  @PPED        datetime,
  @ClockAdjustmentNo  char(1),
  @AdjType     char(1),
  @Amount      numeric(5,2),
  @Day         tinyint,
  @Sales       numeric(9,2),
  @Brand       varchar(2),
  @UserID      int,
  @ReasonCodeID  int = 0,
  @THDRecordId BIGINT = 0 output  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 25Aug2016 >--
) AS

DECLARE @CheckAmount  numeric(5,2)
DECLARE @ErrorCode INT
DECLARE @UDFMappingId INT

SELECT @UDFMappingId = TimeCurrent.dbo.fn_UDF_TemplateMappingId(@Client,@GroupCode,0,0,0,'PATE','','')

INSERT INTO timecurrent..tblPATETxn (	Client,
																		  GroupCode,
																		  SiteNo,
																		  SSN,
																		  DeptNo,
																		  ShiftNo,
																		  PPED,
																		  ClockAdjustmentNo,
																		  AdjType,
																		  Amount,
																		  Day,
																		  Sales,
																		  Brand,
																		  UserID,
																		  ReasonCodeID,
																		  Source,
																		  MaintDateTime)
																		  
VALUES(	@Client,
			  @GroupCode,
			  @SiteNo,
			  @SSN,
			  @DeptNo,
			  @ShiftNo,
			  @PPED,
			  @ClockAdjustmentNo,
			  @AdjType,
			  @Amount,
			  @Day,
			  @Sales,
			  @Brand,
			  @UserID,
			  @ReasonCodeID,
			  CASE WHEN @UserID = 21521 THEN 'IVR' ELSE '' END,
			  GETDATE())

-- If a default value for Brand exists, then overwrite the blank brand
SELECT @Brand = CASE WHEN @Brand = '' THEN IsNull(fd.DefaultValue, '') ELSE @Brand END
FROM TimeCurrent.dbo.tblUDF_WebApps wa
INNER JOIN TimeCurrent.dbo.tblUDF_Templates t
ON t.TemplateCode = 'PATE'
AND t.Client = @Client
INNER JOIN TimeCurrent..tblUDF_TemplateMapping tm
ON t.TemplateID = tm.TemplateID
AND tm.TemplateMappingID = @UDFMappingId
INNER JOIN TimeCurrent.dbo.tblUDF_FieldDefs fd
ON fd.TemplateId = t.TemplateId
AND fd.FieldName = 'Brand'
WHERE wa.WebAppCode = 'PATE'

BEGIN TRANSACTION

SET @CheckAmount = 0

SELECT @CheckAmount = Hours
FROM TimeHistory..tblTimeHistDetail
WHERE Client = @Client
AND GroupCode = @GroupCode
AND SSN = @SSN
AND PayrollPeriodEndDate = @PPED
AND DeptNo = @DeptNo
AND InDay = @Day

--SET @CheckAmount = (
--  SELECT TOP 1 Hours
--  FROM TimeHistory.dbo.tblTimeHistDetail
--  WHERE Client = @Client
--    AND GroupCode = @GroupCode
--    AND SSN = @SSN
--    AND PayrollPeriodEndDate = @PPED
--    AND DeptNo = @DeptNo
--    AND InDay = @Day
--)

IF @CheckAmount > 0
BEGIN
  EXEC usp_PATE_UpdateAdjustment @Client, @GroupCode, @SiteNo, @SSN, @DeptNo, @ShiftNo, @PPED, @ClockAdjustmentNo, @AdjType, @CheckAmount, @Amount, @Day, @Sales, @Brand, @UserID, @ReasonCodeID

  SET @ErrorCode = @@error
    IF @ErrorCode = 0
    COMMIT TRANSACTION
  ELSE
    ROLLBACK TRANSACTION
  
  RETURN
END

SET @ErrorCode = 0

IF @ErrorCode = 0
BEGIN

/*
  DECLARE @GroupCode              int

  SET @GroupCode = (
    SELECT GroupCode
    FROM TimeCurrent..tblGroupDepts
    WHERE Client = @Client
      AND DeptNo = @DeptNo
  )
*/

  DECLARE @PayrollFreq            char(1)
  DECLARE @MasterPayrollDate      datetime

  SET @PayrollFreq = (SELECT PayrollFreq FROM TimeCurrent..tblClientGroups WHERE Client = @Client AND GroupCode = @GroupCode)

  IF @PayrollFreq = 'S'
  BEGIN
    DECLARE @TransDate    datetime

    SET @TransDate = @PPED

    WHILE DATEPART(weekday, @TransDate) <> @Day
    BEGIN
      SET @TransDate = DATEADD(d, -1, @TransDate)
    END

    SET @MasterPayrollDate = (
      SELECT TOP 1 MasterPayrollDate
      FROM tblMasterPayrollDates
      WHERE Client = @Client AND GroupCode = @GroupCode
        AND MasterPayrollDate >= @TransDate
      ORDER BY MasterPayrollDate
    )
  END
  ELSE
  BEGIN
    SET @MasterPayrollDate = (
      SELECT MasterPayrollDate
      FROM tblPeriodEndDates
      WHERE Client = @Client AND GroupCode = @GroupCode AND PayrollPeriodEndDate = @PPED
    )
  END

  IF @MasterPayrollDate IS NOT NULL
  BEGIN
    DECLARE @UserCode    varchar(5)
    DECLARE @DefaultShiftNo smallint

    SET @UserCode = (SELECT UserCode FROM TimeCurrent..tblUser WHERE UserID = @UserID)
    Set @DefaultShiftNo = (SELECT DefaultShift FROM TimeCurrent..tblSiteNames WHERE client = @Client AND groupcode = @GroupCode AND SiteNo = @SiteNo)

    IF isNULL(@DefaultShiftNo,0) = 0
    BEGIN
      Set @DefaultShiftNo = 1
    END

    IF @ShiftNo IN (0,1)
      Set @ShiftNo = @DefaultShiftNo

		UPDATE TimeCurrent..tblAdjustments
		SET SunVal = CASE WHEN @Day = 1 THEN 0 ELSE SunVal END,
				MonVal = CASE WHEN @Day = 2 THEN 0 ELSE MonVal END,
				TueVal = CASE WHEN @Day = 3 THEN 0 ELSE TueVal END,
				WedVal = CASE WHEN @Day = 4 THEN 0 ELSE WedVal END,
				ThuVal = CASE WHEN @Day = 5 THEN 0 ELSE ThuVal END,
				FriVal = CASE WHEN @Day = 6 THEN 0 ELSE FriVal END,
				SatVal = CASE WHEN @Day = 7 THEN 0 ELSE SatVal END
		WHERE Client = @Client
		AND GroupCode = @GroupCode
		AND PayrollPeriodEndDate = @PPED
		AND SSN = @SSN
		AND DeptNo = @DeptNo
		AND ClockAdjustmentNo = @ClockAdjustmentNo
		AND 1 = CASE WHEN @Day = 1 AND SunVal > 0 THEN 1 
								 WHEN @Day = 2 and MonVal > 0 then 1 
								 WHEN @Day = 3 AND TueVal > 0 THEN 1
								 WHEN @Day = 4 AND WedVal > 0 THEN 1
								 WHEN @Day = 5 AND ThuVal > 0 THEN 1
								 WHEN @Day = 6 AND FriVal > 0 THEN 1
								 WHEN @Day = 7 AND SatVal > 0 THEN 1
								 ELSE 0 END

    DECLARE @Record_No    int

    -- tblAdjustments
    INSERT INTO [TimeCurrent].[dbo].[tblAdjustments]([Client], [GroupCode], [PayrollPeriodEndDate], [SSN], [SiteNo], [DeptNo], [ClockAdjustmentNo], [AdjustmentCode], [AdjustmentName], 
      [HoursDollars], [SunVal], [MonVal], [TueVal], [WedVal], [ThuVal], [FriVal], [SatVal], [WeekVal], [TotalVal], [UserID], [TransDateTime], [RecordStatus], [IPAddr], [ShiftNo], [Sales])
    SELECT @Client, @GroupCode, @PPED, @SSN, @SiteNo, @DeptNo, @ClockAdjustmentNo, AdjustmentCode, AdjustmentName,
      @AdjType, 
      (CASE @Day WHEN 1 THEN @Amount ELSE 0 END),
      (CASE @Day WHEN 2 THEN @Amount ELSE 0 END),
      (CASE @Day WHEN 3 THEN @Amount ELSE 0 END),
      (CASE @Day WHEN 4 THEN @Amount ELSE 0 END),
      (CASE @Day WHEN 5 THEN @Amount ELSE 0 END),
      (CASE @Day WHEN 6 THEN @Amount ELSE 0 END),
      (CASE @Day WHEN 7 THEN @Amount ELSE 0 END),
      0, @Amount, @UserID, GETDATE(), '1', '', @ShiftNo, @Sales
    FROM TimeCurrent..tblAdjCodes
    WHERE Client = @Client AND GroupCode = @GroupCode AND ClockAdjustmentNo = @ClockAdjustmentNo-- AND PayrollPeriodEndDate = @PPED

    SET @Record_No = scope_identity()

    IF @Record_No IS NULL
      SET @ErrorCode = @ErrorCode + 1
  
    DECLARE @RecordID    BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 25Aug2016 >--

    -- tblTimeHistDetail
    INSERT INTO [TimeHistory].[dbo].[tblTimeHistDetail]([Client], [GroupCode], [SSN], [PayrollPeriodEndDate], [MasterPayrollDate], [SiteNo], [DeptNo], [ShiftNo], [JobID],
      [TransDate], [EmpStatus], [BillRate], [BillOTRate], [BillOTRateOverride], [PayRate], [InDay], [InTime], [OutDay], [OutTime], [Hours], [Dollars],
      [ClockAdjustmentNo], [AdjustmentCode], [AdjustmentName], [TransType], [AgencyNo], [InSrc], [OutSrc], [DaylightSavTime], [Holiday], 
      [AprvlStatus], [AprvlStatus_UserID], [AprvlStatus_Date], [AprvlAdjOrigRecID], [AprvlAdjOrigClkAdjNo], [UserCode])
    SELECT TOP 1 @Client, @GroupCode, @SSN, @PPED, @MasterPayrollDate, @SiteNo, @DeptNo, @ShiftNo, 0,
      CASE WHEN @Day <= DATEPART(dw, @PPED)
      THEN DATEADD(day, -(DATEPART(dw, @PPED) - @Day), @PPED)
      ELSE DATEADD(day, ((@Day - DATEPART(dw, @PPED)) - 7), @PPED)
      END,
      empls.Status, empls.BillRate, 0, 0, empls.PayRate, @Day, '1899-12-30 00:00:00.000', @Day, '1899-12-30 00:00:00.000', 
      CASE @AdjType WHEN 'H' THEN @Amount ELSE 0 END, CASE @AdjType WHEN 'D' THEN @Amount ELSE 0 END,
	  @ClockAdjustmentNo,
	  @ClockAdjustmentNo,
	  adjs.AdjustmentName,
	  0, empls.AgencyNo, '3', ' ', '0', '0',
      ' ', 0, NULL, NULL, NULL, @UserCode
    FROM TimeCurrent..tblEmplNames AS empls
    INNER JOIN TimeCurrent..tblAdjCodes AS adjs
    ON adjs.Client = empls.Client
      AND adjs.GroupCode = empls.GroupCode
--      AND adjs.PayrollPeriodEndDate = empls.PayrollPeriodEndDate
      AND adjs.ClockAdjustmentNo = @ClockAdjustmentNo
    WHERE empls.Client = @Client
      AND empls.GroupCode = @GroupCode
      AND empls.SSN = @SSN
      AND empls.RecordStatus = '1'

    SET @RecordID = SCOPE_IDENTITY()

    IF @RecordID IS NULL
      SET @ErrorCode = @ErrorCode + 1
  
    IF @ReasonCodeID <> 0
      EXEC usp_Web1_AssignReasonCode @Client, @GroupCode, @SSN, @PPED, NULL, @ReasonCodeID, @RecordID

    SET @THDRecordID = @RecordID

    IF @RecordID IS NOT NULL
    BEGIN
      DECLARE @PateRecordID int
      SET @PateRecordID = (
        SELECT RecordID
        FROM tblTimeHistDetail_PATE
        WHERE THDRecordID = @RecordID
      )

      
      IF @PateRecordID IS NULL
      BEGIN
        INSERT INTO tblTimeHistDetail_PATE (THDRecordID, Brand)
        VALUES (@RecordID, @Brand)
      END
      ELSE
      BEGIN
        UPDATE tblTimeHistDetail_PATE SET Brand = @Brand WHERE THDRecordID = @RecordID
      END
    END

  END
  ELSE
  BEGIN
    -- It won't let me do this inline
    DECLARE @strPPED    AS varchar(10)
    SET @strPPED = CONVERT(varchar(10), @PPED, 101)

    RAISERROR ('Group %d is not set up for Pay Period %s', 16, 1, @GroupCode, @strPPED)
    SET @ErrorCode = @@error
    GOTO ErrorHandler
  END

  ErrorHandler:
  IF @ErrorCode = 0
    COMMIT TRANSACTION
  ELSE
    ROLLBACK TRANSACTION
END

SELECT @ErrorCode AS ReturnCode


