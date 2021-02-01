using System.Collections.Generic;
using System.Linq;
using ErpServices.ErpManager.Interfaces;
using ErpServices.Metadata;
using LiteDB;

namespace ErpServices.ErpManager.Implementation
{
    public partial class ErpManager : IErpManager
    {
        public BomHeader GetBomWithChildrenByNumber(string number)
        {
            return ExecuteOnDatabase(delegate (LiteDatabase database)
            {
                var bomHeader = database.GetCollection<BomHeader>().Find(header => header.Number == number).FirstOrDefault();
                if (bomHeader != null)
                    bomHeader.BomRows = GetBomRowsByHeaderNumber(bomHeader.Number);
                return bomHeader;
            });
        }

        List<BomRow> GetBomRowsByHeaderNumber(string parentNumber)
        {
            return ExecuteOnDatabase(delegate (LiteDatabase database)
            {
                var bomRows = database.GetCollection<BomRow>()
                    .Find(x => x.ParentNumber.Equals(parentNumber))
                    .OrderBy(x => x.Position)
                    .ToList();

                foreach (var bomRow in bomRows)
                {
                    var material = GetMaterialyByNumber(bomRow.ChildNumber);
                    bomRow.Description = material.Description;
                    bomRow.UnitOfMeasure = material.UnitOfMeasure;
                }

                return bomRows;
            });
        }

        public BomRow GetBomRowByNumber(string parentNumber, string childNumber)
        {
            var bomRows = GetBomRowsByHeaderNumber(parentNumber);
            return bomRows.FirstOrDefault(b => b.ChildNumber == childNumber);
        }

        public BomHeader CreateBomWithChildren(BomHeader bom)
        {
            return ExecuteOnDatabase(delegate (LiteDatabase database)
            {
                database.GetCollection<BomHeader>().Insert(bom);
                foreach (var bomRow in bom.BomRows)
                    CreateBomRow(bomRow);
                return bom;
            });
        }

        public BomRow CreateBomRow(BomRow bomRow)
        {
            return ExecuteOnDatabase(delegate (LiteDatabase database)
            {
                database.GetCollection<BomRow>().Insert(bomRow);
                return bomRow;
            });
        }

        public BomHeader UpdateBomHeader(BomHeader bom)
        {
            return ExecuteOnDatabase(delegate (LiteDatabase database)
            {
                database.GetCollection<BomHeader>().Update(bom);
                return bom;
            });
        }

        public BomRow UpdateBomRow(BomRow bomRow)
        {
            return ExecuteOnDatabase(delegate (LiteDatabase database)
            {
                database.GetCollection<BomRow>().Update(bomRow);
                return bomRow;
            });
        }

        public BomRow DeleteBomRow(BomRow bomRow)
        {
            return ExecuteOnDatabase(delegate (LiteDatabase database)
            {
                database.GetCollection<BomRow>().Delete(bomRow.Id);
                return bomRow;
            });
        }
    }
}