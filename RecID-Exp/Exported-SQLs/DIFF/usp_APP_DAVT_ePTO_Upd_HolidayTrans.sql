Comparing files C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_DAVT_ePTO_Upd_HolidayTrans.sql and C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_DAVT_EPTO_UPD_HOLIDAYTRANS.SQL
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_DAVT_ePTO_Upd_HolidayTrans.sql
  101:                  Set @Comment = 'Employee has been hired for less than 90 days. The ePTO(' + ltrim(rtrim(@AdjName)) + ') for ' +
  102:   convert(varchar(12), @TransDate, 101) + ' with hours of ' + ltrim(str(@Hours,6,2)) + ' was changed to HOLPTO.'
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_DAVT_EPTO_UPD_HOLIDAYTRANS.SQL
  100:                  Set @Comment = 'Employee has been hired for less than 90 days. The ePTO(' + ltrim(rtrim(@AdjName)) + ') for ' +
  101:   convert(varchar(12), @TransDate, 101) + ' with hours of ' + ltrim(str(@Hours,6,2)) + ' was changed to HOLPTO.'
*****

