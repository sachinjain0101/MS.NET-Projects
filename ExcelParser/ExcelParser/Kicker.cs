using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;
using Excel = Microsoft.Office.Interop.Excel;       //microsoft Excel 14 object in references-> COM tab

namespace ExcelParser {
    class Kicker {

        const string DTL_STR = "%DTL-";
        const string TMPL_ST_STR = "TemplateStart";
        const string COL_END_NUM_STR = "ColEndNum";
        const string DB_STR = "Database";
        const string SP_STR = "StoredProc";
        const string DATE_FORMAT = "yyyyMMddHHmmss";
        const string SP_COLS = "{0}_{1}_{2}.csv";
        const string COL_SEP = ",";

        public static void Main(string[] args) {
            getExcelFile();
        }

        public static Dictionary<int, int> getCellPosition(Excel.Range xlRange, string searchStr) {
            Dictionary<int, int> kv = new Dictionary<int, int>();
            Excel.Range xlSubRange = xlRange.Find(searchStr, Missing.Value, Excel.XlFindLookIn.xlValues);
            kv.Add(xlSubRange.Row, xlSubRange.Column);
            return kv;
        }

        public static List<string> getColumnList(string dbName, string spName, Excel.Range xlRange, int colEndNum, int hdrStartNum, int dtlStartNum) {
            List<string> lines = new List<string>();
            for (int i = 1; i <= colEndNum; i++) {
                if (xlRange.Cells[hdrStartNum, i].Value2 != null) {
                    string h = xlRange.Cells[hdrStartNum, i].Value2.ToString();
                    string d = xlRange.Cells[dtlStartNum, i].Value2.ToString();
                    h = h.Replace('\n', ' ');
                    d = d.Replace('\n', ' ');

                    if (h.StartsWith("="))
                        h = "'" + h;
                    if (d.StartsWith("="))
                        d = "'" + d;

                    if (h.Contains("\""))
                        h = h.Replace("\"","");
                    if (d.Contains(","))
                        d = d.Replace("\"", "");

                    if (h.Contains(","))
                        h = "\"" + h + "\"";
                    if (d.Contains(","))
                        d = "\"" + d + "\"";

                    lines.Add(dbName + COL_SEP + spName + COL_SEP + h + COL_SEP + d);
                }
            }
            return lines;
        }

        public static void getExcelFile() {

            //Create COM Objects. Create a COM object for everything that is referenced
            Excel.Application xlApp = new Excel.Application();
            xlApp.Application.DisplayAlerts = false;
            Excel.Workbook xlWorkbook = xlApp.Workbooks.Open(@"C:\Users\sachin.jain\Google Drive\#PeopleNet-Work\Reporting Project\BillHour_BHEGByB11_SJ.XLS");
            Excel.Worksheet xlWorksheet = xlWorkbook.Sheets[1];
            Excel.Range xlRange = xlWorksheet.UsedRange;

            Dictionary<int, int> kvDtl = getCellPosition(xlRange, DTL_STR);
            Dictionary<int, int> kvTmplSt = getCellPosition(xlRange, TMPL_ST_STR);
            Dictionary<int, int> kvColEndNum = getCellPosition(xlRange, COL_END_NUM_STR);
            Dictionary<int, int> kvDb = getCellPosition(xlRange, DB_STR);
            Dictionary<int, int> kvSp = getCellPosition(xlRange, SP_STR);

            string dbName = xlRange.Cells[kvDb.ElementAt(0).Key + 1, kvDb.ElementAt(0).Value].Value2.ToString();
            string spName = xlRange.Cells[kvSp.ElementAt(0).Key + 1, kvSp.ElementAt(0).Value].Value2.ToString();

            int colEndNum = Int32.Parse(xlRange.Cells[kvColEndNum.ElementAt(0).Key + 1, kvColEndNum.ElementAt(0).Value].Value2.ToString());
            int hdr = (Int32.Parse(xlRange.Cells[kvTmplSt.ElementAt(0).Key + 1, kvTmplSt.ElementAt(0).Value].Value2.ToString())) - 1;
            int dtl = Int32.Parse(kvDtl.ElementAt(0).Key.ToString());

            List<string> lstCols = getColumnList(dbName, spName, xlRange, colEndNum, hdr, dtl);

            string file = string.Format(SP_COLS, dbName, spName, DateTime.Now.ToString(DATE_FORMAT));

            System.IO.File.WriteAllLines(file, lstCols);

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

            //quit and release
            xlApp.Quit();
            Marshal.ReleaseComObject(xlApp);
        }
    }
}
