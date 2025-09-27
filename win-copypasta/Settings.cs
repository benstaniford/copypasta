using System;
using System.IO;
using System.Diagnostics;
using Newtonsoft.Json;
using Microsoft.Win32;

namespace CopyPasta
{
    public class Settings
    {
        private static readonly string SettingsPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "CopyPasta",
            "settings.json"
        );

        public string ServerEndpoint { get; set; } = "http://localhost:5000";
        public string Username { get; set; } = "";
        public string Password { get; set; } = "";
        public bool AutoStart { get; set; } = false;

        [JsonIgnore]
        public bool IsConfigured => !string.IsNullOrWhiteSpace(ServerEndpoint) &&
                                   !string.IsNullOrWhiteSpace(Username) &&
                                   !string.IsNullOrWhiteSpace(Password);

        public static Settings Load()
        {
            Settings settings;
            
            try
            {
                if (File.Exists(SettingsPath))
                {
                    var json = File.ReadAllText(SettingsPath);
                    settings = JsonConvert.DeserializeObject<Settings>(json) ?? new Settings();
                }
                else
                {
                    settings = new Settings();
                }
            }
            catch (Exception ex)
            {
                // Log error if needed, return default settings
                System.Diagnostics.Debug.WriteLine($"Error loading settings: {ex.Message}");
                settings = new Settings();
            }

            // Override settings if running under debugger
            if (Debugger.IsAttached)
            {
                Logger.Log("Settings", "Debugger detected - using development settings");
                settings.ServerEndpoint = "http://localhost:5000";
                settings.Username = "user";
                settings.Password = "password";
            }

            return settings;
        }

        public void Save()
        {
            try
            {
                var directory = Path.GetDirectoryName(SettingsPath);
                if (!Directory.Exists(directory))
                {
                    Directory.CreateDirectory(directory!);
                }

                var json = JsonConvert.SerializeObject(this, Formatting.Indented);
                File.WriteAllText(SettingsPath, json);

                // Handle auto-start registry setting
                SetAutoStart(AutoStart);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Error saving settings: {ex.Message}");
                throw;
            }
        }

        private void SetAutoStart(bool enable)
        {
            try
            {
                const string appName = "CopyPasta";
                var executablePath = System.Reflection.Assembly.GetExecutingAssembly().Location;
                
                // For .NET 6+ single-file apps, use Environment.ProcessPath
                if (string.IsNullOrEmpty(executablePath))
                {
                    executablePath = Environment.ProcessPath;
                }

                using var key = Registry.CurrentUser.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Run", true);
                
                if (enable && !string.IsNullOrEmpty(executablePath))
                {
                    key?.SetValue(appName, $"\"{executablePath}\"");
                }
                else
                {
                    key?.DeleteValue(appName, false);
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Error setting auto-start: {ex.Message}");
                // Don't throw, auto-start is not critical
            }
        }
    }
}