
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module random;

import container;
import mainwin;
import constants;
import acomp;
import common;
import types;
import controlset;
import lineset;

import std.stdio;
import std.math;
import std.random;
import std.conv;

import gtk.Widget;
import gtk.Label;
import gtk.Button;
import gtk.CheckButton;
import gtk.SpinButton;
import gtk.ComboBoxText;
import gdk.RGBA;
import cairo.Context;
import cairo.Matrix;
import gtkc.cairotypes;
import cairo.Surface;

class Random: LineSet
{
   static int nextOid = 0;
   static Coord[7] crd = [ Coord(0, 0.666), Coord(-1.2, -0.1), Coord(-0.5, -1.1), Coord(0, -0.333),
                           Coord(0.5, -1.1), Coord(1.2, -0.1), Coord(0, 0.666) ];
   int lowerPc, upperPc;
   double lower, upper;
   int count;
   int element;
   ShapeInfo[] si;
   bool reBuild, printRandom;
   Label countLabel, minSize, maxSize;

   override void syncControls()
   {
      cSet.setLineParams(lineWidth);
      cSet.toggling(false);
      cSet.setComboIndex(Purpose.PATTERN, element);
      if (printRandom)
         cSet.setToggle(Purpose.PRINTRANDOM, true);
      cSet.setLabel(Purpose.LINEWIDTH, formatLT(lineWidth));
      cSet.toggling(true);
      cSet.setHostName(name);
      minSize.setText(to!string(lowerPc));
      maxSize.setText(to!string(upperPc));
   }

   this(Random other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      lowerPc = other.lowerPc;
      upperPc = other.upperPc;
      lower = other.lower;
      upper = other.upper;
      lineWidth = other.lineWidth;
      printRandom = other.printRandom;
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Random "~to!string(++nextOid);
      super(w, parent, s, AC_RANDOM);
      group = ACGroups.EFFECTS;
      closed = true;
      hOff = vOff = 0;
      lowerPc = 10;
      upperPc = 40;
      lower = 0.1;
      upper = 0.4;
      lineWidth = 0.5;
      count = 20;
      reBuild = true;
      tm = new Matrix(&tmData);
      fill = true;
      outline = true;

      setupControls();
      positionControls(true);
   }

   override void extendControls()
   {
      int vp = cSet.cy;

      Label t = new Label("Count");
      cSet.add(t, ICoord(215, vp-10), Purpose.LABEL);
      new MoreLess(cSet, 0, ICoord(285, vp-10), true);
      countLabel = new Label("20");
      cSet.add(countLabel, ICoord(320, vp-10), Purpose.LABEL);

      new InchTool(cSet, 0, ICoord(0, vp), true);

      vp += 10;
      t = new Label("Min size%");
      cSet.add(t, ICoord(215, vp), Purpose.LABEL);
      new MoreLess(cSet, 1, ICoord(285, vp), true);
      minSize = new Label(to!string(lowerPc));
      cSet.add(minSize, ICoord(320, vp), Purpose.LABEL);

      vp += 20;
      t = new Label("Max size%");
      cSet.add(t, ICoord(215, vp), Purpose.LABEL);
      new MoreLess(cSet, 2, ICoord(285, vp), true);
      maxSize = new Label(to!string(upperPc));
      cSet.add(maxSize, ICoord(320, vp), Purpose.LABEL);

      vp += 20;
      ComboBoxText cb = new ComboBoxText(false);
      cb.appendText("Bubbles");
      cb.appendText("Hearts");
      cb.appendText("Shards");
      cb.setSizeRequest(120, -1);
      cb.setActive(0);
      cSet.add(cb, ICoord(0, vp), Purpose.PATTERN);

      Button b = new Button("Regenerate");
      cSet.add(b, ICoord(215, vp+3), Purpose.MORE);

      vp += 25;
      CheckButton check = new CheckButton("Print random");
      cSet.add(check, ICoord(213, vp), Purpose.PRINTRANDOM);

      cSet.cy = vp+25;
   }

   override bool specificNotify(Widget w, Purpose wid)
   {
      focusLayout();
      switch (wid)
      {
      case Purpose.PATTERN:
         element = (cast(ComboBoxText) w).getActive();
         if (element == 0 || element == 2)
         {
            fill = true;
            cSet.toggling(false);
            cSet.setToggle(Purpose.FILL, true);
            cSet.toggling(true);
         }
         else
         {
            fill = false;
            cSet.toggling(false);
            cSet.setToggle(Purpose.FILL, false);
            cSet.toggling(true);
         }
         break;
      case Purpose.PRINTRANDOM:
         printRandom = !printRandom;
         break;
      case Purpose.MORE:
         break;
      default:
         return false;
      }
      reBuild = true;
      return true;
   }

