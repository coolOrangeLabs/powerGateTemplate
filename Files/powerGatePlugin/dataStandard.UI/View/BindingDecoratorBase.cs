using System.ComponentModel;
using System.Windows.Markup;

namespace dataStandard.UI.View
{
    [MarkupExtensionReturnType(typeof(object))]
    public abstract class BindingDecoratorBase : MarkupExtension
    {
        [DefaultValue(null)]
        public string StringFormat { get; set; }
    }
}