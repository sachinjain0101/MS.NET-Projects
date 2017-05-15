Comparing files C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_COAS_ShortBreak_SpecPay.sql and C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_COAS_SHORTBREAK_SPECPAY.SQL
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_COAS_ShortBreak_SpecPay.sql
  101:        Update TimeHistory..tblTimeHistDetail Set InClass = 'S',CountAsOT = @ShiftSegment where recordid = @recordID 
  102:        Update TimeHistory..tblTimeHistDetail Set OutClass = 'S', BillOTRateOverride = 0.00 where recordid = isnull(@savRecordID,
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_COAS_SHORTBREAK_SPECPAY.SQL
  100:        Update TimeHistory..tblTimeHistDetail Set InClass = 'S',CountAsOT = @ShiftSegment where recordid = @recordID 
  101:        Update TimeHistory..tblTimeHistDetail Set OutClass = 'S', BillOTRateOverride = 0.00 where recordid = isnull(@savRecordID,
*****

