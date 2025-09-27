using System;
using System.Windows.Forms;

namespace CopyPasta
{
    internal static class Program
    {
        /// <summary>
        /// The main entry point for the application.
        /// </summary>
        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            
            // Run the tray application
            Application.Run(new TrayApplicationContext());
        }
    }
}