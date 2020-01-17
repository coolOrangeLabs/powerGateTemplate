using System.Collections.Generic;
using System.Data.Services.Common;
using System.Linq;
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

        public List<BomRow> BomRows { get; set;  }
        /* {
            get {
                var bomRows = new BomRows();
                return bomRows.GetRowsByParentNumber(Number);
            }
            set {
                var bomRows = new BomRows();
                foreach (var bomRow in value)
                    bomRows.Create(bomRow);
            }
        }*/

        public BomHeader()
        {
            BomRows = new List<BomRow>();
        }
    }


    public class BomHeaders : ServiceMethod<BomHeader>
    {
        static readonly Dictionary<string, BomHeader> BomHeaderStorage = new Dictionary<string, BomHeader>();

        public override string Name
        {
            get { return "BomHeaders"; }
        }

        public override IEnumerable<BomHeader> Query(IExpression<BomHeader> expression)
        {
            List<BomHeader> boms = new List<BomHeader>();
            if(expression.Where.Any(b => b.PropertyName.Equals("Number")))
            {
                var number = expression.Where.FirstOrDefault(w => w.PropertyName.Equals("Number"));
                if (number != null && number.Value != number && number.Value.ToString() != "")
                {
                    if (BomHeaderStorage.TryGetValue(number.Value.ToString(), out var bom))
                    {
                        var bomRows = new BomRows();
                        bom.BomRows = bomRows.GetRowsByParentNumber(number.Value.ToString());
                        boms.Add(bom);
                    }
                }
            }
            return boms;
        }

        public override void Update(BomHeader entity)
        {
            BomHeaderStorage.Remove(entity.Number);
            BomHeaderStorage.Add(entity.Number, entity);
        }

        public override void Create(BomHeader entity)
        {
            BomHeaderStorage.Add(entity.Number, entity);
            var bomRows = new BomRows();
            foreach (var bomRow in entity.BomRows)
                bomRows.Create(bomRow);
        }

        public override void Delete(BomHeader entity)
        {
            BomHeaderStorage.Remove(entity.Number);
        }
    }
}