using System;
using System.Diagnostics;
using System.Drawing;
using System.Reflection;
using System.Windows.Forms;
using Microsoft.Win32;

namespace CopyPasta
{
    public partial class AboutForm : Form
    {
        private Label _titleLabel = null!;
        private Label _versionLabel = null!;
        private Label _copyrightLabel = null!;
        private Label _licenseLabel = null!;
        private LinkLabel _licenseLinkLabel = null!;
        private LinkLabel _githubLinkLabel = null!;
        private Button _okButton = null!;

        public AboutForm()
        {
            InitializeComponent();
        }

        private void InitializeComponent()
        {
            Text = "About CopyPasta";
            Size = new Size(350, 250);
            StartPosition = FormStartPosition.CenterScreen;
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = false;
            ShowInTaskbar = false;

            // Title
            _titleLabel = new Label
            {
                Text = "CopyPasta",
                Location = new Point(20, 20),
                Size = new Size(310, 30),
                Font = new Font("Segoe UI", 16, FontStyle.Bold),
                TextAlign = ContentAlignment.MiddleCenter
            };

            // Version
            _versionLabel = new Label
            {
                Text = $"Version {GetVersionString()}",
                Location = new Point(20, 55),
                Size = new Size(310, 20),
                TextAlign = ContentAlignment.MiddleCenter
            };

            // Copyright
            _copyrightLabel = new Label
            {
                Text = "© 2024 Ben Staniford",
                Location = new Point(20, 85),
                Size = new Size(310, 20),
                TextAlign = ContentAlignment.MiddleCenter
            };

            // License info
            _licenseLabel = new Label
            {
                Text = "Licensed under the GNU General Public License v2.0",
                Location = new Point(20, 115),
                Size = new Size(310, 20),
                TextAlign = ContentAlignment.MiddleCenter
            };

            // License link
            _licenseLinkLabel = new LinkLabel
            {
                Text = "View License",
                Location = new Point(20, 140),
                Size = new Size(310, 20),
                TextAlign = ContentAlignment.MiddleCenter,
                LinkColor = Color.Blue
            };
            _licenseLinkLabel.LinkClicked += LicenseLinkLabel_LinkClicked;

            // GitHub link
            _githubLinkLabel = new LinkLabel
            {
                Text = "See Latest Version on GitHub",
                Location = new Point(20, 165),
                Size = new Size(310, 20),
                TextAlign = ContentAlignment.MiddleCenter,
                LinkColor = Color.Blue
            };
            _githubLinkLabel.LinkClicked += GithubLinkLabel_LinkClicked;

            // OK button
            _okButton = new Button
            {
                Text = "OK",
                Location = new Point(137, 200),
                Size = new Size(75, 30),
                DialogResult = DialogResult.OK
            };

            Controls.AddRange(new Control[]
            {
                _titleLabel,
                _versionLabel,
                _copyrightLabel,
                _licenseLabel,
                _licenseLinkLabel,
                _githubLinkLabel,
                _okButton
            });

            AcceptButton = _okButton;
            CancelButton = _okButton;
        }

        private string GetVersionString()
        {
            try
            {
                // Priority 1: Try to get from CopyPasta registry key (installer version) - most accurate
                try
                {
                    using var key = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\CopyPasta");
                    if (key != null)
                    {
                        var registryVersion = key.GetValue("Version")?.ToString();
                        if (!string.IsNullOrEmpty(registryVersion))
                        {
                            return registryVersion;
                        }
                    }
                }
                catch
                {
                    // Registry access might fail due to permissions, try other methods
                }

                // Priority 2: Try to get version from file version info
                var assembly = Assembly.GetExecutingAssembly();
                var fileVersionInfo = FileVersionInfo.GetVersionInfo(assembly.Location);
                if (!string.IsNullOrEmpty(fileVersionInfo.FileVersion) && fileVersionInfo.FileVersion != "1.0.0.0")
                {
                    return fileVersionInfo.FileVersion;
                }

                // Priority 3: Try to get version from assembly (least reliable for installed apps)
                var assemblyVersion = assembly.GetName().Version;
                if (assemblyVersion != null && assemblyVersion.ToString() != "0.0.0.0" && assemblyVersion.ToString() != "1.0.0.0")
                {
                    return assemblyVersion.ToString();
                }

                // Priority 4: Fallback to uninstall registry entries
                try
                {
                    using var key = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\CopyPasta");
                    if (key != null)
                    {
                        var displayVersion = key.GetValue("DisplayVersion")?.ToString();
                        if (!string.IsNullOrEmpty(displayVersion))
                        {
                            return displayVersion;
                        }
                    }
                }
                catch
                {
                    // Registry access might fail due to permissions
                }

                // Priority 5: Try current user registry
                try
                {
                    using var key = Registry.CurrentUser.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\CopyPasta");
                    if (key != null)
                    {
                        var displayVersion = key.GetValue("DisplayVersion")?.ToString();
                        if (!string.IsNullOrEmpty(displayVersion))
                        {
                            return displayVersion;
                        }
                    }
                }
                catch
                {
                    // Registry access might fail
                }
            }
            catch (Exception ex)
            {
                Logger.LogError("AboutForm", "Error getting version", ex);
            }

            return "Unknown";
        }

        private void LicenseLinkLabel_LinkClicked(object? sender, LinkLabelLinkClickedEventArgs e)
        {
            try
            {
                // Open GPL v2 license URL
                Process.Start(new ProcessStartInfo
                {
                    FileName = "https://www.gnu.org/licenses/old-licenses/gpl-2.0.html",
                    UseShellExecute = true
                });
            }
            catch (Exception ex)
            {
                Logger.LogError("AboutForm", "Error opening license URL", ex);
                MessageBox.Show("Unable to open license URL. Please visit: https://www.gnu.org/licenses/old-licenses/gpl-2.0.html",
                    "Error", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private void GithubLinkLabel_LinkClicked(object? sender, LinkLabelLinkClickedEventArgs e)
        {
            try
            {
                // Open GitHub repository URL
                Process.Start(new ProcessStartInfo
                {
                    FileName = "https://github.com/benstaniford/copypasta",
                    UseShellExecute = true
                });
            }
            catch (Exception ex)
            {
                Logger.LogError("AboutForm", "Error opening GitHub URL", ex);
                MessageBox.Show("Unable to open GitHub URL. Please visit: https://github.com/benstaniford/copypasta",
                    "Error", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }
    }
}