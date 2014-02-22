
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module deserialize;

import types;
import common;
import acomp;
import mainwin;
import container;
import treeops;
import text;
import uspsib;
import serial;
import richtext;
import arrow;
import bevel;
import circle;
import corners;
import cross;
import fancytext;
import fader;
import heart;
import line;
import morphtext;
import pattern;
import pixelimage;
import polygon;
import random;
import rect;
import regpoly;
import separator;
import reference;
import lgradient;
import rgradient;
import svgimage;
import rsvgwrap;
import polycurve;
import strokeset;
import drawing;
import pointset;
import regpc;
import controlset;
import crescent;
import moon;
import triangle;
import brushdabs;
import noise;
import mesh;
import tilings;
import teardrop;
import yinyang;
import shield;
import partition;
import curve;

import std.stdio;
import std.conv;
import std.array;
import std.format;
import std.stream;
import std.string;
import std.conv;
import std.path;
import std.uuid;
import std.zlib;

import gdk.RGBA;
import pango.PgFontDescription;
import gio.MemoryInputStream;
import gdk.Pixbuf;
import gtk.FileChooserDialog;
import gtk.FileFilter;
/*
struct SRGBA
{
   double r, g, b, a;
}
*/

class DSException : Exception
{
   this (size_t lineNum, string fline, string msg = "")
   {
      msg = msg.length? msg: "Variable name out of sequence";
      msg ~= "\n\""~fline~"\"";
      super(msg, __FILE__, lineNum);
   }
}

class Deserializer
{
   AppWindow aw;
   string fileName;
   InputStream si;
   string line;
   string name, val;
   double dWidth, dHeight;

   private string getLn()
   {
      return cast(string) si.readLine();
   }

   private string skip()
   {
      string line;
      for (int i = 0;; i++)
      {
         line = getLn();
         if (line.length > 0)
         {
            if (i == 0)
               throw new DSException(__LINE__, line, "Missing line break");
            return line;
         }
      }
   }

   private void getNV(size_t lineNum, string expected)
   {
      line = cast(string) si.readLine();
      string[] sa = split(line, "=");
      name = sa[0];
      val = sa[1];
      if (name != expected) throw new DSException(lineNum, line);
   }

   RGBA makeColor(string cs)
   {
      string[] a = cs.split(",");
      return new RGBA(to!double(a[0]), to!double(a[1]), to!double(a[2]), to!double(a[3]));
   }

   Transform makeTransform(string ts)
   {
      string[] a = ts.split(",");
      Transform tf;
      tf.hScale = to!double(a[0]);
      tf.vScale = to!double(a[1]);
      tf.hSkew = to!double(a[2]);
      tf.vSkew = to!double(a[3]);
      tf.hFlip = to!bool(a[4]);
      tf.vFlip = to!bool(a[5]);
      tf.ra = to!double(a[6]);

      return tf;
   }

   private ubyte[] readBytes(size_t n)
   {
      ubyte[] a;
      a.length = n;
      if (n)
         si.readExact(&a[0], n);
      return a;
   }

   UUID getUid(string s)
   {
      if (s == "")
         s = "00000000-0000-0000-0000-000000000000";
      return parseUUID(s);
   }

   private Coord s2Coord(string s, size_t ln)
   {
      string[] sa = split(s, ",");
      if (sa.length != 2)
         throw new DSException(ln, line, "Bad coordinate");
      Coord c;
      c.x = to!double(sa[0]);
      c.y = to!double(sa[1]);
      return c;
   }

   private Coord[] s2Path(string s, size_t ln)
   {
      string[] sa = split(s, ",");
      if (sa.length & 1)
         throw new DSException(ln, line, "Bad path");
      Coord[] ca;
      ca.length = sa.length/2;
      for (size_t i = 0; i < sa.length; i += 2)
      {
         ca[i/2].x = to!double(sa[i]);
         ca[i/2].y = to!double(sa[i+1]);
      }
      return ca;
   }

   private PathItem[] s2PCPath(string s, size_t ln)
   {
      string[] lines = split(s, "\n");
      PathItem[] pa;
      pa.length = lines.length;
      for (int i = 0; i < lines.length; i++)
      {
         string[] sa = lines[i].split(";");
         if (sa.length != 6)
            throw new DSException(ln, line, "Bad pcPath");
         pa[i].type = to!int(sa[0]);
         string[] ca = sa[1].split(",");
         pa[i].start.x = to!double(ca[0]); pa[i].start.y = to!double(ca[1]);
         ca = sa[2].split(",");
         pa[i].cp1.x = to!double(ca[0]); pa[i].cp1.y = to!double(ca[1]);
         ca = sa[3].split(",");
         pa[i].cp2.x = to!double(ca[0]); pa[i].cp2.y = to!double(ca[1]);
         ca = sa[4].split(",");
         pa[i].end.x = to!double(ca[0]); pa[i].end.y = to!double(ca[1]);
         ca = sa[5].split(",");
         pa[i].cog.x = to!double(ca[0]); pa[i].cog.y = to!double(ca[1]);
      }
      return pa;
   }

   private PartColor[] s2PartColorArray(string s, size_t ln)
   {
      PartColor[] pca;
      string[] ia = s.split(",");
      for (size_t i = 0; i < ia.length; i++)
      {
         PartColor pc;
         string[] sa = ia[i].split(";");
         if (sa.length != 4)
            throw new DSException(ln, line, "Bad PartColor array");
         pc.r = to!double(sa[0]);
         pc.g = to!double(sa[1]);
         pc.b = to!double(sa[2]);
         pc.a = to!double(sa[3]);
         pca ~= pc;
      }
      return pca;
   }

   this(AppWindow w)
   {
      aw = w;
   }

   double designWidth() { return dWidth; }
   double designHeight() { return dHeight; }

   void deserialize(string fn = null)
   {
      if (fn is null)
      {
         FileChooserDialog fcd = new FileChooserDialog("Choose COMPO File", aw, FileChooserAction.OPEN);
         FileFilter filter = new FileFilter();
         filter.setName("COMPO files (*.compo)");
         filter.addPattern("*.compo");
         fcd.setFilter(filter);
         fcd.setCurrentFolder(aw.recent.lastOpenFolder);

         int response = fcd.run();
         if (response != ResponseType.OK)
         {
            fcd.destroy();
            return;
         }
         fileName = fcd.getFilename();
         fcd.destroy();
      }
      else
         fileName = fn;
      size_t pos = fileName.lastIndexOf("/");
      if (pos > 0)
      {
         aw.cfn = fileName[pos+1..$];
         aw.recent.lastOpenFolder = fileName[0..pos];
      }
      try
      {
         si = new std.stream.File(fileName, FileMode.In);
      }
      catch (Exception x)
      {
         aw.popupMsg("Failed to open "~fileName, MessageType.ERROR);
         return;
      }
      aw.adjustRecent(fileName);
      si.readLine();    // skip the filename - debug only
      aw.versionLoaded = cast(string) si.readLine();
      string sheetName = cast(string) si.readLine();
      aw.newTV(-1, sheetName);

      si.readLine();
      readItems();
   }

