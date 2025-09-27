using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Web;
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
        private readonly string _clientId;

        public CopyPastaClient(Settings settings)
        {
            Logger.Log("CopyPastaClient", "Initializing HTTP client");
            _settings = settings;
            _httpClient = new HttpClient();
            _httpClient.Timeout = TimeSpan.FromSeconds(30);
            _clientId = GenerateClientId();
            Logger.Log("CopyPastaClient", $"HTTP client initialized with 30s timeout, Client ID: {_clientId}");
        }

        public void UpdateSettings(Settings settings)
        {
            Logger.Log("CopyPastaClient", $"Updating settings - Endpoint: {settings.ServerEndpoint}");
            _settings = settings;
            _sessionCookie = null; // Reset session when settings change
            StopPolling();
        }

        public async Task<bool> TestConnection()
        {
            try
            {
                string url = $"{_settings.ServerEndpoint}/health";
                Logger.LogNetwork("GET", url, "Starting");
                
                var response = await _httpClient.GetAsync(url);
                bool success = response.IsSuccessStatusCode;
                
                Logger.LogNetwork("GET", url, success ? "Success" : "Failed", $"Status: {response.StatusCode}");
                return success;
            }
            catch (Exception ex)
            {
                Logger.LogNetwork("GET", $"{_settings.ServerEndpoint}/health", "Exception", ex.Message);
                return false;
            }
        }

        public async Task UploadClipboardContent(string content, ClipboardContentType contentType)
        {
            if (!_settings.IsConfigured)
                throw new InvalidOperationException("CopyPasta client is not configured.");

            Logger.LogNetwork("Upload", "UploadClipboardContent", "Starting", $"Type: {contentType}, Size: {content?.Length ?? 0} bytes");

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
                content = content,
                client_id = _clientId
            };

            var json = JsonConvert.SerializeObject(payload);
            var requestContent = new StringContent(json, Encoding.UTF8, "application/json");

            string url = $"{_settings.ServerEndpoint}/api/paste";
            var request = new HttpRequestMessage(HttpMethod.Post, url)
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
                Logger.LogNetwork("Upload", url, "Failed", $"Status: {response.StatusCode}, Error: {errorMessage}");
                throw new HttpRequestException($"Upload failed: {errorMessage}");
            }
            else
            {
                Logger.LogNetwork("Upload", url, "Success", "Content uploaded successfully");
            }
        }

        private async Task EnsureAuthenticated()
        {
            if (!string.IsNullOrEmpty(_sessionCookie))
            {
                Logger.LogNetwork("Authentication", "EnsureAuthenticated", "Skipped", "Already authenticated");
                return; // Already authenticated
            }

            Logger.LogNetwork("Authentication", "EnsureAuthenticated", "Starting", $"User: {_settings.Username}");

            var loginData = new List<KeyValuePair<string, string>>
            {
                new("username", _settings.Username),
                new("password", _settings.Password)
            };

            var formContent = new FormUrlEncodedContent(loginData);
            string url = $"{_settings.ServerEndpoint}/login";
            Logger.LogNetwork("Authentication", $"POST {url}", "Starting", $"Form data: username={_settings.Username}");
            var response = await _httpClient.PostAsync(url, formContent);
            Logger.LogNetwork("Authentication", $"POST {url}", "Response", $"Status: {response.StatusCode}, HasCookies: {response.Headers.Contains("Set-Cookie")}");

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
                            Logger.LogNetwork("Authentication", url, "Success", "Session cookie acquired");
                            break;
                        }
                    }
                }

                if (string.IsNullOrEmpty(_sessionCookie))
                {
                    Logger.LogNetwork("Authentication", url, "Failed", "No session cookie received");
                    throw new InvalidOperationException("Authentication succeeded but no session cookie received.");
                }
            }
            else
            {
                var errorContent = await response.Content.ReadAsStringAsync();
                Logger.LogNetwork("Authentication", url, "Failed", $"Status: {response.StatusCode}");
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

            Logger.LogNetwork("Poll", "GetClipboardContent", "Starting", "Checking for new clipboard content");

            await EnsureAuthenticated();

            string url = $"{_settings.ServerEndpoint}/api/clipboard";
            var request = new HttpRequestMessage(HttpMethod.Get, url);

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
                    Logger.LogNetwork("Poll", url, "Success", $"New content found, Version: {result.Data.Version}");
                    return result.Data;
                }
                else
                {
                    Logger.LogNetwork("Poll", url, "Success", "No new content");
                }
            }
            else
            {
                Logger.LogNetwork("Poll", url, "Failed", $"Status: {response.StatusCode}");
            }

            return null;
        }

        public event EventHandler<ClipboardChangedEventArgs>? ClipboardChangedOnServer;

        public void StartPolling()
        {
            if (!_settings.IsConfigured)
                return;

            Logger.Log("Poll", "Starting clipboard polling");
            StopPolling();
            _pollCancellationTokenSource = new CancellationTokenSource();
            _ = Task.Run(() => PollForChangesAsync(_pollCancellationTokenSource.Token));
        }

        public void StopPolling()
        {
            Logger.Log("Poll", "Stopping clipboard polling");
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

                    var url = $"{_settings.ServerEndpoint}/api/poll?version={_lastKnownVersion}&timeout=30&client_id={HttpUtility.UrlEncode(_clientId)}";
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
                            Logger.LogNetwork("LongPoll", url, "NewData", $"Version: {result.Version}, Type: {result.Data.ContentType}");
                            
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
                            Logger.LogNetwork("LongPoll", url, "Timeout", $"Version: {result.Version}");
                        }
                    }
                    else
                    {
                        Logger.LogNetwork("LongPoll", url, "Failed", $"Status: {response.StatusCode}");
                    }
                }
                catch (OperationCanceledException)
                {
                    Logger.Log("Poll", "Polling cancelled");
                    break;
                }
                catch (Exception ex)
                {
                    Logger.LogError("Poll", "Polling error", ex);
                    // Wait before retrying on error
                    await Task.Delay(5000, cancellationToken);
                }
            }
        }

        private string GenerateClientId()
        {
            // Generate a unique client ID based on machine name, user, and a random component
            var machineName = Environment.MachineName;
            var userName = Environment.UserName;
            var randomPart = Guid.NewGuid().ToString("N")[..8]; // First 8 chars of GUID
            return $"{machineName}-{userName}-{randomPart}";
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