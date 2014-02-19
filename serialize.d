
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module serialize;

import std.stdio;
import std.conv;
import std.stream;
import std.array;
import std.format;
import std.uuid;

import about;
import common;
import types;
import acomp;
import container;
import mainwin;
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
import polycurve;
import drawing;
import pointset;
import strokeset;
import regpc;
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

import gtk.FileChooserDialog;
import gtk.FileFilter;

class Serializer
{
   AppWindow aw;
   ACBase root;
   //ACBase current;
   OutputStream os;

   private string coord2S(Coord c)
   {
      string s = to!string(c.x) ~ "," ~ to!string(c.y);
      return s;
   }

   private string path2S(Coord[] ca)
   {
      bool first = true;
      string s;
      foreach (Coord c; ca)
      {
         if (!first)
            s ~= ",";
         first = false;
         s ~= to!string(c.x) ~ "," ~ to!string(c.y);
      }
      return s;
   }

   private string pcPath2S(PathItem[] pa)
   {
      bool first = true;
      string s;
      foreach (PathItem pi; pa)
      {
         if (!first)
            s ~= "\n";
         first = false;
         s ~= to!string(pi.type) ~ ";" ~ coord2S(pi.start) ~ ";" ~ coord2S(pi.cp1) ~ ";" ~ coord2S(pi.cp2) ~ ";" ~
                 coord2S(pi.end) ~ ";" ~ coord2S(pi.cog);
      }
      return s;
   }

   private string partColorArray2S(PartColor[] a)
   {
      string s="";
      foreach (int i, PartColor c; a)
      {
         if (i > 0)
            s ~= ",";
         s ~= to!string(c.r)~";"~to!string(c.g)~";"~to!string(c.b)~";"~to!string(c.a);
      }
      return s;
   }

   private string transform2S(Transform tf)
   {
      string s = to!string(tf.hScale);
      s ~= ","~to!string(tf.vScale);
      s ~= ","~to!string(tf.hSkew);
      s ~= ","~to!string(tf.vSkew);
      s ~= ","~to!string(tf.hFlip);
      s ~= ","~to!string(tf.vFlip);
      s ~= ","~to!string(tf.ra);
      return s;
   }

   this(AppWindow w)
   {
      aw = w;
      root = w.tm.root;
   }

   void refresh(AppWindow w)
   {
      root = w.tm.root;
   }

   bool serialize(bool saveas)
   {
      string fileName = aw.cfn;
      string folder;
      if (fileName is null || saveas)
      {
         FileChooserDialog fcd = new FileChooserDialog("Save composition", aw, FileChooserAction.SAVE);
         FileFilter filter = new FileFilter();
         filter.setName("COMPO files");
         filter.addPattern("*.compo");
         fcd.addFilter(filter);
         filter = new FileFilter();
         filter.setName("All files");
         filter.addPattern("*.*");
         fcd.addFilter(filter);
         if (aw.cfn !is null)
            fcd.setCurrentName(aw.cfn);
         else
            fcd.setCurrentName(".compo");
         if (aw.recent.lastSaveFolder)
            fcd.setCurrentFolder(aw.recent.lastSaveFolder);
         else
            fcd.setCurrentFolder(aw.config.defaultFolder);
         fcd.setDoOverwriteConfirmation (1);
         int response = fcd.run();
         if (response != ResponseType.OK)
         {
            fcd.destroy();
            return false;
         }
         fileName = fcd.getFilename();
         folder = fcd.getCurrentFolder();
         fcd.destroy();
      }
      aw.recent.lastSaveFolder = folder;
      aw.adjustRecent(fileName);
      os = new std.stream.File(fileName, FileMode.OutNew);
      // remember file name
      os.writeString(fileName ~ "\n");
      os.writeString("version="~to!string(versionMajor())~"."~to!string(versionMinor())~"\n");
      // save sheet type
      string mfr = aw.currentSheet.mfr;
      string id;
      if (mfr == "COMPO")
      {
         id =to!string(aw.scrapGrid.w)~","~to!string(aw.scrapGrid.h);
      }
      else
         id = aw.currentSheet.id;
      os.writeString(mfr~": "~id~"\n\n");
      os.writeString("dWidth=" ~ to!string(root.children[0].width) ~ "\n");
      os.writeString("dHeight=" ~ to!string(root.children[0].height) ~ "\n");
      os.writeString("rootItems=" ~ to!string(root.children.length) ~ "\n\n");

      foreach (ACBase acb; root.children)
      {
         switch (acb.type)
         {
         case AC_CONTAINER:
            serializeContainer(acb);
            break;
         default:
            serializeType(acb);
            break;
         }
      }
      os.close();
      aw.setFileName(fileName);

      return true;
   }

   string basics(ACBase acb)
   {
      string s = "// " ~ ACTypeNames(acb.type) ~ "\n";
      s ~= "type=" ~ to!string(cast(int) acb.type) ~ "\n";
      s ~= "name=" ~ acb.name ~ "\n";
      s ~= "uuid=" ~ acb.uuid.toString() ~ "\n";
      s ~= "hOff=" ~ to!string(acb.hOff) ~ "\n";
      s ~= "vOff=" ~ to!string(acb.vOff) ~ "\n";
      return s;
   }

   void serializeContainer(ACBase acb)
   {
      Container o = cast(Container) acb;
      string s = basics(acb);
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "nextChildId=" ~ to!string(o.nextChildId) ~ "\n";
      s ~= "cc=" ~ to!string(o.children.length) ~ "\n\n";
      os.writeString(s);
      foreach (ACBase x; o.children)
      {
         serializeType(x);
      }
   }