   void readItems()
   {
      try
      {
         getNV(__LINE__, "dWidth");   // These are not used directly by COMPO, but needed by other tools
         dWidth = to!double(val);
         getNV(__LINE__, "dHeight");
         dHeight = to!double(val);
         getNV(__LINE__, "rootItems");
         int rootItems = to!int(val);
         int count = 0;

         for (int i = 0; i < rootItems; i++)
            readItem();

         aw.cto = aw.tm.root.children[0];
         aw.layout = aw.cto.layout;
         aw.layout.doref();
         aw.rp.add(aw.layout);
         aw.layout.show();
         aw.treeOps.select(aw.cto);

         aw.setFileName(fileName);
         aw.dirty = false;

         // Let the root items know the file is fully deserialised so they can stitch up
         // any fill dependencies
         foreach (ACBase child; aw.tm.root.children)
            child.deserializeComplete();

         return;
      }
      catch (Exception x)
      {
         auto w = appender!string();
         formattedWrite(w, "%s: %d - %s", x.file, x.line, x.msg);
         aw.popupMsg(w.data, MessageType.ERROR);
         string s = aw.config.iso? aw.config.defaultISOLayout:
                    aw.config.defaultUSLayout;
         aw.newTV(AC_CONTAINER, s);
      }
   }

   void deserializeReference(Reference r)
   {
      string fileName;
      FileChooserDialog fcd = new FileChooserDialog("Choose COMPO File", aw, FileChooserAction.OPEN);
      FileFilter filter = new FileFilter();
      filter.setName("COMPO files (*.compo)");
      filter.addPattern("*.compo");
      fcd.setFilter(filter);
      fcd.setCurrentFolder(aw.config.defaultFolder);

      int response = fcd.run();
      if (response != ResponseType.OK)
      {
         fcd.destroy();
         return;
      }
      fileName = fcd.getFilename();
      fcd.destroy();

      si = new std.stream.File(fileName, FileMode.In);
      string line = cast(string) si.readLine();    // skip the filename - debug only
      aw.versionLoaded = cast(string) si.readLine();
      string sheetName = cast(string) si.readLine(); // skip the sheet name

      si.readLine();
      getNV(__LINE__, "dWidth");   // These are not used directly by COMPO, but may be needed by other tools
      dWidth = to!double(val);
      getNV(__LINE__, "dHeight");
      dHeight = to!double(val);
      getNV(__LINE__, "rootItems");
      int rootItems = to!int(val);
      if (rootItems != 1)
      {
         aw.popupMsg("The COMPO file is empty", MessageType.ERROR);
         return;
      }

      Container that = readComposition(r);
      if (that !is null)
      {
         r.that = that;
         if (r.that.type == AC_CONTAINER)
            (cast(Container) r.that).noBG = true;
      }
   }

   void deserializeDrawing(Drawing d)
   {
      string s = d.dName.toLower();
      fileName = expandTilde("/usr/share/compo/drawings/"~s~".compo");

      try
      {
          si = new std.stream.File(fileName, FileMode.In);
      }
      catch (Exception x)
      {
         aw.popupMsg("Failed to open file "~fileName, MessageType.ERROR);
         return;
      }
      string line = cast(string) si.readLine();    // skip the filename - debug only
      aw.versionLoaded = cast(string) si.readLine();
      string sheetName = cast(string) si.readLine(); // skip the sheet name

      si.readLine();
      getNV(__LINE__, "dWidth");   // These are not used directly by COMPO, but ma be needed by other tools
      dWidth = to!double(val);
      getNV(__LINE__, "dHeight");
      dHeight = to!double(val);
      getNV(__LINE__, "rootItems");
      int rootItems = to!int(val);
      if (rootItems < 1)
      {
         aw.popupMsg("The COMPO file is empty", MessageType.ERROR);
         return;
      }

      Container that = readComposition(d);
      if (that !is null)
         d.that = that;
   }

   void readItem()
   {
      line = skip();
      if (line == "// Composition")
      {
         line = getLn();
         if (line != "type=1000")
            throw new DSException(__LINE__, line, "Incorrect type for Container");

         Container ctr = new Container(aw, aw.tm.root);
         aw.tm.root.children ~= ctr;
         aw.treeOps.notifyInsertion(ctr);

         basics(ctr);
         getNV(__LINE__, "baseColor");
         ctr.baseColor = makeColor(val);
         getNV(__LINE__, "nextChildId");
         ctr.nextChildId = to!int(val);
         getNV(__LINE__, "cc");
         int cc = to!int(val);

         for (int i = 0; i < cc; i++)
         {
            line = skip();
            if (line[0..2] != "//")
               throw new DSException(__LINE__, line, "Incorrect singleton intro");
            ACBase child = readSingleton(ctr);
            ctr.children ~= child;
            aw.treeOps.notifyInsertion(child);
            child.syncControls();
         }
      }
      else
      {
         if (line[0..2] != "//")
            throw new DSException(__LINE__, line, "Incorrect singleton intro");
         ACBase acb = readSingleton(aw.tm.root);
         aw.tm.root.children ~= acb;
         aw.treeOps.notifyInsertion(acb);
      }
   }

   Container readContainer(ACBase r)
   {
      line = skip();
      if (line != "// Composition")
      {
         throw new DSException(__LINE__, line,"Incorrect composition intro");
      }
      line = getLn();
      if (line != "type=1000")
         throw new DSException(__LINE__, line, "Incorrect type for Container");

      Container ctr = new Container(aw, r);

      basics(ctr);
      getNV(__LINE__, "baseColor");
      ctr.baseColor = makeColor(val);
      getNV(__LINE__, "nextChildId");
      ctr.nextChildId = to!int(val);
      getNV(__LINE__, "cc");
      int cc = to!int(val);

      for (int i = 0; i < cc; i++)
      {
         line = skip();
         if (line[0..2] != "//")
            throw new DSException(__LINE__, line, "Incorrect singleton intro");
         ACBase child = readSingleton(ctr);
         ctr.children ~= child;
         child.syncControls();
      }
      return ctr;
   }

   Container readComposition(ACBase r)
   {
      try
      {
         line = skip();
         if (line != "// Composition")
            throw new DSException(__LINE__, line, "COMPO file for reference use should contain a Composition as the first element");
         getLn();
         Container ctr = new Container(aw, r);
         ctr.setTransparent();

         basics(ctr);
         getNV(__LINE__, "baseColor");
         //ctr.baseColor = makeColor(val);
         getNV(__LINE__, "nextChildId");
         ctr.nextChildId = to!int(val);
         getNV(__LINE__, "cc");
         int cc = to!int(val);

         for (int i = 0; i < cc; i++)
         {
            line = skip();
            if (line[0..2] != "//")
               throw new DSException(__LINE__, line, "Incorrect singleton intro");
            ACBase child = readSingleton(ctr);
            ctr.children ~= child;
            child.syncControls();
         }
         return ctr;
      }
      catch (Exception x)
      {
         auto w = appender!string();
         formattedWrite(w, "%s: %d - %s", x.file, x.line, x.msg);
         aw.popupMsg(w.data, MessageType.ERROR);
      }
      return null;
   }

