using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;

namespace ErpServices.Tests
{
    public class ErpApi_PerformanceTest
    {
        public Guid Id { get; set; }
        public string Title { get; set; }
        public Stopwatch Stopwatch { get; set; }
        public DateTime Started { get; set; }
    }

    public abstract class ErpBase_TestConfigurator
    {
        private const string PerformanceReportFile = @"C:\temp\powerGate-Performance-Report.txt";

        static readonly List<ErpApi_PerformanceTest> performanceTests = new List<ErpApi_PerformanceTest>();


        public ErpApi_PerformanceTest StartMeasure(string title)
        {
            var stopWatch = new Stopwatch();
            var erpApi_PerformanceTest = new ErpApi_PerformanceTest
            {
                Id = new Guid(),
                Title = title,
                Stopwatch = stopWatch,
                Started = DateTime.Now
            };
            erpApi_PerformanceTest.Stopwatch.Start();
            return erpApi_PerformanceTest;
        }

        public void StopMeasure(ErpApi_PerformanceTest erpApiPerformanceTest)
        {
            erpApiPerformanceTest.Stopwatch.Stop();
            performanceTests.Add(erpApiPerformanceTest);
        }

        public static void ReportAll()
        {
            var report = "Title | Duration | Time stamp (started at)\n";
            report += " - | - | - \n";
            foreach (var erpApiPerformanceTest in performanceTests)
            {
                report += string.Format("{0} | {1} | {2}\n", erpApiPerformanceTest.Title,
                    erpApiPerformanceTest.Stopwatch.Elapsed.ToString(), erpApiPerformanceTest.Started.ToString());
            }

            Debug.Write(report);
            File.WriteAllText(PerformanceReportFile, report);
        }

    }
}