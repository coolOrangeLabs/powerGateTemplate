using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.ServiceModel.Web;
using ErpServices.ErpManager.Interfaces;
using ErpServices.Metadata;
using LiteDB;
using log4net;
using powerGateServer.SDK;

namespace ErpServices.Services
{
    public class Documents : ErpBaseService<Document>, IStreamableServiceMethod<Document>
    {
        static readonly ILog Log =
            LogManager.GetLogger(MethodBase.GetCurrentMethod().DeclaringType);
        public override string Name => "Documents";

        public Documents(string storeForBinaryFiles, IErpManager erpManager) : base(erpManager)
        {
            
        }

        public override IEnumerable<Document> Query(IExpression<Document> expression)
        {
            if (expression.Where.Any(b => b.PropertyName.Equals("Number")))
            {
                var number = expression.Where.FirstOrDefault(w => w.PropertyName.Equals("Number"));
                if (number != null && number.Value != number && number.Value.ToString() != "")
                {
                    using (var db = new LiteDatabase(WebService.DatabaseFileLocation))
                    {
                        return db.GetCollection<Document>()
                            .Find(x => x.Number.Equals(number.Value))
                            .ToList();
                    }
                }
                return null;
            }

            using (var db = new LiteDatabase(WebService.DatabaseFileLocation))
            {
                return db.GetCollection<Document>()
                    .FindAll()
                    .ToList();
            }
        }

        public override void Create(Document entity)
        {
        }

        public override void Update(Document entity)
        {
            using (var db = new LiteDatabase(WebService.DatabaseFileLocation))
            {
                db.GetCollection<Document>()
                    .Update(entity);
            }
        }

        public override void Delete(Document entity)
        {
            throw new NotSupportedException();
        }

        public IStream Download(Document entity)
        {
            if (WebOperationContext.Current != null)
                WebOperationContext.Current.OutgoingResponse.Headers.Add("Access-Control-Allow-Origin", "*");

            var fileLocation = Path.Combine(WebService.FileStorageLocation, entity.Directory, entity.FileName);

            if (WebOperationContext.Current != null)
                WebOperationContext.Current.OutgoingResponse.Headers["Content-Disposition"] = $"filename={Path.GetFileName(fileLocation)}";

            return new powerGateServer.SDK.Streams.FileStream(fileLocation);
        }

        public void Upload(Document entity, IStream stream)
        {
            if (entity.Mode == TransactionMode.Update)
                throw new NotSupportedException();

            try
            {
                entity.Directory = Guid.NewGuid().ToString();
                var path = Path.Combine(WebService.FileStorageLocation, entity.Directory);

                if (!Directory.Exists(path))
                    Directory.CreateDirectory(path);

                var fullFileName = Path.Combine(path, entity.FileName);
                using (var fileStream = File.Create(fullFileName))
                {
                    stream.Source.CopyTo(fileStream);
                }

                using (var db = new LiteDatabase(WebService.DatabaseFileLocation))
                {
                    db.GetCollection<Document>()
                        .Insert(entity);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex);
                throw;
            }
        }

        public void DeleteStream(Document entity)
        {
            throw new NotSupportedException();
        }
    }
}