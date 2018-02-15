using System;
using System.Collections.Generic;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace Opera.Test.NestedJson {
    class NestedJson {


        static Dictionary<String, String> FlattenJson(String str) {
            Dictionary<String, String> dict = new Dictionary<string, string>();
            JObject o = JObject.Parse(str);
            foreach (JToken t in o.Children()) {
                if (!IsValidJson(t.First.ToString())) {
                    dict.Add(t.Path, t.First.ToString());
                } else {
                    dict = FlattenJson(t.First.ToString());
                }
            }
            return dict;
        }

        static void Main(string[] args) {
            string nestedJson = @"{'A':'1','B':'2','C': {'AA':'11','BB':'BB','CC':{'AAA':'111', 'BBB':'222'}}}";



            Dictionary<String, String> dict = FlattenJson(nestedJson);


            JObject jObject = JObject.Parse(nestedJson);

            foreach (JToken token in jObject.Children()) {
                string s = token.First.ToString();
                if (IsValidJson(s)) {
                    JObject o = JObject.Parse(s);
                    foreach (JToken t in o.Children()) {
                        Console.WriteLine(t.Path + " = " + t.First);
                    }

                }
                Console.WriteLine(token.Path + " = " + token.First);
            }

            Console.ReadLine();
        }


        private static bool IsValidJson(string strInput) {
            strInput = strInput.Trim();
            if ((strInput.StartsWith("{") && strInput.EndsWith("}")) || //For object
                (strInput.StartsWith("[") && strInput.EndsWith("]"))) //For array
            {
                try {
                    var obj = JToken.Parse(strInput);
                    return true;
                } catch (JsonReaderException jex) {
                    //Exception in parsing json
                    Console.WriteLine(jex.Message);
                    return false;
                } catch (Exception ex) //some other exception
                  {
                    Console.WriteLine(ex.ToString());
                    return false;
                }
            } else {
                return false;
            }
        }
    }
}