   ACBase readSingleton(ACBase parent)
   {
      getNV(__LINE__, "type");
      int t = to!int(val);
      ACBase child;
      switch (t)
      {
      case AC_TEXT:
         child = new PlainText(aw, parent);
         setupText(cast(PlainText) child);
         break;
      case AC_SERIAL:
         child = new Serial(aw, parent);
         setupSerial(cast(Serial) child);
         break;
      case AC_USPS:
         child = new USPS(aw, parent);
         setupUSPS(cast(USPS) child);
         break;
      case AC_RICHTEXT:
         child = new RichText(aw, parent);
         setupRichText(cast(RichText) child);
         break;
      case AC_ARROW:
         child = new Arrow(aw, parent);
         setupArrow(cast(Arrow) child);
         break;
      case AC_BEVEL:
         child = new Bevel(aw, parent);
         setupBevel(cast(Bevel) child);
         break;
      case AC_BRUSHDABS:
         child = new BrushDabs(aw, parent);
         setupBrushDabs(cast(BrushDabs) child);
         break;
      case AC_CIRCLE:
         child = new Circle(aw, parent);
         setupCircle(cast(Circle) child);
         break;
      case AC_CORNERS:
         child = new Corners(aw, parent);
         setupCorners(cast(Corners) child);
         break;
      case AC_CRESCENT:
         child = new Crescent(aw, parent);
         setupCrescent(cast(Crescent) child);
         break;
      case AC_CROSS:
         child = new Cross(aw, parent);
         setupCross(cast(Cross) child);
         break;
      case AC_CURVE:
         child = new Curve(aw, parent);
         setupCurve(cast(Curve) child);
         break;
      case AC_FANCYTEXT:
         child = new FancyText(aw, parent);
         setupFancyText(cast(FancyText) child);
         break;
      case AC_FADER:
         child = new Fader(aw, parent);
         setupFader(cast(Fader) child);
         break;
      case AC_HEART:
         child = new Heart(aw, parent);
         setupHeart(cast(Heart) child);
         break;
      case AC_LINE:
         child = new Line(aw, parent);
         setupLine(cast(Line) child);
         break;
      case AC_LGRADIENT:
         child = new LGradient(aw, parent);
         setupLGradient(cast(LGradient) child);
         break;
      case AC_MESH:
         child = new Mesh(aw, parent);
         setupMesh(cast(Mesh) child);
         break;
      case AC_MOON:
         child = new Moon(aw, parent);
         setupMoon(cast(Moon) child);
         break;
      case AC_NOISE:
         child = new Noise(aw, parent);
         setupNoise(cast(Noise) child);
         break;
      case AC_MORPHTEXT:
         child = new MorphText(aw, parent, true);
         setupMorphText(cast(MorphText) child);
         break;
      case AC_PARTITION:
         child = new Partition(aw, parent);
         setupPartition(cast(Partition) child);
         break;
      case AC_PATTERN:
         child = new Pattern(aw, parent);
         setupPattern(cast(Pattern) child);
         break;
      case AC_PIXBUF:
         child = new PixelImage(aw, parent);
         setupPixelImage(cast(PixelImage) child);
         // we only save the file name or the original picture in the file,
         // so must reconstitute the scaled one
         if ((cast(PixelImage) child).useFile)
            (cast(PixelImage) child).getPxb();
         (cast(PixelImage) child).setScaling();
         break;
      case AC_POINTSET:
         child = new PointSet(aw, parent);
         setupPointSet(cast(PointSet) child);
         break;
      case AC_POLYGON:
         child = new Polygon(aw, parent);
         setupPolygon(cast(Polygon) child);
         break;
      case AC_POLYCURVE:
         child = new Polycurve(aw, parent);
         setupPolycurve(cast(Polycurve) child);
         break;
      case AC_STROKESET:
         child = new StrokeSet(aw, parent);
         setupStrokeSet(cast(StrokeSet) child);
         break;
      case AC_RANDOM:
         child = new Random(aw, parent);
         setupRandom(cast(Random) child);
         break;
      case AC_RECT:
         child = new rect.Rectangle(aw, parent);
         setupRectangle(cast(rect.Rectangle) child);
         break;
      case AC_REGPOLYGON:
         child = new RegularPolygon(aw, parent);
         setupRegularPolygon(cast(RegularPolygon) child);
         break;
      case AC_REGPOLYCURVE:
         child = new RegularPolycurve(aw, parent);
         setupRegularPolycurve(cast(RegularPolycurve) child);
         break;
      case AC_RGRADIENT:
         child = new RGradient(aw, parent);
         setupRGradient(cast(RGradient) child);
         break;
      case AC_SEPARATOR:
         child = new Separator(aw, parent);
         setupSeparator(cast(Separator) child);
         break;
      case AC_SHIELD:
         child = new Shield(aw, parent);
         setupShield(cast(Shield) child);
         break;
      case AC_TILINGS:
         child = new Tilings(aw, parent);
         setupTilings(cast(Tilings) child);
         break;
      case AC_TEARDROP:
         child = new Teardrop(aw, parent);
         setupTeardrop(cast(Teardrop) child);
         break;
      case AC_TRIANGLE:
         child = new Triangle(aw, parent);
         setupTriangle(cast(Triangle) child);
         break;
      case AC_YINYANG:
         child = new YinYang(aw, parent);
         setupYinYang(cast(YinYang) child);
         break;
      case AC_DRAWING:
         child = new Drawing(aw, parent);
         setupDrawing(cast(Drawing) child);
         break;
      case AC_REFERENCE:
         child = new Reference(aw, parent);
         setupReference(cast(Reference) child);
         break;
      case AC_SVGIMAGE:
         child = new SVGImage(aw, parent);
         setupSVGImage(cast(SVGImage) child);
         break;
      default:
         break;
      }
      child.syncControls();
      return child;
   }

   void basics(ACBase acb)
   {
      getNV(__LINE__, "name");
      acb.name = val;
      getNV(__LINE__, "uuid");
      acb.uuid = UUID(val);
      getNV(__LINE__, "hOff");
      acb.hOff = to!double(val);
      getNV(__LINE__, "vOff");
      acb.vOff = to!double(val);
   }

   void restoreParamBlock(string s, ParamBlock* p)
   {
      string[] a = s.split("|");
      string[] b = a[0].split(";");
      for (int i = 0; i < 8; i++)
      {
         string[] c = b[i].split(",");
         p.cpa[i].x = to!double(c[0]);
         p.cpa[i].y = to!double(c[1]);
      }
      b = a[1].split(",");
      for (int i = 0; i < 8; i++)
         p.dpa[i] = to!double(b[i]);
      b = a[2].split(",");
      for (int i = 0; i < 8; i++)
         p.ipa[i] = to!int(b[i]);
      p.valid = true;
   }

