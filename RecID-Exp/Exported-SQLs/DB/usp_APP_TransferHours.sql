CREATE  Procedure [dbo].[usp_APP_TransferHours](
         @Client char(4),
         @GroupCode int ,
         @HomeSiteNo INT ,  --< @HomeSiteNo data type is changed from  SMALLINT to INT by Srinsoft on 19Aug2016 >--
         @SSN int ,
         @DeptNo INT,  --< @DeptNo data type is changed from  SMALLINT to INT by Srinsoft on 19Aug2016 >--
		 @PPED datetime,
         @TransDate datetime,
         @ClockAdjustmentNo Varchar(3) , --< Srinsoft 08/25/2015 Changed  @ClockAdjustmentNo Char(1) to varchar(3) >--
         @Hours numeric(5,2),
		 @LogonName varchar(20),
		 @UserCode varchar(5),
		 @NewShift int = 1,
		 @ShiftDiffClass char(1) = ''
)
AS

SET NOCOUNT ON

DECLARE @HomeDept smallInt

SET @HomeDept = (
	SELECT PrimaryDept
	FROM TimeCurrent..tblEmplNames
	WHERE Client = @client
	AND GroupCode = @GroupCode
	AND SSN = @SSN
	)

DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 19Aug2016 >--
DECLARE @THDHours numeric(5,2) 
DECLARE @RemHours numeric(5,2)
DECLARE @DoW tinyInt
DECLARE	@Mon numeric(5,2)
DECLARE	@Tue numeric(5,2)
DECLARE	@Wed numeric(5,2)
DECLARE	@Thu numeric(5,2)
DECLARE	@Fri numeric(5,2)
DECLARE	@Sat numeric(5,2)
DECLARE	@Sun numeric(5,2)
DECLARE @AdjCode VARCHAR(3)
DECLARE @AdjName VARCHAR(30)
DECLARE @Err int

SET @Err = 0
SET @DoW = datepart(weekday, @TransDate)
DECLARE CsrTHD CURSOR LOCAL FAST_FORWARD FOR
SELECT thd.recordID,  Hours
	FROM tblTimeHistDetail As thd
	INNER JOIN TimeCurrent..tblAdjCodes AS adjs
	ON adjs.Client = thd.Client
	  AND adjs.GroupCode = thd.GroupCode
	  AND adjs.ClockAdjustmentNo = CASE WHEN thd.ClockAdjustmentNo IN ('8', '', ' ','S') THEN '1' ELSE thd.ClockAdjustmentNo END
	  AND adjs.Worked = 'Y'
	WHERE thd.Client = @Client
	AND thd.GroupCode = @GroupCode
	AND thd.SSN = @SSN
	AND thd.TransDate = @TransDate
	AND thd.Hours > 0
	ORDER BY CASE WHEN DeptNo = @HomeDept THEN 0 ELSE 1 END,
					 CASE WHEN SiteNo = @HomeSiteNo THEN 0 ELSE 1 END
/*	SELECT recordID,  Hours
	FROM tblTimeHistDetail
	WHERE Client = @Client
	AND GroupCode = @GroupCode
	AND SSN = @SSN
	AND TransDate = @TransDate
	AND Hours > 0
	AND ClockAdjustmentNo IN (' ', '1')
	ORDER BY CASE WHEN DeptNo = @HomeDept THEN 0 ELSE 1 END,
					 CASE WHEN SiteNo = @HomeSiteNo THEN 0 ELSE 1 END 
	-- Must place home dept / home site first
*/


SET @RemHours = @Hours

SET @Sun = 0
SET @Mon = 0
SET @Tue = 0
SET @Wed = 0
SET @Thu = 0
SET @Fri = 0
SET @Sat = 0

BEGIN TRAN

OPEN CsrTHD
FETCH NEXT FROM CsrTHD 
INTO @RecordID,  @THDHours
WHILE @@FETCH_STATUS = 0 AND @RemHours > 0 AND @Err = 0
BEGIN
	IF @RemHours >= @THDHours
		SET @THDHours = -1 * @THDHours
	ELSE
		SET @THDHours = -1 * @RemHours
	IF @DoW = 1
		Set @Sun = @THDHours
	ELSE IF @DoW = 2
		Set @Mon = @THDHours
	ELSE IF @DoW = 3
		Set @Tue = @THDHours
	ELSE IF @DoW = 4
		Set @Wed = @THDHours
	ELSE IF @DoW = 5
		Set @Thu = @THDHours
	ELSE IF @DoW = 6
		Set @Fri = @THDHours
	ELSE IF @DoW = 7
		Set @Sat = @THDHours
	
