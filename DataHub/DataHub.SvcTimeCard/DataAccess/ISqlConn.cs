using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Linq;
using System.Threading.Tasks;

namespace DataHub.SvcTimeCard.DataAccess
{
    public interface ISqlConn
    {

        SqlConnection GetConnection();

    }
}
