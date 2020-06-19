using System;
using ErpServices.ErpManager.Interfaces;
using ErpServices.Metadata;

namespace ErpServices.ErpManager.Implementation
{
    public partial class ErpManager : IErpManager
    {
        public BomHeader GetBomByNumber(string number)
        {
            throw new NotImplementedException();
        }

        public BomRow GetBomRowByNumber(string parentNumber, string childNumber)
        {
            throw new NotImplementedException();
        }

        public BomHeader CreateBomWithChildren(BomHeader bom)
        {
            throw new NotImplementedException();
        }

        public BomRow CreateBomRow(BomRow bomRow)
        {
            throw new NotImplementedException();
        }

        public BomHeader UpdateBomHeader(BomHeader bom)
        {
            throw new NotImplementedException();
        }

        public BomRow UpdateBomRow(BomRow bomRow)
        {
            throw new NotImplementedException();
        }

        public BomRow DeleteBomRow(BomRow bomRow)
        {
            throw new NotImplementedException();
        }
    }
}