
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module pattern;

import mainwin;
import acomp;
import common;
import constants;
import types;
import controlset;
import lineset;

import std.stdio;
import std.string;
import std.math;
import std.conv;

import gdk.RGBA;
import gtk.Widget;
import gtk.Label;
import gtk.Button;
import gtk.SpinButton;
import gtk.ComboBoxText;
import cairo.Context;

class Pattern : LineSet
{
   static int nextOid = 0;;
   int rows, cols;
   double unit;
   int choice;

   override void syncControls()
   {
      cSet.setLineParams(lineWidth);
      cSet.setComboIndex(Purpose.PATTERN, choice);
      cSet.setLabel(Purpose.LINEWIDTH, formatLT(lineWidth));
   }

   this(Pattern other)
   {
      this(other.aw, other.parent);
      rows = other.rows;
      cols = other.cols;
      unit = other.unit;
      choice = other.choice;
      lineWidth = other.lineWidth;
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Pattern "~to!string(++nextOid);
      super(w, parent, s, AC_PATTERN);
      group = ACGroups.EFFECTS;
      rows= 30;
      cols = 30;
      unit = 5;
      choice = 0;
      lineWidth = 0.5;

      setupControls();
      positionControls(true);
   }

   override void extendControls()
   {
      int vp = cSet.cy;

      Label l = new Label("Width");
      cSet.add(l, ICoord(185, vp), Purpose.LABEL);
      new MoreLess(cSet, 0, ICoord(246, vp), true);

      l = new Label("Height");
      cSet.add(l, ICoord(185, vp+20), Purpose.LABEL);
      new MoreLess(cSet, 1, ICoord(246, vp+20), true);

      l = new Label("Unit size");
      cSet.add(l, ICoord(185, vp+40), Purpose.LABEL);
      new MoreLess(cSet, 2, ICoord(246, vp+40), true);

      new InchTool(cSet, 0, ICoord(0, vp), true);

      vp += 60;
      l = new Label("Choose Pattern");
      cSet.add(l, ICoord(0, vp+4), Purpose.LABEL);
      ComboBoxText cbb = new ComboBoxText(false);
      cbb.appendText("Grid");
      cbb.appendText("Honeycomb");
      cbb.appendText("Checkers");
      cbb.appendText("Circles");
      cbb.appendText("Triangles");
      cbb.appendText("Cross hatched");
      cbb.appendText("Down stripes");
      cbb.appendText("Up stripes");
      cbb.setSizeRequest(120, -1);
      cbb.setActive(0);
      cSet.add(cbb, ICoord(142, vp), Purpose.PATTERN);

      cSet.cy = vp+40;
   }

   override bool specificNotify(Widget w, Purpose wid)
   {
      switch (wid)
      {
      case Purpose.PATTERN:
         lastOp = push!int(this, choice, OP_IV0);
         choice = (cast(ComboBoxText) w).getActive();
         break;
      default:
         return false;
      }
      return true;
   }

   override void onCSMoreLess(int instance, bool more, bool coarse)
   {
      if (instance == 0)
      {
         lastOp = pushC!int(this, cols, OP_HSIZE);
         if (more)
            cols++;
         else
         {
            if (cols > 1)
               cols--;
         }
      }
      else if (instance == 1)
      {
         lastOp = pushC!int(this, rows, OP_VSIZE);
         if (more)
            rows++;
         else
         {
            if (rows > 1)
               rows--;
         }
      }
      else
      {
         lastOp = pushC!double(this, unit, OP_SIZE);
         if (more)
            unit *= coarse? 1.3: 1.05;
         else
         {
            double saveunit = unit;
            if (unit > 3)
               unit *= coarse? 0.8: 0.95;
            if (unit < 3)
            unit = saveunit;
         }
      }
      aw.dirty = true;
      reDraw();
   }

   override bool specificUndo(CheckPoint cp)
   {
      switch (cp.type)
      {
      case OP_HSIZE:
         cols = cp.iVal;
         break;
      case OP_VSIZE:
         rows = cp.iVal;
         break;
      case OP_SIZE:
         unit = cp.dVal;
         break;
      case OP_IV0:
         choice = cp.iVal;
         break;
      default:
         return false;
      }
      lastOp = OP_UNDEF;
      return true;
   }

   override void preResize(int oldW, int oldH)
   {
      double hr = cast(double) width/oldW;
      double vr = cast(double) height/oldH;
      hOff *= hr;
      vOff *= vr;
   }

