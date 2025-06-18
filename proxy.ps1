# Прокси-сервер с поддержкой AD-аутентификации
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://remote_ip:8888/")
$listener.Start()
Write-Host "AD-прокси запущен на порту 8888. Ожидание запросов..."

while ($true) {
    $context = $listener.GetContext()
    $request = $context.Request
    $reader = New-Object System.IO.StreamReader($request.InputStream)
    $body = $reader.ReadToEnd()
    $reader.Close()

    $method = $request.HttpMethod
    $url = $request.Url.OriginalString

    # Перестраиваем URL, если клиент отправил только путь
    if ($url -notmatch "^https?://") {
        $host = $request.Headers["Host"]
        $url = "http://$host$url"
    }

    # Копируем заголовки (без Host)
    $headers = @{}
    foreach ($key in $request.Headers.AllKeys) {
        if ($key -ne "Host") {
            $headers[$key] = $request.Headers[$key]
        }
    }

    Write-Host "`n[>] $method $url"
    foreach ($h in $headers.Keys) {
        Write-Host "    $h: $($headers[$h])"
    }

    try {
        $response = Invoke-WebRequest -Uri $url -Method $method -Headers $headers -Body $body -UseDefaultCredentials -UseBasicParsing
        $responseBody = $response.Content
        $statusCode = $response.StatusCode
        Write-Host "[+] Ответ: $statusCode"
    } catch {
        $responseBody = "Ошибка при выполнении запроса: $_"
        $statusCode = 502
        Write-Host "[!] $responseBody"
    }

    # Отправка ответа клиенту
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseBody)
    $context.Response.StatusCode = $statusCode
    $context.Response.ContentLength64 = $buffer.Length
    $context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
    $context.Response.OutputStream.Close()
}
