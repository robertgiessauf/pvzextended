$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
public static class DeflectorNutSpriteSheet {
    // Crop the generated row gaps explicitly so no adjacent-row pixels enter a layer.
    static readonly int[] RowCuts={0,380,742,1086,1448};
    static Rectangle Cell(int tile) {int row=tile/3; return new Rectangle((tile%3)*362,RowCuts[row],362,RowCuts[row+1]-RowCuts[row]);}
    static Rectangle Bounds(Bitmap sheet, Rectangle cell, bool rimOnly) {
        int left=cell.Width, top=cell.Height, right=-1, bottom=-1;
        for(int y=0;y<cell.Height;y++) for(int x=0;x<cell.Width;x++) {
            Color p=sheet.GetPixel(cell.X+x,cell.Y+y);
            if(p.A<32 || (rimOnly && (p.A<180 || p.R>125 || p.G>155 || p.B>195))) continue;
            left=Math.Min(left,x); right=Math.Max(right,x); top=Math.Min(top,y); bottom=Math.Max(bottom,y);
        }
        if(right<left) throw new Exception("No visible sprite pixels");
        return Rectangle.FromLTRB(left,top,right+1,bottom+1);
    }
    public static string Slice(string source, string output, string preview) {
        string[] names={"body","cracked1","cracked2","blink","blink_cracked1","blink_cracked2",
            "shield","shield_cracked1","shield_cracked2","shield_glow","shield_glow_cracked1","shield_glow_cracked2"};
        using(var sheet=new Bitmap(source)) {
            if(sheet.Width!=1086 || sheet.Height!=1448) throw new Exception("Unexpected generated atlas dimensions");
            var bounds=new Rectangle[12];
            int bodyWidth=0,bodyHeight=0,shieldWidth=0,shieldHeight=0;
            for(int tile=0;tile<12;tile++) {
                bounds[tile]=Bounds(sheet,Cell(tile),tile>=6);
                if(tile<6) {bodyWidth=Math.Max(bodyWidth,bounds[tile].Width); bodyHeight=Math.Max(bodyHeight,bounds[tile].Height);}
                else {shieldWidth=Math.Max(shieldWidth,bounds[tile].Width); shieldHeight=Math.Max(shieldHeight,bounds[tile].Height);}
            }
            float bodyScale=Math.Min(74f/bodyWidth,94f/bodyHeight),shieldScale=Math.Min(36f/shieldWidth,70f/shieldHeight);
            var sprites=new Bitmap[12];
            try {
                for(int tile=0;tile<12;tile++) {
                    Rectangle core=bounds[tile],cell=Cell(tile);
                    float scale=tile<6 ? bodyScale : shieldScale;
                    float center=tile<6 ? 39 : 90,baseline=tile<6 ? 96 : 90;
                    float x=center-core.Width*scale/2-core.X*scale, y=baseline-core.Height*scale-core.Y*scale;
                    var sprite=new Bitmap(120,100,PixelFormat.Format32bppArgb); sprites[tile]=sprite;
                    using(var g=Graphics.FromImage(sprite)) {
                        g.Clear(Color.Transparent); g.CompositingMode=CompositingMode.SourceCopy;
                        g.InterpolationMode=InterpolationMode.HighQualityBicubic; g.PixelOffsetMode=PixelOffsetMode.HighQuality;
                        g.DrawImage(sheet,new RectangleF(x,y,cell.Width*scale,cell.Height*scale),cell,GraphicsUnit.Pixel);
                    }
                    if(sprite.GetPixel(0,0).A!=0 || sprite.GetPixel(119,99).A!=0) throw new Exception("Opaque sprite background");
                    sprite.Save(Path.Combine(output,"DeflectorNut_"+names[tile]+".png"),ImageFormat.Png);
                }
                using(var contact=new Bitmap(780,340,PixelFormat.Format32bppArgb))
                using(var pg=Graphics.FromImage(contact))
                using(var font=new Font("Arial",12)) {
                    pg.Clear(Color.FromArgb(62,102,55)); pg.InterpolationMode=InterpolationMode.HighQualityBicubic;
                    for(int state=0;state<3;state++) for(int lit=0;lit<2;lit++) {
                        using(var composite=new Bitmap(120,100,PixelFormat.Format32bppArgb)) {
                            using(var g=Graphics.FromImage(composite)) {
                                g.DrawImageUnscaled(sprites[state],0,0); g.DrawImageUnscaled(sprites[6+state],0,0);
                                if(lit!=0) g.DrawImageUnscaled(sprites[9+state],0,0);
                            }
                            int px=state*260,py=lit*170;
                            pg.DrawImage(composite,px+5,py+10,144,120); pg.DrawImage(composite,px+165,py+50,84,70);
                            pg.DrawString((state==0 ? "healthy" : "damage "+state)+(lit==0 ? " / idle" : " / reflecting"),font,Brushes.White,px+10,py+145);
                        }
                    }
                    contact.Save(preview,ImageFormat.Png);
                }
                return "Saved 12 aligned transparent 120x100 layers and an idle/impact preview.";
            } finally { foreach(var sprite in sprites) if(sprite!=null) sprite.Dispose(); }
        }
    }
}
"@
[DeflectorNutSpriteSheet]::Slice((Join-Path $PSScriptRoot 'front-shield-source.png'), (Join-Path $repo 'Debug/reanim'), (Join-Path $PSScriptRoot 'preview.png'))