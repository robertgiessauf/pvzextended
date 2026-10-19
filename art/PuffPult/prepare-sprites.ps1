$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$art = $PSScriptRoot
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
public static class PuffPultSpriteSheet {
    public static string Slice(string source, string output, string preview) {
        string[] names = { "body", "blink", "sleep", "windup", "release", "recover" };
        // Pack the generated poses around the idle body's center and ground baseline.
        // These are placement corrections only; artwork and pose deformation stay intact.
        int[] offsetX = { 0, 12, 0, -59, 14, 12 };
        int[] offsetY = { 0, 0, -13, 57, 57, 57 };
        using (var sheet = new Bitmap(source)) {
            if (sheet.Width != 1536 || sheet.Height != 1024) throw new Exception("Unexpected atlas dimensions");
            using (var concept = sheet.Clone(new Rectangle(0,0,512,512), PixelFormat.Format32bppArgb))
                concept.Save(Path.Combine(Path.GetDirectoryName(preview),"concept.png"),ImageFormat.Png);
            int left = 511, top = 511, right = 0, bottom = 0;
            for (int tile = 0; tile < 6; tile++) {
                int ox = (tile % 3) * 512, oy = (tile / 3) * 512;
                for (int y = 0; y < 512; y++) for (int x = 0; x < 512; x++) {
                    if (sheet.GetPixel(ox+x, oy+y).A < 16) continue;
                    left = Math.Min(left, x+offsetX[tile]); right = Math.Max(right, x+offsetX[tile]);
                    top = Math.Min(top, y+offsetY[tile]); bottom = Math.Max(bottom, y+offsetY[tile]);
                }
            }
            var crop = Rectangle.FromLTRB(left-2, top-2, right+3, bottom+3);
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
                            g.SetClip(dest);
                            var tileDest = new RectangleF(dest.X+(offsetX[tile]-crop.X)*scale,dest.Y+(offsetY[tile]-crop.Y)*scale,512*scale,512*scale);
                            g.DrawImage(sheet, tileDest, new Rectangle((tile%3)*512,(tile/3)*512,512,512), GraphicsUnit.Pixel);
                        }
                        for (int edge=0; edge<100; edge++)
                            if (sprite.GetPixel(edge,0).A != 0 || sprite.GetPixel(edge,99).A != 0 || sprite.GetPixel(0,edge).A != 0 || sprite.GetPixel(99,edge).A != 0)
                                throw new Exception("Sprite border is not transparent: "+names[tile]);
                        sprite.Save(Path.Combine(output,"PuffPult_"+names[tile]+".png"), ImageFormat.Png);
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
[PuffPultSpriteSheet]::Slice((Join-Path $art 'sprite-source.png'), (Join-Path $repo 'Debug/reanim'), (Join-Path $art 'preview.png'))
