using System.Configuration;
using System.Reflection;
using powerGateServer.SDK;

namespace ErpServices
{
    [WebServiceData("coolOrange", "ErpServices")]
    public class WebService : powerGateServer.SDK.WebService
    {
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
            var configFullName = Assembly.GetExecutingAssembly().Location + ".config";
            var fileMap = new ExeConfigurationFileMap { ExeConfigFilename = configFullName };
            var configuration = ConfigurationManager.OpenMappedExeConfiguration(fileMap, ConfigurationUserLevel.None);
            var section = configuration.GetSection("ErpStorage") as AppSettingsSection;
            if (section == null) return;
            DatabaseFileLocation = section.Settings["DatabaseFileLocation"].Value;
            FileStorageLocation = section.Settings["FileStorageLocation"].Value;
        }
    }
}