$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$art = $PSScriptRoot
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
public static class PlanternNutSpriteSheet {
    public static string Slice(string source, string output, string preview) {
        string[] names = { "body", "cracked1", "cracked2", "blink", "blink_cracked1", "blink_cracked2" };
        using (var sheet = new Bitmap(source)) {
            if (sheet.Width != 1536 || sheet.Height != 1024) throw new Exception("Unexpected atlas dimensions");
            int left = 511, top = 511, right = 0, bottom = 0;
            for (int tile = 0; tile < 6; tile++) {
                int ox = (tile % 3) * 512, oy = (tile / 3) * 512;
                for (int y = 0; y < 512; y++) for (int x = 0; x < 512; x++) {
                    if (sheet.GetPixel(ox+x, oy+y).A < 16) continue;
                    left = Math.Min(left, x); right = Math.Max(right, x);
                    top = Math.Min(top, y); bottom = Math.Max(bottom, y);
                }
            }
            var crop = Rectangle.FromLTRB(Math.Max(0,left-2), Math.Max(0,top-2), Math.Min(512,right+3), Math.Min(512,bottom+3));
            float scale = 96f / Math.Max(crop.Width, crop.Height);
            var dest = new RectangleF((100-crop.Width*scale)/2, (100-crop.Height*scale)/2, crop.Width*scale, crop.Height*scale);
            using (var contact = new Bitmap(690, 340, PixelFormat.Format32bppArgb))
            using (var pg = Graphics.FromImage(contact))
            using (var font = new Font("Arial", 12)) {
                pg.Clear(Color.FromArgb(62,102,55));
                pg.InterpolationMode = InterpolationMode.HighQualityBicubic;
                for (int tile = 0; tile < 6; tile++) {
                    using (var sprite = new Bitmap(100, 100, PixelFormat.Format32bppArgb)) {
                        using (var g = Graphics.FromImage(sprite)) {
                            g.Clear(Color.Transparent);
                            g.CompositingMode = CompositingMode.SourceCopy;
                            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                            g.DrawImage(sheet, dest, new Rectangle(crop.X+(tile%3)*512,crop.Y+(tile/3)*512,crop.Width,crop.Height), GraphicsUnit.Pixel);
                        }
                        if (sprite.GetPixel(0,0).A != 0 || sprite.GetPixel(99,99).A != 0) throw new Exception("Sprite background is not transparent");
                        sprite.Save(Path.Combine(output,"PlanternNut_"+names[tile]+".png"), ImageFormat.Png);
                        int px = (tile%3)*230, py = (tile/3)*170;
                        pg.DrawImage(sprite,px+10,py+5,140,140);
                        pg.DrawImage(sprite,px+155,py+62,70,70);
                        pg.DrawString(names[tile], font, Brushes.White, px+10,py+145);
                    }
                }
                contact.Save(preview,ImageFormat.Png);
            }
            return "Saved six transparent 100x100 sprites; shared atlas crop "+crop+"; preview "+preview;
        }
    }
}
'@
[PlanternNutSpriteSheet]::Slice((Join-Path $art 'sprite-source.png'), (Join-Path $repo 'Debug/reanim'), (Join-Path $art 'preview.png'))
