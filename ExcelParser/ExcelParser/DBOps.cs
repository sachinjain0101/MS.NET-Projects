using log4net;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ExcelParser {
    class DBOps {

        private static ILog LOGGER = LogManager.GetLogger(typeof(DBOps));

        const string TBL_DROP = @"DROP TABLE [dbo].[tblReportStructures];";
        const string TBL_CREATE = @"CREATE TABLE [dbo].[tblReportStructures](
	                                    [RecordID] [int] IDENTITY(1,1) NOT NULL,
	                                    [ReportCode] [varchar](100) NULL,
	                                    [ProgramName] [varchar](100) NULL,
	                                    [SortOrder] [varchar](100) NULL,
	                                    [ReportTemplate] [varchar](100) NULL,
	                                    [DatabaseName] [varchar](100) NULL,
	                                    [StoredProcName] [varchar](100) NULL,
	                                    [ColumnAlias] [varchar](1000) NULL,
	                                    [ColumnCalc] [varchar](1000) NULL,
	                                    [LastUpdateDate] [datetime] NOT NULL DEFAULT CURRENT_TIMESTAMP
                                    ) ON [PRIMARY]
                                    ";
        private string TBL_INSERT = "INSERT INTO [dbo].[tblReportStructures] "
                                    + " ([ReportCode] ,[ProgramName] ,[SortOrder] ,[ReportTemplate] ,[DatabaseName] ,[StoredProcName] ,[ColumnAlias] ,[ColumnCalc] ) "
                                    + " VALUES "
                                    + " (@ReportCode ,@ProgramName ,@SortOrder ,@ReportTemplate ,@DatabaseName ,@StoredProcName ,@ColumnAlias ,@ColumnCalc ) ";
        private string connStr;
        public string ConnStr { get => connStr; set => connStr = value; }

        private void ExecuteSqlStmt(string stmt) {
            using (SqlConnection cn = new SqlConnection(connStr))
            using (SqlCommand cmd = new SqlCommand(stmt, cn)) {
                cn.Open();
                cmd.ExecuteNonQuery();
            }
        }

        public void DropTable() {
            LOGGER.Info("Droping Table");
            ExecuteSqlStmt(TBL_DROP);
        }

        public void CreateTable() {
            LOGGER.Info("Creating Table");
            ExecuteSqlStmt(TBL_CREATE);
        }

        public void InsertIntoTable(ReportMetaData rmd) {
            using (SqlConnection cn = new SqlConnection(connStr))
            using (SqlCommand cmd = new SqlCommand(TBL_INSERT, cn)) {
                string x = "";
                x = String.IsNullOrEmpty(rmd.ReportCode) ? "" : rmd.ReportCode;
                cmd.Parameters.AddWithValue("@ReportCode", x);
                x = String.IsNullOrEmpty(rmd.ProgramName) ? "" : rmd.ProgramName;
                cmd.Parameters.AddWithValue("@ProgramName", x);
                x = String.IsNullOrEmpty(rmd.SortOrder) ? "" : rmd.SortOrder;
                cmd.Parameters.AddWithValue("@SortOrder", x);
                x = String.IsNullOrEmpty(rmd.XlsFileName) ? "" : rmd.XlsFileName;
                cmd.Parameters.AddWithValue("@ReportTemplate", x);
                x = String.IsNullOrEmpty(rmd.DbName) ? "" : rmd.DbName;
                cmd.Parameters.AddWithValue("@DatabaseName", x);
                x = String.IsNullOrEmpty(rmd.SpName) ? "" : rmd.SpName;
                cmd.Parameters.AddWithValue("@StoredProcName", x);
                x = String.IsNullOrEmpty(rmd.ColumnAlias) ? "" : rmd.ColumnAlias;
                cmd.Parameters.AddWithValue("@ColumnAlias", x);
                x = String.IsNullOrEmpty(rmd.ColumnCalc) ? "" : rmd.ColumnCalc;
                cmd.Parameters.AddWithValue("@ColumnCalc", x);
                cn.Open();
                cmd.ExecuteNonQuery();
            }
        }

    }
}
