CREATE                                       PROCEDURE [dbo].[usp_Web1_AddAdjustmentEntry] (
  @Client      char(4),
  @GroupCode   int,
  @SiteNo      int,
  @SSN         int,
  @DeptNo      int,
  @ShiftNo     int,
  @PPED        datetime,
  @ClockAdjustmentNo  varchar(3), --< Srinsoft 09/09/2015 Changed @ClockAdjustmentNo char(1) to varchar(3) >--
  @AdjType     char(1),
  @RegHours		 numeric(5,2),
  @OTHours     numeric(5,2),
  @DTHours     numeric(5,2),
  @Amount      numeric(7,2),
  @Day         tinyint,
  @Approval    char(1),
  @Auto        char(1),
  @FLSA       char(1),
  @StartDate  datetime,
  @EndDate   datetime,
  @FaxPageId INT,
  @UserID      int,
  @ReasonCodeID  int = 0,
  @ShiftDiffClass char(1) = '',
  @DayError int OUTPUT
)
AS

--*/

DECLARE @ErrorCode     int
DECLARE @thdRecordCnt  int
DECLARE @adjRecordCnt  int
DECLARE @SweptDateTime datetime
DECLARE @AdjDate datetime
DECLARE @xAdjHours numeric(5,2)
DECLARE @PeriodStatus char(1)
DECLARE @Comment varchar(8000)

DECLARE @FaxApprovalUserID INT

DECLARE @PrevAmount numeric(7,2)

SET @SweptDateTime = NULL
SET @ErrorCode = 0
SET @xAdjHours = 0.00
SET @PrevAmount = 0.00
                  
SELECT @PeriodStatus = Status
FROM TimeHistory..tblPeriodEndDates
WHERE Client = @Client
AND GroupCode = @GroupCode
AND PayrollPeriodEndDate = @PPED

IF @PeriodStatus = 'C'
BEGIN
  SET @xAdjHours = @Amount
END

-- Force the Rest Penalty Adjustment to zero hours.
-- for Davita Only.
IF @Client in('DAVT','DVPC') and @ClockAdjustmentNo = 'H'
	Set @Amount = 0.00

--Begin Transcation for this call
BEGIN TRANSACTION

--If this is for hours adjustment, then delete previous values
IF @ClockAdjustmentNo = '1'
BEGIN
	--Get the amount which is going to be updated
	SET @PrevAmount= (SELECT SUM(Hours) FROM tblTimeHistDetail 
			WHERE Client = @Client AND GroupCode = @GroupCode AND SSN = @SSN 
			AND DeptNo = @DeptNo
			AND payrollperiodenddate = @PPED
			AND (InTime = '1899-12-30 00:00:00.000' OR InTime IS NULL)
			AND (OutTime = '1899-12-30 00:00:00.000' OR OutTime IS NULL)
			AND ClockAdjustmentNo in ('1','8','')
			AND Hours <> 0
			AND InDay = @Day)

	DELETE FROM tblTimeHistDetail 
	WHERE Client = @Client AND GroupCode = @GroupCode AND SSN = @SSN 
	AND DeptNo = @DeptNo
	AND payrollperiodenddate = @PPED
	AND (InTime = '1899-12-30 00:00:00.000' OR InTime IS NULL)
	AND (OutTime = '1899-12-30 00:00:00.000' OR OutTime IS NULL)
	AND ClockAdjustmentNo in ('1','8','')
	AND InDay = @Day
END

