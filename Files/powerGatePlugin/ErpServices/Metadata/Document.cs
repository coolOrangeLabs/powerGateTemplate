using System.Data.Services.Common;
using powerGateServer.SDK;

namespace ErpServices.Metadata
{
    [DataServiceKey("Number")]
    [DataServiceEntity]
    //[IgnoreProperties("Directory")]
    public class Document : Streamable
    {
        public string Number { get; set; }
        public string Description { get; set; }
        public string Directory { get; set; }

        public override string GetContentType()
        {
            return ContentTypes.Application.Pdf;
        }
    }
}