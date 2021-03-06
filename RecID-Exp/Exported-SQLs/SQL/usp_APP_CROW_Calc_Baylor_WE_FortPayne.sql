USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_APP_CROW_Calc_Baylor_WE_FortPayne]    Script Date: 3/31/2015 11:53:36 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_APP_CROW_Calc_Baylor_WE_FortPayne]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_APP_CROW_Calc_Baylor_WE_FortPayne] AS' 
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


Crowne wants to add Baylor Pay for the Ft Payne location. 
The Baylor allows employees working 12 hours as RN, CNA, and LPN on both Saturday and Sunday to receive 
an extra 6 hours of Baylor. 
They would like this to post as 3 hours Baylor on Saturday 
and 3 hours of Baylor on Sunday. 
If the employee works less than 12 hours on either day they are not eligible for Baylor. 
This is similar to the Baylor running at the Eufala location. 
Oncew you let me know you've completed the programming I will setup Baylor departments for the RN, CNA, and LPN. 
These will be setup as departments 71,72, and 74. If you need the depts setup inorder to do your programming let me know. 

***********************************************************************************
*/


--/*
ALTER  Procedure [dbo].[usp_APP_CROW_Calc_Baylor_WE_FortPayne]
( 
  @Client char(4),
  @GroupCode int,
  @PPED datetime

)
AS

SET NOCOUNT ON
--*/

DECLARE @MPD datetime
DECLARE @SSN int
DECLARE @SiteNo int
DECLARE @DeptNo int
DECLARE @enStatus char(1)
DECLARE @SaveError int
DECLARE @RecordID BIGINT  --< @RecordID data type is converted from INT to BIGINT by Srinsoft on 29July2016 >--
DECLARE @TransDate datetime
DECLARE @BaylorHours numeric(7,2)
DECLARE @DOW int

select t.ssn, 
t.TransDate,
DailyHours = sum(Hours),
TotalHours = cast(0.00 as numeric(7,2)),
DeptNo = 0
into #tmpRecs
from TimeHistory..tblTimeHistDetail as t
where t.client = @Client
and t.groupcode = @GroupCode
and t.Payrollperiodenddate = @PPED
and datepart(weekday, t.TransDate) in(1,7)
and t.deptno in(71,72,74)
and isnull(t.ClockAdjustmentNo,'') in(' ','','8','1')
group by t.ssn, t.TransDate

delete from #tmpRecs where DailyHours < 12.0

