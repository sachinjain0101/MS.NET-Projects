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
                string tempTblName = "#wrkRecalc" + DateTime.Now.ToString("yyyyddMMHHmi", CultureInfo.InvariantCulture);

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
                    thd.RecordID = r["RecordID"].ToString();
                else
                    thd.RecordID = "0";
                if (r["Client"].ToString() != "")
                    thd.Client = r["Client"].ToString();
                else
                    thd.Client = "";
                if (r["GroupCode"].ToString() != "")
                    thd.GroupCode = r["GroupCode"].ToString();
                else
                    thd.GroupCode = "0";
                if (r["SSN"].ToString() != "")
                    thd.SSN = r["SSN"].ToString();
                else
                    thd.SSN = "0";
                if (r["PayrollPeriodEndDate"].ToString() != "")
                    thd.PayrollPeriodEndDate = DateTime.Parse(r["PayrollPeriodEndDate"].ToString()).ToString("yyyy-MM-dd HH:mm:ss");
                else
                    thd.PayrollPeriodEndDate = "";
                if (r["MasterPayrollDate"].ToString() != "")
                    thd.MasterPayrollDate = DateTime.Parse(r["MasterPayrollDate"].ToString()).ToString("yyyy-MM-dd HH:mm:ss");
                else
                    thd.MasterPayrollDate = "";
                if (r["SiteNo"].ToString() != "")
                    thd.SiteNo = r["SiteNo"].ToString();
                else
                    thd.SiteNo = "0";
                if (r["DeptNo"].ToString() != "")
                    thd.DeptNo = r["DeptNo"].ToString();
                else
                    thd.DeptNo = "0";
                if (r["JobID"].ToString() != "")
                    thd.JobID = r["JobID"].ToString();
                else
                    thd.JobID = "0";
                if (r["TransDate"].ToString() != "")
                    thd.TransDate = DateTime.Parse(r["TransDate"].ToString()).ToString("yyyy-MM-dd HH:mm:ss");
                else
                    thd.TransDate = "";
                if (r["EmpStatus"].ToString() != "")
                    thd.EmpStatus = r["EmpStatus"].ToString();
                else
                    thd.EmpStatus = "0";
                if (r["BillRate"].ToString() != "")
                    thd.BillRate = r["BillRate"].ToString();
                else
                    thd.BillRate = "0.0";
                if (r["BillOTRate"].ToString() != "")
                    thd.BillOTRate = r["BillOTRate"].ToString();
                else
                    thd.BillOTRate = "0.0";
                if (r["BillOTRateOverride"].ToString() != "")
                    thd.BillOTRateOverride = r["BillOTRateOverride"].ToString();
                else
                    thd.BillOTRateOverride = "0.0";
                if (r["PayRate"].ToString() != "")
                    thd.PayRate = r["PayRate"].ToString();
                else
                    thd.PayRate = "0.0";
                if (r["ShiftNo"].ToString() != "")
                    thd.ShiftNo = r["ShiftNo"].ToString();
                else
                    thd.ShiftNo = "0";
                if (r["InDay"].ToString() != "")
                    thd.InDay = r["InDay"].ToString();
                else
                    thd.InDay = "0";
                if (r["InTime"].ToString() != "")
                    thd.InTime = DateTime.Parse(r["InTime"].ToString()).ToString("yyyy-MM-dd HH:mm:ss");
                else
                    thd.InTime = "";
                if (r["OutDay"].ToString() != "")
                    thd.OutDay = r["OutDay"].ToString();
                else
                    thd.OutDay = "0";
                if (r["OutTime"].ToString() != "")
                    thd.OutTime = DateTime.Parse(r["OutTime"].ToString()).ToString("yyyy-MM-dd HH:mm:ss");
                else
                    thd.OutTime = "";
                if (r["Hours"].ToString() != "")
                    thd.Hours = r["Hours"].ToString();
                else
                    thd.Hours = "0.0";
                if (r["Dollars"].ToString() != "")
                    thd.Dollars = r["Dollars"].ToString();
                else
                    thd.Dollars = "0.0";
                if (r["ClockAdjustmentNo"].ToString() != "")
                    thd.ClockAdjustmentNo = r["ClockAdjustmentNo"].ToString();
                else
                    thd.ClockAdjustmentNo = "";
                if (r["AdjustmentCode"].ToString() != "")
                    thd.AdjustmentCode = r["AdjustmentCode"].ToString();
                else
                    thd.AdjustmentCode = "";
                if (r["AdjustmentName"].ToString() != "")
                    thd.AdjustmentName = r["AdjustmentName"].ToString();
                else
                    thd.AdjustmentName = "";
                if (r["TransType"].ToString() != "")
                    thd.TransType = r["TransType"].ToString();
                else
                    thd.TransType = "0";
                if (r["Changed_DeptNo"].ToString() != "")
                    thd.Changed_DeptNo = r["Changed_DeptNo"].ToString();
                else
                    thd.Changed_DeptNo = "";
                if (r["Changed_InPunch"].ToString() != "")
                    thd.Changed_InPunch = r["Changed_InPunch"].ToString();
                else
                    thd.Changed_InPunch = "";
                if (r["Changed_OutPunch"].ToString() != "")
                    thd.Changed_OutPunch = r["Changed_OutPunch"].ToString();
                else
                    thd.Changed_OutPunch = "";
                if (r["AgencyNo"].ToString() != "")
                    thd.AgencyNo = r["AgencyNo"].ToString();
                else
                    thd.AgencyNo = "0";
                if (r["InSrc"].ToString() != "")
                    thd.InSrc = r["InSrc"].ToString();
                else
                    thd.InSrc = "";
                if (r["OutSrc"].ToString() != "")
                    thd.OutSrc = r["OutSrc"].ToString();
                else
                    thd.OutSrc = "";
                if (r["DaylightSavTime"].ToString() != "")
                    thd.DaylightSavTime = r["DaylightSavTime"].ToString();
                else
                    thd.DaylightSavTime = "";
                if (r["Holiday"].ToString() != "")
                    thd.Holiday = r["Holiday"].ToString();
                else
                    thd.Holiday = "";
                if (r["RegHours"].ToString() != "")
                    thd.RegHours = r["RegHours"].ToString();
                else
                    thd.RegHours = "0.0";
                if (r["OT_Hours"].ToString() != "")
                    thd.OT_Hours = r["OT_Hours"].ToString();
                else
                    thd.OT_Hours = "0.0";
                if (r["DT_Hours"].ToString() != "")
                    thd.DT_Hours = r["DT_Hours"].ToString();
                else
                    thd.DT_Hours = "0.0";
                if (r["RegDollars"].ToString() != "")
                    thd.RegDollars = r["RegDollars"].ToString();
                else
                    thd.RegDollars = "0.0";
                if (r["OT_Dollars"].ToString() != "")
                    thd.OT_Dollars = r["OT_Dollars"].ToString();
                else
                    thd.OT_Dollars = "0.0";
                if (r["DT_Dollars"].ToString() != "")
                    thd.DT_Dollars = r["DT_Dollars"].ToString();
                else
                    thd.DT_Dollars = "0.0";
                if (r["RegBillingDollars"].ToString() != "")
                    thd.RegBillingDollars = r["RegBillingDollars"].ToString();
                else
                    thd.RegBillingDollars = "0.0";
                if (r["OTBillingDollars"].ToString() != "")
                    thd.OTBillingDollars = r["OTBillingDollars"].ToString();
                else
                    thd.OTBillingDollars = "0.0";
                if (r["DTBillingDollars"].ToString() != "")
                    thd.DTBillingDollars = r["DTBillingDollars"].ToString();
                else
                    thd.DTBillingDollars = "0.0";
                if (r["CountAsOT"].ToString() != "")
                    thd.CountAsOT = r["CountAsOT"].ToString();
                else
                    thd.CountAsOT = "";
                if (r["RegDollars4"].ToString() != "")
                    thd.RegDollars4 = r["RegDollars4"].ToString();
                else
                    thd.RegDollars4 = "0.0";
                if (r["OT_Dollars4"].ToString() != "")
                    thd.OT_Dollars4 = r["OT_Dollars4"].ToString();
                else
                    thd.OT_Dollars4 = "0.0";
                if (r["DT_Dollars4"].ToString() != "")
                    thd.DT_Dollars4 = r["DT_Dollars4"].ToString();
                else
                    thd.DT_Dollars4 = "0.0";
                if (r["RegBillingDollars4"].ToString() != "")
                    thd.RegBillingDollars4 = r["RegBillingDollars4"].ToString();
                else
                    thd.RegBillingDollars4 = "0.0";
                if (r["OTBillingDollars4"].ToString() != "")
                    thd.OTBillingDollars4 = r["OTBillingDollars4"].ToString();
                else
                    thd.OTBillingDollars4 = "0.0";
                if (r["DTBillingDollars4"].ToString() != "")
                    thd.DTBillingDollars4 = r["DTBillingDollars4"].ToString();
                else
                    thd.DTBillingDollars4 = "0.0";
                if (r["xAdjHours"].ToString() != "")
                    thd.xAdjHours = r["xAdjHours"].ToString();
                else
                    thd.xAdjHours = "0.0";
                if (r["AprvlStatus"].ToString() != "")
                    thd.AprvlStatus = r["AprvlStatus"].ToString();
                else
                    thd.AprvlStatus = "";
                if (r["AprvlStatus_UserID"].ToString() != "")
                    thd.AprvlStatus_UserID = r["AprvlStatus_UserID"].ToString();
                else
                    thd.AprvlStatus_UserID = "0";
                if (r["AprvlStatus_Date"].ToString() != "")
                    thd.AprvlStatus_Date = DateTime.Parse(r["AprvlStatus_Date"].ToString()).ToString("yyyy-MM-dd HH:mm:ss");
                else
                    thd.AprvlStatus_Date = "";
                if (r["AprvlAdjOrigRecID"].ToString() != "")
                    thd.AprvlAdjOrigRecID = r["AprvlAdjOrigRecID"].ToString();
                else
                    thd.AprvlAdjOrigRecID = "0";
                if (r["HandledByImporter"].ToString() != "")
                    thd.HandledByImporter = r["HandledByImporter"].ToString();
                else
                    thd.HandledByImporter = "";
                if (r["AprvlAdjOrigClkAdjNo"].ToString() != "")
                    thd.AprvlAdjOrigClkAdjNo = r["AprvlAdjOrigClkAdjNo"].ToString();
                else
                    thd.AprvlAdjOrigClkAdjNo = "";
                if (r["ClkTransNo"].ToString() != "")
                    thd.ClkTransNo = r["ClkTransNo"].ToString();
                else
                    thd.ClkTransNo = "0";
                if (r["ShiftDiffClass"].ToString() != "")
                    thd.ShiftDiffClass = r["ShiftDiffClass"].ToString();
                else
                    thd.ShiftDiffClass = "";
                if (r["AllocatedRegHours"].ToString() != "")
                    thd.AllocatedRegHours = r["AllocatedRegHours"].ToString();
                else
                    thd.AllocatedRegHours = "0.0";
                if (r["AllocatedOT_Hours"].ToString() != "")
                    thd.AllocatedOT_Hours = r["AllocatedOT_Hours"].ToString();
                else
                    thd.AllocatedOT_Hours = "0.0";
                if (r["AllocatedDT_Hours"].ToString() != "")
                    thd.AllocatedDT_Hours = r["AllocatedDT_Hours"].ToString();
                else
                    thd.AllocatedDT_Hours = "0.0";
                if (r["Borrowed"].ToString() != "")
                    thd.Borrowed = r["Borrowed"].ToString();
                else
                    thd.Borrowed = "";
                if (r["UserCode"].ToString() != "")
                    thd.UserCode = r["UserCode"].ToString();
                else
                    thd.UserCode = "";
                if (r["DivisionID"].ToString() != "")
                    thd.DivisionID = r["DivisionID"].ToString();
                else
                    thd.DivisionID = "0";
                if (r["CostID"].ToString() != "")
                    thd.CostID = r["CostID"].ToString();
                else
                    thd.CostID = "";
                if (r["ShiftDiffAmt"].ToString() != "")
                    thd.ShiftDiffAmt = r["ShiftDiffAmt"].ToString();
                else
                    thd.ShiftDiffAmt = "0.0";
                if (r["OutUserCode"].ToString() != "")
                    thd.OutUserCode = r["OutUserCode"].ToString();
                else
                    thd.OutUserCode = "";
                if (r["ActualInTime"].ToString() != "")
                    thd.ActualInTime = DateTime.Parse(r["ActualInTime"].ToString()).ToString("yyyy-MM-dd HH:mm:ss");
                else
                    thd.ActualInTime = "";
                if (r["ActualOutTime"].ToString() != "")
                    thd.ActualOutTime = DateTime.Parse(r["ActualOutTime"].ToString()).ToString("yyyy-MM-dd HH:mm:ss");
                else
                    thd.ActualOutTime = "";
                if (r["InSiteNo"].ToString() != "")
                    thd.InSiteNo = r["InSiteNo"].ToString();
                else
                    thd.InSiteNo = "0";
                if (r["OutSiteNo"].ToString() != "")
                    thd.OutSiteNo = r["OutSiteNo"].ToString();
                else
                    thd.OutSiteNo = "0";
                if (r["InVerified"].ToString() != "")
                    thd.InVerified = r["InVerified"].ToString();
                else
                    thd.InVerified = "";
                if (r["OutVerified"].ToString() != "")
                    thd.OutVerified = r["OutVerified"].ToString();
                else
                    thd.OutVerified = "";
                if (r["InClass"].ToString() != "")
                    thd.InClass = r["InClass"].ToString();
                else
                    thd.InClass = "";
                if (r["OutClass"].ToString() != "")
                    thd.OutClass = r["OutClass"].ToString();
                else
                    thd.OutClass = "";
                if (r["InTimestamp"].ToString() != "")
                    thd.InTimestamp = r["InTimestamp"].ToString();
                else
                    thd.InTimestamp = "0";
                if (r["outTimestamp"].ToString() != "")
                    thd.outTimestamp = r["outTimestamp"].ToString();
                else
                    thd.outTimestamp = "0";
                if (r["CrossoverStatus"].ToString() != "")
                    thd.CrossoverStatus = r["CrossoverStatus"].ToString();
                else
                    thd.CrossoverStatus = "";
                if (r["CrossoverOtherGroup"].ToString() != "")
                    thd.CrossoverOtherGroup = r["CrossoverOtherGroup"].ToString();
                else
                    thd.CrossoverOtherGroup = "0";
                if (r["InRoundOFF"].ToString() != "")
                    thd.InRoundOFF = r["InRoundOFF"].ToString();
                else
                    thd.InRoundOFF = "";
                if (r["OutRoundOFF"].ToString() != "")
                    thd.OutRoundOFF = r["OutRoundOFF"].ToString();
                else
                    thd.OutRoundOFF = "";
                if (r["AprvlStatus_Mobile"].ToString() != "True")
                    thd.AprvlStatus_Mobile = "T";
                else if (r["AprvlStatus_Mobile"].ToString() != "False")
                    thd.AprvlStatus_Mobile = "F";
                else
                    thd.AprvlStatus_Mobile = "NA";

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
