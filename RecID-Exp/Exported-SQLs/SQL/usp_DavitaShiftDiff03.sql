USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_DavitaShiftDiff03]    Script Date: 3/31/2015 11:53:38 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_DavitaShiftDiff03]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_DavitaShiftDiff03] AS' 
END
GO


ALTER   procedure [dbo].[usp_DavitaShiftDiff03]
 @Client varchar(4),   
 @GroupCode int,
 @WeekEndDate DateTime, 
 @SSN int,
 @TransDate DateTime,
 @ClkTransNo BIGINT,  --< @ClkTransNo data type is changed from  INT to BIGINT by Srinsoft on 05Oct2016 >--
 @OutTime datetime,
 @OutSrc varchar(2),
 @Hours numeric(5,2)
 
AS

-- Reconnect split record
UPDATE tblTimeHistDetail
SET OutTime = CONVERT(DateTime, '12/30/1899 ' + @OutTime),
	OutSrc = @OutSrc,
	Hours = Hours + @Hours
WHERE Client = @Client
  AND GroupCode = @GroupCode
  AND PayrollPeriodEndDate = @WeekEndDate
  AND SSN = @SSN
  AND TransDate = @TransDate
  AND convert(varchar(8), OutTime, 8) = '16:00:00'
  AND ClkTransNo = @ClkTransNo


GO
