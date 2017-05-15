Create PROCEDURE [dbo].[usp_WTE_CheckForRestBreaks]
    (
      @Client VARCHAR(4) ,
      @Groupcode INT ,
      @SSN INT ,
      @thdRecordId BIGINT ,  --< @thdRecordId data type is changed from  INT to BIGINT by Srinsoft on 16Sept2016 >--
      @RestBreakCheckType CHAR(1), -- 'c' by choice,'w' due to work
      @OutTime DATETIME
    )
AS
    SET NOCOUNT ON

    DECLARE @PPED DATETIME 
    DECLARE @TransDate DATETIME
    DECLARE @TotalHrs NUMERIC(9, 2)
    DECLARE @PromptDesc VARCHAR(100)
    DECLARE @RestBreaks INT
    DECLARE @RestBreakControl INT
    DECLARE @RestBreakCheckTypeVerbiage VARCHAR(50)
    DECLARE @SiteState CHAR(2)
    DECLARE @TotalHoursForThisDayAtThisLocation NUMERIC(9,2)
    
    SELECT  @PPED = Payrollperiodenddate ,
            @Transdate = TransDate ,
            @SiteState = sn.SiteState
    FROM    TImeHistory..tblTimeHistDetail AS thd WITH ( NOLOCK )
    INNER JOIN TimeCurrent..tblSiteNames AS sn
    ON      sn.Client = thd.Client
            AND sn.GroupCode = thd.GroupCode
            AND sn.SiteNo = thd.SiteNo
    WHERE   thd.recordid = @thdRecordID

   -- PRINT @PPED
    --PRINT @TransDate

    -- Get the rest breaks required.
    -- NOTE:  
    --  The BillOTRate contains the number of rest breaks that should be taken.  The Special pay determined that value based on rest break rules.
    --  
    select 
        @RestBreaks = BillOTRate--,
        --@TotalHrs = SUM(Hours) -- removed as it was causing errors as it led to the rest break prommpt not showing up
    from TimeHistory..tblTimeHistDetail with (nolock)
    where client = @Client 
    and groupcode = @Groupcode 
    and SSN = @SSN 
    and PayrollPeriodEndDate >= @PPED
    and RecordID >= @thdRecordID 
    --and outTimestamp = @ActualOutTimeStamp 
    and ActualOutTime = @OutTime
    and clockadjustmentNo in('',' ')
   -- GROUP BY dbo.tblTimeHistDetail.BillOTRate
    
    SELECT  @TotalHoursForThisDayAtThisLocation = SUM(thd.Hours)
    FROM    TimeHistory..tblTimeHistDetail AS thd WITH (NOLOCK)
    INNER JOIN (
                 SELECT TTHD.Client ,
                        TTHD.GroupCode ,
                        TTHD.SiteNo ,
                        TTHD.DeptNo ,
                        TTHD.SSN ,
                        TTHD.PayrollPeriodEndDate ,
                        TTHD.TransDate
                 FROM   TimeHistory..tblTimeHistDetail AS TTHD
                 WHERE  TTHD.RecordID = @thdRecordId
               ) AS thd2 
    ON      thd2.Client = thd.Client
            AND thd2.GroupCode = thd.GroupCode
            AND thd2.SiteNo = thd.SiteNo
            AND thd2.DeptNo = thd.DeptNo
            AND thd2.SSN = thd.SSN
            AND thd2.PayrollPeriodEndDate = thd.PayrollPeriodEndDate
            AND thd2.TransDate = thd.TransDate
            
	SET @TotalHrs=@TotalHoursForThisDayAtThisLocation

    SELECT  @RestBreakCheckTypeVerbiage = CASE @RestBreakCheckType
                                            WHEN 'C' THEN ' by choice'
                                            WHEN 'W' THEN ' due to work'
                                            ELSE ''
                                          END

    --PRINT @RestBreaks

    DECLARE @tmpRecs AS TABLE
        (
          BreaksTaken INT ,
          PromptDesc VARCHAR(200) ,
          dispTotal VARCHAR(20) ,
          dispBreaks VARCHAR(20) ,
          PromptQuestion VARCHAR(100) ,
          PenaltyBreaks INT ,
          SiteState VARCHAR(1056)          
        )

    IF @SiteState = 'WA'
        BEGIN
            SET @PromptDesc = 'Did you miss any rest breaks ?'
            IF @RestBreaks > 0
                BEGIN
                    SET @RestBreakControl = @RestBreaks
                    INSERT  INTO @tmpRecs
                    VALUES  ( @RestBreaks, @PromptDesc, LTRIM(STR(@TotalHrs, 7, 2)), LTRIM(STR(@RestBreaks)), 'I did not miss any rest breaks', 0, @SiteState ) 
  
                    WHILE @RestBreakControl > 0
                        BEGIN
                            INSERT  INTO @tmpRecs
                            VALUES  ( @RestBreaks - @RestBreakControl, @PromptDesc, LTRIM(STR(@TotalHrs, 7, 2)), LTRIM(STR(@RestBreaks)),
                                      'I missed ' + LTRIM(STR(@RestBreakControl)) + ' rest break' + CASE WHEN @RestBreakControl > 1 THEN 's'
                                                                                                         ELSE ''
                                                                                                    END, @RestBreakControl, @SiteState )
                            SET @RestBreakControl = @RestBreakControl - 1
                        END
  
                    SELECT  *,@TotalHoursForThisDayAtThisLocation AS TotalHoursForThisDayAtThisLocation
                    FROM    @tmpRecs
                    ORDER BY BreaksTaken DESC
                END
            ELSE
                BEGIN
                    SELECT  PromptDesc = ''
                    WHERE   1 = 0 
                END
        END
    ELSE
        BEGIN
            SET @PromptDesc = 'Did you miss any rest breaks ' + @RestBreakCheckTypeVerbiage + '?'
            IF @RestBreaks > 0
                BEGIN
                    SET @RestBreakControl = @RestBreaks
                    INSERT  INTO @tmpRecs
                    VALUES  ( @RestBreaks, @PromptDesc, LTRIM(STR(@TotalHrs, 7, 2)), LTRIM(STR(@RestBreaks)),
                              '<b>I did not miss any rest breaks' + @RestBreakCheckTypeVerbiage+'</b>', 0, @SiteState ) 
  
                    WHILE @RestBreakControl > 0
                        BEGIN
                            INSERT  INTO @tmpRecs
                            VALUES  ( @RestBreaks - @RestBreakControl, @PromptDesc, LTRIM(STR(@TotalHrs, 7, 2)), LTRIM(STR(@RestBreaks)),
                                      'I missed ' + LTRIM(STR(@RestBreakControl)) + ' rest break' + CASE WHEN @RestBreakControl > 1 THEN 's'
                                                                                                         ELSE ''
                                                                                                    END + @RestBreakCheckTypeVerbiage+'(notify your manager)', @RestBreakControl,
                                      @SiteState )
                            SET @RestBreakControl = @RestBreakControl - 1
                        END
  
                    SELECT  *,@TotalHoursForThisDayAtThisLocation AS TotalHoursForThisDayAtThisLocation
                    FROM    @tmpRecs
                    ORDER BY BreaksTaken DESC
                END
            ELSE
                BEGIN
                    SELECT  PromptDesc = ''
                    WHERE   1 = 0 
                END
        END



