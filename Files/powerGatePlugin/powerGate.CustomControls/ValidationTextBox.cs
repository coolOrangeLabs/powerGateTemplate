using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Navigation;
using System.Windows.Shapes;

namespace powerGate.CustomControls
{
    /// <summary>
    /// Follow steps 1a or 1b and then 2 to use this custom control in a XAML file.
    ///
    /// Step 1a) Using this custom control in a XAML file that exists in the current project.
    /// Add this XmlNamespace attribute to the root element of the markup file where it is 
    /// to be used:
    ///
    ///     xmlns:MyNamespace="clr-namespace:powerGate.CustomControls"
    ///
    ///
    /// Step 1b) Using this custom control in a XAML file that exists in a different project.
    /// Add this XmlNamespace attribute to the root element of the markup file where it is 
    /// to be used:
    ///
    ///     xmlns:MyNamespace="clr-namespace:powerGate.CustomControls;assembly=powerGate.CustomControls"
    ///
    /// You will also need to add a project reference from the project where the XAML file lives
    /// to this project and Rebuild to avoid compilation errors:
    ///
    ///     Right click on the target project in the Solution Explorer and
    ///     "Add Reference"->"Projects"->[Select this project]
    ///
    ///
    /// Step 2)
    /// Go ahead and use your control in the XAML file.
    ///
    ///     <MyNamespace:CustomControl1/>
    ///
    /// </summary>
    public class ValidationTextBox : TextBox
    {
        static ValidationTextBox()
        {
            DefaultStyleKeyProperty.OverrideMetadata(typeof(ValidationTextBox), new FrameworkPropertyMetadata(typeof(ValidationTextBox)));
        }

        public static readonly DependencyProperty ErpValueProperty =
            DependencyProperty.Register(
                "ErpValue",
                typeof(string),
                typeof(ValidationTextBox),
                new FrameworkPropertyMetadata(string.Empty, FrameworkPropertyMetadataOptions.BindsTwoWayByDefault, ValuePropertyChanged));

        public string ErpValue
        {
            get
            {
                return (string)GetValue(ErpValueProperty);
            }
            set
            {
                SetValue(ErpValueProperty, value);
            }
        }

        private static void ValuePropertyChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
        {
            ValidationTextBox textBox = (ValidationTextBox)d;

            if (d.GetValue(ErpValueProperty) != d.GetValue(TextProperty))
                textBox.BorderBrush = Brushes.Red;
            else
            {
                textBox.BorderBrush = Brushes.Green;
            }
        }

        protected override void OnTextChanged(TextChangedEventArgs e)
        {
            base.OnTextChanged(e);

            if (Text.Equals(ErpValue, StringComparison.CurrentCultureIgnoreCase))
            {
                ClearValue(BackgroundProperty);
            }
            else
            {
                Background = Brushes.Red;
            }
        }
    }
}
