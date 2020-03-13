using System.Windows;
using System.Windows.Controls;
using System.Windows.Markup;
using System.Windows.Media;

namespace dataStandard.UI.View
{
    public class DSNumSchemeCtrl : UserControl, IComponentConnector
    {
        static DSNumSchemeCtrl()
        {
            DefaultStyleKeyProperty.OverrideMetadata(typeof(DSNumSchemeCtrl), new
                FrameworkPropertyMetadata(typeof(DSNumSchemeCtrl)));
        }

        public DSNumSchemeCtrl()
        {
            InitializeComponent();
        }

        public string GeneratedNumberProperty { get; set; }

        public bool NumSchmFieldsEmpty { get; set; }

        public static readonly DependencyProperty SchemeProperty = DependencyProperty.Register("Scheme",
            typeof(NumSchm),
            typeof(Control), new FrameworkPropertyMetadata(new NumSchm()));

        public NumSchm Scheme
        {
            get => GetValue(SchemeProperty) as NumSchm;
            set => SetValue(SchemeProperty, value);
        }

        public void Connect(int connectionId, object target)
        {
        }

        public void InitializeComponent()
        {
            Background = Brushes.Red;
        }
    }
}