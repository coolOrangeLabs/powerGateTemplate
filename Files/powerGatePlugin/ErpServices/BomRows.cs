using System.Collections.Generic;
using System.Data.Services.Common;
using System.Linq;
using powerGateServer.SDK;

namespace ErpServices
{
    [DataServiceKey("ParentNumber","ChildNumber","Position")]
    [DataServiceEntity]
    public class BomRow
    {
        public string ParentNumber { get; set; }
        public string ChildNumber { get; set; }
        public int Position { get; set; }
        public double Quantity { get; set; }

        public string Key
        {
            get => $"{ParentNumber}+{ChildNumber}+{Position.ToString()}";
            set => _ = value;
        }
    }

    public class BomRows : ServiceMethod<BomRow>
    {
        static readonly Dictionary<string, BomRow> BomRowStorage = new Dictionary<string, BomRow>();

        public override string Name => "BomRows";

        public List<BomRow> GetRowsByParentNumber(string parentNumber)
        {
            return BomRowStorage.Values.Where(b => b.ParentNumber.Equals(parentNumber)).ToList();
        }

        public override IEnumerable<BomRow> Query(IExpression<BomRow> expression)
        {
            if (expression.Where.Any(w => w.PropertyName.Equals("ParentNumber")))
            {
                var parentNumber = expression.Where.FirstOrDefault(w => w.PropertyName.Equals("ParentNumber"));
                if (parentNumber != null && parentNumber.Value != null && parentNumber.Value.ToString() != "")
                    return GetRowsByParentNumber(parentNumber.Value.ToString());
            }
            return BomRowStorage.Values;
        }

        public override void Update(BomRow entity)
        {
            BomRowStorage.Remove(entity.Key);
            BomRowStorage.Add(entity.Key, entity);
        }

        public override void Create(BomRow entity)
        {
            BomRowStorage.Add(entity.Key, entity);
        }

        public override void Delete(BomRow entity)
        {
            BomRowStorage.Remove(entity.Key);
        }
    }
}