CREATE      PROCEDURE [dbo].[usp_APP_VoidMissingPunches_SendFAAlert]
    (
      @Client CHAR(4) ,
      @PayrollPeriodEndDate DATETIME ,
      @TimeZone VARCHAR(3)
    )
AS 
/* Declare Local variables */
    DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 22Aug2016 >--
    DECLARE @Intime DATETIME
    DECLARE @InDay INT
    DECLARE @Outtime DATETIME
    DECLARE @OutDay INT
    DECLARE @groupCode INT
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
    
    SET @RecordIDList = ''
    
    DECLARE outerCursor CURSOR  FOR  
    SELECT   TPED.GroupCode ,
    tsn.SiteNo ,
    tes.SSN
    FROM    TimeCurrent..tblSiteNames AS TSN
    INNER JOIN TimeHistory..tblPeriodEndDates AS TPED
    ON      TSN.Client = TPED.Client
    AND TSN.GroupCode = TPED.GroupCode
    AND TPED.payrollPeriodEndDate = @PayrollPeriodEndDate
    AND TPED.Status <> 'C'
    AND TimeZone = @TimeZone      
    AND TPED.Client = @Client
    INNER JOIN TimeHistory..tblEmplSites AS TES
    ON      TPED.Client = TES.Client
    AND TPED.GroupCode = TES.GroupCode
    AND TPED.PayrollPeriodEndDate = TES.PayrollPeriodEndDate
    AND TES.SiteNo = TSN.SiteNo
    INNER JOIN TimeCurrent..tblEmplNames AS TEN
    ON tes.Client = TEN.Client
    AND tes.GroupCode = TEN.GroupCode
    AND tes.SSN=TEN.SSN
  --  AND ISNULL(EmpEmail,'')<>''
    ORDER BY TES.SSN
    
    OPEN outerCursor   
    FETCH NEXT FROM outerCursor INTO @groupcode   ,@SiteNo,@SSN
    -------------------------------------------------------------------------------------------------
    PRINT @@FETCH_STATUS
    WHILE @@FETCH_STATUS = 0 
        BEGIN   
            
    	      -------------------------------------------------------------------------------------------------
    		/* Get cursor with all missing punch records from THD for a given client,pped and timezone */
            DECLARE cVoidCursor CURSOR   FOR  
            SELECT  THTD.RecordID,InTime,InDay,OutTime,OutDay,TransDate  
            FROM    tblTimeHistDetail AS THTD
            INNER JOIN tblEmplNames AS EN
            ON      THTD.Client = EN.Client
            AND THTD.GroupCode = EN.GroupCode
            AND THTD.SSN = EN.SSN
            AND THTD.PayrollPeriodEndDate = EN.PayrollPeriodEndDate
            AND EN.MissingPunch = '1'
            INNER JOIN TimeCurrent..tblSiteNames AS TSN
            ON EN.Client = TSN.Client
            AND EN.GroupCode = TSN.GroupCode
            AND THTD.SiteNo=TSN.SiteNo
            AND TimeZone=@TimeZone   
            LEFT JOIN tblDayDef
            ON      InDay = tblDayDef.DayNo
            LEFT JOIN tblDayDef AS tblDayDef_1
            ON      OutDay = tblDayDef_1.DayNo
            WHERE   THTD.Client = @Client 
            AND THTD.GroupCode=@groupCode
            AND THTD.SiteNo=@SiteNo
            AND THTD.SSN=@SSN   
            AND THTD.PayrollPeriodEndDate = @PayrollPeriodEndDate
            AND (
            THTD.InDay = 10
            OR THTD.OutDay = 10
            )
            ORDER BY EN.SSN
          
            -------------------------------
       
            OPEN cVoidCursor 
            FETCH NEXT FROM cVoidCursor INTO @RecordId,@Intime,@Inday,@OutTime,@OutDay,@TransDate
    
            WHILE @@FETCH_STATUS = 0 
                BEGIN                    
                    SET @RecordIDList = @RecordIDList + ','
                        + CAST(@recordID AS VARCHAR(10))
                    
                    FETCH NEXT FROM cVoidCursor INTO @RecordId ,@Intime,@Inday,@OutTime,@OutDay ,@TransDate
                END  
              	   
            CLOSE cVoidCursor   
            DEALLOCATE cVoidCursor
            
            
            FETCH NEXT FROM outerCursor INTO @groupcode   ,@SiteNo,@SSN
        END 
    
    -------------------------------------------------------------------------------------------------
   	
    CLOSE outerCursor   
    DEALLOCATE outerCursor
    
    IF @RecordIDList <> '' 
        BEGIN
        PRINT @RecordIDList
            EXEC usp_APP_VoidMissingPunches_SendFAAlert_Emailer 
                @RecordIDList,'BEFORE'
            SET @RecordIDList = ''
        END





