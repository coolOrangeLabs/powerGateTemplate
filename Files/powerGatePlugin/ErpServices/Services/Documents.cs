using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.ServiceModel.Web;
using ErpServices.ErpManager.Interfaces;
using ErpServices.Metadata;
using log4net;
using powerGateServer.SDK;
using powerGateServer.SDK.Helper;

namespace ErpServices.Services
{
    public class Documents : ErpBaseService<Document>, IStreamableServiceMethod<Document>
    {
        static readonly ILog Log =
            LogManager.GetLogger(MethodBase.GetCurrentMethod().DeclaringType);
        public override string Name => "Documents";

        public Documents(IErpManager erpManager) : base(erpManager)
        {
        }

        public override IEnumerable<Document> Query(IExpression<Document> expression)
        {
            if (expression.IsSimpleWhereToken())
            {
                var number = expression.GetWhereValuesAsString("Number");
                Log.InfoFormat("Single query for document number {0}", number);
                var document = ErpManager.GetDocumentMetadata(number);
                if (document != null)
                    return new[] { document };
                return Enumerable.Empty<Document>();
            }

            //var searchSettings = GetSearchSettings(expression);
            throw new NotSupportedException("Searching ERP documents is not supported!");
        }

        public override void Create(Document entity)
        {
        }

        public override void Update(Document entity)
        {
            ErpManager.UpdateDocumentMetadata(entity);
        }

        public override void Delete(Document entity)
        {
            throw new NotSupportedException();
        }

        public IStream Download(Document entity)
        {
            if (WebOperationContext.Current != null)
                WebOperationContext.Current.OutgoingResponse.Headers.Add("Access-Control-Allow-Origin", "*");
            var fileStream = ErpManager.DownloadDocument(entity);
            return fileStream;
        }

        public void Upload(Document entity, IStream stream)
        {
            if (entity.Mode == TransactionMode.Update)
                throw new NotSupportedException();

            try
            {
                ErpManager.UploadDocumentWithMetadata(stream, entity);
            }
            catch (Exception ex)
            {
                Log.Error(ex);
                throw;
            }
        }

        public void DeleteStream(Document entity)
        {
            throw new NotSupportedException();
        }
    }
}