   void setupText(PlainText x)
   {
      basics(x);

      getNV(__LINE__, "editMode");
      x.editMode = to!bool(val);
      getNV(__LINE__, "pfd");
      if (val != "0")
         x.pfd = PgFontDescription.fromString(val);
      getNV(__LINE__, "baseColor");
      x.baseColor= makeColor(val);
      getNV(__LINE__, "alignment");
      x.alignment= to!int(val);
      getNV(__LINE__, "centerText");
      x.centerText = to!bool(val);
      getNV(__LINE__, "shrink2Fit");
      x.shrink2Fit = to!bool(val);
      getNV(__LINE__, "text_length");
      int n = to!int(val);
      string text = cast(string) readBytes(n);
      x.textBlock.setAlignment(cast(PangoAlignment) x.alignment);
      x.tb.setText(text);
      x.te.modifyFont(x.pfd);
      x.te.overrideColor(x.te.getStateFlags(), x.baseColor);
      x.afterDeserialize();
}

   void setupUSPS(USPS x)
   {
      basics(x);

      getNV(__LINE__, "editMode");
      x.editMode = to!bool(val);
      getNV(__LINE__, "pfd");
      if (val != "0")
         x.pfd = PgFontDescription.fromString(val);
      getNV(__LINE__, "shrink2Fit");
      x.shrink2Fit = to!bool(val);
      getNV(__LINE__, "showData");
      x.showData = to!bool(val);
      getNV(__LINE__, "text_length");
      int n = to!int(val);
      string text = cast(string) readBytes(n);
      x.tb.setText(text);
      x.afterDeserialize();
   }

