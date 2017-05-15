Create PROCEDURE [dbo].[usp_Web1_DisputeHoursByFaxException] (
  @Client      char(4),
  @GroupCode   int,
  @PPED       datetime,
  @TransDate DATETIME,
  @SSN INT, 
  @DisputeHours NUMERIC(5, 2),
  @DisputeMins INT,
  @DisputeReason INT, 
  @Comment VARCHAR(1000),
  @DetailedRecordID BIGINT,   --< @DetailedRecordId data type is changed from  INT to BIGINT by Srinsoft on 07Sept2016 >--
  @AdjustType CHAR(1),
  @UserID INT,
  @UserName varchar(100),
  @Address VARCHAR(100)
)
AS


DECLARE @ErrorCode     int
DECLARE @Count INT
DECLARE @CheckForOriginalRecordID INT

--- From tblTimehistDetail
DECLARE @SiteNo INT
DECLARE @DeptNo INT
DECLARE @ShiftNo INT
DECLARE @DivisionID BIGINT  --< @DivisionId data type is changed from  INT to BIGINT by Srinsoft on 02Nov2016 >--
DECLARE @InDay INT
DECLARE @EmpStatus INT
DECLARE @AgencyNo INT
DECLARE @ClockAdjustmentNo CHAR(1)

-----From tblAdjcode
DECLARE @ClockAdjustment CHAR(1)
DECLARE @AdjustmentCode VARCHAR(3)
DECLARE @AdjustmentName VARCHAR(50)

SET @Count = 0
SET @CheckForOriginalRecordID = 0
SET @ErrorCode =0 

