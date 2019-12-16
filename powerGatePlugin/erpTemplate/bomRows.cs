using System.Collections.Generic;
using System.Data.Services.Common;
using System.Linq;
using powerGateServer.SDK;

namespace erpTemplate
{

    [DataServiceKey("ParentNumber","ChildNumber", "Position")]
    [DataServiceEntity]
    public class BomRow
    {
        public string ParentNumber { get; set; }
        public string ChildNumber { get; set; }
        public int Position { get; set; }
        public double Quantity { get; set; }
    }


    public class BomRows : ServiceMethod<BomRow>
    {
        static List<BomRow> bomRows = new List<BomRow>();
        public override string Name
        {
            get { return "BomRows"; }
        }

        public List<BomRow> GetRowsByParentNumber(string parentNumber)
        {
            return bomRows.Where(b=>b.ParentNumber.Equals(parentNumber)).ToList();
        }

        public override IEnumerable<BomRow> Query(IExpression<BomRow> expression)
        {
            if (expression.Where.Any(w => w.PropertyName.Equals("ParentNumber")))
            {
                var parentNumber = expression.Where.FirstOrDefault(w=>w.PropertyName.Equals("ParentNumber"));
                if(parentNumber != null && parentNumber.Value != null && parentNumber.Value.ToString() != "")
                    return GetRowsByParentNumber(parentNumber.Value.ToString());
            }
            return bomRows;
        }

        public override void Update(BomRow entity)
        {
            bomRows.Remove(entity);
            bomRows.Add(entity);
        }

        public override void Create(BomRow entity)
        {
            bomRows.Add(entity);
        }

        public override void Delete(BomRow entity)
        {
            bomRows.Remove(entity);
        }
    }
}
