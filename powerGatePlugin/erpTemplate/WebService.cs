using powerGateServer.SDK;

namespace erpTemplate
{
    [WebServiceData("coolOrange", "erpServices")]
    public class TestService : WebService
    {
        public TestService()
        {
            AddMethod(new Materials());
            AddMethod(new BomHeaders());
            AddMethod(new BomRows());
            AddMethod(new MaterialNumbers());
        }
    }
}