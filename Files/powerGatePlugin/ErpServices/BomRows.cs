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
        public DateTime CreateDate { get; set; }
        public DateTime ModifyDate { get; set; }

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
                    using (var db = new LiteDatabase(WebService.DatabaseFileLocation))
                    {
                        return db.GetCollection<BomRow>()
                            .Find(x => x.ParentNumber.Equals(parentNumber.Value))
                            .OrderBy(x => x.Position)
                            .ToList();
                    }
                }
                return null;
            }

            using (var db = new LiteDatabase(WebService.DatabaseFileLocation))
            {
                return db.GetCollection<BomRow>()
                    .FindAll()
                    .OrderBy(x => x.Position)
                    .ToList();
            }
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