   void serializeType(ACBase acb)
   {
      switch (acb.type)
      {
      case AC_TEXT:
         return serializeText(acb);
      case AC_USPS:
         return serializeUSPS(acb);
      case AC_SERIAL:
         return serializeSerial(acb);
      case AC_RICHTEXT:
         return serializeRichText(acb);
      case AC_ARROW:
         return serializeArrow(acb);
      case AC_BEVEL:
         return serializeBevel(acb);
      case AC_BRUSHDABS:
         return serializeBrushDabs(acb);
      case AC_CIRCLE:
         return serializeCircle(acb);
      case AC_CORNERS:
         return serializeCorners(acb);
      case AC_CRESCENT:
         return serializeCrescent(acb);
      case AC_CROSS:
         return serializeCross(acb);
      case AC_FANCYTEXT:
         return serializeFancyText(acb);
      case AC_FADER:
         return serializeFader(acb);
      case AC_HEART:
         return serializeHeart(acb);
      case AC_LINE:
         return serializeLine(acb);
      case AC_LGRADIENT:
         return serializeLGradient(acb);
      case AC_MESH:
         return serializeMesh(acb);
      case AC_MOON:
         return serializeMoon(acb);
      case AC_NOISE:
         return serializeNoise(acb);
      case AC_MORPHTEXT:
         return serializeMorphText(acb);
      case AC_PARTITION:
         return serializePartition(acb);
      case AC_PATTERN:
         return serializePattern(acb);
      case AC_PIXBUF:
         return serializePixelImage(acb);
      case AC_SVGIMAGE:
         return serializeSVGImage(acb);
      case AC_POINTSET:
         return serializePointSet(acb);
      case AC_POLYGON:
         return serializePolygon(acb);
      case AC_POLYCURVE:
         return serializePolycurve(acb);
      case AC_RANDOM:
         return serializeRandom(acb);
      case AC_RECT:
         return serializeRectangle(acb);
      case AC_RGRADIENT:
         return serializeRGradient(acb);
      case AC_REGPOLYGON:
         return serializeRegularPolygon(acb);
      case AC_REGPOLYCURVE:
         return serializeRegularPolycurve(acb);
      case AC_SEPARATOR:
         return serializeSeparator(acb);
      case AC_SHIELD:
         return serializeShield(acb);
      case AC_STROKESET:
         return serializeStrokeSet(acb);
      case AC_TILINGS:
         return serializeTilings(acb);
      case AC_TEARDROP:
         return serializeTeardrop(acb);
      case AC_TRIANGLE:
         return serializeTriangle(acb);
      case AC_YINYANG:
         return serializeYinYang(acb);
      case AC_REFERENCE:
         return serializeReference(acb);
      case AC_DRAWING:
         return serializeDrawing(acb);
      default:
         assert(false);
      }
   }

   string formatParamBlock(ParamBlock* pb)
   {
      scope auto w = appender!string();
      bool first = true;
      foreach (Coord c; pb.cpa)
      {
         if (!first)
            w.put(";");
         formattedWrite(w, "%s,%s", c.x, c.y);
         first = false;
      }
      w.put("|");
      first = true;
      foreach (double d; pb.dpa)
      {
         if (!first)
            w.put(",");
         formattedWrite(w, "%s", d);
         first = false;
      }
      w.put("|");
      first = true;
      foreach (int i; pb.ipa)
      {
         if (!first)
            w.put(",");
         formattedWrite(w, "%s", i);
         first = false;
      }
      w.put("\n");
      return w.data;
   }

   void serializeText(ACBase acb)
   {
      PlainText o = cast(PlainText) acb;
      string s = basics(acb);
      s ~= "editMode=" ~ to!string(o.editMode) ~ "\n";
      s ~= "pfd=" ~ o.pfd.toString() ~ "\n";
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "alignment=" ~ to!string(o.alignment) ~ "\n";
      s ~= "centerText=" ~ to!string(o.centerText) ~ "\n";
      s ~= "shrink2Fit=" ~ to!string(o.shrink2Fit) ~ "\n";
      string t = o.tb.getText();
      s ~= "text_length=" ~ to!string(t.length) ~ "\n";
      s ~= t;
      s ~= "\n\n";
      os.writeString(s);
   }

   void serializeSerial(ACBase acb)
   {
      Serial o = cast(Serial) acb;
      string s = basics(acb);
      s ~= "editMode=" ~ to!string(o.editMode) ~ "\n";
      s ~= "pfd=" ~ o.pfd.toString() ~ "\n";
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "number=" ~ to!string(o.number) ~ "\n";
      s ~= "padLength=" ~ to!string(o.padLength) ~ "\n";
      string t = o.tb.getText();
      s ~= "text_length=" ~ to!string(t.length) ~ "\n";
      s ~= t;
      s ~= "\n\n";
      os.writeString(s);
   }

   void serializeUSPS(ACBase acb)
   {
      USPS o = cast(USPS) acb;
      string s = basics(acb);
      s ~= "editMode=" ~ to!string(o.editMode) ~ "\n";
      s ~= "pfd=" ~ o.pfd.toString() ~ "\n";
      s ~= "shrink2Fit=" ~ to!string(o.shrink2Fit) ~ "\n";
      s ~= "showData=" ~ to!string(o.showData) ~ "\n";
      string t = o.tb.getText();
      s ~= "text_length=" ~ to!string(t.length) ~ "\n";
      s ~= t;
      s ~= "\n\n";
      os.writeString(s);
   }

