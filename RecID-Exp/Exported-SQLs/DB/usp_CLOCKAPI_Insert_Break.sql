CREATE PROCEDURE [dbo].[usp_CLOCKAPI_Insert_Break]
    (
      @TermID VARCHAR(20) = '' ,
	  @Version varchar(20), -- not used in this SP yet, placed for possible use in a future 
	  @Request varchar(20), -- not used in this SP yet, placed for possible use in a future 
	  @MacAddr varchar(100), -- not used in this SP yet, placed for possible use in a future 
      @IPAddress varchar(32), -- not used in this SP yet, placed for possible use in a future 
      @EmplBadge INT = 0 ,
      @DeptNo INT ,
      @LongTimeInUTC BIGINT ,
      @BreakAmount NUMERIC(5, 2),
      @RevisionID varchar(32) = '0'
    )
AS 


SET NOCOUNT ON


DECLARE @client CHAR(4)
DECLARE @GroupCode INT
DECLARE @SSN INT
DECLARE @PPED DATETIME
DECLARE @SiteNo INT
DECLARE @MPD DATETIME
DECLARE @PPED1 datetime
DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 23Aug2016 >--
DECLARE @TransDate datetime
DECLARE @Hours numeric(7,2)
DECLARE @EmpStatus tinyint
DECLARE @InDay tinyint
DECLARE @OutDay tinyint
DECLARE @AgencyNo smallint
DECLARE @ClkTransNo BIGINT  --< @ClkTransNo data type is changed from  INT to BIGINT by Srinsoft on 04Oct2016 >--
DECLARE @ExceptionType int
DECLARE @ActualOutTime datetime
DECLARE @MailSubject varchar(300)
DECLARE @Comment varchar(200)
DECLARE @MasterClockMailBox varchar(20)

Set @PPED1 = dateadd(day,-13, getdate())

if @TermID = '7300590001'
	BEGIN
	  -- Log request to audit table for more research

	  INSERT INTO [Audit].[dbo].[tblSimpleAuditLog]
				 ([DateTimeAdded]
				 ,[LogSource]
				 ,[LogID1]
				 ,[LogID2]
				 ,[LogID3]
				 ,[LogID4]
				 ,[LogID5]
				 ,[LogMessage])
		   VALUES
				 (getdate()
				 ,'usp_CECLOCK_InsertBreak'
				 ,@Termid
				 ,ltrim(str(@EmplBadge))
				 ,ltrim(str(@LongTimeInUTC,20))
				 ,ltrim(str(@BreakAmount,6,2))
				 ,@RevisionID
				 ,'Break Request made')
	END

Select 
  @Client = Client,
  @GroupCode = Groupcode,
  @SiteNo = SiteNo,
  @MasterClockMailBox = isnull(MasterClockMailbox,'') 
FROM  TimeCurrent..tblSiteNames
WHERE ExportMailBox = @termID
  AND ClockType <> 'V'

IF @MasterClockMailBox <> ''
	BEGIN
	  Set @TermID = @MasterClockMailBox 
	  Select 
		@Client = Client,
		@GroupCode = Groupcode,
		@SiteNo = SiteNo
	  FROM  TimeCurrent..tblSiteNames
	  WHERE ExportMailBox = @termID
		AND ClockType <> 'V'
	END

Select 
  @SSN = SSN,
  @EmpStatus = Status
From TimeCurrent..tblEmplNames 
Where client = @Client
And groupcode = @groupcode
and EmplBadge = @EmplBadge

-- Assumption is that this SPROC would not be called if there was not a previous OUT PUNCH just processed by the host
-- So we will look for the out punch time stamp to retrieve the information we need to check for the break
--
SELECT
	@PPED = Payrollperiodenddate,
	@MPD = Masterpayrolldate,
	@RecordID = RecordID,
	@TransDate = Transdate,
	@InDay = InDay,
	@OutDay = OutDay,
	@AgencyNo = AgencyNo,
	@ClkTransNo = ClkTransNo + 5,
	@ActualOutTime = ActualOutTime
from Timehistory..tblTimeHistDetail 
where client = @Client
	and groupcode = @groupcode
	and SSN = @SSN
	and PayrollPeriodenddate >= @PPED1
	and isnull(Outtimestamp,0) = @LongTimeInUTC

