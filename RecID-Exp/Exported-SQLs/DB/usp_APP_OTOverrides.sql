-- Create Procedure usp_APP_OTOverrides
-- Create Procedure usp_APP_OTOverrides
-- Create Procedure usp_APP_OTOverrides
-- Alter Procedure usp_APP_OTOverrides
-- Create Procedure usp_APP_OTOverrides
-- =============================================
-- Author:		Sajjan Sarkar
-- Create date: 5/9/2012
-- Description:	apply OTOverrides
-- Logic:
	/*
	For each day:
		td = total hrs for the day left to be allocated   ( called @TotalUnallocatedHoursForThisDay in sproc)
		dt = total DT hrs for the day left to be allocated( called @UnallocatedDTHours in sproc)
		ot = total OT hrs for the day left to be allocated( called @UnallocatedOTHours in sproc)

		if(td >0 and (dt>0 or ot>0))
		{
			for each txn in the day
			{
				tx = total hrs for the txn left to be allocated( called @TotalUnallocatedHrsForThisTxn in sproc)
				if(tx>0)
				{
					if(tx<=dt)
					{
						update THD set DT =tx,reg=0 
						dt = dt-tx
						td= td-tx
						tx = 0
					}
					else
					{
						update THD set DT = dt,reg = tx-dt
						tx = tx-dt
						td = td-dt
						dt = 0				
					}
				}
				if(tx>0)
				{
					if(tx<=ot)
					{
						update THD set OT =tx,reg=0 
						ot = ot-tx
						td= td-tx
						tx = 0
					}
					else
					{
						update THD set OT = dt,reg = tx-ot
						tx = tx-ot
						td = td-ot
						ot = 0
					}
				}
		
			}
		}
	
	*/
	
