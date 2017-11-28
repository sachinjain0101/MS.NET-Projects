using DataHub.Commons;
using Microsoft.Extensions.Options;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Linq;
using System.Threading.Tasks;

namespace DataHub.SvcTimeCard.DataAccess
{
    public class SqlConn : ISqlConn {

        private DbEnvSettings _settings;
        //public SqlConnection Conn { get; set; }

        public SqlConn(IOptions<DbEnvSettings> settings) {
            _settings = settings.Value;
        }
        public SqlConnection GetConnection() {
            return new SqlConnection(_settings.ConnStrTimeHistory);
        }

    }
}
