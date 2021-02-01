using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using ErpServices.ErpManager.Interfaces;
using ErpServices.Metadata;
using log4net;
using powerGateServer.SDK;
using powerGateServer.SDK.Helper;

namespace ErpServices.Services
{
    public class BomRows : ErpBaseService<BomRow>
    {
        static readonly ILog Log =
            LogManager.GetLogger(MethodBase.GetCurrentMethod().DeclaringType);
        public override string Name => "BomRows";

        public BomRows(IErpManager erpManager) : base(erpManager)
        {
        }

        public override IEnumerable<BomRow> Query(IExpression<BomRow> expression)
        {
            if (expression.IsSimpleWhereToken())
            {
                var parentNumber = expression.GetWhereValuesAsString("ParentNumber");
                var childNumber = expression.GetWhereValuesAsString("ChildNumber");
                Log.InfoFormat("Single query for bom row, header number {0} and child number", parentNumber, childNumber);
                var bomRow = ErpManager.GetBomRowByNumber(parentNumber, childNumber);
                if (bomRow != null)
                    return new[] { bomRow };
                return Enumerable.Empty<BomRow>();
            }

            //var searchSettings = GetSearchSettings(expression);
            throw new NotSupportedException("Search ERP BOM headers is not supported!");
        }

        public override void Update(BomRow entity)
        {
            ErpManager.UpdateBomRow(entity);
        }

        public override void Create(BomRow entity)
        {
            ErpManager.CreateBomRow(entity);
        }

        public override void Delete(BomRow entity)
        {
            ErpManager.DeleteBomRow(entity);
        }
    }
}