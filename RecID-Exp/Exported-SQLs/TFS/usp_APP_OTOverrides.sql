-- Create PROCEDURE usp_APP_OTOverrides
-- Create Procedure usp_APP_OTOverrides
-- Create Procedure usp_APP_OTOverrides
-- Create Procedure usp_APP_OTOverrides
-- Create PROCEDURE usp_APP_OTOverrides
-- Create Procedure usp_APP_OTOverrides
-- =============================================
-- Author:		Sajjan Sarkar
-- Create date: 5/9/2012YouTube - Broadcast Yourself.
-- Description:	not sure
-- =============================================
Create PROCEDURE [dbo].[usp_APP_OTOverrides]
	-- Add the parameters for the stored procedure here
    (
      @Client VARCHAR(4) = '' ,  /* always make Client VARCHAR, not CHAR*/
      @Groupcode INT = 0 ,
      @PPED DATETIME ,
      @SSN INT
      /* GG - Need to pass in @SSN and respect throughout - Empl Calc is called by Client, Group, PPED, SSN*/
    )
AS 
    BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
        SET NOCOUNT ON ;
		       
        DECLARE @SiteNo INT
        DECLARE @DeptNo INT
        DECLARE @newOT NUMERIC(7, 2)
        DECLARE @newDT NUMERIC(7, 2)      
        DECLARE @reg NUMERIC(7, 2)
        DECLARE @Total NUMERIC(7, 2)
        DECLARE @TransDate DATETIME
        DECLARE @THDRecordID BIGINT  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 17Aug2016 >--
        DECLARE @newOT_ORIG NUMERIC(7, 2)
        DECLARE @newDT_ORIG NUMERIC(7, 2)              
				
				
				
     	/** Get all OT Overrides for this C,G and PPED */
        DECLARE outerCursor CURSOR READ_ONLY
        FOR
            SELECT  sa.SiteNo ,
                    sa.DeptNo ,
                    ov.OTHours ,
                    ov.DTHours ,
                    ov.TransDate
            FROM    TimeHistory.dbo.tblWTE_Timesheets AS wts
            INNER JOIN Timehistory..tblWTE_Spreadsheet_Assignments AS sa
            ON      sa.TimesheetId = wts.RecordId
            INNER JOIN TimeHistory..tblWTE_Spreadsheet_OTOverrides AS ov
            ON      ov.SpreadsheetAssignmentId = sa.RecordId
            WHERE   sa.Client = @Client
                    AND sa.GroupCode = @Groupcode
                    AND sa.SSN = @SSN
                    AND wts.TimesheetEndDate = @PPED                                                         
              
        OPEN outerCursor
		/** Loop thru all OT overrides  **/
        FETCH NEXT FROM outerCursor INTO @SiteNo, @DeptNo, @newOT, @newDT, @TransDate 
        WHILE ( @@fetch_status <> -1 ) 
            BEGIN
                IF ( @@fetch_status <> -2 ) 
                    BEGIN
                        --PRINT ''
                        --PRINT 'Processing Positives'
                        --PRINT '@TransDate: ' + CAST(@TransDate AS VARCHAR)
                        --PRINT '@SiteNo: ' + cast(@SiteNo as varchar) + ';  ' + '@DeptNo: ' + cast(@DeptNo as varchar)
                        --PRINT '@NewOT: ' + CAST(@newOT AS VARCHAR) + ';  ' + '@NewDT: ' + CAST(@newDT AS VARCHAR)                        
                        SET @newOT_ORIG = @newOT
                        SET @newDT_ORIG = @newDT
                        /**Set reg =total, DT=OT=0 in THD for that assignment and that day */
                        UPDATE  Timehistory..tblTimeHistDetail
                        SET     RegHours = Hours ,
                                OT_Hours = 0 ,
                                DT_Hours = 0,
                                RegDollars = 0,
                                OT_Dollars = 0,
                                DT_Dollars = 0,
                                RegDollars4 = 0,
                                OT_Dollars4 = 0,
                                DT_Dollars4 = 0,
                                RegBillingDollars = 0,
                                OTBillingDollars = 0,
                                DTBillingDollars = 0,                                
                                RegBillingDollars4 = 0,
                                OTBillingDollars4 = 0,
                                DTBillingDollars4=0
                        WHERE   Client = @Client
                                AND GroupCode = @Groupcode
                                AND PayrollPeriodEndDate = @PPED
                                AND SSN = @SSN
                                AND SiteNo = @SiteNo
                                AND DeptNo = @DeptNo
                                AND TransDate = @TransDate                                
                        /**For each row, get all rows  in THD for that assignment and that day*/ 
                                
