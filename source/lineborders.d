
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module lineborders;

import mainwin;
import constants;
import acomp;
import common;
import types;
import controlset;
import lineset;

import std.stdio;
import std.conv;
import std.array;
import std.format;
import std.math;

import gtk.DrawingArea;
import gtk.Widget;
import gtk.Label;
import gtk.Button;
import gtk.CheckButton;
import gtk.RadioButton;
import gtk.ToggleButton;
import gtk.Layout;
import gtk.Frame;
import gtk.Range;
import gdk.RGBA;
import cairo.Context;
import gtkc.cairotypes;
import cairo.Matrix;

struct BSegment
{
   Coord s0;
   Coord cp10;
   Coord cp20;
   Coord e0;
   Coord s1;
   Coord cp11;
   Coord cp21;
   Coord e1;

   Coord tl;
   Coord br;

   bool doubled;

   this(double l, double d, bool vert, bool dl)
   {
      doubled = dl;
      if (vert)
      {
         if (dl)
         {
            s0.x = d, s0.y = 0;
            cp10.x = d; cp10.y = l/4;
            cp20.x = 0; cp20.y = 3*l/4;
            e0.x = 0; e0.y = l;

            s1.x = 0, s1.y = 0;
            cp11.x = 0; cp11.y = l/4;
            cp21.x = d; cp21.y = 3*l/4;
            e1.x = d; e1.y = l;
         }
         else
         {
            s0.x = 0, s0.y = 0;
            cp10.x = d; cp10.y = l/2;
            cp20.x = d; cp20.y = l/2;
            e0.x = 0; e0.y = l;
         }
      }
      else
      {
         if (dl)
         {
            s0.x = 0, s0.y = 0;
            cp10.x = l/4; cp10.y = 0;
            cp20.x = 3*l/4; cp20.y = d;
            e0.x = l; e0.y = d;

            s1.x = 0, s1.y = d;
            cp11.x = l/4; cp11.y = d;
            cp21.x = 3*l/4; cp21.y = 0;
            e1.x = l; e1.y = 0;
         }
         else
         {
            s0.x = 0, s0.y = 0;
            cp10.x = l/2; cp10.y = d;
            cp20.x = l/2; cp20.y = d;
            e0.x = l; e0.y = 0;
         }
      }
   }

   void shift(int ww, double d)
   {
      switch (ww)
      {
         case 0:
            s0.x += d, cp10.x += d, cp20.x += d, e0.x += d;
            if (doubled)
               s1.x += d, cp11.x += d, cp21.x += d, e1.x += d;
            break;
         case 1:
            s0.y += d, cp10.y += d, cp20.y += d, e0.y += d;
            if (doubled)
               s1.y += d, cp11.y += d, cp21.y += d, e1.y += d;
            break;
         case 2:
            s0.x -= d, cp10.x -= d, cp20.x -= d, e0.x -= d;
            if (doubled)
               s1.x -= d, cp11.x -= d, cp21.x -= d, e1.x -= d;
            break;
         case 3:
            s0.y -= d, cp10.y -= d, cp20.y -= d, e0.y -= d;
            if (doubled)
               s1.y -= d, cp11.y -= d, cp21.y -= d, e1.y -= d;
            break;
         default:
            break;
      }
   }

   void offset(double ho, double vo)
   {
      s0.x += ho, cp10.x += ho, cp20.x += ho, e0.x += ho;
      s0.y += vo, cp10.y += vo, cp20.y += vo, e0.y += vo;
      if (doubled)
      {
         s1.x += ho, cp11.x += ho, cp21.x += ho, e1.x += ho;
         s1.y += vo, cp11.y += vo, cp21.y += vo, e1.y += vo;
      }
   }

   void invert(bool vert, double d)
   {
      if (vert)
      {
         s0.x = d-s0.x, cp10.x = d-cp10.x, cp20.x = d-cp20.x, e0.x = d-e0.x;
      }
      else
      {
         s0.y = d-s0.y, cp10.y = d-cp10.y, cp20.y = d-cp20.y, e0.y = d-e0.y;
      }
   }
}

class LineBorders: LineSet
{
   static int nextOid = 0;
   BSegment bsh, bsv;
   bool doubled;
   double slh, slv, sd, inset;
   int baseN, nh, nv;

