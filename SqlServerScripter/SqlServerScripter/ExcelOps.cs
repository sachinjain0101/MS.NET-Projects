using log4net;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;

using Excel = Microsoft.Office.Interop.Excel;

namespace SqlServerScripter {
    class ExcelOps {
        private static ILog LOGGER = LogManager.GetLogger(typeof(ExcelOps));

        public const char DOT = '.';
        public const char HYPHEN = '-';

        public static Dictionary<string, List<CustomTable>> getExcelSheetData(string file) {
            Excel.Application xlApp = new Excel.Application();
            var oldSecurity = xlApp.AutomationSecurity;
            xlApp.AutomationSecurity = Microsoft.Office.Core.MsoAutomationSecurity.msoAutomationSecurityForceDisable;
            xlApp.Application.DisplayAlerts = false;
            Excel.Workbook xlWorkbook = xlApp.Workbooks.Open(Filename: file, ReadOnly: true);
            Excel.Worksheet xlWorksheet = xlWorkbook.Sheets["RealTableList"];
            Excel.Range xlRange = xlWorksheet.UsedRange;

            Excel.Range range = xlWorksheet.UsedRange;

            int rows = range.Rows.Count;
            int columns = range.Columns.Count;

            Dictionary<string, List<CustomTable>> data = new Dictionary<string, List<CustomTable>>();
            List<CustomTable> lct = null;
            CustomTable ct = null;
            string prevKey = "";
            for (int i = 2; i <= rows; i++) {
                TblSize size = (TblSize)Enum.Parse(typeof(TblSize), (xlRange.Cells[i, 1].Value2 != null) ? xlRange.Cells[i, 1].Value2.ToString() : TblSize.ERR.ToString());

                string tableCatalog = (xlRange.Cells[i, 2].Value2 != null) ? xlRange.Cells[i, 2].Value2.ToString() : "";
                string tableSchema = (xlRange.Cells[i, 3].Value2 != null) ? xlRange.Cells[i, 3].Value2.ToString() : "";
                string tableName = (xlRange.Cells[i, 4].Value2 != null) ? xlRange.Cells[i, 4].Value2.ToString() : "";
                string key = size.ToString() + HYPHEN + tableCatalog + DOT + tableSchema + DOT + tableName;

                if (key != prevKey) {
                    if (ct != null) {
                        lct.Add(ct);
                        data.Add(prevKey, lct);
                    }

                    prevKey = key;

                    ct = new CustomTable();
                    lct = new List<CustomTable>();
                } else {
                    lct.Add(ct);
                }

                ct = new CustomTable();
                ct.TableCatalog = (xlRange.Cells[i, 2].Value2 != null) ? xlRange.Cells[i, 2].Value2.ToString() : "";
                ct.TableSchema = (xlRange.Cells[i, 3].Value2 != null) ? xlRange.Cells[i, 3].Value2.ToString() : "";
                ct.TableName = (xlRange.Cells[i, 4].Value2 != null) ? xlRange.Cells[i, 4].Value2.ToString() : "";
                ct.ColumnName = (xlRange.Cells[i, 5].Value2 != null) ? xlRange.Cells[i, 5].Value2.ToString() : "";
                ct.OldDataType = (xlRange.Cells[i, 6].Value2 != null) ? xlRange.Cells[i, 6].Value2.ToString() : "";
                ct.NewDataType = (xlRange.Cells[i, 7].Value2 != null) ? xlRange.Cells[i, 7].Value2.ToString() : "";

            }

            if (!String.IsNullOrEmpty(prevKey) && lct.Count > 0) {
                lct.Add(ct);
                data.Add(prevKey, lct);
            }

            //cleanup
            GC.Collect();
            GC.WaitForPendingFinalizers();

            //rule of thumb for releasing com objects:
            //  never use two dots, all COM objects must be referenced and released individually
            //  ex: [somthing].[something].[something] is bad
            //release com objects to fully kill excel process from running in the background
            Marshal.ReleaseComObject(xlRange);
            Marshal.ReleaseComObject(xlWorksheet);

            //close and release
            xlWorkbook.Close();
            Marshal.ReleaseComObject(xlWorkbook);
            xlApp.Application.DisplayAlerts = true;
            xlApp.AutomationSecurity = oldSecurity;

            //quit and release
            xlApp.Quit();
            Marshal.ReleaseComObject(xlApp);

            return data;
        }


    }
}