IF(@Amount > 0)
BEGIN
	IF @ErrorCode = 0
	BEGIN
	  
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
			DECLARE @DiffType char(1)
			DECLARE @DiffRate numeric(7,2)
	
			IF @ShiftDiffClass != '' AND @AdjType = 'H' AND @ClockAdjustmentNo = '1'
			BEGIN
				SELECT top 1 @DiffType = DiffType, @DiffRate = DiffRate
				FROM TimeCurrent.dbo.tblDeptShiftDiffs
				WHERE client = @Client
				 and GroupCode = @Groupcode
				 and SiteNo = @SiteNo
				 and ShiftNo = @ShiftDiffClass
				 and (DeptNo = @DeptNo or DeptNo = 99)

				 and ApplyDiff = '1' 
				 and DiffType <> 'D' 
				 and WorkSpan1 <= @Amount
				 and RecordStatus = '1'
				 and CASE @Day
							WHEN 1 THEN ApplyDay1
							WHEN 2 THEN ApplyDay2
							WHEN 3 THEN ApplyDay3
							WHEN 4 THEN ApplyDay4
							WHEN 5 THEN ApplyDay5
							WHEN 6 THEN ApplyDay6
							WHEN 7 THEN ApplyDay7
						END IN ('1', '2')
				ORDER BY case when DeptNo = 99 then 9 else 0 end
	
			END
			IF @DiffType IS NULL
			BEGIN
				SET @DiffType = 'R'
				SET @DiffRate = 0
			END
	
	    IF @UserID = 0
	    BEGIN
	      SET @UserCode = 'EMP'
	    END
	    ELSE
	    BEGIN
	      SET @UserCode = (SELECT UserCode FROM TimeCurrent..tblUser WHERE UserID = @UserID)
	    END
	    
	    Set @DefaultShiftNo = (Select DefaultShift from TimeCurrent..tblSiteNames where client = @Client and groupcode = @GroupCode and SiteNo = @SiteNo)
	
	    IF isNULL(@DefaultShiftNo,0) = 0
	    BEGIN
	      Set @DefaultShiftNo = 1
	    END
	
	    IF @ShiftNo in(0,1)
	      Set @ShiftNo = @DefaultShiftNo
	
		-----Get Fax approval user id
		SET @FaxApprovalUserID = (SELECT UserID FROM TimeCurrent.dbo.tblUser WHERE Client =@Client AND JobDesc = 'FAXAROO_DEFAULT_APPROVER')
		
	
	    DECLARE @RecordID    BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 06Sept2016 >--
	
	    -- tblTimeHistDetail
	    INSERT INTO [TimeHistory].[dbo].[tblTimeHistDetail]([Client], [GroupCode], [SSN], [PayrollPeriodEndDate], [MasterPayrollDate], [SiteNo], [DeptNo], [ShiftNo], [JobID],
	      [TransDate], [EmpStatus], [BillRate], [BillOTRate], [BillOTRateOverride], [PayRate], [InDay], [InTime], [OutDay], [OutTime], [Hours], [Dollars],
	      [ClockAdjustmentNo], [AdjustmentCode], [AdjustmentName], [TransType], [AgencyNo], [InSrc], [OutSrc], [DaylightSavTime], [Holiday], [RegHours], [OT_Hours], [DT_Hours],
	      [xAdjHours], [AprvlStatus], [AprvlStatus_UserID], [AprvlStatus_Date], [AprvlAdjOrigRecID], [AprvlAdjOrigClkAdjNo], [ClkTransNo], [UserCode], [ShiftDiffClass], [ShiftDiffAmt])
	    SELECT TOP 1 @Client, @GroupCode, @SSN, @PPED, @MasterPayrollDate, @SiteNo, @DeptNo, @ShiftNo, 0,
	      CASE WHEN @Day <= DATEPART(dw, @PPED)
	      THEN DATEADD(day, -(DATEPART(dw, @PPED) - @Day), @PPED)
	      ELSE DATEADD(day, ((@Day - DATEPART(dw, @PPED)) - 7), @PPED)
	      END,
	      empls.Status, empldepts.BillRate, 0, 0, empldepts.PayRate, @Day, '1899-12-30 00:00:00.000', @Day, '1899-12-30 00:00:00.000', 
	      CASE @AdjType WHEN 'H' THEN @Amount ELSE 0 END, CASE @AdjType WHEN 'D' THEN @Amount ELSE 0 END,
	      @ClockAdjustmentNo, @ClockAdjustmentNo, adjs.AdjustmentName, 0, empls.AgencyNo, '3', ' ', '0', '0', @RegHours, @OTHours, @DTHours,
	      @xAdjHours, CASE @Approval WHEN '1' THEN 'A' ELSE '' END, CASE @Approval WHEN '1' THEN @FaxApprovalUserID ELSE '' END,  CASE @Approval WHEN '1' THEN GETDATE() ELSE NULL END, NULL, NULL, @UserID,'FAX', @ShiftDiffClass,
				CASE WHEN @DiffType = 'R' THEN @DiffRate
						 WHEN @DiffType = 'P' THEN ROUND(@DiffRate * emplDepts.PayRate, 2)
						 ELSE 0 END
	    FROM tblEmplNames AS empls
	    LEFT JOIN tblEmplNames_Depts AS empldepts
	    ON empldepts.Client = empls.Client
	      AND empldepts.GroupCode = empls.GroupCode
	      AND empldepts.SSN = empls.SSN
	      AND empldepts.PayrollPeriodEndDate = empls.PayrollPeriodEndDate
	      AND empldepts.Department = @DeptNo
	    INNER JOIN TimeCurrent..tblAdjCodes AS adjs
	    ON adjs.Client = empls.Client
	      AND adjs.GroupCode = empls.GroupCode
	--      AND adjs.PayrollPeriodEndDate = empls.PayrollPeriodEndDate
	      AND adjs.ClockAdjustmentNo = @ClockAdjustmentNo
	    WHERE empls.Client = @Client
	      AND empls.GroupCode = @GroupCode
	      AND empls.SSN = @SSN
	      AND empls.PayrollPeriodEndDate = @PPED
	--      AND empls.RecordStatus = '1'
	
	    SET @thdRecordCnt = @@Rowcount
	    SET @RecordID = SCOPE_IDENTITY()

	---Insert to timehistdetail_faxaroo to save start/end date and faxpageid  
	INSERT INTO Timehistory..tblTimeHistDetail_Faxaroo (THD_RecordId, FLSA_StartDate, FLSA_EndDate, FaxPageId, MaintUserName, MaintDateTime)
	VALUES(@RecordID, @StartDate, @EndDate, @FaxPageId, @UserCode, GETDATE())
    
	
	    IF @thdRecordCnt > 0 
	    BEGIN
	      IF @ReasonCodeID <> 0
	      BEGIN
	        EXEC usp_Web1_AssignReasonCode @Client, @GroupCode, @SSN, @PPED, NULL, @ReasonCodeID, @RecordID
	      END
	
				IF (@AdjType = 'D' AND IsNull(@Amount, 0) > 999.99)
				BEGIN
					SELECT @SweptDateTime = GetDate()
				END
	  
	      -- tblAdjustments
	      INSERT INTO TimeCurrent.dbo.tblAdjustments(Client, GroupCode, PayrollPeriodEndDate, SSN, SiteNo, DeptNo, ClockAdjustmentNo, AdjustmentCode, AdjustmentName, 
						        HoursDollars, 
	        					        SunVal, 
						        MonVal, 
						        TueVal, 
						        WedVal, 
						        ThuVal, 
						        FriVal, 
						        SatVal, 
						        WeekVal, TotalVal, UserID, TransDateTime, RecordStatus, IPAddr, ShiftNo, SweptDateTime)
	      SELECT @Client, @GroupCode, @PPED, @SSN, @SiteNo, @DeptNo, @ClockAdjustmentNo, AdjustmentCode, AdjustmentName,
	        @AdjType, 
	        (CASE @Day WHEN 1 THEN @Amount ELSE 0 END),
	        (CASE @Day WHEN 2 THEN @Amount ELSE 0 END),
	        (CASE @Day WHEN 3 THEN @Amount ELSE 0 END),
	        (CASE @Day WHEN 4 THEN @Amount ELSE 0 END),
	        (CASE @Day WHEN 5 THEN @Amount ELSE 0 END),
	        (CASE @Day WHEN 6 THEN @Amount ELSE 0 END),
	        (CASE @Day WHEN 7 THEN @Amount ELSE 0 END),
	        0, @Amount, @UserID, GETDATE(), '1', '', @ShiftNo, @SweptDateTime
	      FROM TimeCurrent..tblAdjCodes
	      WHERE Client = @Client AND GroupCode = @GroupCode AND ClockAdjustmentNo = @ClockAdjustmentNo-- AND PayrollPeriodEndDate = @PPED
	
	      IF @PeriodStatus = 'C'
	      BEGIN
	        SET @AdjDate =  CASE WHEN @Day <= DATEPART(dw, @PPED)
	                        THEN DATEADD(day, -(DATEPART(dw, @PPED) - @Day), @PPED)
	                        ELSE DATEADD(day, ((@Day - DATEPART(dw, @PPED)) - 7), @PPED)
	                        END
	        SET @Comment =   'Adjustment of ' + cast(@Amount as varchar) + ' for ' + CONVERT(nvarchar(20), @AdjDate, 101) + ' added after period was closed'
	      	INSERT INTO tblTimeHistDetail_Comments(Client, GroupCode, PayrollPeriodEndDate, SSN, CreateDate, Comments, UserID, UserName, ManuallyAdded)
	        VALUES (@Client,@GroupCode,@PPED,@SSN,GetDate(),@Comment,@UserID,'','N')
	      END
	      ELSE
	      BEGIN
					SET @AdjDate =  CASE WHEN @Day <= DATEPART(dw, @PPED)
	                        THEN DATEADD(day, -(DATEPART(dw, @PPED) - @Day), @PPED)
	                        ELSE DATEADD(day, ((@Day - DATEPART(dw, @PPED)) - 7), @PPED)
	                     		END
	        IF @ClockAdjustmentNo = '1'
	        BEGIN               
				 		SET @Comment =   'Current hours - ' + cast(ISNULL(@PrevAmount,0) as varchar) + ' for ' + CONVERT(nvarchar(20), @AdjDate, 101) + ' has been updated to ' + cast(ISNULL(@Amount,0) as varchar)
			  		INSERT INTO tblTimeHistDetail_Comments(Client, GroupCode, PayrollPeriodEndDate, SSN, CreateDate, Comments, UserID, UserName, ManuallyAdded)
			   		VALUES (@Client,@GroupCode,@PPED,@SSN,GetDate(),@Comment,@UserID,'','N')
			   	END
	      END
	    END
	    ELSE
	    BEGIN
	      --RAISERROR ('Failed to add transaction. Please try again.', 16, 1)
	      SET @ErrorCode = 1
	      GOTO ErrorHandler
	    END  
	
	  END
	  ELSE
	  BEGIN
	    -- It won't let me do this inline
	    DECLARE @strPPED    AS varchar(10)
	    SET @strPPED = CONVERT(varchar(10), @PPED, 101)
	
	   -- RAISERROR ('Group %d is not set up for Pay Period %s', 16, 1, @GroupCode, @strPPED)
	    SET @ErrorCode = 1
	    GOTO ErrorHandler
	  END
		ErrorHandler:
		SET @DayError = @ErrorCode

	END
END
ELSE
BEGIN
	IF(@PrevAmount <>@Amount)
	BEGIN
		SET @AdjDate =  CASE WHEN @Day <= DATEPART(dw, @PPED)
		                        THEN DATEADD(day, -(DATEPART(dw, @PPED) - @Day), @PPED)
		                        ELSE DATEADD(day, ((@Day - DATEPART(dw, @PPED)) - 7), @PPED)
		                        END
		SET @Comment =   'Current hours - ' + cast(ISNULL(@PrevAmount,0) as varchar) + ' for ' + CONVERT(nvarchar(20), @AdjDate, 101) + ' has been deleted'
		INSERT INTO tblTimeHistDetail_Comments(Client, GroupCode, PayrollPeriodEndDate, SSN, CreateDate, Comments, UserID, UserName, ManuallyAdded)
		VALUES (@Client,@GroupCode,@PPED,@SSN,GetDate(),@Comment,@UserID,'','N')
	END
END


IF @ErrorCode = ''
	COMMIT TRANSACTION
ELSE
 	ROLLBACK TRANSACTION





