using System;
using System.IO;
using System.Reflection;
using ErpServices.ErpManager.Interfaces;
using ErpServices.Metadata;
using LiteDB;
using log4net;

namespace ErpServices.ErpManager.Implementation
{
    public partial class ErpManager : IErpManager
    {
        public DirectoryInfo BinaryStorage { get; }

        static readonly ILog Log =
            LogManager.GetLogger(MethodBase.GetCurrentMethod().DeclaringType);

        public ErpLogin Login { get; private set; }

        public bool IsConnected
        {
            get
            {
                if (string.IsNullOrEmpty(Login.ConnectionString))
                    return false;
                return true;
            }
        }

        public ErpManager(DirectoryInfo binaryStorage)
        {
            BinaryStorage = binaryStorage;
            BsonMapper.Global.Entity<Material>().Id(x => x.Number);
            BsonMapper.Global.Entity<Document>().Id(x => x.Number);
            BsonMapper.Global.Entity<BomHeader>().Id(x => x.Number);
            BsonMapper.Global.Entity<BomRow>().Id(x => x.Id);
        }

        public bool Connect(ErpLogin login)
        {
            Log.InfoFormat("Connect to: {0}", login.ConnectionString);
            try
            {
                Login = login;
                ExecuteOnDatabase(database => database.GetCollection<Material>());
                return true;
            }
            catch (Exception exception)
            {
                Log.Error(exception);
                return false;
            }
        }

        protected T ExecuteOnDatabase<T>(Func<LiteDatabase, T> operation)
        {
            if(!IsConnected)
                throw new Exception("No connection, first make a Connect()");

            using (var db = new LiteDatabase(Login.ConnectionString))
            {
                return operation(db);
            }
        }
        
        public void Dispose()
        {
            Log.InfoFormat("Disposing ERP Manager..");
            // Logout and clean up
        }
    }
}