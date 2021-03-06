USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_WTE_GetSummaryCardDetails_UDF]    Script Date: 3/31/2015 11:53:40 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_WTE_GetSummaryCardDetails_UDF]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_WTE_GetSummaryCardDetails_UDF] AS' 
END
GO

--/*
ALTER PROCEDURE [dbo].[usp_WTE_GetSummaryCardDetails_UDF] (
  @THDRecordID  BIGINT  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 16Sept2016 >--
)
AS
--*/

/*
DECLARE  @THDRecordID  int

SET @THDRecordID  = 319838501
*/

SELECT thd.FieldID, thd.FieldValue, defs.FieldDescription, defs.ControlType,
  CASE defs.DropDownMethod WHEN 'Custom' THEN options.OptionDesc WHEN 'PreDef' THEN lookup.LookupDescription END AS OptionDesc
FROM TimeHistory.dbo.tblTimeHistDetail_UDF thd
INNER JOIN TimeCurrent.dbo.tblUDF_FieldDefs defs
ON defs.FieldID = thd.FieldID
LEFT JOIN TimeCurrent.dbo.tblUDF_FieldOptions options
ON options.FieldID = defs.FieldID
  AND options.OptionValue = thd.FieldValue
  AND defs.DropDownMethod = 'Custom'
LEFT JOIN TimeCurrent.dbo.tblValidLookup lookup
ON lookup.LookupType = defs.LookupType
  AND lookup.LookupValue = thd.FieldValue
  AND defs.DropDownMethod = 'PreDef'
WHERE THDRecordID = @THDRecordID
ORDER BY defs.DisplaySeq


GO