   override void syncControls()
   {
      cSet.toggling(false);
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(LineBorders other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      lineWidth = other.lineWidth;
      slh = other.slh;
      slv = other.slv;
      sd = other.sd;
      inset = other.inset;
      bsh = other.bsh;
      bsv = other.bsv;
      doubled = other.doubled;
      syncControls();
   }

   this(AppWindow wa, ACBase parent)
   {
      string s = "LineBorders "~to!string(++nextOid);
      super(wa, parent, s, AC_LINEBORDERS);
      group = ACGroups.EFFECTS;
      hOff = vOff = 0;

      lineWidth = 0.5;
      baseColor = new RGBA(0,0,0);
      center = Coord(0.5*width, 0.5*height);

      inset = 5;
      doubled = false;
      baseN = 5;
      figureWaves();

      setupControls();
      positionControls(true);
   }

   override void extendControls()
   {
      int vp = 0;

      CheckButton cb = new CheckButton("Doubled");
      cSet.add(cb, ICoord(230, vp+2), Purpose.FULLDATA);
      Label l = new Label("Inset");
      cSet.add(l, ICoord(232, vp+25), Purpose.LABEL);
      new MoreLess(cSet, 0, ICoord(295, vp+25), true);
      l = new Label("Waves");
      cSet.add(l, ICoord(232, vp+45), Purpose.LABEL);
      new MoreLess(cSet, 1, ICoord(295, vp+45), true);

      vp += 35;
      new Compass(cSet, 0, ICoord(0, vp));

      cSet.cy = vp+60;
   }

   override bool specificNotify(Widget w, Purpose p)
   {
      focusLayout();
      switch (p)
      {
      case Purpose.FULLDATA:
      doubled = !doubled;
         bsh = BSegment(slh, sd, false, doubled);
         bsv = BSegment(slv, sd, true, doubled);
         break;
      default:
         return false;
      }
      return true;
   }

   void figureWaves()
   {
      bool wmost = (width > height);
      if (wmost)
      {
         slh = cast(double) width/baseN;
         nh = baseN;
         nv = 1+to!int(floor(height/slh));
         slv = height/nv;
         sd = 0.05*height;
      }
      else
      {
         slv = cast(double) height/baseN;
         nv = baseN;
         nh = to!int(floor(width/slv));
         slh = width/nh;
         sd = 0.05*width;
      }
      bsh = BSegment(slh, sd, false, doubled);
      bsv = BSegment(slv, sd, true, doubled);
   }

   override void onCSMoreLess(int id, bool more, bool coarse)
   {
      focusLayout();
      if (id == 0)
      {
         if (more)
         {
            lastOp = pushC!double(this, inset, OP_OUTER);
            inset += 1;
         }
         else
         {
            if (inset-1 < 0)
               return;
            inset -= 1;
         }
      }
      else
      {              // BaseN needs to be odd
         if (more)
         {
            lastOp = pushC!int(this, baseN, OP_IV0);
            baseN  += 2;
         }
         else
         {
            if (baseN <= 3)
               return;
            lastOp = pushC!int(this, baseN, OP_IV0);
            baseN -= 2;
         }
         figureWaves();
      }
      aw.dirty = true;
      reDraw();
   }

   void ConstructBase()
   {


   }

   void getBounding(PathItemR pi)
   {
      Coord tl, br;
      double left = width, right = 0, top = height, bottom = 0;

      if (pi.start.x > right)
         right = pi.start.x;
      if (pi.start.x < left)
         left = pi.start.x;
      if (pi.start.y > bottom)
         bottom = pi.start.y;
      if (pi.start.y < top)
         top = pi.start.y;
      if (pi.end.x > right)
         right = pi.cp1.x;
      if (pi.end.x < left)
         left = pi.end.x;
      if (pi.end.y > bottom)
         bottom = pi.end.y;
      if (pi.end.y < top)
         top = pi.end.y;
      if (pi.cp1.x > right)
         right = pi.cp1.x;
      if (pi.cp1.x < left)
         left = pi.cp1.x;
      if (pi.cp1.y > bottom)
         bottom = pi.cp1.y;
      if (pi.cp1.y < top)
         top = pi.cp1.y;
      if (pi.cp2.x > right)
         right = pi.cp2.x;
      if (pi.cp2.x < left)
         left = pi.cp2.x;
      if (pi.cp2.y > bottom)
         bottom = pi.cp2.y;
      if (pi.cp2.y < top)
         top = pi.cp2.y;

      //topLeft = Coord(left, top);
      //bottomRight = Coord(right, bottom);
   }

   void renderWavy(Context c)
   {
      c.translate(hOff, vOff);
      c.setLineWidth(lineWidth);
      c.setLineJoin(CairoLineJoin.MITER);
      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);

      c.save();
      c.moveTo(0,0);
      c.lineTo(0.5*width, 0.5*width);
      c.lineTo(width, 0);
      c.closePath();
      c.clip();

      BSegment bs = bsh;
      bs.offset(0, inset);
      for (size_t i = 0; i < nh; i++)
      {
         c.moveTo(bs.s0.x, bs.s0.y);
         c.curveTo(bs.cp10.x, bs.cp10.y, bs.cp20.x, bs.cp20.y, bs.e0.x, bs.e0.y);
         if (doubled)
         {
            c.moveTo(bs.s1.x, bs.s1.y);
            c.curveTo(bs.cp11.x, bs.cp11.y, bs.cp21.x, bs.cp21.y, bs.e1.x, bs.e1.y);
         }
         bs.shift(0, slh);
      }
      c.stroke();
      c.restore();

      c.save();
      c.moveTo(0,0);
      c.lineTo(0.5*height, 0.5*height);
      c.lineTo(0, height);
      c.closePath();
      c.clip();

      bs = bsv;
      bs.offset(inset, 0);
      for (size_t i = 0; i < nv; i++)
      {
         c.moveTo(bs.s0.x, bs.s0.y);
         c.curveTo(bs.cp10.x, bs.cp10.y, bs.cp20.x, bs.cp20.y, bs.e0.x, bs.e0.y);
         if (doubled)
         {
            c.moveTo(bs.s1.x, bs.s1.y);
            c.curveTo(bs.cp11.x, bs.cp11.y, bs.cp21.x, bs.cp21.y, bs.e1.x, bs.e1.y);
         }
         bs.shift(1, slv);
      }
      c.stroke();
      c.restore();

      c.save();
      c.moveTo(0,height);
      c.lineTo(0.5*width, height-0.5*width);
      c.lineTo(width, height);
      c.closePath();
      c.clip();

      bs = bsh;
      if (!doubled)
         bs.invert(false, sd);
      bs.offset(0, height-inset-sd);
      for (size_t i = 0; i < nh; i++)
      {
         c.moveTo(bs.s0.x, bs.s0.y);
         c.curveTo(bs.cp10.x, bs.cp10.y, bs.cp20.x, bs.cp20.y, bs.e0.x, bs.e0.y);
         if (doubled)
         {
            c.moveTo(bs.s1.x, bs.s1.y);
            c.curveTo(bs.cp11.x, bs.cp11.y, bs.cp21.x, bs.cp21.y, bs.e1.x, bs.e1.y);
         }
         bs.shift(0, slh);
      }
      c.stroke();
      c.restore();

      c.save();
      c.moveTo(width, height);
      c.lineTo(width-0.5*height,height-0.5*height);
      c.lineTo(width, 0);
      c.closePath();
      c.clip();

      bs = bsv;
      if (!doubled)
         bs.invert(true, sd);
      bs.offset(width-inset-sd, 0);
      for (size_t i = 0; i < nv; i++)
      {
         c.moveTo(bs.s0.x, bs.s0.y);
         c.curveTo(bs.cp10.x, bs.cp10.y, bs.cp20.x, bs.cp20.y, bs.e0.x, bs.e0.y);
         if (doubled)
         {
            c.moveTo(bs.s1.x, bs.s1.y);
            c.curveTo(bs.cp11.x, bs.cp11.y, bs.cp21.x, bs.cp21.y, bs.e1.x, bs.e1.y);
         }
         bs.shift(1, slv);
      }
      c.stroke();
      c.restore();
   }

   void renderMaze(Context c)
   {
      c.translate(hOff, vOff);
      c.setLineWidth(lineWidth);
      c.setLineJoin(CairoLineJoin.MITER);
      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);

      double unit = 10;
      double x = inset;
      double y = inset;

      c.moveTo(inset, inset);
      x += 2*unit;
      for (int i =0; i < 10; i++)
      {
         c.lineTo(x, y);
         c.lineTo(x, y+unit);
         c.lineTo(x-unit, y+unit);
         c.lineTo(x-unit, y+2*unit);
         c.lineTo(x+unit, y+2*unit);
         c.lineTo(x+unit, y);
         x += 3*unit;
      }
      c.stroke();
   }

   override void render(Context c)
   {
      renderMaze(c);
   }
}



