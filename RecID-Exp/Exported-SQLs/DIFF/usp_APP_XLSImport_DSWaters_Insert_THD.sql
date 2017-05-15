Comparing files C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_XLSImport_DSWaters_Insert_THD.sql and C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_XLSIMPORT_DSWATERS_INSERT_THD.SQL
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_XLSImport_DSWaters_Insert_THD.sql
  101:  Set @RecordID = (Select RecordID from TimeHistory.dbo.tblPeriodenddates where client = @Client and groupcode = @GroupCode and P
  102:  ayrollPeriodenddate = @PPED and Status <> 'C')
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_XLSIMPORT_DSWATERS_INSERT_THD.SQL
  100:  Set @RecordID = (Select RecordID from TimeHistory.dbo.tblPeriodenddates where client = @Client and groupcode = @GroupCode and P
  101:  ayrollPeriodenddate = @PPED and Status <> 'C')
*****

