CREATE  procedure [dbo].[usp_web1_Delete_Adj]
	@THDRecID BIGINT,  --< @THDRecID data type is changed from  INT to BIGINT by Srinsoft on 07Sept2016 >--
	@Client varchar(4),
	@GroupCode int, 
	@PPED datetime

AS
	
declare @err tinyint

begin

	DECLARE @TransDate DATETIME 
					,@ClockAdjustmentNo VARCHAR(3)
					,@SSN INT
					,@PTORequestID INT
					,@Hours NUMERIC(7,2)

	IF EXISTS(SELECT 1 FROM TimeCurrent.dbo.tblAccruals WHERE client = @Client AND GroupCode = @GroupCode )
	BEGIN
			SELECT @TransDate = TransDate 
					,@SSN = SSN
					,@ClockAdjustmentNo = ClockAdjustmentNo
					,@Hours = [Hours]
			FROM TimeHistory.dbo.tblTimeHistDetail (NOLOCK) 
			WHERE RecordID = @THDRecID

			-- Check to See if the Adjustment is associated with a PTO Request from the tblPTORequest table.  If so we need to cancel the request in the PTO Request table
			--
			SET @PTORequestID = (SELECT RecordID FROM TimeHistory.dbo.tblPTORequests (NOLOCK)
															WHERE client = @Client
															AND GroupCode = @GroupCode
															AND SSN = @SSN                          
															AND TransDate >= @TransDate
															AND ClockAdjustmentNo = @ClockAdjustmentNo
															AND [hours] = @Hours
															AND Status IN('A','N') )
	
			IF ISNULL(@PTORequestID,0) <> 0
			BEGIN
				UPDATE TimeHistory.dbo.tblPTORequests
					SET STatus = 'X', ApproverUserID = 1, ApproverMessage = 'Transaction Voided on time card', MaintDateTime = GETDATE()
				WHERE RecordID = @PTORequestID
			END
	END

			-- update the adjustment table
			update timeCurrent.dbo.tblAdjustments
			set sunval = case when x.day = 1 then 0 else sunval end,
			 	monval = case when x.day = 2 then 0 else monval end,
				tueval = case when x.day = 3 then 0 else tueval end,
				wedval = case when x.day = 4 then 0 else wedval end,
				thuval = case when x.day = 5 then 0 else thuval end,
				frival = case when x.day = 6 then 0 else frival end,
				satval = case when x.day = 7 then 0 else satval end,
				totalval = totalval - x.Val
			from
			(
			select top 1 Record_No, Val, Day
			FROM
			(
			select Record_No, Client, GroupCode, PayrollPeriodEndDate, SSN, SiteNo, DeptNo, ClockAdjustmentNo, HoursDollars, SunVal as Val, dbo.PPED_DateTime(PayrollPeriodEndDate,1, '00:00') as TransDate, 1 as day from timecurrent..tbladjustments
			where SunVal <> 0 and client= @client and groupcode=@groupCode and payrollPeriodEndDate = @PPED 
			UNION ALL
			select Record_No, Client, GroupCode, PayrollPeriodEndDate, SSN, SiteNo, DeptNo, ClockAdjustmentNo, HoursDollars, MonVal as Val, dbo.PPED_DateTime(PayrollPeriodEndDate,2, '00:00') as TransDate, 2 as day from timecurrent..tbladjustments
			where MonVal <> 0 and client= @client and groupcode=@groupCode and payrollPeriodEndDate = @PPED
			UNION ALL
			select Record_No, Client, GroupCode, PayrollPeriodEndDate, SSN, SiteNo, DeptNo, ClockAdjustmentNo, HoursDollars, TueVal as Val, dbo.PPED_DateTime(PayrollPeriodEndDate,3, '00:00') as TransDate, 3 as day from timecurrent..tbladjustments
			where TueVal <> 0 and client= @client and groupcode=@groupCode and payrollPeriodEndDate = @PPED
			UNION ALL
			select Record_No, Client, GroupCode, PayrollPeriodEndDate, SSN, SiteNo, DeptNo, ClockAdjustmentNo, HoursDollars, WedVal as Val, dbo.PPED_DateTime(PayrollPeriodEndDate,4, '00:00') as TransDate, 4 as day from timecurrent..tbladjustments
			where WedVal <> 0 and client= @client and groupcode=@groupCode and payrollPeriodEndDate = @PPED
			UNION ALL
			select Record_No, Client, GroupCode, PayrollPeriodEndDate, SSN, SiteNo, DeptNo, ClockAdjustmentNo, HoursDollars, ThuVal as Val, dbo.PPED_DateTime(PayrollPeriodEndDate,5, '00:00') as TransDate, 5 as day from timecurrent..tbladjustments
			where ThuVal <> 0 and client= @client and groupcode=@groupCode and payrollPeriodEndDate = @PPED
			UNION ALL
			select Record_No, Client, GroupCode, PayrollPeriodEndDate, SSN, SiteNo, DeptNo, ClockAdjustmentNo, HoursDollars, FriVal, dbo.PPED_DateTime(PayrollPeriodEndDate,6, '00:00') as TransDate, 6 as day from timecurrent..tbladjustments
			where FriVal <> 0 and client= @client and groupcode=@groupCode and payrollPeriodEndDate = @PPED
			UNION ALL
			select Record_No, Client, GroupCode, PayrollPeriodEndDate, SSN, SiteNo, DeptNo, ClockAdjustmentNo, HoursDollars, SatVal, dbo.PPED_DateTime(PayrollPeriodEndDate,7, '00:00') as TransDate, 7 as day from timecurrent..tbladjustments
			where SatVal <> 0 and client= @client and groupcode=@groupCode and payrollPeriodEndDate = @PPED
			) as adj
			INNER JOIN TimeHistory.dbo.tblTimeHistDetail as thd (NOLOCK)
			ON adj.client = thd.client
			AND adj.groupcode = thd.groupcode
			AND adj.payrollPeriodEndDate = thd.payrollPeriodEndDate
			AND adj.SSN = thd.SSN
			AND adj.ClockAdjustmentNo = thd.ClockAdjustmentNo
			AND adj.Val = CASE WHEN thd.Hours = 0 THEN thd.Dollars ELSE thd.Hours END
			AND adj.SiteNo = thd.SiteNo
			AND adj.DeptNo = thd.DeptNo
			AND adj.TransDate = thd.TransDate
			WHERE thd.RecordID = @THDRecID
			ORDER BY Record_No
			) as x
			WHERE timeCurrent.dbo.tblAdjustments.record_no = x.record_no


end





