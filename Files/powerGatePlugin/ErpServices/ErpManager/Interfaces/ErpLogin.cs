using System.Net;

namespace ErpServices.ErpManager.Interfaces
{
    public struct ErpLogin
    {
        public IPEndPoint Server { get; set; }
        public string ConnectionString { get; set; }
        public int Mandant { get; set; }
        public string UserName { get; set; }
        public string Password { get; set; }
    }
}