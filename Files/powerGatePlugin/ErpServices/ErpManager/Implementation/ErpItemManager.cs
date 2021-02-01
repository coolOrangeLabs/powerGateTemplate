using System.Collections.Generic;
using System.Linq;
using ErpServices.ErpManager.Interfaces;
using ErpServices.Metadata;
using LiteDB;

namespace ErpServices.ErpManager.Implementation
{
    public partial class ErpManager : IErpManager
    {
        public Material GetMaterialyByNumber(string number)
        {
            return ExecuteOnDatabase(database => database.GetCollection<Material>().Find(material => material.Number == number)).FirstOrDefault();
        }

        public IEnumerable<Material> SearchMaterials(IEnumerable<ErpMaterialSearchSettings> query)
        {
            // ToDO: Parse the Query parameter and execute on DB optimized query
            return ExecuteOnDatabase(database => database.GetCollection<Material>()
                .FindAll().ToList());
        }

        public Material CreateMaterial(Material material)
        {
            if (material.Number.Equals("*"))
                material.Number = GetNextNumber();
            Log.InfoFormat("Create material: {0}", material.Number);
            ExecuteOnDatabase(database => database.GetCollection<Material>().Insert(material));
            return material;
        }

        string GetNextNumber()
        {
            Log.Info(">> GetNextNumber >>");
            var nextNumber = "500000";

            return ExecuteOnDatabase(delegate (LiteDatabase database)
            {
                var collection = database.GetCollection<Material>();

                int y;
                var material = collection.Find(x => int.TryParse(x.Number, out y)).OrderByDescending(x => x.Number).FirstOrDefault();
                if (material != null)
                    nextNumber = material.Number;

                var nextIntNumber = int.Parse(nextNumber) + 1;
                Log.InfoFormat("GetNextNumber: {0}", nextIntNumber.ToString());
                return (nextIntNumber).ToString();
            });
        }

        public Material UpdateMaterial(Material material)
        {
            ExecuteOnDatabase(database => database.GetCollection<Material>().Update(material));
            return material;
        }
    }
}