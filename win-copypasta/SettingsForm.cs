using System;
using System.Drawing;
using System.Windows.Forms;

namespace CopyPasta
{
    public partial class SettingsForm : Form
    {
        private Settings _settings;
        private Label _endpointLabel = null!;
        private TextBox _endpointTextBox = null!;
        private Label _usernameLabel = null!;
        private TextBox _usernameTextBox = null!;
        private Label _passwordLabel = null!;
        private TextBox _passwordTextBox = null!;
        private CheckBox _autoStartCheckBox = null!;
        private Button _testConnectionButton = null!;
        private Button _okButton = null!;
        private Button _cancelButton = null!;
        private Label _statusLabel = null!;

        public SettingsForm(Settings settings)
        {
            _settings = settings;
            InitializeComponent();
            LoadSettings();
        }

        private void InitializeComponent()
        {
            Text = "CopyPasta Settings";
            Size = new Size(400, 320);
            StartPosition = FormStartPosition.CenterScreen;
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = false;
            ShowInTaskbar = false;

            // Endpoint
            _endpointLabel = new Label
            {
                Text = "Server Endpoint:",
                Location = new Point(12, 15),
                Size = new Size(100, 23),
                TextAlign = ContentAlignment.MiddleLeft
            };

            _endpointTextBox = new TextBox
            {
                Location = new Point(12, 35),
                Size = new Size(350, 23),
                PlaceholderText = "http://localhost:5000"
            };

            // Username
            _usernameLabel = new Label
            {
                Text = "Username:",
                Location = new Point(12, 70),
                Size = new Size(100, 23),
                TextAlign = ContentAlignment.MiddleLeft
            };

            _usernameTextBox = new TextBox
            {
                Location = new Point(12, 90),
                Size = new Size(350, 23)
            };

            // Password
            _passwordLabel = new Label
            {
                Text = "Password:",
                Location = new Point(12, 125),
                Size = new Size(100, 23),
                TextAlign = ContentAlignment.MiddleLeft
            };

            _passwordTextBox = new TextBox
            {
                Location = new Point(12, 145),
                Size = new Size(350, 23),
                PasswordChar = '*'
            };

            // Auto-start
            _autoStartCheckBox = new CheckBox
            {
                Text = "Start with Windows",
                Location = new Point(12, 180),
                Size = new Size(150, 23)
            };

            // Test connection button
            _testConnectionButton = new Button
            {
                Text = "Test Connection",
                Location = new Point(12, 210),
                Size = new Size(120, 30)
            };
            _testConnectionButton.Click += TestConnectionButton_Click;

            // Status label
            _statusLabel = new Label
            {
                Location = new Point(140, 210),
                Size = new Size(222, 30),
                TextAlign = ContentAlignment.MiddleLeft,
                ForeColor = Color.Green
            };

            // OK button
            _okButton = new Button
            {
                Text = "OK",
                Location = new Point(207, 250),
                Size = new Size(75, 30),
                DialogResult = DialogResult.OK
            };
            _okButton.Click += OkButton_Click;

            // Cancel button
            _cancelButton = new Button
            {
                Text = "Cancel",
                Location = new Point(287, 250),
                Size = new Size(75, 30),
                DialogResult = DialogResult.Cancel
            };

            Controls.AddRange(new Control[]
            {
                _endpointLabel,
                _endpointTextBox,
                _usernameLabel,
                _usernameTextBox,
                _passwordLabel,
                _passwordTextBox,
                _autoStartCheckBox,
                _testConnectionButton,
                _statusLabel,
                _okButton,
                _cancelButton
            });

            AcceptButton = _okButton;
            CancelButton = _cancelButton;
        }

        private void LoadSettings()
        {
            _endpointTextBox.Text = _settings.ServerEndpoint;
            _usernameTextBox.Text = _settings.Username;
            _passwordTextBox.Text = _settings.Password;
            _autoStartCheckBox.Checked = _settings.AutoStart;
        }

        private async void TestConnectionButton_Click(object? sender, EventArgs e)
        {
            _testConnectionButton.Enabled = false;
            _statusLabel.Text = "Testing...";
            _statusLabel.ForeColor = Color.Blue;

            try
            {
                var tempSettings = new Settings
                {
                    ServerEndpoint = _endpointTextBox.Text,
                    Username = _usernameTextBox.Text,
                    Password = _passwordTextBox.Text
                };

                var client = new CopyPastaClient(tempSettings);
                var success = await client.TestConnection();

                if (success)
                {
                    _statusLabel.Text = "Connection successful!";
                    _statusLabel.ForeColor = Color.Green;
                }
                else
                {
                    _statusLabel.Text = "Connection failed!";
                    _statusLabel.ForeColor = Color.Red;
                }
            }
            catch (Exception ex)
            {
                _statusLabel.Text = $"Error: {ex.Message}";
                _statusLabel.ForeColor = Color.Red;
            }
            finally
            {
                _testConnectionButton.Enabled = true;
            }
        }

        private void OkButton_Click(object? sender, EventArgs e)
        {
            if (string.IsNullOrWhiteSpace(_endpointTextBox.Text))
            {
                MessageBox.Show("Please enter a server endpoint.", "Validation Error", 
                    MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            if (string.IsNullOrWhiteSpace(_usernameTextBox.Text))
            {
                MessageBox.Show("Please enter a username.", "Validation Error", 
                    MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            if (string.IsNullOrWhiteSpace(_passwordTextBox.Text))
            {
                MessageBox.Show("Please enter a password.", "Validation Error", 
                    MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            // Update settings
            _settings.ServerEndpoint = _endpointTextBox.Text.TrimEnd('/');
            _settings.Username = _usernameTextBox.Text;
            _settings.Password = _passwordTextBox.Text;
            _settings.AutoStart = _autoStartCheckBox.Checked;

            DialogResult = DialogResult.OK;
            Close();
        }
    }
}