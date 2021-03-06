USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_PATE_CheckBeforeUpdate]    Script Date: 3/31/2015 11:53:38 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_PATE_CheckBeforeUpdate]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_PATE_CheckBeforeUpdate] AS' 
END
GO

-- exec usp_PATE_CheckBeforeUpdate 303180517, 'PATE', 890001, 8923, '09/17/06', '0000002309', '09/11/2006'

ALTER PROCEDURE [dbo].[usp_PATE_CheckBeforeUpdate]
(
@THDRecordId BIGINT,  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 25Aug2016 >--
@Client varchar(4),
@GroupCode int,
@SSN int,
@PPED datetime,
@Account varchar(10),
@TransDate datetime
) AS

SELECT thd.RecordId
FROM TimeHistory.dbo.tblTimeHistDetail thd
INNER JOIN TimeCurrent..tblGroupDepts gd
ON gd.Client = thd.Client
AND gd.GroupCode = thd.GroupCode
AND gd.ClientDeptCode = @Account
AND gd.DeptNo = thd.DeptNo
WHERE thd.Client = @Client
AND thd.GroupCode = @GroupCode
AND thd.PayrollPeriodEndDate = @PPED
AND thd.TransDate = @TransDate
AND thd.SSN = @SSN
AND thd.RecordId <> @THDRecordId
AND thd.ClockAdjustmentNo = '1'


GO
