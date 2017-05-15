CREATE PROCEDURE [dbo].[usp_Web1_ApproveAssignmentTransaction_JM]
(
	@RecordId		BIGINT,  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 06Sept2016 >--
	@ApprovedHours			decimal(5,2),
	@ApprovedDollars		decimal(7,2),
	@Reason			varchar(1000),
	@UserId			int,
	@IsBackupUser	bit
)

AS


DECLARE @SubmittedHours decimal(5,2), @SubmittedDollars decimal(7,2), @ApprovalStatus varchar(1), 
		@DollarsCode int, @HoursCode INT, @Client VARCHAR(4), @GroupCode INT, @SSN INT, @PPED DATETIME 

-- The casting in this statement is to ensure precision when comparing the values
SELECT 
	@SubmittedDollars = Dollars, 
	@SubmittedHours = [Hours],
	@DollarsCode = CASE 
						WHEN CAST(Dollars as decimal(7,2)) < @ApprovedDollars THEN 7
						WHEN CAST(Dollars as decimal(7,2)) > @ApprovedDollars THEN 6
						ELSE 0 
					END,
	@HoursCode = CASE 
						WHEN CAST([Hours] as decimal(5,2)) < @ApprovedHours THEN 7
						WHEN CAST([Hours] as decimal(5,2)) > @ApprovedHours THEN 6
						ELSE 0 
					END,
	@ApprovalStatus = CASE WHEN CAST([Hours] as decimal(5,2)) <> @ApprovedHours 
						OR CAST(Dollars as decimal(7,2)) <> @ApprovedDollars THEN 'D' ELSE 'A' END,
  @Client = Client,
  @GroupCode = GroupCode,
  @SSN = SSN,
  @PPED = PayrollPeriodEndDate
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



IF @HoursCode > 0
BEGIN

	INSERT tblTimeHistDetail_Disputes (Client, GroupCode, PayrollPeriodEndDate, SSN, DetailRecordID, DisputeReason, 
											DisputeText, DisputeMinutes, DisputeHundredths, MaintUserId, MaintDateTime)
  	
	SELECT thd.Client, thd.GroupCode, thd.PayrollPeriodEndDate, thd.SSN, thd.RecordID, @HoursCode, 
			@Reason, 60 * ABS(@SubmittedHours - @ApprovedHours), ABS(@SubmittedHours - @ApprovedHours), @UserId, GETDATE()  
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
	INSERT TimeHistory..tblTimeHistDetail_BackupApproval (THDRecordId, Email, FirstName, LastName)
	
	SELECT 
		@RecordId, Email, FirstName, LastName
	FROM 
		TimeCurrent..tblStaffing_BackupEmail
	WHERE 
		PrimaryUserId = @UserId

END

-- This is not good for performance since it will recalculate status for every THD record.  We need to call this once at the end.
--EXEC TimeHistory.dbo.usp_EmplCalc_SummarizeAprvlStatus @Client, @GroupCode, @PPED, @SSN


