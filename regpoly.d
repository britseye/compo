
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module regpoly;

import mainwin;
import config;
import constants;
import acomp;
import common;
import types;
import controlset;
import lineset;

import std.stdio;
import std.math;
import std.conv;

import gtk.DrawingArea;
import gtk.Widget;
import gtk.Button;
import gtk.Layout;
import gtk.Frame;
import gdk.RGBA;
import gtk.ComboBoxText;
import gtk.SpinButton;
import gtk.RadioButton;
import gtk.CheckButton;
import gtk.Label;
import cairo.Context;
import gtkc.cairotypes;
import cairo.Matrix;

class RegularPolygon : LineSet
{
   static int nextOid = 0;
   int sides;
   bool isStar;
   double radius, starIndent;
   Label numSides;

   override void syncControls()
   {
      cSet.setLineParams(lineWidth);
      cSet.toggling(false);
      if (les)
         cSet.setToggle(Purpose.LESSHARP, true);
      else
         cSet.setToggle(Purpose.LESROUND, true);
      if (solid)
      {
         cSet.setToggle(Purpose.SOLID, true);
         cSet.disable(Purpose.FILL);
         cSet.disable(Purpose.FILLCOLOR);
      }
      else if (fill)
         cSet.setToggle(Purpose.FILL, true);
      cSet.setComboIndex(Purpose.XFORMCB, xform);
      if (isStar)
         cSet.setToggle(Purpose.ASSTAR, true);
      cSet.setLabel(Purpose.LINEWIDTH, formatLT(lineWidth));
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(RegularPolygon other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      altColor = other.altColor.copy();
      lineWidth = other.lineWidth;
      sides = other.sides;
      radius = other.radius;
      les = other.les;
      isStar = other.isStar;
      starIndent = other.starIndent;
      fill = other.fill;
      solid = other.solid;
      center = other.center;
      oPath = other.oPath.dup;
      xform = other.xform;
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Regular Polygon "~to!string(++nextOid);
      super(w, parent, s, AC_REGPOLYGON);
      group = ACGroups.GEOMETRIC;
      altColor = new RGBA(1,1,1,1);
      les  = true;
      radius = cast(double) height/2-20;
      starIndent = 0.3;
      center.x = 0.5*width;
      center.y = 0.5*height;
      sides = w.config.polySides;
      constructBase();
      tm = new Matrix(&tmData);

      setupControls(3);
      positionControls(true);
   }

   override void extendControls()
   {
      int vp = cSet.cy;

      Label l = new Label("Sides:");
      cSet.add(l, ICoord(165, vp-38), Purpose.LABEL);
      new MoreLess(cSet, 0, ICoord(265, vp-38), true);
      numSides = new Label("6");
      cSet.add(numSides, ICoord(300, vp-38), Purpose.LABEL);

      new InchTool(cSet, 0, ICoord(0, vp+5), true);

      ComboBoxText cbb = new ComboBoxText(false);
      cbb.setTooltipText("Select transformation to apply");
      cbb.setSizeRequest(100, -1);
      cbb.appendText("Scale");
      cbb.appendText("Stretch-H");
      cbb.appendText("Stretch-V");
      cbb.appendText("Skew-H");
      cbb.appendText("Skew-V");
      cbb.appendText("Rotate");
      cbb.appendText("Flip-H");
      cbb.appendText("Flip-V");
      cbb.setActive(0);
      cSet.add(cbb, ICoord(165, vp+3), Purpose.XFORMCB);
      new MoreLess(cSet, 1, ICoord(265, vp+5), true);

      vp += 40;

      CheckButton check = new CheckButton("Render as star");
      cSet.add(check, ICoord(0, vp), Purpose.ASSTAR);

      l = new Label("Star Indent");
      cSet.add(l, ICoord(166, vp), Purpose.LABEL);
      new MoreLess(cSet, 2, ICoord(265, vp), true);
      vp += 25;

      check = new CheckButton("Fill with color");
      cSet.add(check, ICoord(0, vp), Purpose.FILL);

      check = new CheckButton("Solid");
      cSet.add(check, ICoord(125, vp), Purpose.SOLID);

      Button b = new Button("Fill Color");
      cSet.add(b, ICoord(240, vp-5), Purpose.FILLCOLOR);

      cSet.cy = vp+30;
   }

   override bool specificNotify(Widget w, Purpose wid)
   {
      focusLayout();
      switch (wid)
      {
      case Purpose.ASSTAR:
         isStar = !isStar;
         constructBase();
         return true;
      default:
         return false;
      }
   }

   override void onCSMoreLess(int instance, bool more, bool much)
   {
      focusLayout();
      int direction = more? 1: -1;

      void doSides()
      {
         lastOp = pushC!int(this, sides, OP_IV1);
         if (more)
            sides++;
         else
         {
            if (sides > 3)
               sides--;
         }
         numSides.setText(to!string(sides));
         if (sides & 1)
         {
            cSet.disable(Purpose.ASSTAR);
            cSet.disable(Purpose.MOL, 2);
         }
         else
         {
            cSet.enable(Purpose.ASSTAR);
            cSet.enable(Purpose.MOL, 2);
         }
         constructBase();
      }

      void doIndent()
      {
         lastOp = pushC!double(this, starIndent, OP_DV1);
         if (more)
         {
            if (starIndent < 1.0)
               starIndent += 0.05;
         }
         else
         {
            if (starIndent > 0.05)
               starIndent -= 0.05;
         }
         constructBase();
      }

      switch (instance)
      {
         case 0:
            doSides();
            break;
         case 1:
            modifyTransform(xform, more, much);
            dirty = true;
            break;
         case 2:
            doIndent();
            break;
         default:
            return;
      }

      aw.dirty = true;
      reDraw();
   }

   override void preResize(int oldW, int oldH)
   {
      center.x = width/2;
      center.y = height/2;
      double hr = cast(double) width/oldW;
      double vr = cast(double) height/oldH;
      tm.initScale(hr, vr);
      for (int i = 0; i < oPath.length; i++)
      {
         tm.transformPoint(oPath[i].x, oPath[i].y);
      }
      hOff *= hr;
      vOff *= vr;
   }

   void constructBase()
   {
      double theta = (PI*2)/sides;
      oPath.length = sides;
      oPath[0].x = center.x+radius;
      oPath[0].y = center.y;
      double a = 0;
      for (int i = 1; i < sides; i++)
      {
         a += theta;
         double r = radius;
         if (isStar && !(sides & 1) && (i & 1))
            r = radius*starIndent;
         oPath[i].x = center.x+r*cos(a);
         oPath[i].y = center.y+r*sin(a);
      }
   }

   override void render(Context c)
   {
      c.setAntialias(cairo_antialias_t.SUBPIXEL);
      double r = baseColor.red;
      double g = baseColor.green;
      double b = baseColor.blue;
      c.setLineWidth(0);
      c.setLineJoin(les? CairoLineJoin.MITER: CairoLineJoin.ROUND);

      c.translate(hOff+center.x, vOff+center.y);
      if (compoundTransform())
         c.transform(tm);
      c.translate(-center.x, -center.y);

      c.moveTo(oPath[0].x, oPath[0].y);
      for (int i = 1; i < oPath.length; i++)
         c.lineTo(oPath[i].x, oPath[i].y);
      c.closePath();
      strokeAndFill(c, lineWidth, solid, fill);
   }
}


