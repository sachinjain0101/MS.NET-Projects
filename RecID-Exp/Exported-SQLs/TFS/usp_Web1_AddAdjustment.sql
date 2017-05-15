Create PROCEDURE [dbo].[usp_Web1_AddAdjustment]
    (
      @Client CHAR(4) ,
      @GroupCode INT ,
      @SiteNo INT ,
      @SSN INT ,
      @DeptNo INT ,
      @ShiftNo INT ,
      @PPED DATETIME ,
      @ClockAdjustmentNo VARCHAR(3) ,
      @AdjType CHAR(1) ,
      @Amount NUMERIC(7, 2) ,
      @Day TINYINT ,
      @UserID INT ,
      @ReasonCodeID INT = 0 ,
      @ShiftDiffClass CHAR(1) = '' ,
      @UserComment VARCHAR(2000) = '' ,
      @AdjName VARCHAR(10) = '',
      @UserCode VARCHAR(5) = NULL,
      @Reg NUMERIC(7,2) = 0,
      @OT NUMERIC(7,2) = 0,
      @DT NUMERIC(7,2) = 0,
      @IsClosedPeriodAdjustment BIT = 0,
	  @TransDate DATETIME = NULL ,
	  @childSiteno int = NULL,
	  @PreApprove int = 0, -- Sayi 09/15/2014 - Most of the VMS files come with pre-approved time. This flag helps to load time with approved status.
	  @PreApproveUserId int = 0 -- Sayi 09/15/2014 - Most of the VMS files come with pre-approved time
	   --UBROWN_20131213
	   ,@InDay INT = 0
	   ,@InTime DATETIME ='1899-12-30 00:00:00.000' 
	   ,@OutDay INT =0
	   ,@OutTime DATETIME ='1899-12-30 00:00:00.000' 
    )
AS --*/

/*
DECLARE @Client      char(4)
DECLARE @GroupCode   int
DECLARE @SiteNo      int
DECLARE @SSN         int
DECLARE @DeptNo      int
DECLARE @ShiftNo     int
DECLARE @PPED        datetime
DECLARE @ClockAdjustmentNo  char(1)
DECLARE @AdjType     char(1)
DECLARE @Amount      numeric(5,2)
DECLARE @Day         tinyint
DECLARE @UserID      int

SET @Client = 'CIG1'
SET @GroupCode = 900000
SET @SiteNo = 1
SET @SSN = 999001764
SET @DeptNo = 1
SET @ShiftNo = 1
SET @PPED = '01/15/05'
SET @ClockAdjustmentNo = '1'
SET @AdjType = 'H'
SET @Amount = 12
SET @Day = 2
SET @UserID = '2594'
*/

    DECLARE @ErrorCode INT
    DECLARE @thdRecordCnt INT
    DECLARE @adjRecordCnt INT
    DECLARE @SweptDateTime DATETIME
    DECLARE @AdjDate DATETIME
    DECLARE @xAdjHours NUMERIC(5, 2)
    DECLARE @PeriodStatus CHAR(1)
    DECLARE @Comment VARCHAR(8000)
    DECLARE @UserName VARCHAR(20)
    DECLARE @AdjustmentRecordID INT

    SET @SweptDateTime = NULL
    SET @ErrorCode = 0
    SET @xAdjHours = 0.00

    SELECT  @UserName = LogonName
    FROM    TimeCurrent..tblUser u WITH(NOLOCK)
    WHERE   UserID = @UserId
                  
    SELECT  @PeriodStatus = Status
    FROM    TimeHistory..tblPeriodEndDates WITH(NOLOCK)
    WHERE   Client = @Client
            AND GroupCode = @GroupCode
            AND PayrollPeriodEndDate = @PPED

	-------------------- Sajjan Sarkar 2/3/2016 - US3207-----------------------
	IF @InDay =0
		SET @InDay = @Day
	IF @OutDay = 0
		SET @OutDay = @Day

	------------------- Sayi 09/15/2014 BEGIN - Handle Pre-Approve Status -----

	DECLARE @ApprovalStatus CHAR(1) = ' '; --Default Value
	DECLARE @ApprovalStatusDate DATETIME = NULL; --Default Value
	DECLARE @ApprovalUserId int = 0; --Default Value

	IF @PreApprove = 1
	BEGIN
		SET @ApprovalStatus = 'A';
		SET @ApprovalStatusDate = GETDATE();
		SET @ApprovalUserId = @PreApproveUserId;
	END

	------------------- Sayi 09/15/2014 END - Handle Pre-Approve Status -------

    IF @PeriodStatus = 'C' 
    BEGIN
       SET @xAdjHours = CASE WHEN @Amount > 999.99 THEN 999.99 ELSE @Amount END 
    END

    IF RTRIM(LTRIM(@UserComment)) = 'Enter optional comment' 
        SET @UserComment = ''