-----------------   POSITIVES                                
                        DECLARE innerCursor CURSOR READ_ONLY
                        FOR
                            SELECT  RecordID , -- used for updates
                                    Hours ,
                                    RegHours
                            FROM    TimeHistory..tblTimeHistDetail AS TTHD
                            WHERE   Client = @Client
                                    AND GroupCode = @Groupcode
                                    AND PayrollPeriodEndDate = @PPED
                                    AND SSN = @SSN
                                    AND SiteNo = @SiteNo
                                    AND DeptNo = @DeptNo
                                    AND TransDate = @TransDate
                                    AND Hours >= 0
                            /* GG - Need to order by in punch descending.  You have to sort OT and DT to end of day, regardless of number of transactions*/
                            ORDER BY InTime DESC -- ordering this way allows us to attempt to affect minimum no of rows
                        OPEN innerCursor
                        
                        FETCH NEXT FROM innerCursor INTO @THDRecordID, @Total, @reg
                        WHILE ( @@fetch_status <> -1 ) 
                            BEGIN
                                IF ( @@fetch_status <> -2 ) 
                                    BEGIN
										/** If over-ride amount is less than total hours ,
											update DT and Reg in THD with new values
										*/
										                    --PRINT '@THDRecordID: ' + CAST(@THDRecordID AS varchar)
										                    --PRINT '@Total: ' + CAST(@Total AS varchar)
										                    --PRINT '@reg: ' + CAST(@reg AS varchar)
										                    --PRINT 'IF ' + CAST(@newDT AS VARCHAR) + ' <= ' + CAST(@Total AS VARCHAR)
                                        IF @newDT <= @Total 
                                            BEGIN
                                                --PRINT 'updating DT 1'
                                                UPDATE  TimeHistory..tblTimeHistDetail
                                                SET     DT_Hours = @newDT ,
                                                        RegHours = @Total - @newDT  /*GG - I think you mean't RegHours here*/
                                                WHERE   RecordID = @THDRecordID
                                       		
                                                SET @reg = @Total - @newDT
                                                SET @newDT = 0 -- this is used after the OT block
                                            END
                                        ELSE 
                                        /** If over-ride amount is less than total hours ,
											top up DT and reset newDT with remainder and set Reg=0 as
											there aren't any more hours left
											in THD with new values
										*/ 
                                            BEGIN
                                              --PRINT 'updating DT 2'
                                                UPDATE  TimeHistory..tblTimeHistDetail
                                                SET     DT_Hours = @Total ,
                                                        RegHours = 0
                                                WHERE   RecordID = @THDRecordID
                                       			/**Will be used in next loop of inner cursor, in another THD row*/
                                                SET @newDT = @newDT - @Total
                                                SET @reg = 0
                                            END
                                    END 
                                 /** If over-ride amount is less than total hours ,
											update OT and Reg in THD with new values											
											@reg is used as it would have the latest value after the DT block.
										*/   										
                                IF @newOT <= @reg 
                                    BEGIN
                                        --PRINT 'updating OT 1'
                                        UPDATE  TimeHistory..tblTimeHistDetail
                                        SET     OT_Hours = @newOT ,
                                                RegHours = @reg - @newOT
                                        WHERE   RecordID = @THDRecordID
                                        
                                        SET @newOT = 0
                                    END
                                ELSE 
                                    BEGIN
                                    /** If over-ride amount is less than total hours ,
											top up OT and reset newOT with remainder and set Reg=0 as
											there aren't any more hours left
											in THD with new values
										*/
										                    --PRINT 'updating OT 2'
                                        UPDATE  TimeHistory..tblTimeHistDetail
                                        SET     OT_Hours = @reg ,
                                                RegHours = 0   /* GG - RegHours  */
                                        WHERE   RecordID = @THDRecordID
                                        
                                        SET @newOT = @newOT - @reg
                                    END
                                    
                                --PRINT '@NewOT: ' + CAST(@NewOT AS VARCHAR)
                                --PRINT '@NewDT: ' + CAST(@newDT AS VARCHAR)
                                IF @newOT = 0
                                    AND @newDT = 0  /**Else will be handled in next loop*/ 
                                    BEGIN
                                        BREAK
                                    END
                                  
                                FETCH NEXT FROM innerCursor INTO @THDRecordID, @Total, @reg
                            END--WHILE (@@fetch_status <> -1)                   
                                    
                        CLOSE innerCursor
                        DEALLOCATE innerCursor
                        
