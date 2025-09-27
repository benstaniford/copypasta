using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace CopyPasta
{
    public enum ClipboardContentType
    {
        Text,
        RichText,
        Image
    }

    public class ClipboardChangedEventArgs : EventArgs
    {
        public string Content { get; set; } = "";
        public ClipboardContentType ContentType { get; set; }

        public ClipboardChangedEventArgs() { }

        public ClipboardChangedEventArgs(string content, ClipboardContentType contentType)
        {
            Content = content;
            ContentType = contentType;
        }
    }

    public class ClipboardMonitor : IDisposable
    {
        private const int WM_CLIPBOARDUPDATE = 0x031D;
        private const int WM_CHANGECBCHAIN = 0x030D;
        private const int WM_DRAWCLIPBOARD = 0x0308;

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool AddClipboardFormatListener(IntPtr hwnd);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool RemoveClipboardFormatListener(IntPtr hwnd);

        private ClipboardForm _clipboardForm = null!;
        private string _lastClipboardContent = "";

        public event EventHandler<ClipboardChangedEventArgs>? ClipboardChanged;

        public void Start()
        {
            Logger.Log("ClipboardMonitor", "Starting clipboard monitoring");
            _clipboardForm = new ClipboardForm();
            _clipboardForm.ClipboardUpdate += OnClipboardUpdate;
            
            // Ensure the form is created and has a handle
            if (!_clipboardForm.IsHandleCreated)
            {
                _clipboardForm.CreateControl();
                
                // Force handle creation if it still doesn't exist
                if (!_clipboardForm.IsHandleCreated)
                {
                    var handle = _clipboardForm.Handle; // This forces handle creation
                    Logger.Log("ClipboardMonitor", $"Handle created: {handle}");
                }
            }
            
            Logger.Log("ClipboardMonitor", "Clipboard monitoring started successfully");
        }

        public void Stop()
        {
            Logger.Log("ClipboardMonitor", "Stopping clipboard monitoring");
            _clipboardForm?.Close();
            _clipboardForm?.Dispose();
        }

        private void OnClipboardUpdate()
        {
            Logger.Log("ClipboardMonitor", "Clipboard update detected");
            
            // Small delay to ensure clipboard is ready
            System.Threading.Thread.Sleep(50);
            
            try
            {
                if (Clipboard.ContainsData(DataFormats.Bitmap) || Clipboard.ContainsImage())
                {
                    // Handle image content
                    Logger.Log("ClipboardMonitor", "Processing image content");
                    var image = Clipboard.GetImage();
                    if (image != null)
                    {
                        var base64Image = ConvertImageToBase64(image);
                        if (!string.IsNullOrEmpty(base64Image) && base64Image != _lastClipboardContent)
                        {
                            _lastClipboardContent = base64Image;
                            Logger.Log("ClipboardMonitor", $"Image content changed, size: {base64Image.Length} chars");
                            ClipboardChanged?.Invoke(this, new ClipboardChangedEventArgs(base64Image, ClipboardContentType.Image));
                        }
                    }
                }
                else if (Clipboard.ContainsData(DataFormats.Rtf))
                {
                    // Handle rich text content
                    Logger.Log("ClipboardMonitor", "Processing rich text content");
                    var rtfContent = Clipboard.GetData(DataFormats.Rtf) as string;
                    var htmlContent = ConvertRtfToHtml(rtfContent);
                    
                    if (!string.IsNullOrEmpty(htmlContent) && htmlContent != _lastClipboardContent)
                    {
                        _lastClipboardContent = htmlContent;
                        Logger.Log("ClipboardMonitor", $"Rich text content changed, length: {htmlContent.Length}");
                        ClipboardChanged?.Invoke(this, new ClipboardChangedEventArgs(htmlContent, ClipboardContentType.RichText));
                    }
                }
                else if (Clipboard.ContainsText())
                {
                    // Handle plain text content
                    Logger.Log("ClipboardMonitor", "Processing text content");
                    var textContent = Clipboard.GetText();
                    if (!string.IsNullOrEmpty(textContent) && textContent != _lastClipboardContent)
                    {
                        _lastClipboardContent = textContent;
                        Logger.Log("ClipboardMonitor", $"Text content changed, length: {textContent.Length}");
                        ClipboardChanged?.Invoke(this, new ClipboardChangedEventArgs(textContent, ClipboardContentType.Text));
                    }
                }
            }
            catch (Exception ex)
            {
                Logger.LogError("ClipboardMonitor", "Error processing clipboard content", ex);
            }
        }

        private string ConvertImageToBase64(Image image)
        {
            try
            {
                using var memoryStream = new MemoryStream();
                image.Save(memoryStream, ImageFormat.Png);
                var imageBytes = memoryStream.ToArray();
                return "data:image/png;base64," + Convert.ToBase64String(imageBytes);
            }
            catch (Exception ex)
            {
                Logger.LogError("ClipboardMonitor", "Error converting image to base64", ex);
                return "";
            }
        }

        private string ConvertRtfToHtml(string? rtfContent)
        {
            if (string.IsNullOrEmpty(rtfContent))
                return "";

            try
            {
                // Basic RTF to HTML conversion
                // This is a simplified converter - for production use, consider a dedicated RTF library
                var html = rtfContent
                    .Replace(@"\b ", "<strong>").Replace(@"\b0 ", "</strong>")
                    .Replace(@"\i ", "<em>").Replace(@"\i0 ", "</em>")
                    .Replace(@"\ul ", "<u>").Replace(@"\ul0 ", "</u>")
                    .Replace(@"\par", "<br>")
                    .Replace(@"\line", "<br>");

                // Remove RTF control codes (basic cleanup)
                html = System.Text.RegularExpressions.Regex.Replace(html, @"\\[a-z]+\d*\s?", "");
                html = System.Text.RegularExpressions.Regex.Replace(html, @"[{}]", "");

                return $"<div>{html.Trim()}</div>";
            }
            catch (Exception ex)
            {
                Logger.LogError("ClipboardMonitor", "Error converting RTF to HTML", ex);
                // Fallback to plain text
                return Clipboard.GetText();
            }
        }

        public void SetClipboardContent(string content, ClipboardContentType contentType)
        {
            try
            {
                // Temporarily disable monitoring to avoid triggering our own event
                _lastClipboardContent = content;

                switch (contentType)
                {
                    case ClipboardContentType.Text:
                        Clipboard.SetText(content);
                        break;

                    case ClipboardContentType.RichText:
                        // For rich text, we'll set it as HTML if it contains HTML tags
                        if (content.Contains("<") && content.Contains(">"))
                        {
                            var dataObject = new DataObject();
                            dataObject.SetData(DataFormats.Html, content);
                            dataObject.SetData(DataFormats.Text, StripHtmlTags(content));
                            Clipboard.SetDataObject(dataObject);
                        }
                        else
                        {
                            Clipboard.SetText(content);
                        }
                        break;

                    case ClipboardContentType.Image:
                        // Convert base64 back to image
                        var image = ConvertBase64ToImage(content);
                        if (image != null)
                        {
                            Clipboard.SetImage(image);
                        }
                        break;
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Error setting clipboard content: {ex.Message}");
            }
        }

        private Image? ConvertBase64ToImage(string base64Content)
        {
            try
            {
                // Remove data URL prefix if present
                var base64Data = base64Content;
                if (base64Data.StartsWith("data:image/"))
                {
                    var commaIndex = base64Data.IndexOf(',');
                    if (commaIndex >= 0)
                    {
                        base64Data = base64Data.Substring(commaIndex + 1);
                    }
                }

                var imageBytes = Convert.FromBase64String(base64Data);
                using var memoryStream = new MemoryStream(imageBytes);
                return new Bitmap(memoryStream);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Error converting base64 to image: {ex.Message}");
                return null;
            }
        }

        private string StripHtmlTags(string html)
        {
            try
            {
                return System.Text.RegularExpressions.Regex.Replace(html, "<.*?>", string.Empty);
            }
            catch
            {
                return html;
            }
        }

        public void Dispose()
        {
            Stop();
        }
    }

    internal class ClipboardForm : Form
    {
        public event Action? ClipboardUpdate;

        public ClipboardForm()
        {
            SetStyle(ControlStyles.UserPaint, false);
            SetStyle(ControlStyles.AllPaintingInWmPaint, false);
            SetStyle(ControlStyles.ResizeRedraw, false);

            ShowInTaskbar = false;
            WindowState = FormWindowState.Minimized;
            Visible = false;
        }

        protected override void CreateHandle()
        {
            base.CreateHandle();
            bool success = AddClipboardFormatListener(Handle);
            Logger.Log("ClipboardForm", $"Handle created {Handle}, AddClipboardFormatListener result: {success}");
            
            if (!success)
            {
                int error = Marshal.GetLastWin32Error();
                Logger.LogError("ClipboardForm", $"AddClipboardFormatListener failed with error: {error}");
            }
        }

        protected override void DestroyHandle()
        {
            bool success = RemoveClipboardFormatListener(Handle);
            Logger.Log("ClipboardForm", $"RemoveClipboardFormatListener result: {success}");
            base.DestroyHandle();
        }

        protected override void WndProc(ref Message m)
        {
            if (m.Msg == WM_CLIPBOARDUPDATE)
            {
                Logger.Log("ClipboardForm", "WM_CLIPBOARDUPDATE message received");
                ClipboardUpdate?.Invoke();
            }
            base.WndProc(ref m);
        }

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool AddClipboardFormatListener(IntPtr hwnd);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool RemoveClipboardFormatListener(IntPtr hwnd);

        private const int WM_CLIPBOARDUPDATE = 0x031D;
    }
}