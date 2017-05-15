Comparing files C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_ADVO_UnionRules_SpecPay.sql and C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_ADVO_UNIONRULES_SPECPAY.SQL
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_ADVO_UnionRules_SpecPay.sql
  101:    Insert into #tmpTrans(TransDate, ShiftSegment, masterpayrolldate, PrimarySite, PRimaryDept, MaxSpan, TotWorked)
  102:    select t.TransDate, 0, t.masterpayrolldate, e.PrimarySite, e.PrimaryDept,
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_ADVO_UNIONRULES_SPECPAY.SQL
  100:    Insert into #tmpTrans(TransDate, ShiftSegment, masterpayrolldate, PrimarySite, PRimaryDept, MaxSpan, TotWorked)
  101:    select t.TransDate, 0, t.masterpayrolldate, e.PrimarySite, e.PrimaryDept,
*****

