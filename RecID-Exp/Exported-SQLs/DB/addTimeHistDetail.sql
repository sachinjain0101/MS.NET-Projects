CREATE PROCEDURE [dbo].[addTimeHistDetail] ( @Client varchar,   
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
