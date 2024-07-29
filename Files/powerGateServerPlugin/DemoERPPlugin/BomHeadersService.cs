using powerGateServer.SDK;
using System.Collections.Generic;
using System.Data.Services.Common;

namespace DemoERPPlugin
{
	[DataServiceKey("Number")]
	[DataServiceEntity]
	public class BomHeader
	{
		public string Number { get; set; }
		public string Description { get; set; }
		public decimal BaseQuantity { get; set; }
		public IEnumerable<BomRow> Children { get; set; }

		public BomHeader()
		{
			Children = new List<BomRow>();
		}
	}

	public class BomHeaders : ServiceMethod<BomHeader>
	{
		readonly ErpSystem _erpSystem = ErpSystem.GetInstance();

		public override IEnumerable<BomHeader> Query(IExpression<BomHeader> expression)
		{
			return _erpSystem.GetBomHeaders();
		}

		public override void Update(BomHeader entity)
		{
			_erpSystem.UpdateBomHeader(entity);
		}

		public override void Create(BomHeader entity)
		{
			_erpSystem.AddBomHeader(entity);
		}

		public override void Delete(BomHeader entity)
		{
			_erpSystem.DeleteBomHeader(entity);
		}
	}

}
