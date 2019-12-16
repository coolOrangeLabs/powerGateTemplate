using System.Collections.Generic;
using System.Data.Services.Common;
using System.Linq;
using powerGateServer.SDK;

namespace erpTemplate
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
        static List<BomHeader> bomHeaders = new List<BomHeader>();
        public override string Name
        {
            get { return "BomHeaders"; }
        }

        public override IEnumerable<BomHeader> Query(IExpression<BomHeader> expression)
        {
            List<BomHeader> boms = new List<BomHeader>();
            if(expression.Where.Any(b=>b.PropertyName.Equals("Number")))
            {
                var number = expression.Where.FirstOrDefault(w => w.PropertyName.Equals("Number"));
                if (number != null && number.Value != number && number.Value.ToString() != "")
                {
                    var bom = bomHeaders.FirstOrDefault(b => b.Number.Equals(number.Value));
                    if (bom != null)
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
            bomHeaders.Remove(entity);
            bomHeaders.Add(entity);
        }

        public override void Create(BomHeader entity)
        {
            bomHeaders.Add(entity);
            var bomRows = new BomRows();
            foreach (var bomRow in entity.BomRows)
                bomRows.Create(bomRow);
        }

        public override void Delete(BomHeader entity)
        {
            bomHeaders.Remove(entity);
        }
    }
}
