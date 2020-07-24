using System.Data.Services.Common;

namespace ErpServices.Metadata
{
    [DataServiceKey("Key")]
    [DataServiceEntity]
    public class Category
    {
        public string Key { get; set; }
        public string Value { get; set; }
    }
}
