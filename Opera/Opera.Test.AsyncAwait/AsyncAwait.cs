using System;
using System.Globalization;
using System.Threading;
using System.Threading.Tasks;

namespace Opera.Test.AsyncAwait
{
    class AsyncAwait {
        static void Main(string[] args)
        {
            Console.WriteLine("Hello World!");

            string MinHours = "01.25";

            if (!string.IsNullOrEmpty(MinHours)) {
                decimal number;
                if (Decimal.TryParse(MinHours, out number))
                    MinHours = Math.Round(Convert.ToDouble(number), 2).ToString();
                else
                    MinHours = "0.00";
            } else {
                MinHours = "";
            }

            Console.WriteLine(MinHours);

            //Console.WriteLine(MinHours.Trim().Substring(0, 2));

            //Console.WriteLine((MinHours != "") ? Convert.ToDouble(MinHours) : 0.00);


            DoSomeWorkAsync("sachin");

            Console.ReadLine();
        }

        public static async void DoSomeWorkAsync(string name) {

            Task<string> t = Task<string>.Factory.StartNew(() => DoSomeWork(name));

            Console.WriteLine("waiting for task to get over....");
            await t;
            Console.WriteLine(t.Result);

            
        }

        public static string DoSomeWork(string name) {
            Thread.Sleep(3000);
            return "Hi," + name;
        }



    }
}
