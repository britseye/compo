
//          Copyright Steve Teale 2014.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module curve;

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

class Curve : LineSet
{
   enum
   {
      SP = Purpose.R_TOGGLEBUTTONS-100,
      EP,
      CP1,
      CP2,
      BOTHCP,
      SPEP,
      ALL
   }

   static int nextOid = 0;
   PathItemR curve;
   int active, cMoves;
   bool showCp;

  override void syncControls()
   {
      cSet.setLineParams(lineWidth);
      cSet.toggling(false);
      if (les)
         cSet.setToggle(Purpose.LESSHARP, true);
      else
         cSet.setToggle(Purpose.LESROUND, true);
      cSet.setToggle(Purpose.SHOWMARKERS, showCp);
      cSet.setToggle(SP+active, true);
      cSet.toggling(true);
      cSet.setLabel(Purpose.LINEWIDTH, formatLT(lineWidth));
      if (!xform)
         cSet.setComboIndex(Purpose.XFORMCB, 0);
      else
         cSet.setComboIndex(Purpose.XFORMCB, 1);
      cSet.setHostName(name);
   }

   this(Curve other)
   {
      this(other.aw, other.parent);
      baseColor = other.baseColor.copy();
      center = other.center;
      lineWidth = other.lineWidth;
      les = other.les;
      curve = other.curve;
      xform = other.xform;
      tf = other.tf;
      if (other.showCp)
      {
         other.showCp = false;
         showCp = true;
         active = other.active;
      }
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Curve "~to!string(++nextOid);
      super(w, parent, s, AC_CURVE, ACGroups.GEOMETRIC);
      notifyHandlers ~= &Curve.notifyHandler;
      undoHandlers ~= &Curve.undoHandler;

      center.x = 0.5*width;
      center.y = 0.5*height;
      les = true;
      curve.start.x = 0.2*width;
      curve.start.y = 0.5*height;
      curve.cp1.x = 0.4*width;
      curve.cp1.y = 0.5*height;
      curve.cp2.x = 0.6*width;
      curve.cp2.y = 0.5*height;
      curve.end.x = 0.8*width;
      curve.end.y = 0.5*height;
      dirty = true;
      tm = new Matrix(&tmData);
      cMoves = 100;

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
      rb = new RadioButton(rb1, "Move CP1");
      cSet.add(rb, ICoord(175, vp), cast(Purpose) CP1);
      rb = new RadioButton(rb1, "Move CP2");
      cSet.add(rb, ICoord(175, vp+20), cast(Purpose) CP2);
      rb = new RadioButton(rb1, "Move Both CP");
      cSet.add(rb, ICoord(175, vp+40), cast(Purpose) BOTHCP);
      rb = new RadioButton(rb1, "Move Ends");
      cSet.add(rb, ICoord(175, vp+60), cast(Purpose) SPEP);
      rb = new RadioButton(rb1, "Move entire");
      cSet.add(rb, ICoord(175, vp+80), cast(Purpose) ALL);
      CheckButton cb = new CheckButton("Show control points");
      cSet.add(cb, ICoord(0, vp+80), Purpose.SHOWMARKERS);

      vp += 25;
      new Compass(cSet, 0, ICoord(0, vp-18));

      cSet.cy = vp+85;
   }

   override bool notifyHandler(Widget w, Purpose p)
   {

      if (p >= SP && p <= ALL)
      {
         if ((cast(RadioButton) w).getActive())
         {
            if (active == p-SP)
            {
               nop =true;
               return true;
            }
            active = p-SP;
         }
         return true;
      }
      else if (p == Purpose.SHOWMARKERS)
      {
         showCp = !showCp;
         return true;
      }
      else
         return false;
   }

   override bool undoHandler(CheckPoint cp)
   {
      switch (cp.type)
      {
      case OP_REDRAW:
         curve = cp.pathItemR;
         break;
      default:
         return false;
      }
      lastOp = OP_UNDEF;
      return true;
   }

   override void preResize(int oldW, int oldH)
   {
      center.x = width/2;
      center.y = height/2;
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
      if (++cMoves > 10)
      {
         lastOp = push!PathItemR(this, curve, OP_REDRAW);
         cMoves = 0;
      }
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
            curve.start.x += dx;
            curve.start.y += dy;
            break;
         case 1:
            curve.end.x += dx;
            curve.end.y += dy;
            break;
         case 2:
            curve.cp1.x += dx;
            curve.cp1.y += dy;
            break;
         case 3:
            curve.cp2.x += dx;
            curve.cp2.y += dy;
            break;
         case 4:
            curve.cp1.x += dx;
            curve.cp1.y += dy;
            curve.cp2.x += dx;
            curve.cp2.y += dy;
            break;
         case 5:
            curve.start.x += dx;
            curve.start.y += dy;
            curve.end.x += dx;
            curve.end.y += dy;
            break;
         case 6:
            curve.start.x += dx;
            curve.start.y += dy;
            curve.cp1.x += dx;
            curve.cp1.y += dy;
            curve.cp2.x += dx;
            curve.cp2.y += dy;
            curve.end.x += dx;
            curve.end.y += dy;
            break;
         default:
            break;
      }
   }

   override void mouseMoveOp(double dx, double dy, GdkModifierType state)
   {
      lastOp = push!PathItemR(this, curve, OP_REDRAW);
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
      c.translate(-center.x, -center.y);

      c.moveTo(curve.start.x, curve.start.y);
      c.curveTo(curve.cp1.x, curve.cp1.y, curve.cp2.x, curve.cp2.y, curve.end.x, curve.end.y);
      c.stroke();
      if (showCp && !printFlag)
      {
         c.setSourceRgb(1,0,0);
         c.moveTo(curve.start.x+3, curve.start.y);
         c.lineTo(curve.start.x-3, curve.start.y+3);
         c.lineTo(curve.start.x-3, curve.start.y-3);
         c.closePath();
         c.fill();
         c.setSourceRgb(0,0,0);
         c.moveTo(curve.cp1.x, curve.cp1.y-3);
         c.lineTo(curve.cp1.x+3, curve.cp1.y+3);
         c.lineTo(curve.cp1.x-3, curve.cp1.y+3);
         c.closePath();
         c.fill();
         c.setSourceRgb(0,0,1);
         c.moveTo(curve.cp2.x, curve.cp2.y+3);
         c.lineTo(curve.cp2.x+3, curve.cp2.y-3);
         c.lineTo(curve.cp2.x-3, curve.cp2.y-3);
         c.closePath();
         c.fill();
         c.setSourceRgb(0,1,0);
         c.moveTo(curve.end.x-3, curve.end.y);
         c.lineTo(curve.end.x+3, curve.end.y-3);
         c.lineTo(curve.end.x+3, curve.end.y+3);
         c.closePath();
         c.fill();
      }
   }
}


