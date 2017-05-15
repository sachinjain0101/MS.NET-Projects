USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_CECLOCK_save_fixedPunch]    Script Date: 3/31/2015 11:53:38 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_CECLOCK_save_fixedPunch]') AND type IN (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_CECLOCK_save_fixedPunch] AS' 
END
GO

ALTER PROC [dbo].[usp_CECLOCK_save_fixedPunch]
(
    @RecordID BIGINT,  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 22Aug2016 >--
    @Type   varchar(1),
    @DateTime Datetime
) AS

SET NOCOUNT ON

DECLARE @cnt int
DECLARE @InDateTime datetime
DECLARE @OutDateTime datetime

SET @InDateTime = CASE WHEN @Type = 'I' THEN @DateTime ELSE null END
SET @OutDateTime = CASE WHEN @Type = 'O' THEN @DateTime ELSE null END
SET @cnt = (SELECT count(RecordID) FROM Timehistory..tblFixedPunchByEe WHERE RecordID = @RecordID)
IF @cnt > 0 
BEGIN
   UPDATE Timehistory..tblFixedPunchByEe
   SET InDateTime = @InDateTime,
       OutDateTime = @OutDateTime,
       DateHandled = getdate()
   WHERE RecordID = @RecordID
END
ELSE
BEGIN
    INSERT INTO Timehistory..tblFixedPunchByEe(RecordID,InDateTime,OutDateTime,DateHandled) VALUES(@RecordID, @InDateTime, @OutDateTime, getdate())
END


GO