   void serializeRichText(ACBase acb)
   {
      RichText o = cast(RichText) acb;
      string s = basics(acb);
      s ~= "editMode=" ~ to!string(o.editMode) ~ "\n";
      s ~= "pfd=" ~ o.pfd.toString() ~ "\n";
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "alignment=" ~ to!string(o.alignment) ~ "\n";
      ubyte[] buffer = o.serialize();
      s ~= "serialized_length=" ~ to!string(buffer.length) ~ "\n";
      os.writeString(s);
      os.writeExact(&buffer[0], buffer.length);
      s = "\n";
      os.writeString(s);
   }

   void serializeFancyText(ACBase acb)
   {
      FancyText o = cast(FancyText) acb;
      string s = basics(acb);
      s ~= "editMode=" ~ to!string(o.editMode) ~ "\n";
      s ~= "pfd=" ~ o.pfd.toString() ~ "\n";
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "altColor=" ~ o.colorString(true) ~ "\n";
      s ~= "alignment=" ~ to!string(o.alignment) ~ "\n";
      s ~= "angle=" ~ to!string(o.angle) ~ "\n";
      s ~= "center=" ~ coord2S(o.center) ~ "\n";
      s ~= "orientation=" ~ to!string(o.orientation) ~ "\n";
      s ~= "olt=" ~ to!string(o.olt) ~ "\n";
      s ~= "fill=" ~ to!string(o.fill) ~ "\n";
      s ~= "outline=" ~ to!string(o.outline) ~"\n";
      s ~= "fillFromPattern=" ~ to!string(o.fillFromPattern) ~ "\n";
      s ~= "fillUid=" ~ o.fillUid.toString() ~ "\n";
      string t = o.tb.getText();
      s ~= "text_length=" ~ to!string(t.length) ~ "\n";
      s ~= t;
      s ~= "\n\n";
      os.writeString(s);
   }

   void serializeMorphText(ACBase acb)
   {
      MorphText o = cast(MorphText) acb;
      o.updateParams();
      string s = basics(acb);
      s ~= "editMode=" ~ to!string(o.editMode) ~ "\n";
      s ~= "pfd=" ~ o.pfd.toString() ~ "\n";
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "altColor=" ~ o.colorString(true) ~ "\n";
      s ~= "fill=" ~ to!string(o.fill) ~ "\n";
      s ~= "fillFromPattern=" ~ to!string(o.fillFromPattern) ~ "\n";
      s ~= "fillUid=" ~ o.fillUid.toString() ~ "\n";
      s ~= "outline=" ~ to!string(o.outline) ~"\n";
      s ~= "olt=" ~ to!string(o.olt) ~ "\n";
      s ~= "tf=" ~ transform2S(o.tf) ~ "\n";
      s ~= "cm=" ~ to!string(o.cm) ~ "\n";
      s ~= "mp=" ~ formatParamBlock(&o.mp);
      string t = o.tb.getText();
      s ~= "text_length=" ~ to!string(t.length) ~ "\n";
      s ~= t;
      s ~= "\n\n";
      os.writeString(s);
   }

   void serializeArrow(ACBase acb)
   {
      Arrow o = cast(Arrow) acb;
      string s = basics(acb);
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "altColor=" ~ o.colorString(true) ~ "\n";
      s ~= "lineWidth=" ~ to!string(o.lineWidth) ~ "\n";
      s ~= "les=" ~ to!string(o.les) ~ "\n";
      s ~= "hw=" ~ to!string(o.hw) ~ "\n";
      s ~= "fill=" ~ to!string(o.fill) ~ "\n";
      s ~= "outline=" ~ to!string(o.outline) ~"\n";
      s ~= "fillFromPattern=" ~ to!string(o.fillFromPattern) ~ "\n";
      s ~= "fillUid=" ~ o.fillUid.toString() ~ "\n";
      s ~= "center=" ~ coord2S(o.center) ~ "\n";
      s ~= "oPath=" ~ path2S(o.oPath) ~ "\n";
      s ~= "tf=" ~ transform2S(o.tf) ~ "\n";
      s ~= "\n";
      os.writeString(s);
   }

   void serializeBevel(ACBase acb)
   {
      Bevel o = cast(Bevel) acb;
      string s = basics(acb);
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "bt=" ~ to!string(o.bt) ~ "\n";
      s ~= "\n";
      os.writeString(s);
   }

   void serializeBrushDabs(ACBase acb)
   {
      BrushDabs o = cast(BrushDabs) acb;
      string s = basics(acb);
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "w=" ~ to!string(o.w) ~ "\n";
      s ~= "tcp=" ~ to!string(o.tcp) ~ "\n";
      s ~= "bcp=" ~ to!string(o.bcp) ~ "\n";
      s ~= "nDabs=" ~ to!string(o.nDabs) ~ "\n";
      s ~= "shapeSeed=" ~ to!string(o.shapeSeed) ~ "\n";
      s ~= "colorSeed=" ~ to!string(o.shapeSeed) ~ "\n";
      s ~= "angle=" ~ to!string(o.angle) ~ "\n";
      s ~= "pointed=" ~ to!string(o.pointed) ~ "\n";
      s ~= "shade=" ~ to!string(o.shade) ~ "\n";
      s ~= "pca=" ~ partColorArray2S(o.pca) ~ "\n";
      s ~= "\n";
      os.writeString(s);
   }

