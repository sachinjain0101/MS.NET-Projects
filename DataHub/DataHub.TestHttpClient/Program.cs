using DataHub.Models;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Net.Http;

namespace DataHub.TestHttpClient
{
    class Program
    {
        List<Recalc> _recalcs = new List<Recalc>();

        static void Main(string[] args)
        {
            Console.WriteLine("Hello World!");
            Program p = new Program();
            p.GetData();
            Console.ReadLine();
        }

        async void GetData() {
            //We will make a GET request to a really cool website...

            string baseUrl = "http://localhost:51002/Recalcs/TopN/10";
            using (HttpClient client = new HttpClient())

            using (HttpResponseMessage res = await client.GetAsync(baseUrl))
            using (HttpContent content = res.Content) {
                string data = await content.ReadAsStringAsync();
                if (data != null) {
                    Console.WriteLine(data);
                }
                this._recalcs = JsonConvert.DeserializeObject<List<Recalc>>(data);
            }
        }
    }
}
