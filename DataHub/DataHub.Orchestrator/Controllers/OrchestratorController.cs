using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using DataHub.Commons;
using Microsoft.Extensions.Options;
using DataHub.Models;
using System.Net;
using System.Net.Http;
using Newtonsoft.Json;
using System.Text;
using System.IO;

namespace DataHub.Orchestrator.Controllers
{
    [Route("Orchestrator")]
    public class OrchestratorController : Controller
    {
        DataHubServicesUrls _urls;

        public OrchestratorController(IOptions<DataHubServicesUrls> urls) {
            _urls = urls.Value;
        }

        [HttpGet("StartCheck/{numRecs}")]
        public List<TimeHistDetail> StartCheck(int numRecs) {
            string data = "";
            string url = "";

            List<Recalc> recalcs = new List<Recalc>();
            url = _urls.UrlSvcRecalcs+"TopN/"+ numRecs;
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
            data = PostData<Recalc>(url,recalcs);
            List<TimeHistDetail> timecards = JsonConvert.DeserializeObject<List<TimeHistDetail>>(data);

            return timecards;

        }

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

            url = _urls.UrlSvcKafkaPub + "PostToKafka";
            data = PostData<TimeHistDetail>(url, timecards);

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


        [Produces("text/html")]
        [HttpGet("GetUrls")]
        public string GetUrls() {
            string msg = "<html><font face=\"verdana\"><p><strong>Woohoo!</strong> You made it...</p>" +
                "<p>This is the Peoplenet DataHub Service : <strong>Orchestrator Service URL Info</strong></p><p>&nbsp;</p>" +
                "<p>The Urls for the API Calls:</p>" +
                "<ul><li><p>"+ _urls.UrlSvcRecalcs + "</p></li></ul>" +
                "<ul><li><p>" + _urls.UrlSvcTimeCard + "</p></li></ul>" +
                "<ul><li><p>" + _urls.UrlSvcKafkaPub + "</p></li></ul>" +
                "</font></ html > ";
            return msg;
        }

        [Produces("text/html")]
        [HttpGet("/Version")]
        public string Version() {
            string msg = "<html><font face=\"verdana\"><p><strong>Woohoo!</strong> You made it...</p>" +
                "<p>This is the Peoplenet DataHub Service : <strong>Orchestrator Service</strong></p><p>&nbsp;</p>" +
                "<p>Here are the relevant API Calls:</p>" +
                "<ul><li><p>/Orchestrator/StartProcess/10</p></li></ul></font></ html > ";
            return msg;
        }
    }
}
