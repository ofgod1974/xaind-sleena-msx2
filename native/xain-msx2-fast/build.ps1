param([string]$Sdcc = $env:SDCC, [string]$Assembler = $env:SJASMPLUS)
$ErrorActionPreference = 'Stop'
if (-not $Sdcc) { $Sdcc = (Get-Command sdcc -ErrorAction Stop).Source }
if (-not $Assembler) { $Assembler = (Get-Command sjasmplus -ErrorAction Stop).Source }
node (Join-Path $PSScriptRoot 'build.cjs') $Sdcc $Assembler
if ($LASTEXITCODE -ne 0) { throw 'Compilazione C/assembly fallita' }