IF @InDay = 10
	BEGIN
	  Set @MailSubject = 'Clock - ' + @TermID + ' BAD Break Rec. Badge = ' + LTRIM(str(@EmplBadge)) 

	  EXECUTE [Scheduler].[dbo].[usp_Email_SendDirect] 
		 '****'
		,0
		,0
		,'dale.humphries@peoplenet.com'
		,'reports@peoplenet-us.com'
		,'PeopleNet Optima Clock'
		,''
		,''
		,@MailSubject
		,@MailSubject
		,''
		,0
		,'usp_CECLOCK_InsertBreak'
		,1

	  Set @InDay = @OutDay
  
	END

--Print @PPED
--Print @MPD

IF @PPED IS NULL
	BEGIN
		  -- record to a log table and process manually until a fix is in place.
		  --
		  Set @PPED = (Select MAX(Payrollperiodenddate) from TimeHistory..tblPeriodEndDates where Client = @client and GroupCode = @GroupCode and Status <> 'C')
    
		  INSERT INTO [TimeHistory].[dbo].[tblTimeTrans](
				 [DateCreated],[PayrollPeriodEndDate],[Client],[GroupCode],[SiteNo],[DeptNo],[Shift],[JobID],[SSN],[TransSrc],[TransType],[TransDateTime],[TransDayNo],[Amount],[Amount2],[LocationInfo],[ProcessedDate],[EmplBadge],[TerminalID])     
		  VALUES(getdate(), @PPED, @client, @GroupCode , @SiteNo, @DeptNo, 0, 0, @SSN, 0, 3,getdate(), 0, @BreakAmount, 0, ltrim(str(@LongTimeInUTC,20)), getdate(), @EmplBadge , @TermID )

		  Set @PPED = null
		  -- the Out punch may have failed for some reason, still process the break.
		  -- find the closest punch within 18 hours 
		  --
		  SELECT top 1
			@PPED = Payrollperiodenddate,
			@MPD = Masterpayrolldate,
			@RecordID = RecordID,
			@TransDate = Transdate,
			@InDay = InDay,
			@OutDay = OutDay,
			@AgencyNo = AgencyNo,
			@ClkTransNo = ClkTransNo + 5,
			@ActualOutTime = ActualOutTime
		  from Timehistory..tblTimeHistDetail with (nolock)
		  where client = @Client
			  and groupcode = @groupcode
			  and SSN = @SSN
			  and PayrollPeriodenddate >= @PPED1
			  and ( 
				  isnull(Outtimestamp,0) between @LongTimeInUTC-64800000 and @LongTimeInUTC 
				  OR
				  isnull(Intimestamp,0) between @LongTimeInUTC-64800000 and @LongTimeInUTC 
				  )
		  order by RecordID desc

	 -- RETURN -- there is no out punch - no need to record a break - something is wrong.

		IF @PPED is NULL
				BEGIN
				IF @RevisionID > '2.1109.2.18368'
					SELECT  
					@client AS Client ,
					@GroupCode AS Groupcode ,
					'1/1/1970' AS PPED ,
					@SSN AS SSN ,
					RetMessage = '',
					RptRec = '<?xml version="1.0" encoding="UTF-8" ?><PeopleNetResponse><ResponseCode>2</ResponseCode><PrintPayload></PrintPayload><ErrorMessage></ErrorMessage></PeopleNetResponse>'
				ELSE
					SELECT  @client AS Client ,
							@GroupCode AS Groupcode ,
							'1/1/1970' AS PPED ,
							@SSN AS SSN ,
							RetMessage = '',
							RptRec = ''
					RETURN
				END
	END

DECLARE @NewAmount numeric(5,2)
Set @NewAmount = @BreakAmount * -1 

-- Check to see if EmplCalc already added a break. 
-- If so then update the amount if the employee requested something different and set break as an employee override
-- so emplcalc won't add it back
--
Set @Hours = 0
Set @RecordID = 0

Select 
  @Hours = Hours,
  @RecordID = RecordID 
from TimeHistory..tblTImeHistDetail
where client = @Client
and groupcode = @groupcode
and SSN = @SSN
and PayrollPeriodenddate = @PPED
and ClockadjustmentNo = '8'
and Transdate = @TransDate
and UserCode <> 'eClk' 

Set @Hours = isnull(@Hours,0)
Set @RecordID = isnull(@RecordID,0)


-- If the Amount of the break was less than 30 minutes and the client = COAS(LaVie)
-- then reset the break to 0 minutes and add comment to time card.
-- 
IF @Client = 'COAS' and @NewAmount <= 0.49
	BEGIN
	  Set @BreakAmount = 0
	  -- Add a comment to the time card.
	  -- 
	  IF @NewAmount > 0 
	  BEGIN
		Set @Comment = 'Employee entered a break amount of ' + LTRIM(str(@newAmount,4,2)) + ' which is less than 30 minutes(0.50) and the break amount has been reset to zero.'
		INSERT INTO [TimeHistory].[dbo].[tblTimeHistDetail_Comments] ([Client],[GroupCode],[PayrollPeriodEndDate],[SSN],[CreateDate],[Comments],[UserID],[UserName],[ManuallyAdded])
		VALUES(@client, @GroupCode, @PPED, @SSN, GETDATE(), @Comment, 1, 'PeopleNet System', '0')
	  END 
    
	END


