USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_APP_VoidMissingPunches_Void_ALL]    Script Date: 3/31/2015 11:53:38 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_APP_VoidMissingPunches_Void_ALL]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_APP_VoidMissingPunches_Void_ALL] AS' 
END
GO


/*******************************************************************************************
	-- Purpose: Multipurpose stored proc used fetch grid data for the employee search
	-- Written by: Sajjan Sarkar
	-- Module: Void Punch Project
	-- Tested on: SQL Server 2000
	-- Date created: 2011-01-5 11:00
	===================================================================================
	Version History:
	Date			Modifier		Change Desc
	===================================================================================
	2011-01-5		Sajjan Sarkar		Initial  version		

********************************************************************************************/
-- =============================================
-- example to execute the store procedure
-- =============================================
--EXEC usp_APP_VoidMissingPunches_Void 'trac','1/8/2011','PST'

/*
select * from TimeCurrent..tblClientGroups where Client = 'DAVT' and GroupName like '%river%'

select TZ = TimeZone, * from TimeCurrent..tblSiteNames where Client = 'DAVT' and GroupCode = 501600 and RecordStatus = '1'
order by TimeZone desc

Exec TimeHistory..usp_APP_VoidMissingPunches_Void 'DAVT', 501600, '7/23/2011', 'CST'

select * from Timehistory..tblTimeHistDetail_Comments where client = 'DAVT' and groupcode = 501600 and payrollperiodenddate = '7/9/2011'
and userid = 1

select * from TimeHistory..tblTimeHistDetail where client = 'DAVT' and groupcode = 501600 and payrollperiodenddate = '7/9/2011'
and ssn in(410434098,
412373992,
427417060,
427417060,
430679311,
430734848,
431698775,
431698775,
431698775,
432333891,
486809260,
509887918) and TransType = '7'
*/

/*
Void Punch Report
select fp.GroupCode, g.GroupName, en.FileNo, en.LastName, en.FirstName, fp.OldSiteNo,
fp.OldTransDate,
PunchVoided = case when fp.OldInDay = 10 then 'IN Punch' else 'OUT Punch' end,
PunchTime = case when fp.OldInDay = 10 then CONVERT(varchar(5),fp.oldOutTime,108) else CONVERT(varchar(5),fp.oldInTime,108) end
from TimeCurrent..tblFixedPunch as fp
Inner Join TimeCurrent..tblClientGroups as g
on g.Client = fp.Client
and g.GroupCode = fp.GroupCode 
Inner Join TimeCurrent..tblEmplNames as en
on en.Client = fp.Client
and en.GroupCode = fp.GroupCode
and en.SSN = fp.SSN 
where fp.Client = 'DAVT' 
and fp.GroupCode = 501600 
and fp.PayrollPeriodEndDate in('7/16/11','7/23/11')
and fp.UserID = 1

*/

--[usp_APP_VoidMissingPunches_Void_ALL] 'DAVT', 0, '11/19/11'

ALTER  PROCEDURE [dbo].[usp_APP_VoidMissingPunches_Void_ALL]
    (
      @Client CHAR(4) ,
      @GroupCode int,
      @PayrollPeriodEndDate DATETIME 
    )
