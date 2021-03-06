USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_APP_VoidMissingPunches_SendTeamMateAlert]    Script Date: 3/31/2015 11:53:38 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_APP_VoidMissingPunches_SendTeamMateAlert]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_APP_VoidMissingPunches_SendTeamMateAlert] AS' 
END
GO




/*******************************************************************************************
	-- Purpose: Multipurpose stored proc used fetch grid data for the employee search
	-- Written by: Sajjan Sarkar
	-- Module: OrderEntry-->Employee Search
	-- Tested on: SQL Server 2000
	-- Date created: 2010-01-27 17:00
	===================================================================================
	Version History:
	Date			Modifier		Change Desc
	===================================================================================
	2010-01-27		Sajjan Sarkar		Initial  version		

********************************************************************************************/
/*
OBJECTIVE:
To send email to every employee who has missingpunches with missingpunch info

LOGIC:
1. ALTER  cursor with all employees for all sites in all groups for the given payeek and who have valid email IDs
	for each employee in this cursor:
	{
		create a cursor with all missinpunch txns
		for each txn in this cursor:
		{
			append the txn's THD record ID to the CSV list variable @RecordIDList
		}
		if this employee has missing punches (i.e.:@RecordIDList<>'')
		{
			send email by passing this CSV list
		}	
	}	
*/



-- =============================================
-- example to execute the store procedure
-- =============================================
--EXEC  usp_APP_VoidMissingPunches_SendTeamMateAlert 'OLST','1/8/2011','EST'

ALTER     PROCEDURE [dbo].[usp_APP_VoidMissingPunches_SendTeamMateAlert]
    (
      @Client CHAR(4) ,
      @PayrollPeriodEndDate DATETIME ,
      @TimeZone VARCHAR(3)
    )
AS /* Declare Local variables */
    DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 22Aug2016 >--
    DECLARE @Intime DATETIME
    DECLARE @InDay INT
    DECLARE @Outtime DATETIME
    DECLARE @OutDay INT
    DECLARE @groupCode INT
    DECLARE @SSN INT
    DECLARE @TransDate DATETIME
    DECLARE @SiteNo INT
    DECLARE @EmplNamesRecordID INT
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
    
    /*  This variable stores a CSV list of the recordIDs from THD for the Missing Punch txns*/
    SET @RecordIDList=''
    
    
    /*
      Outer cursor gets list of employees in all sites for that payweek,
      reason is to avoind hittting THD without all its 4 indices
      with this cursor we can select from THD with C,G,P,SSN
    */
    DECLARE outerCursor CURSOR  FOR  
    SELECT   TPED.GroupCode ,
    tsn.SiteNo ,
    tes.SSN,TEN.RecordID
    FROM    TimeCurrent..tblSiteNames AS TSN
    INNER JOIN TimeHistory..tblPeriodEndDates AS TPED
    ON      TSN.Client = TPED.Client
    AND TSN.GroupCode = TPED.GroupCode
    AND TPED.payrollPeriodEndDate = @PayrollPeriodEndDate
    AND TPED.Status <> 'C' -- consider only open weeks
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
    AND ISNULL(EmpEmail,'')<>'' -- no point including employees without email ids
    ORDER BY TES.SSN
    

    OPEN outerCursor   
    FETCH NEXT FROM outerCursor INTO @groupcode   ,@SiteNo,@SSN,@EmplNamesRecordID
    -------------------------------------------------------------------------------------------------

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
                    
                    SET @RecordIDList = @RecordIDList+','+CAST(@recordID AS VARCHAR(10))
                    
                    FETCH NEXT FROM cVoidCursor INTO @RecordId ,@Intime,@Inday,@OutTime,@OutDay ,@TransDate
                END  
            
  	    IF @RecordIDList <>''
  	    	BEGIN
  	    		EXEC usp_APP_VoidMissingPunches_SendTeamMateAlert_Emailer @RecordIDList
  	    		SET @RecordIDList=''
  	    	END
	
            
            
            CLOSE cVoidCursor   
            DEALLOCATE cVoidCursor
            
            
            FETCH NEXT FROM outerCursor INTO @groupcode   ,@SiteNo,@SSN,@EmplNamesRecordID
        END 
    
    -------------------------------------------------------------------------------------------------
  
           
    	
    CLOSE outerCursor   
    DEALLOCATE outerCursor
        
    







GO
