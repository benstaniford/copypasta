using System;
using System.Drawing;
using System.Windows.Forms;
using System.Threading.Tasks;

namespace CopyPasta
{
    public class TrayApplicationContext : ApplicationContext
    {
        private NotifyIcon _trayIcon = null!;
        private ClipboardMonitor _clipboardMonitor = null!;
        private CopyPastaClient _client = null!;
        private Settings _settings = null!;

        public TrayApplicationContext()
        {
            InitializeComponent();
            LoadSettings();
            StartClipboardMonitoring();
        }

        private void InitializeComponent()
        {
            // Create the tray icon
            _trayIcon = new NotifyIcon()
            {
                Icon = CreateIcon(),
                ContextMenuStrip = CreateContextMenu(),
                Visible = true,
                Text = "CopyPasta - Cross-device clipboard sharing"
            };

            _trayIcon.DoubleClick += TrayIcon_DoubleClick;
        }

        private Icon CreateIcon()
        {
            // Load the icon from embedded resources
            try
            {
                var assembly = System.Reflection.Assembly.GetExecutingAssembly();
                using (var stream = assembly.GetManifestResourceStream("CopyPasta.icon.ico"))
                {
                    if (stream != null)
                    {
                        return new Icon(stream);
                    }
                }
            }
            catch
            {
                // Fall back to programmatic icon if embedded resource fails
            }

            // Fallback: Create a simple icon programmatically
            var bitmap = new Bitmap(16, 16);
            using (var g = Graphics.FromImage(bitmap))
            {
                g.Clear(Color.Transparent);
                g.FillEllipse(Brushes.Blue, 2, 2, 12, 12);
                g.DrawString("C", new Font("Arial", 8, FontStyle.Bold), Brushes.White, 4, 2);
            }
            return Icon.FromHandle(bitmap.GetHicon());
        }

        private ContextMenuStrip CreateContextMenu()
        {
            var contextMenu = new ContextMenuStrip();
            
            var statusItem = new ToolStripMenuItem("CopyPasta")
            {
                Enabled = false,
                Font = new Font(contextMenu.Font, FontStyle.Bold)
            };
            
            var settingsItem = new ToolStripMenuItem("Settings...");
            settingsItem.Click += SettingsItem_Click;
            
            var separatorItem = new ToolStripSeparator();
            
            var exitItem = new ToolStripMenuItem("Exit");
            exitItem.Click += ExitItem_Click;

            contextMenu.Items.AddRange(new ToolStripItem[]
            {
                statusItem,
                new ToolStripSeparator(),
                settingsItem,
                separatorItem,
                exitItem
            });

            return contextMenu;
        }

        private void LoadSettings()
        {
            _settings = Settings.Load();
            _client = new CopyPastaClient(_settings);
        }

        private void StartClipboardMonitoring()
        {
            _clipboardMonitor = new ClipboardMonitor();
            _clipboardMonitor.ClipboardChanged += OnClipboardChanged;
            _clipboardMonitor.Start();
        }

        private async void OnClipboardChanged(object? sender, ClipboardChangedEventArgs e)
        {
            if (_settings.IsConfigured)
            {
                try
                {
                    await _client.UploadClipboardContent(e.Content, e.ContentType);
                    UpdateTrayIcon("Upload successful", ToolTipIcon.Info);
                }
                catch (Exception ex)
                {
                    UpdateTrayIcon($"Upload failed: {ex.Message}", ToolTipIcon.Error);
                }
            }
        }

        private void UpdateTrayIcon(string message, ToolTipIcon icon)
        {
            _trayIcon.ShowBalloonTip(3000, "CopyPasta", message, icon);
        }

        private void TrayIcon_DoubleClick(object? sender, EventArgs e)
        {
            ShowSettings();
        }

        private void SettingsItem_Click(object? sender, EventArgs e)
        {
            ShowSettings();
        }

        private void ShowSettings()
        {
            using (var settingsForm = new SettingsForm(_settings))
            {
                if (settingsForm.ShowDialog() == DialogResult.OK)
                {
                    _settings.Save();
                    _client.UpdateSettings(_settings);
                }
            }
        }

        private void ExitItem_Click(object? sender, EventArgs e)
        {
            ExitThread();
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                _clipboardMonitor?.Stop();
                _clipboardMonitor?.Dispose();
                _trayIcon?.Dispose();
            }
            base.Dispose(disposing);
        }

        protected override void ExitThreadCore()
        {
            _trayIcon.Visible = false;
            base.ExitThreadCore();
        }
    }
}