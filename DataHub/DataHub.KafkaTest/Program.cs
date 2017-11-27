using Confluent.Kafka;
using Confluent.Kafka.Serialization;
using DataHub.Models;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Threading;

namespace DataHub.KafkaTest {
    public class Program {
        public static void Main(string[] args) {

            string brokerList = "pnet-kafka1.eastus2.cloudapp.azure.com:6667,pnet-kafka2.eastus2.cloudapp.azure.com:6667,pnet-kafka3.eastus2.cloudapp.azure.com:6667";
            string topicName = "pnet-dw-perf";

            List<TimeHistDetail> thds = new List<TimeHistDetail>();
            for (int i = 1; i <= 10000; i++) {
                TimeHistDetail thd = new TimeHistDetail();
                thd.RecordID = i;
                thd.Client = "X" + i.ToString();
                thds.Add(thd);
            }

            List<string> list = new List<string>();

            foreach (TimeHistDetail thd in thds) {
                string text = JsonConvert.SerializeObject(thd);
                list.Add(text);
            }

            var config = new Dictionary<string, object> { { "bootstrap.servers", brokerList } };

            config.Add("acks", "all");
            config.Add("retries", 0);
            //config.Add("batch.size", 16384);
            config.Add("linger.ms", 1);
            //config.Add("buffer.memory", 33554432);
            //config.Add("key.serializer", "org.apache.kafka.common.serialization.StringSerializer");
            //config.Add("value.serializer", "org.apache.kafka.common.serialization.StringSerializer");


            using (var producer = new Producer<string, string>(config, new StringSerializer(Encoding.UTF8), new StringSerializer(Encoding.UTF8))) {

                foreach (string text in list) {

                    var key = "";
                    var val = text;
                    // split line if both key and value specified.
                    int index = text.IndexOf(" ");
                    if (index != -1) {
                        key = text;
                        val = text;
                    }

                    var deliveryReport = producer.ProduceAsync(topicName, key, val);
                    //Console.WriteLine(val);
                    //var result = deliveryReport.Result; // synchronously waits for message to be produced.
                    //Console.WriteLine($"Partition: {result.Partition}, Offset: {result.Offset}");
                }
            }

            Console.ReadLine();
        }
    }


}
