using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using ErpServices.Metadata;
using LiteDB;
using log4net;
using powerGateServer.SDK;

namespace ErpServices.Services
{
    public class Materials : ServiceMethod<Material>
    {
        static readonly ILog Log =
            LogManager.GetLogger(MethodBase.GetCurrentMethod().DeclaringType);
        public override string Name => "Materials";

        public Materials()
        {
            BsonMapper.Global.Entity<Material>().Id(x => x.Number);
        }

        public string GetNextNumber()
        {
            Log.Info(">> GetNextNumber >>");
            var nextNumber = "500000";

            using (var db = new LiteDatabase(WebService.DatabaseFileLocation))
            {
                var collection = db.GetCollection<Material>();

                int y;
                var material = collection.Find(x => int.TryParse(x.Number, out y)).OrderByDescending(x => x.Number).FirstOrDefault();
                if (material != null)
                    nextNumber = material.Number;

                var nextIntNumber = int.Parse(nextNumber) + 1;
                Log.InfoFormat("GetNextNumber: {0}", nextIntNumber.ToString());
                return (nextIntNumber).ToString();
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
            //                .Find(x => x.Number.Equals(number.Value))
            //                .ToList();
            //        }
            //    }
            //    return null;
            //}

            using (var db = new LiteDatabase(WebService.DatabaseFileLocation))
            {
                return db.GetCollection<Material>()
                    .FindAll()
                    .ToList();
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