   void serializeCircle(ACBase acb)
   {
      Circle o = cast(Circle) acb;
      string s = basics(acb);
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "altColor=" ~ o.colorString(true) ~ "\n";
      s ~= "lineWidth=" ~ to!string(o.lineWidth) ~ "\n";
      s ~= "radius=" ~ to!string(o.radius) ~"\n";
      s ~= "tf=" ~ transform2S(o.tf) ~ "\n";
      s ~= "fill=" ~ to!string(o.fill) ~ "\n";
      s ~= "outline=" ~ to!string(o.outline) ~"\n";
      s ~= "fillFromPattern=" ~ to!string(o.fillFromPattern) ~ "\n";
      s ~= "fillUid=" ~ o.fillUid.toString() ~ "\n";
      s ~= "\n";
      os.writeString(s);
   }

   void serializeCorners(ACBase acb)
   {
      Corners o = cast(Corners) acb;
      string s = basics(acb);
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "lineWidth=" ~ to!string(o.lineWidth) ~ "\n";
      s ~= "les=" ~ to!string(o.les) ~ "\n";
      s ~= "cw=" ~ to!string(o.cw) ~ "\n";
      s ~= "ch=" ~ to!string(o.ch) ~ "\n";
      s ~= "inset=" ~ to!string(o.inset) ~ "\n";
      s ~= "relto=" ~ to!string(o.relto) ~ "\n";
      s ~= "tl=" ~ to!string(o.tl) ~ "\n";
      s ~= "tr=" ~ to!string(o.tr) ~ "\n";
      s ~= "bl=" ~ to!string(o.bl) ~ "\n";
      s ~= "br=" ~ to!string(o.br) ~ "\n";
      s ~= "\n";
      os.writeString(s);
   }

   void serializeCrescent(ACBase acb)
   {
      Crescent o = cast(Crescent) acb;
      string s = basics(acb);
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "altColor=" ~ o.colorString(true) ~ "\n";
      s ~= "lineWidth=" ~ to!string(o.lineWidth) ~ "\n";
      s ~= "les=" ~ to!string(o.les) ~ "\n";
      s ~= "fill=" ~ to!string(o.fill) ~ "\n";
      s ~= "outline=" ~ to!string(o.outline) ~"\n";
      s ~= "fillFromPattern=" ~ to!string(o.fillFromPattern) ~ "\n";
      s ~= "fillUid=" ~ o.fillUid.toString() ~ "\n";
      s ~= "center=" ~ coord2S(o.center) ~ "\n";
      s ~= "r0=" ~ to!string(o.r0) ~ "\n";
      s ~= "r1=" ~ to!string(o.r1) ~ "\n";
      s ~= "d=" ~ to!string(o.d) ~ "\n";
      s ~= "guidelines=" ~ to!string(o.guidelines) ~ "\n";
      s ~= "tf=" ~ transform2S(o.tf) ~ "\n";
      s ~= "\n";
      os.writeString(s);
   }

   void serializeCross(ACBase acb)
   {
      Cross o = cast(Cross) acb;
      string s = basics(acb);
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "altColor=" ~ o.colorString(true) ~ "\n";
      s ~= "lineWidth=" ~ to!string(o.lineWidth) ~ "\n";
      s ~= "les=" ~ to!string(o.les) ~ "\n";
      s ~= "fill=" ~ to!string(o.fill) ~ "\n";
      s ~= "outline=" ~ to!string(o.outline) ~"\n";
      s ~= "fillFromPattern=" ~ to!string(o.fillFromPattern) ~ "\n";
      s ~= "fillUid=" ~ o.fillUid.toString() ~ "\n";
      s ~= "center=" ~ coord2S(o.center) ~ "\n";
      s ~= "oPath=" ~ path2S(o.oPath) ~ "\n";
      s ~= "tf=" ~ transform2S(o.tf) ~ "\n";
      s ~= "ar=" ~ to!string(o.ar) ~ "\n";
      s ~= "cbOff=" ~ to!string(o.cbOff) ~ "\n";
      s ~= "urW=" ~ to!string(o.urW) ~ "\n";
      s ~= "cbW=" ~ to!string(o.cbW) ~ "\n";
      s ~= "\n";
      os.writeString(s);
   }

   void serializeFader(ACBase acb)
   {
      Fader o = cast(Fader) acb;
      string s = basics(acb);
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "rw=" ~to!string(o.rw) ~ "\n";
      s ~= "rh=" ~ to!string(o.rh) ~ "\n";
      s ~= "opacity=" ~ to!string(o.opacity) ~ "\n";
      s ~= "pin=" ~ to!string(o.pin) ~ "\n";
      s ~= "outline=" ~ to!string(o.outline) ~ "\n";
      s ~= "\n";
      os.writeString(s);
   }

   void serializeHeart(ACBase acb)
   {
      Heart o = cast(Heart) acb;
      string s = basics(acb);
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "altColor=" ~ o.colorString(true) ~ "\n";
      s ~= "unit=" ~ to!string(o.unit) ~ "\n";
      s ~= "lineWidth=" ~ to!string(o.lineWidth) ~ "\n";
      s ~= "xform=" ~ to!string(o.xform) ~ "\n";
      s ~= "fill=" ~ to!string(o.fill) ~ "\n";
      s ~= "outline=" ~ to!string(o.outline) ~ "\n";
      s ~= "fillFromPattern=" ~ to!string(o.fillFromPattern) ~ "\n";
      s ~= "fillUid=" ~ o.fillUid.toString() ~ "\n";
      s ~= "tf=" ~ transform2S(o.tf) ~ "\n";
      s ~= "\n";
      os.writeString(s);
   }

