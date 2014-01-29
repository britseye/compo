
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module separator;

import mainwin;
import constants;
import acomp;
import common;
import types;
import controlset;
import lineset;

import std.stdio;
import std.conv;

import gtk.Widget;
import gtk.Label;
import gtk.Button;
import gtk.RadioButton;
import gtk.SpinButton;
import gdk.RGBA;
import cairo.Context;

// A do-nothing graphical object to serve as template for real graphical objects
class Separator : LineSet
{
   static int nextOid = 0;
   Coord hStart, hEnd;
   Coord vStart, vEnd;
   bool horizontal;

   override void syncControls()
   {
      cSet.setLineParams(lineWidth);
      cSet.toggling(false);
      if (les)
         cSet.setToggle(Purpose.LESSHARP, true);
      else
         cSet.setToggle(Purpose.LESROUND, true);
      if (horizontal)
         cSet.setToggle(Purpose.HORIZONTAL, true);
      else
         cSet.setToggle(Purpose.VERTICAL, true);
      cSet.setLabel(Purpose.LINEWIDTH, formatLT(lineWidth));
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(Separator other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      hStart = other.hStart;
      hEnd = other.hEnd;
      vStart = other.vStart;
      vEnd = other.vEnd;
      baseColor = other.baseColor.copy();
      lineWidth = other.lineWidth;
      les = other.les;
      horizontal = other.horizontal;
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Separator "~to!string(++nextOid);
      super(w, parent, s, AC_SEPARATOR);
      group = ACGroups.EFFECTS;
      hOff = vOff = 0;
      horizontal = true;
      lineWidth = 1.0;
      les = true;

      hStart.x = 10.0;
      hStart.y = (height*2.0)/3;
      hEnd.x = width-11;
      hEnd.y = hStart.y;
      vStart.x = width/10;
      vStart.y = 2;
      vEnd.x = vStart.x;
      vEnd.y = height-3;
      setupControls(3);
      positionControls(true);
   }

   override void extendControls()
   {
      int vp = cSet.cy;

      RadioButton rb1 = new RadioButton("Horizontal", true);
      cSet.add(rb1, ICoord(220, vp-38), Purpose.HORIZONTAL);
      RadioButton rb2 = new RadioButton(rb1, "Vertical", false);
      cSet.add(rb2, ICoord(220, vp-18), Purpose.VERTICAL);

      Label l = new Label("Length");
      cSet.add(l, ICoord(220, vp+2), Purpose.LABEL);
      new MoreLess(cSet, 0, ICoord(290, vp+2), true);

      vp += 5;
      new InchTool(cSet, 0, ICoord(0, vp), true);

      vp += 50;
      new Compass(cSet, 0, ICoord(0, vp), true);

      cSet.cy = vp+40;
   }

   override bool specificNotify(Widget w, Purpose wid)
   {
      switch (wid)
      {
      case Purpose.HORIZONTAL:
         if ((cast(RadioButton) w).getActive())
            horizontal = true;
         break;
      case Purpose.VERTICAL:
         if ((cast(RadioButton) w).getActive())
            horizontal = false;
         break;
      default:
         return false;
      }
      return true;
   }

   override void onCSMoreLess(int instance, bool more, bool far)
   {
      focusLayout();
      int n = more? 1: -1;
      if (far)
         n *= 10;
      if (horizontal)
      {
         lastOp = pushC!Coord(this, hEnd, OP_HSIZE);
         hEnd.x += n;
      }
      else
      {
         lastOp = pushC!Coord(this, vEnd, OP_VSIZE);
         vEnd.y += n;
      }
      aw.dirty = true;
      reDraw();
   }

   override bool specificUndo(CheckPoint cp)
   {
      switch (cp.type)
      {
      case OP_HSIZE:
         hEnd= cp.coord;
         lastOp = OP_UNDEF;
         break;
      case OP_VSIZE:
         vEnd= cp.coord;
         lastOp = OP_UNDEF;
         break;
      default:
         return false;
      }
      return true;
   }

   override void preResize(int oldW, int oldH)
   {
      double hr = cast(double) width/oldW;
      double vr = cast(double) height/oldH;
      hStart.x *= hr;
      hEnd.x *= hr;
      hStart.y *= vr;
      hEnd.y *= vr;
      hOff *= hr;
      vOff *= vr;
   }

   override void render(Context c)
   {
      c.setLineWidth(lineWidth);
      c.setLineCap(les? CairoLineCap.BUTT: CairoLineCap.ROUND);
      double r = cast(double)baseColor.red()/ushort.max;
      double g = cast(double)baseColor.green()/ushort.max;
      double b = cast(double)baseColor.blue()/ushort.max;

      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);
      if (horizontal)
      {
         c.moveTo(hOff+hStart.x, vOff+hStart.y);
         c.lineTo(hOff+hEnd.x, vOff+hEnd.y);
      }
      else
      {
         c.moveTo(hOff+vStart.x, vOff+vStart.y);
         c.lineTo(hOff+vEnd.x, vOff+vEnd.y);
      }
      c.stroke();

      if (!isMoved) cSet.setDisplay(0, reportPosition());
   }
}


