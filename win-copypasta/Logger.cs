using System;
using System.IO;
using System.Diagnostics;

namespace CopyPasta
{
    public static class Logger
    {
        private static readonly string LogFilePath;
        private static readonly object LockObject = new object();

        static Logger()
        {
            // Create log file in user's local app data folder
            string appDataPath = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            string appFolder = Path.Combine(appDataPath, "CopyPasta");
            
            // Ensure directory exists
            Directory.CreateDirectory(appFolder);
            
            LogFilePath = Path.Combine(appFolder, "copypasta.log");
            
            // Clear log file on startup
            try
            {
                File.WriteAllText(LogFilePath, "");
                Log("Logger", "=== CopyPasta Application Started ===");
                Log("Logger", $"Log file: {LogFilePath}");
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Failed to initialize log file: {ex.Message}");
            }
        }

        public static void Log(string component, string message)
        {
            try
            {
                lock (LockObject)
                {
                    string timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff");
                    string logEntry = $"[{timestamp}] [{component}] {message}";
                    
                    File.AppendAllText(LogFilePath, logEntry + Environment.NewLine);
                    
                    // Also write to debug output for development
                    Debug.WriteLine(logEntry);
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Failed to write to log: {ex.Message}");
            }
        }

        public static void LogNetwork(string method, string url, string? status = null, string? details = null)
        {
            string message = $"HTTP {method} {url}";
            if (!string.IsNullOrEmpty(status))
                message += $" - {status}";
            if (!string.IsNullOrEmpty(details))
                message += $" - {details}";
            
            Log("Network", message);
        }

        public static void LogError(string component, string message, Exception? ex = null)
        {
            string errorMessage = $"ERROR: {message}";
            if (ex != null)
                errorMessage += $" - Exception: {ex.Message}";
            
            Log(component, errorMessage);
        }

        public static void OpenLogFile()
        {
            try
            {
                if (File.Exists(LogFilePath))
                {
                    Process.Start("notepad.exe", LogFilePath);
                    Log("Logger", "Log file opened in Notepad");
                }
                else
                {
                    Log("Logger", "Log file does not exist");
                }
            }
            catch (Exception ex)
            {
                LogError("Logger", "Failed to open log file", ex);
            }
        }

        public static string GetLogFilePath()
        {
            return LogFilePath;
        }
    }
}