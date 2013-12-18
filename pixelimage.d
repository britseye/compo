
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module pixelimage;

import main;
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
//import cairo.Surface;
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
   Pixbuf pxb, spxb, pspxb;
   double sadj;
   int cw, ch;
   bool useFile, realized;

   void syncControls()
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
      cw = other.cw;
      ch = other.ch;
      useFile = other.useFile;
      syncControls();
      doScaling();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Picture "~to!string(++nextOid);
      super(w, parent, s, AC_PIXBUF);
      scaleType = 0;
      sadj = 1.0;
      setupControls();
      positionControls(true);
   }

   void setupControls()
   {
      int vp = 0;

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

      vp += 50;

      RenameGadget rg = new RenameGadget(cSet, ICoord(0, vp), name, true);
   }

   void onCSNotify(Widget w, Purpose wid)
   {
      switch (wid)
      {
      case Purpose.OPENFILE:
         onCFB();
         dummy.grabFocus();
         return;
      case Purpose.SCALEPROP:
         if ((cast(RadioButton) w).getActive())
         {
            scaleType = 0;
            doScaling();
            return;
         }
         break;
      case Purpose.SCALEFIT:
         if ((cast(RadioButton) w).getActive())
         {
            scaleType = 1;
            doScaling();
            return;
         }
         break;
      case Purpose.SCALENON:
         if ((cast(RadioButton) w).getActive())
         {
            scaleType = 2;
            doScaling();
            return;
         }
      case Purpose.USEFILE:
         useFile = !useFile;
         break;
      default:
         break;
      }
      reDraw();
   }

   void onCSMoreLess(int id, bool more, bool coarse)
   {
      dummy.grabFocus();
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
      int cw = cast(int) (cw * sadj);
      int ch = cast(int) (ch * sadj);
      spxb = pxb.scaleSimple(cw, ch, GdkInterpType.BILINEAR);

      aw.dirty = true;
      if (pxb !is null)
         reDraw();
   }


   void undo()
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
         doScaling();
         break;
      case OP_MOVE:
         Coord t = cp.coord;
         hOff = t.x;
         vOff = t.y;
         lastOp = OP_UNDEF;
      default:
         break;
      }
      aw.dirty = true;
      reDraw();
   }

   void preResize(int oldW, int oldH)
   {
      double hr = cast(double) width/oldW;
      double vr = cast(double) height/oldH;
      hOff *= hr;
      vOff *= vr;
      doScaling();
   }

   void pasteImg(Pixbuf img)
   {
      pxb = img;
      doScaling();
   }

   void doScaling()
   {
      if (scaleType == 0)
      {
         if (pxb !is null)
         {
            int pw = pxb.getWidth();
            int ph = pxb.getHeight();
            int nw, nh;
            double tar = cast(double)width/height;
            double ar = cast(double)pw/ph;
            if (tar > ar)
            {
               nh = height;
               nw = cast(int)(nh*ar);
            }
            else
            {
               nw = width;
               nh = cast(int)(nw/ar);
            }
            cw = cast(int) (nw*sadj);
            ch = cast(int) (nh*sadj);
            spxb = pxb.scaleSimple(cw, ch, GdkInterpType.BILINEAR);
         }
      }
      else if (scaleType == 1)
      {
         if (pxb !is null)
         {
            spxb = pxb.scaleSimple(width, height, GdkInterpType.BILINEAR);
         }
         hOff = vOff = 0.0;
      }
      else
      {
         spxb = pxb.copy();
         hOff = vOff = 0.0;
      }
      aw.dirty = true;
      if (pxb !is null)
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

      int pw = pxb.getWidth();
      int ph = pxb.getHeight();
      double tar = cast(double)width/height;
      double ar = cast(double)pw/ph;
      if (tar > ar)
      {
         ch = height;
         cw = cast(int)(ch*ar);
      }
      else
      {
         cw = width;
         ch = cast(int)(cw/ar);
      }
      spxb = pxb.scaleSimple(cw, ch, GdkInterpType.BILINEAR);
      aw.dirty = true;
      reDraw();
   }

   void scaleForPrint()
   {
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

   void render(Context c)
   {
      if (printFlag)
      {
         if (pspxb is null)
            scaleForPrint();
      }
      Pixbuf pbt = printFlag? pspxb: spxb;
      if (pxb !is null)
      {
         // GTK+3 essentially moved the previous Cairo method into gdk.Cairo
         setSourcePixbuf(c, spxb, hOff, vOff);
         c.paint();
      }
   }
}
