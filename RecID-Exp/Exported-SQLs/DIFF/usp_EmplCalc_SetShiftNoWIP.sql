Comparing files C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_EmplCalc_SetShiftNoWIP.sql and C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_EMPLCALC_SETSHIFTNOWIP.SQL
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_EmplCalc_SetShiftNoWIP.sql
  101:                                case when ApplyDay2 in('1','2') then case when ShiftEnd <= ShiftStart then dateadd(day,@Basedays+
  102:  2,Shiftend) else dateadd(day,@Basedays+1,Shiftend) end else '1/2/2026' END as MonEnd,
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_EMPLCALC_SETSHIFTNOWIP.SQL
  100:                                case when ApplyDay2 in('1','2') then case when ShiftEnd <= ShiftStart then dateadd(day,@Basedays+
  101:  2,Shiftend) else dateadd(day,@Basedays+1,Shiftend) end else '1/2/2026' END as MonEnd,
*****