   void renderShape(Context c, double x, double y, double u)
   {
      double r = cast(double)baseColor.red()/ushort.max;
      double g = cast(double)baseColor.green()/ushort.max;
      double b = cast(double)baseColor.blue()/ushort.max;
      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);
      switch (choice)
      {
      case 2:                                         // checkers
         c.rectangle(x, y, u, u);
         c.fill();
         break;
      case 3:                                         // circles
         c.setLineWidth(lineWidth);
         double rad = u*1.414/2;
         c.arc(x+u/2, y+u/2, rad, 0, 2*PI);
         c.stroke();
         break;
      case 4:                                         // down  ticks
         c.moveTo(x, y);
         c.lineTo(x+u, y);
         c.lineTo(x+u/2, y+u);
         c.closePath();
         c.fill();
         break;
      case 5:                                         // cross hatch
         c.setLineWidth(lineWidth);
         c.moveTo(x, y);
         c.lineTo(x+u, y+u);
         c.stroke();
         c.moveTo(x+u, y);
         c.lineTo(x, y+u);
         c.stroke();
         break;
      case 6:                                         // down striped
         c.setLineWidth(lineWidth);
         c.moveTo(x, y);
         c.lineTo(x+u, y+u);
         c.stroke();
         break;
      case 7:
         c.setLineWidth(lineWidth);                     // up striped
         c.moveTo(x+u, y);
         c.lineTo(x, y+u);
         c.stroke();
         break;
      default:
         break;
      }
   }

   void renderGrid(Context c)
   {
      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);
      c.setLineWidth(lineWidth);
      for (int i = 0; i < cols+1; i++)
      {
         c.moveTo(hOff+i*unit, vOff);
         c.lineTo(hOff+i*unit, vOff+rows*unit);
         c.stroke();
      }
      for (int i = 0; i < rows+1; i++)
      {
         c.moveTo(hOff, vOff+i*unit);
         c.lineTo(hOff+cols*unit, vOff+i*unit);
         c.stroke();
      }
      if (!isMoved) cSet.setDisplay(0, reportPosition());
   }

   void renderHoneycomb(Context c)
   {
      double hunit = unit*1.333;
      double cx, cy = vOff;
      c.setLineWidth(lineWidth);
      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);

      double side = hunit*sin(PI/6);
      double apoth = 0.5*hunit*cos(PI/6);
      double rise = side*cos(PI/3);

      cx = hOff;
      cy += apoth;
      for (int i = 0; i < cols/2; i++)
      {
         c.moveTo(cx, cy);
         c.lineTo(cx+rise, cy-apoth);
         c.lineTo(cx+rise+side, cy-apoth);
         c.lineTo(cx+hunit, cy);
         cx += hunit+side;
         c.lineTo(cx, cy);
      }
      c.stroke();
      if (cols & 1)
      {
         c.moveTo(cx, cy);
         c.lineTo(cx+rise, cy-apoth);
         c.lineTo(cx+rise+side, cy-apoth);
         c.lineTo(cx+hunit, cy);
         c.stroke();
      }
      for (int i = 0; i < rows-1; i++)
      {
         cx = hOff;


         for (int j = 0; j  < cols/2; j++)
         {
            c.moveTo(cx, cy);
            c.lineTo(cx+rise, cy+apoth);
            c.stroke();
            c.moveTo(cx+hunit, cy);
            c.lineTo(cx+rise+side, cy+apoth);
            cx += hunit+side;
            c.stroke();
         }
         c.moveTo(cx, cy);
         c.lineTo(cx+rise, cy+apoth);
         c.stroke();
         if (cols & 1)
         {
            c.moveTo(cx+hunit, cy);
            c.lineTo(cx+rise+side, cy+apoth);
            c.stroke();
         }
         cx = hOff;
         cy += 2*apoth;
         for (int j = 0; j  < cols/2; j++)
         {
            c.moveTo(cx, cy);
            c.lineTo(cx+rise, cy-apoth);
            c.lineTo(cx+rise+side, cy-apoth);
            c.lineTo(cx+hunit, cy);
            cx += hunit+side;
            c.lineTo(cx, cy);
         }
         c.moveTo(cx, cy);
         c.lineTo(cx+rise, cy-apoth);
         c.stroke();
         if (cols & 1)
         {
            c.moveTo(cx+rise, cy-apoth);
            c.lineTo(cx+rise+side, cy-apoth);
            c.lineTo(cx+hunit, cy);
            c.stroke();
         }
      }
      cx = hOff;
      for (int i = 0; i < cols/2; i++)
      {
         c.moveTo(cx, cy);
         c.lineTo(cx+rise, cy+apoth);
         c.lineTo(cx+rise+side, cy+apoth);
         c.lineTo(cx+hunit, cy);
         c.stroke();
         cx += hunit+side;
      }
      if (cols & 1)
      {
         c.moveTo(cx, cy);
         c.lineTo(cx+rise, cy+apoth);
         c.lineTo(cx+rise+side, cy+apoth);
         c.lineTo(cx+hunit, cy);
         c.stroke();
      }
      if (!isMoved) cSet.setDisplay(0, reportPosition());
   }

   override void render(Context c)
   {
      if (choice == 0)
      {
         renderGrid(c);
         return;
      }
      else if (choice == 1)
      {
         renderHoneycomb(c);
         return;
      }
      double cx, cy = vOff;
      c.setLineWidth(lineWidth);
      for (int i = 0; i < rows; i++)
      {
         cx = hOff;
         bool render = (i & 1);
         for (int j = 0; j < cols; j++)
         {
            if (render)
            {
               renderShape(c, cx, cy, unit);
            }
            render = !render;
            cx += unit;
         }
         cy += unit;
      }

      if (!isMoved) cSet.setDisplay(0, reportPosition());
   }
}