-- Force the Rest Penalty Adjustment to zero hours.
-- for Davita Only.
    IF @Client IN ( 'DAVT', 'DVPC' )
        AND @ClockAdjustmentNo IN ( 'H', '/' ) 
        SET @Amount = 0.00


    IF @ErrorCode = 0 
        BEGIN
            --BEGIN TRANSACTION

            DECLARE @PayrollFreq CHAR(1)
            DECLARE @MasterPayrollDate DATETIME

            SET @PayrollFreq = (
                                 SELECT PayrollFreq
                                 FROM   TimeCurrent..tblClientGroups WITH(NOLOCK)
                                 WHERE  Client = @Client
                                        AND GroupCode = @GroupCode
                               )

            IF @PayrollFreq = 'S' 
                BEGIN
                    DECLARE @oTransDate DATETIME

                    SET @oTransDate = @PPED

                    WHILE DATEPART(weekday, @oTransDate) <> @Day 
                        BEGIN
                            SET @oTransDate = DATEADD(d, -1, @oTransDate)
                        END
                        SET @MasterPayrollDate = (
                                               SELECT TOP 1
                                                        MasterPayrollDate
                                               FROM     tblMasterPayrollDates WITH(NOLOCK)
                                               WHERE    Client = @Client
                                                        AND GroupCode = @GroupCode
                                                        AND MasterPayrollDate >= @oTransDate
                                               ORDER BY MasterPayrollDate
                                             )
                        IF @MasterPayrollDate IS NULL
                        BEGIN	
                          EXEC TimeHistory..usp_Web1_AddSemiMonthlyPeriod @Client, @GroupCode, @oTransDate
                          SET @MasterPayrollDate = (
                                               SELECT TOP 1
                                                        MasterPayrollDate
                                               FROM     tblMasterPayrollDates WITH(NOLOCK)
                                               WHERE    Client = @Client
                                                        AND GroupCode = @GroupCode
                                                        AND MasterPayrollDate >= @oTransDate
                                               ORDER BY MasterPayrollDate
                                             )
                        END
                    
                END
                ELSE 
                BEGIN
                    SET @MasterPayrollDate = (
                                               SELECT   MasterPayrollDate
                                               FROM     tblPeriodEndDates WITH(NOLOCK)
                                               WHERE    Client = @Client
                                                        AND GroupCode = @GroupCode
                                                        AND PayrollPeriodEndDate = @PPED
                                             )
                END

            IF @MasterPayrollDate IS NOT NULL 
                BEGIN                   
                    DECLARE @DefaultShiftNo SMALLINT
                    DECLARE @DiffType CHAR(1)
                    DECLARE @DiffRate NUMERIC(7, 2)
                    
                    IF @ShiftDiffClass != ''
                        AND @AdjType = 'H'
                        AND @ClockAdjustmentNo = '1' 
                        BEGIN
                            SELECT TOP 1
                                    @DiffType = DiffType ,
                                    @DiffRate = DiffRate
                            FROM    TimeCurrent.dbo.tblDeptShiftDiffs WITH(NOLOCK)
                            WHERE   client = @Client
                                    AND GroupCode = @Groupcode
                                    AND SiteNo = @SiteNo
                                    AND ShiftNo = @ShiftDiffClass
                                    AND ( DeptNo = @DeptNo
                                          OR DeptNo = 99
                                        )
                                    AND ApplyDiff = '1'
                                    AND DiffType <> 'D'
                                    AND WorkSpan1 <= @Amount
                                    AND RecordStatus = '1'
                                    AND CASE @Day
                                          WHEN 1 THEN ApplyDay1
                                          WHEN 2 THEN ApplyDay2
                                          WHEN 3 THEN ApplyDay3
                                          WHEN 4 THEN ApplyDay4
                                          WHEN 5 THEN ApplyDay5
                                          WHEN 6 THEN ApplyDay6
                                          WHEN 7 THEN ApplyDay7
                                        END IN ( '1', '2' )
                            ORDER BY CASE WHEN DeptNo = 99 THEN 9
                                          ELSE 0
                                     END

                        END
                    IF @DiffType IS NULL 
                        BEGIN
                            SET @DiffType = 'R'
                            SET @DiffRate = 0
                        END

					IF ISNULL(@UserCode, '') <> '*VMS'
					BEGIN
						IF @UserID = 0 
							BEGIN
								SET @UserCode = 'EMP'
							END
						ELSE IF @UserID = -1
							BEGIN
								SET @UserCode = IsNULL(@UserCode, 'WTE')
							END                        
						ELSE 
							BEGIN
								SET @UserCode = (
												  SELECT    UserCode
												  FROM      TimeCurrent..tblUser WITH(NOLOCK)
												  WHERE     UserID = @UserID
												)
							END
					END
    
                    SET @DefaultShiftNo = (
                                            SELECT  DefaultShift
                                            FROM    TimeCurrent..tblSiteNames WITH(NOLOCK)
                                            WHERE   client = @Client
                                                    AND groupcode = @GroupCode
                                                    AND SiteNo = @SiteNo
                                          )

                    IF ISNULL(@DefaultShiftNo, 0) = 0 
                        BEGIN
                            SET @DefaultShiftNo = 1
                        END

                    IF @ShiftNo IN ( 0, 1 ) 
                        SET @ShiftNo = @DefaultShiftNo
      
                    DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 06Sept2016 >--
                    DECLARE @DeductionOrEarning VARCHAR(20)
                    DECLARE @ADP_EarningsCode VARCHAR(10)
                    DECLARE @Rand_CreateBonusMarkup VARCHAR(1)
                    DECLARE @Rand_Markup NUMERIC(7, 2)
    
                    SELECT  @Rand_CreateBonusMarkup = '0'
                    IF ( @Client = 'RAND' ) 
                        BEGIN
                            SELECT  @DeductionOrEarning = ISNULL(ac.SpecialHandling, '') ,
                                    @ADP_EarningsCode = ISNULL(ac.ADP_EarningsCode, '') ,
                                    @Rand_Markup = ISNULL(ac.BillingMarkup, 0) / 100
                            FROM    TimeCurrent.dbo.tblAdjCodes ac WITH(NOLOCK)
                            WHERE   ac.Client = @Client
                                    AND ac.GroupCode = @GroupCode
                                    AND ac.ClockAdjustmentNo = @ClockAdjustmentNo    	    	
    	
                            IF ( LEFT(@DeductionOrEarning, 1) = 'D' ) 
                                BEGIN
                                    SELECT  @Amount = @Amount * -1
                                END
    	
                            IF ( @AdjType = 'D'
                                 AND @Rand_Markup <> 0
                               ) 
                                BEGIN
                                    SELECT  @Rand_CreateBonusMarkup = '1'
                                END
                        END
    -- tblTimeHistDetail
    PRINT 'inserting'
    PRINT CASE @AdjType WHEN 'H' THEN @Reg ELSE 0 END
    
    
                    INSERT  INTO [TimeHistory].[dbo].[tblTimeHistDetail]
                            ( [Client] ,
                              [GroupCode] ,
                              [SSN] ,
                              [PayrollPeriodEndDate] ,
                              [MasterPayrollDate] ,
                              [SiteNo] ,
                              [DeptNo] ,
                              [ShiftNo] ,
                              [JobID] ,
                              [TransDate] ,
                              [EmpStatus] ,
                              [BillRate] ,
                              [BillOTRate] ,
                              [BillOTRateOverride] ,
                              [PayRate] ,
                              [InDay] ,
                              [InTime] ,
                              [OutDay] ,
                              [OutTime] ,
                              [Hours] ,
                              [Dollars] ,
                              [ClockAdjustmentNo] ,
                              [AdjustmentCode] ,
                              [AdjustmentName] ,
                              [TransType] ,
                              [AgencyNo] ,
                              [InSrc] ,
                              [OutSrc] ,
                              [DaylightSavTime] ,
                              [Holiday] ,
                              [xAdjHours] ,
                              [AprvlStatus] ,
                              [AprvlStatus_UserID] ,
                              [AprvlStatus_Date] ,
                              [AprvlAdjOrigRecID] ,
                              [AprvlAdjOrigClkAdjNo] ,
                              [UserCode] ,
                              [ShiftDiffClass] ,
                              [ShiftDiffAmt] ,
                              [OutUserCode],
                              RegHours,
                              OT_Hours,
                              DT_Hours      ,
							  InSiteNo, 
							  OutSiteNo                                            
                            )
                            SELECT TOP 1
                                    @Client ,
                                    @GroupCode ,
                                    @SSN ,
                                    @PPED ,
                                    @MasterPayrollDate ,
                                    @SiteNo ,
                                    @DeptNo ,
                                    @ShiftNo ,
                                    0 ,
									CASE WHEN @TransDate IS NOT NULL THEN @TransDate ELSE  --UBROWN_20131213
											CASE WHEN @Day <= DATEPART(dw, @PPED)
																THEN DATEADD(day, -( DATEPART(dw, @PPED) - @Day ), @PPED)
																ELSE DATEADD(day, ( ( @Day - DATEPART(dw, @PPED) ) - 7 ), @PPED)
											END
									END ,  --UBROWN_20131213
                                    empls.Status ,
                                    empldepts.BillRate ,
                                    0 ,
                                    0 ,
                                    empldepts.PayRate ,
                                    @InDay ,
                                    @InTime ,
                                    @OutDay ,
                                    @OutTime ,
                                    CASE @AdjType
                                      WHEN 'H' THEN @Amount
                                      ELSE 0
                                    END ,
                                    CASE @AdjType
                                      WHEN 'D' THEN @Amount
                                      ELSE 0
                                    END ,
                                    @ClockAdjustmentNo ,
                                    @ClockAdjustmentNo ,
                                    CASE WHEN @Client = 'DAVT'
                                              AND @ClockADjustmentNo = 'D'
                                              AND @AdjName LIKE 'PRE %'
                                         THEN @AdjName
                                         ELSE CASE WHEN @AdjName <> ''
                                                   THEN @AdjName
                                                   ELSE LEFT(adjs.AdjustmentName, 10)
                                              END
                                    END ,
                                    0 ,
                                    empls.AgencyNo ,
                                    '3' ,
                                    ' ' ,
                                    '0' ,
                                    '0' ,
                                    @xAdjHours ,
                                    @ApprovalStatus,--' ' , --Sayi - 09/15/2014
                                    @ApprovalUserId,--0 , --Sayi - 09/15/2014
                                    @ApprovalStatusDate,--NULL ,  --Sayi - 09/15/2014
                                    NULL ,
                                    NULL ,
                                    @UserCode ,
                                    @ShiftDiffClass ,
                                    CASE WHEN @DiffType = 'R' THEN @DiffRate
                                         WHEN @DiffType = 'P'
                                         THEN ROUND(@DiffRate * emplDepts.PayRate, 2)
                                         ELSE 0
                                    END ,
                                    CASE WHEN @Client = 'DAVT'
                                              AND @ClockADjustmentNo = 'D'
                                              AND @AdjName LIKE 'PRE %'
                                         THEN 'MCRP'
                                         ELSE ''
                                    END,                                    
                                    CASE @AdjType WHEN 'H' THEN @Reg ELSE 0 END,
                                    CASE @AdjType WHEN 'H' THEN @OT ELSE 0 END,
                                    CASE @AdjType WHEN 'H' THEN @DT ELSE 0 END,
					@childSiteno,
					@childSiteno
                            FROM    tblEmplNames AS empls
                            LEFT JOIN tblEmplNames_Depts AS empldepts
                            ON      empldepts.Client = empls.Client
                                    AND empldepts.GroupCode = empls.GroupCode
                                    AND empldepts.SSN = empls.SSN
                                    AND empldepts.PayrollPeriodEndDate = empls.PayrollPeriodEndDate
                                    AND empldepts.Department = @DeptNo
                            INNER JOIN TimeCurrent..tblAdjCodes AS adjs
                            ON      adjs.Client = empls.Client
                                    AND adjs.GroupCode = empls.GroupCode
