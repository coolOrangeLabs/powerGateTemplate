using System;
using System.IO;
using ErpServices.ErpManager.Interfaces;

namespace ErpServices.ErpManager.Implementation
{
    public partial class ErpManager : IErpManager
    {
        public Document CreateDocumentMetadata(Document documentMetadata)
        {
            throw new NotImplementedException();
        }

        public Document UploadDocumentWithMetadata(MemoryStream fileStream, Document documentMetadata)
        {
            throw new NotImplementedException();
        }

        public Document UpdateDocumentMetadata(Document documentMetadata)
        {
            throw new NotImplementedException();
        }

        public Document UpdateDocumentWithMetadata(MemoryStream fileStream, Document documentMetadata)
        {
            throw new NotImplementedException();
        }
    }
}