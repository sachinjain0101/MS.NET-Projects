using log4net;
using System;
using System.Data;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using System.Text;

namespace PeoplenetBillingConsole.Services {

    class DBOps {
        private static ILog LOGGER = LogManager.GetLogger(typeof(DBOps));

        private static string connStr = "";
        private SqlCommand cmd = null;
        private SqlDataAdapter da = null;
        public DBOps(string serverName) {
            connStr = string.Format(Constants.CONNECT_STR, serverName);
            LOGGER.Info(Constants.DisplayLine("DBOps Object initialized"));
        }

        public Int32 getLatestInvoiceNumber() {
            LOGGER.Info(Constants.DisplayLine("Getting latest invoice number"));
            Int32 latestInvoiceNo = 0;
            DataTable dt = new DataTable();
            string prcName = "[CigOrders].[dbo].[usp_APP_PeopleNetBilling_GetLatestInvoiceNumber]";
            using (SqlConnection conn = new SqlConnection(connStr)) {
                cmd = new SqlCommand(prcName, conn) {
                    CommandType = CommandType.StoredProcedure
                };

                da = new SqlDataAdapter(cmd);
                da.Fill(dt);
                latestInvoiceNo = Int32.Parse(dt.Rows[0]["LatestInvoiceNo"].ToString());
            }
            return latestInvoiceNo;
        }

        public void updateNetBilling(string billingDate) {
            string prcName = "Cigorders.[dbo].[usp_APP_PeopleNetBilling_Update_Comms_ItemNo]";
            using (SqlConnection conn = new SqlConnection(connStr)) {
                cmd = new SqlCommand(prcName, conn) {
                    CommandType = CommandType.StoredProcedure
                };
                cmd.Parameters.AddWithValue("@BillingDate", billingDate);
                //conn.Close();
                conn.Open();
                cmd.ExecuteNonQuery();
            }
        }

        public DataTable getBillingXrefCustomers(string billingDate, Int32 latestInvoiceNo) {
            DataTable dt = new DataTable();
            Int32 invoiceNo = latestInvoiceNo;
            string prcName = "Cigorders.[dbo].[usp_APP_PeopleNetBilling_GetXref_Customers]";
            using (SqlConnection conn = new SqlConnection(connStr)) {
                cmd = new SqlCommand(prcName, conn) {
                    CommandType = CommandType.StoredProcedure
                };
                cmd.Parameters.AddWithValue("@BillingDate", billingDate);
                da = new SqlDataAdapter(cmd);
                da.Fill(dt);

                dt.Columns.Add("InvoiceNo", typeof(System.Int32));
                foreach (DataRow r in dt.Rows) {
                    if (r["InvoiceKey"].ToString() != invoiceNo.ToString()) {
                        invoiceNo++;
                        r["InvoiceNo"] = invoiceNo;
                    }
                }
            }
            return dt;
        }

        public DataTable getItemBillMasterClientDef2(DataRow row) {
            //string client, int groupCode, int siteNo, int parentGroupCode, Int32 invoiceNo, string QBJobName
            DataTable dt = new DataTable();
            string prcName = "Cigorders.[dbo].[usp_APP_PeopleNetBilling_Get_ItemBillingMaster_ClientDef2]";
            using (SqlConnection conn = new SqlConnection(connStr)) {
                cmd = new SqlCommand(prcName, conn) {
                    CommandType = CommandType.StoredProcedure
                };
                cmd.Parameters.AddWithValue("@Client", row["Client"]);
                cmd.Parameters.AddWithValue("@GroupCode", row["GroupCode"]);
                da = new SqlDataAdapter(cmd);
                da.Fill(dt);
                dt.Columns.Add("Client", typeof(System.String));
                dt.Columns.Add("GroupCode", typeof(System.Int32));
                dt.Columns.Add("SiteNo", typeof(System.Int32));
                dt.Columns.Add("ParentGroupCode", typeof(System.Int32));
                dt.Columns.Add("InvoiceNo", typeof(System.Int32));
                dt.Columns.Add("QB_Job_Name", typeof(System.String));
                dt.Columns.Add("Taxable", typeof(System.String));
                dt.Columns.Add("RefNum", typeof(System.Int32));

                if (dt.Rows.Count > 0) {
                    foreach (DataRow r in dt.Rows) {
                        r["Client"] = row["Client"];
                        r["GroupCode"] = row["GroupCode"];
                        r["SiteNo"] = row["SiteNo"];
                        r["ParentGroupCode"] = row["ParentGroupCode"];
                        r["InvoiceNo"] = row["InvoiceNo"];
                        r["QB_Job_Name"] = row["QB_Job_Name"];
                        r["Taxable"] = row["Taxable"];
                        r["RefNum"] = row["RefNum"];
                    }
                }
            }
            return dt;
        }

