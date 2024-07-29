using System;
using System.Collections.Generic;
using System.Linq;

namespace DemoERPPlugin
{
	public class ErpSystem
	{
		private static ErpSystem _instance;

		private readonly List<Item> _items = new List<Item>();
		private readonly List<BomHeader> _bomHeaders = new List<BomHeader>();
		private readonly List<BomRow> _bomRows = new List<BomRow>();
		private ErpSystem()
		{
		}

		public IEnumerable<Item> GetItems()
		{
			return _items;
		}

		public IEnumerable<BomHeader> GetBomHeaders()
		{
			foreach (var header in _bomHeaders)
				header.Children = GetBomRows().Where(b => b.ParentNumber == header.Number).ToList();
			return _bomHeaders;
		}

		public IEnumerable<BomRow> GetBomRows()
		{
			foreach (var row in _bomRows)
				row.Item = _items.FirstOrDefault(i => i.Number == row.ChildNumber);
			return _bomRows;
		}

		public void AddItem(Item item)
		{
			if (_items.Any(i => i.Number == item.Number))
				throw new Exception("Item already exists");
			_items.Add(item);
		}

		public void AddBomHeader(BomHeader bomHeader)
		{
			if (_bomHeaders.Any(header => header.Number == bomHeader.Number))
				throw new Exception("BomHeader already exists");
			_bomHeaders.Add(bomHeader);

			if (bomHeader.Children != null)
				foreach (var childRow in bomHeader.Children)
					AddBomRow(childRow);
		}

		public void AddBomRow(BomRow bomRow)
		{
			if (_bomRows.Any(i => i.ChildNumber == bomRow.ChildNumber && i.ParentNumber == bomRow.ParentNumber))
				throw new Exception("BomRow already exists");
			_bomRows.Add(bomRow);

			if (bomRow.Item != null)
				AddItem(bomRow.Item);
		}

		public void UpdateItem(Item item)
		{
			DeleteItem(item);
			AddItem(item);
		}

		public void UpdateBomHeader(BomHeader bomHeader)
		{
			DeleteBomHeader(bomHeader);
			AddBomHeader(bomHeader);
		}

		public void UpdateBomRow(BomRow bomRow)
		{
			DeleteBomRow(bomRow);
			AddBomRow(bomRow);
		}

		public void DeleteItem(Item item)
		{
			var existingItem = _items.FirstOrDefault(i => i.Number == item.Number);
			if (existingItem != null)
				_items.Remove(existingItem);
		}

		public void DeleteBomHeader(BomHeader bomHeader)
		{
			var existingBomHeader = _bomHeaders.FirstOrDefault(header => header.Number == bomHeader.Number);
			if (existingBomHeader != null)
				_bomHeaders.Remove(existingBomHeader);
		}

		public void DeleteBomRow(BomRow bomRow)
		{
			var existingRow = _bomRows.FirstOrDefault(row => row.ParentNumber == bomRow.ParentNumber && row.ChildNumber == bomRow.ChildNumber);
			if (existingRow != null)
				_bomRows.Remove(existingRow);
		}

		public static ErpSystem GetInstance()
		{
			return _instance == null ? _instance = new ErpSystem() : _instance;
		}
	}
}