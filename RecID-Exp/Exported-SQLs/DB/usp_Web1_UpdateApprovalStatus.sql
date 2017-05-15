CREATE   procedure [dbo].[usp_Web1_UpdateApprovalStatus]
(
  @THDRecordId BIGINT,  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 15Sept2016 >--
  @Client varchar(4),
  @GroupCode int,
  @SSN int,
  @SiteNo int,
  @DeptNo int,
  @PPED datetime,
  @ApprovalStatus char(1),
  @DisputeReason int,
  @CorrectedHours numeric(5,2),
  @CorrectedDollars numeric(7,2),
  @DisputeText varchar(1000),
  @BackupUser CHAR(1),
  @MaintUserId int,
  @DisputeType char(1),
  @AlternateEmail  VARCHAR(50) = NULL,
  @MobileApproved BIT = NULL
)
AS


DECLARE @DisputeMinutes numeric(5,0)
DECLARE @DisputeHundredths numeric(5,2)
DECLARE @CurrentHours numeric(5,2)
DECLARE @CorrectedMinutes numeric(5,0)
DECLARE @CurrentDollars numeric(5,2)
DECLARE @MaintDateTime datetime

SET @MaintDateTime = GETDATE()

IF (@MobileApproved IS NULL)
BEGIN
  IF EXISTS(SELECT 1
            FROM master..sysprocesses
            WHERE spid = @@spid
            AND RTRIM(Program_Name) = '.Net SqlClient Data Provider')
  BEGIN
    SET @MobileApproved = 1
  END
END

UPDATE TimeHistory..tblTimeHistDetail
SET AprvlStatus = @ApprovalStatus,
    AprvlStatus_UserID = @MaintUserId,
    AprvlStatus_Date = @MaintDateTime,
    AprvlStatus_Mobile = @MobileApproved
WHERE RecordId = @THDRecordId

UPDATE TimeHistory..tblTimeHistDetail
SET AprvlStatus = 'A',
    AprvlStatus_UserID = @MaintUserId,
    AprvlStatus_Date = @MaintDateTime
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


IF @ApprovalStatus = 'D'
BEGIN
--    IF @CorrectedHours > 0
		IF @DisputeType = 'H'
    BEGIN
	    SET @CorrectedMinutes = @CorrectedHours * 60
	
	    SELECT @CurrentHours = Hours
	    FROM TimeHistory..tblTimeHistDetail
	    WHERE RecordId = @THDRecordId
	
	    IF @CurrentHours < @CorrectedHours 
	    BEGIN
	    	SET @DisputeReason = '7'
	    END
	    SET @DisputeMinutes = abs(@CurrentHours * 60 - @CorrectedHours * 60)       
	    SET @DisputeHundredths = abs(@CurrentHours - @CorrectedHours)	    
    END
    ELSE IF @DisputeType = 'D'
    BEGIN
      SELECT @CurrentDollars = Dollars
      FROM TimeHistory..tblTimeHistDetail
      WHERE RecordID = @THDRecordId

      IF @CurrentDollars < @CorrectedHours
      BEGIN
      	SET @DisputeReason = '7'
      END
      SET @DisputeMinutes = 0
      SET @DisputeHundredths = ABS(@CurrentDollars - @CorrectedDollars)            
    END
    
		INSERT INTO tblTimeHistDetail_Disputes(Client, GroupCode, PayrollPeriodEndDate, SSN, DetailRecordID, DisputeReason,DisputeText,DisputeMinutes,DisputeHundredths,MaintUserId,MaintDateTime)
  	VALUES(@Client, @GroupCode, @PPED, @SSN, @THDRecordId,@DisputeReason,@DisputeText,@DisputeMinutes,@DisputeHundredths,@MaintUserId,@MaintDateTime)  
END

IF @BackupUser = '1'
BEGIN
	DECLARE @FirstName VARCHAR(40)
	DECLARE @LastName VARCHAR(40)

	SELECT @FirstName = FirstName, @LastName = LastName
	FROM TimeCurrent..tblStaffing_BackupEmail
	WHERE PrimaryUserId = @MaintUserId
	AND Email = @AlternateEmail
	ORDER BY RecordId DESC

    IF EXISTS (
		SELECT 1
		FROM TimeHistory..tblTimeHistDetail_BackupApproval
		WHERE THDRecordId = @THDRecordId
	)
	BEGIN
		UPDATE TimeHistory..tblTimeHistDetail_BackupApproval
		SET Email = @AlternateEmail, FirstName = @FirstName, LastName = @LastName
		WHERE THDRecordId = @THDRecordId	
	END
	ELSE
	BEGIN
		INSERT INTO TimeHistory..tblTimeHistDetail_BackupApproval(THDRecordId,Email,FirstName,LastName)
		VALUES (@THDRecordId,@AlternateEmail,@FirstName,@LastName)
	END
END

-- This is not good for performance since it will recalculate status for every THD record.  We need to call this once at the end.
EXEC TimeHistory.dbo.usp_EmplCalc_SummarizeAprvlStatus @Client, @GroupCode, @PPED, @SSN
