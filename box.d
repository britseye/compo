
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module box;

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
import gtk.SpinButton;
import gtk.RadioButton;
import gtk.ToggleButton;
import gtk.Layout;
import gtk.Frame;
import gtk.Range;
import gdk.RGBA;
import cairo.Context;
import gtkc.cairotypes;
import cairo.Matrix;

class Box : LineSet
{
   static int nextOid = 0;
   Coord topLeft, bottomRight;

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

   this(Box other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      topLeft = other.topLeft;
      bottomRight = other.bottomRight;
      lineWidth = other.lineWidth;
      les = other.les;
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Box "~to!string(++nextOid);
      super(w, parent, s, AC_BOX);
      hOff = vOff = 0;
      topLeft.x = 4.0;
      topLeft.y = 4;
      bottomRight.x = width-5;
      bottomRight.y = height-5;
      lineWidth = 0.5;
      les = true;

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

      new InchTool(cSet, 0, ICoord(0, vp+5), true);

      Label l = new Label("Width");
      l.setTooltipText("Adjust width - hold down <Ctrl> for faster action");
      cSet.add(l, ICoord(220, vp-2), Purpose.LABEL);
      new MoreLess(cSet, 0, ICoord(265, vp-3), true);

      vp += 20;

      l = new Label("Height");
      l.setTooltipText("Adjust height - hold down <Ctrl> for faster action");
      cSet.add(l, ICoord(220, vp-2), Purpose.LABEL);
      new MoreLess(cSet, 1, ICoord(265, vp-3), true);

      cSet.cy = vp+25;
   }

   void preResize(int oldW, int oldH)
   {
      topLeft.x = 4.0;
      topLeft.y = 4;
      bottomRight.x = width-5;
      bottomRight.y = height-5;
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

   void onCSMoreLess(int id, bool more, bool coarse)
   {
      int n = more? 1: -1;
      dummy.grabFocus();
      if (coarse)
         n *= 10;
      if (id == 0)
      {
         lastOp = pushC!double(this, bottomRight.x, OP_HSIZE);
         bottomRight.x += n;
      }
      else
      {
         lastOp = pushC!double(this, bottomRight.y, OP_VSIZE);
         bottomRight.y += n;
      }
      aw.dirty = true;
      reDraw();
   }

   bool specificUndo(CheckPoint cp)
   {
      switch (cp.type)
      {
      case OP_HSIZE:
         bottomRight.x = cp.dVal;
         lastOp = OP_UNDEF;
         break;
      case OP_VSIZE:
         bottomRight.y = cp.dVal;
         lastOp = OP_UNDEF;
         break;
      default:
         return false;
      }
      return true;
   }

   void render(Context c)
   {
      c.setLineWidth(lineWidth);
      c.setLineJoin(les? CairoLineJoin.MITER: CairoLineJoin.ROUND);
      double r = baseColor.red();
      double g = baseColor.green();
      double b = baseColor.blue();
      c.setSourceRgb(r, g, b);
      c.moveTo(hOff+topLeft.x, vOff+topLeft.y);
      c.lineTo(hOff+bottomRight.x, vOff+topLeft.y);
      c.lineTo(hOff+bottomRight.x, vOff+bottomRight.y);
      c.lineTo(hOff+topLeft.x, vOff+bottomRight.y);
      c.closePath();
      c.stroke();

      if (!isMoved) cSet.setDisplay(0, reportPosition());
   }
}


