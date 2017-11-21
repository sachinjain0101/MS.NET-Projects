using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using DataHub.Models;
using DataHub.SvcTimeCard.DataAccess;
using System.Data.SqlClient;
using System.Globalization;
using DataHub.Commons;
using System.Data;
using System.Reflection;
using log4net;

namespace DataHub.SvcTimeCard.Services {

    public class TimeCardService : ITimeCardService {

        private static readonly ILog LOGGER = LogManager.GetLogger(MethodBase.GetCurrentMethod().DeclaringType);

        ISqlConn _conn;

        TimeCardContext _timeCardContext;


        public TimeCardService(ISqlConn conn, TimeCardContext timeCardContext) {
            _conn = conn;
            _timeCardContext = timeCardContext;
        }



        List<TimeHistDetail> ITimeCardService.GetTimeCardData(List<Recalc> recalcs) {

            List<TimeHistDetail> thds = new List<TimeHistDetail>();
            string sql = "";
            bool done = false;
            DateTime current;

            using (SqlConnection sqlConn = _conn.GetConnection()) {
                sqlConn.Open();
                string tempTblName = "#wrkRecalc" + DateTime.Now.ToString("yyyyddMMhhmi", CultureInfo.InvariantCulture);

                //***********************************************************************
                sql = @"CREATE TABLE {0} ([RecordID] [BIGINT] NOT NULL, [Client] [VARCHAR](4) NULL, 
                                                    [GroupCode] [INT] NULL, [SSN] [INT] NULL, [PPED] [DATE] NULL,
                                                    [CalcTimeStamp][DATETIME] NULL, [Status] [VARCHAR] (50) NULL);";
                sql = String.Format(sql, tempTblName);
                current = DateTime.Now;
                done = RunDDL(sqlConn, sql);
                LOGGER.Info("Temp Table Creation : "+DateTime.Now.Subtract(current).Milliseconds);

                //***********************************************************************
                sql = @"INSERT INTO {0} (RecordID, Client, GroupCode, SSN, PPED, CalcTimeStamp, Status) 
                                         VALUES (@param1, @param2, @param3, @param4, @param5, @param6, @param7);";
                sql = String.Format(sql, tempTblName);
                current = DateTime.Now;
                done = RunInsert(sqlConn, recalcs, sql);
                LOGGER.Info("Recalc Insert : " + DateTime.Now.Subtract(current).Milliseconds);

                //***********************************************************************
                sql = @"SELECT 
                        thd.RecordID, thd.Client, thd.GroupCode, thd.SSN, thd.PayrollPeriodEndDate, thd.MasterPayrollDate, thd.SiteNo, thd.DeptNo, 
                        thd.JobID, thd.TransDate, thd.EmpStatus, thd.BillRate, thd.BillOTRate, thd.BillOTRateOverride, thd.PayRate, thd.ShiftNo, 
                        thd.InDay, thd.InTime, thd.OutDay, thd.OutTime, thd.Hours, thd.Dollars, thd.ClockAdjustmentNo, thd.AdjustmentCode, thd.AdjustmentName, 
                        thd.TransType, thd.Changed_DeptNo, thd.Changed_InPunch, thd.Changed_OutPunch, thd.AgencyNo, thd.InSrc, thd.OutSrc, thd.DaylightSavTime, 
                        thd.Holiday, thd.RegHours, thd.OT_Hours, thd.DT_Hours, thd.RegDollars, thd.OT_Dollars, thd.DT_Dollars, thd.RegBillingDollars, 
                        thd.OTBillingDollars, thd.DTBillingDollars, thd.CountAsOT, thd.RegDollars4, thd.OT_Dollars4, thd.DT_Dollars4, thd.RegBillingDollars4, 
                        thd.OTBillingDollars4, thd.DTBillingDollars4, thd.xAdjHours, thd.AprvlStatus, thd.AprvlStatus_UserID, thd.AprvlStatus_Date, 
                        thd.AprvlAdjOrigRecID, thd.HandledByImporter, thd.AprvlAdjOrigClkAdjNo, thd.ClkTransNo, thd.ShiftDiffClass, thd.AllocatedRegHours, 
                        thd.AllocatedOT_Hours, thd.AllocatedDT_Hours, thd.Borrowed, thd.UserCode, thd.DivisionID, thd.CostID, thd.ShiftDiffAmt, thd.OutUserCode, 
                        thd.ActualInTime, thd.ActualOutTime, thd.InSiteNo, thd.OutSiteNo, thd.InVerified, thd.OutVerified, thd.InClass, thd.OutClass, thd.InTimestamp, 
                        thd.outTimestamp, thd.CrossoverStatus, thd.CrossoverOtherGroup, thd.InRoundOFF, thd.OutRoundOFF, thd.AprvlStatus_Mobile 
                        FROM dbo.tblTimeHistDetail (NOLOCK) thd 
                           JOIN {0} wrk ON wrk.Client=thd.Client AND wrk.GroupCode=thd.GroupCode AND wrk.SSN=thd.SSN AND wrk.PPED=thd.PayrollPeriodEndDate;";
                sql = String.Format(sql, tempTblName);
                current = DateTime.Now;
                thds = RunSelect(sqlConn, sql);
                LOGGER.Info("THD Select : " + DateTime.Now.Subtract(current).Milliseconds);

                //***********************************************************************
                sql = @"DROP TABLE {0};";
                sql = String.Format(sql, tempTblName);
                current = DateTime.Now;
                done = RunDDL(sqlConn, sql);
                LOGGER.Info("Temp Table Drop : " + DateTime.Now.Subtract(current).Milliseconds);

                sqlConn.Close();
                sqlConn.Dispose();
            }