   void serializeLine(ACBase acb)
   {
      Line o = cast(Line) acb;
      string s = basics(acb);
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "lineWidth=" ~ to!string(o.lineWidth) ~ "\n";
      s ~= "les=" ~ to!string(o.les) ~ "\n";
      s ~= "oPath=" ~ path2S(o.oPath) ~ "\n";
      s ~= "tf=" ~ transform2S(o.tf) ~ "\n";
      s ~= "\n";
      os.writeString(s);
   }

   void serializeLGradient(ACBase acb)
   {
      LGradient o = cast(LGradient) acb;
      string s = basics(acb);
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "fw=" ~ to!string(o.fw) ~ "\n";
      s ~= "fp=" ~ to!string(o.fp) ~ "\n";
      s ~= "angle=" ~ to!string(o.angle) ~ "\n";
      s ~= "maxOpacity=" ~ to!string(o.maxOpacity) ~ "\n";
      s ~= "gType=" ~ to!string(o.gType) ~ "\n";
      s ~= "nStops=" ~ to!string(o.nStops) ~ "\n";
      s ~= "revfade=" ~ to!string(o.revfade) ~ "\n";
      s ~= "orient=" ~ to!string(o.orient) ~ "\n";
      s ~= "\n";
      os.writeString(s);
   }

   void serializeMesh(ACBase acb)
   {
      Mesh o = cast(Mesh) acb;
      string s = basics(acb);
      s ~= "pca=" ~ partColorArray2S(o.pca) ~ "\n";
      s ~= "diagonal=" ~ to!string(o.diagonal) ~ "\n";
      s ~= "pattern=" ~ to!string(o.pattern) ~ "\n";
      s ~= "instanceSeed=" ~ to!string(o.instanceSeed) ~ "\n";
      s ~= "tf=" ~ transform2S(o.tf) ~ "\n";
      s ~= "\n";
      os.writeString(s);
   }

   void serializeMoon(ACBase acb)
   {
      Moon o = cast(Moon) acb;
      string s = basics(acb);
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "altColor=" ~ o.colorString(true) ~ "\n";
      s ~= "lineWidth=" ~ to!string(o.lineWidth) ~ "\n";
      s ~= "radius=" ~ to!string(o.radius) ~"\n";
      s ~= "tf=" ~ transform2S(o.tf) ~ "\n";
      s ~= "fill=" ~ to!string(o.fill) ~ "\n";
      s ~= "outline=" ~ to!string(o.outline) ~"\n";
      s ~= "fillFromPattern=" ~ to!string(o.fillFromPattern) ~ "\n";
      s ~= "fillUid=" ~ o.fillUid.toString() ~ "\n";
      s ~= "day=" ~ to!string(o.day) ~"\n";
      s ~= "\n";
      os.writeString(s);
   }

   void serializeNoise(ACBase acb)
   {
      Noise o = cast(Noise) acb;
      string s = basics(acb);
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "lineWidth=" ~ to!string(o.lineWidth) ~ "\n";
      s ~= "level=" ~ to!string(o.level) ~"\n";
      s ~= "dots=" ~ to!string(o.dots) ~ "\n";
      s ~= "instanceSeed=" ~ to!string(o.instanceSeed) ~ "\n";
      s ~= "\n";
      os.writeString(s);
   }

   void serializePartition(ACBase acb)
   {
      Partition o = cast(Partition) acb;
      string s = basics(acb);
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "lineWidth=" ~ to!string(o.lineWidth) ~ "\n";
      s ~= "x=" ~ to!string(o.x) ~ "\n";
      s ~= "y=" ~ to!string(o.y) ~ "\n";
      s ~= "choice=" ~ to!string(o.choice) ~ "\n";
      s ~= "outline=" ~ to!string(o.outline) ~ "\n";
      s ~= "vertical=" ~ to!string(o.vertical) ~ "\n";
      s ~= "\n\n";
      os.writeString(s);
   }

   void serializePattern(ACBase acb)
   {
      Pattern o = cast(Pattern) acb;
      string s = basics(acb);
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "lineWidth=" ~ to!string(o.lineWidth) ~ "\n";
      s ~= "rows=" ~ to!string(o.rows) ~ "\n";
      s ~= "cols=" ~ to!string(o.cols) ~ "\n";
      s ~= "unit=" ~ to!string(o.unit) ~ "\n";
      s ~= "choice=" ~ to!string(o.choice) ~ "\n";
      s ~= "tf=" ~ transform2S(o.tf) ~ "\n";
      s ~= "\n\n";
      os.writeString(s);
   }

   void serializePixelImage(ACBase acb)
   {
      PixelImage o = cast(PixelImage) acb;
      string s = basics(acb);
      s ~= "fileName=" ~ o.fileName ~ "\n";
      s ~= "scaleType=" ~ to!string(o.scaleType) ~ "\n";
      s ~= "sadj=" ~ to!string(o.sadj) ~ "\n";
      s ~= "scale4Printer=false" ~ "\n";   // We have already scaled to printer res first time around - no need to do it again
      s ~= "useFile=" ~ to!string(o.useFile) ~ "\n";
      if (o.useFile)
      {
         s ~= "data_length=0\n\n";
         os.writeString(s);
      }
      else
      {
         ubyte[] buf;
         string[] dummy;
         if (o.scale4Printer)
            o.spxb.saveToBuffer(buf, "png", dummy, dummy);
         else
            o.pxb.saveToBuffer(buf, "png", dummy, dummy);
         s ~= "data_length=" ~ to!string(buf.length) ~ "\n";
         os.writeString(s);
         os.writeExact(buf.ptr, buf.length);
         s = "\n\n";
         os.writeString(s);
      }
   }

