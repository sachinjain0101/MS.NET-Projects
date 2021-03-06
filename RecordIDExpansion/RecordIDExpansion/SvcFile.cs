﻿using log4net;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Security.AccessControl;
using System.Text.RegularExpressions;

namespace RecordIDExpansion {
    public class SvcFile {
        private static ILog LOGGER = LogManager.GetLogger(typeof(SvcFile));

        public static void CreateDirs(string dir) {
            if (Directory.Exists(dir))
                Directory.Delete(dir, true);
            //DirectoryInfo dInfo = new DirectoryInfo(dir);
            DirectorySecurity dSecurity = new DirectorySecurity();// dInfo.GetAccessControl();
            dSecurity.AddAccessRule(new FileSystemAccessRule("everyone", FileSystemRights.FullControl,
                               InheritanceFlags.ObjectInherit | InheritanceFlags.ContainerInherit,
                               PropagationFlags.NoPropagateInherit, AccessControlType.Allow));
            //dInfo.SetAccessControl(dSecurity);
            Directory.CreateDirectory(dir, dSecurity);
        }

        public static void CopyFiles(string dir, List<String> lstVals) {
            string[] files = Directory.GetFiles(@dir);


            /*
            List<String> lst = new List<string>();
            foreach (string f in files)
                lst.Add(Path.GetFileNameWithoutExtension(f));

            List<string> ll = lstVals;
            ll.RemoveAll(e => lst.Contains(e));
            */

            foreach (string val in lstVals) {
                string f = Constants.TFS_TH_TRUNK_DIR + val + Constants.EXT;
                string tfsPath = Constants.EXP_PATH_TFS + val + Constants.EXT;
                string sqlPath = Constants.EXP_PATH_SQL + val + Constants.EXT;

                int pos = Array.FindIndex(files, x => x == f);
                if (pos >= 0) {
                    File.Copy(files[pos], tfsPath, true);
                    File.Copy(files[pos], sqlPath, true);
                }
            }
        }

        public static List<string> GetDiffSize(string dir) {
            string[] files = Directory.GetFiles(dir);
            List<string> sizeDict = new List<string>();
            foreach (string f in files) {
                long size = new FileInfo(f).Length;
                //LOGGER.Info("\t" + f + " = " + size.ToString());
                if (size <= 10000)
                    sizeDict.Add(f);
            }
            return sizeDict;
        }

        public static List<String> ReplaceString(List<String> lstVals, string oldStr, string newStr) {
            List<String> newLstVals = new List<string>();
            foreach (string s in lstVals) {
                newLstVals.Add(s.Replace(oldStr,newStr));
            }
            return newLstVals;
        }

        public static void ReplaceString(string dir, List<String> lstVals) {
            string[] newfiles = Directory.GetFiles(Constants.EXP_PATH_TFS);
            Regex rgx = null;
            foreach (string f in newfiles) {
                // Replacing Alter with Create
                var fileContents = System.IO.File.ReadAllText(@f);
                string atlerPat = "(ALTER|Alter|alter)\\s+(Procedure|PROCEDURE|procedure|PROC|Proc|proc)";
                rgx = new Regex(atlerPat);
                fileContents = rgx.Replace(fileContents, "Create PROCEDURE");
                File.WriteAllText(@f, fileContents);
            }
        }

        public static void RemoveLastLine(string dir, List<string> lstVals, StmtType stmtType) {
            string[] newfiles = Directory.GetFiles(dir);
            Regex rgx = null;
            string pat = "";
            switch (stmtType) {
                case StmtType.GO:
                    pat = "(GO|Go|go)";
                    break;
            }
            rgx = new Regex(pat);
            foreach (string f in newfiles) {
                string[] lines = File.ReadAllLines(f);
                if (rgx.IsMatch(lines[lines.Length - 1]))
                    File.WriteAllLines(@f, lines.Take(lines.Length - 1).ToArray());
            }
        }

        public static void ModifyFiles(string dir, List<string> lstVals, StmtType stmtType) {
            string[] newfiles = Directory.GetFiles(dir);
            Regex rgx = null;
            string createPat = "";
            switch (stmtType) {
                case StmtType.ALTER:
                    createPat = "(ALTER|Alter|alter)\\s+(Procedure|PROCEDURE|procedure|PROC|Proc|proc)";
                    break;
                case StmtType.CREATE:
                    createPat = "(CREATE|Create|create)\\s+(Procedure|PROCEDURE|procedure|PROC|Proc|proc)";
                    break;
            }
            foreach (string f in newfiles) {

                rgx = new Regex(createPat);
                var lines = File.ReadAllLines(f);
                int pos = 0;
                foreach (string line in lines) {
                    if (rgx.IsMatch(line))
                        break;
                    pos++;
                }
                if (pos == lines.Length)
                    LOGGER.Info(Constants.WHITE_SEP + f + " : No change to be done");
                else
                    File.WriteAllLines(@f, lines.Skip(pos).ToArray());
            }
        }

        public static void CreateFiles(List<String> files) {
            foreach (string f in files) {
                string opFname = Constants.EXP_PATH_DIFF + Path.GetFileName(f) + ".LOG";
                CreateFile(opFname);
            }
        }

        public static void CreateFile(string file) {
            try {
                if (File.Exists(file))
                    File.Delete(file);
                File.Create(file);

            } catch (Exception e) {
                LOGGER.Info(e.StackTrace);
            }
        }

        public static void DiffFiles(string dir1, string dir2) {
            List<string> lst1 = Directory.GetFiles(dir1).Select(Path.GetFileName).ToList<string>();
            List<string> lst2 = Directory.GetFiles(dir2).Select(Path.GetFileName).ToList<string>();
            LOGGER.Info(Constants.LONG_SEP);
            foreach (string f1 in lst1) {
                if (lst2.Contains(f1)) {
                    Diff(Constants.EXP_PATH_DB + f1, Constants.EXP_PATH_TFS + lst2.Find(item => item == f1));
                    LOGGER.Info(Constants.LONG_SEP);
                }
            }
        }

        public static void Diff(string f1, string f2) {
            try {
                string opFname = Constants.EXP_PATH_DIFF + Path.GetFileName(f2);
                string args = string.Format(Constants.DIFF_STR, f1, f2);
                //var psi = new ProcessStartInfo(@"C:\\Program Files\\ExamDiff Pro\\ExamDiff.exe") {
                var psi = new ProcessStartInfo(@"fc.exe") {
                    Arguments = @args,
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    RedirectStandardOutput = true
                };
                Process p = Process.Start(psi);
                string op = p.StandardOutput.ReadToEnd();
                LOGGER.Info(op);
                File.WriteAllText(opFname, op);
                //p.WaitForExit();
                //p.Kill();
            } catch (Exception e) {
                LOGGER.Info(e.StackTrace);
            }
        }
    }

}
