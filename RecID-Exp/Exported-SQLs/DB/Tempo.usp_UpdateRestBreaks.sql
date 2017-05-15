CREATE PROCEDURE [Tempo].[usp_UpdateRestBreaks]
(
  @Client VARCHAR(4) ,
  @Groupcode INT ,
  @SSN INT ,
	@PPED DATE,
  @PenaltyBreaks INT ,  -- Rest breaks missed
  @punchDateTime DATETIME,
  @thdRecordID BIGINT ,
	@rbType CHAR(1),
	@TotalRestBreaks INT ,  -- Total Rest breaks that should have been taken
  @Source INT = 12
)
AS
    
SET NOCOUNT ON

    DECLARE @TransDate DATETIME
    DECLARE @DeptNo INT
    DECLARE @MPD DATETIME 
    DECLARE @Amount NUMERIC(7, 2)
    DECLARE @AdjCode VARCHAR(3)
    DECLARE @AdjName VARCHAR(10)
    DECLARE @SiteNo INT
    DECLARE @SiteState VARCHAR(4)
    DECLARE @Comment VARCHAR(200)
    DECLARE @ActIn datetime
    DECLARE @ActOut datetime 
    DECLARE @Hours numeric(7,2)
    DECLARE @BreakCode INT
    DECLARE @EmpName VARCHAR(100)

    SET @AdjCode = 'W'
    SET @AdjName = 'NO_RESTBRK'

    SELECT 
      @EmpName = FirstName + ' ' + LastName
    FROM TimeCurrent.dbo.tblEmplNames (NOLOCK)
    WHERE client = @Client
    AND groupcode = @Groupcode
    AND SSN = @SSN 

    SELECT 
            @Transdate = TransDate ,
            @SiteNo = Siteno ,
            @DeptNo = DeptNo ,
            @MPD = Masterpayrolldate,
            @Hours = [Hours],
            @ActIn = isnull(ActualInTime, TimeHistory.dbo.PunchDateTime2(TransDate, inDay, Intime)),
            @ActOut = isnull(ActualOutTime, TimeHistory.dbo.PunchDateTime2(TransDate, outDay, OutTime))
    FROM TImeHistory.dbo.tblTimeHistDetail (NOLOCK)
    WHERE   
      CLient = @Client
      AND GroupCode = @Groupcode
      AND ssn = @SSN
      AND PayrollPeriodEndDate = @PPED
      AND recordid >= @thdRecordID
      AND ActualOutTime = @punchDateTime

    IF ISNULL(@SiteNo,0) = 0
    BEGIN

      -- Error condition.  Could not find a match on the out punch.
      -- Add comment to the latest time card and continue.
      --
      SET @PPED = (SELECT MAX(PayrollPeriodEndDate) FROM TimeHistory.dbo.tblPeriodEndDates (NOLOCK) WHERE client = @Client AND groupcode = @groupcode )

      IF @PenaltyBreaks > 0
      BEGIN
        SET @Comment = 'REST BREAK RESPONSE - Warning: Time card NOT updated.  System could not find matching Out Punch (' + CONVERT(VARCHAR(16), @punchDateTime, 120) + '). Employee recorded number of missed rest breaks = ' + LTRIM(STR(@PenaltyBreaks)) + ''

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
                  0 ,
                  0 ,
                  @Source
                )
      END
      return  
    END

    SELECT  @SiteState = SiteState
    FROM    TImeCurrent..tblSIteNames (NOLOCK)
    WHERE   client = @Client
            AND groupcode = @Groupcode
            AND siteno = @Siteno 

    SET @Amount = 0

    IF @SiteState = 'WA' AND @PenaltyBreaks > 0
    BEGIN  
      SET @AdjCode = '0'
      SET @Amount = @PenaltyBreaks * 10.00/60	
    END
    IF @SiteState = 'CA' AND @PenaltyBreaks > 0
    BEGIN
      SET @AdjCode = 'H'
      SET @Amount = 0 -- recalc will insert an entry for 60 min
    END

    SET @Comment = 'REST BREAK RESPONSE - ' + CONVERT(VARCHAR(12), @Transdate, 101) + ' : Employee entered ' + LTRIM(STR(@PenaltyBreaks))
        + ' missed break' + CASE WHEN @PenaltyBreaks = 1 THEN '' ELSE 's' END

-- Need to calculate the hours amount based on what was missed.
-- Add adjustment to the time card -- make sure there isn't already one there?
-- Add comment to reflect employee's answer to the question and what date and time he/she answered.
--
    IF @PenaltyBreaks > 0
    BEGIN
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


