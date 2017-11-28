using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace DataHub.Models {
    public class Recalc {
        public long RecordID { get; set; }
        public string Client { get; set; }
        public int GroupCode { get; set; }
        public int SSN { get; set; }
        public DateTime PPED { get; set; }
        public Nullable<System.DateTime> CalcTimeStamp { get; set; }
        public string Status { get; set; }
    }
}