   void serializeSVGImage(ACBase acb)
   {
      SVGImage o = cast(SVGImage) acb;
      string s = basics(acb);
      s ~= "fileName=" ~ o.fileName ~ "\n";
      s ~= "scaleType=" ~ to!string(o.scaleType) ~ "\n";
      s ~= "scaleX=" ~ to!string(o.scaleX) ~ "\n";
      s ~= "useFile=" ~ to!string(o.useFile) ~ "\n";
      if (o.useFile)
      {
         s ~= "data_length=0\n\n";
         os.writeString(s);
      }
      else
      {
         s ~= "data_length=" ~ to!string(o.svgData.length) ~ "\n";
         os.writeString(s);
         os.writeExact(o.svgData.ptr, o.svgData.length);
         s = "\n\n";
         os.writeString(s);
      }
   }

   void serializePointSet(ACBase acb)
   {
      PointSet o = cast(PointSet) acb;
      string s = basics(acb);
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "lineWidth=" ~ to!string(o.lineWidth) ~ "\n";
      s ~= "center=" ~ coord2S(o.center) ~ "\n";
      s ~= "oPath=" ~ path2S(o.oPath) ~ "\n";
      s ~= "tf=" ~ transform2S(o.tf) ~ "\n";
      s ~= "\n";
      os.writeString(s);
   }

   void serializePolygon(ACBase acb)
   {
      Polygon o = cast(Polygon) acb;
      string s = basics(acb);
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "altColor=" ~ o.colorString(true) ~ "\n";
      s ~= "lineWidth=" ~ to!string(o.lineWidth) ~ "\n";
      s ~= "les=" ~ to!string(o.les) ~ "\n";
      s ~= "fill=" ~ to!string(o.fill) ~ "\n";
      s ~= "outline=" ~ to!string(o.outline) ~"\n";
      s ~= "fillFromPattern=" ~ to!string(o.fillFromPattern) ~ "\n";
      s ~= "fillUid=" ~ o.fillUid.toString() ~ "\n";
      s ~= "center=" ~ coord2S(o.center) ~ "\n";
      s ~= "oPath=" ~ path2S(o.oPath) ~ "\n";
      s ~= "tf=" ~ transform2S(o.tf) ~ "\n";
      s ~= "\n";
      os.writeString(s);
   }

   void serializePolycurve(ACBase acb)
   {
      Polycurve o = cast(Polycurve) acb;
      string s = basics(acb);
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "altColor=" ~ o.colorString(true) ~ "\n";
      s ~= "lineWidth=" ~ to!string(o.lineWidth) ~ "\n";
      s ~= "les=" ~ to!string(o.les) ~ "\n";
      s ~= "fill=" ~ to!string(o.fill) ~ "\n";
      s ~= "outline=" ~ to!string(o.outline) ~"\n";
      s ~= "fillFromPattern=" ~ to!string(o.fillFromPattern) ~ "\n";
      s ~= "fillUid=" ~ o.fillUid.toString() ~ "\n";
      s ~= "center=" ~ coord2S(o.center) ~ "\n";
      s ~= "activeCoords=" ~ to!string(o.activeCoords) ~ "\n";
      s ~= "current=" ~ to!string(o.current) ~ "\n";
      s ~= "tf=" ~ transform2S(o.tf) ~ "\n";
      string ps = pcPath2S(o.pcPath);
      s ~= "data_length=" ~ to!string(ps.length) ~ "\n";
      os.writeString(s);
      os.writeExact(ps.ptr, ps.length);
      s = "\n\n";
      os.writeString(s);
   }

   void serializeStrokeSet(ACBase acb)
   {
      StrokeSet o = cast(StrokeSet) acb;
      string s = basics(acb);
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "altColor=" ~ o.colorString(true) ~ "\n";
      s ~= "lineWidth=" ~ to!string(o.lineWidth) ~ "\n";
      s ~= "les=" ~ to!string(o.les) ~ "\n";
      s ~= "fill=" ~ to!string(o.fill) ~ "\n";
      s ~= "outline=" ~ to!string(o.outline) ~"\n";
      s ~= "center=" ~ coord2S(o.center) ~ "\n";
      s ~= "activeCoords=" ~ to!string(o.activeCoords) ~ "\n";
      s ~= "current=" ~ to!string(o.current) ~ "\n";
      s ~= "tf=" ~ transform2S(o.tf) ~ "\n";
      string ps = pcPath2S(o.pcPath);
      s ~= "data_length=" ~ to!string(ps.length) ~ "\n";
      os.writeString(s);
      os.writeExact(ps.ptr, ps.length);
      s = "\n\n";
      os.writeString(s);
   }

   void serializeRandom(ACBase acb)
   {
      Random o = cast(Random) acb;
      string s = basics(acb);
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "altColor=" ~ o.colorString(true) ~ "\n";
      s ~= "lineWidth=" ~ to!string(o.lineWidth) ~ "\n";
      s ~= "count=" ~ to!string(o.count) ~"\n";
      s ~= "element=" ~ to!string(o.element) ~"\n";
      s ~= "lower=" ~ to!string(o.lower) ~"\n";
      s ~= "upper=" ~ to!string(o.upper) ~"\n";
      s ~= "printRandom=" ~ to!string(o.printRandom) ~"\n";
      foreach (ShapeInfo t; o.si)
      {
         string sis = to!string(t.c1)~"|"~to!string(t.c2)~"|"~to!string(t.c3)~"|"~to!string(t.c4)~"|"~to!string(t.c5)~"|"~to!string(t.c6)~"\n";
         s ~= sis;
      }
      s ~= "\n";
      os.writeString(s);
   }

