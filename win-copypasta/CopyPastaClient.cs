using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;

namespace CopyPasta
{
    public class CopyPastaClient : IDisposable
    {
        private readonly HttpClient _httpClient;
        private Settings _settings;
        private string? _sessionCookie;

        public CopyPastaClient(Settings settings)
        {
            _settings = settings;
            _httpClient = new HttpClient();
            _httpClient.Timeout = TimeSpan.FromSeconds(30);
        }

        public void UpdateSettings(Settings settings)
        {
            _settings = settings;
            _sessionCookie = null; // Reset session when settings change
        }

        public async Task<bool> TestConnection()
        {
            try
            {
                var response = await _httpClient.GetAsync($"{_settings.ServerEndpoint}/health");
                return response.IsSuccessStatusCode;
            }
            catch
            {
                return false;
            }
        }

        public async Task UploadClipboardContent(string content, ClipboardContentType contentType)
        {
            if (!_settings.IsConfigured)
                throw new InvalidOperationException("CopyPasta client is not configured.");

            await EnsureAuthenticated();

            var apiContentType = contentType switch
            {
                ClipboardContentType.Text => "text",
                ClipboardContentType.RichText => "rich",
                ClipboardContentType.Image => "image",
                _ => "text"
            };

            var payload = new
            {
                type = apiContentType,
                content = content
            };

            var json = JsonConvert.SerializeObject(payload);
            var requestContent = new StringContent(json, Encoding.UTF8, "application/json");

            var request = new HttpRequestMessage(HttpMethod.Post, $"{_settings.ServerEndpoint}/api/paste")
            {
                Content = requestContent
            };

            if (!string.IsNullOrEmpty(_sessionCookie))
            {
                request.Headers.Add("Cookie", _sessionCookie);
            }

            var response = await _httpClient.SendAsync(request);

            if (!response.IsSuccessStatusCode)
            {
                var errorContent = await response.Content.ReadAsStringAsync();
                var errorMessage = TryParseErrorMessage(errorContent);
                throw new HttpRequestException($"Upload failed: {errorMessage}");
            }
        }

        private async Task EnsureAuthenticated()
        {
            if (!string.IsNullOrEmpty(_sessionCookie))
                return; // Already authenticated

            var loginData = new List<KeyValuePair<string, string>>
            {
                new("username", _settings.Username),
                new("password", _settings.Password)
            };

            var formContent = new FormUrlEncodedContent(loginData);
            var response = await _httpClient.PostAsync($"{_settings.ServerEndpoint}/login", formContent);

            if (response.IsSuccessStatusCode)
            {
                // Extract session cookie
                if (response.Headers.TryGetValues("Set-Cookie", out var cookies))
                {
                    foreach (var cookie in cookies)
                    {
                        if (cookie.StartsWith("session="))
                        {
                            _sessionCookie = cookie.Split(';')[0]; // Get just the session part
                            break;
                        }
                    }
                }

                if (string.IsNullOrEmpty(_sessionCookie))
                {
                    throw new InvalidOperationException("Authentication succeeded but no session cookie received.");
                }
            }
            else
            {
                var errorContent = await response.Content.ReadAsStringAsync();
                throw new UnauthorizedAccessException("Authentication failed. Please check your username and password.");
            }
        }

        private string TryParseErrorMessage(string errorContent)
        {
            try
            {
                var errorObj = JsonConvert.DeserializeObject<dynamic>(errorContent);
                return errorObj?.error ?? "Unknown error";
            }
            catch
            {
                return errorContent.Length > 100 ? errorContent.Substring(0, 100) + "..." : errorContent;
            }
        }

        public void Dispose()
        {
            _httpClient?.Dispose();
        }
    }
}