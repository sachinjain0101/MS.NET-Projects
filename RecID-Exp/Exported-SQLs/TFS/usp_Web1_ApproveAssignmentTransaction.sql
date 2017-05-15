Create PROCEDURE [dbo].[usp_Web1_ApproveAssignmentTransaction]
(
	@RecordId		BIGINT,  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 06Sept2016 >--
	@ApprovedHours			decimal(5,2),
	@ApprovedDollars		decimal(7,2),
	@Reason			varchar(1000),
	@UserId			int,
	@IsBackupUser	BIT,
	@AlternateEmail  VARCHAR(50) = ''
)

AS

DECLARE @SubmittedHours decimal(5,2), @SubmittedDollars decimal(7,2), @ApprovalStatus varchar(1), 
		@DollarsCode int, @HoursCode INT, @Client VARCHAR(4), @GroupCode INT, @SSN INT,
		@SiteNo INT, @DeptNo INT, @PPED DATETIME, @TransDate DATETIME, 
		@TotalHours decimal(5,2), @TotalDollars decimal(7,2),
		@ClockAdjustmentNo varchar(3) --< Srinsoft 09/09/2015 Changed @ClockAdjustmentNo char(1) to varchar(3) >--



-- The casting in this statement is to ensure precision when comparing the values
SELECT 
	@SubmittedDollars = Dollars, 
	@SubmittedHours = [Hours],
	@DollarsCode = CASE 
						WHEN CAST(Dollars as decimal(7,2)) > @ApprovedDollars THEN 7
						WHEN CAST(Dollars as decimal(7,2)) < @ApprovedDollars THEN 6
						ELSE 0 
					END,
	@HoursCode = CASE 
						WHEN CAST([Hours] as decimal(5,2)) > @ApprovedHours THEN 7
						WHEN CAST([Hours] as decimal(5,2)) < @ApprovedHours THEN 6
						ELSE 0 
					END,
	@ApprovalStatus = CASE WHEN CAST([Hours] as decimal(5,2)) <> @ApprovedHours 
						OR CAST(Dollars as decimal(7,2)) <> @ApprovedDollars THEN 'D' ELSE 'A' END,
	@Client = Client,
	@GroupCode = GroupCode,
	@SSN = SSN,
	@SiteNo = SiteNo,
	@DeptNo = DeptNo,
	@PPED = PayrollPeriodEndDate,
	@TransDate = TransDate,
	@ClockAdjustmentNo = CASE IsNULL(ClockAdjustmentNo, '')
							WHEN '' THEN '1' 
							WHEN '8' THEN '1'
							ELSE ClockAdjustmentNo 
						END

FROM 
	TimeHistory..tblTimeHistDetail 
WHERE 
	RecordId = @RecordId

UPDATE 
	TimeHistory..tblTimeHistDetail
SET 
	AprvlStatus = @ApprovalStatus,
    AprvlStatus_UserID = @UserId,
    AprvlStatus_Date = GETDATE(),
    AprvlStatus_Mobile = 0
WHERE 
	RecordId = @RecordId

UPDATE TimeHistory..tblTimeHistDetail
SET AprvlStatus = 'A',
    AprvlStatus_UserID = @UserId,
    AprvlStatus_Date = GETDATE()
WHERE Client = @Client
AND GroupCode = @GroupCode
AND SSN = @SSN
AND PayrollPeriodEndDate = @PPED
AND Hours = 0
AND Dollars = 0
AND SiteNo = @SiteNo
AND DeptNo = @DeptNo
AND InDay <> 10
AND OutDay <> 10
AND ISNULL(AprvlStatus, '') = ''


IF @HoursCode > 0
BEGIN
	
	--Handle DisputeValues
	SET @TotalHours = (SELECT CAST(SUM([Hours]) as decimal(5,2)) 
						FROM tblTimeHistDetail 
						WHERE Client = @Client AND GroupCode = @GroupCode AND SSN = @SSN 
							AND @ClockAdjustmentNo = CASE IsNULL(ClockAdjustmentNo, '')
														WHEN '' THEN '1' 
														WHEN '8' THEN '1'
														ELSE ClockAdjustmentNo 
													END
							AND SiteNo = @SiteNo AND DeptNo = @DeptNo
							AND PayrollPeriodEndDate = @PPED AND TransDate = @TransDate)
						
	IF @TotalHours > @ApprovedHours
		SET @HoursCode = 6
	ELSE
		SET @HoursCode = 7

	INSERT tblTimeHistDetail_Disputes (Client, GroupCode, PayrollPeriodEndDate, SSN, DetailRecordID, DisputeReason, 
											DisputeText, DisputeMinutes, DisputeHundredths, MaintUserId, MaintDateTime)

	SELECT thd.Client, thd.GroupCode, thd.PayrollPeriodEndDate, thd.SSN, thd.RecordID, @HoursCode, 
			@Reason, 60 * ABS(@TotalHours - @ApprovedHours), ABS(@TotalHours - @ApprovedHours), @UserId, GETDATE()  
	FROM 
		TimeHistory..tblTimeHistDetail thd
	WHERE 
		thd.RecordID = @RecordId
END

IF @DollarsCode > 0
BEGIN
	INSERT tblTimeHistDetail_Disputes (Client, GroupCode, PayrollPeriodEndDate, SSN, DetailRecordID, DisputeReason, 
											DisputeText, DisputeMinutes, DisputeHundredths, MaintUserId, MaintDateTime)

	SELECT thd.Client, thd.GroupCode, thd.PayrollPeriodEndDate, thd.SSN, thd.RecordID, @DollarsCode, 
			@Reason, 0, ABS(@SubmittedDollars - @ApprovedDollars), @UserId, GETDATE()  
	FROM 
		TimeHistory..tblTimeHistDetail thd
	WHERE 
		thd.RecordID = @RecordId
END


IF @IsBackupUser = 1
BEGIN
	DECLARE @FirstName VARCHAR(40)
	DECLARE @LastName VARCHAR(40)

    SELECT @FirstName = FirstName, @LastName = LastName
	FROM TimeCurrent..tblStaffing_BackupEmail
	WHERE PrimaryUserId = @UserId
	AND Email = @AlternateEmail

    IF EXISTS (
		SELECT 1
		FROM TimeHistory..tblTimeHistDetail_BackupApproval
		WHERE THDRecordId = @RecordId
	)
	BEGIN

		UPDATE TimeHistory..tblTimeHistDetail_BackupApproval
		SET Email = @AlternateEmail, FirstName = @FirstName, LastName = @LastName
		WHERE THDRecordId = @RecordId	
	END
	ELSE
	BEGIN
		INSERT INTO TimeHistory..tblTimeHistDetail_BackupApproval(THDRecordId,Email,FirstName,LastName)
		VALUES (@RecordId,@AlternateEmail,@FirstName,@LastName)
	END
END



