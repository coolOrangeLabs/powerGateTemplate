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
        public string Description { get; set; }
        public string Status { get; set; }
        public DateTime CreateDate { get; set; }
        public DateTime ModifyDate { get; set; }

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
                {
                    using (var db = new LiteDatabase(WebService.DatabaseFileLocation))
                    {
                        var bomHeaders = db.GetCollection<BomHeader>().Find(x => x.Number.Equals(number.Value)).ToList();
                        if (expression.Expand.Any(e => e.PropertyNames.Contains("BomRows")))
                        {
                            foreach (var bomHeader in bomHeaders)
                            {
                                bomHeader.BomRows = db.GetCollection<BomRow>()
                                    .Find(x => x.ParentNumber.Equals(bomHeader.Number))
                                    .OrderBy(x => x.Position)
                                    .ToList();
                            }
                        }
                        return bomHeaders;
                    }
                }
                return null;
            }

            using (var db = new LiteDatabase(WebService.DatabaseFileLocation))
            {
                var bomHeaders = db.GetCollection<BomHeader>().FindAll().ToList();
                if (expression.Expand.Any(e => e.PropertyNames.Contains("BomRows")))
                {
                    foreach (var bomHeader in bomHeaders)
                    {
                        bomHeader.BomRows = db.GetCollection<BomRow>()
                            .Find(x => x.ParentNumber.Equals(bomHeader.Number))
                            .OrderBy(x => x.Position)
                            .ToList();
                    }
                }
                return bomHeaders;
            }
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