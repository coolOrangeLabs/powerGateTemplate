using System.Net;

namespace ErpServices.ErpManager.Interfaces
{
    public struct ErpLogin
    {
        public IPEndPoint Server { get; }
        public string ConnectionString { get; }
        public string Mandant { get; }
        public string UserName { get; }
        public string Password { get; }
    }
}