   override void onCSMoreLess(int instance, bool more, bool coarse)
   {
      if (instance == 0)
      {
         lastOp = pushC!int(this, count, OP_IV0);
         int d = more? 1: -1;
         if (coarse) d *= 3;
         count += d;
         countLabel.setText(to!string(count));
      }
      else if (instance == 1)
      {
         lastOp = pushC!int(this, lowerPc, OP_IV1);
         int d = 5;
         if (more)
         {
            if (lowerPc < upperPc-d)
               lowerPc += d;
         }
         else
         {
            if (lowerPc > 5)
               lowerPc -= d;
         }
         minSize.setText(to!string(lowerPc));
         lower = 0.01*lowerPc;
      }
      else
      {
         lastOp = pushC!int(this, upperPc, OP_IV2);
         int d = 5;
         if (more)
         {
            if (upperPc < 100)
               upperPc += d;
         }
         else
         {
            if (upperPc > lowerPc+5)
               upperPc -= d;
         }
         maxSize.setText(to!string(upperPc));
         upper = 0.01*upperPc;
      }
      reBuild = true;
      aw.dirty = true;
      reDraw();
   }

   override bool specificUndo(CheckPoint cp)
   {
      switch (cp.type)
      {
      case OP_IV0:
         count = cp.iVal;
         countLabel.setText(to!string(count));
         lastOp = OP_UNDEF;
         break;
      case OP_IV1:
         lowerPc = cp.iVal;
         lower = 0.01*lowerPc;
         minSize.setText(to!string(lowerPc));
         lastOp = OP_UNDEF;
         break;
      case OP_IV2:
         upperPc = cp.iVal;
         upper = 0.01*upperPc;
         maxSize.setText(to!string(upperPc));
         lastOp = OP_UNDEF;
         break;
      default:
         return false;
      }
      reBuild = true;
      return true;
   }

   void build()
   {
      if (!printRandom && !reBuild)
         return;
      auto gen = Xorshift(unpredictableSeed());
      si.length = count;
      if (element == 0)
      {
         for (int i = 0; i < count; i++)
         {
            si[i].c1 = uniform(cast(float) lower, cast(float) upper, gen)/2;
            si[i].c2 = uniform(cast(float) 0, cast(float) width, gen);
            si[i].c3 = uniform(cast(float) 0, cast(float) height, gen);
         }
      }
      else if (element == 1)
      {
         for (int i = 0; i < count; i++)
         {
            si[i].c1 = uniform(cast(float) lower, cast(float) upper, gen)/2;
            si[i].c2 = uniform(cast(float) 0, cast(float) 2*PI, gen);
            si[i].c3 = uniform(cast(float) 0, cast(float) width, gen);
            si[i].c4 = uniform(cast(float) 0, cast(float) height, gen);
         }
      }
      else
      {
         for (int i = 0; i < count; i++)
         {
            si[i].c1 = uniform(cast(float) 0, cast(float) width, gen);
            si[i].c2 = uniform(cast(float) 0, cast(float) height, gen);
            si[i].c3 = uniform(cast(float) -upper, cast(float) upper, gen)/2;
            si[i].c4 = uniform(cast(float) -upper, cast(float) upper, gen)/2;
            si[i].c5 =uniform(cast(float) -upper, cast(float) upper, gen)/2;
            si[i].c6 =uniform(cast(float) -upper, cast(float) upper, gen)/2;
         }
      }
      reBuild = false;
   }

   override void render(Context c)
   {
      build();
      c.setLineWidth(lineWidth);
      double r = baseColor.red();
      double g = baseColor.green();
      double b = baseColor.blue();
      if (element == 0)
      {
         altColor.alpha(0.5);
         foreach (ShapeInfo t; si)
         {
            c.arc(hOff+t.c2, vOff+t.c3, t.c1*height, 0, 2*PI);
            strokeAndFill(c, lineWidth, outline, fill);
         }
      }
      else if (element == 1)
      {
         foreach (ShapeInfo s; si)
         {
            Coord[7] t;
            t[] = (crd)[];
            for (int i = 0; i < 7; i++)
            {
               t[i].x *= s.c1*height;
               t[i].y *= s.c1*height;
            }
            tm.initRotate (s.c2);
            for (int i = 0; i < 7; i++)
               tm.transformPoint(t[i].x, t[i].y);
            for (int i = 0; i < 7; i++)
            {
               t[i].x += s.c3;
               t[i].y += s.c4;
            }

            c.moveTo(hOff+t[0].x, vOff+t[0].y);
            c.curveTo(hOff+t[1].x, vOff+t[1].y,     hOff+t[2].x, vOff+t[2].y,     hOff+t[3].x, vOff+t[3].y);
            c.curveTo(hOff+t[4].x, vOff+t[4].y,    hOff+t[5].x, vOff+t[5].y,     hOff+t[6].x, vOff+t[6].y);
            c.closePath();
            strokeAndFill(c, lineWidth, outline, fill);
         }
      }
      else
      {
         altColor.alpha(0.5);
         foreach (ShapeInfo t; si)
         {
            double x = hOff+t.c1;
            double y = vOff+t.c2;
            c.moveTo(x, y);
            c.lineTo(x+t.c3*height, y+t.c4*height);
            c.lineTo(x+t.c5*height, y+t.c6*height);
            c.closePath();
            strokeAndFill(c, lineWidth, outline, fill);
         }
      }
   }

}
