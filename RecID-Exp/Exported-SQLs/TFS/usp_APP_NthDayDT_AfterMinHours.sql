Create PROCEDURE [dbo].[usp_APP_NthDayDT_AfterMinHours]
(
  @OTMult numeric(7,3),
  @NthDay INT,
  @MinOTHours NUMERIC(7,2),
  @MinDTHours NUMERIC(7,2),
  @Client varchar(4),
  @GroupCode int,
  @PPED datetime,
  @SSN int
)
AS
SET NOCOUNT ON

DECLARE @WeeklyHours NUMERIC(7,2)
DECLARE @NthDayWorked CHAR(1)
DECLARE @RunningTotal NUMERIC(7,2)
DECLARE @RecordId BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 16Aug2016 >--
DECLARE @TransHours NUMERIC(7,2)
DECLARE @NewDT NUMERIC(7,2)
DECLARE @NewOT NUMERIC(7,2)
DECLARE @NewReg NUMERIC(7,2)
DECLARE @HoursOverMin NUMERIC(7,2)

SET @NthDayWorked = '0'

SELECT @NthDayWorked = '1'
FROM TimeHistory..tblTimeHistDetail
WHERE Client = @Client
AND GroupCode = @GroupCode
AND SSN = @SSN
AND PayrollPeriodEndDate = @PPED
AND DATEPART(dw,TransDate) = @NthDay

SELECT @WeeklyHours = SUM(Hours)
FROM TimeHistory..tblTimeHistDetail
WHERE Client = @Client
AND GroupCode = @GroupCode
AND SSN = @SSN
AND PayrollPeriodEndDate = @PPED


IF @NthDayWorked = '1' AND @WeeklyHours > @MinDTHours
BEGIN
    SELECT @RunningTotal = SUM(Hours)
	FROM TimeHistory..tblTimeHistDetail
	WHERE Client = @Client
	AND GroupCode = @GroupCode
	AND SSN = @SSN
	AND PayrollPeriodEndDate = @PPED
	AND DATEPART(dw,TransDate) <> @NthDay


	DECLARE csrTrans CURSOR READ_ONLY STATIC
	FOR 
	SELECT RecordID,Hours
	FROM TimeHistory..tblTimeHistDetail
	WHERE Client = @Client
	AND GroupCode = @GroupCode
	AND SSN = @SSN
	AND PayrollPeriodEndDate = @PPED
	AND DATEPART(dw,TransDate) = @NthDay
	ORDER BY CASE WHEN Hours < 0 THEN 0 ELSE 1 END, intime DESC
    
	OPEN csrTrans
	FETCH NEXT FROM csrTrans INTO @RecordId,@TransHours
	WHILE (@@fetch_status <> -1)
	BEGIN
	  IF (@@fetch_status <> -2)
	  BEGIN
		SET @NewDT = 0
		SET @NewOT = 0
		SET @NewReg = 0

		IF @TransHours < 0 AND (@RunningTotal > @MinDTHours)
		BEGIN
		    -- If the negative hours brings the total below @MinDTHours, it needs to be partial DT
			IF @RunningTotal + @TransHours < @MinDTHours
			BEGIN
				SET @NewDT = @RunningTotal - @MinDTHours
				SET @TransHours = @TransHours + @NewDT
				SET @NewDT = @NewDT * -1
				SET @RunningTotal = @MinDTHours
			END			
		END

		SET @RunningTotal = @RunningTotal + @TransHours
		
		IF @RunningTotal > @MinDTHours
		BEGIN
			SET @HoursOverMin = @RunningTotal - @MinDTHours

			IF @HoursOverMin > @TransHours
			BEGIN
				-- All DT
				SET @NewDT = @TransHours
			END
			ELSE
			BEGIN
			    -- Partial DT.  Figure out what to do with the rest
				SET @NewDT = @HoursOverMin
				IF @RunningTotal - @TransHours > @MinOTHours
				BEGIN
				    -- They had OT prior to this transaction. All OT
					SET @NewOT = @TransHours - @NewDT
				END
				ELSE
				BEGIN
				    -- Split between Reg and OT
					SET @NewOT = (@RunningTotal - @NewDT) - @MinOTHours
					SET @NewReg = (@TransHours - @NewDT) - @NewOT
				END
			END
		END
		ELSE
		BEGIN
		    IF @RunningTotal - @TransHours > @MinOTHours
			BEGIN
				SET @NewOT = @TransHours
			END
			ELSE
			BEGIN
			    IF @MinOTHours = @MinDTHours
				BEGIN
				    -- Since they're the same, if it's not DT then it's Reg.
					SET @NewReg = @TransHours
					SET @NewOT = 0
				END
				ELSE
				BEGIN
					SET @NewOT = (@RunningTotal - @TransHours) - @MinOTHours
					SET @NewReg = @TransHours - @NewOT
				END
			END
		END

		UPDATE TimeHistory..tblTimeHistDetail
		SET RegHours = @NewReg,
		    OT_Hours = @NewOT,
		    DT_Hours = @NewDT,
		    RegDollars = ROUND(PayRate * @NewReg,2),
			RegDollars4 = ROUND(PayRate * @NewReg,4),
			RegBillingDollars = ROUND(BillRate * @NewReg,2),
			RegBillingDollars4 = ROUND(BillRate * @NewReg,4),
		    OT_Dollars = ROUND(PayRate * 1.5 * @NewOT,2),
			OT_Dollars4 = ROUND(PayRate * 1.5 * @NewOT,4),
			OTBillingDollars = ROUND(BillRate * @OTMult * @NewOT,2),
			OTBillingDollars4 = ROUND(BillRate * @OTMult * @NewOT,4),
		    DT_Dollars = ROUND(PayRate * 2.0 * @NewDT,2),
			DT_Dollars4 = ROUND(PayRate * 1.5 * @NewDT,4),
			DTBillingDollars = ROUND(BillRate * @OTMult * @NewDT,2),
			DTBillingDollars4 = ROUND(BillRate * @OTMult * @NewDT,4)
        WHERE RecordID = @RecordId
			 
	  END
	  FETCH NEXT FROM csrTrans INTO @RecordId,@TransHours
	END
	CLOSE csrTrans
	DEALLOCATE csrTrans
END

