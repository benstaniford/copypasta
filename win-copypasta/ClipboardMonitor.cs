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
        public string Content { get; }
        public ClipboardContentType ContentType { get; }

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

        private ClipboardForm _clipboardForm;
        private string _lastClipboardContent = "";
        private ClipboardContentType _lastContentType = ClipboardContentType.Text;

        public event EventHandler<ClipboardChangedEventArgs>? ClipboardChanged;

        public void Start()
        {
            _clipboardForm = new ClipboardForm();
            _clipboardForm.ClipboardUpdate += OnClipboardUpdate;
            _clipboardForm.CreateControl();
        }

        public void Stop()
        {
            _clipboardForm?.Close();
            _clipboardForm?.Dispose();
        }

        private void OnClipboardUpdate()
        {
            try
            {
                if (Clipboard.ContainsData(DataFormats.Bitmap) || Clipboard.ContainsImage())
                {
                    // Handle image content
                    var image = Clipboard.GetImage();
                    if (image != null)
                    {
                        var base64Image = ConvertImageToBase64(image);
                        if (!string.IsNullOrEmpty(base64Image) && base64Image != _lastClipboardContent)
                        {
                            _lastClipboardContent = base64Image;
                            _lastContentType = ClipboardContentType.Image;
                            ClipboardChanged?.Invoke(this, new ClipboardChangedEventArgs(base64Image, ClipboardContentType.Image));
                        }
                    }
                }
                else if (Clipboard.ContainsData(DataFormats.Rtf))
                {
                    // Handle rich text content
                    var rtfContent = Clipboard.GetData(DataFormats.Rtf) as string;
                    var htmlContent = ConvertRtfToHtml(rtfContent);
                    
                    if (!string.IsNullOrEmpty(htmlContent) && htmlContent != _lastClipboardContent)
                    {
                        _lastClipboardContent = htmlContent;
                        _lastContentType = ClipboardContentType.RichText;
                        ClipboardChanged?.Invoke(this, new ClipboardChangedEventArgs(htmlContent, ClipboardContentType.RichText));
                    }
                }
                else if (Clipboard.ContainsText())
                {
                    // Handle plain text content
                    var textContent = Clipboard.GetText();
                    if (!string.IsNullOrEmpty(textContent) && textContent != _lastClipboardContent)
                    {
                        _lastClipboardContent = textContent;
                        _lastContentType = ClipboardContentType.Text;
                        ClipboardChanged?.Invoke(this, new ClipboardChangedEventArgs(textContent, ClipboardContentType.Text));
                    }
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Error processing clipboard content: {ex.Message}");
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
                System.Diagnostics.Debug.WriteLine($"Error converting image to base64: {ex.Message}");
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
                System.Diagnostics.Debug.WriteLine($"Error converting RTF to HTML: {ex.Message}");
                // Fallback to plain text
                return Clipboard.GetText();
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
            AddClipboardFormatListener(Handle);
        }

        protected override void DestroyHandle()
        {
            RemoveClipboardFormatListener(Handle);
            base.DestroyHandle();
        }

        protected override void WndProc(ref Message m)
        {
            if (m.Msg == WM_CLIPBOARDUPDATE)
            {
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