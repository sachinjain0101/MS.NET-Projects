using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FileNameSplitter {
    class Kicker {
        static void Main(string[] args) {

            string dir = @"C:\Users\sachin.jain\Google Drive\#PeopleNet-Work\Reporting Project\Report Templates_";
            foreach (string file in System.IO.Directory.GetFiles(dir)) {
                string fileName = System.IO.Path.GetFileNameWithoutExtension(file);

                string repName = "";
                string repCode = "";
                string repOrder = "";

                string[] split1 = fileName.Split('_');
                string[] split2 = { };

                if (split1.Length > 1) {
                    split2 = split1[1].Split(new string[] { "By" }, StringSplitOptions.None);
                    if(split2.Length > 1) {
                        repOrder = split2[1];
                    }
                    repCode = split2[0];
                }
                repName = split1[0];

                Console.WriteLine(repName+" - "+ repCode +" - "+repOrder);
            }

            Console.WriteLine("");
        }
    }
}