update #tmpRecs
  Set TotalHours = (Select Sum(t.DailyHours) from #tmpRecs as t where t.ssn = #tmpRecs.SSN)

delete from #tmpRecs where TotalHours < 24.0

-- =============================================
-- Process each Baylor Record and add to tblTimeHistDetail and tblADjustments.
-- =============================================
DECLARE cBaylor CURSOR
READ_ONLY
FOR 
Select t.SSN, t.TransDate, en.PrimarySite, en.Status, DOW = datepart(weekday,t.TransDate)
from #tmpRecs as t 
Inner join TimeCurrent..tblEmplNames as en
on en.client = @Client
and en.groupcode = @Groupcode
and en.SSN = t.SSN
order by t.SSN, datepart(weekday,t.TransDate)


OPEN cBaylor

FETCH NEXT FROM cBaylor INTO @SSN, @TransDate, @SiteNo, @enStatus, @DOW
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
      IF @DOW = 1
      BEGIN
        delete from tblTimeHistDetail where client = @Client
                  and GroupCode = @GroupCode
                  and PayrollPeriodEndDate = @PPED
                  and ClockAdjustmentNo = 'Y'
                  and AdjustmentName = 'BAYLOR'
                  and ClkTransNo = 847105      --Indicates system generated
                  and SSN = @SSN
  
        delete from [TimeCurrent].[dbo].[tblAdjustments] where client = @Client
                  and GroupCode = @GroupCode
                  and PayrollPeriodEndDate = @PPED
                  and ClockAdjustmentNo = 'Y'
                  and AdjustmentName = 'BAYLOR'
                  and IPAddr = '000.000.000.000'    --Indicates system generated
                  and SSN = @SSN
      END
  
      Set @DeptNo = (select top 1 Deptno from TimeHistory..tblTimeHistDetail 
                        where client = @Client 
                        and groupcode = @Groupcode 
                        and payrollperiodenddate = @PPED 
                        and SSN = @SSN
                        and TransDate = @TransDate
                        and DeptNo IN(71,72,74)
                        order by Hours Desc )
 
      -- Set the Master Payroll Date to 1/1/1900 since Empl Calc is going to figure it out anyway
      --
      SET @MPD = '1/1/1900'

      BEGIN TRANSACTION
        -- Insert the time detail for this employee.
      
        Insert into [TimeHistory].[dbo].[tblTimeHistDetail]
        (Client, GroupCode, SSN, PayrollPeriodEndDate, MasterPayrollDate, SiteNo, DeptNo, JobID, 
        TransDate, EmpStatus, BillRate, BillOTRate, BillOTRateOverride, PayRate, ShiftNo, InDay, 
        InTime, OutDay, OutTime, Hours, Dollars, TransType, AgencyNo, InSrc, OutSrc, ClockAdjustmentNo, 
        AdjustmentCode, AdjustmentName, DaylightSavTime, Holiday, HandledByImporter, ClkTransNo, UserCode )
        Values
        (@Client, @GroupCode, @SSN, @PPED, @MPD, @SiteNo, @DeptNo, 0, 
        @TransDate, @enStatus, 0.00, 0.00, 0.00, 0.00, 1, datepart(weekday,@TransDate), 
        '12/30/1899 00:00:00', datepart(weekday,@TransDate), '12/30/1899 00:00:00', 3.00, 0.00, '1', 0, '3', '3', 'Y', 
        '', 'BAYLOR', '0', '0', '', 847105, 'B_P')
      
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
              [AdjustmentCode], [AdjustmentName], [HoursDollars], [MonVal], [TueVal], [WedVal], [ThuVal], 
              [FriVal], [SatVal], [SunVal], [WeekVal], [TotalVal], [AgencyNo], [UserName], [UserID], 
              [TransDateTime], [DeletedDateTime], [DeletedByUserName], [DeletedByUserID], [SweptDateTime], 
              [RecordStatus], [IPAddr], [ShiftNo])
        (Select '', RecordID, Client, GroupCode, PayrollPeriodEndDate, SSN, SiteNo, DeptNo, ClockAdjustmentNo,
              'B_P', AdjustmentName, 'H', 
              Case when InDay = 2 then Hours else 0 end,
              Case when InDay = 3 then Hours else 0 end,
              Case when InDay = 4 then Hours else 0 end,
              Case when InDay = 5 then Hours else 0 end,
              Case when InDay = 6 then Hours else 0 end,
              Case when InDay = 7 then Hours else 0 end,
              Case when InDay = 1 then Hours else 0 end,
              Case when InDay < 1 or InDay > 7 then Hours else 0 end,
              Hours, AgencyNo, 'B_P',0,getdate(),null,null,0,null,'1','000.000.000.000',ShiftNo
        from TimeHistory..tblTimeHistdetail
        where RecordID = @RecordID)
      
        if @@Error <> 0 
        begin
          Set @SaveError = @@Error
          goto RollBackTransaction
        end  
      
      COMMIT TRANSACTION

	END
	FETCH NEXT FROM cBaylor INTO @SSN, @TransDate, @SiteNo, @enStatus, @DOW
END

CLOSE cBaylor
DEALLOCATE cBaylor

Select Distinct en.Client, en.GroupCode, PPED = @PPED, t.SSN, en.LastName, en.FirstName, BaylorHours = 6.00
from #tmpRecs as t 
Inner join TimeCurrent..tblEmplNames as en
on en.client = @Client
and en.groupcode = @Groupcode
and en.SSN = t.SSN


drop table #tmpRecs

return

RollBackTransaction:
Rollback Transaction

return --@SaveError













GO
