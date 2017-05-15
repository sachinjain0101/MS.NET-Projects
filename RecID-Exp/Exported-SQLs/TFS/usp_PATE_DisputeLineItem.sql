Create PROCEDURE [dbo].[usp_PATE_DisputeLineItem]
(
@Client char(4),
@GroupCode int,
@PPED datetime,
@SSN int,
@THDRecordId BIGINT,  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 25Aug2016 >--
@TransDate datetime,
@UserId int,
@UserName varchar(20),
@OrigHours numeric(7,2),
@NewHours numeric(7,2),
@DisputeText varchar(2000),
@Account varchar(10),
@IPAddress varchar(20)
) AS

DECLARE @DisputedHours numeric(7,2)
DECLARE @AutoApproveDispute char(1)
DECLARE @EmpStatus char(1)
DECLARE @AgencyNo int
DECLARE @DivisionId BIGINT  --< @DivisionId data type is changed from  INT to BIGINT by Srinsoft on 27Oct2016 >--
DECLARE @SiteNo int
DECLARE @DeptNo INT
DECLARE @BillRate NUMERIC(7,2)
DECLARE @PayRate NUMERIC(7,2)

SELECT @DisputedHours = @OrigHours - @NewHours
SELECT @AutoApproveDispute = '1'

IF NOT EXISTS	( SELECT 1
								FROM TimeHistory.dbo.tblTimeHistDetail_Disputes
								WHERE Client = @Client
								AND GroupCode = @GroupCode
								AND PayrollPeriodEndDate = @PPED
								AND SSN = @SSN
								AND DetailRecordID = @THDRecordID)
BEGIN
	INSERT INTO TimeHistory.dbo.tblTimeHistDetail_Disputes(Client, GroupCode, PayrollPeriodEndDate, SSN, DetailRecordID, DisputeText, DisputeReason, DisputeMinutes, DisputeHundredths)
	VALUES(@Client, @GroupCode, @PPED, @SSN, @THDRecordID, @DisputeText, '6', (@DisputedHours * 60), @DisputedHours)
END
ELSE
BEGIN
    -- The user can't edit a dispute, only remove it and add a new one. If a dispute already exists, there's a problem, like the form was submitted more than once, so just return. 
    RETURN
   /* 
	UPDATE TimeHistory.dbo.tblTimeHistDetail_Disputes
	SET DisputeText = @DisputeText,
			DisputeReason = '6', -- Subtract time OTHER
			DisputeMinutes = (@DisputedHours * 60),
			DisputeHundredths = @DisputedHours
	WHERE Client = @Client
	AND GroupCode = @GroupCode
	AND PayrollPeriodEndDate = @PPED
	AND SSN = @SSN
	AND DetailRecordID = @THDRecordID
	*/
END

UPDATE TimeHistory.dbo.tblTimeHistDetail
SET AprvlStatus = 'D',
		AprvlStatus_UserId = @UserId,
		AprvlStatus_Date = GetDate()
WHERE RecordID = @THDRecordID


IF (@AutoApproveDispute = '1')
BEGIN
	
	SELECT @EmpStatus = thd.EmpStatus,
				 @AgencyNo = thd.AgencyNo,
				 @DivisionId = thd.DivisionId,
				 @SiteNo = thd.SiteNo,
				 @DeptNo = gd.DeptNo,
				 @BillRate = thd.BillRate,
				 @PayRate = thd.PayRate
	FROM TimeHistory.dbo.tblTimeHistDetail thd
	INNER JOIN TimeCurrent.dbo.tblGroupDepts gd
	ON gd.Client = thd.Client
	AND gd.GroupCode = thd.GroupCode
	AND rtrim(ltrim(gd.ClientDeptCode)) = rtrim(ltrim(@Account))
	WHERE thd.RecordId = @THDRecordID

	INSERT INTO TimeHistory.dbo.tblTimeHistDetail(Client, GroupCode, SSN, PayrollPeriodEndDate, MasterPayrollDate, SiteNo, DeptNo, ShiftNo,BillRate,PayRate,
																								DivisionID, JobID, TransDate, InDay, OutDay, Hours, ClockAdjustmentNo, AdjustmentCode, 
																								AdjustmentName, InSrc, OutSrc, AprvlStatus, AprvlStatus_UserID, AprvlStatus_Date, AprvlAdjOrigRecID,
																								EmpStatus, AgencyNo, AprvlAdjOrigClkAdjNo)
	VALUES (@Client , @GroupCode, @SSN, @PPED, @PPED, @SiteNo, @DeptNo, 1, @BillRate, @PayRate,
					@DivisionId, 0, @TransDate, DatePart(dw, @TransDate), 0, @DisputedHours * -1, '@', '@', 
					'ADJ BILL/P', '3', '', 'L', @UserId, GetDate(), @THDRecordID, 
					@EmpStatus, @AgencyNo, '1')

	UPDATE TimeHistory.dbo.tblTimeHistDetail
	SET AprvlStatus = 'L'
	WHERE RecordID = @THDRecordID

	UPDATE TimeHistory.dbo.tblTimeHistDetail_Disputes
	SET AdjCode = '@'
	WHERE DetailRecordID = @THDRecordID

	INSERT INTO TimeCurrent..tblAdjustments(Client, GroupCode, PayrollPeriodEndDate, SSN, SiteNo,
																					DeptNo, ShiftNo, ClockAdjustmentNo, AdjustmentCode, AdjustmentName, HoursDollars,
																				  SunVal,
																					MonVal,
																					TueVal,
																					WedVal,
																					ThuVal,
																					FriVal,
																					SatVal,
																					TotalVal, Username, UserID, TransDateTime, IPAddr)
	VALUES (@Client, @GroupCode, @PPED, @SSN, @SiteNo, 
				 	@DeptNo, 1, '@', '@', 'ADJ BILL/P', 'H',
			   	CASE WHEN datepart(dw, @TransDate) = 1 THEN @DisputedHours * -1 ELSE 0 END,
				 	CASE WHEN datepart(dw, @TransDate) = 2 THEN @DisputedHours * -1 ELSE 0 END,
				 	CASE WHEN datepart(dw, @TransDate) = 3 THEN @DisputedHours * -1 ELSE 0 END,
				 	CASE WHEN datepart(dw, @TransDate) = 4 THEN @DisputedHours * -1 ELSE 0 END,
				 	CASE WHEN datepart(dw, @TransDate) = 5 THEN @DisputedHours * -1 ELSE 0 END,
				 	CASE WHEN datepart(dw, @TransDate) = 6 THEN @DisputedHours * -1 ELSE 0 END,
				 	CASE WHEN datepart(dw, @TransDate) = 7 THEN @DisputedHours * -1 ELSE 0 END,
				 	@DisputedHours * -1, 
				 	@UserName, @UserID, GetDate(), @IPAddress)

END


