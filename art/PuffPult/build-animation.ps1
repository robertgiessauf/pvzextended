$ErrorActionPreference = 'Stop'
Add-Type -ReferencedAssemblies System.Drawing,System.Xml -TypeDefinition @'
using System;
using System.IO;
using System.IO.Compression;
using System.Xml;
using System.Globalization;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;

public static class PuffPultAssets {
    static CultureInfo Culture = CultureInfo.InvariantCulture;
    static string Root;
    static float PuffPivotX, PuffPivotY;

    static XmlDocument Load(string relative) {
        var doc = new XmlDocument();
        doc.LoadXml("<reanim>" + File.ReadAllText(Path.Combine(Root, relative)) + "</reanim>");
        return doc;
    }
    static float Number(XmlNode node, string key, float fallback) {
        return node[key] == null ? fallback : float.Parse(node[key].InnerText, Culture);
    }
    static void AddValue(XmlDocument doc, XmlElement node, string key, float value) {
        var field = doc.CreateElement(key);
        field.InnerText = value.ToString("0.000", Culture);
        node.AppendChild(field);
    }
    static void AddString(XmlDocument doc, XmlElement node, string key, string value) {
        var field = doc.CreateElement(key);
        field.InnerText = value;
        node.AppendChild(field);
    }
    static void WriteString(BinaryWriter writer, string value) {
        byte[] bytes = System.Text.Encoding.ASCII.GetBytes(value);
        writer.Write(bytes.Length);
        writer.Write(bytes);
    }
    static byte[] Inflate(string path) {
        var source = File.ReadAllBytes(path);
        using (var input = new MemoryStream(source, 10, source.Length - 14))
        using (var inflater = new DeflateStream(input, CompressionMode.Decompress))
        using (var output = new MemoryStream()) {
            inflater.CopyTo(output);
            byte[] data = output.ToArray();
            if (BitConverter.ToUInt32(source, 0) != 0xDEADFED4 || data.Length != BitConverter.ToInt32(source, 4))
                throw new Exception("Invalid compiled header");
            return data;
        }
    }
    static byte[] Serialize(XmlDocument doc, uint schema) {
        XmlNodeList tracks = doc.DocumentElement.SelectNodes("track");
        using (var stream = new MemoryStream())
        using (var writer = new BinaryWriter(stream)) {
            writer.Write(schema);
            writer.Write(0); writer.Write(tracks.Count);
            writer.Write(Number(doc.DocumentElement, "fps", 12)); writer.Write(0);
            writer.Write(12); // sizeof(ReanimatorTrack), Win32
            foreach (XmlNode track in tracks) {
                writer.Write(0); writer.Write(0); writer.Write(track.SelectNodes("t").Count);
            }
            foreach (XmlNode track in tracks) {
                WriteString(writer, track["name"].InnerText);
                writer.Write(44); // sizeof(ReanimatorTransform), Win32
                foreach (XmlNode frame in track.SelectNodes("t")) {
                    foreach (string field in new[] { "x", "y", "kx", "ky", "sx", "sy", "f", "a" })
                        writer.Write(Number(frame, field, -10000));
                    writer.Write(0); writer.Write(0); writer.Write(0);
                }
                foreach (XmlNode frame in track.SelectNodes("t")) {
                    foreach (string field in new[] { "i", "font", "text" })
                        WriteString(writer, frame[field] == null ? "" : frame[field].InnerText);
                }
            }
            return stream.ToArray();
        }
    }
    static void Compile(XmlDocument doc, uint schema, string path) {
        byte[] data = Serialize(doc, schema);
        using (var stream = File.Create(path))
        using (var writer = new BinaryWriter(stream)) {
            writer.Write(0xDEADFED4u); writer.Write(data.Length);
            writer.Write((byte)0x78); writer.Write((byte)0x9C);
            using (var deflater = new DeflateStream(stream, CompressionLevel.Optimal, true))
                deflater.Write(data, 0, data.Length);
            uint a = 1, b = 0;
            foreach (byte value in data) { a = (a + value) % 65521; b = (b + a) % 65521; }
            uint checksum = (b << 16) | a;
            writer.Write((byte)(checksum >> 24)); writer.Write((byte)(checksum >> 16));
            writer.Write((byte)(checksum >> 8)); writer.Write((byte)checksum);
        }
    }
    static string ReadString(BinaryReader reader) {
        int length = reader.ReadInt32();
        return System.Text.Encoding.ASCII.GetString(reader.ReadBytes(length));
    }
    static void Validate(XmlDocument doc, byte[] data) {
        var tracks = doc.DocumentElement.SelectNodes("track");
        using (var reader = new BinaryReader(new MemoryStream(data))) {
            reader.ReadUInt32(); reader.ReadInt32();
            if (reader.ReadInt32() != tracks.Count) throw new Exception("Track count mismatch");
            if (reader.ReadSingle() != Number(doc.DocumentElement, "fps", 12)) throw new Exception("FPS mismatch");
            reader.ReadInt32();
            if (reader.ReadInt32() != 12) throw new Exception("Wrong track size");
            var counts = new List<int>();
            foreach (XmlNode track in tracks) {
                reader.ReadInt32(); reader.ReadInt32(); int count = reader.ReadInt32();
                if (count != track.SelectNodes("t").Count) throw new Exception("Frame count mismatch");
                counts.Add(count);
            }
            foreach (XmlNode track in tracks) {
                if (ReadString(reader) != track["name"].InnerText) throw new Exception("Track name mismatch");
                if (reader.ReadInt32() != 44) throw new Exception("Wrong transform size");
                foreach (XmlNode frame in track.SelectNodes("t")) {
                    foreach (string field in new[] { "x", "y", "kx", "ky", "sx", "sy", "f", "a" }) {
                        float actual = reader.ReadSingle();
                        if (actual != Number(frame, field, -10000)) throw new Exception("Float mismatch: " + field);
                    }
                    reader.ReadInt32(); reader.ReadInt32(); reader.ReadInt32();
                }
                foreach (XmlNode frame in track.SelectNodes("t")) {
                    foreach (string field in new[] { "i", "font", "text" }) {
                        string actual = ReadString(reader), expected = frame[field] == null ? "" : frame[field].InnerText;
                        if (actual != expected) throw new Exception("Resource mismatch: " + field);
                        if (field == "i" && actual.Length > 0) {
                            string imagePath = actual=="IMAGE_PUFFSHROOM_PUFF1" ? Path.Combine(Root,"Debug","particles","PuffShroom_puff1.png") :
                                Path.Combine(Root, "Debug", "reanim", actual.Substring("IMAGE_REANIM_".Length) + ".png");
                            if (!File.Exists(imagePath)) throw new Exception("Missing image: " + actual);
                        }
                    }
                }
            }
            if (reader.BaseStream.Position != data.Length) throw new Exception("Trailing compiled data");
        }
    }
    static float Ease(float t) {
        t=Math.Max(0,Math.Min(1,t));
        return t*t*t*(t*(6*t-15)+10);
    }
    // Cup, elbow, body squash/stretch, body lean, and cup tilt in the 100px rig canvas.
    static readonly float[][] ThrowKeys = {
        new float[] { 0,24,24,21,46,1,1,0,0 },
        new float[] { 6,3,40,23,56,1.045f,0.93f,-3,-16 },
        new float[] { 8,0,41,22,57,1.06f,0.92f,-4,-19 },
        new float[] { 10,64,-3,51,23,0.965f,1.045f,3.5f,35 },
        new float[] { 12,70,-1,55,22,0.98f,1.03f,2.5f,45 },
        new float[] { 15,20,29,20,48,1.015f,0.985f,-1.5f,-7 },
        new float[] { 18,26,23,22,45,0.995f,1.005f,0.5f,2 },
        new float[] { 20,24,24,21,46,1,1,0,0 }
    };
    static float[] Pose(int index) {
        if(index>=17 && index<38) {
            int frame=index-17, key=0;
            while(key<ThrowKeys.Length-2 && frame>ThrowKeys[key+1][0]) key++;
            var before=ThrowKeys[key]; var after=ThrowKeys[key+1];
            float t=Ease((frame-before[0])/(after[0]-before[0]));
            var pose=new float[8];
            for(int i=0;i<pose.Length;i++) pose[i]=before[i+1]+(after[i+1]-before[i+1])*t;
            return pose;
        }
        int cycle=index<17 ? index : index>=38 && index<55 ? index-38 : 0;
        float breath=(1-(float)Math.Cos(cycle*Math.PI*2/16))/2;
        bool asleep=index>=38 && index<55;
        return new float[] { asleep ? 22 : 24,(asleep ? 29 : 24)+breath,21,46+breath*0.5f,1,1-0.018f*breath,0,asleep ? -6 : 0 };
    }
    static void Place(XmlDocument doc,XmlElement frame,float x,float y,float sx,float sy,float angle,float pivotX,float pivotY) {
        double radians=angle*Math.PI/180;
        float cos=(float)Math.Cos(radians),sin=(float)Math.Sin(radians);
        AddValue(doc,frame,"x",x-cos*sx*pivotX+sin*sy*pivotY);
        AddValue(doc,frame,"y",y-sin*sx*pivotX-cos*sy*pivotY);
        AddValue(doc,frame,"kx",angle); AddValue(doc,frame,"ky",angle);
        AddValue(doc,frame,"sx",sx); AddValue(doc,frame,"sy",sy);
    }
    static void Stem(XmlDocument doc,XmlElement frame,float ax,float ay,float bx,float by) {
        float dx=bx-ax,dy=by-ay;
        float length=(float)Math.Sqrt(dx*dx+dy*dy);
        float angle=(float)(Math.Atan2(dy,dx)*180/Math.PI)+90;
        Place(doc,frame,ax*0.8f,ay*0.8f,0.8f,length/58*0.8f,angle,8,61);
    }
    public static string Build(string root) {
        Root = root;
        using(var puff=new Bitmap(Path.Combine(Root,"Debug","particles","PuffShroom_puff1.png"))) {
            PuffPivotX=puff.Width/2f; PuffPivotY=puff.Height/2f;
        }
        var wallnut = Load(@"Debug\compiled\reanim\Wallnut.reanim");
        byte[] reference = Inflate(Path.Combine(Root, @"Debug\compiled\reanim\Wallnut.reanim.compiled"));
        uint schema = BitConverter.ToUInt32(reference, 0);
        Validate(wallnut, reference);
        var doc = new XmlDocument();
        doc.LoadXml("<reanim><fps>12</fps></reanim>");
        string[] names = { "anim_idle", "anim_shooting", "anim_sleep", "anim_blink", "PuffPult_stalk_lower", "PuffPult_stalk_upper", "anim_face", "PuffPult_cup", "PuffPult_spore", "PuffPult_blink_anchor", "PuffPult_blink" };
        int[] starts = { 0, 17, 38, 55 }, lengths = { 17, 21, 17, 4 };
        for (int trackIndex = 0; trackIndex < names.Length; trackIndex++) {
            string name = names[trackIndex];
            var track = doc.CreateElement("track");
            AddString(doc, track, "name", name);
            for (int index = 0; index < 59; index++) {
                var frame = doc.CreateElement("t");
                if (trackIndex < 4) {
                    AddValue(doc, frame, "f", index >= starts[trackIndex] && index < starts[trackIndex]+lengths[trackIndex] ? 0 : -1);
                } else {
                    float[] pose=Pose(index);
                    bool blink=index>=55,shoot=index>=17 && index<38;
                    bool blinkSprite=name=="PuffPult_blink";
                    int shotFrame=index-17;
                    bool visible=blinkSprite ? blink : !blink;
                    // The standard pult releases 31 ticks into the 35 FPS / 21-frame clip.
                    // Frame 10 places the loaded puff at the actual projectile origin (55,-8).
                    if(name=="PuffPult_spore" && shoot && shotFrame>=10 && shotFrame<16) visible=false;
                    AddValue(doc,frame,"f",visible ? 0 : -1);
                    if(name=="PuffPult_stalk_lower") Stem(doc,frame,46,52,pose[2],pose[3]);
                    else if(name=="PuffPult_stalk_upper") {
                        float angle=pose[7]*(float)Math.PI/180;
                        Stem(doc,frame,pose[2],pose[3],pose[0]-8*(float)Math.Sin(angle),pose[1]+8*(float)Math.Cos(angle));
                    }
                    else if(name=="PuffPult_cup") Place(doc,frame,pose[0]*0.8f,pose[1]*0.8f,0.8f,0.8f,pose[7],16,12);
                    else if(name=="PuffPult_spore") {
                        float angle=pose[7]*(float)Math.PI/180;
                        float reload=shoot && shotFrame>=16 ? Ease((shotFrame-16)/4f) : 1;
                        float scale=(0.45f+0.55f*reload)*0.8f;
                        Place(doc,frame,(pose[0]+8*(float)Math.Sin(angle))*0.8f,(pose[1]-8*(float)Math.Cos(angle))*0.8f,scale,scale,0,PuffPivotX,PuffPivotY);
                        AddValue(doc,frame,"a",reload);
                    } else Place(doc,frame,48,68.8f,pose[4]*0.8f,pose[5]*0.8f,pose[6],60,86);
                    if(name!="PuffPult_blink_anchor") {
                        string image=name=="anim_face" ? (index>=38 && index<55 ? "RIG_SLEEP" : "RIG_BODY") :
                            blinkSprite ? "RIG_BLINK" : name=="PuffPult_cup" ? "CUP" : name=="PuffPult_spore" ? "SPORE" : "STALK";
                        AddString(doc,frame,"i",name=="PuffPult_spore" ? "IMAGE_PUFFSHROOM_PUFF1" : "IMAGE_REANIM_PUFFPULT_"+image);
                    }
                }
                track.AppendChild(frame);
            }
            doc.DocumentElement.AppendChild(track);
        }
        string path = Path.Combine(Root, @"Debug\compiled\reanim\PuffPult.reanim");
        var settings = new XmlWriterSettings { OmitXmlDeclaration = true, Indent = true, ConformanceLevel = ConformanceLevel.Fragment, NewLineChars = "\n" };
        using (var writer = XmlWriter.Create(path,settings))
            foreach (XmlNode node in doc.DocumentElement.ChildNodes) node.WriteTo(writer);
        Compile(doc,schema,path+".compiled");
        Validate(doc,Inflate(path+".compiled"));
        return "Compiled and validated Puff Pult: interpolated arm, cup, squash/stretch and reload; 11 tracks, 59 frames.";
    }
}

'@
[PuffPultAssets]::Build((Resolve-Path (Join-Path $PSScriptRoot '../..')).Path)
