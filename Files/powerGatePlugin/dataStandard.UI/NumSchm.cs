using System.ComponentModel;
using System.Xml.Serialization;

namespace dataStandard.UI
{
    public class NumSchm
    {
        [XmlElement("FieldArray", Order = 0)] public string[] FieldArray { get; set; }

        [XmlAttribute] public bool IsAct { get; set; }

        [XmlAttribute] public bool IsDflt { get; set; }

        [XmlAttribute] public bool IsInUse { get; set; }

        [XmlAttribute] public bool IsSys { get; set; }

        [XmlAttribute] public string Name { get; set; }

        [XmlAttribute] public long SchmID { get; set; }

        [XmlAttribute] public string SysName { get; set; }

        [XmlAttribute] public bool ToUpper { get; set; }

        [Browsable(false)]
        [EditorBrowsable(EditorBrowsableState.Never)]
        public NumSchm()
        {
        }
    }
}