-- Create negating transactions
		INSERT INTO TimeCurrent..tblAdjustments 
				 (client,
					PayrollPeriodEndDate,
					DeptNo,
					ShiftNo,
					ClockAdjustmentNo,
					AdjustmentCode,
					AdjustmentName,
					GroupCode,
					SSN,
					SiteNo,
					HoursDollars,
					WeekVal,
					MonVal,
					TueVal,
					WedVal,
					ThuVal,
					FriVal,
					SatVal,
					SunVal,
					TotalVal,
					UserName,
					UserID,
					TransDateTime,
					IPAddr)
		SELECT client,
					 PayrollPeriodEndDate,
					 DeptNo,
					 ShiftNo,
					 ClockAdjustmentNo,
					 AdjustmentCode,
					 AdjustmentName,
					 GroupCode,
					 SSN,
					 SiteNo,
					 'H',
						0,
						@Mon,
						@Tue,
						@Wed,
						@Thu,
						@Fri,
						@Sat,
						@Sun,
						@THDHours,
						@LogonName,
						0,
						GetDate(),
						'99.99.99.99'
			FROM tblTimeHistDetail		
			WHERE recordID = @RecordID
	
			IF @@Error <> 0
				SET @Err = 1

			INSERT INTO tblTimeHistDetail 
					(client,
						GroupCode,
						SSN,
						PayrollPeriodEndDate,
						MasterPayrollDate,
						SiteNo,
						DeptNo,
						ShiftNo,
						JobId,
						UserCode,
						TransDate,
						EmpStatus,
						BillRate,
						BillOTRate,
						BillOTRateOverride,
						PayRate,
						InDay,
						OutDay,
						Hours,
						Dollars,
						ClockAdjustmentNo,
						AdjustmentCode,
						AdjustmentName,
						TransType,
						AgencyNo,
						InSrc,
						OutSrc,
						DaylightSavTime,
						Holiday,
						ShiftDiffClass)
			SELECT
						client,
						GroupCode,
						SSN,
						PayrollPeriodEndDate,
						MasterPayrollDate,
						SiteNo,
						DeptNo,
						ShiftNo,
						JobId,
						@UserCode,
						TransDate,
						EmpStatus,
						BillRate,
						BillOTRate,
						BillOTRateOverride,
						PayRate,
						InDay,
						OutDay,
						@THDHours,
						Dollars,
						CASE WHEN (ClockAdjustmentNo = '') THEN '1' ELSE ClockAdjustmentNo END,
						AdjustmentCode,
						CASE WHEN (ClockAdjustmentNo = '') THEN 'Worked' ELSE AdjustmentName END,
						TransType,
						AgencyNo,
						'3',
						' ',
						DaylightSavTime,
						Holiday,
						ShiftDiffClass
			FROM tblTimeHistDetail
			WHERE recordID = @RecordID

			IF @@Error <> 0
				SET @Err = 1


	SET @RemHours = @RemHours + @THDHours
	FETCH NEXT FROM CsrTHD 
	INTO @RecordID,  @THDHours
END
CLOSE CsrTHD
DEALLOCATE CsrTHD

-- create moved txn
IF @DoW = 1
	Set @Sun = @Hours
ELSE IF @DoW = 2
	Set @Mon = @Hours
ELSE IF @DoW = 3
	Set @Tue = @Hours
ELSE IF @DoW = 4
	Set @Wed = @Hours
ELSE IF @DoW = 5
	Set @Thu = @Hours
ELSE IF @DoW = 6
	Set @Fri = @Hours
ELSE IF @DoW = 7
	Set @Sat = @Hours



SELECT @AdjCode = left(AdjustmentCode,1), @AdjName = AdjustmentName
FROM timeCurrent..tblAdjCodes
WHERE ClockAdjustmentNo = @clockAdjustmentNo
AND Client = @Client

IF @NewShift = 0 
	Select @NewShift = 1

INSERT INTO TimeCurrent..tblAdjustments 
		 (client,
			PayrollPeriodEndDate,
			DeptNo,
			ShiftNo,
			ClockAdjustmentNo,
			AdjustmentCode,
			AdjustmentName,
			GroupCode,
			SSN,
			SiteNo,
			HoursDollars,
			WeekVal,
			MonVal,
			TueVal,
			WedVal,
			ThuVal,
			FriVal,
			SatVal,
			SunVal,
			TotalVal,
			UserName,
			UserID,
			TransDateTime,
			IPAddr)
Values(@Client,
			 @PPED,
			 @DeptNo,
			 @NewShift,
			 @ClockAdjustmentNo,
			 @AdjCode,
			 @AdjName,
			 @GroupCode,
			 @SSN,
			 @HomeSiteNo,
			 'H',
				0,
				@Mon,
				@Tue,
				@Wed,
				@Thu,
				@Fri,
				@Sat,
				@Sun,
				@Hours,
				@LogonName,
				0,
				GetDate(),
				'99.99.99.99'
	)


IF @@Error <> 0
	SET @Err = 1

INSERT INTO tblTimeHistDetail 
		(client,
			GroupCode,
			SSN,
			PayrollPeriodEndDate,
			MasterPayrollDate,
			SiteNo,
			DeptNo,
			ShiftNo,
			JobId,
			UserCode,
			TransDate,
			EmpStatus,
			BillRate,
			BillOTRate,
			BillOTRateOverride,
			PayRate,
			InDay,
			OutDay,
			Hours,
			Dollars,
			ClockAdjustmentNo,
			AdjustmentCode,
			AdjustmentName,
			TransType,
			AgencyNo,
			InSrc,
			OutSrc,
			DaylightSavTime,
			Holiday,
			ShiftDiffClass)
SELECT
			@Client,
			@GroupCode,
			@SSN,
			@PPED,
			MasterPayrollDate,
			@HomeSiteNo,
			@DeptNo,
			@NewShift,
			JobId,
			@UserCode,
			@TransDate,
			EmpStatus,
			BillRate,
			BillOTRate,
			BillOTRateOverride,
			PayRate,
			InDay,
			OutDay,
			@Hours,
			Dollars,
			@ClockAdjustmentNo,
			@AdjCode,
			@AdjName,
			TransType,
			AgencyNo,
			'3',
			' ',
			DaylightSavTime,
			Holiday,
			@ShiftDiffClass
FROM tblTimeHistDetail
WHERE recordID = @RecordID

IF @@Error <> 0
	SET @Err = 1

IF @Err = 0
	COMMIT TRAN
ELSE
	ROLLBACK TRAN







