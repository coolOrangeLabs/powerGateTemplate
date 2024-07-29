using powerGateServer.SDK;
using System.Collections.Generic;
using System.Data.Services.Common;

namespace DemoERPPlugin
{
	[DataServiceKey("Number")]
	[DataServiceEntity]
	public class Item
	{
		public string Number { get; set; }
		public string Title { get; set; }
		public string Description { get; set; }
		public string UnitOfMeasure { get; set; }
		public decimal Weight { get; set; }
		public string Material { get; set; }
		public decimal Price { get; set; }
		public int Stock { get; set; }
		public bool MakeBuy { get; set; }
		public string Supplier { get; set; }
	}

	public class Items : ServiceMethod<Item>
	{
		readonly ErpSystem _erpSystem = ErpSystem.GetInstance();
		public override IEnumerable<Item> Query(IExpression<Item> expression)
		{
			return _erpSystem.GetItems();
		}

		public override void Update(Item entity)
		{
			_erpSystem.UpdateItem(entity);
		}

		public override void Create(Item entity)
		{
			_erpSystem.AddItem(entity);
		}

		public override void Delete(Item entity)
		{
			_erpSystem.DeleteItem(entity);
		}
	}

}
