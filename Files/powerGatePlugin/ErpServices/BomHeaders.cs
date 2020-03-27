using System;
using System.Collections.Generic;
using System.Data.Services.Common;
using System.Linq;
using LiteDB;
using powerGateServer.SDK;

namespace ErpServices
{
    [DataServiceKey("Number")]
    [DataServiceEntity]
    public class BomHeader
    {
        public string Number { get; set; }
        [BsonIgnore]
        public string Description { get; set; }
        public string State { get; set; }
        public DateTime ModifiedDate { get; set; }

        public List<BomRow> BomRows { get; set;  }

        public BomHeader()
        {
            BomRows = new List<BomRow>();
        }
    }


    public class BomHeaders : ServiceMethod<BomHeader>
    {
        public override string Name => "BomHeaders";

        public BomHeaders()
        {
            BsonMapper.Global.Entity<BomHeader>().Id(x => x.Number);
            //BsonMapper.Global.Entity<BomHeader>().DbRef(x => x.BomRows);
        }

        public override IEnumerable<BomHeader> Query(IExpression<BomHeader> expression)
        {
            if (expression.Where.Any(b => b.PropertyName.Equals("Number")))
            {
                var number = expression.Where.FirstOrDefault(w => w.PropertyName.Equals("Number"));
                if (number != null && number.Value != number && number.Value.ToString() != "")
                    return GetBomHeaders(number.Value.ToString());
            }

            return GetBomHeaders();
        }

        public static List<BomHeader> GetBomHeaders(string number = null)
        {
            List<BomHeader> bomHeaders;
            using (var db = new LiteDatabase(WebService.DatabaseFileLocation))
            {
                if (number == null)
                {
                    bomHeaders = db.GetCollection<BomHeader>()
                        .FindAll()
                        .ToList();
                }
                else
                {
                    bomHeaders = db.GetCollection<BomHeader>()
                        .Find(x => x.Number.Equals(number))
                        .ToList();
                }

                foreach (var bomHeader in bomHeaders)
                {
                    var material = db.GetCollection<Material>()
                        .FindOne(x => x.Number.Equals(bomHeader.Number));
                    bomHeader.Description = material.Description;
                    bomHeader.BomRows = BomRows.GetBomRows(bomHeader.Number);
                }
            }
            return bomHeaders;
        }

        public override void Update(BomHeader entity)
        {
            using (var db = new LiteDatabase(WebService.DatabaseFileLocation))
            {
                db.GetCollection<BomHeader>()
                    .Update(entity);
            }
        }

        public override void Create(BomHeader entity)
        {
            using (var db = new LiteDatabase(WebService.DatabaseFileLocation))
            {
                db.GetCollection<BomRow>()
                    .Insert(entity.BomRows);
                db.GetCollection<BomHeader>()
                    .Insert(entity);
            }
        }

        public override void Delete(BomHeader entity)
        {
            using (var db = new LiteDatabase(WebService.DatabaseFileLocation))
            {
                db.GetCollection<BomRow>()
                    .Delete(x => x.ParentNumber.Equals(entity.Number));
                db.GetCollection<BomHeader>()
                    .Delete(x => x.Number.Equals(entity.Number));
            }
        }
    }
}