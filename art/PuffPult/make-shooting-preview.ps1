param([string]$FramesPath = (Join-Path $env:LOCALAPPDATA 'Temp/codex-puffpult/frames'))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationCore,WindowsBase
$encoder = [System.Windows.Media.Imaging.GifBitmapEncoder]::new()
for ($index = 0; $index -lt 60; $index++) {
    $path = Join-Path $FramesPath ('{0:000}.png' -f $index)
    $source = [System.Windows.Media.Imaging.BitmapImage]::new()
    $source.BeginInit()
    $source.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $source.UriSource = [System.Uri]::new($path)
    $source.EndInit()
    $scaled = [System.Windows.Media.Imaging.TransformedBitmap]::new($source, [System.Windows.Media.ScaleTransform]::new(3,3))
    $metadata = [System.Windows.Media.Imaging.BitmapMetadata]::new('gif')
    $metadata.SetQuery('/grctlext/Delay', [System.UInt16]2)
    $metadata.SetQuery('/grctlext/Disposal', [byte]2)
    $encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($scaled,$null,$metadata,$null))
}
$output = Join-Path $PSScriptRoot 'shooting-preview.gif'
$stream = [System.IO.File]::Create($output)
try { $encoder.Save($stream) } finally { $stream.Dispose() }
# WPF's GIF encoder accepts per-frame metadata but no global metadata.
# Add the standard loop application extension after the global color table.
$gif = [System.IO.File]::ReadAllBytes($output)
$headerSize = 13
if (($gif[10] -band 128) -ne 0) { $headerSize += 3 * [int][Math]::Pow(2,($gif[10] -band 7)+1) }
# Set frame timing directly, since framework GIF encoders can discard the delay metadata.
$cursor = $headerSize
$timedFrames = 0
while ($gif[$cursor] -ne 0x3B) {
    if ($gif[$cursor] -eq 0x21) {
        if ($gif[$cursor+1] -eq 0xF9) {
            $gif[$cursor+3] = ($gif[$cursor+3] -band 0xE3) -bor 8
            $gif[$cursor+4] = 2
            $gif[$cursor+5] = 0
            $timedFrames++
        }
        $cursor += 2
    } elseif ($gif[$cursor] -eq 0x2C) {
        $packed = $gif[$cursor+9]
        $cursor += 10
        if (($packed -band 128) -ne 0) { $cursor += 3 * [int][Math]::Pow(2,($packed -band 7)+1) }
        $cursor++ # LZW minimum code size
    } else { throw 'Unexpected GIF block' }
    while ($gif[$cursor] -ne 0) { $cursor += 1 + [int]$gif[$cursor] }
    $cursor++
}
if ($timedFrames -ne 60) { throw 'Missing GIF frame controls' }
[byte[]]$loopBlock = @(0x21,0xFF,0x0B) + [System.Text.Encoding]::ASCII.GetBytes('NETSCAPE2.0') + @(3,1,0,0,0)
$looped = [System.IO.MemoryStream]::new()
try {
    $looped.Write($gif,0,$headerSize)
    $looped.Write($loopBlock,0,$loopBlock.Length)
    $looped.Write($gif,$headerSize,$gif.Length-$headerSize)
    [System.IO.File]::WriteAllBytes($output,$looped.ToArray())
} finally { $looped.Dispose() }
$checkStream = [System.IO.File]::OpenRead($output)
try {
    $decoder = [System.Windows.Media.Imaging.GifBitmapDecoder]::new($checkStream,[System.Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat,[System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
    if ($decoder.Frames.Count -ne 60 -or $decoder.Frames[0].Metadata.GetQuery('/grctlext/Delay') -ne 2) { throw 'Invalid animated preview' }
} finally { $checkStream.Dispose() }
Write-Output "Saved 60 native engine frames at 50 FPS: $output"
