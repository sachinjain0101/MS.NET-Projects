using System.Collections.Generic;
using Excel = Microsoft.Office.Interop.Excel;
using System.Runtime.InteropServices;
using log4net;

namespace RecordIDExpansion
{
    public class SvcExcel {
        private static ILog LOGGER = LogManager.GetLogger(typeof(SvcExcel));
        public List<string> ReadSheet(string file, Sheet sheet) {
            List<string> lst = new List<string>();
            Excel.Application xlApp = null;
            Excel.Workbook xlWorkbook = null;
            Excel._Worksheet xlWorksheet = null;
            try {
                xlApp = new Excel.Application();
                xlWorkbook = xlApp.Workbooks.Open(@file);
                switch (sheet) {
                    case Sheet.TIMECURRENT:
                        xlWorksheet = xlWorkbook.Sheets[1];
                        break;
                    case Sheet.TIMEHISTORY:
                        xlWorksheet = xlWorkbook.Sheets[2];
                        break;
                    default:
                        break;
                }
                Excel.Range xlRange = xlWorksheet.UsedRange;
                int rows = xlRange.Rows.Count;
                int cols = xlRange.Columns.Count;

                for (int i = 2; i <= rows; i++) {
                    string val = (string)(xlRange.Cells[i, 1] as Excel.Range).Value2;
                    lst.Add(val);
                }

            } finally {
                xlWorkbook.Close(true, null, null);
                xlApp.Quit();

                Marshal.ReleaseComObject(xlWorksheet);
                Marshal.ReleaseComObject(xlWorkbook);
                Marshal.ReleaseComObject(xlApp);
            }
            return lst;
        }
    }

}