   void serializeRectangle(ACBase acb)
   {
      rect.Rectangle o = cast(rect.Rectangle) acb;
      string s = basics(acb);
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "altColor=" ~ o.colorString(true) ~ "\n";
      s ~= "lineWidth=" ~ to!string(o.lineWidth) ~ "\n";
      s ~= "les=" ~ to!string(o.les) ~ "\n";
      s ~= "square=" ~ to!string(o.square) ~ "\n";
      s ~= "rounded=" ~ to!string(o.rounded) ~ "\n";
      s ~= "fill=" ~ to!string(o.fill) ~ "\n";
      s ~= "outline=" ~ to!string(o.outline) ~"\n";
      s ~= "fillFromPattern=" ~ to!string(o.fillFromPattern) ~ "\n";
      s ~= "fillUid=" ~ o.fillUid.toString() ~ "\n";
      s ~= "ar=" ~ to!string(o.ar) ~ "\n";
      s ~= "rr=" ~ to!string(o.rr) ~ "\n";
      s ~= "tf=" ~ transform2S(o.tf) ~ "\n";
      s ~= "\n";
      os.writeString(s);
   }

   void serializeRegularPolygon(ACBase acb)
   {
      RegularPolygon o = cast(RegularPolygon) acb;
      string s = basics(acb);
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "altColor=" ~ o.colorString(true) ~ "\n";
      s ~= "lineWidth=" ~ to!string(o.lineWidth) ~ "\n";
      s ~= "les=" ~ to!string(o.les) ~ "\n";
      s ~= "sides=" ~ to!string(o.sides) ~ "\n";
      s ~= "fill=" ~ to!string(o.fill) ~ "\n";
      s ~= "outline=" ~ to!string(o.outline) ~ "\n";
      s ~= "fillFromPattern=" ~ to!string(o.fillFromPattern) ~ "\n";
      s ~= "fillUid=" ~ o.fillUid.toString() ~ "\n";
      s ~= "isStar=" ~ to!string(o.isStar) ~ "\n";
      s ~= "radius=" ~ to!string(o.radius) ~ "\n";
      s ~= "center=" ~ coord2S(o.center) ~ "\n";
      s ~= "starIndent=" ~ to!string(o.starIndent) ~ "\n";
      s ~= "oPath=" ~ path2S(o.oPath) ~ "\n";
      s ~= "tf=" ~ transform2S(o.tf) ~ "\n";
      s ~= "\n";
      os.writeString(s);
   }

   void serializeRegularPolycurve(ACBase acb)
   {
      RegularPolycurve o = cast(RegularPolycurve) acb;
      string s = basics(acb);
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "altColor=" ~ o.colorString(true) ~ "\n";
      s ~= "lineWidth=" ~ to!string(o.lineWidth) ~ "\n";
      s ~= "les=" ~ to!string(o.les) ~ "\n";
      s ~= "sides=" ~ to!string(o.sides) ~ "\n";
      s ~= "fill=" ~ to!string(o.fill) ~ "\n";
      s ~= "outline=" ~ to!string(o.outline) ~ "\n";
      s ~= "fillFromPattern=" ~ to!string(o.fillFromPattern) ~ "\n";
      s ~= "fillUid=" ~ o.fillUid.toString() ~ "\n";
      s ~= "target=" ~ to!string(o.target) ~ "\n";
      /*
      s ~= "inner=" ~ to!string(o.inner) ~ "\n";
      s ~= "outer=" ~ to!string(o.outer) ~ "\n";
      s ~= "cangle=" ~ to!string(o.cangle) ~ "\n";
      s ~= "laglead=" ~ to!string(o.laglead) ~ "\n";
      s ~= "cpos=" ~ to!string(cast(int) o.cpos) ~ "\n";
      */
      //s ~= "alternating=" ~ to!string(o.alternating) ~ "\n";
      //s ~= "prop=" ~ to!string(o.prop) ~ "\n";
      s ~= "center=" ~ coord2S(o.center) ~ "\n";
      s ~= "tf=" ~ transform2S(o.tf) ~ "\n";
      s ~= "\n";
      os.writeString(s);
   }

   void serializeRGradient(ACBase acb)
   {
      RGradient o = cast(RGradient) acb;
      string s = basics(acb);
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "outrad=" ~ to!string(o.outrad) ~ "\n";
      s ~= "maxOpacity=" ~ to!string(o.maxOpacity) ~ "\n";
      s ~= "center=" ~ coord2S(o.center) ~ "\n";
      s ~= "gType=" ~ to!string(o.gType) ~ "\n";
      s ~= "nStops=" ~ to!string(o.nStops) ~ "\n";
      s ~= "mark=" ~ to!string(o.mark) ~ "\n";
      s ~= "revfade=" ~ to!string(o.revfade) ~ "\n";
      s ~= "\n";
      os.writeString(s);
   }

   void serializeSeparator(ACBase acb)
   {
      Separator o = cast(Separator) acb;
      string s = basics(acb);
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "lineWidth=" ~ to!string(o.lineWidth) ~ "\n";
      s ~= "hStart=" ~ coord2S(o.hStart) ~ "\n";
      s ~= "hEnd=" ~ coord2S(o.hEnd) ~ "\n";
      s ~= "vStart=" ~ coord2S(o.vStart) ~ "\n";
      s ~= "vEnd=" ~ coord2S(o.vEnd) ~ "\n";
      s ~= "les=" ~ to!string(o.les) ~ "\n";
      s ~= "horizontal=" ~ to!string(o.horizontal) ~ "\n";
      s ~= "\n";
      os.writeString(s);
   }

