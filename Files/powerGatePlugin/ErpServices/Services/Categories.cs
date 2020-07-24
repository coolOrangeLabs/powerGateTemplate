using System;
using System.Collections.Generic;
using ErpServices.ErpManager.Interfaces;
using ErpServices.Metadata;
using powerGateServer.SDK;

namespace ErpServices.Services
{
    public class Categories :  ErpBaseService<Category>
    {
        public override string Name => "Categories";

        public Categories(IErpManager erpManager) : base(erpManager)
        {
        }

        public override IEnumerable<Category> Query(IExpression<Category> expression)
        {
            return new List<Category>
            {
                new Category {Key = "MISC", Value = "Miscellaneous"}, 
                new Category {Key = "SUPPLIERS", Value = "Supplies"}
            };
        }

        public override void Update(Category entity)
        {
            throw new NotSupportedException();
        }

        public override void Create(Category entity)
        {
            throw new NotSupportedException();
        }

        public override void Delete(Category entity)
        {
            throw new NotSupportedException();
        }
    }
}