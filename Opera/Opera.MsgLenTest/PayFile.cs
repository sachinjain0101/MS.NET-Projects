using System;
using System.Collections.Generic;
using System.Text;

namespace Opera.Test.MsgLen {
    public class Payfile {
        //public String IntegrationKey         { get; set; }//Assigned IntegrationKey (APIKey)[Required]//[Required]w 
        //public String MessageType            { get; set; }// Payfile message or PayfileError Message
        //public String Client                 { get; set; }//varchar(4),

        //JobID|SegmentNumber|TotalSegments
        public String JobID { get; set; } //[Required] 
        public String SegmentNumber { get; set; } //[Required]
        public String SegmentsTotal { get; set; } //[Required]
        public String BranchID { get; set; }
        public String FileName { get; set; }//[Required] - nk 04/04/2016 added
        public String FileBatch { get; set; }//[Required] - nk 04/04/2016 added ISNULL(cg.ADP_BatchNo,'') AS BatchNo||ISNULL(cg.ADP_CompanyCode,'') AS CompCode,
        public String EmployeeFirstName { get; set; }
        public String EmployeeLastName { get; set; }
        public String EmployeeID { get; set; }
        public String AssignmentNumber { get; set; }
        public String WeekEndingDate { get; set; }
        public String TransDate { get; set; }
        public String WorkedHours { get; set; }
        public String PayCode { get; set; }
        public String TimeCode { get; set; }//nk 05/11/2015
        public String PayAmt { get; set; }
        public String BillAmt { get; set; }
        public String ProjectCode { get; set; }
        public String ApproverName { get; set; }
        public String ApproverEmail { get; set; }
        public String ApprovalDateTime { get; set; }
        public String PayFileGroup { get; set; }
        public String TimeSource { get; set; }
        public String ApprovalSource { get; set; }
        public String TimeSheetID { get; set; }
        public String ApprovalStatus { get; set; }
        public List<CustomField> CustomFieldValues { get; set; }//optional nk 05/11/2015 - holder for additional fields-values 
        public String ImageFileName { get; set; }
        public String ErrorMessage { get; set; }
        //public String UDF1Code          { get; set; } 
        //public String UDF1Hours         { get; set; } 
        //public String UDF2Code          { get; set; } 
        //public String UDF2Hours         { get; set; } 
        //public String UDF3Code          { get; set; } 
        //public String UDF3Hours         { get; set; } 
    }

    public class CustomField {
        public string FieldName { get; set; }
        public string FieldValue { get; set; }
    }
}
