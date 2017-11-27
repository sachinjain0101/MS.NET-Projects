using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using DataHub.Models;
using DataHub.Commons;
using Microsoft.Extensions.Options;
using Confluent.Kafka;
using Confluent.Kafka.Serialization;
using System.Text;
using Newtonsoft.Json;
using log4net;
using System.Reflection;

namespace DataHub.SvcKafkaPublisher.Services
{
    public class KafkaPubService : IKafkaPubService {

        private static readonly ILog LOGGER = LogManager.GetLogger(MethodBase.GetCurrentMethod().DeclaringType);
        private KafkaEnvSettings _settings;

        public KafkaPubService(IOptions<KafkaEnvSettings> settings) {
            _settings = settings.Value;
        }

        public bool PublishData(List<TimeHistDetail> thds) {

            string brokerList = _settings.KafkaBrokers;
            string topicName = _settings.KafkaTopics;

            List<string> list = new List<string>();

            foreach (TimeHistDetail thd in thds) {
                string text = JsonConvert.SerializeObject(thd);
                list.Add(text);
            }

            var config = new Dictionary<string, object> { { "bootstrap.servers", brokerList } };

            config.Add("acks", "all");
            config.Add("retries", 0);
            config.Add("linger.ms", 1);

            using (var producer = new Producer<string, string>(config, new StringSerializer(Encoding.UTF8), new StringSerializer(Encoding.UTF8))) {
                int cntr = 0;
                foreach (string text in list) {

                    var key = "";
                    var val = text;
                    int index = text.IndexOf(" ");
                    if (index != -1) {
                        key = text;
                        val = text;
                    }

                    LOGGER.Info(text);
                    if (cntr < 1) {
                        var deliveryReport = producer.ProduceAsync(topicName, key, val);
                        var result = deliveryReport.Result; // synchronously waits for message to be produced.
                        LOGGER.Info("First Message Published {Partition: "+ result.Partition+", Offset:"+result.Offset+"}");
                    } else
                        producer.ProduceAsync(topicName, key, val);
                    cntr++;
                }
            }

            return false;
        }

    }
}
