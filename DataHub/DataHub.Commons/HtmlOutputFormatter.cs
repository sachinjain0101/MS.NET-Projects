using Microsoft.AspNetCore.Mvc.Formatters;
using System;

namespace DataHub.Commons
{
    public class HtmlOutputFormatter : StringOutputFormatter {
        public HtmlOutputFormatter() {
            SupportedMediaTypes.Add("text/html");
        }
    }
}
