using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using DataHub.Commons;

namespace DataHub.Orchestrator
{
    public class SvcOrchestratorStartup {

        public SvcOrchestratorStartup(IConfiguration configuration)
        {
            Configuration = configuration;
        }

        public IConfiguration Configuration { get; }

        // This method gets called by the runtime. Use this method to add services to the container.
        public void ConfigureServices(IServiceCollection services)
        {
            services.Configure<DataHubServicesUrls>(options => Configuration.GetSection("DataHubServicesUrls").Bind(options));
            services.Configure<DbEnvSettings>(options => Configuration.GetSection("DbEnvSettings").Bind(options));
            services.AddMvc(options => options.OutputFormatters.Add(new HtmlOutputFormatter()));
            services.AddMvc();
        }

        // This method gets called by the runtime. Use this method to configure the HTTP request pipeline.
        public void Configure(IApplicationBuilder app, IHostingEnvironment env)
        {
            if (env.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
            }

            app.UseMvc();
        }
    }
}
