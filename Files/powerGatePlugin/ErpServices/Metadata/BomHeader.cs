using System;
using System.Collections.Generic;
using System.Data.Services.Common;
using LiteDB;

namespace ErpServices.Metadata
{
    [DataServiceKey("Number")]
    [DataServiceEntity]
    public class BomHeader
    {
        public string Number { get; set; }
        [BsonIgnore]
        public string Description { get; set; }
        public string State { get; set; }
        public string UnitOfMeasure { get; set; }
        public DateTime ModifiedDate { get; set; }
        public string Link
        {
            get => "https://www.coolorange.com/en-us/connect.html";
            set => _ = value;
        }

        public List<BomRow> BomRows { get; set; }

        public BomHeader()
        {
            BomRows = new List<BomRow>();
        }
    }
}