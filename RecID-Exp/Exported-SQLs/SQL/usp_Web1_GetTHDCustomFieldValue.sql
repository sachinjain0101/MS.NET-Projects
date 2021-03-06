USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_Web1_GetTHDCustomFieldValue]    Script Date: 3/31/2015 11:53:39 AM ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER OFF
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_Web1_GetTHDCustomFieldValue]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_Web1_GetTHDCustomFieldValue] AS' 
END
GO

-- exec usp_Web1_GetCustomFieldValues 72


--/*
ALTER PROCEDURE [dbo].[usp_Web1_GetTHDCustomFieldValue] 
(
  @Client varchar(4),
  @GroupCode int,
  @PPED datetime,
  @SSN int,
  @TransDate datetime,
  @THDRecordId BIGINT,  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 09Sept2016 >--
  @FieldId int
)

AS
--*/

DECLARE @OutTimeStamp bigint
Set @OutTimeStamp = (select isnull(outTimestamp,0) from TimeHistory..tblTimeHistDetail with (nolock) where RecordID = @THDRecordId )

IF @OutTimeStamp = 0
  Set @OutTimeStamp = 1

SELECT RecordId,FieldValue
FROM TimeHistory..tblTimeHistDetail_UDF
WHERE THDRecordId = @THDRecordId
AND FieldId = @FieldId
union 
Select RecordID, FieldValue 
FROM TimeHistory..tblTimeHistDetail_UDF
WHERE Client = @Client
and GroupCode = @GroupCode 
and Payrollperiodenddate = @PPED
and SSN = @SSN
and TransDate = @TransDate 
AND FieldId = @FieldId
and isnull(PunchTimeStamp,0) = @OutTimeStamp 



GO