        public void loadInvoiceDetails(DataRow row, string billingDate) {
            LOGGER.Info(Constants.DisplayLine("Loading invoice information"));
            DataTable dt = new DataTable();
            string prcName = row["SPROC"].ToString();
            if (prcName.Length > 0) {
                LOGGER.Info(Constants.DisplayLine("SPROC - " + prcName));
                using (SqlConnection conn = new SqlConnection(connStr)) {
                    cmd = new SqlCommand(prcName, conn) {
                        CommandType = CommandType.StoredProcedure
                    };
                    cmd.Parameters.AddWithValue("@Client", row["Client"]);
                    cmd.Parameters.AddWithValue("@GroupCode", row["GroupCode"]);
                    cmd.Parameters.AddWithValue("@SiteNo", row["SiteNo"]);
                    cmd.Parameters.AddWithValue("@SumUpLevel", row["SumUpLevel"]);
                    cmd.Parameters.AddWithValue("@BillingDate", billingDate);
                    cmd.Parameters.AddWithValue("@InvoiceNo", row["InvoiceNo"]);
                    cmd.Parameters.AddWithValue("@Rate", row["Rate"]);
                    cmd.Parameters.AddWithValue("@ParentGroupCode", row["ParentGroupCode"]);
                    cmd.Parameters.AddWithValue("@ItemMasterID", row["ItemMasterID"]);

                    da = new SqlDataAdapter(cmd);

                    da.Fill(dt);

                    dt.Columns.Add("ItemNo", typeof(System.String));

                    DataColumnCollection columns = dt.Columns;
                    if (!columns.Contains("AddressMD5")) {
                        dt.Columns.Add("AddressMD5", typeof(System.String));
                    }

                    foreach (DataRow r in dt.Rows) {
                        r["ItemNo"] = row["ItemNo"];
                        if (r["AddressMD5"] == null)
                            r["AddressMD5"] = "";
                        
                        decimal dAmount = (!DBNull.Value.Equals(r["Count"])) ? decimal.Parse(r["Count"].ToString()) : 0;
                        decimal dRate = (!DBNull.Value.Equals(r["Rate"])) ? decimal.Parse(r["Rate"].ToString()) : 0;

                        string strItemDesc = r["Itemdesc"].ToString();
                        decimal dExtAmount = decimal.Parse("0");
                        if (dAmount > 0) {
                            strItemDesc = (strItemDesc != "") ? strItemDesc + " " + row["ItemDesc"].ToString() : row["ItemDesc"].ToString();
                            dExtAmount = dAmount * dRate;
                        }
                        strItemDesc = strItemDesc.Replace("'", "''");


                        string innrPrcName = "Cigorders.dbo.usp_APP_PeopleNetbilling_InsertInvoiceDTL";
                        SqlCommand cmd1 = new SqlCommand(innrPrcName, conn) {
                            CommandType = CommandType.StoredProcedure
                        };
                        cmd1.Parameters.AddWithValue("@BillingDate", billingDate);
                        cmd1.Parameters.AddWithValue("@Client", row["Client"]);
                        cmd1.Parameters.AddWithValue("@GroupCode", row["GroupCode"]);
                        cmd1.Parameters.AddWithValue("@SiteNo", row["SiteNo"]);

                        cmd1.Parameters.AddWithValue("@InvGroupSite", 0);
                        cmd1.Parameters.AddWithValue("@ItemNo", row["ItemNo"]);
                        cmd1.Parameters.AddWithValue("@ItemDesc", strItemDesc);
                        cmd1.Parameters.AddWithValue("@Rate", dRate);
                        cmd1.Parameters.AddWithValue("@Qty", dAmount);
                        cmd1.Parameters.AddWithValue("@ExtendedAmt", dExtAmount);
                        cmd1.Parameters.AddWithValue("@ParentGroupCode", row["ParentGroupCode"]);
                        cmd1.Parameters.AddWithValue("@InvoiceNo", row["InvoiceNo"]);
                        cmd1.Parameters.AddWithValue("@InvoiceDate", billingDate);
                        cmd1.Parameters.AddWithValue("@CustName", row["QB_Job_Name"]);
                        cmd1.Parameters.AddWithValue("@SalesTax", row["Taxable"]);
                        cmd1.Parameters.AddWithValue("@RefNum", row["RefNum"]);
                        cmd1.Parameters.AddWithValue("@RateCode", row["RateCode"]);
                        cmd1.Parameters.AddWithValue("@AddressMD5", r["AddressMD5"] ?? null);

                        if (conn != null && conn.State == ConnectionState.Closed) {
                            conn.Open();
                        }

                        cmd1.ExecuteNonQuery();
                    }
                }
            }
        }
    }
}
