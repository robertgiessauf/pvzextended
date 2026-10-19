$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
public static class PuffPultRigSprites {
    static Rectangle Bounds(Bitmap sheet, int tile) {
        int left=512, top=512, right=-1, bottom=-1;
        for (int y=0; y<512; y++) for (int x=0; x<512; x++) {
            if (sheet.GetPixel((tile%3)*512+x,(tile/3)*512+y).A<16) continue;
            left=Math.Min(left,x); top=Math.Min(top,y);
            right=Math.Max(right,x); bottom=Math.Max(bottom,y);
        }
        if (right<left) throw new Exception("Empty rig component");
        return Rectangle.FromLTRB(left,top,right+1,bottom+1);
    }
    public static string Export(string source,string puffSource,string output,string preview) {
        string[] names={"rig_body","rig_blink","rig_sleep","stalk","cup","spore"};
        using (var sheet=new Bitmap(source))
        using (var originalPuff=new Bitmap(puffSource)) {
            if(sheet.Width!=1536 || sheet.Height!=1024) throw new Exception("Expected 3x2 rig atlas");
            var bounds=new Rectangle[6];
            for(int i=0;i<6;i++) bounds[i]=Bounds(sheet,i);
            float bodyScale=1;
            for(int i=0;i<3;i++) bodyScale=Math.Min(bodyScale,Math.Min(56f/bounds[i].Width,50f/bounds[i].Height));
            using(var contact=new Bitmap(660,340))
            using(var pg=Graphics.FromImage(contact))
            using(var font=new Font("Arial",12)) {
                pg.Clear(Color.FromArgb(62,102,55));
                pg.InterpolationMode=InterpolationMode.HighQualityBicubic;
                for(int i=0;i<6;i++) {
                    int width=i<3 ? 100 : i==3 ? 16 : i==4 ? 32 : originalPuff.Width;
                    int height=i<3 ? 100 : i==3 ? 64 : i==4 ? 24 : originalPuff.Height;
                    float w,h;
                    if(i<3) {w=bounds[i].Width*bodyScale; h=bounds[i].Height*bodyScale;}
                    else if(i==3) {w=6; h=60;}
                    else if(i==4) {w=30; h=18;}
                    else {w=width; h=height;}
                    var dest=new RectangleF(i<3 ? 60-w/2 : (width-w)/2, i<3 ? 86-h : (height-h)/2,w,h);
                    var crop=new Rectangle(bounds[i].X+(i%3)*512,bounds[i].Y+(i/3)*512,bounds[i].Width,bounds[i].Height);
                    using(var part=new Bitmap(width,height,PixelFormat.Format32bppArgb)) {
                        using(var g=Graphics.FromImage(part)) {
                            g.Clear(Color.Transparent);
                            g.CompositingMode=CompositingMode.SourceCopy;
                            g.InterpolationMode=InterpolationMode.HighQualityBicubic;
                            g.PixelOffsetMode=PixelOffsetMode.HighQuality;
                            // Reuse the original game's puff pixels, including their soft alpha.
                            if(i==5) g.DrawImageUnscaled(originalPuff,0,0);
                            else g.DrawImage(sheet,dest,crop,GraphicsUnit.Pixel);
                        }
                        string target=Path.Combine(output,"PuffPult_"+names[i]+".png");
                        if(i==5) File.Copy(puffSource,target,true);
                        else part.Save(target,ImageFormat.Png);
                        int x=(i%3)*220,y=(i/3)*170;
                        if(i<3) pg.DrawImage(part,x+30,y+5,140,140);
                        else pg.DrawImage(part,x+100-width,y+75-height,width*2,height*2);
                        pg.DrawString(names[i],font,Brushes.White,x+15,y+145);
                    }
                }
                contact.Save(preview,ImageFormat.Png);
            }
        }
        return "Exported six rig components with shared body scale and fixed pivots.";
    }
}
'@
[PuffPultRigSprites]::Export((Join-Path $PSScriptRoot 'rig-source.png'), (Join-Path $repo 'Debug/particles/PuffShroom_puff1.png'), (Join-Path $repo 'Debug/reanim'), (Join-Path $PSScriptRoot 'rig-parts.png'))