            return thds;

        }

        private bool RunDDL(SqlConnection conn, string sql) {
            try {
                using (SqlCommand command = new SqlCommand(sql, conn))
                    command.ExecuteNonQuery();
                return true;
            } catch (Exception e) {
                throw e;
            }
        }

        private bool RunInsert(SqlConnection conn, List<Recalc> recalcs, string sql) {
            try {
                SqlCommand cmd = new SqlCommand(sql, conn);
                cmd.CommandType = CommandType.Text;
                cmd.Parameters.Add("@param1", SqlDbType.BigInt);
                cmd.Parameters.Add("@param2", SqlDbType.VarChar);
                cmd.Parameters.Add("@param3", SqlDbType.Int);
                cmd.Parameters.Add("@param4", SqlDbType.Int);
                cmd.Parameters.Add("@param5", SqlDbType.Date);
                cmd.Parameters.Add("@param6", SqlDbType.DateTime);
                cmd.Parameters.Add("@param7", SqlDbType.VarChar);

                foreach (Recalc r in recalcs) {
                    cmd.Parameters[0].Value = r.RecordID;
                    cmd.Parameters[1].Value = r.Client;
                    cmd.Parameters[2].Value = r.GroupCode;
                    cmd.Parameters[3].Value = r.SSN;
                    cmd.Parameters[4].Value = r.PPED;
                    cmd.Parameters[5].Value = r.CalcTimeStamp;
                    cmd.Parameters[6].Value = (r.Status != null ? r.Status : "");

                    cmd.ExecuteNonQuery();
                }

                return true;
            } catch (Exception e) {
                throw e;
            }
        }

