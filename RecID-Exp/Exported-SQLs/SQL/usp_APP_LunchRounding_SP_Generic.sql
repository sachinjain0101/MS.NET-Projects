USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_APP_LunchRounding_SP_Generic]    Script Date: 3/31/2015 11:53:37 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_APP_LunchRounding_SP_Generic]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_APP_LunchRounding_SP_Generic] AS' 
END
GO

/*SELECT * FROM TimeCurrent..tblPayRules AS TPR WHERE  RecordID=14116 */

/*
Lunch Policy

The employees will be punching for lunch but are ONLY to be unpaid for 30 minutes. 
They are combining an extra paid break with their lunch to equal 45 minutes but are to be paid for the additional 15 minutes.
Please program the pay rule as follows:
If the employee punches for 45 minutes - please ADD 15 minutes back in to their paid time.
If the employee punches for 46 minutes or more - please ONLY ADD 15 minutes back in.
If the employee punches for anything less than 45 minutes - please only add the time in addition to 30 minutes.
If the employee punches for less than 30 - please record actual time employee took.

*/
-- exec usp_APP_OLST_LunchRounding_SP_Generic 'OLST',883900,'5/9/2010',4315

--exec usp_APP_OLST_LunchRounding_SP_Generic 0,0,30,0.25,1,90, 'OLST',883900,'4/18/2010',4315
-- exec usp_APP_OLST_LunchRounding_SP_Generic 0,0,30,0.25,1,90, 'OLST',883900,'3/14/2010',4315
-- exec usp_APP_OLST_LunchRounding_SP_Generic 0,0,30,0.25,1,90,0, 'OLST',883900,'3/14/2010',4315
-- exec usp_APP_OLST_LunchRounding_SP_Generic 0,0,30,0.25,1,90,0, 'OLST',883900,'6/20/2010',4315
-- exec usp_APP_OLST_LunchRounding_SP_Generic 0,0,30,0.25,1,90,0, 'OLST',883900,'6/13/2010',4315

ALTER PROCEDURE [dbo].[usp_APP_LunchRounding_SP_Generic]
    (
      @AddlLunchMin INT , -- 0
      @AddlLunchDec NUMERIC(5, 2) , --0
      @CreditLunchMin INT , -- 30
      @CreditLunchAmtDec NUMERIC(5, 2) , -- 0.25
      @LunchPunchMin INT ,  -- 1
      @LunchPunchMax INT ,  -- 90
      @MinHoursPerDay NUMERIC(7, 2) ,--0
      @Client VARCHAR(4) ,
      @GroupCode INT ,
      @PPED DATETIME ,
      @SSN INT
    )
AS 
    SET NOCOUNT ON

    SET NOCOUNT ON

    DECLARE @OutTime DATETIME
    DECLARE @iOutTime DATETIME
    DECLARE @InTime DATETIME
    DECLARE @NewInTime DATETIME
    DECLARE @NewInDay INT
    DECLARE @TransDate DATETIME
    DECLARE @Minutes NUMERIC(7, 2)
    DECLARE @MPD DATETIME
    DECLARE @RecordID INT
    DECLARE @oRecordID BIGINT  --< @oRecordId data type is changed from  INT to BIGINT by Srinsoft on 16Aug2016 >--
    DECLARE @iRecordID BIGINT  --< @iRecordId data type is changed from  INT to BIGINT by Srinsoft on 16Aug2016 >--
    DECLARE @SiteNo INT
    DECLARE @DeptNo INT
    DECLARE @TotHours NUMERIC(9, 2)
    DECLARE @MinLunchMinutes INT 
    DECLARE @MaxLunchMinutes INT 
--DECLARE @MinHoursPerDay NUMERIC(7,2)
    DECLARE @PaidMinutes INT 
    DECLARE @DailyHours NUMERIC(7, 2)
    DECLARE @PPSD DATETIME
    DECLARE @ClientID VARCHAR(50)
    DECLARE @WorkSiteID VARCHAR(50)
    DECLARE @PaidLunchStatus INT 

    SELECT  @PPSD = DATEADD(dd, -6, @PPED)


	
    DELETE  FROM TimeHistory..tblTimeHistDetail
    WHERE   Client = @Client
            AND GroupCode = @GroupCode
            AND SSN = @SSN
            AND ClockAdjustmentNo = '8'
            AND AdjustmentName = 'PD_LUNCH'
            AND UserCode = 'SYS'
            AND PayrollPeriodEndDate = @PPED

----------------

