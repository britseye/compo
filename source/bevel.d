
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module bevel;

import mainwin;
import constants;
import acomp;
import common;
import types;
import controlset;
import mol;

import std.stdio;
import std.conv;
import std.array;
import std.format;

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

class Bevel: ACBase
{
   static int nextOid = 0;
   double bt;
   double lineWidth;

   string formatLT(double lt)
   {
      scope auto w = appender!string();
      formattedWrite(w, "%1.1f", lt);
      return w.data;
   }

   override void syncControls()
   {
      cSet.toggling(false);
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(Bevel other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      bt = other.bt;
      lineWidth = other.lineWidth;
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Bevel "~to!string(++nextOid);
      super(w, parent, s, AC_BEVEL);
      group = ACGroups.EFFECTS;
      hOff = vOff = 0;
      bt = 10.0;
      lineWidth = 0.5;
      baseColor = new RGBA(0.7, 0.7, 0.7);

      setupControls();
      positionControls(true);
   }

   override int getNextOid()
   {
      return ++nextOid;
   }

   override void extendControls()
   {
      int vp = 0;

      Button b = new Button("Color");
      cSet.add(b, ICoord(0, vp), Purpose.COLOR);

      Label t = new Label("Bevel Width");
      cSet.add(t, ICoord(150, vp), Purpose.LABEL);
      new MoreLess(cSet, 0, ICoord(240, vp), true);

      cSet.cy = 35;
   }

   override void onCSMoreLess(int id, bool more, bool quickly)
   {
      focusLayout();

      double result = bt;
      if (!molA!double(more, quickly, result, 0.6, 2, 40))
         return;
      lastOp = pushC!double(this, bt, OP_THICK);
      bt = result;
      aw.dirty = true;
      reDraw();
   }

   override void undo()
   {
      CheckPoint cp;
      cp = popOp();
      if (cp.type == 0)
         return;
      switch (cp.type)
      {
      case OP_COLOR:
         baseColor = cp.color.copy();
         lastOp = OP_UNDEF;
         break;
      case OP_THICK:
         bt = cp.dVal;
         lastOp = OP_UNDEF;
         break;
      default:
         return;
      }
      aw.dirty = true;
      reDraw();
   }

   override string onCSInch(int id, int direction, bool coarse)
   {
      return "";
   }

   override void render(Context c)
   {
      c.setLineWidth(0);
      c.setLineJoin(CairoLineJoin.MITER);
      double r = baseColor.red();
      double g = baseColor.green();
      double b = baseColor.blue();
      if (r == 0.0 && g == 0.0 && b == 0.0)
      {
         r = 0.9;
         g = 0.9;
         b = 0.9;
      }
      double mr = 0.8*r;
      double mg = 0.8*g;
      double mb = 0.8*b;
      double dr = 0.6*r;
      double dg = 0.6*g;
      double db = 0.6*b;

      double x0 = hOff, y0 = vOff;
      double w= width+hOff;
      double h = height+vOff;

      c.moveTo(x0, y0);
      c.lineTo(x0, h);
      c.lineTo(x0+bt, h-bt);
      c.lineTo(x0+bt, y0+bt);
      c.closePath();
      c.setSourceRgba(dr, dg, db, 1);
      c.fill();

      c.moveTo(x0, y0);
      c.lineTo(w, y0);
      c.lineTo(w-bt, y0+bt);
      c.lineTo(x0+bt, y0+bt);
      c.closePath();
      c.setSourceRgba(mr, mg, mb, 1);
      c.fill();

      c.moveTo(x0, h);
      c.lineTo(w, h);
      c.lineTo(w-bt, h-bt);
      c.lineTo(x0+bt, h-bt);
      c.closePath();
      c.fill();

      c.moveTo(w, y0);
      c.lineTo(w, h);
      c.lineTo(w-bt, h-bt);
      c.lineTo(w-bt, y0+bt);
      c.closePath();
      c.setSourceRgba(r, g, b, 1);
      c.fill();

      c.setSourceRgb(1, 1, 1);
      c.moveTo(x0, y0);
      c.lineTo(x0+bt, y0+bt);
      c.stroke();
      c.moveTo(w, y0);
      c.lineTo(w-bt, y0+bt);
      c.stroke();
      c.moveTo(x0, h);
      c.lineTo(x0+bt, h-bt);
      c.stroke();
      c.moveTo(w, h);
      c.lineTo(w-bt, h-bt);
      c.stroke();


      if (!isMoved) cSet.setDisplay(0, reportPosition());
   }
}