IF @RecordID > 0
	BEGIN
	  -- There is an existing Break record for this employee
	  -- Check to see if we need to update it.
		  IF @Hours <> @BreakAmount and @BreakAmount <> 0.00
			  BEGIN
				-- Amounts are different - Update the record.
				Update TimeHistory..tblTimeHistDetail
				  Set Hours = @BreakAmount, UserCode = 'eClk' 
				where recordid = @Recordid
			  END
	END
ELSE
	BEGIN
	  -- NEED TO ADD A BREAK
	  INSERT INTO tblTimeHistDetail(Client, GroupCode, SSN, PayrollPeriodEndDate, MasterPayrollDate, SiteNo, DeptNo, ShiftNo, JobID, TransDate, InDay, OutDay, Hours, ClockAdjustmentNo, AdjustmentCode, AdjustmentName, InSrc, OutSrc, EmpStatus, AgencyNo, ClkTransNo, Holiday, UserCode )
	  VALUES (@Client, @GroupCode, @SSN, @PPED, @MPD, @SiteNo, @DeptNo, 0, 0, @TransDate, @InDay, 0, @BreakAmount, '8', 'B', 'BREAK', '3', '', @EmpStatus, @AgencyNo, @ClkTransNo, '0','eClk' )
	END


IF @NewAmount not in(0.50,1.00)
	BEGIN
	  -- Put an exception in the exception table and send a time card exception to the employee.
	  --

	  IF @NewAmount > .50 
		  BEGIN
			set @ExceptionType = 13    -- Long Break
		  END  
	  ELSE
		  BEGIN
			IF @NewAmount = 0
			  Set @ExceptionType = 8    -- NO Break
			ELSE
			  Set @ExceptionType = 12    -- Short Break
		  END
  
	  INSERT  INTO TimeCurrent..tblCEClock_OUT_OF_SHIFT_HOURS
			  ( TERM_ID ,
				EMPL_BADGE ,
				PUNCH_TIME_IN_MILLISECONDS ,
				EXCEPTION_TYPE ,
				LENGTH ,
				APPROVAL_STATUS,
				CLIENT,GROUPCODE,SSN

		  )
	  VALUES  ( @TermID , -- TERM_ID - varchar(20)
				@EmplBadge , -- EMPL_BADGE - int
				@LongTimeInUTC , -- PUNCH_TIME_IN_MILLISECONDS - bigint
				@ExceptionType , -- EXCEPTION_TYPE - int
				(@NewAmount * -1) , -- LENGTH - numeric
				0,  -- APPROVAL_STATUS - bit
				@Client,@GroupCode,@SSN
		  )
	  SET @RecordID = SCOPE_IDENTITY()

	  IF @RevisionID > '2.1109.2.18368'
		-- Create the exception report for the clock to print.
		--
		Exec TimeHistory..usp_CECLOCK_Get_Employee_Exception_PrintOut @Client, @Groupcode, @PPED, @SSN, @ExceptionType, @RecordID, @ActualOutTime
	  ELSE
			SELECT  
			  @client AS Client ,
			  @GroupCode AS Groupcode ,
			  TimeCurrent.dbo.fn_GetDateTime(@PPED, 3) AS PPED ,
			  @SSN AS SSN ,
			  RetMessage = '',
			  RptRec = ''

	END
ELSE
	BEGIN
           
	  IF @RevisionID > '2.1109.2.18368'
			SELECT  
			  @client AS Client ,
			  @GroupCode AS Groupcode ,
			  TimeCurrent.dbo.fn_GetDateTime(@PPED, 3) AS PPED ,
			  @SSN AS SSN ,
			  RptRec = '<?xml version="1.0" encoding="UTF-8" ?><PeopleNetResponse><ResponseCode>1</ResponseCode><PrintPayload></PrintPayload><ErrorMessage></ErrorMessage></PeopleNetResponse>'
	  ELSE
			SELECT  
			  @client AS Client ,
			  @GroupCode AS Groupcode ,
			  TimeCurrent.dbo.fn_GetDateTime(@PPED, 3) AS PPED ,
			  @SSN AS SSN ,
			  RetMessage = '',
			  RptRec = ''

	END



