using Avalara.AvaTax.RestClient;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.IO;

public class Program {
    public static void Main(string[] args) {
        // Create a client and set up authentication
        var Client = new AvaTaxClient("PeoplenetAddressCheck", "1.0", Environment.MachineName, AvaTaxEnvironment.Sandbox)
            .WithSecurity("tim.adcock@peoplenet.com", "FC5C68100D");

        // Verify that we can ping successfully
        var pingResult = Client.Ping();
        if ((bool)pingResult.authenticated) {
            Console.WriteLine("Success!");
        }

        string strConnection = ConfigurationManager.ConnectionStrings["CigOrders"].ToString();

        List<string> lines = new List<string>();
        foreach (Address a in DBOps.GetAddressses(strConnection))
            lines.Add(a.ValidatePNetAddress(Client, a));

        lines.Sort();

        FileOps.LogData(lines);

        Console.ReadLine();
    }
}

public class FileOps {
    const string OUTPUT_FILE = "Peoplenet_AddressValidation_{0}.csv";
    public static string OutputFile => OUTPUT_FILE;

    public static void LogData(List<string> lines) {
        DateTime time = DateTime.Now;
        string format = "yyyyMMddHHmm";

        string file = Environment.CurrentDirectory + "\\" + String.Format(OutputFile, time.ToString(format));
        if (!File.Exists(file))
            File.WriteAllLines(file, lines);

    }
}


public class DBOps {
    //const string sql = "SELECT DISTINCT Client, GroupCode, SiteNo, SiteAddr1, SiteAddr2, SiteCity, SiteState, SiteZip FROM CigOrders..tblProdAddress";
    const string sql = "SELECT 'DAVT' AS Client, 0 as GroupCode, 0 as SiteNo, '640 Martin Luther King Jr Blvd' AS SiteAddr1, '' As SiteAddr2, 'Macon' As SiteCity, 'GA' AS SiteState, '31201' As SiteZip UNION "+
                       "SELECT 'DAVT' AS Client, 0 as GroupCode, 0 as SiteNo, '640 Martin Luther King Jr' AS SiteAddr1, '' As SiteAddr2, 'Macon' As SiteCity, 'GA' AS SiteState, '31201' As SiteZip";

    public static string Sql => sql;

    public static List<Address> GetAddressses(string connStr) {
        List<Address> addresses = new List<Address>();
        using (SqlConnection connection = new SqlConnection(connStr)) {
            SqlCommand cmd = new SqlCommand(Sql, connection);
            connection.Open();
            using (SqlDataReader rdr = cmd.ExecuteReader()) {
                if (rdr.HasRows.Equals(true)) {
                    while (rdr.Read()) {
                        addresses.Add(new Address(rdr["Client"].ToString()
                                                , rdr["GroupCode"].ToString()
                                                , rdr["SiteNo"].ToString()
                                                , rdr["SiteAddr1"].ToString()
                                                , rdr["SiteAddr2"].ToString()
                                                , rdr["SiteCity"].ToString()
                                                , rdr["SiteState"].ToString()
                                                , rdr["SiteZip"].ToString()
                                                 ));
                    }
                }
            }
        }
        return addresses;
    }
}

public class Address {
    string client;
    string groupCode;
    string siteNo;
    string line1;
    string line2;
    const string line3 = "";
    string city;
    string region;
    string postalcode;
    const string country = "US";
    const TextCase addrCase = TextCase.Mixed;
    const decimal lat = 0;
    const decimal lon = 0;

    public string Line1 { get => line1; set => line1 = value; }
    public string Line2 { get => line2; set => line2 = value; }
    public string City { get => city; set => city = value; }
    public string Region { get => region; set => region = value; }
    public string Postalcode { get => postalcode; set => postalcode = value; }

    public static string Line3 => line3;
    public static string Country => country;
    public static TextCase AddrCase => addrCase;
    public static decimal Lon => lon;
    public static decimal Lat => lat;

    public string SiteNo { get => siteNo; set => siteNo = value; }
    public string GroupCode { get => groupCode; set => groupCode = value; }
    public string Client { get => client; set => client = value; }

    public Address(string client, string groupCode, string siteNo, string line1, string line2, string city, string region, string postalcode) {
        this.Client = client;
        this.GroupCode = groupCode;
        this.SiteNo = siteNo;
        this.Line1 = line1;
        this.Line2 = line2;
        this.City = city;
        this.Region = region;
        this.Postalcode = postalcode;
    }

    public string ValidatePNetAddress(AvaTaxClient Client, Address a) {
        string line = "";
        try {
            AddressResolutionModel x = Client.ResolveAddress(a.Line1, a.Line2, Line3, a.City, a.Region, a.Postalcode, Country, AddrCase, Lat, Lon);
            if (x.validatedAddresses.Count > 0) {
                line = "No. of Tax Auth - " + ((x.taxAuthorities != null) ? x.taxAuthorities.Count.ToString() : "NA")
                                + "\tAddress Type - " + x.validatedAddresses[0].addressType
                                + "\t" + a.ToString();
            }
        } catch (AvaTaxError e) {
            line = "Error\t" + e.Message + "\t" + a.ToString();
        }
        Console.WriteLine(line);
        return line;
    }

    public string ResolvePNetAddress(AvaTaxClient Client, Address a) {
        string line = "";
        try {
            AddressResolutionModel x = Client.ResolveAddress(a.Line1, a.Line2, Line3, a.City, a.Region, a.Postalcode, Country, AddrCase, Lat, Lon);
            if (x.validatedAddresses.Count > 0) {
                line = "No. of Tax Auth - " + ((x.taxAuthorities != null) ? x.taxAuthorities.Count.ToString() : "NA")
                                + "\tAddress Type - " + x.validatedAddresses[0].addressType
                                + "\t" + a.ToString();
            }
        } catch (AvaTaxError e) {
            line = "Error\t" + e.Message + "\t" + a.ToString();
        }
        Console.WriteLine(line);
        return line;
    }


    public override String ToString() {
        return "[" + Client
                  + "]|[" + GroupCode
                  + "]|[" + SiteNo
                  + "]|[" + Line1
                  + "]|[" + Line2
                  + "]|[" + Line3
                  + "]|[" + City
                  + "]|[" + Region
                  + "]|[" + Postalcode
                  + "]|[" + Country
                  + "]";
    }

}

