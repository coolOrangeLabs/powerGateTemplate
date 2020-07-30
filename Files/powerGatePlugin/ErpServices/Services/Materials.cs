using System;
using System.Collections.Generic;
using System.Linq;
using ErpServices.ErpManager.Interfaces;
using ErpServices.Metadata;
using powerGateServer.SDK;
using powerGateServer.SDK.Helper;

namespace ErpServices.Services
{
    public class Materials : ErpBaseService<Material>
    {
        public override string Name => "Materials";


        public Materials(IErpManager erpManager) : base(erpManager)
        {
        }

        public override IEnumerable<Material> Query(IExpression<Material> expression)
        {
            if (expression.IsSimpleWhereToken())
            {
                var number = expression.GetWhereValuesAsString("Number");
                Log.InfoFormat("Single query for item number {0}", number);
                var material = ErpManager.GetMaterialByNumber(number);

                if (material != null)
                    return new[] { material };
                return Enumerable.Empty<Material>();
            }
            var searchSettings = GetSearchSettings(expression);
            return ErpManager.SearchMaterials(searchSettings);
        }

        public override void Update(Material entity)
        {
            ErpManager.UpdateMaterial(entity);
        }

        public override void Create(Material entity)
        {
            ErpManager.CreateMaterial(entity);
        }

        public override void Delete(Material entity)
        {
            throw new NotSupportedException();
        }
    }
}