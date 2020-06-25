using System;
using System.Configuration;
using System.Reflection;
using ErpServices.ErpManager.Interfaces;
using ErpServices.Services;
using log4net;
using powerGateServer.SDK;

namespace ErpServices
{
    [WebServiceData("coolOrange", "ErpServices")]
    public class WebService : powerGateServer.SDK.WebService
    {
        static readonly ILog Log =
            LogManager.GetLogger(MethodBase.GetCurrentMethod().DeclaringType);
        public static readonly string DatabaseFileLocation;
        public static readonly string FileStorageLocation;

        public WebService()
        {
            var erpStorageConfiguration = GetErpStorageConfiguration();
            var erpManager = new ErpManager.Implementation.ErpManager();
            var erpLogin = new ErpLogin
            {
                ConnectionString = erpStorageConfiguration.Settings["FileStorageLocation"].Value,
                UserName = "coolOrange",
                Password = "Template2020",
                Mandant = 2020
            };
            var connected = erpManager.Connect(erpLogin);
            if(!connected)
                throw new Exception(string.Format("Failed to connect to ERP with Connection-String: {0}", erpLogin.ConnectionString));

            AddMethod(new Materials(erpManager));
            AddMethod(new BomHeaders(erpManager));
            AddMethod(new BomRows(erpManager));

            var storeForBinaryFiles = erpStorageConfiguration.Settings["DatabaseFileLocation"].Value;
            AddMethod(new Documents(storeForBinaryFiles, erpManager));
        }

        AppSettingsSection GetErpStorageConfiguration()
        {
            Log.Info("Reading .config file");
            var configFullName = Assembly.GetExecutingAssembly().Location + ".config";
            var fileMap = new ExeConfigurationFileMap { ExeConfigFilename = configFullName };
            var configuration = ConfigurationManager.OpenMappedExeConfiguration(fileMap, ConfigurationUserLevel.None);
            var section = configuration.GetSection("ErpStorage") as AppSettingsSection;
            if (section == null) 
                throw new Exception("Failed to find 'ErpStorage' section inside the config file!");

            Log.Info("Reading .config file successfully done!");
            return section;
        }
    }
}