--      AND adjs.PayrollPeriodEndDate = empls.PayrollPeriodEndDate
                                    AND adjs.ClockAdjustmentNo = @ClockAdjustmentNo
                            WHERE   empls.Client = @Client
                                    AND empls.GroupCode = @GroupCode
                                    AND empls.SSN = @SSN
                                    AND empls.PayrollPeriodEndDate = @PPED
--      AND empls.RecordStatus = '1'

                    --SET @thdRecordCnt = @@Rowcount

                    SET @RecordID = SCOPE_IDENTITY()
                    IF @RecordID > 0
                    --IF @thdRecordCnt > 0 
                        BEGIN
                            IF @ReasonCodeID <> 0 
                                BEGIN
                                    EXEC usp_Web1_AssignReasonCode 
                                        @Client ,
                                        @GroupCode ,
                                        @SSN ,
                                        @PPED ,
                                        NULL ,
                                        @ReasonCodeID ,
                                        @RecordID
                                END

                            IF ( @AdjType = 'D'
                                 AND ISNULL(@Amount, 0) > 999.99
                               ) 
                                BEGIN
                                    SELECT  @SweptDateTime = GETDATE()
                                END
			
                            IF ( @Rand_CreateBonusMarkup = '1' ) 
                                BEGIN
    		-- Insert the markup thd transaction based on the original transaction
                                    INSERT  INTO TimeHistory.dbo.tblTimeHistDetail
                                            ( Client ,
                                              GroupCode ,
                                              SSN ,
                                              PayrollPeriodEndDate ,
                                              MasterPayrollDate ,
                                              SiteNo ,
                                              DeptNo ,
                                              ShiftNo ,
                                              JobID ,
                                              TransDate ,
                                              EmpStatus ,
                                              BillRate ,
                                              BillOTRate ,
                                              BillOTRateOverride ,
                                              PayRate ,
                                              InDay ,
                                              InTime ,
                                              OutDay ,
                                              OutTime ,
                                              Hours ,
                                              Dollars ,
                                              ClockAdjustmentNo ,
                                              AdjustmentCode ,
                                              AdjustmentName ,
                                              TransType ,
                                              AgencyNo ,
                                              InSrc ,
                                              OutSrc ,
                                              DaylightSavTime ,
                                              Holiday ,
                                              xAdjHours ,
                                              AprvlStatus ,
                                              AprvlStatus_UserID ,
                                              AprvlStatus_Date ,
                                              AprvlAdjOrigRecID ,
                                              AprvlAdjOrigClkAdjNo ,
                                              UserCode ,
                                              ShiftDiffClass ,
                                              ShiftDiffAmt,
											  InSiteNo, 
											  OutSiteNo 
                                            )
                                            SELECT  Client ,
                                                    GroupCode ,
                                                    SSN ,
                                                    PayrollPeriodEndDate ,
                                                    MasterPayrollDate ,
                                                    SiteNo ,
                                                    DeptNo ,
                                                    ShiftNo ,
                                                    JobID ,
                                                    TransDate ,
                                                    EmpStatus ,
                                                    BillRate ,
                                                    BillOTRate ,
                                                    BillOTRateOverride ,
                                                    PayRate ,
                                                    InDay ,
                                                    InTime ,
                                                    OutDay ,
                                                    OutTime ,
                                                    Hours ,
                                                    Dollars * @Rand_Markup ,
                                                    'Z' ,
                                                    'Z' ,
                                                    'Markup' ,
                                                    TransType ,
                                                    AgencyNo ,
                                                    InSrc ,
                                                    OutSrc ,
                                                    DaylightSavTime ,
                                                    Holiday ,
                                                    xAdjHours ,
                                                    AprvlStatus ,
                                                    AprvlStatus_UserID ,
                                                    AprvlStatus_Date ,
                                                    AprvlAdjOrigRecID ,
                                                    AprvlAdjOrigClkAdjNo ,
                                                    UserCode ,
                                                    ShiftDiffClass ,
                                                    ShiftDiffAmt,
													@childSiteno,
													@childSiteno
                                            FROM    TimeHistory..tblTimeHistDetail
                                            WHERE   RecordId = @RecordID			
				
                                    SET @thdRecordCnt = @@Rowcount
                                    SET @RecordID = SCOPE_IDENTITY()
		    				
                                    IF @ReasonCodeID <> 0
                                        AND ISNULL(@thdRecordCnt, 0) > 0 
                                        BEGIN
                                            EXEC usp_Web1_AssignReasonCode 
                                                @Client ,
                                                @GroupCode ,
                                                @SSN ,
                                                @PPED ,
                                                NULL ,
                                                @ReasonCodeID ,
                                                @RecordID
                                        END																									      
                                END			
      -- tblAdjustments
                            INSERT  INTO TimeCurrent.dbo.tblAdjustments
                                    ( Client ,
                                      GroupCode ,
                                      PayrollPeriodEndDate ,
                                      SSN ,
                                      SiteNo ,
                                      DeptNo ,
                                      ClockAdjustmentNo ,
                                      AdjustmentCode ,
                                      AdjustmentName ,
                                      HoursDollars ,
                                      SunVal ,
                                      MonVal ,
                                      TueVal ,
                                      WedVal ,
                                      ThuVal ,
                                      FriVal ,
                                      SatVal ,
                                      WeekVal ,
                                      TotalVal ,
                                      UserID ,
                                      UserName ,
                                      TransDateTime ,
                                      RecordStatus ,
                                      IPAddr ,
                                      ShiftNo ,
                                      SweptDateTime ,
                                      Comment,
                                      THDRecordID,
                                      ClosedPeriodAdjustment                                     
                                    )
                                    SELECT  @Client ,
                                            @GroupCode ,
                                            @PPED ,
                                            @SSN ,
                                            @SiteNo ,
                                            @DeptNo ,
                                            @ClockAdjustmentNo ,
                                            AdjustmentCode ,
                                            LEFT(AdjustmentName, 10) ,
                                            @AdjType ,
                                            ( CASE @Day
                                                WHEN 1 THEN @Amount
                                                ELSE 0
                                              END ) ,
                                            ( CASE @Day
                                                WHEN 2 THEN @Amount
                                                ELSE 0
                                              END ) ,
                                            ( CASE @Day
                                                WHEN 3 THEN @Amount
                                                ELSE 0
                                              END ) ,
                                            ( CASE @Day
                                                WHEN 4 THEN @Amount
                                                ELSE 0
                                              END ) ,
                                            ( CASE @Day
                                                WHEN 5 THEN @Amount
                                                ELSE 0
                                              END ) ,
                                            ( CASE @Day
                                                WHEN 6 THEN @Amount
                                                ELSE 0
                                              END ) ,
                                            ( CASE @Day
                                                WHEN 7 THEN @Amount
                                                ELSE 0
                                              END ) ,
                                            0 ,
                                            @Amount ,
                                            @UserID ,
                                            @UserName ,
                                            GETDATE() ,
                                            '1' ,
                                            '' ,
                                            @ShiftNo ,
                                            @SweptDateTime ,
                                            @UserComment,
                                            @RecordID,
                                            ISNULL(@IsClosedPeriodAdjustment,0)
                                    FROM    TimeCurrent..tblAdjCodes
                                    WHERE   Client = @Client
                                            AND GroupCode = @GroupCode
                                            AND ClockAdjustmentNo = @ClockAdjustmentNo
                              SET @AdjustmentRecordID = SCOPE_IDENTITY()
                              
                                        
							                                  
      
                            IF ( @Rand_CreateBonusMarkup = '1' ) 
                                BEGIN
	      -- Insert the markup tblAdjustments transaction based on the original transaction
                                    INSERT  INTO TimeCurrent.dbo.tblAdjustments
                                            ( Client ,
                                              GroupCode ,
                                              PayrollPeriodEndDate ,
                                              SSN ,
                                              SiteNo ,
                                              DeptNo ,
                                              ClockAdjustmentNo ,
                                              AdjustmentCode ,
                                              AdjustmentName ,
                                              HoursDollars ,
                                              SunVal ,
                                              MonVal ,
                                              TueVal ,
                                              WedVal ,
                                              ThuVal ,
                                              FriVal ,
                                              SatVal ,
                                              WeekVal ,
                                              TotalVal ,
                                              UserID ,
                                              TransDateTime ,
                                              RecordStatus ,
                                              IPAddr ,
                                              ShiftNo ,
                                              SweptDateTime
                                            )
                                            SELECT  @Client ,
                                                    @GroupCode ,
                                                    @PPED ,
                                                    @SSN ,
                                                    @SiteNo ,
                                                    @DeptNo ,
                                                    'Z' ,
                                                    AdjustmentCode ,
                                                    LEFT(AdjustmentName, 10) ,
                                                    @AdjType ,
                                                    ( CASE @Day
                                                        WHEN 1 THEN @Amount
                                                        ELSE 0
                                                      END ) ,
                                                    ( CASE @Day
                                                        WHEN 2 THEN @Amount
                                                        ELSE 0
                                                      END ) ,
                                                    ( CASE @Day
                                                        WHEN 3 THEN @Amount
                                                        ELSE 0
                                                      END ) ,
                                                    ( CASE @Day
                                                        WHEN 4 THEN @Amount
                                                        ELSE 0
                                                      END ) ,
                                                    ( CASE @Day
                                                        WHEN 5 THEN @Amount
                                                        ELSE 0
                                                      END ) ,
                                                    ( CASE @Day
                                                        WHEN 6 THEN @Amount
                                                        ELSE 0
                                                      END ) ,
                                                    ( CASE @Day
                                                        WHEN 7 THEN @Amount
                                                        ELSE 0
                                                      END ) ,
                                                    0 ,
                                                    @Amount * @Rand_Markup ,
                                                    @UserID ,
                                                    GETDATE() ,
                                                    '1' ,
                                                    '' ,
                                                    @ShiftNo ,
                                                    @SweptDateTime
                                            FROM    TimeCurrent..tblAdjCodes
                                            WHERE   Client = @Client
                                                    AND GroupCode = @GroupCode
                                                    AND ClockAdjustmentNo = 'Z'
                                END       

                            IF @PeriodStatus = 'C' 
                                BEGIN
                                    SET @AdjDate = 
																																				CASE WHEN @TransDate IS NOT NULL THEN @TransDate ELSE  --UBROWN_20131213
																																					CASE WHEN @Day <= DATEPART(dw, @PPED)
																																																									THEN DATEADD(day, -( DATEPART(dw, @PPED) - @Day ), @PPED)
																																																									ELSE DATEADD(day,( ( @Day - DATEPART(dw, @PPED) ) - 7 ), @PPED)
																																																				END
																																				END  --UBROWN_20131213
                                    SET @Comment = 'Adjustment of '
                                        + CAST(@Amount AS VARCHAR) + ' for '
                                        + CONVERT(NVARCHAR(20), @AdjDate, 101)
                                        + ' added after period was closed'
                                    INSERT  INTO tblTimeHistDetail_Comments
                                            ( Client ,
                                              GroupCode ,
                                              PayrollPeriodEndDate ,
                                              SSN ,
                                              CreateDate ,
                                              Comments ,
                                              UserID ,
                                              UserName ,
                                              ManuallyAdded
                                            )
                                    VALUES  ( @Client ,
                                              @GroupCode ,
                                              @PPED ,
                                              @SSN ,
                                              GETDATE() ,
                                              @Comment ,
                                              @UserID ,
                                              '' ,
                                              'N'
                                            )
                                END
                        END
                    ELSE 
                        BEGIN
                            --PRINT 'err' + @@error
                            --ROLLBACK TRANSACTION x1
                            RAISERROR ('Failed to add transaction. Please try again.', 16, 1)
                            SET @ErrorCode = @@error
                            GOTO ErrorHandler
                        END  

                END
            ELSE 
                BEGIN
     -- It won't let me do this inline
                    DECLARE @strPPED AS VARCHAR(10)
                    SET @strPPED = CONVERT(VARCHAR(10), @PPED, 101)
                    --ROLLBACK TRANSACTION x1
                    RAISERROR ('Group %d is not set up for Pay Period %s', 16, 1, @GroupCode, @strPPED)
                    
                    SET @ErrorCode = @@error
                    GOTO ErrorHandler
                END

                      
            --IF @ErrorCode = 0 
            -- COMMIT TRANSACTION
                
        END

--PRINT @ErrorCode
ErrorHandler:
    RETURN @ErrorCode
