using Microsoft.VisualStudio.TestTools.UnitTesting;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Security.AccessControl;
using System.Threading;
using ErpServices.ErpManager.Interfaces;
using ErpServices.Metadata;
using LiteDB;
using Moq;
using powerGateServer.SDK;

namespace ErpServices.Tests
{
    [TestClass]
    public class ErpItemManager_Tests : ErpBase_TestConfigurator
    {
        const string Erp_LocalTestDirectory = @"C:\temp\Plugin_Tests";

        public IErpManager ErpManager
        {
            get
            {
                var directory = new DirectoryInfo(Erp_LocalTestDirectory + "\\ErpData.db");
                return new ErpManager.Implementation.ErpManager(directory);
            }
        }

        ErpLogin Erp_TestCredentials
        {
            get
            {
                var testStorage = new DirectoryInfo(Erp_LocalTestDirectory + "\\ErpFiles");
                return new ErpLogin
                {
                    ConnectionString = testStorage.FullName,
                    UserName = "coolOrange",
                    Password = "Template2020",
                    Mandant = 2021
                };
            }
        }

        void AssertMaterials(Material expectedMaterial, Material actualMaterial)
        {
            Assert.AreEqual(expectedMaterial.Number, actualMaterial.Number);
            Assert.AreEqual(expectedMaterial.Category, actualMaterial.Category);
            Assert.AreEqual(expectedMaterial.Description, actualMaterial.Description);
            Assert.AreEqual(expectedMaterial.IsBlocked, actualMaterial.IsBlocked);
            Assert.AreEqual(expectedMaterial.UnitOfMeasure, actualMaterial.UnitOfMeasure);
            Assert.AreEqual(expectedMaterial.Link, actualMaterial.Link);
            Assert.AreEqual(expectedMaterial.ModifiedDate.ToLongTimeString(), actualMaterial.ModifiedDate.ToLongTimeString());
            Assert.AreEqual(expectedMaterial.SearchDescription, actualMaterial.SearchDescription);
            Assert.AreEqual(expectedMaterial.Shelf, actualMaterial.Shelf);
            Assert.AreEqual(expectedMaterial.Type, actualMaterial.Type);
        }

        Material GetDefaultMaterial()
        {
            return new Material
            {
                Number = DateTime.Now.Ticks.ToString(),
                Description = string.Format("UnitTest: {0}", DateTime.Now.Ticks),
                IsBlocked = false,
                Category = "Engineering",
                UnitOfMeasure = "mm",
                Type = "Purchase",
                Shelf= "Shelf1",
                SearchDescription= "Bolzen",
                Link = "Not existing",
                ModifiedDate = DateTime.Now
            };
        }

        public bool StopOnFailure = true;
        public bool CancelNextTests = false;
        public string CancelNextTestsMessage = "Not executed this test! Because one previous test failed which is important for this one!";

        [TestInitialize]
        public void TestInitialize()
        {
            if (StopOnFailure)
            {
                if(CancelNextTests)
                    Assert.Fail(CancelNextTestsMessage);
            }
        }

        [ClassCleanup()]
        public static void ClassCleanup()
        {
            ReportAll();
        }

        [TestMethod]
        public void Connect_With_Production_Credentials_Are_Working()
        {
            var erpManager = ErpManager;
            Assert.IsFalse(erpManager.IsConnected);

            var erp_productionCredentials = Erp_TestCredentials; // ToDo Replace this in project with real production credentials
            var startedMeasure = StartMeasure("Connect to production system");

            Thread.Sleep(1600);
            var connect = erpManager.Connect(erp_productionCredentials);
            StopMeasure(startedMeasure);
            Assert.IsTrue(connect);
            Assert.IsTrue(erpManager.IsConnected);
        }

        [TestMethod]
        public void Connect_With_Test_Credentials_Are_Working()
        {
            try
            {
                var erpManager = ErpManager;
                Assert.IsFalse(erpManager.IsConnected);

                var startedMeasure = StartMeasure("Connect to test system");
                var connect = erpManager.Connect(Erp_TestCredentials);
                StopMeasure(startedMeasure);
                Assert.IsTrue(connect);
                Assert.IsTrue(erpManager.IsConnected);
            }
            finally
            {
                CancelNextTests = true;
            }
        }

        [TestMethod]
        public void SearchMaterials_Where_ErpNumber_Contains_Specific_Digits()
        {
            var erpManager = ErpManager;
            erpManager.Connect(Erp_TestCredentials);

            var numberSearchText = "43";
            var startedMeasure = StartMeasure(String.Format("SearchMaterials where number contains '{0}'", numberSearchText));
            var erpItems = erpManager.SearchMaterials(new[]
            {
                new ErpMaterialSearchSettings
                {
                    PropertyName = ErpSearchProperty.Number,
                    Operator = OperatorType.Contains,
                    SearchValue = numberSearchText
                }
            }).ToList();
            StopMeasure(startedMeasure);

            Debug.WriteLine("Found {0} erp items", erpItems.Count());

            foreach (var material in erpItems)
                StringAssert.Contains(material.Number, numberSearchText);
        }

        [TestMethod]
        public void SearchMaterials_Where_ErpDescription_Contains_Specific_Text()
        {
            var erpManager = ErpManager;
            erpManager.Connect(Erp_TestCredentials);

            var numberSearchText = "test";
            var startedMeasure = StartMeasure(String.Format("SearchMaterials where description contains '{0}'", numberSearchText));
            var erpItems = erpManager.SearchMaterials(new[]
            {
                new ErpMaterialSearchSettings
                {
                    PropertyName = ErpSearchProperty.Description,
                    Operator = OperatorType.Contains,
                    SearchValue = numberSearchText
                }
            }).ToList();
            StopMeasure(startedMeasure);

            Debug.WriteLine("Found {0} erp items", erpItems.Count());

            foreach (var material in erpItems)
                StringAssert.Contains(material.Description, numberSearchText);
        }

