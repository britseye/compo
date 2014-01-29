
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module pixelimage;

import mainwin;
import acomp;
import common;
import constants;
import types;
import controlset;

import std.conv;

import std.stdio;
import std.conv;
import std.string;
import gtk.Layout;
import gtk.Frame;
import gtk.DrawingArea;
import cairo.Context;
import cairo.Surface;
//import cairo.ImageSurface;
import gdk.Cairo;
import gtk.Widget;
import gtk.Label;
import gtk.Button;
import gtk.ToggleButton;
import gtk.RadioButton;
import gtk.CheckButton;
import gtk.FileFilter;
import gtk.FileChooserDialog;
import gdk.Pixbuf;
import gdk.Cairo;
import gobject.ObjectG;
import gtk.Style;
import pango.PgFontDescription;
import gobject.Value;

class PixelImage : ACBase
{
   static int nextOid = 0;
   int scaleType;
   string fileName;
   Pixbuf pxb, spxb, rpxb;
   double sadj, scaleX, scaleY, pw, ph;
   bool useFile, scale4Printer;

   override void syncControls()
   {
      cSet.toggling(false);
      if (scaleType == 0)
         cSet.setToggle(Purpose.SCALEPROP, true);
      else if (scaleType == 1)
         cSet.setToggle(Purpose.SCALEFIT, true);
      else
         cSet.setToggle(Purpose.SCALENON, true);
      cSet.setToggle(Purpose.USEFILE, useFile);
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(PixelImage other)
   {
      this(other.aw, other.parent);
      fileName = other.fileName;
      pxb = other.pxb;
      spxb = null;
      scaleType = other.scaleType;
      sadj = other.sadj;
      useFile = other.useFile;
      syncControls();
      setScaling();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Picture "~to!string(++nextOid);
      super(w, parent, s, AC_PIXBUF);
      group = ACGroups.PIXMAP;
      scaleType = 0;
      sadj = 1.0;
      scale4Printer = true;
      setupControls();
      positionControls(true);
   }

   override void extendControls()
   {
      int vp = cSet.cy;

      Button b = new Button("Choose picture file");
      cSet.add(b, ICoord(0, vp), Purpose.OPENFILE);

      RadioButton rb1 = new RadioButton("Scale in proportion");
      cSet.add(rb1, ICoord(150, vp), Purpose.SCALEPROP);
      RadioButton rb2 = new RadioButton(rb1, "Scale to fit");
      cSet.add(rb2, ICoord(150, vp+20), Purpose.SCALEFIT);
      rb2 = new RadioButton(rb1, "Do not scale");
      cSet.add(rb2, ICoord(150, vp+40), Purpose.SCALENON);

      vp += 65;
      new InchTool(cSet, 0, ICoord(0, vp-20), true);

      Label l = new Label("Additional scaling");
      l.setTooltipText("Scale larger or smaller - hold down <Ctrl> for faster action");
      cSet.add(l, ICoord(160, vp),Purpose. LABEL);
      new MoreLess(cSet, 0, ICoord(290, vp), true);
      CheckButton cb = new CheckButton("Reference the File");
      cSet.add(cb, ICoord(150, vp+20), Purpose.USEFILE);

      cSet.cy = vp+50;
   }

   override bool specificNotify(Widget w, Purpose wid)
   {
      switch (wid)
      {
      case Purpose.OPENFILE:
         onCFB();
         focusLayout();
         return true;
      case Purpose.SCALEPROP:
         if ((cast(RadioButton) w).getActive())
         {
            scaleType = 0;
            setScaling();
            return true;
         }
         break;
      case Purpose.SCALEFIT:
         if ((cast(RadioButton) w).getActive())
         {
            scaleType = 1;
            setScaling();
            return true;
         }
         break;
      case Purpose.SCALENON:
         if ((cast(RadioButton) w).getActive())
         {
            scaleType = 2;
            setScaling();
            return true;
         }
         break;
      case Purpose.USEFILE:
         useFile = !useFile;
         break;
      default:
         return false;
      }
      return true;
   }

   override void onCSMoreLess(int id, bool more, bool coarse)
   {
      focusLayout();
      if (scaleType != 0)
         return;
      lastOp = pushC!double(this, sadj, OP_SCALE);
      if (lastOp != OP_SCALE)
      {
         lcp.dVal = sadj;
         lcp.type = lastOp = OP_SCALE;
         pushOp(lcp);
      }
      if (coarse)
      {
         if (more)
            sadj *= 1.05;
         else
            sadj *= 0.95;
      }
      else
      {
         if (more)
            sadj *= 1.01;
         else
            sadj *= 0.99;
      }

      aw.dirty = true;
      if (pxb !is null)
         reDraw();
   }


   override void undo()
   {
      CheckPoint cp;
      cp = popOp();
      if (cp.type == 0)
         return;
      switch (cp.type)
      {
      case OP_SCALE:
         sadj = cp.dVal;
         lastOp = OP_UNDEF;
         setScaling();
         break;
      case OP_MOVE:
         Coord t = cp.coord;
         hOff = t.x;
         vOff = t.y;
         lastOp = OP_UNDEF;
         break;
      default:
         break;
      }
      aw.dirty = true;
      reDraw();
   }

   override void preResize(int oldW, int oldH)
   {
      double hr = cast(double) width/oldW;
      double vr = cast(double) height/oldH;
      hOff *= hr;
      vOff *= vr;
      setScaling();
   }

   void pasteImg(Pixbuf img)
   {
      pxb = img;
      setScaling();
   }

   void setScaling()
   {
      double bw, bh;
      if (pxb is null)
         return;
      pw = 1.0*pxb.getWidth();
      ph = 1.0*pxb.getHeight();
      if (scaleType == 0)
      {
         double tar = (1.0*width)/height;
         double ar = pw/ph;
         if (tar > ar)  // Limited by height
         {
            scaleY = height/ph;
            scaleX = scaleY;
            bw = width;
            bh = width/ar;
         }
         else           // limited by width;
         {
            scaleX = width/pw;
            scaleY = scaleX;
            bh = height;
            bw = bh/ar;
         }
         // This is what we'll save in the .compo file if requested
         if (scale4Printer)
            spxb = pxb.scaleSimple(to!int(bw), to!int(bh), GdkInterpType.HYPER);
      }
      else if (scaleType == 1)
      {
         scaleX = width/pw;
         scaleY =height/ph;
      }
      else
      {
         scaleX = scaleY = 1;
      }
      aw.dirty = true;
      reDraw();
   }

   void getPxb()
   {
      try
      {
         pxb = new Pixbuf(fileName);
      }
      catch (Exception ex)
      {
         return;
      }
      bool suitable = true;
      int channels = pxb.getNChannels();
      int hasAlpha = pxb.getHasAlpha();
      int bits = pxb.getBitsPerSample();
      uchar* px = cast(uchar*) pxb.getPixels();
      int stride = pxb.getRowstride();
      if (hasAlpha)
      {
         if (channels != 4 || bits != 8)
            suitable = false;
      }
      else
      {
         if (channels != 3 || bits != 8)
            suitable = false;
      }
      if (!suitable)
      {
         aw.popupMsg("The file you chose does not have a sutable image format.", MessageType.WARNING);
         pxb = null;
         return;
      }
      string s;
      int p = fileName.lastIndexOf('/');
      if (p >= 0)
         s = fileName[p+1..$];
      else
         s = fileName[];
      setName(s);
      aw.tv.queueDraw();
      setScaling();
      reDraw();
   }

   void onCFB()
   {
      FileChooserDialog fcd = new FileChooserDialog("Choose Picture File", aw, FileChooserAction.OPEN);
      FileFilter filter = new FileFilter();
      filter.setName("Bitmapped graphics files");
      filter.addPixbufFormats();

      fcd.setFilter(filter);
      int response = fcd.run();
      if (response != ResponseType.OK)
      {
         fcd.destroy();
         return;
      }
      fileName = fcd.getFilename();
      fcd.destroy();
      getPxb();
   }

   override void render(Context c)
   {
      if (pxb is null)
         return;
      double sx = scaleX*sadj, sy = scaleY*sadj;
      rpxb = pxb.scaleSimple(to!int(pw*sx), to!int(ph*sy), GdkInterpType.HYPER);

      if (svgFlag)
      {
         // If our picture is not filling the drawing area, we need to organize it onto a
         // surface with a white transparent background, and then render that to our
         // composition. Otherwise, when rendered to an SVG surface, the image will be
         // used as a repeating pattern.
         Surface mask = c.getTarget().createSimilar(cairo_content_t.COLOR_ALPHA, width, height);
         Context mc = c.create(mask);

         mc.setSourceRgba(1,1,1,0);
         mc.paint();
         // GTK+3 essentially moved the previous Cairo method into gdk.Cairo
         setSourcePixbuf(mc, rpxb, hOff, vOff);
         mc.moveTo(lpX, lpY);
         mc.lineTo(lpX, lpY+height);
         mc.lineTo(lpX+width, lpY+height);
         mc.lineTo(lpX+width, lpY);
         mc.closePath();
         mc.fill();
         c.setSourceSurface(mask, 0, 0);
         c.paint();
      }
      else
      {
         setSourcePixbuf(c, rpxb, hOff, vOff);
         c.moveTo(lpX, lpY);
         c.lineTo(lpX, lpY+height);
         c.lineTo(lpX+width, lpY+height);
         c.lineTo(lpX+width, lpY);
         c.closePath();
         c.fill();
      }
   }
}
