using System;
using System.Collections.Generic;
using System.Data.Services;
using System.Data.Services.Common;
using System.Linq;
using System.Reflection;
using LiteDB;
using log4net;
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
        public string Type { get; set; }
        public double Quantity { get; set; }
        [BsonIgnore]
        public string UnitOfMeasure { get; set; }
        [BsonIgnore]
        public string Description { get; set; }
        public DateTime ModifiedDate { get; set; }

        public string Id => $"{ParentNumber}+{ChildNumber}+{Position.ToString()}";
    }

    public class BomRows : ServiceMethod<BomRow>
    {
        static readonly ILog Log =
            LogManager.GetLogger(MethodBase.GetCurrentMethod().DeclaringType);
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
                    return GetBomRows(parentNumber.Value.ToString());
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
                    bomRow.UnitOfMeasure = material.UnitOfMeasure;
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