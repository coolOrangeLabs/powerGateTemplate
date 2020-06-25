using powerGateServer.SDK;

namespace ErpServices.ErpManager.Interfaces
{
    public struct ErpMaterialSearchSettings
    {
        public ErpSearchProperty PropertyName { get; set; }
        public OperatorType? Operator { get; set; }
        public string SearchValue { get; set; }
    }

    public enum ErpSearchProperty
    {
        Number,
        Description
    }
}