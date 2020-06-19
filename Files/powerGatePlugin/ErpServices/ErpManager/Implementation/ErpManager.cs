using System;
using ErpServices.ErpManager.Interfaces;

namespace ErpServices.ErpManager.Implementation
{
    public partial class ErpManager : IErpManager
    {
        public void Dispose()
        {
            throw new NotImplementedException();
        }

        public ErpLogin Login { get; }
        public bool IsConnected { get; }

        public bool Connect(ErpLogin login)
        {
            throw new NotImplementedException();
        }

    }
}