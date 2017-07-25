﻿using System;
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
        //const string TMPL_ST_STR = "TemplateStart";
        const string COL_END_NUM_STR = "ColEndNum";
        const string DB_STR = "Database";
        const string SP_STR = "StoredProc";
        const string DATE_FORMAT = "yyyyMMddHHmmss";
        const string SP_COLS = "{0}_{1}_{2}.csv";
        const string DUMMY = "dummy_{0}.csv";
        const string COL_SEP = ",";
        const string SPACE = " ";
        const string NEWLINE = "\n";
        const string DQUOTE = "\"";
        const string SQUOTE = "'";
        const string EQUALSTO = "=";
        const string BLANK = "";
        const string BANG = "!";
        const string COMMA = ",";
        const string PIPE = "|";

        public class XlData {
            string _dbName;
            string _spName;
            List<string> _lines;

            public string DbName { get => _dbName; set => _dbName = value; }
            public string SpName { get => _spName; set => _spName = value; }
            public List<string> Lines { get => _lines; set => _lines = value; }
        }

        public static void Main(string[] args) {

            Kicker k = new Kicker();
            string inputDir = @"C:\Users\sachin.jain\Google Drive\#PeopleNet-Work\Reporting Project\Report Templates";

            foreach (string file in System.IO.Directory.EnumerateFiles(inputDir)) {
                Console.WriteLine("Processing: " + file);
                XlData xld = k.getExcelData(file);
                if (xld != null) {
                    string outFile = string.Format(SP_COLS, xld.DbName, xld.SpName, DateTime.Now.ToString(DATE_FORMAT));
                    System.IO.File.WriteAllLines(outFile, xld.Lines);
                } else {
                    string outFile = string.Format(DUMMY, DateTime.Now.ToString(DATE_FORMAT));
                    System.IO.File.WriteAllLines(outFile, new List<string>() { "dummy" });
                }
            }


        }

        static Dictionary<int, int> getCellPosition(Excel.Range xlRange, string searchStr) {
            Dictionary<int, int> kv = new Dictionary<int, int>();
            Excel.Range xlSubRange = xlRange.Find(searchStr, Missing.Value, Excel.XlFindLookIn.xlValues);
            if (xlSubRange == null)
                return null;
            kv.Add(xlSubRange.Row, xlSubRange.Column);
            return kv;
        }

        static Dictionary<int, int> getHeaderCellPosition(Excel.Range xlRange) {
            Dictionary<int, int> kv = new Dictionary<int, int>();
            //report definition starts from 3
            //and the header row will be available in the first 10 rows and we will check from 2nd column
            bool found = false;
            int J = 2;
            LOOP_AGAIN:
            for (int i = 3; i <= 10; i++) {
                if (xlRange.Cells[i, J].Value2 != null) {
                    kv.Add(i, 1);
                    found = true;
                    break;
                }
            }
            if (!found && J < 4) {
                J += 1;
                goto LOOP_AGAIN;
            }
            return kv;
        }

        static List<string> getColumnList(string dbName, string spName, Excel.Range xlRange, int colEndNum, int hdrStartNum, int dtlStartNum) {
            List<string> lines = new List<string>();
            for (int i = 1; i <= colEndNum; i++) {
                if (xlRange.Cells[hdrStartNum, i].Value2 != null) {
                    string h = (xlRange.Cells[hdrStartNum, i].Value2 == null) ? BLANK : xlRange.Cells[hdrStartNum, i].Value2.ToString();
                    string d = (xlRange.Cells[dtlStartNum, i].Value2 == null) ? BLANK : xlRange.Cells[dtlStartNum, i].Value2.ToString();

                    h = replaceStr(h, NEWLINE, SPACE);
                    d = replaceStr(d, NEWLINE, SPACE);

                    if (h.StartsWith(EQUALSTO))
                        h = SQUOTE + h;
                    if (d.StartsWith(EQUALSTO))
                        d = SQUOTE + d;

                    h = replaceStr(h, DQUOTE, BLANK);
                    d = replaceStr(d, DQUOTE, BLANK);

                    h = replaceStr(h, BANG, BLANK);
                    d = replaceStr(d, BANG, BLANK);

                    if (h.Contains(COMMA))
                        h = DQUOTE + h + DQUOTE;
                    if (d.Contains(COMMA))
                        d = DQUOTE + d + DQUOTE;

                    lines.Add(dbName + COL_SEP + spName + COL_SEP + h + COL_SEP + d);
                }
            }
            return lines;
        }

        static string replaceStr(string inStr, string toFind, string toReplace) {
            if (inStr.Contains(toFind))
                inStr = inStr.Replace(toFind, toReplace);
            return inStr;
        }

        public XlData getExcelData(string file) {

            //Create COM Objects. Create a COM object for everything that is referenced
            Excel.Application xlApp = new Excel.Application();
            var oldSecurity = xlApp.AutomationSecurity;
            xlApp.AutomationSecurity = Microsoft.Office.Core.MsoAutomationSecurity.msoAutomationSecurityForceDisable;
            xlApp.Application.DisplayAlerts = false;
            Excel.Workbook xlWorkbook = xlApp.Workbooks.Open(Filename: file, ReadOnly: true);
            Excel.Worksheet xlWorksheet = xlWorkbook.Sheets[1];
            Excel.Range xlRange = xlWorksheet.UsedRange;

            xlRange.Rows.EntireRow.Hidden = false;
            xlRange.Rows.EntireColumn.Hidden = false;

            Dictionary<int, int> kvDtl = getCellPosition(xlRange, DTL_STR);
            Console.WriteLine("");
            if (kvDtl == null)
                return null;
            Dictionary<int, int> kvHdrSt = getHeaderCellPosition(xlRange);
            Dictionary<int, int> kvColEndNum = getCellPosition(xlRange, COL_END_NUM_STR);
            Dictionary<int, int> kvDb = getCellPosition(xlRange, DB_STR);
            Dictionary<int, int> kvSp = getCellPosition(xlRange, SP_STR);

            XlData xld = new XlData();
            xld.DbName = xlRange.Cells[kvDb.ElementAt(0).Key + 1, kvDb.ElementAt(0).Value].Value2.ToString();
            xld.SpName = xlRange.Cells[kvSp.ElementAt(0).Key + 1, kvSp.ElementAt(0).Value].Value2.ToString();

            int colEndNum = Int32.Parse(xlRange.Cells[kvColEndNum.ElementAt(0).Key + 1, kvColEndNum.ElementAt(0).Value].Value2.ToString());
            int hdr = kvHdrSt.ElementAt(0).Key;
            int dtl = kvDtl.ElementAt(0).Key;

            xld.Lines = getColumnList(xld.DbName, xld.SpName, xlRange, colEndNum, hdr, dtl);

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

            return xld;

        }
    }
}
