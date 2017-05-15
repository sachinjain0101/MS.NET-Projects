Comparing files C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_web1_Delete_Adj.sql and C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DELETE_ADJ.SQL
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_web1_Delete_Adj.sql
  101:  sDollars, SatVal, dbo.PPED_DateTime(PayrollPeriodEndDate,7, '00:00') as TransDate, 7 as day from timecurrent..tbladjustments
  102:                          where SatVal <> 0 and client= @client and groupcode=@groupCode and payrollPeriodEndDate = @PPED
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WEB1_DELETE_ADJ.SQL
  100:  sDollars, SatVal, dbo.PPED_DateTime(PayrollPeriodEndDate,7, '00:00') as TransDate, 7 as day from timecurrent..tbladjustments
  101:                          where SatVal <> 0 and client= @client and groupcode=@groupCode and payrollPeriodEndDate = @PPED
*****

