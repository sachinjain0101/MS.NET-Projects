USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_SetBreakAdj_ShiftNo]    Script Date: 3/31/2015 11:53:39 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_SetBreakAdj_ShiftNo]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_SetBreakAdj_ShiftNo] AS' 
END
GO
ALTER Procedure [dbo].[usp_SetBreakAdj_ShiftNo](
@RecordID BIGINT)  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 02Sept2016 >--

AS

SET NOCOUNT ON

/********************************************************************************************

Feed this procedure the RecordID from tblTimeHistDetail of a Break Adjustment and it will update that transaction
with the most appropriate DeptNo, ShiftNo & PayRate.

*******************************************************************************************/

DECLARE @Dept As Int
DECLARE @SSN As Int
DECLARE @TransDate as DateTime
DECLARE @Client As Char(4)
DECLARE @GroupCode As Int
DECLARE @ShiftNo As Int
DECLARE @PayRate As Numeric(5,2)
DECLARE @Hours As Numeric(5,2)

Select @SSN = SSN, @TransDate = TransDate, @Client = Client, @GroupCode = GroupCode
 From TimeHistory..tblTimeHistDetail Where RecordId = @RecordID

Select Top 1 @Dept = DeptNo, @ShiftNo=ShiftNo, @PayRate = PayRate, @Hours = Sum(Hours) 
From TimeHistory..tblTimeHistDetail 
where TransDate = @TransDate and Client = @Client and GroupCode = @GroupCode and SSN = @SSN and 
(ClockAdjustmentNo = '' or ClockAdjustmentNo = ' ' or ClockAdjustmentNo = '1')
Group By DeptNo, ShiftNo, PayRate
Order by Sum(Hours), DeptNo, ShiftNo DESC

Update TimeHistory..tblTimeHistDetail 
Set DeptNo = @Dept, ShiftNo = @ShiftNo, PayRate = @PayRate 
Where RecordID = @RecordID

return 
GO