   void serializeShield(ACBase acb)
   {
      Shield o = cast(Shield) acb;
      string s = basics(acb);
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "altColor=" ~ o.colorString(true) ~ "\n";
      s ~= "unit=" ~ to!string(o.unit) ~ "\n";
      s ~= "style=" ~ to!string(o.style) ~ "\n";
      s ~= "lineWidth=" ~ to!string(o.lineWidth) ~ "\n";
      s ~= "xform=" ~ to!string(o.xform) ~ "\n";
      s ~= "fill=" ~ to!string(o.fill) ~ "\n";
      s ~= "outline=" ~ to!string(o.outline) ~ "\n";
      s ~= "fillFromPattern=" ~ to!string(o.fillFromPattern) ~ "\n";
      s ~= "fillUid=" ~ o.fillUid.toString() ~ "\n";
      s ~= "tf=" ~ transform2S(o.tf) ~ "\n";
      s ~= "\n";
      os.writeString(s);
   }

   void serializeTilings(ACBase acb)
   {
      Tilings o = cast(Tilings) acb;
      string s = basics(acb);
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "center=" ~ coord2S(o.center) ~ "\n";
      s ~= "pattern=" ~ to!string(o.pattern) ~ "\n";
      s ~= "shade=" ~ to!string(o.shade) ~ "\n";
      s ~= "colorSeed=" ~ to!string(o.colorSeed) ~ "\n";
      s ~= "shapeSeed=" ~ to!string(o.shapeSeed) ~ "\n";
      s ~= "pca=" ~ partColorArray2S(o.pca) ~ "\n";
      s ~= "printRandom=" ~ to!string(o.printRandom) ~ "\n";
      s ~= "irregular=" ~ to!string(o.irregular) ~ "\n";
      s ~= "\n";
      os.writeString(s);
   }

   void serializeTeardrop(ACBase acb)
   {
      Teardrop o = cast(Teardrop) acb;
      string s = basics(acb);
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "altColor=" ~ o.colorString(true) ~ "\n";
      s ~= "unit=" ~ to!string(o.unit) ~ "\n";
      s ~= "lineWidth=" ~ to!string(o.lineWidth) ~ "\n";
      s ~= "xform=" ~ to!string(o.xform) ~ "\n";
      s ~= "fill=" ~ to!string(o.fill) ~ "\n";
      s ~= "outline=" ~ to!string(o.outline) ~ "\n";
      s ~= "fillFromPattern=" ~ to!string(o.fillFromPattern) ~ "\n";
      s ~= "fillUid=" ~ o.fillUid.toString() ~ "\n";
      s ~= "tf=" ~ transform2S(o.tf) ~ "\n";
      s ~= "\n";
      os.writeString(s);
   }

   void serializeTriangle(ACBase acb)
   {
      Triangle o = cast(Triangle) acb;
      string s = basics(acb);
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "altColor=" ~ o.colorString(true) ~ "\n";
      s ~= "lineWidth=" ~ to!string(o.lineWidth) ~ "\n";
      s ~= "les=" ~ to!string(o.les) ~ "\n";
      s ~= "fill=" ~ to!string(o.fill) ~ "\n";
      s ~= "outline=" ~ to!string(o.outline) ~"\n";
      s ~= "fillFromPattern=" ~ to!string(o.fillFromPattern) ~ "\n";
      s ~= "fillUid=" ~ o.fillUid.toString() ~ "\n";
      s ~= "center=" ~ coord2S(o.center) ~ "\n";
      s ~= "oPath=" ~ path2S(o.oPath) ~ "\n";
      s ~= "tf=" ~ transform2S(o.tf) ~ "\n";
      s ~= "w=" ~ to!string(o.w) ~ "\n";
      s ~= "h=" ~ to!string(o.h) ~ "\n";
      s ~= "ttype=" ~ to!string(o.ttype) ~ "\n";
      s ~= "\n";
      os.writeString(s);
   }

   void serializeYinYang(ACBase acb)
   {
      YinYang o = cast(YinYang) acb;
      string s = basics(acb);
      s ~= "baseColor=" ~ o.colorString(false) ~ "\n";
      s ~= "altColor=" ~ o.colorString(true) ~ "\n";
      s ~= "unit=" ~ to!string(o.unit) ~ "\n";
      s ~= "lineWidth=" ~ to!string(o.lineWidth) ~ "\n";
      s ~= "xform=" ~ to!string(o.xform) ~ "\n";
      s ~= "fill=" ~ to!string(o.fill) ~ "\n";
      s ~= "outline=" ~ to!string(o.outline) ~ "\n";
      s ~= "tf=" ~ transform2S(o.tf) ~ "\n";
      s ~= "\n";
      os.writeString(s);
   }

   void serializeDrawing(ACBase acb)
   {
      Drawing o = cast(Drawing) acb;
      string s = basics(acb);
      s ~= "center=" ~ coord2S(o.center) ~ "\n";
      s ~= "dName=" ~ o.dName ~ "\n";
      s ~= "tf=" ~ transform2S(o.tf) ~ "\n";
      s ~= "\n";
      os.writeString(s);
   }

   void serializeReference(ACBase acb)
   {
      Reference o = cast(Reference) acb;
      string s = basics(acb);
      s ~= "scf=" ~ to!string(o.scf) ~ "\n";
      if (o.that is null)
         s ~= "that=null\n";
      else
         s ~= "that=ok\n";
      s ~= "\n";
      os.writeString(s);
      if (o.that !is null)
         serializeContainer(o.that);
   }
}

