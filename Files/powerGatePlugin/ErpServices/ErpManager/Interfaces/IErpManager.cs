using System;
using System.Collections.Generic;
using ErpServices.Metadata;
using powerGateServer.SDK;

namespace ErpServices.ErpManager.Interfaces
{
    public interface IErpManager : IDisposable
    {
        bool IsConnected { get; }

        bool Connect(ErpLogin login);

        // Material functionality 
        Material GetMaterialByNumber(string number);
        IEnumerable<Material> SearchMaterials(IEnumerable<ErpMaterialSearchSettings> query);
        Material CreateMaterial(Material material);
        Material UpdateMaterial(Material material);
        
        // Documents functionality 
        Document GetDocumentMetadata(string number);
        Document CreateDocumentMetadata(Document documentMetadata);
        Document UpdateDocumentMetadata(Document documentMetadata);
        Document UploadDocumentWithMetadata(IStream stream, Document documentMetadata);
        IStream DownloadDocument(Document documentMetadata);
        Document ChangeDocumentWithMetadata(IStream stream, Document documentMetadata);

        // BOM functionality 
        BomHeader GetBomWithChildrenByNumber(string number);
        BomRow GetBomRowByNumber(string parentNumber, string childNumber);
        BomHeader CreateBomWithChildren(BomHeader bom);
        BomRow CreateBomRow(BomRow bomRow);
        BomHeader UpdateBomHeader(BomHeader bom);
        BomRow UpdateBomRow(BomRow bomRow);
        BomRow DeleteBomRow(BomRow bomRow);
    }
}