        [TestMethod]
        public void CreateMaterial_And_GetMaterialByNumber_Will_Return_The_Just_Created_ErpItem()
        {
            var erpManager = ErpManager;
            erpManager.Connect(Erp_TestCredentials);

            var defaultMaterial = GetDefaultMaterial();
            var startedMeasure1 = StartMeasure(String.Format("CreateMaterial with default properties '{0}'", defaultMaterial.Number));
            var createdErpMaterial = erpManager.CreateMaterial(defaultMaterial);
            StopMeasure(startedMeasure1);

            AssertMaterials(defaultMaterial, createdErpMaterial);

            var startedMeasure2 = StartMeasure(String.Format("GetMaterialByNumber for '{0}'", defaultMaterial.Number));
            var queriedMaterial = erpManager.GetMaterialyByNumber(createdErpMaterial.Number);
            StopMeasure(startedMeasure2);

            AssertMaterials(createdErpMaterial, queriedMaterial);

            var startedMeasure3 = StartMeasure(String.Format("SearchMaterials with exact number for '{0}'", defaultMaterial.Number));
            var quierMaterials = erpManager.SearchMaterials(new[]
            {
                new ErpMaterialSearchSettings
                {
                    PropertyName = ErpSearchProperty.Description,
                    Operator = OperatorType.Equals,
                    SearchValue = createdErpMaterial.Description
                }
            }).ToList();
            StopMeasure(startedMeasure3);

            Assert.AreEqual(1, quierMaterials.Count);
            AssertMaterials(createdErpMaterial, quierMaterials.First());
        }

        [TestMethod]
        public void CreateMaterial_When_Number_Exists_Already_In_Erp_Then_It_Throws_Exception()
        {
            var erpManager = ErpManager;
            erpManager.Connect(Erp_TestCredentials);

            var quieredMaterials = erpManager.SearchMaterials(new List<ErpMaterialSearchSettings>()).ToList(); // Return me all items

            if (quieredMaterials.Count < 1)
                Assert.Fail("Test failed, because it requires a existing ErpItem number and it could not find one! Please make sure to provide this test always a number of an existing ErpItem.");
            var existingErpMaterial = quieredMaterials.First();

            var defaultMaterial = GetDefaultMaterial();
            defaultMaterial.Number = existingErpMaterial.Number;

            var startedMeasure1 = StartMeasure(String.Format("CreateMaterial when number already exists '{0}'", defaultMaterial.Number));
            Assert.ThrowsException<LiteException>(delegate
            {
                var createdErpMaterial = erpManager.CreateMaterial(defaultMaterial);
            }, string.Format("Cannot insert duplicate key in unique index '_id'. The duplicate value is '\"{0}\"'", defaultMaterial.Number));

            StopMeasure(startedMeasure1);
        }

        [TestMethod]
        public void UpdateMaterial_All_Properties_For_A_New_ErpItem()
        {
            var erpManager = ErpManager;
            erpManager.Connect(Erp_TestCredentials);

            var defaultMaterial = GetDefaultMaterial();
            var createdErpMaterial = erpManager.CreateMaterial(defaultMaterial);

            createdErpMaterial.SearchDescription = createdErpMaterial.Description = string.Format("Updated-{0}", DateTime.Now.Ticks);
            createdErpMaterial.IsBlocked = !createdErpMaterial.IsBlocked;
            createdErpMaterial.Link = DateTime.Now.Ticks.ToString();
            createdErpMaterial.ModifiedDate = DateTime.Now;
            createdErpMaterial.Shelf= string.Format("Updated-{0}", DateTime.Now.Ticks);
            createdErpMaterial.Type= string.Format("Updated-{0}", DateTime.Now.Ticks);
            createdErpMaterial.UnitOfMeasure= string.Format("Updated-{0}", DateTime.Now.Ticks);
            createdErpMaterial.Category = string.Format("Updated-{0}", DateTime.Now.Ticks);

            var startedMeasure1 = StartMeasure(String.Format("UpdateMaterial with default properties for '{0}'", defaultMaterial.Number));
            var updatedErpMaterial = erpManager.UpdateMaterial(defaultMaterial);
            StopMeasure(startedMeasure1);

            AssertMaterials(updatedErpMaterial, createdErpMaterial);

            var startedMeasure2 = StartMeasure(String.Format("GetMaterialByNumber for '{0}'", defaultMaterial.Number));
            var queriedMaterial = erpManager.GetMaterialyByNumber(createdErpMaterial.Number);
            StopMeasure(startedMeasure2);

            AssertMaterials(updatedErpMaterial, queriedMaterial);

            var startedMeasure3 = StartMeasure(String.Format("SearchMaterials with exact number for '{0}'", defaultMaterial.Number));
            var quierMaterials = erpManager.SearchMaterials(new[]
            {
                new ErpMaterialSearchSettings
                {
                    PropertyName = ErpSearchProperty.Number,
                    Operator = OperatorType.Equals,
                    SearchValue = createdErpMaterial.Number
                }
            }).ToList();
            StopMeasure(startedMeasure3);

            Assert.AreEqual(1, quierMaterials.Count);
            AssertMaterials(updatedErpMaterial, quierMaterials.First());
        }
    }
}