-----------------   NEGATIVES         
                        --PRINT ''
                        --PRINT 'Processing Negatives'
                        SET @newOT = @newOT_ORIG
                        SET @newDT = @newDT_ORIG
                        --PRINT '@TransDate: ' + CAST(@TransDate AS VARCHAR)
                        --PRINT '@SiteNo: ' + cast(@SiteNo as varchar) + ';  ' + '@DeptNo: ' + cast(@DeptNo as varchar)
                        --PRINT '@NewOT: ' + CAST(@newOT AS VARCHAR) + ';  ' + '@NewDT: ' + CAST(@newDT AS VARCHAR)                          
                        --PRINT '@NewOT: ' + CAST(@NewOT AS VARCHAR)
                        --PRINT '@NewDT: ' + CAST(@newDT AS VARCHAR)                        
                        
                        DECLARE innerCursor CURSOR READ_ONLY
                        FOR
                            SELECT  RecordID , -- used for updates
                                    Hours ,
                                    RegHours
                            FROM    TimeHistory..tblTimeHistDetail AS TTHD
                            WHERE   Client = @Client
                                    AND GroupCode = @Groupcode
                                    AND PayrollPeriodEndDate = @PPED
                                    AND SSN = @SSN
                                    AND SiteNo = @SiteNo
                                    AND DeptNo = @DeptNo
                                    AND TransDate = @TransDate
                                    AND Hours < 0
                            /* GG - Need to order by in punch descending.  You have to sort OT and DT to end of day, regardless of number of transactions*/
                            ORDER BY InTime DESC -- ordering this way allows us to attempt to affect minimum no of rows
                        OPEN innerCursor
                        
                        FETCH NEXT FROM innerCursor INTO @THDRecordID, @Total, @reg
                        WHILE ( @@fetch_status <> -1 ) 
                            BEGIN
                                IF ( @@fetch_status <> -2 ) 
                                    BEGIN
										/** If over-ride amount is less than total hours ,
											update DT and Reg in THD with new values
										*/
										                    --PRINT '@THDRecordID: ' + CAST(@THDRecordID AS varchar)
										                    --PRINT 'IF ABS(' + CAST(@newDT AS VARCHAR) + ') <= ' + CAST(@Total AS VARCHAR)
                                        IF @newDT <= @Total * -1
                                            BEGIN
                                                --PRINT 'updating DT 1'
                                                UPDATE  TimeHistory..tblTimeHistDetail
                                                SET     DT_Hours = @newDT * -1 ,
                                                        RegHours = @Total - (@newDT * -1) /*GG - I think you mean't RegHours here*/
                                                WHERE   RecordID = @THDRecordID
                                       		
                                                SET @reg = @Total - (@newDT * -1)
                                                SET @newDT = 0 -- this is used after the OT block
                                            END
                                        ELSE 
                                        /** If over-ride amount is less than total hours ,
											top up DT and reset newDT with remainder and set Reg=0 as
											there aren't any more hours left
											in THD with new values
										*/ 
                                            BEGIN
                                              --PRINT 'updating DT 2'
                                                UPDATE  TimeHistory..tblTimeHistDetail
                                                SET     DT_Hours = @Total ,
                                                        RegHours = 0
                                                WHERE   RecordID = @THDRecordID
                                       			/**Will be used in next loop of inner cursor, in another THD row*/
                                                SET @newDT = @newDT - (@Total * -1)
                                                SET @reg = 0
                                            END
                                    END 
                                 /** If over-ride amount is less than total hours ,
											update OT and Reg in THD with new values											
											@reg is used as it would have the latest value after the DT block.
										*/   										
                                IF @newOT <= @reg * -1
                                    BEGIN
                                        --PRINT 'updating OT 1'
                                        UPDATE  TimeHistory..tblTimeHistDetail
                                        SET     OT_Hours = (@newOT * -1) ,
                                                RegHours = @reg - (@newOT * -1)
                                        WHERE   RecordID = @THDRecordID
                                        
                                        SET @newOT = 0
                                    END
                                ELSE 
                                    BEGIN
                                    /** If over-ride amount is less than total hours ,
											top up OT and reset newOT with remainder and set Reg=0 as
											there aren't any more hours left
											in THD with new values
										*/
										                    --PRINT 'updating OT 2'
                                        UPDATE  TimeHistory..tblTimeHistDetail
                                        SET     OT_Hours = @reg ,
                                                RegHours = 0   /* GG - RegHours  */
                                        WHERE   RecordID = @THDRecordID
                                        
                                        SET @newOT = @newOT - (@reg * -1)
                                    END
                                    
                                --PRINT '@NewOT: ' + CAST(@NewOT AS VARCHAR)
                                --PRINT '@NewDT: ' + CAST(@newDT AS VARCHAR)
                                IF @newOT = 0
                                    AND @newDT = 0  /**Else will be handled in next loop*/ 
                                    BEGIN
                                        BREAK
                                    END
                                  
                                FETCH NEXT FROM innerCursor INTO @THDRecordID, @Total, @reg
                            END--WHILE (@@fetch_status <> -1)                   
                                    
                        CLOSE innerCursor
                        DEALLOCATE innerCursor
                                                
                        /**update $s*/
                        UPDATE  TimeHistory..tblTimeHistdetail
                        SET     RegDollars = ROUND(Payrate * regHours, 2) ,
                                OT_Dollars = ROUND(( Payrate * TimeHistory.dbo.fn_GetPayRateMultiplier(Client, GroupCode, SSN, SiteNo, DeptNo, 'OT') ) * OT_Hours, 2) ,
                                DT_Dollars = ROUND(( Payrate * TimeHistory.dbo.fn_GetPayRateMultiplier(Client, GroupCode, SSN, SiteNo, DeptNo, 'DT') ) * DT_Hours, 2) ,
                                RegBillingDollars = ROUND(Billrate * regHours, 2) ,
                                OTBillingDollars = ROUND(ROUND(Billrate * TimeHistory.dbo.fn_GetBillRateMultiplier(Client, GroupCode, SSN, SiteNo, DeptNo, 'OT'), 2) * OT_Hours, 2) ,
                                DTBillingDollars = ROUND(( Billrate * TimeHistory.dbo.fn_GetBillRateMultiplier(Client, GroupCode, SSN, SiteNo, DeptNo, 'DT') ) * DT_Hours, 2) ,
                                RegDollars4 = ROUND(Payrate * regHours, 4) ,
                                OT_Dollars4 = ROUND(( Payrate * TimeHistory.dbo.fn_GetPayRateMultiplier(Client, GroupCode, SSN, SiteNo, DeptNo, 'OT') ) * OT_Hours, 4) ,
                                DT_Dollars4 = ROUND(( Payrate * TimeHistory.dbo.fn_GetPayRateMultiplier(Client, GroupCode, SSN, SiteNo, DeptNo, 'DT') ) * DT_Hours, 4) ,
                                RegBillingDollars4 = ROUND(Billrate * RegHours, 4) ,
                                OTBillingDollars4 = ROUND(ROUND(Billrate * TimeHistory.dbo.fn_GetBillRateMultiplier(Client, GroupCode, SSN, SiteNo, DeptNo, 'OT'), 2) * OT_Hours, 4) ,
                                DTBillingDollars4 = ROUND(( Billrate * 2.0 ) * DT_Hours, 4)
                        WHERE   Client = @Client
                                AND GroupCode = @groupcode
                                AND PayrollPeriodEndDate = @pped
                                AND SSN = @ssn
                                AND SiteNo = @siteno
                                AND DeptNo = @deptno
                                AND TransDate = @transdate
                        
                    END 
                FETCH NEXT FROM outerCursor INTO @SiteNo, @DeptNo, @newOT, @newDT, @TransDate 
            END--WHILE (@@fetch_status <> -1)                   
               
        CLOSE outerCursor
        DEALLOCATE outerCursor
   
       

   
    END