BEGIN TRANSACTION
	
	---- find out there exist dispute or not
	SET @Count = (
				SELECT COUNT(*)
				FROM tblTimeHistDetail_Disputes
				WHERE Client = @Client
				AND GroupCode = @GroupCode
				AND PayrollPeriodEndDate = @PPED
				AND SSN = @SSN
				AND DetailRecordID = @DetailedRecordID
			)

	IF @Count = 0
	BEGIN
		IF @Client = 'PATE'
		BEGIN
			INSERT INTO tblTimeHistDetail_Disputes(Client, GroupCode, PayrollPeriodEndDate, SSN, DetailRecordID)
			SELECT Client, GroupCode, PayrollPeriodEndDate, SSN, RecordID
			FROM TimeHistory..tblTimeHistDetail WHERE Recordid = @DetailedRecordID
			IF @@ROWCOUNT = 0
				SET @ErrorCode = @ErrorCode +1
		END
		ELSE
		BEGIN
			INSERT INTO tblTimeHistDetail_Disputes(Client, GroupCode, PayrollPeriodEndDate, SSN, DetailRecordID)
			VALUES(@Client, @GroupCode, @PPED, @SSN, @DetailedRecordID)
			IF @@ROWCOUNT = 0
				SET @ErrorCode = @ErrorCode +1
		END	
	END
	
	UPDATE tblTimeHistDetail
	SET AprvlStatus = 'D', AprvlStatus_UserId = @UserID, AprvlStatus_Date = GetDate()
	WHERE RecordID = @DetailedRecordID
	IF @@ROWCOUNT = 0
		SET @ErrorCode = @ErrorCode +1
	
	UPDATE tblTimeHistDetail_Disputes
	SET Disputetext = @Comment, DisputeReason = @DisputeReason, DisputeMinutes = @DisputeMins, DisputeHundredths =@DisputeHours, MaintUserId = @UserID, 	MaintDateTime = GetDate()
	WHERE Client = @Client
	AND GroupCode = @GroupCode
	AND PayrollPeriodEndDate = @PPED
	AND SSN = @SSN
	AND DetailRecordID = @DetailedRecordID
	IF @@ROWCOUNT = 0
		SET @ErrorCode = @ErrorCode +1
		
	---------------------------------------   until now put dispute and from now resolve it -------------------------------------------------------------
	
	--- Get old values from tbltimehistdetail
	SELECT @SiteNo = SiteNo, @DeptNo=DeptNo, @ShiftNo=ShiftNo, @DivisionID=DivisionID, @InDay=InDay, @EmpStatus=EmpStatus, @AgencyNo=AgencyNo, @ClockAdjustmentNo=ClockAdjustmentNo
	FROM TimeHistory..tblTimeHistDetail
	WHERE RecordID = @DetailedRecordID
	
	SELECT @ClockAdjustment = ClockAdjustmentNo, @AdjustmentCode = AdjustmentCode, @AdjustmentName = @AdjustmentName
	FROM TimeCurrent..tblAdjCodes
	WHERE Client=@Client
	AND GroupCode=@GroupCode
	AND ClockAdjustmentNo = @AdjustType
	
	----- insert the disputed value into timehisdetail 
	INSERT INTO tblTimeHistDetail(Client, GroupCode, SSN, PayrollPeriodEndDate, MasterPayrollDate, SiteNo, DeptNo, ShiftNo, DivisionID, JobID, 
				TransDate, InDay, OutDay, Hours, ClockAdjustmentNo, AdjustmentCode, AdjustmentName, InSrc, OutSrc, AprvlStatus, 
				AprvlStatus_UserID, AprvlStatus_Date, AprvlAdjOrigRecID, EmpStatus, AgencyNo, AprvlAdjOrigClkAdjNo, PayRate, BillRate) 
	VALUES (@Client, @GroupCode, @SSN, @PPED, @PPED, @SiteNo, @DeptNo, @ShiftNo, @DivisionID, 0, @TransDate, @InDay, 0, 
	               CASE WHEN @DisputeReason = 6 THEN -@DisputeHours ELSE @DisputeHours END,@ClockAdjustment, @AdjustmentCode, Left(@AdjustmentName, 10), '3', '', 'L', 
	               @UserID, GETDATE(), @DetailedRecordID, @EmpStatus, @AgencyNo, @ClockAdjustmentNo, 0, 0) 
	
	IF @@ROWCOUNT = 0
		SET @ErrorCode = @ErrorCode +1
	
	---- update the exisitng value 
	UPDATE tblTimeHistDetail 
	SET AprvlStatus = 'L' 
	WHERE RecordID = @DetailedRecordID
	
	IF @@ROWCOUNT = 0
		SET @ErrorCode = @ErrorCode +1
	
	---- update the exisitng dispute
	UPDATE tblTimeHistDetail_Disputes 
	SET AdjCode = @AdjustmentCode 
	WHERE DetailRecordID = @DetailedRecordID
	
	IF @@ROWCOUNT = 0
		SET @ErrorCode = @ErrorCode +1
	
	
	 --- insert into tblAdjustments table
	 IF @InDay = 1
	 BEGIN
		 INSERT INTO TimeCurrent..tblAdjustments(Client, GroupCode, PayrollPeriodEndDate, SSN, SiteNo, DeptNo, ShiftNo, ClockAdjustmentNo, AdjustmentCode, AdjustmentName, HoursDollars,
		 				SunVal,TotalVal, Username, UserID, TransDateTime, IPAddr) 
		 VALUES (@Client, @GroupCode, @PPED, @SSN, @SiteNo, @DeptNo, @ShiftNo, @ClockAdjustment, @AdjustmentCode, Left(@AdjustmentName, 10), @AdjustType,
	 		 CASE WHEN @DisputeReason = 6 THEN -@DisputeHours ELSE @DisputeHours END,
	 		 CASE WHEN @DisputeReason = 6 THEN -@DisputeHours ELSE @DisputeHours END, 
	 		 SUBSTRING(@UserName,1,20), @UserID, GETDATE(), @Address)
	 END
	 ELSE IF @InDay=2
 	 BEGIN
 	 	INSERT INTO TimeCurrent..tblAdjustments(Client, GroupCode, PayrollPeriodEndDate, SSN, SiteNo, DeptNo, ShiftNo, ClockAdjustmentNo, AdjustmentCode, AdjustmentName, HoursDollars,
		 				MonVal,TotalVal, Username, UserID, TransDateTime, IPAddr) 
		 VALUES (@Client, @GroupCode, @PPED, @SSN, @SiteNo, @DeptNo, @ShiftNo, @ClockAdjustment, @AdjustmentCode, Left(@AdjustmentName, 10), @AdjustType,
	 		 CASE WHEN @DisputeReason = 6 THEN -@DisputeHours ELSE @DisputeHours END,
	 		 CASE WHEN @DisputeReason = 6 THEN -@DisputeHours ELSE @DisputeHours END, 
	 		 SUBSTRING(@UserName,1,20), @UserID, GETDATE(), @Address)
 	 END
 	 ELSE IF @InDay=3
 	 BEGIN
 	 	INSERT INTO TimeCurrent..tblAdjustments(Client, GroupCode, PayrollPeriodEndDate, SSN, SiteNo, DeptNo, ShiftNo, ClockAdjustmentNo, AdjustmentCode, AdjustmentName, HoursDollars,
		 				TueVal,TotalVal, Username, UserID, TransDateTime, IPAddr) 
		 VALUES (@Client, @GroupCode, @PPED, @SSN, @SiteNo, @DeptNo, @ShiftNo, @ClockAdjustment, @AdjustmentCode, Left(@AdjustmentName, 10), @AdjustType,
	 		 CASE WHEN @DisputeReason = 6 THEN -@DisputeHours ELSE @DisputeHours END,
	 		 CASE WHEN @DisputeReason = 6 THEN -@DisputeHours ELSE @DisputeHours END, 
	 		 SUBSTRING(@UserName,1,20), @UserID, GETDATE(), @Address)
 	 END
 	 ELSE IF @InDay=4
 	 BEGIN
 	 	INSERT INTO TimeCurrent..tblAdjustments(Client, GroupCode, PayrollPeriodEndDate, SSN, SiteNo, DeptNo, ShiftNo, ClockAdjustmentNo, AdjustmentCode, AdjustmentName, HoursDollars,
		 				WedVal,TotalVal, Username, UserID, TransDateTime, IPAddr) 
		 VALUES (@Client, @GroupCode, @PPED, @SSN, @SiteNo, @DeptNo, @ShiftNo, @ClockAdjustment, @AdjustmentCode, Left(@AdjustmentName, 10), @AdjustType,
	 		 CASE WHEN @DisputeReason = 6 THEN -@DisputeHours ELSE @DisputeHours END,
	 		 CASE WHEN @DisputeReason = 6 THEN -@DisputeHours ELSE @DisputeHours END, 
	 		 SUBSTRING(@UserName,1,20), @UserID, GETDATE(), @Address)
 	 END
 	 ELSE IF @InDay=5
 	 BEGIN
 	 	INSERT INTO TimeCurrent..tblAdjustments(Client, GroupCode, PayrollPeriodEndDate, SSN, SiteNo, DeptNo, ShiftNo, ClockAdjustmentNo, AdjustmentCode, AdjustmentName, HoursDollars,
		 				ThuVal,TotalVal, Username, UserID, TransDateTime, IPAddr) 
		 VALUES (@Client, @GroupCode, @PPED, @SSN, @SiteNo, @DeptNo, @ShiftNo, @ClockAdjustment, @AdjustmentCode, Left(@AdjustmentName, 10), @AdjustType,
	 		 CASE WHEN @DisputeReason = 6 THEN -@DisputeHours ELSE @DisputeHours END,
	 		 CASE WHEN @DisputeReason = 6 THEN -@DisputeHours ELSE @DisputeHours END, 
	 		 SUBSTRING(@UserName,1,20), @UserID, GETDATE(), @Address)
 	 END	
 	 ELSE IF @InDay=6
 	 BEGIN
 	 	INSERT INTO TimeCurrent..tblAdjustments(Client, GroupCode, PayrollPeriodEndDate, SSN, SiteNo, DeptNo, ShiftNo, ClockAdjustmentNo, AdjustmentCode, AdjustmentName, HoursDollars,
		 				FriVal,TotalVal, Username, UserID, TransDateTime, IPAddr) 
		 VALUES (@Client, @GroupCode, @PPED, @SSN, @SiteNo, @DeptNo, @ShiftNo, @ClockAdjustment, @AdjustmentCode, Left(@AdjustmentName, 10), @AdjustType,
	 		 CASE WHEN @DisputeReason = 6 THEN -@DisputeHours ELSE @DisputeHours END,
	 		 CASE WHEN @DisputeReason = 6 THEN -@DisputeHours ELSE @DisputeHours END, 
	 		 SUBSTRING(@UserName,1,20), @UserID, GETDATE(), @Address)
 	 END
 	 ELSE
 	 BEGIN
 	 	INSERT INTO TimeCurrent..tblAdjustments(Client, GroupCode, PayrollPeriodEndDate, SSN, SiteNo, DeptNo, ShiftNo, ClockAdjustmentNo, AdjustmentCode, AdjustmentName, HoursDollars,
		 				SatVal,TotalVal, Username, UserID, TransDateTime, IPAddr) 
		 VALUES (@Client, @GroupCode, @PPED, @SSN, @SiteNo, @DeptNo, @ShiftNo, @ClockAdjustment, @AdjustmentCode, Left(@AdjustmentName, 10), @AdjustType,
	 		 CASE WHEN @DisputeReason = 6 THEN -@DisputeHours ELSE @DisputeHours END,
	 		 CASE WHEN @DisputeReason = 6 THEN -@DisputeHours ELSE @DisputeHours END, 
	 		 SUBSTRING(@UserName,1,20), @UserID, GETDATE(), @Address)
 	 END
 	 

	 IF @@ROWCOUNT = 0
		SET @ErrorCode = @ErrorCode +1
	 
	 

IF @ErrorCode = 0
    COMMIT TRANSACTION
ELSE
    ROLLBACK TRANSACTION

SELECT @ErrorCode AS ErrorCode




