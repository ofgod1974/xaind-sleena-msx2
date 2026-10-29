param([string]$Assembler = 'sjasmplus')
$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot 'src')
try {
    & $Assembler '--raw=../xain-msx2.rom' '--sym=../symbols.txt' 'game.asm'
    if ($LASTEXITCODE -ne 0) { throw 'Compilazione fallita' }
} finally {
    Pop-Location
}
$romPath = Join-Path $PSScriptRoot 'xain-msx2.rom'
$htmlPath = Join-Path $PSScriptRoot 'index.html'
$romBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($romPath))
$htmlText = [IO.File]::ReadAllText($htmlPath)
$htmlText = [regex]::Replace($htmlText, '(?<=base64,)[A-Za-z0-9+/=]+', $romBase64)
[IO.File]::WriteAllText($htmlPath, $htmlText, [Text.UTF8Encoding]::new($false))
Write-Output 'ROM e pagina di gioco aggiornate.'
