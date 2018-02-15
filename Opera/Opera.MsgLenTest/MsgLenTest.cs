using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Linq;

namespace Opera.Test.MsgLen
{
    class MsgLenTest
    {
        static void Main(string[] args)
        {
            string jsonStr = @"[{""JobID"":""83071566"",""SegmentNumber"":""1"",""SegmentsTotal"":""1"",""BranchID"":""Locums"",""FileName"":""PN_Time_20171110_144035.csv"",""FileBatch"":""Locums-LLL-SUN"",""EmployeeFirstName"":""BARBARA"",""EmployeeLastName"":""MINNITT"",""EmployeeID"":""10014526"",""AssignmentNumber"":""0000046816"",""WeekEndingDate"":""2017-10-08T04:00:00.000Z"",""TransDate"":""2017-10-02T04:00:00.000Z"",""WorkedHours"":""8.00"",""PayCode"":""REG"",""TimeCode"":""RGM"",""PayAmt"":""8.00"",""BillAmt"":""8.00"",""ProjectCode"":"""",""ApproverName"":""Approver; System"",""ApproverEmail"":""SYSTEM APPROVER"",""ApprovalDateTime"":""2017-11-10T19:11:57.000Z"",""PayFileGroup"":"""",""TimeSource"":""W"",""ApprovalSource"":""P"",""TimeSheetID"":""999999999"",""ApprovalStatus"":""1"",""CustomFieldValues"":[{""FieldName"":""InTime"",""FieldValue"":""""},{""FieldName"":""OutTime"",""FieldValue"":""""},{""FieldName"":""UDF1_Name"",""FieldValue"":""""},{""FieldName"":""UDF1_Value"",""FieldValue"":""""},{""FieldName"":""UDF2_Name"",""FieldValue"":""""},{""FieldName"":""UDF2_Value"",""FieldValue"":""""},{""FieldName"":""UDF3_Name"",""FieldValue"":""""},{""FieldName"":""UDF3_Value"",""FieldValue"":""""},{""FieldName"":""UDF4_Name"",""FieldValue"":""""},{""FieldName"":""UDF4_Value"",""FieldValue"":""""},{""FieldName"":""UDF5_Name"",""FieldValue"":""""},{""FieldName"":""UDF5_Value"",""FieldValue"":""""},{""FieldName"":""UDF6_Name"",""FieldValue"":""""},{""FieldName"":""UDF6_Value"",""FieldValue"":""""}],""ImageFileName"":""863173135"",""ErrorMessage"":""""},{""JobID"":""83071566"",""SegmentNumber"":""1"",""SegmentsTotal"":""1"",""BranchID"":""Locums"",""FileName"":""PN_Time_20171110_144035.csv"",""FileBatch"":""Locums-LLL-SUN"",""EmployeeFirstName"":""BARBARA"",""EmployeeLastName"":""MINNITT"",""EmployeeID"":""10014526"",""AssignmentNumber"":""0000046816"",""WeekEndingDate"":""2017-10-08T04:00:00.000Z"",""TransDate"":""2017-10-03T04:00:00.000Z"",""WorkedHours"":""8.00"",""PayCode"":""REG"",""TimeCode"":""RGM"",""PayAmt"":""8.00"",""BillAmt"":""8.00"",""ProjectCode"":"""",""ApproverName"":""Approver; System"",""ApproverEmail"":""SYSTEM APPROVER"",""ApprovalDateTime"":""2017-11-10T19:11:57.000Z"",""PayFileGroup"":"""",""TimeSource"":""W"",""ApprovalSource"":""P"",""TimeSheetID"":""999999999"",""ApprovalStatus"":""1"",""CustomFieldValues"":[{""FieldName"":""InTime"",""FieldValue"":""""},{""FieldName"":""OutTime"",""FieldValue"":""""},{""FieldName"":""UDF1_Name"",""FieldValue"":""""},{""FieldName"":""UDF1_Value"",""FieldValue"":""""},{""FieldName"":""UDF2_Name"",""FieldValue"":""""},{""FieldName"":""UDF2_Value"",""FieldValue"":""""},{""FieldName"":""UDF3_Name"",""FieldValue"":""""},{""FieldName"":""UDF3_Value"",""FieldValue"":""""},{""FieldName"":""UDF4_Name"",""FieldValue"":""""},{""FieldName"":""UDF4_Value"",""FieldValue"":""""},{""FieldName"":""UDF5_Name"",""FieldValue"":""""},{""FieldName"":""UDF5_Value"",""FieldValue"":""""},{""FieldName"":""UDF6_Name"",""FieldValue"":""""},{""FieldName"":""UDF6_Value"",""FieldValue"":""""}],""ImageFileName"":""863173135"",""ErrorMessage"":""""},{""JobID"":""83071566"",""SegmentNumber"":""1"",""SegmentsTotal"":""1"",""BranchID"":""Locums"",""FileName"":""PN_Time_20171110_144035.csv"",""FileBatch"":""Locums-LLL-SUN"",""EmployeeFirstName"":""BARBARA"",""EmployeeLastName"":""MINNITT"",""EmployeeID"":""10014526"",""AssignmentNumber"":""0000046816"",""WeekEndingDate"":""2017-10-08T04:00:00.000Z"",""TransDate"":""2017-10-04T04:00:00.000Z"",""WorkedHours"":""8.00"",""PayCode"":""REG"",""TimeCode"":""RGM"",""PayAmt"":""8.00"",""BillAmt"":""8.00"",""ProjectCode"":"""",""ApproverName"":""Approver; System"",""ApproverEmail"":""SYSTEM APPROVER"",""ApprovalDateTime"":""2017-11-10T19:11:57.000Z"",""PayFileGroup"":"""",""TimeSource"":""W"",""ApprovalSource"":""P"",""TimeSheetID"":""863173135"",""ApprovalStatus"":""1"",""CustomFieldValues"":[{""FieldName"":""InTime"",""FieldValue"":""""},{""FieldName"":""OutTime"",""FieldValue"":""""},{""FieldName"":""UDF1_Name"",""FieldValue"":""""},{""FieldName"":""UDF1_Value"",""FieldValue"":""""},{""FieldName"":""UDF2_Name"",""FieldValue"":""""},{""FieldName"":""UDF2_Value"",""FieldValue"":""""},{""FieldName"":""UDF3_Name"",""FieldValue"":""""},{""FieldName"":""UDF3_Value"",""FieldValue"":""""},{""FieldName"":""UDF4_Name"",""FieldValue"":""""},{""FieldName"":""UDF4_Value"",""FieldValue"":""""},{""FieldName"":""UDF5_Name"",""FieldValue"":""""},{""FieldName"":""UDF5_Value"",""FieldValue"":""""},{""FieldName"":""UDF6_Name"",""FieldValue"":""""},{""FieldName"":""UDF6_Value"",""FieldValue"":""""}],""ImageFileName"":""863173135"",""ErrorMessage"":""""},{""JobID"":""83071566"",""SegmentNumber"":""1"",""SegmentsTotal"":""1"",""BranchID"":""Locums"",""FileName"":""PN_Time_20171110_144035.csv"",""FileBatch"":""Locums-LLL-SUN"",""EmployeeFirstName"":""BARBARA"",""EmployeeLastName"":""MINNITT"",""EmployeeID"":""10014526"",""AssignmentNumber"":""0000046816"",""WeekEndingDate"":""2017-10-08T04:00:00.000Z"",""TransDate"":""2017-10-05T04:00:00.000Z"",""WorkedHours"":""8.00"",""PayCode"":""REG"",""TimeCode"":""RGM"",""PayAmt"":""8.00"",""BillAmt"":""8.00"",""ProjectCode"":"""",""ApproverName"":""Approver; System"",""ApproverEmail"":""SYSTEM APPROVER"",""ApprovalDateTime"":""2017-11-10T19:11:57.000Z"",""PayFileGroup"":"""",""TimeSource"":""W"",""ApprovalSource"":""P"",""TimeSheetID"":""863173135"",""ApprovalStatus"":""1"",""CustomFieldValues"":[{""FieldName"":""InTime"",""FieldValue"":""""},{""FieldName"":""OutTime"",""FieldValue"":""""},{""FieldName"":""UDF1_Name"",""FieldValue"":""""},{""FieldName"":""UDF1_Value"",""FieldValue"":""""},{""FieldName"":""UDF2_Name"",""FieldValue"":""""},{""FieldName"":""UDF2_Value"",""FieldValue"":""""},{""FieldName"":""UDF3_Name"",""FieldValue"":""""},{""FieldName"":""UDF3_Value"",""FieldValue"":""""},{""FieldName"":""UDF4_Name"",""FieldValue"":""""},{""FieldName"":""UDF4_Value"",""FieldValue"":""""},{""FieldName"":""UDF5_Name"",""FieldValue"":""""},{""FieldName"":""UDF5_Value"",""FieldValue"":""""},{""FieldName"":""UDF6_Name"",""FieldValue"":""""},{""FieldName"":""UDF6_Value"",""FieldValue"":""""}],""ImageFileName"":""863173135"",""ErrorMessage"":""""},{""JobID"":""83071566"",""SegmentNumber"":""1"",""SegmentsTotal"":""1"",""BranchID"":""Locums"",""FileName"":""PN_Time_20171110_144035.csv"",""FileBatch"":""Locums-LLL-SUN"",""EmployeeFirstName"":""BARBARA"",""EmployeeLastName"":""MINNITT"",""EmployeeID"":""10014526"",""AssignmentNumber"":""0000046816"",""WeekEndingDate"":""2017-10-08T04:00:00.000Z"",""TransDate"":""2017-10-06T04:00:00.000Z"",""WorkedHours"":""8.00"",""PayCode"":""REG"",""TimeCode"":""RGM"",""PayAmt"":""8.00"",""BillAmt"":""8.00"",""ProjectCode"":"""",""ApproverName"":""Approver; System"",""ApproverEmail"":""SYSTEM APPROVER"",""ApprovalDateTime"":""2017-11-10T19:11:57.000Z"",""PayFileGroup"":"""",""TimeSource"":""W"",""ApprovalSource"":""P"",""TimeSheetID"":""863173135"",""ApprovalStatus"":""1"",""CustomFieldValues"":[{""FieldName"":""InTime"",""FieldValue"":""""},{""FieldName"":""OutTime"",""FieldValue"":""""},{""FieldName"":""UDF1_Name"",""FieldValue"":""""},{""FieldName"":""UDF1_Value"",""FieldValue"":""""},{""FieldName"":""UDF2_Name"",""FieldValue"":""""},{""FieldName"":""UDF2_Value"",""FieldValue"":""""},{""FieldName"":""UDF3_Name"",""FieldValue"":""""},{""FieldName"":""UDF3_Value"",""FieldValue"":""""},{""FieldName"":""UDF4_Name"",""FieldValue"":""""},{""FieldName"":""UDF4_Value"",""FieldValue"":""""},{""FieldName"":""UDF5_Name"",""FieldValue"":""""},{""FieldName"":""UDF5_Value"",""FieldValue"":""""},{""FieldName"":""UDF6_Name"",""FieldValue"":""""},{""FieldName"":""UDF6_Value"",""FieldValue"":""""}],""ImageFileName"":""863173135"",""ErrorMessage"":""""}]";



            Console.WriteLine("MsgLenTest!");

            Console.WriteLine(jsonStr);


            Payfile p1 = new Payfile();
            p1.JobID = "83071566";
            p1.SegmentNumber = "1";
            p1.SegmentsTotal = "1";
            p1.FileName = "PN_Time_20171110_144035.csv";
            p1.TransDate = "2017-10-08T04:00:00.000Z";
            p1.TimeSheetID = "99999";

            CustomField cf1 = new CustomField();
            cf1.FieldName = "fname";
            cf1.FieldValue = "Sachin";
            CustomField cf2 = new CustomField();
            cf1.FieldName = "lname";
            cf1.FieldValue = "Jain";

            List<CustomField> lstCf = new List<CustomField>();

            p1.CustomFieldValues = lstCf;

            var jsonMsg = JsonConvert.SerializeObject(p1);

            var js = JsonConvert.DeserializeObject<List<Payfile>>(jsonStr);
     
            var res = js.GroupBy(x => x.TimeSheetID).Select(y => y).ToArray();

            for(int i=0; i < res.Length; i++) {
                Console.WriteLine(res[i].Key);
                var x = js.Where(y => y.TimeSheetID == res[i].Key).ToList();
            }

            Console.ReadLine();
        }
    }
}
