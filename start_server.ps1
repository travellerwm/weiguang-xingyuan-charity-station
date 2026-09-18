$ErrorActionPreference = "Stop"
Set-Location -LiteralPath $PSScriptRoot

function Test-PortAvailable {
	param([int]$Port)
	$client = New-Object System.Net.Sockets.TcpClient
	try {
		$iar = $client.BeginConnect("127.0.0.1", $Port, $null, $null)
		$connected = $iar.AsyncWaitHandle.WaitOne(120)
		if ($connected) {
			$client.EndConnect($iar)
			return $false
		}
		return $true
	} catch {
		return $true
	} finally {
		$client.Close()
	}
}

function Get-MimeType {
	param([string]$Path)
	switch ([System.IO.Path]::GetExtension($Path).ToLowerInvariant()) {
		".html" { "text/html; charset=utf-8" }
		".js" { "text/javascript; charset=utf-8" }
		".wasm" { "application/wasm" }
		".pck" { "application/octet-stream" }
		".png" { "image/png" }
		".jpg" { "image/jpeg" }
		".jpeg" { "image/jpeg" }
		".svg" { "image/svg+xml" }
		".mp3" { "audio/mpeg" }
		default { "application/octet-stream" }
	}
}

$port = 8090
$url = "http://127.0.0.1:$port/index.html"
if (-not (Test-PortAvailable $port)) {
	Write-Host "Game server is already running: $url"
	Write-Host "Opening the existing game address so browser saves stay in the same slot."
	Start-Process $url
	exit 0
}

$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Parse("127.0.0.1"), $port)
$listener.Start()
Write-Host "Game started: $url"
Write-Host "Keep this window open. After the browser opens, click the page once to enable audio."
Start-Process $url

while ($true) {
	$client = $listener.AcceptTcpClient()
	try {
		$stream = $client.GetStream()
		$reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::ASCII, $false, 1024, $true)
		$requestLine = $reader.ReadLine()
		if ([string]::IsNullOrWhiteSpace($requestLine)) {
			$client.Close()
			continue
		}
		while ($reader.ReadLine()) { }
		$parts = $requestLine.Split(" ")
		$requestPath = "/"
		if ($parts.Length -ge 2) {
			$requestPath = $parts[1].Split("?")[0]
		}
		if ($requestPath -eq "/") {
			$requestPath = "/index.html"
		}
		$requestPath = [System.Uri]::UnescapeDataString($requestPath).TrimStart("/")
		$requestPath = $requestPath.Replace("/", [System.IO.Path]::DirectorySeparatorChar)
		$root = (Resolve-Path -LiteralPath $PSScriptRoot).Path
		$filePath = [System.IO.Path]::GetFullPath((Join-Path $root $requestPath))

		if (-not $filePath.StartsWith($root) -or -not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
			$body = [System.Text.Encoding]::UTF8.GetBytes("Not Found")
			$header = "HTTP/1.1 404 Not Found`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n"
			$bytes = [System.Text.Encoding]::ASCII.GetBytes($header)
			$stream.Write($bytes, 0, $bytes.Length)
			$stream.Write($body, 0, $body.Length)
			$client.Close()
			continue
		}

		$data = [System.IO.File]::ReadAllBytes($filePath)
		$mime = Get-MimeType $filePath
		$header = "HTTP/1.1 200 OK`r`nContent-Type: $mime`r`nContent-Length: $($data.Length)`r`nCross-Origin-Opener-Policy: same-origin`r`nCross-Origin-Embedder-Policy: require-corp`r`nCache-Control: no-store`r`nConnection: close`r`n`r`n"
		$bytes = [System.Text.Encoding]::ASCII.GetBytes($header)
		$stream.Write($bytes, 0, $bytes.Length)
		$stream.Write($data, 0, $data.Length)
	} catch {
		Write-Host $_.Exception.Message
	} finally {
		$client.Close()
	}
}
