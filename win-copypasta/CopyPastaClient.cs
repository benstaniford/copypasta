using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Newtonsoft.Json;

namespace CopyPasta
{
    public class CopyPastaClient : IDisposable
    {
        private readonly HttpClient _httpClient;
        private Settings _settings;
        private string? _sessionCookie;
        private int _lastKnownVersion = 0;
        private CancellationTokenSource? _pollCancellationTokenSource;

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
            StopPolling();
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

        public async Task<ClipboardData?> GetClipboardContent()
        {
            if (!_settings.IsConfigured)
                return null;

            await EnsureAuthenticated();

            var request = new HttpRequestMessage(HttpMethod.Get, $"{_settings.ServerEndpoint}/api/clipboard");

            if (!string.IsNullOrEmpty(_sessionCookie))
            {
                request.Headers.Add("Cookie", _sessionCookie);
            }

            var response = await _httpClient.SendAsync(request);

            if (response.IsSuccessStatusCode)
            {
                var content = await response.Content.ReadAsStringAsync();
                var result = JsonConvert.DeserializeObject<ApiResponse>(content);
                
                if (result?.Data != null)
                {
                    _lastKnownVersion = result.Data.Version;
                    return result.Data;
                }
            }

            return null;
        }

        public event EventHandler<ClipboardChangedEventArgs>? ClipboardChangedOnServer;

        public void StartPolling()
        {
            if (!_settings.IsConfigured)
                return;

            StopPolling();
            _pollCancellationTokenSource = new CancellationTokenSource();
            _ = Task.Run(() => PollForChangesAsync(_pollCancellationTokenSource.Token));
        }

        public void StopPolling()
        {
            _pollCancellationTokenSource?.Cancel();
            _pollCancellationTokenSource?.Dispose();
            _pollCancellationTokenSource = null;
        }

        private async Task PollForChangesAsync(CancellationToken cancellationToken)
        {
            while (!cancellationToken.IsCancellationRequested)
            {
                try
                {
                    await EnsureAuthenticated();

                    var url = $"{_settings.ServerEndpoint}/api/poll?version={_lastKnownVersion}&timeout=30";
                    var request = new HttpRequestMessage(HttpMethod.Get, url);

                    if (!string.IsNullOrEmpty(_sessionCookie))
                    {
                        request.Headers.Add("Cookie", _sessionCookie);
                    }

                    // Use a longer timeout for long polling
                    using var httpClient = new HttpClient { Timeout = TimeSpan.FromSeconds(35) };
                    var response = await httpClient.SendAsync(request, cancellationToken);

                    if (response.IsSuccessStatusCode)
                    {
                        var content = await response.Content.ReadAsStringAsync();
                        var result = JsonConvert.DeserializeObject<PollResponse>(content);

                        if (result?.Status == "success" && result.Data != null)
                        {
                            _lastKnownVersion = result.Version;
                            
                            var contentType = result.Data.ContentType switch
                            {
                                "text" => ClipboardContentType.Text,
                                "rich" => ClipboardContentType.RichText,
                                "image" => ClipboardContentType.Image,
                                _ => ClipboardContentType.Text
                            };

                            ClipboardChangedOnServer?.Invoke(this, new ClipboardChangedEventArgs
                            {
                                Content = result.Data.Content,
                                ContentType = contentType
                            });
                        }
                        else if (result?.Status == "timeout")
                        {
                            _lastKnownVersion = result.Version;
                        }
                    }
                }
                catch (OperationCanceledException)
                {
                    break;
                }
                catch (Exception)
                {
                    // Wait before retrying on error
                    await Task.Delay(5000, cancellationToken);
                }
            }
        }

        public void Dispose()
        {
            StopPolling();
            _httpClient?.Dispose();
        }
    }

    public class ApiResponse
    {
        [JsonProperty("status")]
        public string Status { get; set; } = "";

        [JsonProperty("data")]
        public ClipboardData? Data { get; set; }
    }

    public class PollResponse
    {
        [JsonProperty("status")]
        public string Status { get; set; } = "";

        [JsonProperty("data")]
        public ClipboardData? Data { get; set; }

        [JsonProperty("version")]
        public int Version { get; set; }

        [JsonProperty("message")]
        public string Message { get; set; } = "";
    }

    public class ClipboardData
    {
        [JsonProperty("content_type")]
        public string ContentType { get; set; } = "";

        [JsonProperty("content")]
        public string Content { get; set; } = "";

        [JsonProperty("metadata")]
        public string Metadata { get; set; } = "";

        [JsonProperty("created_at")]
        public string CreatedAt { get; set; } = "";

        [JsonProperty("version")]
        public int Version { get; set; }
    }
}