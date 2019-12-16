using System;
using System.Collections.Generic;
using System.Data.Services.Common;
using System.Linq;
using powerGateServer.SDK;

namespace erpTemplate
{

    [DataServiceKey("Number")]
    [DataServiceEntity]
    public class Material
    {
        public string Number { get; set; }
        public string Description { get; set; }
        public string UnitOfMeasure { get; set; }
        public double Height { get; set; }
        public double Width { get; set; }
        public double Weight { get; set; }
        public string Type { get; set; }
        public DateTime CreateDate { get; set; }
    }


    public class Materials : ServiceMethod<Material>
    {
        static List<Material> materials = new List<Material>();
        public override string Name
        {
            get { return "Materials"; }
        }

        public string GetNextNumber()
        {
            string nextNumber = "500000";
            var highestNumber = materials.OrderByDescending(m => m.Number).FirstOrDefault();
            if (highestNumber != null)
                nextNumber = highestNumber.Number;
            int nn = int.Parse(nextNumber);
            nn++;
            return nn.ToString();
        }

        public override IEnumerable<Material> Query(IExpression<Material> expression)
        {
            return materials;
        }

        public override void Update(Material entity)
        {
            materials.Remove(entity);
            materials.Add(entity);
        }

        public override void Create(Material entity)
        {
            materials.Add(entity);
        }

        public override void Delete(Material entity)
        {
            materials.Remove(entity);
        }
    }
}
