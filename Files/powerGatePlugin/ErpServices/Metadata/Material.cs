using System;
using System.Data.Services.Common;
using LiteDB;

namespace ErpServices.Metadata
{
    [DataServiceKey("Number")]
    [DataServiceEntity]
    public class Material
    {
        public string Number { get; set; }
        public string Description { get; set; }
        public DateTime ModifiedDate { get; set; }
        public string UnitOfMeasure { get; set; }
        public string Type { get; set; }
        public bool IsBlocked { get; set; }
        public string Category { get; set; }
        public string Shelf { get; set; }
        public double Weight { get; set; }
        public string Dimensions { get; set; }
        [BsonIgnore]
        public bool IsVendorSpecified
        {
            get => !string.IsNullOrEmpty(VendorNumber);
            set => _ = value;
        }
        public string VendorNumber { get; set; }
        public string VendorName { get; set; }
        public string VendorItemNumber { get; set; }
        public decimal Cost { get; set; }
        public string SearchDescription { get; set; }
        public string Link
        {
            get => "https://www.coolorange.com/en-us/connect.html";
            set => _ = value;
        }
    }
}