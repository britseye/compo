
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
import mainwin;
import sheets;
import graphics;
import mol;

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
   int nextChildId;

   double zsf;
   Coord cvo;
   bool cZoomed, noBG;

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
      this(other.aw, other.parent);

      children.length = other.children.length;
      foreach (int i, ACBase acb; other.children)
      {
         children[i] = aw.cloneItem(other.children[i]);
         children[i].parent = this;
         //aw.treeOps.notifyInsertion(children[i]);
      }

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
      group = ACGroups.CONTAINER;
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
      cb.setTooltipText("The layer selected in the LHS tree view\ncan be moved using the 'inch tool' below.");
      cb.setActive(1);
      cSet.add(cb, ICoord(85, vp), Purpose.GLWHICH);

      new MoreLess(cSet, 0, ICoord(205, vp+1), true);

      vp += 35;
      new InchTool(cSet, 0, ICoord(0, vp), true);

      vp += 35;
      Label l = new Label("Right-click the composition container in the LHS\ntree view to add layers to this composition.");
      cSet.add(l, ICoord(0, vp), Purpose.LABEL);

      cSet.cy = vp+35;
   }

   override void deserializeComplete()
   {
      foreach (ACBase child; children)
         child.deserializeComplete();
   }

   int getNextId() { return ++nextChildId; }

   override bool specificNotify(Widget w, Purpose wid)
   {
      focusLayout();
      switch (wid)
      {
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
         return false;
      }
      return true;
   }

   override void onCSMoreLess(int instance, bool more, bool quickly)
   {
      focusLayout();
      double result = glUseV? hOff: vOff;
      if (!molA!double(more, quickly, result, 1, 0, 1.0*width))
         return;
      if (glUseV)
         hOff = result;
      else
         vOff = result;
      reDraw();
   }

   override void setSelectedChild(ACBase acb)
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

   void inchAll(int direction, bool coarse)
   {
      int any;
      foreach (ACBase child; children)
      {
         double d = coarse? 5.0: 0.5;
         switch (direction)
         {
         case 0:
            child.hOff -= d;
            break;
         case 1:
            child.vOff -= d;
            break;
         case 2:
            child.hOff += d;
            break;
         case 3:
            child.vOff += d;
            break;
         default:
            break;
         }
         any++;
      }
      if (any)
         aw.dirty = true;
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
      c.setSourceRgba(baseColor.red, baseColor.green, baseColor.blue, baseColor.alpha);
      c.paint();

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
      t[] = (cast(char[]) data[0..len])[];
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

   void setTransparent()
   {
      baseColor = new RGBA(1,1,1,0);
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
      if (!noBG)
      {
         c.setSourceRgba(baseColor.red, baseColor.green, baseColor.blue, baseColor.alpha);
         c.paint();
      }

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
         c.setOperator(CairoOperator.SOURCE);
         c.setLineWidth(1);
         c.setSourceRgb(0,0,0);
         c.setDash([2.0, 2.0], 0.0);
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
         c.setSourceRgb(1,1,1);
         c.setDash([2.0, 2.0], 2.0);
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
