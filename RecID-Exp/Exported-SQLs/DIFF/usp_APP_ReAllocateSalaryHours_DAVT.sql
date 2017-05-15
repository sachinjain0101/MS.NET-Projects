Comparing files C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_ReAllocateSalaryHours_DAVT.sql and C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_REALLOCATESALARYHOURS_DAVT.SQL
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_ReAllocateSalaryHours_DAVT.sql
  101:    Insert into #tmpRecs (SSN, ClockAdjustmentNo, AdjustmentName, TotHours)
  102:    (select thd.SSN, thd.ClockAdjustmentNo, thd.AdjustmentName, 
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_REALLOCATESALARYHOURS_DAVT.SQL
  100:    Insert into #tmpRecs (SSN, ClockAdjustmentNo, AdjustmentName, TotHours)
  101:    (select thd.SSN, thd.ClockAdjustmentNo, thd.AdjustmentName, 
*****

