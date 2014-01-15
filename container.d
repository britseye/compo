
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module container;

import constants;
import types;
import controlset;
import acomp;
import main;
import sheets;
import graphics;

import std.stdio;
import std.conv;
import std.math;
import std.variant;

import gdk.Pixbuf;
import gdk.RGBA;
import gdkpixbuf.PixbufLoader;
import gtk.Widget;
import gtk.Label;
import gtk.Button;
import gtk.CheckButton;
import gtk.Layout;
import gtk.DrawingArea;
import gtk.Frame;
import gtk.TreeModel;
import cairo.Surface;
import cairo.ImageSurface;
import cairo.Context;
import gtkc.cairotypes;

class Container: ACBase
{
   static int nextOid = 0;
   ACBase selectedChild, skip;
   Surface surface;
   bool glShowing, glUseV, decorate;
   double glSaved;

   double zsf;
   Coord cvo;
   bool cZoomed;

   override void syncControls()
   {
      cSet.toggling(false);
      if (glUseV)
         cSet.setToggle(Purpose.GLWHICH, true);
      else
         cSet.setToggle(Purpose.GLWHICH, false);
      cSet.toggling(true);
   }

   this(Container other)
   {
      name = "Container "~to!string(++nextOid);
      this(other.aw);

      glShowing = other.glShowing;
      glUseV = other.glUseV;
      hOff = other.hOff;
      glSaved = other.glSaved;
      syncControls();
   }

   this (AppWindow  w)
   {
      string s = "Container "~to!string(++nextOid);
      super(w, null, s, AC_CONTAINER);
      children.length = 1;
      baseColor = new RGBA(1,1,1,1);
   }

   this(AppWindow w, ACBase parent)
   {
      string s= "Container "~ to!string(++nextOid);
      super(w, parent, s, AC_CONTAINER);
      baseColor = new RGBA(1,1,1,1);
      glShowing = false;
      glUseV = true;
      hOff = 0.25*width;
      glSaved = 0.75*height;
      setupControls();
      positionControls(true);
   }

   override void extendControls()
   {
      int vp = cSet.cy;

      Button b = new Button("Background Color");
      cSet.add(b, ICoord(0, vp), Purpose.COLOR);

      vp += 27;
      b = new Button("Guidelines");
      cSet.add(b, ICoord(0, vp), Purpose.GUIDELINE);

      CheckButton cb = new CheckButton("Move Vertical");
      cb.setActive(1);
      cSet.add(cb, ICoord(85, vp), Purpose.GLWHICH);

      new MoreLess(cSet, 0, ICoord(205, vp+1), true);

      vp += 35;
      Label l = new Label("Move the child object currently checked\nas active in the LHS tree view");
      cSet.add(l, ICoord(0, vp), Purpose.LABEL);

      vp += 35;
      new InchTool(cSet, 0, ICoord(0, vp), true);

      cSet.cy = vp+35;
   }

   override void onCSNotify(Widget w, Purpose wid)
   {
      focusLayout();
      switch (wid)
      {
      case Purpose.COLOR:
         lastOp = push!RGBA(this, baseColor, OP_COLOR);
         setColor(false);
         break;
      case Purpose.GUIDELINE:
         glShowing = !glShowing;
         reDraw();
         break;
      case Purpose.GLWHICH:
         glUseV = !glUseV;
         if (glUseV)
         {
            hOff = glSaved;
            glSaved = vOff;
         }
         else
         {
            vOff = glSaved;
            glSaved = hOff;
         }
         break;
      default:
         break;
      }
      focusLayout();
   }

   override void onCSMoreLess(int instance, bool more, bool coarse)
   {
      focusLayout();
      double delta = 1.0;
      if (coarse)
         delta *= 10;
      if (!more)
         delta = -delta;
      if (glUseV)
         hOff += delta;
      else
         vOff += delta;
      reDraw();
   }

   void setSelectedChild(ACBase acb)
   {
      selectedChild = acb;
   }

   override void move(int direction, bool far)
   {
      if (selectedChild is null)
         return;
      selectedChild.move(direction, far);
      aw.dirty = true;
      reDraw();
   }

   override string onCSInch(int id, int direction, bool coarse)
   {
      if (selectedChild is null)
         return "";
      selectedChild.move(direction, coarse);
      aw.dirty = true;
      reDraw();
      return "";
   }

   override void onChildChanged()
   {
      surface = null;
   };

   Surface renderForPL(Context c)
   {
      if (surface is null)
      {
         surface = c.getTarget().createSimilar(cairo_content_t.COLOR_ALPHA, width, height);
         Context t = c.create(surface);
         render(t);
      }
      return surface;
   }

   override void renderToPL(Context c, double xpos, double ypos)
   {
      c.rectangle(xpos, ypos, width, height);
      c.clip();

      foreach (ACBase x; children)
      {
         x.printFlag = printFlag;
         c.save();
         x.cRender(c, xpos, ypos);
         c.restore();
         x.printFlag = false;
      }
   }

   override bool drawCallback(Context c, Widget widget)
   {
      // This is where we draw on the design window
      c.setSourceRgba(1.0, 1.0, 1.0, 1.0);
      c.paint();
      decorate = true;
      render(c);
      decorate = false;

      return true;
   }

   void renderOther(ACBase that, Context c)
   {
      decorate = true;
      skip = that;
      render(c);
      decorate = false;
   }

   static extern(C) cairo_status_t imgWriteFunc(void* closure, uchar* data, uint len)
   {
      PixbufLoader pbl = cast(PixbufLoader) closure;
      char[] t;
      t.length = len;
      t[] = cast(char[]) data[0..len];
      int rv = pbl.write(t);
      return rv? cairo_status_t.SUCCESS: cairo_status_t.WRITE_ERROR;
   }

   Pixbuf getPixbuf()
   {
      bool old = glShowing;
      glShowing = false;
      ImageSurface isf = ImageSurface.create(cairo_format_t.RGB24, width, height);
      Context isc = Context.create(isf);
      render(isc);
      PixbufLoader pbl = new PixbufLoader();
      isf.writeToPngStream (&Container.imgWriteFunc, cast(void*) pbl);
      pbl.close();
      Pixbuf rv = pbl.getPixbuf();
      glShowing = old;
      return rv;
   }

   void zoom(double sf, Coord vpo)
   {
      cZoomed = true;
      if (sf == 0)
         return;
      zsf = sf;
      cvo = vpo;
   }

   void unZoom() { cZoomed = false; }

   override void render(Context c)
   {
      //c.save();
      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);
      c.paint();
      //c.restore();
      if (decorate)
         decorateSheet(c);
      foreach (ACBase x; children)
      {
         if (x is skip || x.hidden)
            continue;
         c.save();
         x.render(c);
         c.restore();
      }
      skip = null;
      if (glShowing)
      {
         c.save();
         c.setOperator(CairoOperator.XOR);
         c.setSourceRgb(0.8,0.8,0.8);
         c.setLineWidth(0.5);
         c.setDash([4.0, 4.0], 0.0);
         if (glUseV)
         {
            c.moveTo(hOff, 0);
            c.lineTo(hOff, height);
            c.stroke();
            c.moveTo(0, glSaved);
            c.lineTo(width, glSaved);
            c.stroke();
         }
         else
         {
            c.moveTo(glSaved, 0);
            c.lineTo(glSaved, height);
            c.stroke();
            c.moveTo(0, vOff);
            c.lineTo(width, vOff);
            c.stroke();
         }
         c.restore();
      }
   }
}
