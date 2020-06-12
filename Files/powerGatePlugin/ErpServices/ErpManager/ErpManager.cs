using System;
using System.Collections.Generic;
using System.IO;
using System.Net;

namespace ErpServices.ErpManager
{
    public enum ErpSearchOperator
    {
        Contains
    }

    public enum ErpSearchProperty
    {
        Number,
        Description
    }

    public struct ErpMaterialSearchSettings
    {
        public ErpSearchProperty PropertyName { get; set; }
        public ErpSearchOperator Operator { get; set; }
        public string SearchValue { get; set; }
    }

    public struct ErpLogin
    {
        public IPEndPoint Server { get; }
        public string ConnectionString { get; }
        public string Mandant { get; }
        public string UserName { get; }
        public string Password { get; }
    }

    public interface IErpManager : IDisposable
    {
        ErpLogin Login { get; }
        bool IsConnected { get; }

        bool Connect(ErpLogin login);

        // Material functionality 
        Material GetMaterialyByNumber(string number);
        IEnumerable<Material> SearchMaterials(IEnumerable<ErpMaterialSearchSettings> query);
        Material CreateMaterial(Material material);
        Material UpdateMaterial(Material material);


        // Documents functionality 
        Document CreateDocumentMetadata(Document documentMetadata);
        Document UploadDocumentWithMetadata(MemoryStream fileStream, Document documentMetadata);
        Document UpdateDocumentMetadata(Document documentMetadata);
        Document UpdateDocumentWithMetadata(MemoryStream fileStream, Document documentMetadata);

        // BOM functionality 
        BomHeader GetBomByNumber(string number);
        BomRow GetBomRowByNumber(string parentNumber, string childNumber);
        BomHeader CreateBomWithChildren(BomHeader bom);
        BomRow CreateBomRow(BomRow bomRow);
        BomHeader UpdateBomHeader(BomHeader bom);
        BomRow UpdateBomRow(BomRow bomRow);
        BomRow DeleteBomRow(BomRow bomRow);

    }

    public partial class ErpManager : IErpManager
    {
    }
}