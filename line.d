
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module line;

import mainwin;
import constants;
import acomp;
import lineset;
import common;
import types;
import controlset;
import lineset;

import std.stdio;
import std.conv;
import std.math;

import gdk.RGBA;
import gtk.Widget;
import gtk.ToggleButton;
import gtk.RadioButton;
import gtk.CheckButton;
import gtk.ComboBoxText;
import cairo.Context;
import gtkc.cairotypes;
import cairo.Matrix;

class Line : LineSet
{
   enum
   {
      SP = Purpose.R_CHECKBUTTONS-100,
      EP,
      ALL
   }

   static int nextOid = 0;
   int active;
   bool showSe;

   override void syncControls()
   {
      cSet.setLineParams(lineWidth);
      cSet.toggling(false);
      if (les)
         cSet.setToggle(Purpose.LESSHARP, true);
      else
         cSet.setToggle(Purpose.LESROUND, true);
      cSet.setLabel(Purpose.LINEWIDTH, formatLT(lineWidth));
      cSet.toggling(true);
      if (!xform)
         cSet.setComboIndex(Purpose.XFORMCB, 0);
      else
         cSet.setComboIndex(Purpose.XFORMCB, 1);
      cSet.setHostName(name);
   }

   this(Line other)
   {
      this(other.aw, other.parent);
      baseColor = other.baseColor.copy();
      lineWidth = other.lineWidth;
      les = other.les;
      center = other.center;
      oPath.length = other.oPath.length;
      oPath[] = other.oPath[];
      xform = other.xform;
      tf = other.tf;
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Line "~to!string(++nextOid);
      super(w, parent, s, AC_LINE);
      aw = w;
      group = ACGroups.GEOMETRIC;
      tm = new Matrix(&tmData);

      center.x = 0.5*width;
      center.y = 0.5*height;
      les = true;
      oPath.length = 2;
      oPath[0].x = 0.25*width;
      oPath[0].y = 0.5*height;
      oPath[1].x = 0.75*width;
      oPath[1].y = 0.5*height;
      dirty = true;

      setupControls(3);
      positionControls(true);
   }

   override void extendControls()
   {
      int vp = cSet.cy;

      RadioButton rb1 = new RadioButton("Move start point");
      cSet.add(rb1, ICoord(175, vp-40), cast(Purpose) SP);
      RadioButton rb = new RadioButton(rb1, "Move end point");
      cSet.add(rb, ICoord(175, vp-20), cast(Purpose) EP);
      rb = new RadioButton(rb1, "Move entire");
      cSet.add(rb, ICoord(175, vp), cast(Purpose) ALL);
      CheckButton cb = new CheckButton("Show start/end");
      cSet.add(cb, ICoord(175, vp+20), Purpose.EDITMODE);

      vp += 25;
      new Compass(cSet, 0, ICoord(0, vp-18));

      cSet.cy = vp+40;
   }

   override bool specificNotify(Widget w, Purpose wid)
   {
      if (wid >= SP && wid <= ALL)
      {
         if ((cast(ToggleButton) w).getActive())
         {
            if (active == wid-SP)
               return false;
            active = wid-SP;
         }
         return true;
      }
      else if (wid == Purpose.EDITMODE)
         showSe = !showSe;
      else
         return false;
      return true;
   }

   override void preResize(int oldW, int oldH)
   {
      center.x = width/2;
      center.y = height/2;
      double hr = cast(double) width/oldW;
      double vr = cast(double) height/oldH;
      tm.initScale(hr, vr);
      for (int i = 0; i < oPath.length; i++)
      {
         tm.transformPoint(oPath[i].x, oPath[i].y);
      }
      hOff *= hr;
      vOff *= vr;
   }

   override void onCSLineWidth(double lt)
   {
      lastOp = pushC!double(this, lineWidth, OP_THICK);
      lineWidth = lt;
      aw.dirty = true;
      reDraw();
   }

   static pure void moveCoord(ref Coord p, double distance, double angle)
   {
      p.x += cos(angle)*distance;
      p.y -= sin(angle)*distance;
   }

   override void onCSCompass(int instance, double angle, bool coarse)
   {
      double d = coarse? 2: 0.5;
      Coord dummy = Coord(0,0);
      moveCoord(dummy, d, angle);
      double dx = dummy.x, dy = dummy.y;
      adjust(dx, dy);
      dirty = true;
      reDraw();
   }

   void adjust(double dx, double dy)
   {
      switch (active)
      {
         case 0:
            oPath[0].x += dx;
            oPath[0].y += dy;
            break;
         case 1:
            oPath[1].x += dx;
            oPath[1].y += dy;
            break;
         case 2:
            oPath[0].x += dx;
            oPath[0].y += dy;
            oPath[1].x += dx;
            oPath[1].y += dy;
            break;
         default:
            break;
      }
   }

   override void mouseMoveOp(double dx, double dy, GdkModifierType state)
   {
      adjust(dx, dy);
      dirty = true;
   }

   override void render(Context c)
   {
      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);
      c.setLineWidth(lineWidth);
      c.setAntialias(CairoAntialias.SUBPIXEL);
      c.setLineCap(les? CairoLineCap.BUTT: CairoLineCap.ROUND);

      c.translate(hOff+center.x, vOff+center.y);
      if (compoundTransform())
         c.transform(tm);
      c.translate(-center.x, -center.y);  // lpX and lpY both zero at design time

      c.moveTo(oPath[0].x, oPath[0].y);
      c.lineTo(oPath[1].x, oPath[1].y);
      c.stroke();
      if (showSe && !printFlag)
      {
         c.setSourceRgb(1,0,0);
         c.moveTo(oPath[0].x+3, oPath[0].y);
         c.lineTo(oPath[0].x-3, oPath[0].y+3);
         c.lineTo(oPath[0].x-3, oPath[0].y-3);
         c.closePath();
         c.fill();
         c.setSourceRgb(0,1,0);
         c.moveTo(oPath[1].x-3, oPath[1].y);
         c.lineTo(oPath[1].x+3, oPath[1].y-3);
         c.lineTo(oPath[1].x+3, oPath[1].y+3);
         c.closePath();
         c.fill();
      }
   }
}