AS /* Declare Local variables */
    DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 22Aug2016 >--
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
    /*Outer cursor gets list of employees in all sites for that payweek,
      reason is to avoind hittting THD without all its 4 indices
      with this cursor we can select from THD with C,G,P,SSN
    

      SELECT  Distinct SN.GroupCode ,
              sn.SiteNo ,
              ES.SSN
      FROM    TimeCurrent..tblSiteNames AS SN with (nolock)
      INNER JOIN TimeHistory..tblPeriodEndDates AS PED
        ON PED.Client = SN.Client
        AND PED.GroupCode = SN.GroupCode
        AND PED.PayrollPeriodenddate = @PayrollPeriodEndDate
        AND PED.Status <> 'C'
      INNER JOIN TimeHistory..tblEmplSites AS ES with (nolock)
        ON es.Client = SN.Client 
         AND es.GroupCode = SN.Groupcode 
         AND es.SiteNo = SN.SiteNo
         AND es.Payrollperiodenddate = @PayrollPeriodEndDate
      INNER Join TimeHistory..tblEmplNames as enh with (nolock)
        on enh.Client = es.Client
        and enh.Groupcode = es.groupcode
        and enh.payrollperiodenddate = es.payrollperiodenddate
        and enh.SSN = es.SSN
        --and isnull(enh.MissingPunch,'0') <> '0'
      Inner Join TimeHistory..tblTimeHistDetail as t with (nolock)
        on t.client = es.Client
        and t.groupcode = es.groupcode
        and t.Payrollperiodenddate = @PayrollPeriodEndDate
        and t.ssn = es.SSN
        and t.siteno = es.siteno
        and (t.Inday = 10 or t.outday = 10)
      Where SN.Client = @Client
*/
    
    DECLARE outerCursor CURSOR STATIC
    FOR
        SELECT  Distinct SN.GroupCode ,
                sn.SiteNo ,
                ES.SSN
        FROM    TimeCurrent..tblSiteNames AS SN with (nolock)
        INNER JOIN TimeHistory..tblPeriodEndDates AS PED
          ON PED.Client = SN.Client
          AND PED.GroupCode = SN.GroupCode
          AND PED.PayrollPeriodenddate = @PayrollPeriodEndDate
          AND PED.Status <> 'C'
        INNER JOIN TimeHistory..tblEmplSites AS ES with (nolock)
          ON es.Client = SN.Client 
           AND es.GroupCode = SN.Groupcode 
           AND es.SiteNo = SN.SiteNo
           AND es.Payrollperiodenddate = @PayrollPeriodEndDate
        INNER Join TimeHistory..tblEmplNames as enh with (nolock)
          on enh.Client = es.Client
          and enh.Groupcode = es.groupcode
          and enh.payrollperiodenddate = es.payrollperiodenddate
          and enh.SSN = es.SSN
          --and isnull(enh.MissingPunch,'0') <> '0'
        Inner Join TimeHistory..tblTimeHistDetail as t with (nolock)
          on t.client = es.Client
          and t.groupcode = es.groupcode
          and t.Payrollperiodenddate = @PayrollPeriodEndDate
          and t.ssn = es.SSN
          and t.siteno = es.siteno
          and (t.Inday = 10 or t.outday = 10)
        Where SN.Client = @Client
--        and SN.GroupCOde = @GroupCode
        --and SN.TimeZone = @TimeZone
        
    OPEN outerCursor   
    FETCH NEXT FROM outerCursor INTO @Groupcode, @SiteNo, @SSN
    	
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
                INNER JOIN TimeHistory..tblEmplNames AS EN
                ON      THTD.Client = EN.Client
                        AND THTD.GroupCode = EN.GroupCode
                        AND THTD.SSN = EN.SSN
                        AND THTD.PayrollPeriodEndDate = EN.PayrollPeriodEndDate
                        AND EN.MissingPunch = '1'
                WHERE   THTD.Client = @Client
                        AND THTD.GroupCode = @GroupCode
                        AND THTD.SiteNo = @SiteNo
                        AND THTD.SSN = @SSN
                        AND THTD.PayrollPeriodEndDate = @PayrollPeriodEndDate
                        AND (THTD.InDay = 10 OR THTD.OutDay = 10)
	
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
                        AND @InDay = 10 
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
                        AND @OutDay = 10 
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
    	
            FETCH NEXT FROM outerCursor INTO @groupcode, @SiteNo, @SSN
        END   
    	
    CLOSE outerCursor   
    DEALLOCATE outerCursor
     
    --PRINT '::' + @recordIDList  
        
    IF @@ERROR <> 0 
        GOTO ERR_HANDLER    
    EXEC TimeHistory..usp_APP_VoidMissingPunches_SendFAAlert_Emailer 
        @RecordIDList ,
        'AFTER'
    
        
    ERR_HANDLER:
    IF @@TRANCOUNT > 0 
        BEGIN
            SELECT  'Unexpected error occurred!'
                    + CAST(@@ERROR AS VARCHAR(10))    
           
        END



GO
