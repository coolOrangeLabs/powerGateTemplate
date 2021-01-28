using System;
using System.Collections.Generic;
using System.Reflection;
using ErpServices.ErpManager.Interfaces;
using log4net;
using powerGateServer.SDK;
using powerGateServer.SDK.Helper;

namespace ErpServices.Services
{
    public abstract class ErpBaseService<T> : ServiceMethod<T> 
    {
        protected IErpManager ErpManager;

        protected static readonly ILog Log =
            LogManager.GetLogger(MethodBase.GetCurrentMethod().DeclaringType);

        protected ErpBaseService(IErpManager erpManager)
        {
            ErpManager = erpManager;
        }

        protected IEnumerable<ErpMaterialSearchSettings> GetSearchSettings(IExpression<T> expression)
        {
            var query = new List<ErpMaterialSearchSettings>();
            foreach (var whereToken in expression.Where)
            {
                var searchValue = expression.GetWhereValueByName(whereToken.PropertyName);

                if (!Enum.TryParse(whereToken.PropertyName, out ErpSearchProperty searchProperty))
                {
                    Log.WarnFormat("Search query for property name '{0}' is not supported by ERP, therefore make a search with other properties in order to filter the values!", searchValue);
                    continue;
                }

                query.Add(new ErpMaterialSearchSettings
                {
                    Operator = whereToken.Operator,
                    PropertyName = searchProperty,
                    SearchValue = searchValue.ToString()
                });
            }
            return query;
        }
    }
}