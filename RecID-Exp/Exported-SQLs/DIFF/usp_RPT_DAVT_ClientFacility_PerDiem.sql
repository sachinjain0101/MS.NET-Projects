Comparing files C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_RPT_DAVT_ClientFacility_PerDiem.sql and C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_RPT_DAVT_CLIENTFACILITY_PERDIEM.SQL
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_RPT_DAVT_ClientFacility_PerDiem.sql
  101:  AND ac.ClockAdjustmentNo = case when thd.ClockAdjustmentNo in('',' ','8') then '1' else thd.ClockAdjustmentNo END
  102:  WHERE thd.Client = @Client 
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_RPT_DAVT_CLIENTFACILITY_PERDIEM.SQL
  100:  AND ac.ClockAdjustmentNo = case when thd.ClockAdjustmentNo in('',' ','8') then '1' else thd.ClockAdjustmentNo END
  101:  WHERE thd.Client = @Client 
*****

