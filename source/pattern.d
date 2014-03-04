
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
import std.random;

import gdk.RGBA;
import gtk.Widget;
import gtk.Label;
import gtk.CheckButton;
import gtk.ComboBoxText;
import cairo.Context;
import cairo.Matrix;
import cairo.Surface;

class Pattern : LineSet
{
   static int nextOid = 0;
   ACBase partner;
   int rows, cols;
   double unit, diagonal;
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
      hOff = other.hOff;
      vOff = other.vOff;
      rows = other.rows;
      cols = other.cols;
      unit = other.unit;
      choice = other.choice;
      lineWidth = other.lineWidth;
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Pattern "~to!string(++nextOid);
      super(w, parent, s, AC_PATTERN, ACGroups.EFFECTS);
      notifyHandlers ~= &Pattern.notifyHandler;

      center = Coord(0.5*width, 0.5*height);
      diagonal = 1.1*sqrt(cast(double)(width*width+height*height));
      unit = 5;
      rows= to!int(diagonal/unit);
      cols = rows;
      choice = 0;
      lineWidth = 0.5;
      tm = new Matrix(&tmData);

      setupControls();
      positionControls(true);
   }

   override void extendControls()
   {
      int vp = cSet.cy;

      ComboBoxText cbb = new ComboBoxText(false);
      cbb.appendText("Grid");
      cbb.appendText("Honeycomb");
      cbb.appendText("Checkers");
      cbb.appendText("Circles");
      cbb.appendText("Triangles");
      cbb.appendText("Cross hatched");
      cbb.appendText("Down stripes");
      cbb.appendText("Up stripes");
      cbb.appendText("Concentric");
      cbb.appendText("Spiral");
      cbb.appendText("Vortex");
      cbb.setSizeRequest(150, -1);
      cbb.setActive(0);
      cSet.add(cbb, ICoord(150, vp), Purpose.PATTERN);

      cbb = new ComboBoxText(false);
      cbb.appendText("Scale");
      cbb.appendText("Stretch-H");
      cbb.appendText("Stretch-V");
      cbb.appendText("Skew-H");
      cbb.appendText("Skew-V");
      cbb.appendText("Rotate");
      cbb.appendText("Flip-H");
      cbb.appendText("Flip-V");
      cbb.setActive(0);
      cbb.setSizeRequest(150, -1);
      cSet.add(cbb, ICoord(150, vp+30), Purpose.XFORMCB);
      new MoreLess(cSet, 0, ICoord(300, vp+35), true);

      new InchTool(cSet, 0, ICoord(0, vp), true);

      vp += 32;

      cSet.cy = vp+40;
   }

   override bool notifyHandler(Widget w, Purpose p)
   {
      switch (p)
      {
      case Purpose.PATTERN:
         lastOp = push!int(this, choice, OP_IV0);
         choice = (cast(ComboBoxText) w).getActive();
         dirty = true;
         break;
      default:
         return false;
      }
      return true;
   }
/*
   override bool specificNotify(Widget w, Purpose wid)
   {
      switch (wid)
      {
      case Purpose.PATTERN:
         lastOp = push!int(this, choice, OP_IV0);
         choice = (cast(ComboBoxText) w).getActive();
         dirty = true;
         break;
      default:
         return false;
      }
      return true;
   }
*/
   override void onCSMoreLess(int instance, bool more, bool coarse)
   {
      focusLayout();
      if (instance == 0)
         modifyTransform(xform, more, coarse);
      else
         return;
      dirty = true;
      aw.dirty = true;
      reDraw();
   }

   override bool specificUndo(CheckPoint cp)
   {
      switch (cp.type)
      {
      default:
         break;
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

      double ho = -(diagonal-width)/2;
      double vo = -(diagonal-height)/2;
      for (int i = 0; i < cols; i++)
      {
         c.moveTo(ho+i*unit, vo);
         c.lineTo(ho+i*unit, vo+rows*unit);
         c.stroke();
      }
      for (int i = 0; i < rows; i++)
      {
         c.moveTo(ho, vo+i*unit);
         c.lineTo(ho+cols*unit, vo+i*unit);
         c.stroke();
      }
   }

   void renderHoneycomb(Context c)
   {
      double hunit = unit*1.333;
      double cx = center.x-diagonal/2, cy = center.y-diagonal/2;
      c.setLineWidth(lineWidth);
      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);

      double side = hunit*sin(PI/6);
      double apoth = 0.5*hunit*cos(PI/6);
      double rise = side*cos(PI/3);

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
         cx = center.x-diagonal/2;

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
         cx = center.x-diagonal/2;
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
      cx = center.x-diagonal/2;
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
   }

   void renderConcentric(Context c, int n)
   {
      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);
      c.setLineWidth(lineWidth);
      double ho = center.x;
      double vo = center.y;
      double r;

      if (n == 8)
      {
         r = 4;
         for (; r*2 < diagonal;)
         {
            c.arc(ho,vo,r,0,PI*2);
            c.stroke();
            r += 8;
         }
      }
      else if (n == 9)
      {
         r = 0;
         double a = 0;
         double x = ho;
         double y = vo;
         c.moveTo(x, y);
         for (; r*2 < diagonal;)
         {
            r = 1.15*a;
            x = ho+r*cos(a);
            y = vo+r*sin(a);
            c.lineTo(x, y);
            a += 2* rads;
         }
         c.stroke();
      }
      else
      {
         r = 0;
         double a = PI*45;
         r = 0.1*pow(E, 0.03*a);
         double x = ho+r*cos(a);
         double y = vo+r*sin(a);
         a += 2* rads;
         c.moveTo(x, y);
         for (; r*2 < diagonal;)
         {
            r = 0.1*pow(E, 0.03*a);
            x = ho+r*cos(a);
            y = vo+r*sin(a);
            c.lineTo(x, y);
            a += 2* rads;
         }
         c.stroke();
      }
   }

   override void render(Context c)
   {
      c.translate(hOff+center.x, vOff+center.y);
      if (compoundTransform())
         c.transform(tm);
      c.translate(-center.x, -center.y);  // lpX and lpY both zero at design time

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
      else if (choice >= 8)
      {
         renderConcentric(c, choice);
         return;
      }
      double cx, cy = center.y-diagonal/2;
      c.setLineWidth(lineWidth);
      for (int i = 0; i < rows; i++)
      {
         cx = center.x-diagonal/2;
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
   }
}
