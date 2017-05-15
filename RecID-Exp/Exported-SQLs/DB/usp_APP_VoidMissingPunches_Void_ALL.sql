CREATE  PROCEDURE [dbo].[usp_APP_VoidMissingPunches_Void_ALL]
    (
      @Client CHAR(4) ,
      @GroupCode int,
      @PayrollPeriodEndDate DATETIME 
    )
AS 
/* Declare Local variables */
    DECLARE @RecordID INT
    DECLARE @Intime DATETIME
    DECLARE @InDay INT
    DECLARE @Outtime DATETIME
    DECLARE @OutDay INT
    DECLARE @SSN INT
    DECLARE @TransDate DATETIME
    DECLARE @SiteNo INT
    DECLARE @RecordIDList VARCHAR(1000)
    
    /* Declare Constants */
    DECLARE @TRANSACTION_NAME VARCHAR(20)
    DECLARE @NULL_TIME DATETIME
    DECLARE @COMMENT VARCHAR(500)
    DECLARE @SYSTEM_USER_ID TINYINT
    DECLARE @SYSTEM_LOGONNAME VARCHAR(10)
    DECLARE @IS_MANUALLY_ADDED CHAR(1)
    
     /* Initialize Constants */
    SET @TRANSACTION_NAME = 'VoidTransaction'
    SET @NULL_TIME = '1899-12-30 00:00:00.000'    
    SET @SYSTEM_USER_ID = 1
    SET @SYSTEM_LOGONNAME = 'SYSTEM'
    SET @IS_MANUALLY_ADDED = 'N'               
    
    SET @recordIDList = ''

		DECLARE @PPED1 DATETIME
		SET @PPED1 = DATEADD(DAY,-7, @PayrollPeriodEndDate)
    

        SELECT  Distinct t.GroupCode ,
                t.SiteNo ,
                t.SSN
				FROM TimeHistory..tblTimeHistDetail AS t WITH (NOLOCK)
				INNER JOIN Timecurrent..tblClientGroups AS g
				ON g.client = t.Client
				AND g.groupcode = t.GroupCode
				AND g.RecordStatus = '1'
				INNER JOIN TimeHistory..tblPeriodEndDates AS p
				ON p.client = t.Client
				AND p.groupcode = t.GroupCode
				AND p.PayrollPeriodEndDate = t.PayrollPeriodEndDate
				AND p.status <> 'C'
				WHERE t.Client = @Client
				AND t.PayrollPeriodEndDate IN(@PayrollPeriodEndDate, @PPED1)
				AND (t.InDay > 7 OR t.OutDay > 7 )

    DECLARE outerCursor CURSOR STATIC
    FOR
        SELECT  Distinct t.GroupCode ,
                t.SiteNo ,
                t.SSN,
								t.PayrollPeriodEndDate
				FROM TimeHistory..tblTimeHistDetail AS t WITH (NOLOCK)
				INNER JOIN Timecurrent..tblClientGroups AS g
				ON g.client = t.Client
				AND g.groupcode = t.GroupCode
				AND g.RecordStatus = '1'
				INNER JOIN TimeHistory..tblPeriodEndDates AS p
				ON p.client = t.Client
				AND p.groupcode = t.GroupCode
				AND p.PayrollPeriodEndDate = t.PayrollPeriodEndDate
				AND p.status <> 'C'
				WHERE t.Client = @Client
				AND t.PayrollPeriodEndDate IN(@PayrollPeriodEndDate, @PPED1)
				AND (t.InDay > 7 OR t.OutDay > 7 )
        
    OPEN outerCursor   
    FETCH NEXT FROM outerCursor INTO @Groupcode, @SiteNo, @SSN, @PayrollPeriodEndDate
    	
    WHILE @@FETCH_STATUS = 0 
        BEGIN   
    	      -------------------------------------------------------------------------------------------------
    	      /* Get cursor with all missing punch records from THD for a given client,pped and timezone */
            DECLARE cVoidCursor CURSOR STATIC
            FOR
                SELECT  THTD.RecordID ,
                        THTD.InTime ,
                        THTD.InDay ,
                        THTD.OutTime ,
                        THTD.OutDay ,
                        THTD.TransDate
                FROM    TimeHistory..tblTimeHistDetail AS THTD with(nolock)
                WHERE   THTD.Client = @Client
                        AND THTD.GroupCode = @GroupCode
                        AND THTD.SiteNo = @SiteNo
                        AND THTD.SSN = @SSN
                        AND THTD.PayrollPeriodEndDate = @PayrollPeriodEndDate
                        AND (THTD.InDay > 7 OR THTD.OutDay > 7)
	
            OPEN cVoidCursor   
            FETCH NEXT FROM cVoidCursor INTO @RecordId, @Intime, @Inday, @OutTime, @OutDay, @TransDate
            WHILE @@FETCH_STATUS = 0 
                BEGIN                    	    
                    IF @@ERROR <> 0 
                        GOTO ERR_HANDLER
             
                    INSERT  INTO TimeCurrent..tblFixedPunch
                            ( OrigRecordId ,
                              Client ,
                              GroupCode ,
                              SSN ,
                              PayrollPeriodEndDate ,
                              MasterPayrollDate ,
                              OldSiteNo ,
                              OldDeptNo ,
                              OldJobID ,
                              OldTransDate ,
                              OldEmpStatus ,
                              OldBillRate ,
                              OldBillOTRate ,
                              OldBillOTRateOverride ,
                              OldPayRate ,
                              OldShiftNo ,
                              OldInDay ,
                              OldInTime ,
                              OldInSrc ,
                              OldOutDay ,
                              OldOutTime ,
                              OldOutSrc ,
                              OldHours ,
                              OldDollars ,
                              OldClockAdjustmentNo ,
                              OldAdjustmentCode ,
                              OldAdjustmentName ,
                              OldTransType ,
                              OldAgencyNo ,
                              OldDaylightSavTime ,
                              OldHoliday ,
                              NewSiteNo ,
                              NewDeptNo ,
                              NewJobID ,
                              NewTransDate ,
                              NewEmpStatus ,
                              NewBillRate ,
                              NewBillOTRate ,
                              NewBillOTRateOverride ,
                              NewPayRate ,
                              NewShiftNo ,
                              NewInDay ,
                              NewInTime ,
                              NewInSrc ,
                              NewOutDay ,
                              NewOutTime ,
                              NewOutSrc ,
                              NewHours ,
                              NewDollars ,
                              NewClockAdjustmentNo ,
                              NewAdjustmentCode ,
                              NewAdjustmentName ,
                              NewTransType ,
                              NewAgencyNo ,
                              NewDaylightSavTime ,
                              NewHoliday ,
                              UserName ,
                              UserID ,
                              TransDateTime ,
                              IPAddr
				 
                            )
                            SELECT  RecordID ,
                                    Client ,
                                    GroupCode ,
                                    SSN ,
                                    PayrollPeriodEndDate ,
                                    MasterPayrollDate ,
                                    SiteNo ,
                                    DeptNo ,
                                    JobID ,
                                    TransDate ,
                                    EmpStatus ,
                                    BillRate ,
                                    BillOTRate ,
                                    BillOTRateOverride ,
                                    PayRate ,
                                    ShiftNo ,
                                    InDay ,
                                    InTime ,
                                    InSrc ,
                                    OutDay ,
                                    OutTime ,
                                    OutSrc ,
                                    Hours ,
                                    Dollars ,
                                    ClockAdjustmentNo ,
                                    AdjustmentCode ,
                                    AdjustmentName ,
                                    TransType ,
                                    AgencyNo ,
                                    DaylightSavTime ,
                                    Holiday ,
                                    SiteNo ,
                                    DeptNo ,
                                    JobID ,
                                    TransDate ,
                                    EmpStatus ,
                                    BillRate ,
                                    BillOTRate ,
                                    BillOTRateOverride ,
                                    PayRate ,
                                    1 ,
                                    InDay ,
                                    InTime ,
                                    InSrc ,
                                    OutDay ,
                                    OutTime ,
                                    OutSrc ,
                                    Hours = '0' ,
                                    Dollars ,
                                    ClockAdjustmentNo ,
                                    AdjustmentCode ,
                                    AdjustmentName ,
                                    TransType = '7' ,
                                    AgencyNo ,
                                    DaylightSavTime ,
                                    Holiday ,
                                    UserName = @SYSTEM_LOGONNAME ,
                                    UserID = @SYSTEM_USER_ID ,
                                    TransDateTime = GETDATE() ,
                                    IPAddr = '0.0.0.00'
                            FROM    TimeHistory..tblTimeHistDetail
                            WHERE   RecordID = @RecordID
                    
                    
                    IF @@ERROR <> 0 
                        GOTO ERR_HANDLER       
             /* check if it is missing an in punch */      
                    IF @Intime = @NULL_TIME
                        AND @InDay > 7
                        BEGIN
                    
                     /* Sync Intime,Inday,Insrc with Out Data and set transtype=7 so that recalc ignores this record */
                            UPDATE  TimeHistory..tblTimeHistDetail
                            SET     TransType = '7' ,
                                    InTime = OutTime ,
                                    --ActualInTime=ActualOutTime,
                                    --Hours=0,
                                    InDay = OutDay ,
                                    InSrc = 3 ,
                                     --AdjustmentName='VOIDED',
                                    Changed_InPunch = '1',
                                    Shiftno = 1
                            WHERE   RecordID = @RecordID
                        END 
               
                    IF @@ERROR <> 0 
                        GOTO ERR_HANDLER
                    IF @Outtime = @NULL_TIME
                        AND @OutDay > 7 
                        BEGIN
                     /* Sync Outtime,Outday,Outsrc with In Data and set transtype=7 so that recalc ignores this record */
                            UPDATE  TimeHistory..tblTimeHistDetail
                            SET     TransType = '7' ,
                                    OutTime = InTime ,
                                    --ActualOutTime=ActualInTime,
                                    OutDay = InDay ,
                                    --Hours=0,
                                    OutSrc = 3 ,
                                    --AdjustmentName='VOIDED',
                                    Changed_OutPunch = '1',
                                    Shiftno = 1
                            WHERE   RecordID = @RecordID
                        END
               
                    IF @@ERROR <> 0 
                        GOTO ERR_HANDLER
            /* reset missing punch flag in emplnames */    
                    UPDATE  TimeHistory..tblEmplNames
                    SET     MissingPunch = '0'
                    WHERE   client = @Client
                            AND groupcode = @groupCode
                            AND PayrollPeriodEndDate = @PayrollPeriodEndDate
                            AND SSN = @SSN
               
                    IF @@ERROR <> 0 
                        GOTO ERR_HANDLER
            /* Insert a comment */ 
                    SET @COMMENT = 'Punch Voided by PeopleNet for missing punch on '
                        + TimeCurrent.dbo.fn_GetDateTime(@TransDate, 3) 
                    INSERT  INTO TimeHistory..tblTimeHistDetail_Comments
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
                    VALUES  ( @client ,
                              @groupcode ,
                              @PayrollPeriodEndDate ,
                              @SSN ,
                              GETDATE() ,
                              @COMMENT ,
                              @SYSTEM_USER_ID ,
                              @SYSTEM_LOGONNAME ,
                              @IS_MANUALLY_ADDED
                            ) 
                    SET @recordIDList = @ReCordIDList + ','
                        + CAST(@RecordID AS VARCHAR(15))
                    FETCH NEXT FROM cVoidCursor INTO @RecordId, @Intime,
                        @Inday, @OutTime, @OutDay, @TransDate
                END   
	
            CLOSE cVoidCursor   
            DEALLOCATE cVoidCursor
    
    	      
    	      -------------------------------------------------------------------------------------------------
    	
            FETCH NEXT FROM outerCursor INTO @groupcode, @SiteNo, @SSN,@PayrollPeriodEndDate
        END   
    	
    CLOSE outerCursor   
    DEALLOCATE outerCursor
     
    --PRINT '::' + @recordIDList  
        
    IF @@ERROR <> 0 
        GOTO ERR_HANDLER    
    EXEC TimeHistory..usp_APP_VoidMissingPunches_SendFAAlert_Emailer 
        @RecordIDList ,
        'AFTER',
				@Client 
    
        
    ERR_HANDLER:
    IF @@TRANCOUNT > 0 
        BEGIN
            SELECT  'Unexpected error occurred!'
                    + CAST(@@ERROR AS VARCHAR(10))    
           
        END


