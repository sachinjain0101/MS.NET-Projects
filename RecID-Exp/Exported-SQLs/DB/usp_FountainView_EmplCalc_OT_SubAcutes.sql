CREATE Procedure [dbo].[usp_FountainView_EmplCalc_OT_SubAcutes]
	@Client 		  varchar(4), 
	@GroupCode 		int,
	@PeriodDate 	datetime, 
	@SSN 			    int 
AS


SET NOCOUNT ON
--*/

/*
DECLARE @Client			  varchar(4)
DECLARE @GroupCode		int
DECLARE @PeriodDate		datetime
DECLARE @SSN			    int

SELECT @Client = 'FOUN'
SELECT @GroupCode = 360300
SELECT @PeriodDate = '10/13/02'
SELECT @SSN = 1
*/

/*
Rules:
- Only applies to punches in Dept 20
- Only applies to 'worked' time (punches and worked adjustments)
- Anything above 12 hours in a single day automatically goes to Double Time regardless of other rules
- The day on which 40 hours is reached (or exceeded) is known as "4th Day"
- After the "4th Day" comes the "5th Day" ...
- 4th Day Rule: Up to 40 hours for the week goes Regular ... up to 4 hours above that to OT ... rest to DT
- 5th Day Rule: Up to 8 hours for the day goes to OT ... rest to DT
- 6th Day and on: All hours to DT
*/

SELECT thd.RecordID, thd.TransDate, thd.Hours
INTO #tmpHours
FROM tblTimeHistDetail AS thd
LEFT JOIN TimeCurrent..tblAdjCodes AS adjs
ON adjs.Client = thd.Client
  AND adjs.GroupCode = thd.GroupCode
  AND adjs.ClockAdjustmentNo = thd.ClockAdjustmentNo
WHERE thd.Client = @Client
  AND thd.GroupCode = @GroupCode
  AND thd.PayrollPeriodEndDate = @PeriodDate
  AND thd.SSN = @SSN
  AND thd.Hours <> 0
  AND thd.DeptNo = 20
  AND (adjs.Worked = 'Y' OR thd.ClockAdjustmentNo = ' ')

DECLARE @TotalHours    numeric(5,2)

SELECT @TotalHours = SUM(Hours) FROM #tmpHours

IF @TotalHours > 40
BEGIN
--  PRINT @TotalHours

  DECLARE @HoursSum    numeric(5,2)
  DECLARE @Day         tinyint        -- The term "Day" is relative.  The "4th Day" is the day on which 40 hours is reached (or exceeded)
  DECLARE @RegHours    numeric(5,2)
  DECLARE @OT_Hours    numeric(5,2)
  DECLARE @DT_Hours    numeric(5,2)

  SET @HoursSum = 0
  SET @Day = 0
  SET @RegHours = 0
  SET @OT_Hours = 0
  SET @DT_Hours = 0

  -- Iterate through Daily Hours table and calculate how Reg/OT/DT should be allocated for the day

  DECLARE @Date        datetime
  DECLARE @Hours       numeric(5,2)

  DECLARE csrTempDailyHours CURSOR FOR
    SELECT TransDate, SUM(Hours) AS Hours
    FROM #tmpHours
    GROUP BY TransDate
    ORDER BY TransDate ASC

  OPEN csrTempDailyHours

    FETCH NEXT FROM csrTempDailyHours INTO @Date, @Hours
    WHILE @@FETCH_STATUS = 0
    BEGIN
      SET @HoursSum = @HoursSum + @Hours
      IF @HoursSum >= 40 AND @Day = 0
        SET @Day = 4
      ELSE IF @Day >= 4
        SET @Day = @Day + 1
        
      IF @Day = 4
      BEGIN
        SET @RegHours = 40 - (@HoursSum - @Hours)
        SET @Hours = @Hours - @RegHours

        IF @Hours > 4
          SET @OT_Hours = 4
        ELSE
          SET @OT_Hours = @Hours

        SET @DT_Hours = @Hours - @OT_Hours
      END
      ELSE IF @Day = 5
      BEGIN
        SET @RegHours = 0

        IF @Hours > 8
          SET @OT_Hours = 8
        ELSE
          SET @OT_Hours = @Hours

        SET @DT_Hours = @Hours - @OT_Hours
      END
      ELSE IF @Day > 5
      BEGIN
        SET @RegHours = 0
        SET @OT_Hours = 0
        SET @DT_Hours = @Hours
      END
      ELSE
      BEGIN
        SET @RegHours = @Hours
        SET @OT_Hours = 0
        SET @DT_Hours = 0
      END

      -- If after these calculations, there are more than 12 RegHours for a day, put the rest in DT
      IF @RegHours > 12
      BEGIN
        SET @DT_Hours = @DT_Hours + @OT_Hours + (@RegHours - 12)
        SET @RegHours = 12
        SET @OT_Hours = 0
      END

--      PRINT CAST(@RegHours AS varchar(10)) + '-' + CAST(@OT_Hours AS varchar(10)) + '-' + CAST(@DT_Hours AS varchar(10))

      -- Iterate through each record for the day and distribute the Reg/OT/DT appropriately

      DECLARE @RecordID      AS BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 24Aug2016 >--

      DECLARE csrTransDatePunches CURSOR FOR
        SELECT RecordID, Hours
        FROM #tmpHours
        WHERE TransDate = @Date
        ORDER BY RecordID
    
      OPEN csrTransDatePunches
    
        FETCH NEXT FROM csrTransDatePunches INTO @RecordID, @Hours
        WHILE @@FETCH_STATUS = 0
        BEGIN
--          PRINT @RecordID
          IF @Hours >= @RegHours
          BEGIN
            SET @Hours = @Hours - @RegHours
            UPDATE tblTimeHistDetail SET RegHours = @RegHours WHERE RecordID = @RecordID
            SET @RegHours = 0
          END
          ELSE
          BEGIN
            SET @RegHours = @RegHours - @Hours
            UPDATE tblTimeHistDetail SET RegHours = @Hours WHERE RecordID = @RecordID
            SET @Hours = 0
          END

          IF @Hours >= @OT_Hours
          BEGIN
            SET @Hours = @Hours - @OT_Hours
            UPDATE tblTimeHistDetail SET OT_Hours = @OT_Hours WHERE RecordID = @RecordID
            SET @OT_Hours = 0
          END
          ELSE
          BEGIN
            SET @OT_Hours = @OT_Hours - @Hours
            UPDATE tblTimeHistDetail SET OT_Hours = @Hours WHERE RecordID = @RecordID
            SET @Hours = 0
          END

          IF @Hours >= @DT_Hours
          BEGIN
            SET @Hours = @Hours - @DT_Hours
            UPDATE tblTimeHistDetail SET DT_Hours = @DT_Hours WHERE RecordID = @RecordID
            SET @DT_Hours = 0
          END
          ELSE
          BEGIN
            SET @DT_Hours = @DT_Hours - @Hours
            UPDATE tblTimeHistDetail SET DT_Hours = @Hours WHERE RecordID = @RecordID
            SET @Hours = 0
          END

          FETCH NEXT FROM csrTransDatePunches INTO @RecordID, @Hours
        END

      CLOSE csrTransDatePunches

      DEALLOCATE csrTransDatePunches

      FETCH NEXT FROM csrTempDailyHours INTO @Date, @Hours
    END
  
  CLOSE csrTempDailyHours

  DEALLOCATE csrTempDailyHours
END

DROP TABLE #tmpHours



