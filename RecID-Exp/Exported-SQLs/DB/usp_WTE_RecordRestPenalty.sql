CREATE PROCEDURE [dbo].[usp_WTE_RecordRestPenalty]
    (
      @Client VARCHAR(4) ,
      @Groupcode INT ,
      @SSN INT ,
      @thdRecordID BIGINT ,  --< @thdRecordId data type is changed from  INT to BIGINT by Srinsoft on 16Sept2016 >--
      @PenaltyBreaks INT ,
      @ResponseSelected VARCHAR(100) ,
      @EmpName VARCHAR(80) ,
      @Source INT = 12 ,
      @RestBreakCheckType CHAR(1) -- W- due to work, C - by choice
    )
AS
    
SET NOCOUNT ON

    DECLARE @PPED DATETIME
    DECLARE @TransDate DATETIME
    DECLARE @DeptNo INT
    DECLARE @MPD DATETIME 
    DECLARE @Amount NUMERIC(7, 2)
    DECLARE @AdjCode CHAR(1)
    DECLARE @AdjName VARCHAR(10)
    DECLARE @SiteNo INT
    DECLARE @SiteState VARCHAR(4)
    DECLARE @Comment VARCHAR(200)
    DECLARE @ActIn datetime
    DECLARE @ActOut datetime 
    DECLARE @Hours numeric(7,2)
    DECLARE @BreakCode int

    SET @AdjCode = 'W'
    SET @AdjName = 'NO_RESTBRK'

    SELECT  @PPED = Payrollperiodenddate ,
            @Transdate = TransDate ,
            @SiteNo = Siteno ,
            @DeptNo = DeptNo ,
            @MPD = Masterpayrolldate,
            @Hours = [Hours],
            @ActIn = isnull(ActualInTime, TimeHistory.dbo.PunchDateTime2(TransDate, inDay, Intime)),
            @ActOut = isnull(ActualOutTime, TimeHistory.dbo.PunchDateTime2(TransDate, outDay, OutTime))
    FROM    TImeHistory..tblTimeHistDetail WITH ( NOLOCK )
    WHERE   recordid = @thdRecordID

    SELECT  @SiteState = SiteState
    FROM    TImeCurrent..tblSIteNames
    WHERE   client = @Client
            AND groupcode = @Groupcode
            AND siteno = @Siteno 
	PRINT @SiteState
    IF @SiteState = 'WA'
        BEGIN  
            SET @AdjCode = '0'
            IF @RestBreakCheckType = 'W'
                BEGIN
                    SET @Amount = @PenaltyBreaks * 10.00/60	
                END
            ELSE -- do nothing for due to choice
                BEGIN
                    SET @Amount = 0
                END
  
        END
    IF @SiteState = 'CA'
        BEGIN
            SET @AdjCode = 'H'
            IF @RestBreakCheckType = 'W' AND @PenaltyBreaks >0
                BEGIN
                    SET @Amount = 0 -- recalc will insert an entry for 60 min
                END
            ELSE -- do nothing for due to choice
                BEGIN
                    SET @Amount = 0
                END
        END

    PRINT 'Amount:' + CAST(@Amount AS VARCHAR)
    SET @Comment = 'REST BREAK RESPONSE - ' + CONVERT(VARCHAR(12), @Transdate, 101) + ' : ' + @ResponseSelected + '(missed ' + LTRIM(STR(@PenaltyBreaks))
        + ' break' + CASE WHEN @PenaltyBreaks = 1 THEN ')'
                          ELSE 's)'
                     END

-- Need to calculate the hours amount based on what was missed.
-- Add adjustment to the time card -- make sure there isn't already one there?
-- Add comment to reflect employee's answer to the question and what date and time he/she answered.
--
    IF @PenaltyBreaks > 0
        AND @RestBreakCheckType = 'W' --must be "W" (due to work)
    BEGIN
      PRINT 'inserting adjustment'
      EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD]
          @Client ,
          @GroupCode ,
          @PPED ,
          @SSN ,
          @SiteNo ,
          @DeptNo ,
          @AdjCode ,
          @AdjName ,
          @Amount ,
          0.00 ,
          @TransDate ,
          @MPD ,
          'SYS' ,
          'N'
/*
      select 
        Top 1 @BreakCode = RecordID
      from TimeHistory..tblWTE_BreakCodes 
      where Client = @Client
        and BreakType = 'CARest'
        and BreakCodeIndex = 0

      -- Insert Rest break item.
      INSERT INTO [TimeHistory].[dbo].[tblWTE_Spreadsheet_Breaks]
                  ([Client]
                  ,[GroupCode]
                  ,[PayrollPeriodEndDate]
                  ,[SiteNo]
                  ,[DeptNo]
                  ,[BreakType]
                  ,[SSN]
                  ,[TransDate]
                  ,[In]
                  ,[Out]
                  ,[Hours]
                  ,[Position]
                  ,[WorkNEat]
                  ,[LunchBreakNP]
                  ,[LunchBreakWP]
                  ,[LunchBreakPM]
                  ,[LunchBreakVPM]
                  ,[BreakCode]
                  ,[InOutId])
            VALUES
                  (@Client
                  ,@GroupCode
                  ,@PPED
                  ,@SiteNo
                  ,@DeptNo
                  ,'CARest'
                  ,@SSN
                  ,@TransDate
                  ,@ActIn
                  ,@ActOut
                  ,@Hours
                  ,0
                  ,0
                  ,0
                  ,0
                  ,0
                  ,0
                  ,@BreakCode
                  ,@thdRecordID)
*/
    END
-- Add Comments
--
    INSERT  INTO [TimeHistory].[dbo].[tblTimeHistDetail_Comments]
            ( [Client] ,
              [GroupCode] ,
              [PayrollPeriodEndDate] ,
              [SSN] ,
              [CreateDate] ,
              [Comments] ,
              [UserID] ,
              [UserName] ,
              [ManuallyAdded] ,
              [SiteNo] ,
              [DeptNo] ,
              [CommentSourceID]
            )
    VALUES  ( @Client ,
              @Groupcode ,
              @PPED ,
              @SSN ,
              GETDATE() ,
              @Comment ,
              0 ,
              @EmpName ,
              0 ,
              @SiteNo ,
              @DeptNo ,
              @Source
            )


