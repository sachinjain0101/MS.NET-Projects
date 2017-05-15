Comparing files C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WGET_RestBreak_Response_OLD.sql and C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WGET_RESTBREAK_RESPONSE_OLD.SQL
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WGET_RestBreak_Response_OLD.sql
  101:    + ' missed rest break' + CASE WHEN @MissedDuetoWork > 1 THEN 's' ELSE '' END + ' by choice.'
  103:    INSERT  INTO [TimeHistory].[dbo].[tblTimeHistDetail_Comments]
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WGET_RESTBREAK_RESPONSE_OLD.SQL
  100:    + ' missed rest break' + CASE WHEN @MissedDuetoWork > 1 THEN 's' ELSE '' END + ' by choice.'
  102:    INSERT  INTO [TimeHistory].[dbo].[tblTimeHistDetail_Comments]
*****

