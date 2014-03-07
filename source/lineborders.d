
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
import mol;

import std.stdio;
import std.conv;
import std.array;
import std.format;
import std.math;
import std.random;

import gtk.DrawingArea;
import gtk.Widget;
import gtk.Label;
import gtk.Button;
import gtk.ComboBoxText;
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

   this(double l, double inset, double d, bool vert, bool dl)
   {
      doubled = dl;
      if (vert)
      {
         if (dl)
         {
            s0.x = d+inset, s0.y = inset;
            cp10.x = d+inset; cp10.y = l/4+inset;
            cp20.x = inset; cp20.y = 3*l/4+inset;
            e0.x = inset; e0.y = l+inset;

            s1.x = inset, s1.y = inset;
            cp11.x = inset; cp11.y = l/4+inset;
            cp21.x = d+inset; cp21.y = 3*l/4+inset;
            e1.x = d; e1.y = l;
         }
         else
         {
            s0.x = inset, s0.y = inset;
            cp10.x = d+inset; cp10.y = l/2+inset;
            cp20.x = d; cp20.y = l/2;
            e0.x = inset; e0.y = l+inset;
         }
      }
      else
      {
         if (dl)
         {
            s0.x = inset, s0.y = inset;
            cp10.x = l/4+inset; cp10.y = inset;
            cp20.x = 3*l/4+inset; cp20.y = d+inset;
            e0.x = l; e0.y = d;

            s1.x = inset, s1.y = d+inset;
            cp11.x = l/4+inset; cp11.y = d+inset;
            cp21.x = 3*l/4+inset; cp21.y = inset;
            e1.x = l; e1.y = 0;
         }
         else
         {
            s0.x = inset, s0.y = inset;
            cp10.x = l/2+inset; cp10.y = d+inset;
            cp20.x = l/2+inset; cp20.y = d+inset;
            e0.x = l+inset; e0.y = inset;
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
   Coord[][4] corners;
   bool doubled;
   double slh, slv, sd, inset, unit, mhinset, mvinset, cunit;
   int baseN, mssn, cssn;
   int nh, nv, nmh, nmv, pattern, activeCP;
   uint instanceSeed;
   cairo_matrix_t ttData;
   Matrix tt;
   Random gen;

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
      mixin(initString!LineBorders());
      super(wa, parent, sname, AC_LINEBORDERS, ACGroups.EFFECTS, ahdg);

      lineWidth = 0.5;
      baseColor = new RGBA(0,0,0);
      center = Coord(0.5*width, 0.5*height);
      tm = new Matrix(&tmData);
      tt = new Matrix(&ttData);
      mssn = 12;
      cssn = 12;
      for (int i = 0; i < 4; i++)
         corners[i].length = cssn;

      double least = (width > height)? height: width;
      inset = 0.025*least;
      doubled = false;
      baseN = 5;
      instanceSeed=42;

      figureMeander();

      setupControls();
      positionControls(true);
   }

   override void extendControls()
   {
      int vp = 0;

      ComboBoxText cbb = new ComboBoxText(false);
      cbb.appendText("Greek Meander");
      cbb.appendText("Wavy Lines");
      cbb.appendText("Double Wavy");
      cbb.appendText("Confused");
      cbb.setActive(0);
      cSet.add(cbb, ICoord(200, vp+23), Purpose.PATTERN);
      vp += 35;
      Label l = new Label("Inset");
      cSet.add(l, ICoord(200, vp+20), Purpose.LABEL);
      new MoreLess(cSet, 0, ICoord(295, vp+20), true);
      l = new Label("Items per Side");
      cSet.add(l, ICoord(200, vp+40), Purpose.LABEL);
      new MoreLess(cSet, 1, ICoord(295, vp+40), true);

      new Compass(cSet, 0, ICoord(0, vp+5));
      RadioButton rbg = new RadioButton("CP1");
      rbg.setSensitive(0);
      cSet.add(rbg, ICoord(60, vp), Purpose.CP1);
      RadioButton rb = new RadioButton(rbg, "CP2");
      rb.setSensitive(0);
      cSet.add(rb, ICoord(60, vp+20), Purpose.CP2);
      rb = new RadioButton(rbg, "BothCP");
      rb.setSensitive(0);
      cSet.add(rb, ICoord(60, vp+40), Purpose.CPBOTH);

      vp += 60;
      Button b = new Button("Refresh");
      b.setSensitive(0);
      cSet.add(b, ICoord(200, vp), Purpose.REFRESH);

      cSet.cy = vp+30;
   }

   override bool notifyHandler(Widget w, Purpose p)
   {
      focusLayout();
      if (p >= Purpose.CP1 && p <= Purpose.CPBOTH)
      {
         if ((cast(ToggleButton) w).getActive())
         {
            if (activeCP == p-Purpose.CP1)
            {
               nop = true;
               return true;
            }
            lastOp = push!int(this, activeCP, OP_IV0);
            activeCP = p-Purpose.CP1;
         }
         return true;
      }
      switch (p)
      {
      case Purpose.PATTERN:
         int n = (cast(ComboBoxText) w).getActive();
         if (pattern == n)
         {
            nop = true;
            return false;
         }
         lastOp = push!int(this, pattern, OP_CHOICE);
         pattern = n;
         if (!(pattern == 1 || pattern ==2))
         {
            cSet.disable(Purpose.CP1);
            cSet.disable(Purpose.CP2);
            cSet.disable(Purpose.CPBOTH);
         }
         if (pattern == 0)
         {
            cSet.disable(Purpose.REFRESH);
            figureMeander();
         }
         else if (pattern == 1  || pattern == 2)
         {
            cSet.enable(Purpose.CP1);
            cSet.enable(Purpose.CP2);
            cSet.enable(Purpose.CPBOTH);
            cSet.disable(Purpose.REFRESH);
            doubled = (pattern == 2);
            figureWaves();
         }
         else
         {
            cSet.enable(Purpose.REFRESH);
            figureConfusion();
         }
         break;
      case Purpose.REFRESH:
         if (cSet.control)
            instanceSeed--;
         else
            instanceSeed++;
         figureConfusion();
         break;
      default:
         return false;
      }
      return true;
   }

   override bool undoHandler(CheckPoint cp)
   {
      return false;
   }

   void figureWaves()
   {
      bool wmost = (width > height);
      if (wmost)
      {
         slh = cast(double) width/baseN-2*inset;
         nh = baseN;
         nv = 1+to!int(floor(height/slh));
         slv = height/nv;
         sd = 0.05*height;
      }
      else
      {
         slv = cast(double) height/baseN-2*inset;
         nv = baseN;
         nh = to!int(floor(width/slv));
         slh = width/nh;
         sd = 0.05*width;
      }
      bsh = BSegment(slh, inset, sd, false, doubled);
      bsv = BSegment(slv, inset, sd, true, doubled);
   }

   static pure void moveCoord(ref Coord p, double distance, double angle)
   {
      p.x += cos(angle)*distance;
      p.y -= sin(angle)*distance;
   }

   override void onCSCompass(int instance, double angle, bool coarse)
   {
      //lastOp = push!(Coord[])(this, oPath, OP_REDRAW);
      double d = coarse? 2: 0.5;
      Coord dummy = Coord(0,0);
      moveCoord(dummy, d, angle);
      if (activeCP == 0)
      {
         bsh.cp10.x += dummy.x;
         bsh.cp10.y += dummy.y;
         bsh.cp11.x -= dummy.x;
         bsh.cp11.y -= dummy.y;
         bsv.cp10.x += dummy.x;
         bsv.cp10.y += dummy.y;
         bsv.cp11.x -= dummy.x;
         bsv.cp11.y -= dummy.y;
      }
      if (activeCP == 1)
      {
         bsh.cp20.x += dummy.x;
         bsh.cp20.y += dummy.y;
         bsh.cp21.x -= dummy.x;
         bsh.cp21.y -= dummy.y;
         bsv.cp20.x += dummy.x;
         bsv.cp20.y += dummy.y;
         bsv.cp21.x -= dummy.x;
         bsv.cp21.y -= dummy.y;
      }
      if (activeCP == 2)
      {
         bsh.cp10.x += dummy.x;
         bsh.cp10.y += dummy.y;
         bsh.cp11.x -= dummy.x;
         bsh.cp11.y -= dummy.y;
         bsh.cp20.x += dummy.x;
         bsh.cp20.y += dummy.y;
         bsh.cp21.x -= dummy.x;
         bsh.cp21.y -= dummy.y;
         bsv.cp10.x += dummy.x;
         bsv.cp10.y += dummy.y;
         bsv.cp11.x -= dummy.x;
         bsv.cp11.y -= dummy.y;
         bsv.cp20.x += dummy.x;
         bsv.cp20.y += dummy.y;
         bsv.cp21.x -= dummy.x;
         bsv.cp21.y -= dummy.y;
      }
      //figureWaves();
      reDraw();
   }

   void figureMeander()
   {
      bool landscape = false;
      double least = (width > height)? landscape = true, height: width;
      least -= 2*inset;
      double most = landscape? width-2*inset: height-2*inset;
      unit = least/(4*mssn);
      if (landscape)
      {
         nmv = mssn;
         mvinset = inset;
         double t = most/(unit*4);
         nmh = to!int(floor(t));
         mhinset = (1.0*width-nmh*4*unit)/2;
      }
      else
      {
         nmh = mssn;
         mhinset = inset;
         double t = most/(unit*4);
         nmv = to!int(floor(t));
         mvinset = (1.0*height-nmv*4*unit)/2;
      }
   }

   void figureConfusion()
   {
      for (int i = 0; i < 4; i++)
         corners[i].length = cssn;
      double least = (width > height)? height: width;
      cunit = 0.2*least;
      double half = 0.5*cunit;
      oPath.length = cssn;
      oPath[0] = Coord(-half, half);
      oPath[$-1] = Coord(half, -half);
      gen.seed(instanceSeed);
      for (size_t i = 1; i < cssn-1; i++)
      {
         double x = uniform(0, cunit, gen);
         double y = uniform(0, cunit, gen);
         oPath[i] = Coord(-half+x, -half+y);
      }
      Coord[] t, t1;
      t.length = cssn;
      t1.length = cssn;
      t[] = oPath[];
      foreach (ref Coord c; t)
         c.x += half+inset, c.y += half+inset;
      corners[0][] = t[];
      t[] = oPath[];
      tm.init(-1.0, 0.0, 0.0, 1.0, 0.0, 0.0);  // horizontal flip
      foreach (int i, ref Coord c; t)
      {
         tm.transformPoint(c.x, c.y);
         t1[i].x=c.x, t1[i].y =c.y;
         c.x += half+width-cunit-inset, c.y += half+inset;
      }
      corners[1][] = t;
      tm.init(1.0, 0.0, 0.0, -1.0, 0.0, 0.0);  // vertical flip
      foreach (ref Coord c; t1)
      {
         tm.transformPoint(c.x, c.y);
         c.x += half+width-cunit-inset, c.y += half+height-cunit-inset;
      }
      corners[2][] = t1[];
      t[] = oPath[];
      tm.init(1.0, 0.0, 0.0, -1.0, 0.0, 0.0);  // vertical flip
      foreach (int i, ref Coord c; t)
      {
         tm.transformPoint(c.x, c.y);
         c.x += half+inset, c.y += half+height-cunit-inset;
      }
      corners[3][] = t[];
   }

   override void onCSMoreLess(int id, bool more, bool quickly)
   {
      focusLayout();
      if (id == 0)
      {
         double result = inset;
         if (!molA!double(more, quickly, result, 1, 0, 0.5*width))
            return;
         lastOp = pushC!double(this, inset, OP_OUTER);
         inset = result;
         if (pattern == 0)
            figureMeander();
         else if (pattern == 3)
            figureConfusion();
         else
            figureWaves();
      }
      else
      {
         int result;
         switch (pattern)
         {
            case 0:
               result = mssn;
               if (!molA!int(more, quickly, result, 1, 3, 30))
                  return;
               lastOp = pushC!int(this, mssn, OP_IV0);
               mssn = result;
               figureMeander();
               break;
            case 1:
            case 2:
               result = baseN;
               if (!molA!int(more, quickly, result, 1, 3, 500))
                  return;
               lastOp = pushC!int(this, baseN, OP_IV1);
               baseN = result;
               figureWaves();
               break;
            case 3:
               result = cssn;
               if (!molA!int(more, quickly, result, 1, 3, 30))
                  return;
               lastOp = pushC!int(this, mssn, OP_IV2);
               cssn = result;
               figureConfusion();
               break;
            default:
               return;
         }
      }
      aw.dirty = true;
      reDraw();
   }

   void renderWavy(Context c)
   {
      c.translate(hOff, vOff);
      c.setLineWidth(lineWidth);
      c.setLineJoin(CairoLineJoin.MITER);
      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);

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
   }

   void renderMeander(Context c)
   {
      c.translate(hOff, vOff);
      c.setLineWidth(lineWidth);
      c.setLineJoin(CairoLineJoin.MITER);
      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);

      double x = mhinset;
      double y = height-mvinset;

      c.moveTo(x+4*unit, y);
      c.lineTo(x, y);
      for (int i = 0; i < nmv-1; i++)
      {
         c.lineTo(x, y-3*unit);
         c.lineTo(x+2*unit, y-3*unit);
         c.lineTo(x+2*unit, y-2*unit);
         c.lineTo(x+unit, y-2*unit);
         c.lineTo(x+unit, y-unit);
         c.lineTo(x+3*unit, y-unit);
         c.lineTo(x+3*unit, y-4*unit);
         c.lineTo(x, y-4*unit);
         y -= 4*unit;
      }
      //c.stroke();

      //c.moveTo(x, y);
      y -= 4*unit;
      c.lineTo(x, y);
      for (int i = 0; i < nmh-1; i++)
      {
         c.lineTo(x+3*unit, y);
         c.lineTo(x+3*unit, y+2*unit);
         c.lineTo(x+2*unit, y+2*unit);
         c.lineTo(x+2*unit, y+unit);
         c.lineTo(x+unit, y+unit);
         c.lineTo(x+unit, y+3*unit);
         c.lineTo(x+4*unit, y+3*unit);
         c.lineTo(x+4*unit, y);
         x += 4*unit;
      }
      //c.stroke();

      //c.moveTo(x, y);
      x += 4*unit;
      c.lineTo(x, y);
      for (int i = 0; i < nmv-1; i++)
      {
         c.lineTo(x, y+3*unit);
         c.lineTo(x-2*unit, y+3*unit);
         c.lineTo(x-2*unit, y+2*unit);
         c.lineTo(x-unit, y+2*unit);
         c.lineTo(x-unit, y+unit);
         c.lineTo(x-3*unit, y+unit);
         c.lineTo(x-3*unit, y+4*unit);
         c.lineTo(x, y+4*unit);
         y += 4*unit;
      }
      //c.stroke();

      //c.moveTo(x, y);
      y += 4*unit;
      c.lineTo(x, y);
      for (int i = 0; i < nmh-1; i++)
      {
         c.lineTo(x-3*unit, y);
         c.lineTo(x-3*unit, y-2*unit);
         c.lineTo(x-2*unit, y-2*unit);
         c.lineTo(x-2*unit, y-unit);
         c.lineTo(x-unit, y-unit);
         c.lineTo(x-unit, y-3*unit);
         c.lineTo(x-4*unit, y-3*unit);
         c.lineTo(x-4*unit, y);
         x -= 4*unit;
      }

      c.stroke();
   }

   void renderConfused(Context c)
   {
      c.translate(hOff, vOff);
      c.setLineWidth(lineWidth);
      c.setLineJoin(CairoLineJoin.MITER);
      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);

      Coord[] t = corners[0];
      c.moveTo(t[0].x, t[0].y);
      for (int i = 0; i < 11; i++)
         c.lineTo(t[i].x, t[i].y);
      c.lineTo(t[11].x, t[11].y);
      c.lineTo(width-inset-cunit, inset);

      t = corners[1];
      for (int i = 11; i > 0; i--)
         c.lineTo(t[i].x, t[i].y);
      c.lineTo(t[0].x, t[0].y);
      c.lineTo(width-inset, height-inset-cunit);

      t = corners[2];
      for (int i = 0; i < 11; i++)
         c.lineTo(t[i].x, t[i].y);
      c.lineTo(t[11].x, t[11].y);
      c.lineTo(inset+cunit, height-inset);

      t = corners[3];
      for (int i = 11; i > 0; i--)
         c.lineTo(t[i].x, t[i].y);
      c.lineTo(t[0].x, t[0].y);
      c.closePath();

      c.stroke();
   }

   override void render(Context c)
   {
      if (pattern == 0)
         renderMeander(c);
      else if (pattern == 3)
         renderConfused(c);
      else
         renderWavy(c);

   }
}
