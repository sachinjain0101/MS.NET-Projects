USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_Web1_SplitPunch_VoidPunch]    Script Date: 3/31/2015 11:53:40 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_Web1_SplitPunch_VoidPunch]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_Web1_SplitPunch_VoidPunch] AS' 
END
GO




/*******************************************************************************************
	-- Purpose: stored proc to void a punch
	-- Written by: Sajjan Sarkar
	-- Module: Split Punch
	-- Tested on: SQL Server 2000
	-- Date created: 2010-09-21 09:26
	===================================================================================
	Version History:
	Date			Modifier		Change Desc
	===================================================================================
	2010-09-21		Sajjan Sarkar		Initial  version		

********************************************************************************************/
-- =============================================
-- example to execute the store procedure
-- =============================================
--exec usp_Web1_SplitPunch_VoidPunch 'DAVT', 504500, 223530801, '01/01/2011', 671847471, 25481, '10.3.0.188', 1, 'O', 'Original punch was voided as user split punches.'
ALTER  PROCEDURE [dbo].[usp_Web1_SplitPunch_VoidPunch]
    (
      @Client CHAR(4) ,
      @GroupCode INT ,
      @SSN INT = 0 ,
      @PayrollPeriodEndDate DATETIME ,
      @RecordId BIGINT ,  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 15Sept2016 >--
      @UserID INT ,
      @IPAddress VARCHAR(15) ,
      @PMAllowTxnAfterClose TINYINT ,
      @TH_PRStatus CHAR(1) ,
      @Comment VARCHAR(500)
    )
AS 
    BEGIN
        DECLARE @LogonName VARCHAR(50)
        DECLARE @FirstName VARCHAR(100)
        DECLARE @LastName VARCHAR(100)
        DECLARE @xadjhours INT
        DECLARE @tblFixedPunchRecordID BIGINT  --< @tblFixedPunchRecordID data type is changed from  INT to BIGINT by Srinsoft on 15Sept2016 >--
        
	-- select validity of record
      /*  SELECT  PayrollPeriodEndDate ,
                transDate ,
                hours ,
                dollars ,
                CASE WHEN ClockAdjustmentNo = '' THEN '1'
                     ELSE ClockAdjustmentNo
                END ClockAdjustmentNo
        FROM    TimeHistory..tblTimeHistDetail
        WHERE   RecordID = @RecordId*/
        
        -- get user details
        SELECT  @LogonName = LogonName ,
                @FirstName = FirstName ,
                @LastName = LastName
        FROM    TimeCurrent..tbluser
        WHERE   UserID = @UserID
	
	--insert tblFixedPunch entry
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
                        ShiftNo ,
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
                        UserName = @LogonName ,
                        UserID = @UserID ,
                        TransDateTime = GETDATE() ,
                        IPAddr = @IPAddress
                FROM    TimeHistory..tblTimeHistDetail
                WHERE   RecordID = @recordID
	
        SELECT  @tblFixedPunchRecordID = SCOPE_IDENTITY()
	
	-- set xAdjhrs
        IF @PMAllowTxnAfterClose = 1
            AND @TH_PRStatus = 'c' 
            SET @xadjhours = 1
        ELSE 
            SET @xadjhours = 0
            
        --update THD
        UPDATE  TimeHistory..tblTimeHistDetail
        SET     Hours = 0 ,
                TransType = '7' ,
                xadjhours = @xadjhours ,
                ShiftDiffAmt = 0
        WHERE   RecordID = @RecordId
        
        --insert comment
        INSERT  INTO TimeHistory..tblTimeHistDetail_Comments
                ( Client ,
                  GroupCode ,
                  PayrollPeriodEndDate ,
                  SSN ,
                  CreateDate ,
                  Comments ,
                  UserID ,
                  UserName
                )
        VALUES  ( @Client ,
                  @GroupCode ,
                  @PayrollPeriodEndDate ,
                  @SSN ,
                  GETDATE() ,
                  @Comment ,
                  @UserID ,
                  @FirstName + ' ' + @LastName
                )
        
        -- perform closed week processing if week is closed
        IF @PMAllowTxnAfterClose = 1
            AND @TH_PRStatus = 'c' 
            BEGIN
                EXEC TimeHistory..usp_Web1_ClosedWeekPostProcessing 
                    @client ,
                    @GroupCode ,
                    @SSN ,
                    @PayrollPeriodEndDate ,
                    @UserID
            END
      	
        SELECT  @RecordID AS THDRecordID ,
                @tblFixedPunchRecordID AS tblFixedPunchRecordID
		
    END
	





GO
