USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_APP_LSA_Calc_Baylor_Sun_Winston_Salem]    Script Date: 3/31/2015 11:53:37 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_APP_LSA_Calc_Baylor_Sun_Winston_Salem]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_APP_LSA_Calc_Baylor_Sun_Winston_Salem] AS' 
END
GO

/*
***********************************************************************************
 OWNER      :     (C) Copyright 2002 by Cignify Corporation
 PRODUCT    :     PeopleNet
 DESCRIPTION:     

  Get employees that are eligible for baylor

***********************************************************************************
 Copyright (c) Cignify Corporation, as an unpublished work first licensed in
 2002.  This program is a confidential, unpublished work of authorship created
 in 2002.  It is a trade secret which is the property of Cignify Corporation.

 All use, disclosure, and/or reproduction not specifically authorized by
 Cignify Corporation, is prohibited.  This program is protected by
 domestic and international copyright and/or trade secret laws.
 All rights reserved.

***********************************************************************************
REVISION HISTORY

DATE      INIT  Description
--------  ----  --------------------------------------------------------------------------------

***********************************************************************************
*/

--/*
ALTER     Procedure [dbo].[usp_APP_LSA_Calc_Baylor_Sun_Winston_Salem]
( 
  @Client char(4),
  @GroupCode int,
  @PPED datetime

)
AS

SET NOCOUNT ON
--*/
/*
-- DEBUG SECTION
Declare @Client char(4)
Declare @GroupCode int
Declare @PPED datetime

Select @Client = 'LSA'
Select @GroupCode = 251103
Select @PPED = '11/29/2003'

drop table #tmpRecs
*/

DECLARE @MPD datetime
DECLARE @SSN int
DECLARE @SiteNo int
DECLARE @DeptNo int
DECLARE @enStatus char(1)
DECLARE @SaveError int
DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 16Aug2016 >--
DECLARE @Threshold numeric(5,2)

Set @Threshold = 11.95

select t.SSN, t.SiteNo, t.deptNo, enStatus = e.Status, e.LastName, e.FirstName,
SunHrs = sum(case when datepart(weekday, t.TransDate) = 1 then Hours else 0 end )
into #tmpRecs
from tblTimeHistDetail as t
inner join timecurrent..tblEmplnames as e
on e.client = t.client
and e.groupcode = t.groupcode
and e.ssn = t.ssn
where t.client = @Client
and t.groupcode = @GroupCode
and t.Payrollperiodenddate = @PPED
and datepart(weekday, t.TransDate) = 1
and t.deptno in(17,24)
and t.ClockAdjustmentNo in('1','8','',' ')
group by t.ssn, t.DeptNo, t.SiteNo, e.Status, e.LastName, e.FirstName

-- =============================================
-- 
-- =============================================
DECLARE cBaylor CURSOR
READ_ONLY
FOR Select SSN, SiteNo, DeptNo, enStatus from #tmpRecs 
where SunHrs >= @Threshold

OPEN cBaylor