        private List<TimeHistDetail> RunSelect(SqlConnection conn, string sql) {

            DataTable dt = new DataTable();
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                using (SqlDataAdapter da = new SqlDataAdapter(cmd))
                    da.Fill(dt);

            List<TimeHistDetail> thds = new List<TimeHistDetail>();

            foreach (DataRow r in dt.Rows) {

                TimeHistDetail thd = new TimeHistDetail();

                if (r["RecordID"].ToString() != "")
                    thd.RecordID = Int64.Parse(r["RecordID"].ToString());
                else
                    thd.RecordID = null;
                thd.Client = r["Client"].ToString();
                if (r["GroupCode"].ToString() != "")
                    thd.GroupCode = Int32.Parse(r["GroupCode"].ToString());
                else
                    thd.GroupCode = null;
                if (r["SSN"].ToString() != "")
                    thd.SSN = Int32.Parse(r["SSN"].ToString());
                else
                    thd.SSN = null;
                if (r["PayrollPeriodEndDate"].ToString() != "")
                    thd.PayrollPeriodEndDate = DateTime.Parse(r["PayrollPeriodEndDate"].ToString());
                else
                    thd.PayrollPeriodEndDate = null;
                if (r["MasterPayrollDate"].ToString() != "")
                    thd.MasterPayrollDate = DateTime.Parse(r["MasterPayrollDate"].ToString());
                else
                    thd.MasterPayrollDate = null;
                if (r["SiteNo"].ToString() != "")
                    thd.SiteNo = Int32.Parse(r["SiteNo"].ToString());
                else
                    thd.SiteNo = null;
                if (r["DeptNo"].ToString() != "")
                    thd.DeptNo = Int32.Parse(r["DeptNo"].ToString());
                else
                    thd.DeptNo = null;
                if (r["JobID"].ToString() != "")
                    thd.JobID = Int64.Parse(r["JobID"].ToString());
                else
                    thd.JobID = null;
                if (r["TransDate"].ToString() != "")
                    thd.TransDate = DateTime.Parse(r["TransDate"].ToString());
                else
                    thd.TransDate = null;
                if (r["EmpStatus"].ToString() != "")
                    thd.EmpStatus = Int32.Parse(r["EmpStatus"].ToString());
                else
                    thd.EmpStatus = null;
                if (r["BillRate"].ToString() != "")
                    thd.BillRate = Decimal.Parse(r["BillRate"].ToString());
                else
                    thd.BillRate = null;
                if (r["BillOTRate"].ToString() != "")
                    thd.BillOTRate = Decimal.Parse(r["BillOTRate"].ToString());
                else
                    thd.BillOTRate = null;
                if (r["BillOTRateOverride"].ToString() != "")
                    thd.BillOTRateOverride = Decimal.Parse(r["BillOTRateOverride"].ToString());
                else
                    thd.BillOTRateOverride = null;
                if (r["PayRate"].ToString() != "")
                    thd.PayRate = Decimal.Parse(r["PayRate"].ToString());
                else
                    thd.PayRate = null;
                if (r["ShiftNo"].ToString() != "")
                    thd.ShiftNo = Int32.Parse(r["ShiftNo"].ToString());
                else
                    thd.ShiftNo = null;
                if (r["InDay"].ToString() != "")
                    thd.InDay = Int32.Parse(r["InDay"].ToString());
                else
                    thd.InDay = null;
                if (r["InTime"].ToString() != "")
                    thd.InTime = DateTime.Parse(r["InTime"].ToString());
                else
                    thd.InTime = null;
                if (r["OutDay"].ToString() != "")
                    thd.OutDay = Int32.Parse(r["OutDay"].ToString());
                else
                    thd.OutDay = null;
                if (r["OutTime"].ToString() != "")
                    thd.OutTime = DateTime.Parse(r["OutTime"].ToString());
                else
                    thd.OutTime = null;
                if (r["Hours"].ToString() != "")
                    thd.Hours = Decimal.Parse(r["Hours"].ToString());
                else
                    thd.Hours = null;
                if (r["Dollars"].ToString() != "")
                    thd.Dollars = Decimal.Parse(r["Dollars"].ToString());
                else
                    thd.Dollars = null;
                thd.ClockAdjustmentNo = r["ClockAdjustmentNo"].ToString();
                thd.AdjustmentCode = r["AdjustmentCode"].ToString();
                thd.AdjustmentName = r["AdjustmentName"].ToString();
                if (r["TransType"].ToString() != "")
                    thd.TransType = Int32.Parse(r["TransType"].ToString());
                else
                    thd.TransType = null;
                thd.Changed_DeptNo = r["Changed_DeptNo"].ToString();
                thd.Changed_InPunch = r["Changed_InPunch"].ToString();
                thd.Changed_OutPunch = r["Changed_OutPunch"].ToString();
                if (r["AgencyNo"].ToString() != "")
                    thd.AgencyNo = Int32.Parse(r["AgencyNo"].ToString());
                else
                    thd.AgencyNo = null;
                thd.InSrc = r["InSrc"].ToString();
                thd.OutSrc = r["OutSrc"].ToString();
                thd.DaylightSavTime = r["DaylightSavTime"].ToString();
                thd.Holiday = r["Holiday"].ToString();
                if (r["RegHours"].ToString() != "")
                    thd.RegHours = Decimal.Parse(r["RegHours"].ToString());
                else
                    thd.RegHours = null;
                if (r["OT_Hours"].ToString() != "")
                    thd.OT_Hours = Decimal.Parse(r["OT_Hours"].ToString());
                else
                    thd.OT_Hours = null;
                if (r["DT_Hours"].ToString() != "")
                    thd.DT_Hours = Decimal.Parse(r["DT_Hours"].ToString());
                else
                    thd.DT_Hours = null;
                if (r["RegDollars"].ToString() != "")
                    thd.RegDollars = Decimal.Parse(r["RegDollars"].ToString());
                else
                    thd.RegDollars = null;
                if (r["OT_Dollars"].ToString() != "")
                    thd.OT_Dollars = Decimal.Parse(r["OT_Dollars"].ToString());
                else
                    thd.OT_Dollars = null;
                if (r["DT_Dollars"].ToString() != "")
                    thd.DT_Dollars = Decimal.Parse(r["DT_Dollars"].ToString());
                else
                    thd.DT_Dollars = null;
                if (r["RegBillingDollars"].ToString() != "")
                    thd.RegBillingDollars = Decimal.Parse(r["RegBillingDollars"].ToString());
                else
                    thd.RegBillingDollars = null;
                if (r["OTBillingDollars"].ToString() != "")
                    thd.OTBillingDollars = Decimal.Parse(r["OTBillingDollars"].ToString());
                else
                    thd.OTBillingDollars = null;
                if (r["DTBillingDollars"].ToString() != "")
                    thd.DTBillingDollars = Decimal.Parse(r["DTBillingDollars"].ToString());
                else
                    thd.DTBillingDollars = null;
                thd.CountAsOT = r["CountAsOT"].ToString();
                if (r["RegDollars4"].ToString() != "")
                    thd.RegDollars4 = Decimal.Parse(r["RegDollars4"].ToString());
                else
                    thd.RegDollars4 = null;
                if (r["OT_Dollars4"].ToString() != "")
                    thd.OT_Dollars4 = Decimal.Parse(r["OT_Dollars4"].ToString());
                else
                    thd.OT_Dollars4 = null;
                if (r["DT_Dollars4"].ToString() != "")
                    thd.DT_Dollars4 = Decimal.Parse(r["DT_Dollars4"].ToString());
                else
                    thd.DT_Dollars4 = null;
                if (r["RegBillingDollars4"].ToString() != "")
                    thd.RegBillingDollars4 = Decimal.Parse(r["RegBillingDollars4"].ToString());
                else
                    thd.RegBillingDollars4 = null;
                if (r["OTBillingDollars4"].ToString() != "")
                    thd.OTBillingDollars4 = Decimal.Parse(r["OTBillingDollars4"].ToString());
                else
                    thd.OTBillingDollars4 = null;
                if (r["DTBillingDollars4"].ToString() != "")
                    thd.DTBillingDollars4 = Decimal.Parse(r["DTBillingDollars4"].ToString());
                else
                    thd.DTBillingDollars4 = null;
                if (r["xAdjHours"].ToString() != "")
                    thd.xAdjHours = Decimal.Parse(r["xAdjHours"].ToString());
                else
                    thd.xAdjHours = null;
                thd.AprvlStatus = r["AprvlStatus"].ToString();
                if (r["AprvlStatus_UserID"].ToString() != "")
                    thd.AprvlStatus_UserID = Int32.Parse(r["AprvlStatus_UserID"].ToString());
                else
                    thd.AprvlStatus_UserID = null;
                if (r["AprvlStatus_Date"].ToString() != "")
                    thd.AprvlStatus_Date = DateTime.Parse(r["AprvlStatus_Date"].ToString());
                else
                    thd.AprvlStatus_Date = null;
                if (r["AprvlAdjOrigRecID"].ToString() != "")
                    thd.AprvlAdjOrigRecID = Int64.Parse(r["AprvlAdjOrigRecID"].ToString());
                else
                    thd.AprvlAdjOrigRecID = null;
                thd.HandledByImporter = r["HandledByImporter"].ToString();
                thd.AprvlAdjOrigClkAdjNo = r["AprvlAdjOrigClkAdjNo"].ToString();
                if (r["ClkTransNo"].ToString() != "")
                    thd.ClkTransNo = Int64.Parse(r["ClkTransNo"].ToString());
                else
                    thd.ClkTransNo = null;
                thd.ShiftDiffClass = r["ShiftDiffClass"].ToString();
                if (r["AllocatedRegHours"].ToString() != "")
                    thd.AllocatedRegHours = Decimal.Parse(r["AllocatedRegHours"].ToString());
                else
                    thd.AllocatedRegHours = null;
                if (r["AllocatedOT_Hours"].ToString() != "")
                    thd.AllocatedOT_Hours = Decimal.Parse(r["AllocatedOT_Hours"].ToString());
                else
                    thd.AllocatedOT_Hours = null;
                if (r["AllocatedDT_Hours"].ToString() != "")
                    thd.AllocatedDT_Hours = Decimal.Parse(r["AllocatedDT_Hours"].ToString());
                else
                    thd.AllocatedDT_Hours = null;
                thd.Borrowed = r["Borrowed"].ToString();
                thd.UserCode = r["UserCode"].ToString();
                if (r["DivisionID"].ToString() != "")
                    thd.DivisionID = Int64.Parse(r["DivisionID"].ToString());
                else
                    thd.DivisionID = null;
                thd.CostID = r["CostID"].ToString();
                if (r["ShiftDiffAmt"].ToString() != "")
                    thd.ShiftDiffAmt = Decimal.Parse(r["ShiftDiffAmt"].ToString());
                else
                    thd.ShiftDiffAmt = null;
                thd.OutUserCode = r["OutUserCode"].ToString();
                if (r["ActualInTime"].ToString() != "")
                    thd.ActualInTime = DateTime.Parse(r["ActualInTime"].ToString());
                else
                    thd.ActualInTime = null;
                if (r["ActualOutTime"].ToString() != "")
                    thd.ActualOutTime = DateTime.Parse(r["ActualOutTime"].ToString());
                else
                    thd.ActualOutTime = null;
                if (r["InSiteNo"].ToString() != "")
                    thd.InSiteNo = Int32.Parse(r["InSiteNo"].ToString());
                else
                    thd.InSiteNo = null;
                if (r["OutSiteNo"].ToString() != "")
                    thd.OutSiteNo = Int32.Parse(r["OutSiteNo"].ToString());
                else
                    thd.OutSiteNo = null;
                thd.InVerified = r["InVerified"].ToString();
                thd.OutVerified = r["OutVerified"].ToString();
                thd.InClass = r["InClass"].ToString();
                thd.OutClass = r["OutClass"].ToString();
                if (r["InTimestamp"].ToString() != "")
                    thd.InTimestamp = Int64.Parse(r["InTimestamp"].ToString());
                else
                    thd.InTimestamp = null;
                if (r["outTimestamp"].ToString() != "")
                    thd.outTimestamp = Int64.Parse(r["outTimestamp"].ToString());
                else
                    thd.outTimestamp = null;
                thd.CrossoverStatus = r["CrossoverStatus"].ToString();
                if (r["CrossoverOtherGroup"].ToString() != "")
                    thd.CrossoverOtherGroup = Int32.Parse(r["CrossoverOtherGroup"].ToString());
                else
                    thd.CrossoverOtherGroup = null;
                thd.InRoundOFF = r["InRoundOFF"].ToString();
                thd.OutRoundOFF = r["OutRoundOFF"].ToString();
                if (r["AprvlStatus_Mobile"].ToString() != "")
                    thd.AprvlStatus_Mobile = Boolean.Parse(r["AprvlStatus_Mobile"].ToString());
                else
                    thd.AprvlStatus_Mobile = null;

                thds.Add(thd);

            }

            return thds;
        }

