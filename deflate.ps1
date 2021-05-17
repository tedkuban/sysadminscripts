
#$base64data = "insert compressed and base64 data here"
#$data = Get-Content -Path $args[0] -Raw

#$ms = New-Object System.IO.MemoryStream
#$ms.Write($data, 0, $data.Length)
#$ms.Seek(0,0) | Out-Null
#$sr = New-Object System.IO.StreamReader(New-Object System.IO.Compression.DeflateStream($ms, [System.IO.Compression.CompressionMode]::Decompress))

$sr = New-Object System.IO.StreamReader(New-Object System.IO.Compression.DeflateStream((Get-Item -Path $args[0]).OpenRead(), [System.IO.Compression.CompressionMode]::Decompress))

while ($line = $sr.ReadLine()) {  
    $line
}