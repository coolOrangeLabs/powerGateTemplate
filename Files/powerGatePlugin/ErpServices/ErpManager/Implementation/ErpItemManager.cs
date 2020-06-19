using System;
using System.Collections.Generic;
using ErpServices.ErpManager.Interfaces;
using ErpServices.Metadata;

namespace ErpServices.ErpManager.Implementation
{
    public partial class ErpManager : IErpManager
    {
        public Material GetMaterialyByNumber(string number)
        {
            throw new NotImplementedException();
        }

        public IEnumerable<Material> SearchMaterials(IEnumerable<ErpMaterialSearchSettings> query)
        {
            throw new NotImplementedException();
        }

        public Material CreateMaterial(Material material)
        {
            throw new NotImplementedException();
        }

        public Material UpdateMaterial(Material material)
        {
            throw new NotImplementedException();
        }
    }
}