        public TimeHistDetailEF GetByRecordId(int recordId) {
            var timecards = _timeCardContext.timecard.Single(x => x.RecordID == recordId);
            return timecards;
        }

        public List<TimeHistDetailEF> GetNTimeCards(int numRecs) {
            var timecards = _timeCardContext.timecard.OrderBy(m => m.RecordID).Skip(10).Take(numRecs);
            return timecards.ToList<TimeHistDetailEF>();
        }

        public List<TimeHistDetailEF> GetTimeCards(List<Recalc> recalcs) {

            List<TimeHistDetailEF> timcecards = new List<TimeHistDetailEF>();

            var timecards = _timeCardContext.timecard;

            var c = recalcs.GroupBy(r => r.Client).SelectMany(x => x).ToList();

            var clients = recalcs.Select(r => r.Client).GroupBy(s => s).ToList();
            var groups = recalcs.Select(r => r.GroupCode).GroupBy(s => s).ToList();
            var ssns = recalcs.Select(r => r.SSN).GroupBy(s => s).ToList();
            var minPped = recalcs.Min(r => r.PPED);
            var maxPped = recalcs.Max(r => r.PPED);

            var tcs = (timecards.Where(tc => clients.Any(m => m.Key == tc.Client)
                                       && groups.Any(m => m.Key == tc.GroupCode)
                                       && ssns.Any(m => m.Key == tc.SSN)
                                       && tc.PayrollPeriodEndDate > minPped
                                       && tc.PayrollPeriodEndDate <= maxPped)).ToList();

            return tcs;
        }
    }
}
