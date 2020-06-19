using System.Configuration;
using System.Reflection;
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
            AddMethod(new Materials());
            AddMethod(new BomHeaders());
            AddMethod(new BomRows());
            AddMethod(new Documents());
        }

        static WebService()
        {
            Log.Info("Reading .config file");
            var configFullName = Assembly.GetExecutingAssembly().Location + ".config";
            var fileMap = new ExeConfigurationFileMap { ExeConfigFilename = configFullName };
            var configuration = ConfigurationManager.OpenMappedExeConfiguration(fileMap, ConfigurationUserLevel.None);
            var section = configuration.GetSection("ErpStorage") as AppSettingsSection;
            if (section == null) return;
            DatabaseFileLocation = section.Settings["DatabaseFileLocation"].Value;
            FileStorageLocation = section.Settings["FileStorageLocation"].Value;
            Log.Info("Reading .config file successfully done!");
        }
    }
}