--RETURN
----------

    DECLARE cPunch CURSOR READ_ONLY FOR 
    SELECT 	o.ActualOutTime, 
    o.RecordID, 
    i.ActualInTime, 
    i.OutTime, 
    i.SiteNo, 
    i.DeptNo, 
    i.RecordID, 
    i.TransDate, 
    i.MasterPayrollDate,
    DiffInMinutes = DATEDIFF(minute, dbo.PunchDateTime2(o.TransDate, o.OutDay, o.OutTime), dbo.PunchDateTime2(i.TransDate, i.InDay, i.InTime)),
    (SELECT SUM(thd.Hours)
    FROM TimeHistory.dbo.tblTimeHistDetail thd
    WHERE thd.Client = o.Client
    AND thd.GroupCode = o.GroupCode
    AND thd.SSN = o.SSN
    AND thd.PayrollPeriodEndDate = o.PayrollPeriodEndDate
    AND thd.TransDate = o.TransDate) AS DailyHours--,
					
    FROM TimeHistory..tblTimeHistDetail AS o		
    INNER JOIN TimeHistory..tblTimeHistDetail AS i
    ON i.Client = o.Client

    AND i.Groupcode = o.GroupCode
    AND i.PayrollPeriodEndDate = o.PayrollPeriodEndDate
    AND i.SSN = o.SSN
    WHERE o.Client = @Client
    AND o.Groupcode = @GroupCode
    AND o.Payrollperiodenddate = @PPED
    AND o.SSN = @SSN
    AND o.OutDay NOT IN (10, 11)
    AND i.INDay NOT IN (10, 11)
    AND i.ClockAdjustmentNo IN ('', ' ')
    AND o.ClockAdjustmentNo IN ('', ' ')
    AND o.Hours > 0
    AND i.Hours > 0
	
	
    OPEN cPunch
	
    FETCH NEXT FROM cPunch INTO @OutTime, @oRecordID, @InTime, @iOutTime, @SiteNo, @Deptno, @iRecordID, @TransDate, @MPD, @Minutes, @DailyHours--, @ClientID, @WorkSiteID
    WHILE ( @@fetch_status <> -1 ) 
        BEGIN
            IF ( @@fetch_status <> -2 ) 
                BEGIN
                    IF ( @DailyHours > @MinHoursPerDay ) 
                        BEGIN

			
	
                            SET @MinLunchMinutes = @LunchPunchMin
                            SET @MaxLunchMinutes = @LunchPunchMax
                            SET @PaidMinutes = @CreditLunchAmtDec * 60
				
                            IF ( @Minutes BETWEEN @MinLunchMinutes
                                          AND     @MaxLunchMinutes ) 
                                BEGIN
                                    IF ( @Minutes - @CreditLunchMin > @PaidMinutes ) 
                                        BEGIN
                                            SET @Minutes = @PaidMinutes
                                        END
                                    ELSE 
                                        BEGIN
                                            SET @Minutes = @Minutes
                                                - @CreditLunchMin
						
                                            IF @Minutes <= 0 
                                                BEGIN
                                                    CONTINUE							
                                                END
                                        END
                                    SELECT  @TotHours = @Minutes / 60
					
					
					
			
                                    EXEC TimeHistory.dbo.usp_APP_XLSImport_Adjustment_Insert_THD 
                                        @Client ,
                                        @GroupCode ,
                                        @PPED ,
                                        @SSN ,
                                        @SiteNo ,
                                        @DeptNo ,
                                        '8' ,
                                        'PD_LUNCH' ,
                                        @TotHours ,
                                        0 ,
                                        @TransDate ,
                                        @MPD ,
                                        'SYS'
					
                                END
                        END
                END
            FETCH NEXT FROM cPunch INTO @OutTime, @oRecordID, @InTime, @iOutTime, @SiteNo, @Deptno, @iRecordID, @TransDate, @MPD, @Minutes, @DailyHours--, @ClientID, @WorkSiteID
        END
	
    CLOSE cPunch
    DEALLOCATE cPunch



    UPDATE TimeHistory..tblTimeHistDetail
    SET TimeHistory..tblTimeHistDetail.ShiftNo = thd2.ShiftNo
    FROM TimeHistory..tblTimeHistDetail
    INNER Join TimeHistory..tblTimeHistDetail thd2
    ON TimeHistory..tblTimeHistDetail.Client = thd2.Client
    AND TimeHistory..tblTimeHistDetail.GroupCode = thd2.GroupCode
    AND TimeHistory..tblTimeHistDetail.SSN = thd2.SSN
    AND TimeHistory..tblTimeHistDetail.TransDate = thd2.TransDate
    AND TimeHistory..tblTimeHistDetail.AdjustmentName = 'PD_LUNCH'
    AND thd2.AdjustmentName <> 'PD_LUNCH'
    WHERE TimeHistory..tblTimeHistDetail.Client = @Client
    AND TimeHistory..tblTimeHistDetail.GroupCode = @GroupCode
    AND TimeHistory..tblTimeHistDetail.SSN = @SSN
    AND TimeHistory..tblTimeHistDetail.PayrollPeriodEndDate = @PPED
    AND thd2.ShiftNo NOT IN (0,1)






GO
