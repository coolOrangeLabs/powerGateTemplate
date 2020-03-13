using System;
using System.Collections.Generic;
using System.Data.Services;
using System.Data.Services.Common;
using System.IO;
using System.Linq;
using System.ServiceModel.Web;
using LiteDB;
using powerGateServer.SDK;

namespace ErpServices
{
    [DataServiceKey("Number")]
    [DataServiceEntity]
    [IgnoreProperties("Directory")]
    public class Document : Streamable
    {
        public string Number { get; set; }
        public string Description { get; set; }
        public string Directory { get; set; }
        public DateTime CreateDate { get; set; }
        public DateTime ModifyDate { get; set; }

        public override string GetContentType()
        {
            return ContentTypes.Application.Pdf;
        }
    }

    public class Documents : ServiceMethod<Document>, IStreamableServiceMethod<Document>
    {
        public override string Name => "Documents";

        public Documents()
        {
            BsonMapper.Global.Entity<Document>().Id(x => x.Number);
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
                            .Find(x => x.Number.Equals(number.Value));
                    }
                }
                return null;
            }

            using (var db = new LiteDatabase(WebService.DatabaseFileLocation))
            {
                return db.GetCollection<Document>()
                    .FindAll();
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