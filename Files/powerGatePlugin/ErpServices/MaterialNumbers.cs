using System.Collections.Generic;
using System.Data.Services.Common;
using powerGateServer.SDK;

namespace ErpTemplate
{
    [DataServiceKey("NextNumber")]
    [DataServiceEntity]
    public class MaterialNumber
    {
        public string NextNumber { get; set; }
        public string MaterialType { get; set; }
    }

    public class MaterialNumbers : ServiceMethod<MaterialNumber>
    {
        public override string Name
        {
            get { return "MaterialNumbers"; }
        }

        public override IEnumerable<MaterialNumber> Query(IExpression<MaterialNumber> expression)
        {
            List<MaterialNumber> materialNumbers = new List<MaterialNumber>();
            var materials = new Materials();
            string nextNumber = materials.GetNextNumber();
            materialNumbers.Add(new MaterialNumber() { NextNumber = nextNumber, MaterialType = "" });
            return materialNumbers;
        }

        public override void Update(MaterialNumber entity)
        {
        }

        public override void Create(MaterialNumber entity)
        {
        }

        public override void Delete(MaterialNumber entity)
        {
        }
    }
}