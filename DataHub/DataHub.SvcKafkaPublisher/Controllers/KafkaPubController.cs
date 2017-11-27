using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using DataHub.SvcKafkaPublisher.Services;
using DataHub.Models;
using DataHub.Commons;
using Microsoft.Extensions.Options;
using System.Net;
using System.IO;
using Newtonsoft.Json;
using System.Net.Http;
using System.Text;

namespace DataHub.SvcKafkaPublisher.Controllers
{
    [Route("KafkaPub")]
    public class KafkaPubController : Controller
    {

        IKafkaPubService _kafkaPubService;
        DataHubServicesUrls _urls;

        public KafkaPubController(IKafkaPubService kafkaPubService, IOptions<DataHubServicesUrls> urls) {
            _kafkaPubService = kafkaPubService;
            _urls = urls.Value; ;
        }

        [HttpPost("PostToKafka")]
        public string PostToKafka(List<TimeHistDetail> thds)
        {
            _kafkaPubService.PublishData(thds);
            return "done";
        }

        [Produces("text/html")]
        [HttpGet("/Version")]
        public string Version() {
            string msg = "<html><font face=\"verdana\"><p><strong>Woohoo!</strong> You made it...</p>" +
                "<p>This is the Peoplenet DataHub Service : <strong>Kafka Publisher Service</strong></p><p>&nbsp;</p>" +
                "<p>Here are the relevant API Calls:</p>" +
                "<ul><li><p>/KafkaPub/{RecordId}</p></li><li><p>/KafkaPub/Version</p></li></ul></font></ html > ";
            return msg;
        }






        //////////////////////////////////////////////////////////////////////////////////////////////////////////
        [HttpGet("StartProcess/{numRecs}")]
        public List<TimeHistDetail> StartProcess(int numRecs) {
            string data = "";
            string url = "";

            List<Recalc> recalcs = new List<Recalc>();
            url = _urls.UrlSvcRecalcs + "TopN/" + numRecs;
            url = String.Format(url, numRecs);
            var webRequest = System.Net.WebRequest.Create(url);
            if (webRequest != null) {
                webRequest.Method = WebRequestMethods.Http.Get;
                webRequest.ContentType = "application/json";
                using (var reponse = webRequest.GetResponse().GetResponseStream())
                using (var reader = new StreamReader(reponse))
                    recalcs = JsonConvert.DeserializeObject<List<Recalc>>(reader.ReadToEnd());
            }

            url = _urls.UrlSvcTimeCard + "GetPostTimeCards";
            data = PostData<Recalc>(url, recalcs);
            List<TimeHistDetail> timecards = JsonConvert.DeserializeObject<List<TimeHistDetail>>(data);

            _kafkaPubService.PublishData(timecards);
            
            return timecards;

        }

        private string PostData<T>(string url, List<T> jsonList) {
            WebRequest webRequest = WebRequest.Create(url);
            StringContent content = new StringContent(JsonConvert.SerializeObject(jsonList), Encoding.UTF8, "application/json");
            Task<byte[]> t = content.ReadAsByteArrayAsync();
            var byteContent = t.Result;
            if (webRequest != null) {
                webRequest.Method = WebRequestMethods.Http.Post;
                webRequest.ContentType = "application/json";

                using (Stream dataStream = webRequest.GetRequestStream())
                    dataStream.Write(byteContent, 0, byteContent.Length);

                using (var reponse = webRequest.GetResponse().GetResponseStream())
                using (var reader = new StreamReader(reponse))
                    return reader.ReadToEnd();
            }
            return "";
        }


        //////////////////////////////////////////////////////////////////////////////////////////////////////////




    }
}
