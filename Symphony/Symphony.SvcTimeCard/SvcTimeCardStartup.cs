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
using Microsoft.EntityFrameworkCore;
using DataHub.SvcTimeCard.DataAccess;
using DataHub.SvcTimeCard.Services;

namespace DataHub.SvcTimeCard {
    public class SvcTimeCardStartup {
        public SvcTimeCardStartup(IConfiguration configuration)
        {
            Configuration = configuration;
        }

        public IConfiguration Configuration { get; }

        // This method gets called by the runtime. Use this method to add services to the container.
        public void ConfigureServices(IServiceCollection services)
        {
            services.Configure<DbEnvSettings>(options => Configuration.GetSection("DbEnvSettings").Bind(options));
            services.AddDbContext<TimeCardContext>(options => options.UseSqlServer(Configuration.GetConnectionString("TimeHistory")));
            services.AddMvc(options => options.OutputFormatters.Add(new HtmlOutputFormatter()));
            services.RegisterServices();
            services.AddTransient<ITimeCardService, TimeCardService>();
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

    public static class ServiceCollectionExtensions {
        public static IServiceCollection RegisterServices(this IServiceCollection services) {
            services.AddTransient<ISqlConn,SqlConn>();
            return services;
        }
    }

}
