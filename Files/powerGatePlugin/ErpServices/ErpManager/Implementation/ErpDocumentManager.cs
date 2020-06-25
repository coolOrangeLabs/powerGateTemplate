using System;
using System.IO;
using System.Linq;
using System.ServiceModel.Web;
using ErpServices.ErpManager.Interfaces;
using ErpServices.Metadata;
using LiteDB;
using powerGateServer.SDK;

namespace ErpServices.ErpManager.Implementation
{
    public partial class ErpManager : IErpManager
    {
        public Document GetDocumentMetadata(string number)
        {
            return ExecuteOnDatabase(delegate (LiteDatabase database)
            {
                var document = database.GetCollection<Document>().Find(doc => doc.Number == number).FirstOrDefault();
                return document;
            });

        }

        public Document CreateDocumentMetadata(Document documentMetadata)
        {
            return ExecuteOnDatabase(delegate (LiteDatabase database)
            {
                database.GetCollection<Document>().Insert(documentMetadata);
                return documentMetadata;
            });
        }

        public IStream DownloadDocument(Document documentMetadata)
        {
            var fileLocation = Path.Combine(BinaryStorage.FullName, documentMetadata.Directory, documentMetadata.FileName);
            if (WebOperationContext.Current != null)
                WebOperationContext.Current.OutgoingResponse.Headers["Content-Disposition"] = $"filename={Path.GetFileName(fileLocation)}";
            return new powerGateServer.SDK.Streams.FileStream(fileLocation);
        }

        public Document UploadDocumentWithMetadata(IStream stream, Document documentMetadata)
        {
            documentMetadata.Directory = Guid.NewGuid().ToString();
            var path = Path.Combine(BinaryStorage.FullName, documentMetadata.Directory);
            if (!Directory.Exists(path))
                Directory.CreateDirectory(path);

            var fullFileName = Path.Combine(path, documentMetadata.FileName);
            using (var fileStream = File.Create(fullFileName))
            {
                stream.Source.CopyTo(fileStream);
            }

            return CreateDocumentMetadata(documentMetadata);
        }

        public Document UpdateDocumentMetadata(Document documentMetadata)
        {
            return ExecuteOnDatabase(delegate (LiteDatabase database)
            {
                database.GetCollection<Document>().Update(documentMetadata);
                return documentMetadata;
            });
        }

        public Document ChangeDocumentWithMetadata(IStream stream, Document documentMetadata)
        {
            throw new NotImplementedException();
        }
    }
}