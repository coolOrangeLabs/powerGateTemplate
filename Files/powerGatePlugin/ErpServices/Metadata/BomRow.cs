using System;
using System.Data.Services;
using System.Data.Services.Common;
using LiteDB;

namespace ErpServices.Metadata
{
    [DataServiceKey("ParentNumber","ChildNumber","Position")]
    [DataServiceEntity]
    [IgnoreProperties("Id")]
    public class BomRow
    {
        public string ParentNumber { get; set; }
        public string ChildNumber { get; set; }
        public int Position { get; set; }
        public string Type { get; set; }
        public double Quantity { get; set; }
        [BsonIgnore]
        public string UnitOfMeasure { get; set; }
        [BsonIgnore]
        public string Description { get; set; }
        public DateTime ModifiedDate { get; set; }

        public string Id => $"{ParentNumber}+{ChildNumber}+{Position.ToString()}";
    }
}