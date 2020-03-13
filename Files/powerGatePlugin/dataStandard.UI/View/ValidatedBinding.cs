using System;

namespace dataStandard.UI.View
{
    public class ValidatedBinding : BindingDecoratorBase
    {
        public ValidatedBinding()
        {
        }

        public ValidatedBinding(string path) : this()
        {
        }

        public override object ProvideValue(IServiceProvider serviceProvider)
        {
            return null;
        }
    }
}