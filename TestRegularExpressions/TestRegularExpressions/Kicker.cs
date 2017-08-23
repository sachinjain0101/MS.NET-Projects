using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace TestRegularExpressions {
    class TestRegEx {
        static void Main() {
            string[] sentences =
            {
            "CREATE   TRIGGER ",
            "CREATE TRIGGER ",
            "create triggers",
            "createtrigger",
            "insert  into",
            "insert ",
            "insert into ",
            "insertinto"
            };

            string str = @"TimeHistory,usp_RPT_YOH_Holiday,Employee Name,""LastName, FirstName""";
            Console.WriteLine(str);
            string[] arr = Regex.Split(str, @",");

            List<string> lst = Regex.Matches(str, @"\w+|""[\w,]*""") .Cast<Match>() .Select(m => m.Value) .ToList();


            string[] sen = { "RecordId int", "RecordId  INT", "[RecordId] [int]","[RecordID]  [int]","[RecordID] [int]"};

            string pattern = @"create[\s]+trigger\b|insert[\s]+into\b";

            foreach (string s in sentences) {
                System.Console.Write("{0,24}", s);

                if (System.Text.RegularExpressions.Regex.IsMatch(s, pattern, System.Text.RegularExpressions.RegexOptions.IgnoreCase)) {
                    System.Console.WriteLine("  (match for '{0}' found)", pattern);
                } else {
                    System.Console.WriteLine();
                }
            }

            System.Console.WriteLine("");
            System.Console.WriteLine("");

            string pat = @"recordid\b[\s]+int\b|\[recordid\b\][\s]+\[int\b\]";

            foreach (string s in sen) {
                System.Console.Write("{0,24}", s);

                if (System.Text.RegularExpressions.Regex.IsMatch(s, pat, System.Text.RegularExpressions.RegexOptions.IgnoreCase)) {
                    System.Console.WriteLine("  (match for '{0}' found)", pat);
                    System.Console.WriteLine("{0,24}",Regex.Replace(s, pat, "[RECORDID] [bigint]", RegexOptions.IgnoreCase));
                } else {
                    System.Console.WriteLine();
                }
            }

            // Keep the console window open in debug mode.
            System.Console.WriteLine("Press any key to exit.");
            System.Console.ReadKey();

        }
    }
}
