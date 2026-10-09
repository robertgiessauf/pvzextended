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

public static class PlanternNutAssets {
    static CultureInfo Culture = CultureInfo.InvariantCulture;
    static string Root;

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
                            string imagePath = Path.Combine(Root, "Debug", "reanim", actual.Substring("IMAGE_REANIM_".Length) + ".png");
                            if (!File.Exists(imagePath)) throw new Exception("Missing image: " + actual);
                        }
                    }
                }
            }
            if (reader.BaseStream.Position != data.Length) throw new Exception("Trailing compiled data");
        }
    }
    public static string Build(string root) {
        Root = root;
        var wallnut = Load(@"Debug\compiled\reanim\Wallnut.reanim");
        byte[] reference = Inflate(Path.Combine(Root, @"Debug\compiled\reanim\Wallnut.reanim.compiled"));
        uint schema = BitConverter.ToUInt32(reference, 0);
        Validate(wallnut, reference);
        XmlNodeList poses = wallnut.DocumentElement.SelectNodes("track[name='anim_face']/t");
        var doc = new XmlDocument();
        doc.LoadXml("<reanim><fps>12</fps></reanim>");
        foreach (string name in new[] { "anim_idle", "anim_blink", "anim_face", "PlanternNut_blink_anchor", "PlanternNut_blink" }) {
            var track = doc.CreateElement("track");
            AddString(doc, track, "name", name);
            for (int index = 0; index < 21; index++) {
                var frame = doc.CreateElement("t");
                bool idle = index < 17;
                if (name == "anim_idle" || name == "anim_blink") {
                    if (index == 0 || index == 17)
                        AddValue(doc, frame, "f", (name == "anim_idle") == idle ? 0 : -1);
                } else if (name == "anim_face" || name == "PlanternNut_blink_anchor") {
                    if (idle) {
                        foreach (XmlNode field in poses[index].ChildNodes)
                            if (field.Name != "i" && field.Name != "f") frame.AppendChild(doc.ImportNode(field,true));
                        if (index == 0) {
                            AddValue(doc, frame, "f", 0);
                            if (name == "anim_face") AddString(doc, frame, "i", "IMAGE_REANIM_PLANTERNNUT_BODY");
                        }
                    } else if (index == 17 && name == "anim_face") AddValue(doc, frame, "f", -1);
                } else {
                    if (index == 0) AddValue(doc, frame, "f", -1);
                    if (index == 17) {
                        foreach (XmlNode field in poses[0].ChildNodes)
                            if (field.Name != "i" && field.Name != "f") frame.AppendChild(doc.ImportNode(field,true));
                        AddValue(doc, frame, "f", 0);
                        AddString(doc, frame, "i", "IMAGE_REANIM_PLANTERNNUT_BLINK");
                    }
                }
                track.AppendChild(frame);
            }
            doc.DocumentElement.AppendChild(track);
        }
        string path = Path.Combine(Root, @"Debug\compiled\reanim\PlanternNut.reanim");
        var settings = new XmlWriterSettings { OmitXmlDeclaration = true, Indent = true, ConformanceLevel = ConformanceLevel.Fragment, NewLineChars = "\n" };
        using (var writer = XmlWriter.Create(path,settings))
            foreach (XmlNode node in doc.DocumentElement.ChildNodes) node.WriteTo(writer);
        Compile(doc,schema,path+".compiled");
        Validate(doc,Inflate(path+".compiled"));
        return "Created and validated PlanternNut source and compiled animation: 5 tracks, 17 idle frames, 4 blink frames.";
    }
}
'@
[PlanternNutAssets]::Build((Resolve-Path (Join-Path $PSScriptRoot '../..')).Path)
