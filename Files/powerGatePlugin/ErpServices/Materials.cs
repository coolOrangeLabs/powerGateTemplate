using System;
using System.Collections.Generic;
//using System.Configuration;
using System.Data.Services.Common;
using System.Linq;
using LiteDB;
using powerGateServer.SDK;

namespace ErpServices
{
    [DataServiceKey("Number")]
    [DataServiceEntity]
    public class Material
    {
        public string Number { get; set; }
        public string Description { get; set; }
        public string Title { get; set; }
        public string UnitOfMeasure { get; set; }
        public double Height { get; set; }
        public double Width { get; set; }
        public double Weight { get; set; }
        public string Type { get; set; }
        public DateTime CreateDate { get; set; }
        public DateTime ModifyDate { get; set; }
    }

    public class Materials : ServiceMethod<Material>
    {
        public override string Name => "Materials";

        public Materials()
        {
            BsonMapper.Global.Entity<Material>().Id(x => x.Number);
        }

        public string GetNextNumber()
        {
            var nextNumber = "500000";

            using (var db = new LiteDatabase(WebService.DatabaseFileLocation))
            {
                //var material = db.GetCollection<Material>().FindOne(LiteDB.Query.All(LiteDB.Query.Descending));
                var collection = db.GetCollection<Material>();

                int y;
                var material = collection.Find(x => int.TryParse(x.Number, out y)).OrderByDescending(x => x.Number).FirstOrDefault();
                if (material != null)
                    nextNumber = material.Number;

                return (int.Parse(nextNumber) +1).ToString();
            }
        }

        public override IEnumerable<Material> Query(IExpression<Material> expression)
        {
            //if (expression.Where.Any(b => b.PropertyName.Equals("Number")))
            //{
            //    var number = expression.Where.FirstOrDefault(w => w.PropertyName.Equals("Number"));
            //    if (number != null && number.Value != number && number.Value.ToString() != "")
            //    {
            //        using (var db = new LiteDatabase(WebService.DatabaseFileLocation))
            //        {
            //            return db.GetCollection<Material>()
            //                .Find(x => x.Number.Equals(number.Value));
            //        }
            //    }
            //    return null;
            //}

            using (var db = new LiteDatabase(WebService.DatabaseFileLocation))
            {
                return db.GetCollection<Material>()
                    .FindAll();
            }
        }

        public override void Update(Material entity)
        {
            using (var db = new LiteDatabase(WebService.DatabaseFileLocation))
            {
                db.GetCollection<Material>()
                    .Update(entity);
            }
        }

        public override void Create(Material entity)
        {
            if (entity.Number.Equals("*"))
                entity.Number = GetNextNumber();

            using (var db = new LiteDatabase(WebService.DatabaseFileLocation))
            {
                db.GetCollection<Material>()
                    .Insert(entity);
            }
        }

        public override void Delete(Material entity)
        {
            using (var db = new LiteDatabase(WebService.DatabaseFileLocation))
            {
                db.GetCollection<Material>()
                    .Delete(x => x.Number.Equals(entity.Number));
            }
        }
    }
}