using powerGateServer.SDK;
using System.Collections.Generic;
using System.Data.Services.Common;

namespace DemoERPPlugin
{
	[DataServiceKey("ParentNumber", "ChildNumber")]
	[DataServiceEntity]
	public class BomRow
	{
		public string ParentNumber { get; set; }
		public string ChildNumber { get; set; }
		public int Position { get; set; }
		public decimal Quantity { get; set; }
		public Item Item { get; set; }
	}

	public class BomRows : ServiceMethod<BomRow>
	{
		readonly ErpSystem _erpSystem = ErpSystem.GetInstance();
		public override IEnumerable<BomRow> Query(IExpression<BomRow> expression)
		{
			return _erpSystem.GetBomRows();
		}

		public override void Update(BomRow entity)
		{
			_erpSystem.UpdateBomRow(entity);
		}

		public override void Create(BomRow entity)
		{
			_erpSystem.AddBomRow(entity);
		}

		public override void Delete(BomRow entity)
		{
			_erpSystem.DeleteBomRow(entity);
		}
	}

}
