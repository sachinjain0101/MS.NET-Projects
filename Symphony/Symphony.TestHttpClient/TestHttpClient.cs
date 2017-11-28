using DataHub.Models;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Threading.Tasks;

namespace DataHub.TestHttpClient {
    class TestHttpClient {
        List<Recalc> _recalcs = new List<Recalc>();

        static void Main(string[] args) {
            Console.WriteLine("Hello World!");
            TestHttpClient p = new TestHttpClient();
            Task<List<Recalc>> t1 = p.GetData();
            t1.Wait();
            var x = t1.Result;

            Task<string> t2 = p.PostData(x);
            t2.Wait();
            var y = t2.Result;
            Console.WriteLine(Environment.NewLine+"&&&&&&&&"+y);

            Console.ReadLine();
        }

        async Task<List<Recalc>> GetData() {
            string baseUrl = "http://localhost:51002/Recalcs/TopN/10";
            string data = "";
            using (HttpClient client = new HttpClient()) {
                using (HttpResponseMessage res = await client.GetAsync(baseUrl))
                using (HttpContent content = res.Content) {
                    data = await content.ReadAsStringAsync();
                    if (data != null) {
                        Console.WriteLine(Environment.NewLine + "====================" + data);
                    }
                    return JsonConvert.DeserializeObject<List<Recalc>>(data);
                }
            }
        }

        async Task<string> PostData(List<Recalc> recalcs) {
            string baseUrl = "http://localhost:51002/Recalcs/UpdateRecalcs";
            string data = "";
            using (HttpClient client = new HttpClient()) {
                client.DefaultRequestHeaders.Accept.Clear();
                client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

                StringContent content = new StringContent(JsonConvert.SerializeObject(recalcs), Encoding.UTF8, "application/json");
                //new StringContent(JsonConvert.SerializeObject(recalcs));

                using (HttpResponseMessage res = await client.PostAsync(baseUrl, content)) {
                    Console.WriteLine(Environment.NewLine + "************" +res.StatusCode);
                    if (res.IsSuccessStatusCode) {
                        data = await res.Content.ReadAsStringAsync();
                        Console.WriteLine(data);
                    }

                    return data;
                }
            }
        }
    }


}


//client.BaseAddress = new Uri("http://localhost:51002/Recalcs/TopN/10");
//client.DefaultRequestHeaders.Accept.Clear();
//                client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

//                // HTTP POST
//                HttpResponseMessage response = await client.PostAsync("api/products/save", data);
//                if (response.IsSuccessStatusCode) {
//                    string d = await response.Content.ReadAsStringAsync();
//product = JsonConvert.DeserializeObject<Product>(data);
//                }