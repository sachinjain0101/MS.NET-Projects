Comparing files C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_SpecPay_Paid_Break_OLST_UniPharm.sql and C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_SPECPAY_PAID_BREAK_OLST_UNIPHARM.SQL
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_SpecPay_Paid_Break_OLST_UniPharm.sql
  101:                Set @RecordID = (Select TOP 1 RecordID from TimeHistory..tblTimeHistDetail
  102:                                  where client = @Client 
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_SPECPAY_PAID_BREAK_OLST_UNIPHARM.SQL
  100:                Set @RecordID = (Select TOP 1 RecordID from TimeHistory..tblTimeHistDetail
  101:                                  where client = @Client 
*****