FETCH NEXT FROM cBaylor INTO @SSN, @SiteNo, @DeptNo, @enStatus
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
      if @DeptNo = 17
      BEGIN
        delete from tblTimeHistDetail where client = @Client
                and GroupCode = @GroupCode
                and PayrollPeriodEndDate = @PPED
                and ClockAdjustmentNo = 'G'
                and AdjustmentName = 'SD1574'
                and UserCode = 'B_P'
                and SSN = @SSN
                and InDay = 1
        delete from [TimeCurrent].[dbo].[tblAdjustments] where client = @Client
                and GroupCode = @GroupCode
                and PayrollPeriodEndDate = @PPED
                and ClockAdjustmentNo = 'G'
                and AdjustmentName = 'SD1574'
                and IPAddr = '000.000.000.000'    --Indicates system generated
                and SSN = @SSN
                and SunVal > 0
      END
      ELSE
      BEGIN
        delete from tblTimeHistDetail where client = @Client
                and GroupCode = @GroupCode
                and PayrollPeriodEndDate = @PPED
                and ClockAdjustmentNo = 'H'
                and AdjustmentName = 'SD2055'
                and UserCode = 'B_P'
                and SSN = @SSN
                and InDay = 1
        delete from [TimeCurrent].[dbo].[tblAdjustments] where client = @Client
                and GroupCode = @GroupCode
                and PayrollPeriodEndDate = @PPED
                and ClockAdjustmentNo = 'H'
                and AdjustmentName = 'SD2055'
                and IPAddr = '000.000.000.000'    --Indicates system generated
                and SSN = @SSN
                and SunVal > 0
      END

      -- Set the Master Payroll Date to 1/1/1900 since Empl Calc is going to figure it out anyway
      --
      SET @MPD = '1/1/1900'

      BEGIN TRANSACTION
        -- Insert the time detail for this employee.
      
        Insert into [TimeHistory].[dbo].[tblTimeHistDetail]
        (Client, GroupCode, SSN, PayrollPeriodEndDate, MasterPayrollDate, SiteNo, DeptNo, JobID, 
        TransDate, EmpStatus, BillRate, BillOTRate, BillOTRateOverride, PayRate, ShiftNo, InDay, 
        InTime, OutDay, OutTime, Hours, 
        Dollars, 
        TransType, AgencyNo, InSrc, OutSrc, 
        ClockAdjustmentNo, 
        AdjustmentCode, 
        AdjustmentName, 
        DaylightSavTime, Holiday, HandledByImporter, ClkTransNo, UserCode )
        Values
        (@Client, @GroupCode, @SSN, @PPED, @MPD, @SiteNo, @DeptNo, 0, 
        convert(char(10), @PPED,101), @enStatus, 0.00, 0.00, 0.00, 0.00, 1, 1, 
        '12/30/1899 00:00:00', 1, '12/30/1899 00:00:00', 0.00, 
        CASE WHEN @DeptNo = 17 THEN 15.74 ELSE 20.55 END, 
        '1', 0, '3', '3', 
        CASE WHEN @DeptNo = 17 THEN 'G' ELSE 'H' END, 
        '', 
        CASE WHEN @DeptNo = 17 THEN 'SD1574' ELSE 'SD2055' END, 
        '0', '0', '', 847105, 'B_P')
      
        if @@Error <> 0 
        begin
          Set @SaveError = @@Error
          goto RollBackTransaction
        end  
        Set @RecordID = SCOPE_IDENTITY()
      
        -- Add the adjustment to tblAdjustments for auditing purposes and for physical clocks
        -- so it will get sent back to the time clock.
        INSERT INTO [TimeCurrent].[dbo].[tblAdjustments]([ReverseFlag], [OrigRecord_No], [Client], 
              [GroupCode], [PayrollPeriodEndDate], [SSN], [SiteNo], [DeptNo], [ClockAdjustmentNo], 
              [AdjustmentCode], [AdjustmentName], [HoursDollars], 
              [MonVal], [TueVal], [WedVal], [ThuVal], [FriVal], [SatVal], [SunVal], [WeekVal], 
              [TotalVal], [AgencyNo], [UserName], [UserID], 
              [TransDateTime], [DeletedDateTime], [DeletedByUserName], [DeletedByUserID], [SweptDateTime], 
              [RecordStatus], [IPAddr], [ShiftNo])
        (Select '', RecordID, Client, GroupCode, PayrollPeriodEndDate, SSN, SiteNo, DeptNo, ClockAdjustmentNo,
              'B_P', AdjustmentName, 'D', 
              Case when InDay = 2 then Dollars else 0 end,
              Case when InDay = 3 then Dollars else 0 end,
              Case when InDay = 4 then Dollars else 0 end,
              Case when InDay = 5 then Dollars else 0 end,
              Case when InDay = 6 then Dollars else 0 end,
              Case when InDay = 7 then Dollars else 0 end,
              Case when InDay = 1 then Dollars else 0 end,
              Case when InDay < 1 or InDay > 7 then Dollars else 0 end,
              Dollars, AgencyNo, 'B_P',0,
              getdate(),null,null,0,null,
              '1','000.000.000.000',ShiftNo
        from tblTimeHistdetail
        where RecordID = @RecordID)
      
        if @@Error <> 0 
        begin
          Set @SaveError = @@Error
          goto RollBackTransaction
        end  
      
      COMMIT TRANSACTION
	END
	FETCH NEXT FROM cBaylor INTO @SSN, @SiteNo, @DeptNo, @enStatus
END

CLOSE cBaylor
DEALLOCATE cBaylor

Select Client = @Client, GroupCode = @GroupCode, PPED = @PPED, SSN, LastName, FirstName from #tmpRecs 
where SunHrs >= @Threshold

drop table #tmpRecs

return

RollBackTransaction:
Rollback Transaction

return @SaveError


















GO
