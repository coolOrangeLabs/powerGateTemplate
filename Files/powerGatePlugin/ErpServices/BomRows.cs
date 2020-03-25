using System;
using System.Collections.Generic;
using System.Data.Services;
using System.Data.Services.Common;
using System.Linq;
using LiteDB;
using powerGateServer.SDK;

namespace ErpServices
{
    [DataServiceKey("ParentNumber","ChildNumber","Position")]
    [DataServiceEntity]
    [IgnoreProperties("Id")]
    public class BomRow
    {
        public string ParentNumber { get; set; }
        public string ChildNumber { get; set; }
        public int Position { get; set; }
        public double Quantity { get; set; }

        [BsonIgnore]
        public string Description { get; set; }

        public string Id => $"{ParentNumber}+{ChildNumber}+{Position.ToString()}";
    }

    public class BomRows : ServiceMethod<BomRow>
    {
        public override string Name => "BomRows";

        public BomRows()
        {
            BsonMapper.Global.Entity<BomRow>().Id(x => x.Id);
        }

        public override IEnumerable<BomRow> Query(IExpression<BomRow> expression)
        {
            if (expression.Where.Any(w => w.PropertyName.Equals("ParentNumber")))
            {
                var parentNumber = expression.Where.FirstOrDefault(w => w.PropertyName.Equals("ParentNumber"));
                if (parentNumber != null && parentNumber.Value != null && parentNumber.Value.ToString() != "")
                {
                    return GetBomRows(parentNumber.Value.ToString());
                }
            }

            return GetBomRows();
        }

        public static List<BomRow> GetBomRows(string parentNumber = null)
        {
            List<BomRow> bomRows;
            using (var db = new LiteDatabase(WebService.DatabaseFileLocation))
            {
                if (parentNumber == null)
                {
                    bomRows = db.GetCollection<BomRow>()
                        .FindAll()
                        .OrderBy(x => x.Position)
                        .ToList();
                }
                else
                {
                    bomRows = db.GetCollection<BomRow>()
                        .Find(x => x.ParentNumber.Equals(parentNumber))
                        .OrderBy(x => x.Position)
                        .ToList();                    
                }

                foreach (var bomRow in bomRows)
                {
                    var material = db.GetCollection<Material>()
                        .FindOne(x => x.Number.Equals(bomRow.ChildNumber));
                    bomRow.Description = material.Description;
                }
            }
            return bomRows;
        }

        public override void Update(BomRow entity)
        {
            using (var db = new LiteDatabase(WebService.DatabaseFileLocation))
            {
                db.GetCollection<BomRow>()
                    .Update(entity);
            }
        }

        public override void Create(BomRow entity)
        {
            using (var db = new LiteDatabase(WebService.DatabaseFileLocation))
            {
                db.GetCollection<BomRow>()
                    .Insert(entity);
            }
        }

        public override void Delete(BomRow entity)
        {
            using (var db = new LiteDatabase(WebService.DatabaseFileLocation))
            {
                db.GetCollection<BomRow>()
                    .Delete(x => x.Id.Equals(entity.Id));
            }
        }
    }
}