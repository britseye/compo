
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module deserialize;

import types;
import common;
import acomp;
import main;
import container;
import treeops;
import text;
import uspsib;
import serial;
import richtext;
import arrow;
import bevel;
import box;
import circle;
import connector;
import corner;
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

import std.stdio;
import std.conv;
import std.array;
import std.format;
import std.stream;
import std.string;
import std.conv;

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
      Transform tf;
      tf.hScale = to!double(a[0]);
      tf.vScale = to!double(a[1]);
      tf.hSkew = to!double(a[2]);
      tf.vSkew = to!double(a[3]);
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

   private ubyte[] readBytes(uint n)
   {
      ubyte[] a;
      a.length = n;
      if (n)
         si.readExact(&a[0], n);
      return a;
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
      for (int i = 0; i < sa.length; i += 2)
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

   this(AppWindow w)
   {
      aw = w;
   }

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
      int pos = fileName.lastIndexOf("/");
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
      string line = cast(string) si.readLine();    // skip the filename - debug only
      string sheetName = cast(string) si.readLine();
      aw.newTV(-1, sheetName);

      si.readLine();
      readItems();
   }

   void readItems()
   {
      try
      {
         getNV(__LINE__, "rootItems");
         int rootItems = to!int(val);
         int count = 0;

         for (int i = 0; i <rootItems; i++)
            readItem();

         aw.cto = aw.tm.root.children[0];
         aw.layout = aw.cto.layout;
         aw.layout.doref();
         aw.rp.add(aw.layout);
         aw.layout.show();
         aw.treeOps.select(aw.cto);

         aw.setFileName(fileName);
         aw.dirty = false;
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
      string sheetName = cast(string) si.readLine(); // skip the sheet name

      si.readLine();
      getNV(__LINE__, "rootItems");
      int rootItems = to!int(val);
      if (rootItems != 1)
      {
         aw.popupMsg("The COMPO file is empty", MessageType.ERROR);
         return;
      }

      Container that = readComposition(r);
      if (that !is null)
         r.that = that;
   }

   void readItem()
   {
      line = skip();
      if (line == "// Composition")
      {
         line = getLn();
         if (line != "type=1000")
            throw new DSException(__LINE__, line, "Incorrect type for Container");

         ACBase ctr = new Container(aw, aw.tm.root);
         aw.tm.root.children ~= ctr;
         aw.treeOps.notifyInsertion(ctr);

         basics(ctr);
         getNV(__LINE__, "baseColor");
         ctr.baseColor = makeColor(val);
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

   Container readContainer(Reference r)
   {
      line = skip();
      if (line != "// Composition")
      {
         throw new DSException(__LINE__, line,"Incorrect composition intro");
         return null;
      }
      line = getLn();
      if (line != "type=1000")
         throw new DSException(__LINE__, line, "Incorrect type for Container");

      Container ctr = new Container(aw, r);

      basics(ctr);
      getNV(__LINE__, "baseColor");
      ctr.baseColor = makeColor(val);
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

   Container readComposition(Reference r)
   {
      try
      {
         line = skip();
         if (line != "// Composition")
            throw new DSException(__LINE__, line, "COMPO file for reference use should contain a Composition as the first element");
         getLn();
         Container ctr = new Container(aw, r);

         basics(ctr);
         getNV(__LINE__, "baseColor");
         ctr.baseColor = makeColor(val);
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
      case AC_BOX:
         child = new Box(aw, parent);
         setupBox(cast(Box) child);
         break;
      case AC_CIRCLE:
         child = new Circle(aw, parent);
         setupCircle(cast(Circle) child);
         break;
      case AC_CONNECTOR:
         child = new Connector(aw, parent);
         setupConnector(cast(Connector) child);
         break;
      case AC_CORNER:
         child = new Corner(aw, parent);
         setupCorner(cast(Corner) child);
         break;
      case AC_CROSS:
         child = new Cross(aw, parent);
         setupCross(cast(Cross) child);
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
      case AC_MORPHTEXT:
         child = new MorphText(aw, parent, true);
         setupMorphText(cast(MorphText) child);
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
         (cast(PixelImage) child).doScaling();
         break;
      case AC_POLYGON:
         child = new Polygon(aw, parent);
         setupPolygon(cast(Polygon) child);
         break;
      case AC_POLYCURVE:
         child = new Polycurve(aw, parent);
         setupPolycurve(cast(Polycurve) child);
         break;
      case AC_RANDOM:
         child = new Random(aw, parent);
         setupRandom(cast(Random) child);
         break;
      case AC_RECT:
         child = new rect.Rect(aw, parent);
         setupRect(cast(rect.Rect) child);
         break;
      case AC_REGPOLYGON:
         child = new RegularPolygon(aw, parent);
         setupRegularPolygon(cast(RegularPolygon) child);
         break;
      case AC_RGRADIENT:
         child = new RGradient(aw, parent);
         setupRGradient(cast(RGradient) child);
         break;
      case AC_SEPARATOR:
         child = new Separator(aw, parent);
         setupSeparator(cast(Separator) child);
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
      x.dirty = true;
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
      x.dirty = true;
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
      x.dirty = true;
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
      x.alignment= to!int(val);;
      getNV(__LINE__, "serialized_length");
      int n = to!int(val);
      ubyte[] buffer;
      buffer.length = n;
      si.readExact(&buffer[0], n);
      x.deserialize(buffer);
      x.textBlock.setAlignment(cast(PangoAlignment) x.alignment);
      x.te.modifyFont(x.pfd);
      x.te.overrideColor(x.te.getStateFlags(), x.baseColor);
      x.dirty = true;
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
      getNV(__LINE__, "solid");
      x.solid = to!bool(val);
      getNV(__LINE__, "text_length");
      int n = to!int(val);
      string text = cast(string) readBytes(n);
      x.tb.setText(text);
      x.textBlock.setAlignment(cast(PangoAlignment) x.alignment);
      x.te.modifyFont(x.pfd);
      x.te.overrideColor(x.te.getStateFlags(), x.baseColor);
      x.dirty = true;
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
      getNV(__LINE__, "solid");
      x.solid = to!bool(val);
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
      x.changeMorph();
      x.createMorphDlg();
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
      getNV(__LINE__, "solid");
      x.solid = to!bool(val);
      getNV(__LINE__, "center");
      x.center = s2Coord(val, __LINE__);
      getNV(__LINE__, "oPath");
      x.oPath = s2Path(val, __LINE__);
      getNV(__LINE__, "tf");
      x.tf = makeTransform(val);
   }

   void setupBevel(Bevel x)
   {
      basics(x);

      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "bt");
      x.bt = to!double(val);
   }

   void setupBox(Box x)
   {
      basics(x);

      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "lineWidth");
      x.lineWidth = to!double(val);
      getNV(__LINE__, "topLeft");
      x.topLeft = s2Coord(val, __LINE__);
      getNV(__LINE__, "bottomRight");
      x.bottomRight = s2Coord(val, __LINE__);
      getNV(__LINE__, "les");
      x.les = to!bool(val);
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
      getNV(__LINE__, "tf");
      x.tf = makeTransform(val);
      getNV(__LINE__, "fill");
      x.fill = to!bool(val);
      getNV(__LINE__, "solid");
      x.solid = to!bool(val);
   }

   void setupConnector(Connector x)
   {
      basics(x);

      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "lineWidth");
      x.lineWidth = to!double(val);
      getNV(__LINE__, "start");
      x.start = s2Coord(val, __LINE__);
      getNV(__LINE__, "end");
      x.end = s2Coord(val, __LINE__);
      getNV(__LINE__, "les");
      x.les = to!bool(val);
   }

   void setupCorner(Corner x)
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
      getNV(__LINE__, "which");
      x.which = to!int(val);
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
      getNV(__LINE__, "solid");
      x.solid = to!bool(val);
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
   }

   void setupFader(Fader x)
   {
      basics(x);

      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "topLeft");
      x.rw = to!double(val);
      getNV(__LINE__, "bottomRight");
      x.rh = to!double(val);
      getNV(__LINE__, "opacity");
      x.opacity = to!double(val);
      getNV(__LINE__, "pin");
      x.pin = to!bool(val);
      getNV(__LINE__, "outline");
      x.outline = to!bool(val);
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
      getNV(__LINE__, "tf");
      x.tf = makeTransform(val);
      getNV(__LINE__, "lineWidth");
      x.lineWidth = to!double(val);
      getNV(__LINE__, "xform");
      x.xform = to!int(val);
      getNV(__LINE__, "fill");
      x.fill = to!bool(val);
      getNV(__LINE__, "solid");
      x.solid = to!bool(val);
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
   }

   void setupLGradient(LGradient x)
   {
      basics(x);
      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "rw");
      x.rw = to!double(val);
      getNV(__LINE__, "rh");
      x.rh = to!double(val);
      getNV(__LINE__, "maxOpacity");
      x.maxOpacity = to!double(val);
      getNV(__LINE__, "gType");
      x.gType = to!int(val);
      getNV(__LINE__, "nStops");
      x.nStops = to!int(val);
      getNV(__LINE__, "outline");
      x.outline = to!bool(val);
      getNV(__LINE__, "pin");
      x.pin = to!bool(val);
      getNV(__LINE__, "revfade");
      x.revfade = to!bool(val);
      getNV(__LINE__, "orient");
      x.orient = to!bool(val);
   }

   void setupPattern(Pattern x)
   {
      basics(x);

      getNV(__LINE__, "baseColor");
      x.baseColor = makeColor(val);
      getNV(__LINE__, "rows");
      x.rows = to!int(val);
      getNV(__LINE__, "cols");
      x.cols = to!int(val);
      getNV(__LINE__, "unit");
      x.unit = to!double(val);
      getNV(__LINE__, "choice");
      x.choice = to!int(val);;
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
      getNV(__LINE__, "cw");
      x.cw = to!int(val);
      getNV(__LINE__, "ch");
      x.ch = to!int(val);
      getNV(__LINE__, "useFile");
      x.useFile = to!bool(val);
      getNV(__LINE__, "data_length");
      int n = to!int(val);
      if (n)
      {
         ubyte[] buffer;
         buffer.length = n;
         si.readExact(&buffer[0], n);
         MemoryInputStream ms = new MemoryInputStream(&buffer[0], n, null);
         x.pxb = new Pixbuf(ms, null);
      }
      else
      {
         x.getPxb();
      }
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
      int n = to!int(val);
      if (n)
      {
         x.svgData.length = n;
         si.readExact(x.svgData.ptr, n);
         string tf = "__temp__"~x.fileName;
         std.file.write(tf, x.svgData);
         x.svgr = new SVGRenderer(tf);
         tf ~="\0";
         remove(tf.ptr);
      }
      else
         x.svgr = new SVGRenderer(x.fileName);
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
      getNV(__LINE__, "fill");
      x.fill = to!bool(val);
      getNV(__LINE__, "solid");
      x.solid = to!bool(val);
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

      x.constructing = false;
      x.dirty = true;
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
      getNV(__LINE__, "fill");
      x.fill = to!bool(val);
      getNV(__LINE__, "solid");
      x.solid = to!bool(val);
      getNV(__LINE__, "center");
      x.center = s2Coord(val, __LINE__);
      getNV(__LINE__, "oPath");
      x.oPath = s2Path(val, __LINE__);
      getNV(__LINE__, "tf");
      x.tf = makeTransform(val);
      x.constructing = false;
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
      x.lower = to!int(val);
      getNV(__LINE__, "upper");
      x.upper = to!int(val);
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
   }

   void setupRect(rect.Rect x)
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
      getNV(__LINE__, "rounded");
      x.rounded = to!bool(val);
      getNV(__LINE__, "fill");
      x.fill = to!bool(val);
      getNV(__LINE__, "solid");
      x.solid = to!bool(val);
      getNV(__LINE__, "topLeft");
      x.topLeft = s2Coord(val, __LINE__);
      getNV(__LINE__, "bottomRight");
      x.bottomRight =  s2Coord(val, __LINE__);
      getNV(__LINE__, "rr");
      x.rr =  to!double(val);
      getNV(__LINE__, "tf");
      x.tf = makeTransform(val);
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
      getNV(__LINE__, "solid");
      x.solid = to!bool(val);
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
   }
}

