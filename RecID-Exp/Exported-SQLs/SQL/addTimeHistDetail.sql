USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[addTimeHistDetail]    Script Date: 3/31/2015 11:53:36 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[addTimeHistDetail]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[addTimeHistDetail] AS' 
END
GO
/****** Object:  Stored Procedure dbo.addTimeHistDetail    Script Date: 6/16/99 3:55:28 PM ******/
ALTER PROCEDURE [dbo].[addTimeHistDetail] ( @Client varchar,   
     @GroupCode integer,
     @SSN integer,
     @PayrollPeriodEndDate datetime,
     @MasterPayrollDate datetime,
     @SiteNo integer, 
     @DeptNo integer,
     @JobID BIGINT,  --< @JobId data type is changed from  INT to BIGINT by Srinsoft on 21Sept2016 >--
     @TransDate datetime,
     @EmpStatus integer,
     @BillRate numeric,
     @BillOTRate numeric,
     @BillOTRateOverride numeric,
     @PayRate numeric,
     @ShiftNo integer,
     @InDay integer,
     @InTime datetime,
     @OutDay integer,
     @OutTime datetime,
     @Hours numeric,
     @Dollars numeric,
     @ClockAdjustmentNo varchar(3),  --< Srinsoft 08/05/2015 Changed @ClockAdjustmentNo char to varchar(3) >--
     @AdjustmentCode varchar(3),  --< Srinsoft 09/21/2015 Changed @AdjustmentCode char to varchar(3) >--
     @AdjustmentName char)
AS
INSERT INTO tblTimeHistDetail (  Client,
     GroupCode,
                       SSN,
                       PayrollPeriodEndDate,
                       MasterPayrollDate,
                       SiteNo,
                       DeptNo,
                       JobID,
                       TransDate,
                       EmpStatus,
                       BillRate,
                       BillOTRate,
                       BillOTRateOverride,
                       PayRate,
                       ShiftNo,
                       InDay,
                       InTime,
                       OutDay,
                       OutTime,
                       Hours,
                       Dollars,
                       ClockAdjustmentNo,
                       AdjustmentCode,
                       AdjustmentName)
VALUES (    @Client,
         @GroupCode,
                       @SSN,
                       @PayrollPeriodEndDate,
                       @MasterPayrollDate,
                       @SiteNo,
                       @DeptNo,
                       @JobID,
                       @TransDate,
                       @EmpStatus,
                       @BillRate,
                       @BillOTRate,
                       @BillOTRateOverride,
                       @PayRate,
                       @ShiftNo,
                       @InDay,
                       @InTime,
                       @OutDay,
                       @OutTime,
                       @Hours,
                       @Dollars,
                       @ClockAdjustmentNo,
                       @AdjustmentCode,
                       @AdjustmentName)
GO
