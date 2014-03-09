
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

class LineBorders: LineSet
{
   static int nextOid = 0;
   Coord[][4] corners;
   bool doubled;
   double slh, slv, sd, inset, unit, mhinset, mvinset, cunit, cf;
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
      cf = 1;
      instanceSeed = 42;

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
      cSet.add(cbb, ICoord(0, vp+30), Purpose.PATTERN);
      Label l = new Label("Curvature");
      cSet.add(l, ICoord(0, vp+65), Purpose.LABEL);
      new MoreLess(cSet, 0, ICoord(110, vp+65), true);
      l = new Label("Inset");
      cSet.add(l, ICoord(200, vp+30), Purpose.LABEL);
      new MoreLess(cSet, 1, ICoord(295, vp+30), true);
      l = new Label("Items per Side");
      cSet.add(l, ICoord(200, vp+50), Purpose.LABEL);
      new MoreLess(cSet, 2, ICoord(295, vp+50), true);

      vp += 70;
      Button b = new Button("Refresh");
      b.setSensitive(0);
      cSet.add(b, ICoord(200, vp), Purpose.REFRESH);

      cSet.cy = vp+30;
   }

   override bool notifyHandler(Widget w, Purpose p)
   {
      focusLayout();
      switch (p)
      {
      case Purpose.PATTERN:
         int n = (cast(ComboBoxText) w).getActive();
         if (pattern == n)
         {
            nop = true;
            return true;
         }
         lastOp = push!int(this, pattern, OP_CHOICE);
         pattern = n;
         if (pattern == 0)
         {
            cSet.disable(Purpose.REFRESH);
            figureMeander();
         }
         else if (pattern == 1  || pattern == 2)
         {
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

   void goFigure()
   {
      if (pattern == 0)
         figureMeander();
      else if (pattern == 3)
         figureConfusion();
      else figureWaves();
   }

   override bool undoHandler(CheckPoint cp)
   {
      switch (cp.type)
      {
      case OP_OUTER:
         inset = cp.dVal;
         goFigure();
         break;
      case OP_DV0:
         cf = cp.dVal;
         break;
      case OP_IV0:
         mssn = cp.iVal;
         figureMeander();
         break;
      case OP_IV1:
         baseN = cp.iVal;
         figureWaves();
         break;
      case OP_IV2:
         cssn = cp.iVal;
         figureConfusion();
         break;
      case OP_CHOICE:
         pattern = cp.iVal;
         cSet.setComboIndex(Purpose.PATTERN, pattern);
         goFigure();
         break;
      default:
         return false;
      }
      lastOp = OP_UNDEF;
      return true;
   }

   void figureWaves()
   {
      bool wmost = (width > height);
      if (wmost)
      {
         sd = 0.05*height;
         double margin = 2*inset;
         if (doubled)
            margin += sd;
         slh = (cast(double) width-margin)/baseN;
         nh = baseN;
         double t = cast (double) height-margin;
         nv = 1+to!int(floor(t/slh));
         slv = t/nv;
      }
      else
      {
         sd = 0.05*width;
         double margin = 2*inset;
         if (doubled)
            margin += sd;
         slv = (cast(double) height-margin)/baseN;
         nv = baseN;
         double t = cast (double) width-margin;
         nh = 1+to!int(floor(t/slh));
         slh = t/nh;
      }
   }

   static pure void moveCoord(ref Coord p, double distance, double angle)
   {
      p.x += cos(angle)*distance;
      p.y -= sin(angle)*distance;
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
      int n = cssn+2;
      for (int i = 0; i < 4; i++)
         corners[i].length = n;
      double least = (width > height)? height: width;
      cunit = 0.15*least;
      double half = 0.5*cunit;
      oPath.length = n;
      oPath[0] = Coord(-half, half);
      oPath[$-1] = Coord(half, -half);
      gen.seed(instanceSeed);
      for (size_t i = 1; i < n-1; i++)
      {
         double x = uniform(0, cunit, gen);
         double y = uniform(0, cunit, gen);
         oPath[i] = Coord(-half+x, -half+y);
      }
      Coord[] t, t1;
      t.length = n;
      t1.length = n;
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
         double result = cf;
         if (!molA!double(more, quickly, result, 0.01, 0, 10))
            return;
         lastOp = pushC!double(this, cf, OP_DV0);
         cf = result;
      }
      else if (id == 1)
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

      double x = inset, y = inset;
      if (doubled)
         x += 0.5*sd, y += 0.5*sd;
      c.moveTo(x, y);
      for (size_t i = 0; i < nh; i++)
      {
         c.curveTo(x+slh/2, y+sd*cf, x+slh/2, y+sd*cf, x+slh, y);
         if (doubled)
         {
            c.moveTo(x, y);
            c.curveTo(x+slh/2, y-sd*cf, x+slh/2, y-sd*cf, x+slh, y);
         }
         x += slh;
      }

      for (size_t i = 0; i < nv; i++)
      {
         c.curveTo(x-sd*cf, y+slv/2, x-sd*cf, y+slv/2, x, y+slv);
         if (doubled)
         {
            c.moveTo(x, y);
            c.curveTo(x+sd*cf, y+slv/2, x+sd*cf, y+slv/2, x, y+slv);
         }
         y += slv;
      }

      for (size_t i = 0; i < nh; i++)
      {
         c.curveTo(x-slh/2, y-sd*cf, x-slh/2, y-sd*cf, x-slh, y);
         if (doubled)
         {
            c.moveTo(x, y);
            c.curveTo(x-slh/2, y+sd*cf, x-slh/2, y+sd*cf, x-slh, y);
         }
         x -= slh;
      }

      for (size_t i = 0; i < nv; i++)
      {
         c.curveTo(x+sd*cf, y-slv/2, x+sd*cf, y-slv/2, x, y-slv);
         if (doubled)
         {
            c.moveTo(x, y);
            c.curveTo(x-sd*cf, y-slv/2, x-sd*cf, y-slv/2, x, y-slv);
         }
         y -= slv;
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

      size_t n = cssn+2;

      Coord[] t = corners[0];
      c.moveTo(t[0].x, t[0].y);
      for (int i = 0; i < n-1; i++)
         c.lineTo(t[i].x, t[i].y);
      c.lineTo(t[n-1].x, t[n-1].y);
      c.lineTo(width-inset-cunit, inset);

      t = corners[1];
      for (int i = n-1; i > 0; i--)
         c.lineTo(t[i].x, t[i].y);
      c.lineTo(t[0].x, t[0].y);
      c.lineTo(width-inset, height-inset-cunit);

      t = corners[2];
      for (int i = 0; i < n-1; i++)
         c.lineTo(t[i].x, t[i].y);
      c.lineTo(t[n-1].x, t[n-1].y);
      c.lineTo(inset+cunit, height-inset);

      t = corners[3];
      for (int i = n-1; i > 0; i--)
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
