
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module connector;

import main;
import constants;
import acomp;
import common;
import types;
import controlset;
import lineset;

import std.stdio;
import std.conv;

import gtk.DrawingArea;
import gtk.Widget;
import gtk.Label;
import gtk.Button;
import gtk.RadioButton;
import gtk.ToggleButton;
import gtk.SpinButton;
import gtk.Layout;
import gtk.Frame;
import gtk.Range;
import gdk.RGBA;
import cairo.Context;
import gtkc.cairotypes;
import cairo.Matrix;

// A do-nothing graphical object to serve as template for real graphical objects
class Connector : LineSet
{
   static int nextOid = 0;
   Coord start, end;

   void syncControls()
   {
      cSet.setLineParams(lineWidth);
      cSet.toggling(false);
      if (les)
         cSet.setToggle(Purpose.LESSHARP, true);
      else
         cSet.setToggle(Purpose.LESROUND, true);
      cSet.setLabel(Purpose.LINEWIDTH, formatLT(lineWidth));
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(Connector other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      lineWidth = other.lineWidth;
      start = other.start;
      end = other.end;
      les = other.les;
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Connector "~to!string(++nextOid);
      super(w, parent, s, AC_CONNECTOR);
      start.x = width/4.0;
      start.y = height/4.0;
      end.x = width*0.75;
      end.y = height*0.75;
      les = cairo_line_cap_t.ROUND;

      setupControls(3);
      positionControls(true);
   }

   override int getNextOid()
   {
      return ++nextOid;
   }

   void extendControls()
   {
      int vp = cSet.cy;

      Label l = new Label("Start");
      l.setTooltipText("Move the starting point");
      cSet.add(l, ICoord(0, vp), Purpose.LABEL);
      l = new Label("End");
      l.setTooltipText("Move the end point");
      cSet.add(l, ICoord(150, vp), Purpose.LABEL);

      vp += 15;

      new InchTool(cSet, 0, ICoord(0, vp), true);
      new InchTool(cSet, 1, ICoord(140, vp), true);
      cSet.cy = vp+40;
   }

   void preResize(int oldW, int oldH)
   {
      double hr = cast(double) width/oldW;
      double vr = cast(double) height/oldH;
      start.x *= hr;
      end.x *= hr;
      start.y *= vr;
      end.y *= vr;
      hOff *= hr;
      vOff *= vr;
   }

   void onCSNotify(Widget w, Purpose wid)
   {
      switch (wid)
      {
      case Purpose.COLOR:
         dummy.grabFocus();
         lastOp = push!RGBA(this, baseColor, OP_COLOR);
         setColor(false);
         break;
      case Purpose.LINEWIDTH:
         lastOp = pushC!double(this, lineWidth, OP_THICK);
         lineWidth = (cast(SpinButton) w).getValue();
         break;
      case Purpose.LESROUND:
         if ((cast(RadioButton) w).getActive())
            les = false;
         break;
      case Purpose.LESSHARP:
         if ((cast(RadioButton) w).getActive())
            les = true;
         break;
      default:
         break;
      }
      aw.dirty = true;
      reDraw();
   }

   override bool specificUndo(CheckPoint cp)
   {
      switch (cp.type)
      {
      case OP_HSIZE:
         start = cp.coord;
         lastOp = OP_UNDEF;
         break;
      case OP_VSIZE:
         end = cp.coord;
         lastOp = OP_UNDEF;
         break;
      default:
         return false;
      }
      return true;
   }

   override string onCSInch(int instance, int direction, bool coarse)
   {
      dummy.grabFocus();
      double d = coarse? 10.0: 1.0;
      bool skip = false;

      if (instance)  // move the end point
      {
         lastOp = pushC!Coord(this, end, OP_VSIZE);
         switch (direction)
         {
         case 0:
            end.x -= d;
            break;
         case 1:
            end.y -= d;
            break;
         case 2:
            end.x += d;
            break;
         case 3:
            end.y += d;
            break;
         default:
            skip = true;
            break;
         }
      }
      else
      {
         lastOp = pushC!Coord(this, start, OP_HSIZE);
         if (lastOp != OP_HSIZE)
         {
            lcp.coord = start;
            lcp.type = lastOp = OP_HSIZE;
            pushOp(lcp);
         }
         switch (direction)
         {
         case 0:
            start.x -= d;
            break;
         case 1:
            start.y -= d;
            break;
         case 2:
            start.x += d;
            break;
         case 3:
            start.y += d;
            break;
         default:
            skip = true;
            break;
         }
      }
      if (!skip)
      {
         aw.dirty = true;
         reDraw();
      }
      return reportPosition(instance);
   }

   string onCSMove(int id, int direction, bool far)
   {
      dummy.grabFocus();
      double d = far? 20.0: 1.0;
      bool skip = false;

      if (id)  // move the end point
      {
         lastOp = pushC!Coord(this, end, OP_VSIZE);
         switch (direction)
         {
         case 0:
            end.x -= d;
            break;
         case 1:
            end.y -= d;
            break;
         case 2:
            end.x += d;
            break;
         case 3:
            end.y += d;
            break;
         default:
            skip = true;
            break;
         }
      }
      else
      {
         lastOp = pushC!Coord(this, start, OP_HSIZE);
         if (lastOp != OP_HSIZE)
         {
            lcp.coord = start;
            lcp.type = lastOp = OP_HSIZE;
            pushOp(lcp);
         }
         switch (direction)
         {
         case 0:
            start.x -= d;
            break;
         case 1:
            start.y -= d;
            break;
         case 2:
            start.x += d;
            break;
         case 3:
            start.y += d;
            break;
         default:
            skip = true;
            break;
         }
      }
      if (!skip)
      {
         aw.dirty = true;
         reDraw();
      }
      return reportPosition(id);
   }

   string reportPosition(int id)
   {
      if (id)
         return formatCoord(Coord(hOff+end.x, vOff+end.y));
      else
         return formatCoord(Coord(hOff+start.x, vOff+start.y));
   }

   void render(Context c)
   {
      c.setLineWidth(lineWidth);
      c.setLineCap(les? CairoLineCap.BUTT: CairoLineCap.ROUND);
      double r = baseColor.red();
      double g = baseColor.green();
      double b = baseColor.blue();
      c.setSourceRgb(r, g, b);
      c.moveTo(hOff+start.x, vOff+start.y);
      c.lineTo(hOff+end.x, vOff+end.y);
      c.stroke();

      if (!isMoved)
      {
         cSet.setDisplay(0, reportPosition(0));
         cSet.setDisplay(1, reportPosition(1));
      }
   }
}


