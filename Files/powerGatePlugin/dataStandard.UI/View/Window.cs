using System.Runtime.InteropServices;
using System.Windows;

namespace dataStandard.UI.View
{
    [ComVisible(false)]
    public class DSWindow : Window
    {

        public object CancelWindowCommand { get; set; }

        public object CloseWindowCommand { get; set; }

        public void Refresh()
        {
        }
    }
}