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
            Logger.Log("TrayApp", "Initializing TrayApplicationContext");
            InitializeComponent();
            LoadSettings();
            StartClipboardMonitoring();
            Logger.Log("TrayApp", "TrayApplicationContext initialization complete");
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
            
            var onlineClipsItem = new ToolStripMenuItem("Clip History...");
            onlineClipsItem.Click += OnlineClipsItem_Click;
            
            var settingsItem = new ToolStripMenuItem("Settings...");
            settingsItem.Click += SettingsItem_Click;
            
            var viewLogsItem = new ToolStripMenuItem("View Logs...");
            viewLogsItem.Click += ViewLogsItem_Click;
            
            var aboutItem = new ToolStripMenuItem("About...");
            aboutItem.Click += AboutItem_Click;
            
            var separatorItem = new ToolStripSeparator();
            
            var exitItem = new ToolStripMenuItem("Exit");
            exitItem.Click += ExitItem_Click;

            contextMenu.Items.AddRange(new ToolStripItem[]
            {
                statusItem,
                new ToolStripSeparator(),
                onlineClipsItem,
                new ToolStripSeparator(),
                settingsItem,
                viewLogsItem,
                aboutItem,
                separatorItem,
                exitItem
            });

            return contextMenu;
        }

        private void LoadSettings()
        {
            Logger.Log("TrayApp", "Loading settings");
            _settings = Settings.Load();
            _client = new CopyPastaClient(_settings);
            _client.ClipboardChangedOnServer += OnClipboardChangedOnServer;
            
            // Start polling if configured
            if (_settings.IsConfigured)
            {
                Logger.Log("TrayApp", "Settings configured, starting polling");
                _client.StartPolling();
            }
            else
            {
                Logger.Log("TrayApp", "Settings not configured, skipping polling");
            }
        }

        private void StartClipboardMonitoring()
        {
            Logger.Log("TrayApp", "Starting clipboard monitoring");
            _clipboardMonitor = new ClipboardMonitor();
            _clipboardMonitor.ClipboardChanged += OnClipboardChanged;
            _clipboardMonitor.Start();
        }

        private async void OnClipboardChanged(object? sender, ClipboardChangedEventArgs e)
        {
            Logger.Log("TrayApp", $"Clipboard changed: {e.ContentType} content, length: {e.Content?.Length ?? 0}, filename: {e.Filename}");

            if (_settings.IsConfigured)
            {
                try
                {
                    await _client.UploadClipboardContent(e.Content ?? string.Empty, e.ContentType, e.Filename);
                    UpdateTrayIcon("Upload successful", ToolTipIcon.Info);
                    Logger.Log("TrayApp", "Clipboard content uploaded successfully");
                }
                catch (Exception ex)
                {
                    UpdateTrayIcon($"Upload failed: {ex.Message}", ToolTipIcon.Error);
                    Logger.LogError("TrayApp", "Failed to upload clipboard content", ex);
                }
            }
            else
            {
                Logger.Log("TrayApp", "Settings not configured, skipping upload");
            }
        }

        private void UpdateTrayIcon(string message, ToolTipIcon icon)
        {
            if (_settings.ShowToastNotifications)
            {
                _trayIcon.ShowBalloonTip(3000, "CopyPasta", message, icon);
            }
        }

        private void TrayIcon_DoubleClick(object? sender, EventArgs e)
        {
            ShowSettings();
        }

        private void OnlineClipsItem_Click(object? sender, EventArgs e)
        {
            Logger.Log("TrayApp", "Clip History menu clicked");
            OpenOnlineClips();
        }

        private void SettingsItem_Click(object? sender, EventArgs e)
        {
            Logger.Log("TrayApp", "Settings menu clicked");
            ShowSettings();
        }

        private void ViewLogsItem_Click(object? sender, EventArgs e)
        {
            Logger.Log("TrayApp", "View Logs menu clicked");
            Logger.OpenLogFile();
        }

        private void AboutItem_Click(object? sender, EventArgs e)
        {
            Logger.Log("TrayApp", "About menu clicked");
            ShowAbout();
        }

        private void OnClipboardChangedOnServer(object? sender, ClipboardChangedEventArgs e)
        {
            Logger.Log("TrayApp", $"Clipboard changed on server: {e.ContentType} content, length: {e.Content?.Length ?? 0}");
            
            try
            {
                // Update the system clipboard with content from server
                                        _clipboardMonitor.SetClipboardContent(e.Content ?? string.Empty, e.ContentType);
                UpdateTrayIcon("Clipboard updated from server", ToolTipIcon.Info);
                Logger.Log("TrayApp", "System clipboard updated from server");
            }
            catch (Exception ex)
            {
                UpdateTrayIcon($"Failed to update clipboard: {ex.Message}", ToolTipIcon.Error);
                Logger.LogError("TrayApp", "Failed to update clipboard from server", ex);
            }
        }

        private void ShowSettings()
        {
            using (var settingsForm = new SettingsForm(_settings))
            {
                if (settingsForm.ShowDialog() == DialogResult.OK)
                {
                    _settings.Save();
                    _client.UpdateSettings(_settings);
                    
                    // Restart polling if now configured
                    if (_settings.IsConfigured)
                    {
                        _client.StartPolling();
                    }
                }
            }
        }

        private void OpenOnlineClips()
        {
            try
            {
                if (_settings.IsConfigured)
                {
                    var url = _settings.ServerEndpoint;
                    Logger.Log("TrayApp", $"Opening web interface at: {url}");
                    System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
                    {
                        FileName = url,
                        UseShellExecute = true
                    });
                }
                else
                {
                    MessageBox.Show("Please configure the server settings first.", "CopyPasta", 
                        MessageBoxButtons.OK, MessageBoxIcon.Information);
                    ShowSettings();
                }
            }
            catch (Exception ex)
            {
                Logger.LogError("TrayApp", "Failed to open web interface", ex);
                MessageBox.Show($"Failed to open web interface: {ex.Message}", "CopyPasta", 
                    MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private void ShowAbout()
        {
            using (var aboutForm = new AboutForm())
            {
                aboutForm.ShowDialog();
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