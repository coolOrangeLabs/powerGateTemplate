using System;
using System.Collections.Generic;
using System.Linq;
using ErpServices.ErpManager.Interfaces;
using ErpServices.Metadata;
using powerGateServer.SDK;
using powerGateServer.SDK.Helper;

namespace ErpServices.Services
{
    public class BomHeaders : ErpBaseService<BomHeader>
    {
        public override string Name => "BomHeaders";

        public BomHeaders(IErpManager erpManager) : base(erpManager)
        {
        }

        public override IEnumerable<BomHeader> Query(IExpression<BomHeader> expression)
        {
            if (expression.IsSimpleWhereToken())
            {
                var number = expression.GetWhereValuesAsString("Number");
                Log.InfoFormat("Single query for bom number {0}", number);
                var bom = ErpManager.GetBomWithChildrenByNumber(number);
                if (bom != null)
                    return new[] { bom};
                return Enumerable.Empty<BomHeader>();
            }

            //var searchSettings = GetSearchSettings(expression);
            throw new NotSupportedException("Search ERP BOM headers is not supported!");
        }

        public override void Update(BomHeader entity)
        {
            ErpManager.UpdateBomHeader(entity);
        }

        public override void Create(BomHeader entity)
        {
            ErpManager.CreateBomWithChildren(entity);
        }

        public override void Delete(BomHeader entity)
        {
            throw new NotSupportedException();
        }
    }
}