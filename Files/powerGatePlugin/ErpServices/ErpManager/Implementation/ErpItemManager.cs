using System.Collections.Generic;
using System.Linq;
using ErpServices.ErpManager.Interfaces;
using ErpServices.Metadata;
using LiteDB;
using powerGateServer.SDK;

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
            if (query.Count() == 1)
            {
                var query1 = query.First();
                if (query1.Operator == OperatorType.Contains)
                {
                    if (query1.PropertyName == ErpSearchProperty.Number)
                        return ExecuteOnDatabase(database => database.GetCollection<Material>().Find(material => material.Number.Contains(query1.SearchValue)).ToList());
                    if (query1.PropertyName == ErpSearchProperty.Description)
                        return ExecuteOnDatabase(database => database.GetCollection<Material>().Find(material => material.Description.Contains(query1.SearchValue)).ToList());
                }
                if (query1.Operator == OperatorType.StartsWith)
                {
                    if (query1.PropertyName == ErpSearchProperty.Number)
                        return ExecuteOnDatabase(database => database.GetCollection<Material>().Find(material => material.Number.StartsWith(query1.SearchValue)).ToList());
                    if (query1.PropertyName == ErpSearchProperty.Description)
                        return ExecuteOnDatabase(database => database.GetCollection<Material>().Find(material => material.Description.StartsWith(query1.SearchValue)).ToList());
                }
                if (query1.Operator == OperatorType.EndsWith)
                {
                    if (query1.PropertyName == ErpSearchProperty.Number)
                        return ExecuteOnDatabase(database => database.GetCollection<Material>().Find(material => material.Number.EndsWith(query1.SearchValue)).ToList());
                    if (query1.PropertyName == ErpSearchProperty.Description)
                        return ExecuteOnDatabase(database => database.GetCollection<Material>().Find(material => material.Description.EndsWith(query1.SearchValue)).ToList());
                }

                if (query1.Operator == OperatorType.Equals)
                {
                    if (query1.PropertyName == ErpSearchProperty.Number)
                        return ExecuteOnDatabase(database => database.GetCollection<Material>().Find(material => material.Number.Equals(query1.SearchValue)).ToList());
                    if (query1.PropertyName == ErpSearchProperty.Description)
                        return ExecuteOnDatabase(database => database.GetCollection<Material>().Find(material => material.Description.Equals(query1.SearchValue)).ToList());
                }
            }
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