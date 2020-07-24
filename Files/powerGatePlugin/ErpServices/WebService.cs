using System;
using System.Configuration;
using System.IO;
using System.Reflection;
using System.ServiceModel;
using System.ServiceModel.Discovery;
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
        
        public WebService()
        {
            var erpStorageConfiguration = GetErpStorageConfiguration();
            var storeForBinaryFiles = erpStorageConfiguration.Settings["DatabaseFileLocation"].Value;
            var binaryStoreDirectory = new DirectoryInfo(storeForBinaryFiles);

            var erpManager = new ErpManager.Implementation.ErpManager(binaryStoreDirectory);
            var erpLogin = new ErpLogin
            {
                ConnectionString = erpStorageConfiguration.Settings["FileStorageLocation"].Value,
                UserName = "coolOrange",
                Password = "Template2020",
                Mandant = 2020
            };
            Log.Info("Connecting to ERP...");
            var connected = erpManager.Connect(erpLogin);
            if(!connected)
                throw new Exception(string.Format("Failed to connect to ERP with Connection-String: {0}", erpLogin.ConnectionString));

            AddMethod(new Materials(erpManager));
            AddMethod(new BomHeaders(erpManager));
            AddMethod(new BomRows(erpManager));
            AddMethod(new Documents(erpManager));

            if (OperationContext.Current != null)
            {
                OperationContext.Current.Host.Description.Behaviors.Add(new ServiceDiscoveryBehavior());
                OperationContext.Current.Host.AddServiceEndpoint(new UdpDiscoveryEndpoint());
            }
        }

        AppSettingsSection GetErpStorageConfiguration()
        {
            Log.Info("Reading .config file...");
            var configFullName = Assembly.GetExecutingAssembly().Location + ".config";
            var fileMap = new ExeConfigurationFileMap { ExeConfigFilename = configFullName };
            var configuration = ConfigurationManager.OpenMappedExeConfiguration(fileMap, ConfigurationUserLevel.None);
            var section = configuration.GetSection("ErpStorage") as AppSettingsSection;
            if (section == null) 
                throw new Exception("Failed to find 'ErpStorage' section inside the config file!");

            Log.Info(".config file successfully parsed!");
            return section;
        }
    }
}