   void setupSerial(Serial x)
   {
      basics(x);

      getNV(__LINE__, "editMode");
      x.editMode = to!bool(val);
      getNV(__LINE__, "pfd");
      if (val != "0")
         x.pfd = PgFontDescription.fromString(val);
      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "number");
      x.number = to!uint(val);
      getNV(__LINE__, "padLength");
      x.padLength = to!int(val);
      getNV(__LINE__, "text_length");
      int n = to!int(val);
      string text = cast(string) readBytes(n);
      x.text = text;
      x.number = to!int(text)-1;
      x.tb.setText(text);
      x.te.modifyFont(x.pfd);
      x.te.overrideColor(x.te.getStateFlags(), x.baseColor);
      x.afterDeserialize();
   }

   void setupRichText(RichText x)
   {
      basics(x);

      getNV(__LINE__, "editMode");
      x.editMode = to!bool(val);
      getNV(__LINE__, "pfd");
      if (val != "0")
         x.pfd = PgFontDescription.fromString(val);
      getNV(__LINE__, "baseColor");
      x.baseColor= makeColor(val);
      getNV(__LINE__, "alignment");
      x.alignment= to!int(val);
      getNV(__LINE__, "serialized_length");
      int n = to!int(val);
      ubyte[] buffer;
      buffer.length = n;
      si.readExact(&buffer[0], n);
      x.deserialize(buffer);
      x.textBlock.setAlignment(cast(PangoAlignment) x.alignment);
      x.te.modifyFont(x.pfd);
      x.te.overrideColor(x.te.getStateFlags(), x.baseColor);
      x.afterDeserialize();
   }

   void setupFancyText(FancyText x)
   {
      basics(x);

      getNV(__LINE__, "editMode");
      x.editMode = to!bool(val);
      getNV(__LINE__, "pfd");
      if (val != "0")
         x.pfd = PgFontDescription.fromString(val);
      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "altColor");
      x.altColor = makeColor(val);
      getNV(__LINE__, "alignment");
      x.alignment = to!int(val);
      getNV(__LINE__, "angle");
      x.angle = to!double(val);
      getNV(__LINE__, "center");
      x.center = s2Coord(val, __LINE__);
      getNV(__LINE__, "orientation");
      x.orientation = to!int(val);
      getNV(__LINE__, "olt");
      x.olt = to!double(val);
      getNV(__LINE__, "fill");
      x.fill = to!bool(val);
      getNV(__LINE__, "outline");
      x.outline = to!bool(val);
      getNV(__LINE__, "fillFromPattern");
      x.fillFromPattern = to!bool(val);
      getNV(__LINE__, "fillUid");
      x.fillUid = parseUUID(val);
      getNV(__LINE__, "text_length");
      int n = to!int(val);
      string text = cast(string) readBytes(n);
      x.tb.setText(text);
      x.textBlock.setAlignment(cast(PangoAlignment) x.alignment);
      x.te.modifyFont(x.pfd);
      x.te.overrideColor(x.te.getStateFlags(), x.baseColor);
      x.dirty = true;
      x.afterDeserialize();
   }

   void setupMorphText(MorphText x)
   {
      basics(x);

      getNV(__LINE__, "editMode");
      x.editMode = to!bool(val);
      getNV(__LINE__, "pfd");
      if (val != "0")
         x.pfd = PgFontDescription.fromString(val);
      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "altColor");
      x.altColor = makeColor(val);
      getNV(__LINE__, "fill");
      x.fill = to!bool(val);
      getNV(__LINE__, "outline");
      x.outline = to!bool(val);
      getNV(__LINE__, "fillFromPattern");
      x.fillFromPattern = to!bool(val);
      getNV(__LINE__, "fillUid");
      x.fillUid = parseUUID(val);
      getNV(__LINE__, "olt");
      x.olt = to!double(val);
      getNV(__LINE__, "tf");
      x.tf = makeTransform(val);
      getNV(__LINE__, "cm");
      x.cm = to!int(val);
      getNV(__LINE__, "mp");
      restoreParamBlock(val, &x.mp);
      getNV(__LINE__, "text_length");
      int n = to!int(val);
      string text = cast(string) readBytes(n);
      x.tb.setText(text);
      x.afterDeserialize();
   }

   void setupArrow(Arrow x)
   {
      basics(x);

      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "altColor");
      x.altColor = makeColor(val);
      getNV(__LINE__, "lineWidth");
      x.lineWidth = to!double(val);
      getNV(__LINE__, "les");
      x.les = to!bool(val);
      getNV(__LINE__, "hw");
      x.hw = to!int(val);
      getNV(__LINE__, "fill");
      x.fill = to!bool(val);
      getNV(__LINE__, "outline");
      x.outline = to!bool(val);
      getNV(__LINE__, "fillFromPattern");
      x.fillFromPattern = to!bool(val);
      getNV(__LINE__, "fillUid");
      x.fillUid = parseUUID(val);
      getNV(__LINE__, "center");
      x.center = s2Coord(val, __LINE__);
      getNV(__LINE__, "oPath");
      x.oPath = s2Path(val, __LINE__);
      getNV(__LINE__, "tf");
      x.tf = makeTransform(val);
      x.afterDeserialize();
   }

   void setupBevel(Bevel x)
   {
      basics(x);

      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "bt");
      x.bt = to!double(val);
      x.afterDeserialize();
   }

   void setupBrushDabs(BrushDabs x)
   {
      basics(x);

      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "w");
      x.w = to!double(val);
      getNV(__LINE__, "tcp");
      x.tcp = to!double(val);
      getNV(__LINE__, "bcp");
      x.bcp = to!double(val);
      getNV(__LINE__, "nDabs");
      x.nDabs = to!uint(val);
      getNV(__LINE__, "shapeSeed");
      x.shapeSeed = to!uint(val);
      getNV(__LINE__, "colorSeed");
      x.colorSeed = to!uint(val);
      getNV(__LINE__, "angle");
      x.angle = to!double(val);
      getNV(__LINE__, "pointed");
      x.pointed = to!bool(val);
      getNV(__LINE__, "shade");
      x.shade = to!int(val);
      getNV(__LINE__, "printRandom");
      x.printRandom = to!bool(val);
      getNV(__LINE__, "pca");
      x.pca[] = s2PartColorArray(val,__LINE__)[];
      x.afterDeserialize();
   }

   void setupCircle(Circle x)
   {
      basics(x);

      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "altColor");
      x.altColor = makeColor(val);
      getNV(__LINE__, "lineWidth");
      x.lineWidth = to!double(val);
      getNV(__LINE__, "radius");
      x.radius = to!double(val);
      getNV(__LINE__, "tf");
      x.tf = makeTransform(val);
      getNV(__LINE__, "fill");
      x.fill = to!bool(val);
      getNV(__LINE__, "outline");
      x.outline = to!bool(val);
      getNV(__LINE__, "fillFromPattern");
      x.fillFromPattern = to!bool(val);
      getNV(__LINE__, "fillUid");
      x.fillUid = parseUUID(val);
      x.afterDeserialize();
   }

   void setupCorners(Corners x)
   {
      basics(x);

      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "lineWidth");
      x.lineWidth = to!double(val);
      getNV(__LINE__, "les");
      x.les = to!bool(val);
      getNV(__LINE__, "cw");
      x.cw = to!double(val);
      getNV(__LINE__, "ch");
      x.ch = to!double(val);
      getNV(__LINE__, "inset");
      x.inset = to!double(val);
      getNV(__LINE__, "relto");
      x.relto = to!int(val);
      getNV(__LINE__, "tl");
      x.tl = to!bool(val);
      getNV(__LINE__, "tr");
      x.tr = to!bool(val);
      getNV(__LINE__, "bl");
      x.bl = to!bool(val);
      getNV(__LINE__, "br");
      x.br = to!bool(val);
   }

   void setupCrescent(Crescent x)
   {
      basics(x);

      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "altColor");
      x.altColor = makeColor(val);
      getNV(__LINE__, "lineWidth");
      x.lineWidth = to!double(val);
      getNV(__LINE__, "les");
      x.les = to!bool(val);
      getNV(__LINE__, "fill");
      x.fill = to!bool(val);
      getNV(__LINE__, "outline");
      x.outline = to!bool(val);
      getNV(__LINE__, "fillFromPattern");
      x.fillFromPattern = to!bool(val);
      getNV(__LINE__, "fillUid");
      x.fillUid = parseUUID(val);
      getNV(__LINE__, "center");
      x.center = s2Coord(val, __LINE__);
      getNV(__LINE__, "r0");
      x.r0 = to!double(val);
      getNV(__LINE__, "r1");
      x.r1 =to!double(val);
      getNV(__LINE__, "d");
      x.d =to!double(val);
      getNV(__LINE__, "guidelines");
      x.guidelines =to!bool(val);
      getNV(__LINE__, "tf");
      x.tf = makeTransform(val);
      x.afterDeserialize();
   }

   void setupCross(Cross x)
   {
      basics(x);

      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "altColor");
      x.altColor = makeColor(val);
      getNV(__LINE__, "lineWidth");
      x.lineWidth = to!double(val);
      getNV(__LINE__, "les");
      x.les = to!bool(val);
      getNV(__LINE__, "fill");
      x.fill = to!bool(val);
      getNV(__LINE__, "outline");
      x.outline = to!bool(val);
      getNV(__LINE__, "fillFromPattern");
      x.fillFromPattern = to!bool(val);
      getNV(__LINE__, "fillUid");
      x.fillUid = parseUUID(val);
      getNV(__LINE__, "center");
      x.center = s2Coord(val, __LINE__);
      getNV(__LINE__, "oPath");
      x.oPath = s2Path(val, __LINE__);
      getNV(__LINE__, "tf");
      x.tf = makeTransform(val);
      getNV(__LINE__, "ar");
      x.ar = to!double(val);
      getNV(__LINE__, "cbOff");
      x.cbOff = to!double(val);
      getNV(__LINE__, "urW");
      x.urW = to!double(val);
      getNV(__LINE__, "cbW");
      x.cbW = to!double(val);
      x.afterDeserialize();
   }

   void setupCurve(Curve x)
   {
      basics(x);

      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "lineWidth");
      x.lineWidth = to!double(val);
      getNV(__LINE__, "les");
      x.les = to!bool(val);
      Coord start, cp1, cp2, end;
      getNV(__LINE__, "start");
      start = s2Coord(val, __LINE__);
      getNV(__LINE__, "cp1");
      cp1 = s2Coord(val, __LINE__);
      getNV(__LINE__, "cp2");
      cp2 = s2Coord(val, __LINE__);
      getNV(__LINE__, "end");
      end = s2Coord(val, __LINE__);
      x.curve = PathItemR(0, start, cp1, cp2, end);
      getNV(__LINE__, "tf");
      x.tf = makeTransform(val);
      x.afterDeserialize();
   }

   void setupFader(Fader x)
   {
      basics(x);

      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "rw");
      x.rw = to!double(val);
      getNV(__LINE__, "rh");
      x.rh = to!double(val);
      getNV(__LINE__, "opacity");
      x.opacity = to!double(val);
      getNV(__LINE__, "pin");
      x.pin = to!bool(val);
      getNV(__LINE__, "outline");
      x.outline = to!bool(val);
      x.afterDeserialize();
   }

   void setupHeart(Heart x)
   {
      basics(x);

      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "altColor");
      x.altColor = makeColor(val);
      getNV(__LINE__, "unit");
      x.unit = to!double(val);
      getNV(__LINE__, "lineWidth");
      x.lineWidth = to!double(val);
      getNV(__LINE__, "xform");
      x.xform = to!int(val);
      getNV(__LINE__, "fill");
      x.fill = to!bool(val);
      getNV(__LINE__, "outline");
      x.outline = to!bool(val);
      getNV(__LINE__, "fillFromPattern");
      x.fillFromPattern = to!bool(val);
      getNV(__LINE__, "fillUid");
      x.fillUid = parseUUID(val);
      getNV(__LINE__, "tf");
      x.tf = makeTransform(val);
      x.afterDeserialize();
   }

   void setupLine(Line x)
   {
      basics(x);

      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "lineWidth");
      x.lineWidth = to!double(val);
      getNV(__LINE__, "les");
      x.les = to!bool(val);
      getNV(__LINE__, "oPath");
      x.oPath = s2Path(val, __LINE__);
      getNV(__LINE__, "tf");
      x.tf = makeTransform(val);
      x.afterDeserialize();
   }

   void setupLGradient(LGradient x)
   {
      basics(x);
      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "fw");
      x.fw = to!double(val);
      getNV(__LINE__, "fp");
      x.fp = to!double(val);
      getNV(__LINE__, "angle");
      x.angle = to!double(val);
      getNV(__LINE__, "maxOpacity");
      x.maxOpacity = to!double(val);
      getNV(__LINE__, "gType");
      x.gType = to!int(val);
      getNV(__LINE__, "nStops");
      x.nStops = to!int(val);
      getNV(__LINE__, "revfade");
      x.revfade = to!bool(val);
      getNV(__LINE__, "orient");
      x.orient = to!int(val);
      x.afterDeserialize();
   }

   void setupMesh(Mesh x)
   {
      basics(x);

      getNV(__LINE__, "pca");
      x.pca[] = s2PartColorArray(val,__LINE__)[];
      getNV(__LINE__, "diagonal");
      x.diagonal = to!double(val);
      getNV(__LINE__, "pattern");
      x.pattern = to!int(val);
      getNV(__LINE__, "instanceSeed");
      x.instanceSeed = to!uint(val);
      getNV(__LINE__, "printRandom");
      x.printRandom = to!bool(val);
      getNV(__LINE__, "tf");
      x.tf = makeTransform(val);
      x.afterDeserialize();
   }

   void setupMoon(Moon x)
   {
      basics(x);

      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "altColor");
      x.altColor = makeColor(val);
      getNV(__LINE__, "lineWidth");
      x.lineWidth = to!double(val);
      getNV(__LINE__, "radius");
      x.radius = to!double(val);
      getNV(__LINE__, "tf");
      x.tf = makeTransform(val);
      getNV(__LINE__, "fill");
      x.fill = to!bool(val);
      getNV(__LINE__, "outline");
      x.outline = to!bool(val);
      getNV(__LINE__, "fillFromPattern");
      x.fillFromPattern = to!bool(val);
      getNV(__LINE__, "fillUid");
      x.fillUid = parseUUID(val);
      getNV(__LINE__, "day");
      x.day = to!int(val);
      x.afterDeserialize();
   }

   void setupNoise(Noise x)
   {
      basics(x);

      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "lineWidth");
      x.lineWidth = to!double(val);
      getNV(__LINE__, "level");
      x.level = to!int(val);
      getNV(__LINE__, "dots");
      x.dots = to!int(val);
      getNV(__LINE__, "instanceSeed");
      x.instanceSeed = to!uint(val);
      x.afterDeserialize();
   }

   void setupPartition(Partition x)
   {
      basics(x);

      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "lineWidth");
      x.lineWidth = to!double(val);
      getNV(__LINE__, "x");
      x.x = to!double(val);
      getNV(__LINE__, "y");
      x.y = to!double(val);
      getNV(__LINE__, "choice");
      x.choice = to!int(val);
      getNV(__LINE__, "outline");
      x.outline = to!bool(val);
      getNV(__LINE__, "vertical");
      x.vertical = to!bool(val);
      x.afterDeserialize();
   }

   void setupPattern(Pattern x)
   {
      basics(x);

      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "lineWidth");
      x.lineWidth = to!double(val);
      getNV(__LINE__, "rows");
      x.rows = to!int(val);
      getNV(__LINE__, "cols");
      x.cols = to!int(val);
      getNV(__LINE__, "unit");
      x.unit = to!double(val);
      getNV(__LINE__, "choice");
      x.choice = to!int(val);
      getNV(__LINE__, "tf");
      x.tf = makeTransform(val);
      x.afterDeserialize();
   }

   void setupPixelImage(PixelImage x)
   {
      basics(x);

      getNV(__LINE__, "fileName");
      x.fileName = val;
      getNV(__LINE__, "scaleType");
      x.scaleType = to!int(val);
      getNV(__LINE__, "sadj");
      x.sadj = to!double(val);
      getNV(__LINE__, "useFile");
      x.useFile = to!bool(val);
      getNV(__LINE__, "data_length");
      int n = to!int(val);
      if (n)
      {
         x.src.length = n;
         si.readExact(x.src.ptr, n);
         MemoryInputStream ms = new MemoryInputStream(x.src.ptr, x.src.length, null);
         x.pxb = new Pixbuf(ms, null);
      }
      else
      {
         x.getPxb();
      }
      x.afterDeserialize();
   }

   void setupSVGImage(SVGImage x)
   {
      basics(x);

      getNV(__LINE__, "fileName");
      x.fileName = val;
      getNV(__LINE__, "scaleType");
      x.scaleType = to!int(val);
      getNV(__LINE__, "scaleX");
      x.scaleX = to!double(val);
      getNV(__LINE__, "useFile");
      x.useFile = to!bool(val);
      getNV(__LINE__, "data_length");
      size_t n = to!int(val);
      if (n)
      {
         x.svgData.length = n;
         si.readExact(x.svgData.ptr, n);
         x.svgr = new SVGRenderer(x.svgData.ptr, n);
      }
      else
         x.svgr = new SVGRenderer(x.fileName);
      x.afterDeserialize();
   }

   void setupPolycurve(Polycurve x)
   {
      basics(x);

      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "altColor");
      x.altColor = makeColor(val);
      getNV(__LINE__, "lineWidth");
      x.lineWidth = to!double(val);
      getNV(__LINE__, "les");
      x.les = to!bool(val);
      getNV(__LINE__, "open");
      x.open = to!bool(val);
      getNV(__LINE__, "fill");
      x.fill = to!bool(val);
      getNV(__LINE__, "outline");
      x.outline = to!bool(val);
      getNV(__LINE__, "fillFromPattern");
      x.fillFromPattern = to!bool(val);
      getNV(__LINE__, "fillUid");
      x.fillUid = parseUUID(val);
      getNV(__LINE__, "center");
      x.center = s2Coord(val, __LINE__);
      getNV(__LINE__, "activeCoords");
      x.activeCoords = to!int(val);
      getNV(__LINE__, "current");
      x.current = to!int(val);
      getNV(__LINE__, "tf");
      x.tf = makeTransform(val);
      getNV(__LINE__, "data_length");
      int n = to!int(val);
      char[] ca;
      ca.length = n;
      si.readExact(&ca[0], n);
      x.pcPath = s2PCPath(cast(string) ca, __LINE__);
      x.afterDeserialize();
   }

   void setupStrokeSet(StrokeSet x)
   {
      basics(x);

      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "altColor");
      x.altColor = makeColor(val);
      getNV(__LINE__, "lineWidth");
      x.lineWidth = to!double(val);
      getNV(__LINE__, "les");
      x.les = to!bool(val);
      getNV(__LINE__, "fill");
      x.fill = to!bool(val);
      getNV(__LINE__, "outline");
      x.outline = to!bool(val);
      getNV(__LINE__, "center");
      x.center = s2Coord(val, __LINE__);
      getNV(__LINE__, "activeCoords");
      x.activeCoords = to!int(val);
      getNV(__LINE__, "current");
      x.current = to!int(val);
      getNV(__LINE__, "tf");
      x.tf = makeTransform(val);
      getNV(__LINE__, "data_length");
      int n = to!int(val);
      char[] ca;
      ca.length = n;
      si.readExact(&ca[0], n);
      x.pcPath = s2PCPath(cast(string) ca, __LINE__);
      x.afterDeserialize();
   }

   void setupPointSet(PointSet x)
   {
      basics(x);

      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "lineWidth");
      x.lineWidth = to!double(val);
      getNV(__LINE__, "center");
      x.center = s2Coord(val, __LINE__);
      getNV(__LINE__, "oPath");
      x.oPath = s2Path(val, __LINE__);
      getNV(__LINE__, "tf");
      x.tf = makeTransform(val);
      x.afterDeserialize();
   }

   void setupPolygon(Polygon x)
   {
      basics(x);

      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "altColor");
      x.altColor = makeColor(val);
      getNV(__LINE__, "lineWidth");
      x.lineWidth = to!double(val);
      getNV(__LINE__, "les");
      x.les = to!bool(val);
      getNV(__LINE__, "open");
      x.open = to!bool(val);
      getNV(__LINE__, "fill");
      x.fill = to!bool(val);
      getNV(__LINE__, "outline");
      x.outline = to!bool(val);
      getNV(__LINE__, "fillFromPattern");
      x.fillFromPattern = to!bool(val);
      getNV(__LINE__, "fillUid");
      x.fillUid = parseUUID(val);
      getNV(__LINE__, "center");
      x.center = s2Coord(val, __LINE__);
      getNV(__LINE__, "oPath");
      x.oPath = s2Path(val, __LINE__);
      getNV(__LINE__, "tf");
      x.tf = makeTransform(val);
      x.afterDeserialize();
   }

   void setupRandom(Random x)
   {
      x.reBuild = false;
      basics(x);

      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "altColor");
      x.altColor = makeColor(val);
      getNV(__LINE__, "lineWidth");
      x.lineWidth = to!double(val);
      getNV(__LINE__, "count");
      x.count = to!int(val);
      getNV(__LINE__, "element");
      x.element = to!int(val);
      getNV(__LINE__, "lower");
      x.lower = to!double(val);
      getNV(__LINE__, "upper");
      x.upper = to!double(val);
      getNV(__LINE__, "instanceSeed");
      x.instanceSeed = to!uint(val);
      getNV(__LINE__, "printRandom");
      x.printRandom = to!bool(val);
      x.si.length = x.count;
      for (int i = 0; i < x.count; i++)
      {
         string a = getLn();
         string[] sa = split(a, "|");
         ShapeInfo t;
         t.c1 = to!double(sa[0]);
         t.c2 = to!double(sa[1]);
         t.c3 = to!double(sa[2]);
         t.c4 = to!double(sa[3]);
         t.c5 = to!double(sa[4]);
         t.c6 = to!double(sa[5]);
         x.si[i] = t;
      }
      x.afterDeserialize();
   }

   void setupRectangle(rect.Rectangle x)
   {
      basics(x);

      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "altColor");
      x.altColor = makeColor(val);
      getNV(__LINE__, "lineWidth");
      x.lineWidth = to!double(val);
      getNV(__LINE__, "les");
      x.les = to!bool(val);
      getNV(__LINE__, "square");
      x.square = to!bool(val);
      getNV(__LINE__, "rounded");
      x.rounded = to!bool(val);
      getNV(__LINE__, "fill");
      x.fill = to!bool(val);
      getNV(__LINE__, "outline");
      x.outline = to!bool(val);
      getNV(__LINE__, "fillFromPattern");
      x.fillFromPattern = to!bool(val);
      getNV(__LINE__, "fillUid");
      x.fillUid = parseUUID(val);
      getNV(__LINE__, "ar");
      x.ar = to!double(val);
      getNV(__LINE__, "size");
      x.size = to!double(val);
      getNV(__LINE__, "rr");
      x.rr =  to!double(val);
      getNV(__LINE__, "tf");
      x.tf = makeTransform(val);
      x.afterDeserialize();
   }

   void setupRegularPolygon(RegularPolygon x)
   {
      basics(x);

      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "altColor");
      x.altColor = makeColor(val);
      getNV(__LINE__, "lineWidth");
      x.lineWidth = to!double(val);
      getNV(__LINE__, "les");
      x.les = to!bool(val);
      getNV(__LINE__, "sides");
      x.sides = to!int(val);
      getNV(__LINE__, "fill");
      x.fill = to!bool(val);
      getNV(__LINE__, "outline");
      x.outline = to!bool(val);
      getNV(__LINE__, "fillFromPattern");
      x.fillFromPattern = to!bool(val);
      getNV(__LINE__, "fillUid");
      x.fillUid = parseUUID(val);
      getNV(__LINE__, "isStar");
      x.isStar = to!bool(val);
      getNV(__LINE__, "radius");
      x.radius = to!double(val);
      getNV(__LINE__, "center");
      x.center = s2Coord(val, __LINE__);
      getNV(__LINE__, "starIndent");
      x.starIndent = to!double(val);
      getNV(__LINE__, "oPath");
      x.oPath = s2Path(val, __LINE__);
      getNV(__LINE__, "tf");
      x.tf = makeTransform(val);
      x.afterDeserialize();
   }

   void setupRegularPolycurve(RegularPolycurve x)
   {
      basics(x);

      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "altColor");
      x.altColor = makeColor(val);
      getNV(__LINE__, "lineWidth");
      x.lineWidth = to!double(val);
      getNV(__LINE__, "les");
      x.les = to!bool(val);
      getNV(__LINE__, "sides");
      x.sides = to!int(val);
      getNV(__LINE__, "joinRadius");
      x.joinRadius = to!double(val);
      getNV(__LINE__, "joinAngle");
      x.joinAngle = to!double(val);
      getNV(__LINE__, "cp1Radius");
      x.cp1Radius = to!double(val);
      getNV(__LINE__, "cp1ARadius");
      x.cp1ARadius = to!double(val);
      getNV(__LINE__, "cp1Angle");
      x.cp1Angle = to!double(val);
      getNV(__LINE__, "cp1AAngle");
      x.cp1AAngle = to!double(val);
      getNV(__LINE__, "cp2Radius");
      x.cp2Radius = to!double(val);
      getNV(__LINE__, "cp2ARadius");
      x.cp2ARadius = to!double(val);
      getNV(__LINE__, "cp2Angle");
      x.cp2Angle = to!double(val);
      getNV(__LINE__, "cp2AAngle");
      x.cp2AAngle = to!double(val);
      getNV(__LINE__, "activeCP");
      x.activeCP = to!int(val);
      getNV(__LINE__, "symmetry");
      x.symmetry = to!int(val);
      getNV(__LINE__, "fill");
      x.fill = to!bool(val);
      getNV(__LINE__, "outline");
      x.outline = to!bool(val);
      getNV(__LINE__, "fillFromPattern");
      x.fillFromPattern = to!bool(val);
      getNV(__LINE__, "fillUid");
      x.fillUid = parseUUID(val);
      getNV(__LINE__, "target");
      x.target = to!double(val);
      getNV(__LINE__, "center");
      x.center = s2Coord(val, __LINE__);
      getNV(__LINE__, "tf");
      x.tf = makeTransform(val);
      x.afterDeserialize();
   }

   void setupRGradient(RGradient x)
   {
      basics(x);
      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "outrad");
      x.outrad = to!double(val);
      getNV(__LINE__, "maxOpacity");
      x.maxOpacity = to!double(val);
      getNV(__LINE__, "center");
      x.center = s2Coord(val, __LINE__);
      getNV(__LINE__, "gType");
      x.gType = to!int(val);
      getNV(__LINE__, "nStops");
      x.nStops = to!int(val);
      getNV(__LINE__, "mark");
      x.mark = to!bool(val);
      getNV(__LINE__, "revfade");
      x.revfade = to!bool(val);
      x.afterDeserialize();
   }


   void setupSeparator(Separator x)
   {
      basics(x);

      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "lineWidth");
      x.lineWidth = to!double(val);
      getNV(__LINE__, "hStart");
      x.hStart = s2Coord(val, __LINE__);
      getNV(__LINE__, "hEnd");
      x.hEnd = s2Coord(val, __LINE__);
      getNV(__LINE__, "vStart");
      x.vStart = s2Coord(val, __LINE__);
      getNV(__LINE__, "vEnd");
      x.vEnd = s2Coord(val, __LINE__);
      getNV(__LINE__, "les");
      x.les = to!bool(val);
      getNV(__LINE__, "horizontal");
      x.horizontal = to!bool(val);
      x.afterDeserialize();
   }

   void setupShield(Shield x)
   {
      basics(x);

      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "altColor");
      x.altColor = makeColor(val);
      getNV(__LINE__, "unit");
      x.unit = to!double(val);
      getNV(__LINE__, "style");
      x.style = to!int(val);
      getNV(__LINE__, "lineWidth");
      x.lineWidth = to!double(val);
      getNV(__LINE__, "xform");
      x.xform = to!int(val);
      getNV(__LINE__, "fill");
      x.fill = to!bool(val);
      getNV(__LINE__, "outline");
      x.outline = to!bool(val);
      getNV(__LINE__, "fillFromPattern");
      x.fillFromPattern = to!bool(val);
      getNV(__LINE__, "fillUid");
      x.fillUid = parseUUID(val);
      getNV(__LINE__, "tf");
      x.tf = makeTransform(val);
      x.afterDeserialize();
   }

   void setupTilings(Tilings x)
   {
      basics(x);

      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "center");
      x.center = s2Coord(val, __LINE__);
      getNV(__LINE__, "pattern");
      x.pattern = to!int(val);
      getNV(__LINE__, "shade");
      x.shade = to!int(val);
      getNV(__LINE__, "colorSeed");
      x.colorSeed = to!uint(val);
      getNV(__LINE__, "shapeSeed");
      x.shapeSeed = to!uint(val);
      getNV(__LINE__, "pca");
      x.pca[] = s2PartColorArray(val,__LINE__)[];
      getNV(__LINE__, "printRandom");
      x.printRandom = to!bool(val);
      getNV(__LINE__, "irregular");
      x.irregular = to!bool(val);
      x.afterDeserialize();
   }

   void setupTeardrop(Teardrop x)
   {
      basics(x);

      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "altColor");
      x.altColor = makeColor(val);
      getNV(__LINE__, "unit");
      x.unit = to!double(val);
      getNV(__LINE__, "lineWidth");
      x.lineWidth = to!double(val);
      getNV(__LINE__, "xform");
      x.xform = to!int(val);
      getNV(__LINE__, "fill");
      x.fill = to!bool(val);
      getNV(__LINE__, "outline");
      x.outline = to!bool(val);
      getNV(__LINE__, "fillFromPattern");
      x.fillFromPattern = to!bool(val);
      getNV(__LINE__, "fillUid");
      x.fillUid = parseUUID(val);
      getNV(__LINE__, "tf");
      x.tf = makeTransform(val);
      x.afterDeserialize();
   }

   void setupTriangle(Triangle x)
   {
      basics(x);

      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "altColor");
      x.altColor = makeColor(val);
      getNV(__LINE__, "lineWidth");
      x.lineWidth = to!double(val);
      getNV(__LINE__, "les");
      x.les = to!bool(val);
      getNV(__LINE__, "fill");
      x.fill = to!bool(val);
      getNV(__LINE__, "outline");
      x.outline = to!bool(val);
      getNV(__LINE__, "fillFromPattern");
      x.fillFromPattern = to!bool(val);
      getNV(__LINE__, "fillUid");
      x.fillUid = parseUUID(val);
      getNV(__LINE__, "center");
      x.center = s2Coord(val, __LINE__);
      getNV(__LINE__, "oPath");
      x.oPath = s2Path(val, __LINE__);
      getNV(__LINE__, "tf");
      x.tf = makeTransform(val);
      getNV(__LINE__, "w");
      x.w = to!double(val);
      getNV(__LINE__, "h");
      x.h = to!double(val);
      getNV(__LINE__, "ttype");
      x.ttype = to!int(val);
      x.afterDeserialize();
   }

   void setupYinYang(YinYang x)
   {
      basics(x);

      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "altColor");
      x.altColor = makeColor(val);
      getNV(__LINE__, "unit");
      x.unit = to!double(val);
      getNV(__LINE__, "lineWidth");
      x.lineWidth = to!double(val);
      getNV(__LINE__, "xform");
      x.xform = to!int(val);
      getNV(__LINE__, "fill");
      x.fill = to!bool(val);
      getNV(__LINE__, "outline");
      x.outline = to!bool(val);
      getNV(__LINE__, "fillFromPattern");
      x.fillFromPattern = to!bool(val);
      getNV(__LINE__, "fillUid");
      x.fillUid = parseUUID(val);
      getNV(__LINE__, "tf");
      x.tf = makeTransform(val);
      x.afterDeserialize();
   }

   void setupDrawing(Drawing x)
   {
      basics(x);

      getNV(__LINE__, "center");
      x.center = s2Coord(val, __LINE__);
      getNV(__LINE__, "dName");
      x.dName = val;
      getNV(__LINE__, "tf");
      x.tf = makeTransform(val);
      x.afterDeserialize();
   }

   void setupReference(Reference x)
   {
      basics(x);
      string ts;

      getNV(__LINE__, "scf");
      x.scf = to!double(val);
      getNV(__LINE__, "that");
      if (val == "ok")
         x.that = readContainer(x);
      else
         x.that = null;
      x.afterDeserialize();
   }
}

