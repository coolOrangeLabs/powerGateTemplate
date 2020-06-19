using System;
using System.Collections.Generic;
using System.IO;
using ErpServices.Metadata;

namespace ErpServices.ErpManager.Interfaces
{
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
}