-- =============================================
CREATE PROCEDURE [dbo].[usp_APP_OTOverrides]
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
        SET NOCOUNT ON;
		       
        DECLARE @SiteNo INT
        DECLARE @DeptNo INT
        DECLARE @UnallocatedOTHours NUMERIC(7, 2)
        DECLARE @UnallocatedDTHours NUMERIC(7, 2)      
        
        DECLARE @TotalUnallocatedHrsForThisTxn NUMERIC(7, 2)
		DECLARE @TotalUnallocatedHoursForThisDay NUMERIC(7, 2)
        DECLARE @TransDate DATETIME
        DECLARE @THDRecordID INT    
        	
				
				
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
        FETCH NEXT FROM outerCursor INTO @SiteNo, @DeptNo, @UnallocatedOTHours, @UnallocatedDTHours, @TransDate 
        WHILE ( @@fetch_status <> -1 )
            BEGIN
                IF ( @@fetch_status <> -2 )
                    BEGIN
                        /*
							Move all hours from OT, DT into REG.
						*/

                        /**Set reg =total, DT=OT=0 in THD for that assignment and that day */
                        UPDATE  Timehistory..tblTimeHistDetail
                        SET     RegHours = Hours ,
                                OT_Hours = 0 ,
                                DT_Hours = 0 ,
                                RegDollars = 0 ,
                                OT_Dollars = 0 ,
                                DT_Dollars = 0 ,
                                RegDollars4 = 0 ,
                                OT_Dollars4 = 0 ,
                                DT_Dollars4 = 0 ,
                                RegBillingDollars = 0 ,
                                OTBillingDollars = 0 ,
                                DTBillingDollars = 0 ,
                                RegBillingDollars4 = 0 ,
                                OTBillingDollars4 = 0 ,
                                DTBillingDollars4 = 0
                        WHERE   Client = @Client
                                AND GroupCode = @Groupcode
                                AND PayrollPeriodEndDate = @PPED
                                AND SSN = @SSN
                                AND SiteNo = @SiteNo
                                AND DeptNo = @DeptNo
                                AND TransDate = @TransDate                                

						-- get sumarized hours for this day
                        SELECT  @TotalUnallocatedHoursForThisDay = SUM([THD].[Hours])
                        FROM    [TimeHistory]..[tblTimeHistDetail] AS THD WITH ( NOLOCK )
                        WHERE   Client = @Client
                                AND GroupCode = @Groupcode
                                AND PayrollPeriodEndDate = @PPED
                                AND SSN = @SSN
                                AND SiteNo = @SiteNo
                                AND DeptNo = @DeptNo
                                AND TransDate = @TransDate   
						/*
							Only process txns if :
								- there are +ve hours in the timecard
								- OT or DT allocation is specified
						*/
                        IF @TotalUnallocatedHoursForThisDay > 0
                            AND ( @UnallocatedDTHours <> 0
                                  OR @UnallocatedOTHours <> 0
                                )
                            BEGIN
                            	 /**
									For each row, get all rows  in THD :
										- for that assignment
										- that day
										- with +ve hours
								*/ 
                             
                                DECLARE perTxnCursor CURSOR READ_ONLY
                                FOR
                                    SELECT  RecordID , -- used for updates
                                            Hours
                                    FROM    TimeHistory..tblTimeHistDetail AS TTHD WITH ( NOLOCK )
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
                                OPEN perTxnCursor
                        
                                FETCH NEXT FROM perTxnCursor INTO @THDRecordID, @TotalUnallocatedHrsForThisTxn
                                WHILE ( @@fetch_status <> -1 )
                                    BEGIN
                                        IF ( @@fetch_status <> -2 )
                                            BEGIN
                                                PRINT 'Processing record ID:' + CAST(@THDRecordID AS VARCHAR)
									
										/**********************************************************************************************************
															PROCESSING DT ALLOCATION
										***********************************************************************************************************/										
                                                IF @TotalUnallocatedHrsForThisTxn > 0 -- there are unallocated hours
                                                    BEGIN
														/*
															if all available hours for the txn can be allocated to DT, do it.
														*/
                                                        IF ( @TotalUnallocatedHrsForThisTxn <= @UnallocatedDTHours )
                                                            BEGIN
                                                                UPDATE  [TimeHistory]..[tblTimeHistDetail]
                                                                SET     [DT_Hours] = @TotalUnallocatedHrsForThisTxn ,
                                                                        [RegHours] = 0 -- nothing left 
                                                                WHERE   [tblTimeHistDetail].[RecordID] = @THDRecordID

											
                                                                SET @UnallocatedDTHours = @UnallocatedDTHours - @TotalUnallocatedHrsForThisTxn -- new value is old - hrs we just allocated                                                
                                                                SET @TotalUnallocatedHoursForThisDay = @TotalUnallocatedHoursForThisDay
                                                                    - @TotalUnallocatedHrsForThisTxn  -- reduce no of unallocated hours
                                                                SET @TotalUnallocatedHrsForThisTxn = 0 -- since all have been allocated to DT
                                                            END
                                                        ELSE --@TotalUnallocatedHrsForThisTxn > @UnallocatedDTHours
                                                            BEGIN
												/*
													We have more hours than what the DT needs, so 
													use up the whole DT override.
												*/
                                                                UPDATE  [TimeHistory]..[tblTimeHistDetail]
                                                                SET     [DT_Hours] = @UnallocatedDTHours ,
                                                                        [RegHours] = @TotalUnallocatedHrsForThisTxn - @UnallocatedDTHours-- everything else goes to reg
                                                                WHERE   [tblTimeHistDetail].[RecordID] = @THDRecordID

                                                                SET @TotalUnallocatedHrsForThisTxn = @TotalUnallocatedHrsForThisTxn - @UnallocatedDTHours -- deduct the newly allocated DT hrs
                                                                SET @TotalUnallocatedHoursForThisDay = @TotalUnallocatedHoursForThisDay - @UnallocatedDTHours-- deduct the newly allocated DT hrs from this day total
                                                                SET @UnallocatedDTHours = 0 -- no other DT allocation needs to happen for this day
												

                                                            END
                                                    END
                                        
										/**********************************************************************************************************
															PROCESSING OT ALLOCATION
										***********************************************************************************************************/
										
                                                IF @TotalUnallocatedHrsForThisTxn > 0-- there are unallocated hours
                                                    BEGIN
												/*
													if all available hours for the txn can be allocated to DT, do it.
												*/
                                                        IF ( @TotalUnallocatedHrsForThisTxn <= @UnallocatedOTHours )
                                                            BEGIN
                                                                UPDATE  [TimeHistory]..[tblTimeHistDetail]
                                                                SET     [OT_Hours] = @TotalUnallocatedHrsForThisTxn ,
                                                                        [RegHours] = 0
                                                                WHERE   [tblTimeHistDetail].[RecordID] = @THDRecordID

											
                                                                SET @UnallocatedOTHours = @UnallocatedOTHours - @TotalUnallocatedHrsForThisTxn -- new value is old - hrs we just allocated                                                
                                                                SET @TotalUnallocatedHoursForThisDay = @TotalUnallocatedHoursForThisDay
                                                                    - @TotalUnallocatedHrsForThisTxn  -- reduce no of unallocated hours
                                                                SET @TotalUnallocatedHrsForThisTxn = 0 -- since all have been allocated to OT
                                                            END
                                                        ELSE --@TotalUnallocatedHrsForThisTxn > @UnallocatedOTHours
                                                            BEGIN
												/*
													We have more hours than what the DT needs, so 
													use up the whole DT override.
												*/
                                                                UPDATE  [TimeHistory]..[tblTimeHistDetail]
                                                                SET     [OT_Hours] = @UnallocatedOTHours ,
                                                                        [RegHours] = @TotalUnallocatedHrsForThisTxn - @UnallocatedOTHours-- everything else goes to reg
                                                                WHERE   [tblTimeHistDetail].[RecordID] = @THDRecordID

                                                                SET @TotalUnallocatedHrsForThisTxn = @TotalUnallocatedHrsForThisTxn - @UnallocatedOTHours -- deduct the newly allocated OT hrs
                                                                SET @TotalUnallocatedHoursForThisDay = @TotalUnallocatedHoursForThisDay - @UnallocatedOTHours-- deduct the newly allocated OT hrs from this day total
                                                                SET @UnallocatedOTHours = 0 -- no other OT allocation needs to happen for this day
												

                                                            END
                                                    END
                                        


                                            END
                                  
                                        FETCH NEXT FROM perTxnCursor INTO @THDRecordID, @TotalUnallocatedHrsForThisTxn
                                    END--WHILE (@@fetch_status <> -1)                   
                                    
                                CLOSE perTxnCursor
                                DEALLOCATE perTxnCursor
                            END     

                       
                        

                        
                        /**update $s*/
                        UPDATE  TimeHistory..tblTimeHistdetail
                        SET     RegDollars = ROUND(Payrate * regHours, 2) ,
                                OT_Dollars = ROUND(( Payrate * TimeHistory.dbo.fn_GetPayRateMultiplier(Client, GroupCode, SSN, SiteNo, DeptNo, 'OT') )
                                                   * OT_Hours, 2) ,
                                DT_Dollars = ROUND(( Payrate * TimeHistory.dbo.fn_GetPayRateMultiplier(Client, GroupCode, SSN, SiteNo, DeptNo, 'DT') )
                                                   * DT_Hours, 2) ,
                                RegBillingDollars = ROUND(Billrate * regHours, 2) ,
                                OTBillingDollars = ROUND(ROUND(Billrate * TimeHistory.dbo.fn_GetBillRateMultiplier(Client, GroupCode, SSN, SiteNo, DeptNo, 'OT'),
                                                               2) * OT_Hours, 2) ,
                                DTBillingDollars = ROUND(( Billrate * TimeHistory.dbo.fn_GetBillRateMultiplier(Client, GroupCode, SSN, SiteNo, DeptNo, 'DT') )
                                                         * DT_Hours, 2) ,
                                RegDollars4 = ROUND(Payrate * regHours, 4) ,
                                OT_Dollars4 = ROUND(( Payrate * TimeHistory.dbo.fn_GetPayRateMultiplier(Client, GroupCode, SSN, SiteNo, DeptNo, 'OT') )
                                                    * OT_Hours, 4) ,
                                DT_Dollars4 = ROUND(( Payrate * TimeHistory.dbo.fn_GetPayRateMultiplier(Client, GroupCode, SSN, SiteNo, DeptNo, 'DT') )
                                                    * DT_Hours, 4) ,
                                RegBillingDollars4 = ROUND(Billrate * RegHours, 4) ,
                                OTBillingDollars4 = ROUND(ROUND(Billrate * TimeHistory.dbo.fn_GetBillRateMultiplier(Client, GroupCode, SSN, SiteNo, DeptNo, 'OT'),
                                                                2) * OT_Hours, 4) ,
                                DTBillingDollars4 = ROUND(( Billrate * 2.0 ) * DT_Hours, 4)
                        WHERE   Client = @Client
                                AND GroupCode = @groupcode
                                AND PayrollPeriodEndDate = @pped
                                AND SSN = @ssn
                                AND SiteNo = @siteno
                                AND DeptNo = @deptno
                                AND TransDate = @transdate
                        
                    END 
                FETCH NEXT FROM outerCursor INTO @SiteNo, @DeptNo, @UnallocatedOTHours, @UnallocatedDTHours, @TransDate 
            END--WHILE (@@fetch_status <> -1)                   
               
        CLOSE outerCursor
        DEALLOCATE outerCursor
   
       

   
    END

