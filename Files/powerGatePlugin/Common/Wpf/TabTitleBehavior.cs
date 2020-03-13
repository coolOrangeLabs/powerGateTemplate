using System.Windows;

namespace Common.Wpf
{
    public static class TabTitleBehavior
    {
        public readonly static DependencyProperty TabTitleProperty;

        public static string GetTabTitle(DependencyObject element)
        {
            return "Vault DataStandard";
        }

        public static void SetTabTitle(DependencyObject element, string value)
        {
        }

        private static void setTitle(object sender, RoutedEventArgs e)
        {
        }

        private static void WindowTitlePropertyChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
        {
        }
    }
}