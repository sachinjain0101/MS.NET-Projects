CREATE   PROCEDURE [dbo].[usp_PATE_UpdateAdjustment2]
(
@THDRecordId BIGINT,  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 26Aug2016 >--
@Client varchar(4),
@GroupCode int,
@SSN int,
@PPED datetime,
@TransDate datetime,
@Account varchar(10),
@NewHours numeric(7,2),
@OrigHours numeric(7,2),
@Sales numeric(9,2),
--@Brand varchar(2),
@UserId int,
@UserName varchar(20),
@DisputeText varchar(2000),
@IPAddress varchar(20),
@NewTHDRecordId BIGINT output  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 26Aug2016 >--
) AS


DECLARE @AdjRecordID int
DECLARE @NewDeptNo int
DECLARE @Day int
DECLARE @Hours numeric(7,2)

IF (@NewHours < @OrigHours)
BEGIN
	SET @Hours = @OrigHours
END
ELSE
BEGIN
	SET @Hours = @NewHours
END

PRINT 'here'

IF (@THDRecordId <> 0)
BEGIN
	SELECT @AdjRecordID = adj.Record_No,
				 @NewDeptNo = gd.DeptNo
	FROM TimeHistory..tblTimeHistDetail thd
	INNER JOIN TimeCurrent..tblAdjustments adj
	ON adj.Client = thd.Client
	AND adj.GroupCode = thd.GroupCode
	AND adj.SiteNo = thd.SiteNo
	AND adj.SSN = thd.SSN
	AND adj.DeptNo = thd.DeptNo
	AND adj.ShiftNo = thd.ShiftNo
	AND adj.PayrollPeriodEndDate = thd.PayrollPeriodEndDate
	AND adj.ClockAdjustmentNo = thd.ClockAdjustmentNo
/*	AND ((adj.SunVal <> 0 AND datepart(dw, thd.TransDate) = 1) OR
			 (adj.MonVal <> 0 AND datepart(dw, thd.TransDate) = 2) OR
			 (adj.TueVal <> 0 AND datepart(dw, thd.TransDate) = 3) OR
			 (adj.WedVal <> 0 AND datepart(dw, thd.TransDate) = 4) OR
			 (adj.ThuVal <> 0 AND datepart(dw, thd.TransDate) = 5) OR
			 (adj.FriVal <> 0 AND datepart(dw, thd.TransDate) = 6) OR
			 (adj.SatVal <> 0 AND datepart(dw, thd.TransDate) = 7))*/
	AND CASE DATEPART(dw, thd.TransDate)
	      WHEN 1 THEN adj.SunVal
	      WHEN 2 THEN adj.MonVal
	      WHEN 3 THEN adj.TueVal
	      WHEN 4 THEN adj.WedVal
	      WHEN 5 THEN adj.ThuVal
	      WHEN 6 THEN adj.FriVal
	      WHEN 7 THEN adj.SatVal
	      END = thd.Hours
	INNER JOIN TimeCurrent.dbo.tblGroupDepts gd
	ON gd.Client = thd.Client
	AND gd.GroupCode = thd.GroupCode
	AND rtrim(ltrim(gd.ClientDeptCode)) = rtrim(ltrim(@Account))
	WHERE thd.RecordId = @THDRecordID
	
	IF (@AdjRecordID IS NOT NULL)
	BEGIN
	  UPDATE TimeCurrent..tblAdjustments 
		SET SunVal = (CASE WHEN datepart(dw, @TransDate) = 1 THEN @Hours ELSE 0 END),
				MonVal = (CASE WHEN datepart(dw, @TransDate) = 2 THEN @Hours ELSE 0 END),
				TueVal = (CASE WHEN datepart(dw, @TransDate) = 3 THEN @Hours ELSE 0 END),
				WedVal = (CASE WHEN datepart(dw, @TransDate) = 4 THEN @Hours ELSE 0 END),
				ThuVal = (CASE WHEN datepart(dw, @TransDate) = 5 THEN @Hours ELSE 0 END),
				FriVal = (CASE WHEN datepart(dw, @TransDate) = 6 THEN @Hours ELSE 0 END),
				SatVal = (CASE WHEN datepart(dw, @TransDate) = 7 THEN @Hours ELSE 0 END),
				DeptNo = @NewDeptNo,
	      Sales = @Sales
	  WHERE Record_No = @AdjRecordID
	END
	
	UPDATE TimeHistory.dbo.tblTimeHistDetail
	SET TransDate = @TransDate,
			Hours = @Hours,
			DeptNo = @NewDeptNo
	WHERE RecordId = @THDRecordID
	AND (TransDate <> @TransDate OR
			 Hours <> @Hours OR
			 DeptNo <> @NewDeptNo)
			 
/* Brand and other custom PATE fields are updated in a different stored proc	
	UPDATE TimeHistory.dbo.tblTimeHistDetail_PATE
	SET Brand = @Brand
	WHERE THDRecordId = @THDRecordID
	AND Brand <> @Brand
*/
END
ELSE
BEGIN
	SELECT @NewDeptNo = DeptNo
	FROM TimeCurrent.dbo.tblGroupDepts
	WHERE Client = @Client
	AND GroupCode = @GroupCode
	AND rtrim(ltrim(ClientDeptCode)) = rtrim(ltrim(@Account))

	SELECT @Day = datepart(dw, @TransDate)
/*
  PRINT @Client
  PRINT @GroupCode
  PRINT 1
  PRINT @SSN
  PRINT @NewDeptNo
  PRINT 1
  PRINT @PPED
  PRINT '1'
  PRINT 'H'
  PRINT @Hours
  PRINT @Day
  PRINT @Sales
  PRINT ''
  PRINT @UserId
  PRINT 0
*/  
	EXEC TimeHistory..usp_PATE_AddAdjustment  @Client,
																					  @GroupCode,
																					  1, -- @SiteNo
																					  @SSN,
																					  @NewDeptNo,
																					  1, -- @ShiftNo
																					  @PPED,
																					  1, -- @ClockAdjustmentNo
																					  'H', -- @AdjType
																					  @Hours,
																					  @Day,
																					  @Sales,
																						-- @Brand,
																						'', -- @Brand
																					  @UserID,
																					  0, -- @ReasonCodeID
																					  @NewTHDRecordId output
END

IF (@NewHours < @OrigHours)
BEGIN
	EXEC TimeHistory.dbo.usp_PATE_DisputeLineItem @Client,
																								@GroupCode,
																								@PPED,
																								@SSN,
																								@THDRecordId,
																								@TransDate,
																								@UserId,
																								@UserName,
																								@OrigHours,
																								@NewHours,
																								@DisputeText,
																								@Account,
																								@IPAddress

END




