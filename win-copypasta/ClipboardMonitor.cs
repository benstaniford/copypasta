using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using System.Web;

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
        private bool _suppressNextChange = false;
        private DateTime _lastSetTime = DateTime.MinValue;

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
            
            // Check if we should suppress this change (recently set by SetClipboardContent)
            if (_suppressNextChange && (DateTime.Now - _lastSetTime).TotalMilliseconds < 2000)
            {
                Logger.Log("ClipboardMonitor", "Suppressing clipboard change - recently set by SetClipboardContent");
                _suppressNextChange = false;
                return;
            }
            
            // Reset suppression flag after timeout
            if ((DateTime.Now - _lastSetTime).TotalMilliseconds >= 2000)
            {
                _suppressNextChange = false;
            }
            
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
                else if (Clipboard.ContainsData(DataFormats.Html) || Clipboard.ContainsData(DataFormats.Rtf))
                {
                    // Handle rich text content - prioritize HTML format over RTF
                    Logger.Log("ClipboardMonitor", "Processing rich text content");
                    string htmlContent = "";
                    
                    if (Clipboard.ContainsData(DataFormats.Html))
                    {
                        // Prefer HTML format when available
                        var htmlData = Clipboard.GetData(DataFormats.Html) as string;
                        if (!string.IsNullOrEmpty(htmlData))
                        {
                            htmlContent = ExtractHtmlFragment(htmlData);
                            Logger.Log("ClipboardMonitor", "Using HTML format directly from clipboard");
                        }
                    }
                    
                    if (string.IsNullOrEmpty(htmlContent) && Clipboard.ContainsData(DataFormats.Rtf))
                    {
                        // Fallback to RTF conversion
                        var rtfContent = Clipboard.GetData(DataFormats.Rtf) as string;
                        if (!string.IsNullOrEmpty(rtfContent))
                        {
                            htmlContent = ConvertRtfToHtmlUsingRichTextBox(rtfContent);
                            Logger.Log("ClipboardMonitor", "Converted RTF to HTML");
                        }
                    }
                    
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
                    Logger.Log("ClipboardMonitor", $"Current clipboard text: '{(textContent?.Length > 50 ? textContent.Substring(0, 50) + "..." : textContent)}'");
                    Logger.Log("ClipboardMonitor", $"Last known content: '{(_lastClipboardContent?.Length > 50 ? _lastClipboardContent.Substring(0, 50) + "..." : _lastClipboardContent)}'");
                    
                    if (!string.IsNullOrEmpty(textContent) && textContent != _lastClipboardContent)
                    {
                        _lastClipboardContent = textContent;
                        Logger.Log("ClipboardMonitor", $"Text content changed, length: {textContent.Length}");
                        ClipboardChanged?.Invoke(this, new ClipboardChangedEventArgs(textContent, ClipboardContentType.Text));
                    }
                    else
                    {
                        Logger.Log("ClipboardMonitor", "Text content unchanged, ignoring event");
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


        private string ExtractHtmlFragment(string cfHtml)
        {
            try
            {
                // Windows CF_HTML format includes metadata, we need to extract just the HTML fragment
                var startHtml = cfHtml.IndexOf("StartHTML:");
                var endHtml = cfHtml.IndexOf("EndHTML:");
                var startFragment = cfHtml.IndexOf("StartFragment:");
                var endFragment = cfHtml.IndexOf("EndFragment:");

                if (startFragment >= 0 && endFragment >= 0)
                {
                    var fragmentStart = cfHtml.IndexOf("<!--StartFragment-->");
                    var fragmentEnd = cfHtml.IndexOf("<!--EndFragment-->");
                    
                    if (fragmentStart >= 0 && fragmentEnd >= 0)
                    {
                        fragmentStart += "<!--StartFragment-->".Length;
                        var fragment = cfHtml.Substring(fragmentStart, fragmentEnd - fragmentStart).Trim();
                        
                        // Clean up the fragment - remove any remaining CF_HTML artifacts
                        fragment = System.Text.RegularExpressions.Regex.Replace(fragment, @"Version:\d+\.\d+\s*", "");
                        fragment = System.Text.RegularExpressions.Regex.Replace(fragment, @"StartHTML:\d+\s*", "");
                        fragment = System.Text.RegularExpressions.Regex.Replace(fragment, @"EndHTML:\d+\s*", "");
                        fragment = System.Text.RegularExpressions.Regex.Replace(fragment, @"StartFragment:\d+\s*", "");
                        fragment = System.Text.RegularExpressions.Regex.Replace(fragment, @"EndFragment:\d+\s*", "");
                        
                        return fragment;
                    }
                }

                // If fragment markers not found, try to extract HTML content directly
                var htmlBodyMatch = System.Text.RegularExpressions.Regex.Match(cfHtml, @"<body[^>]*>(.*?)</body>", System.Text.RegularExpressions.RegexOptions.Singleline | System.Text.RegularExpressions.RegexOptions.IgnoreCase);
                if (htmlBodyMatch.Success)
                {
                    return htmlBodyMatch.Groups[1].Value.Trim();
                }

                // Last attempt - look for any HTML-like content
                var htmlMatch = System.Text.RegularExpressions.Regex.Match(cfHtml, @"<[^>]+>.*", System.Text.RegularExpressions.RegexOptions.Singleline);
                if (htmlMatch.Success)
                {
                    return htmlMatch.Value;
                }

                return "";
            }
            catch (Exception ex)
            {
                Logger.LogError("ClipboardMonitor", "Error extracting HTML fragment", ex);
                return "";
            }
        }

        private string ConvertRtfToHtmlUsingRichTextBox(string rtfContent)
        {
            try
            {
                Logger.Log("ClipboardMonitor", "Converting RTF to HTML using RichTextBox");
                
                // Use a RichTextBox to properly convert RTF to HTML
                using var richTextBox = new System.Windows.Forms.RichTextBox();
                richTextBox.Rtf = rtfContent;
                
                // Get the plain text content
                var plainText = richTextBox.Text;
                
                // If there's no actual text content, return empty
                if (string.IsNullOrEmpty(plainText.Trim()))
                {
                    return "";
                }
                
                // Try to detect if there was actual formatting by checking RTF content
                var hasFormatting = rtfContent.Contains(@"\b") || rtfContent.Contains(@"\i") || 
                                  rtfContent.Contains(@"\ul") || rtfContent.Contains(@"\cf") ||
                                  (rtfContent.Contains(@"\f") && rtfContent.Contains(@"\fs"));
                
                if (hasFormatting)
                {
                    Logger.Log("ClipboardMonitor", "RTF formatting detected, converting to HTML");
                    
                    // For now, preserve the plain text but wrap it properly for HTML
                    // Future enhancement: could use a proper RTF->HTML converter library
                    var htmlContent = System.Web.HttpUtility.HtmlEncode(plainText)
                        .Replace("\r\n", "<br>")
                        .Replace("\n", "<br>")
                        .Replace("\r", "<br>");
                    
                    return $"<div>{htmlContent}</div>";
                }
                else
                {
                    Logger.Log("ClipboardMonitor", "No significant RTF formatting detected, returning empty (will fall back to plain text)");
                    return ""; // Return empty to let the main logic fall back to plain text handling
                }
            }
            catch (Exception ex)
            {
                Logger.LogError("ClipboardMonitor", "Error in RichTextBox RTF conversion", ex);
                return "";
            }
        }

        public void SetClipboardContent(string content, ClipboardContentType contentType)
        {
            try
            {
                Logger.Log("ClipboardMonitor", $"Setting clipboard content: type={contentType}, length={content?.Length ?? 0}");
                Logger.Log("ClipboardMonitor", $"Content preview: '{(content?.Length > 50 ? content.Substring(0, 50) + "..." : content)}'");
                
                // Set suppression flag to ignore the next few clipboard changes
                _suppressNextChange = true;
                _lastSetTime = DateTime.Now;
                _lastClipboardContent = content ?? string.Empty;

                // Ensure clipboard operations happen on the UI thread
                var safeContent = content ?? string.Empty;
                if (_clipboardForm.InvokeRequired)
                {
                    Logger.Log("ClipboardMonitor", "Marshaling clipboard operation to UI thread");
                    _clipboardForm.Invoke(new Action(() => SetClipboardContentInternal(safeContent, contentType)));
                }
                else
                {
                    SetClipboardContentInternal(safeContent, contentType);
                }
                
                Logger.Log("ClipboardMonitor", "SetClipboardContent completed successfully");
            }
            catch (Exception ex)
            {
                Logger.LogError("ClipboardMonitor", "Error setting clipboard content", ex);
            }
        }

        private void SetClipboardContentInternal(string content, ClipboardContentType contentType)
        {
            switch (contentType)
            {
                case ClipboardContentType.Text:
                    if (!string.IsNullOrEmpty(content))
                    {
                        Clipboard.SetText(content);
                        Logger.Log("ClipboardMonitor", "Clipboard.SetText() completed");
                    }
                    break;

                case ClipboardContentType.RichText:
                    // For rich text, we'll set it as HTML if it contains HTML tags
                    if (!string.IsNullOrEmpty(content) && content.Contains("<") && content.Contains(">"))
                    {
                        var dataObject = new DataObject();
                        dataObject.SetData(DataFormats.Html, content);
                        dataObject.SetData(DataFormats.Text, StripHtmlTags(content));
                        Clipboard.SetDataObject(dataObject);
                        Logger.Log("ClipboardMonitor", "Clipboard.SetDataObject() completed for HTML content");
                    }
                    else if (!string.IsNullOrEmpty(content))
                    {
                        Clipboard.SetText(content);
                        Logger.Log("ClipboardMonitor", "Clipboard.SetText() completed for rich text");
                    }
                    break;

                case ClipboardContentType.Image:
                    // Convert base64 back to image
                    if (!string.IsNullOrEmpty(content))
                    {
                        var image = ConvertBase64ToImage(content);
                        if (image != null)
                        {
                            Clipboard.SetImage(image);
                            Logger.Log("ClipboardMonitor", "Clipboard.SetImage() completed");
                        }
                        else
                        {
                            Logger.LogError("ClipboardMonitor", "Failed to convert base64 to image", null);
                        }
                    }
                    break;
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