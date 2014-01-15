
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module regpc;

import main;
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

class RegularPolycurve : LineSet
{
   static int nextOid = 0;
   PathItem[] pcPath, pcRPath;
   int sides;
   bool alternating;
   double target, maxTarget, inner, outer, cangle, laglead, prop;
   Purpose cpos;
   Label numSides;

   override void syncControls()
   {
      cSet.setLineParams(lineWidth);
      cSet.toggling(false);
      cSet.setToggle(cpos, true);
      cSet.setToggle(Purpose.ASSTAR, alternating);
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
      cSet.setLabel(Purpose.LINEWIDTH, formatLT(lineWidth));
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(RegularPolycurve other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      altColor = other.altColor.copy();
      lineWidth = other.lineWidth;
      sides = other.sides;
      target = other.target;
      maxTarget = other.maxTarget;
      inner = other.inner;
      outer = other.outer;
      cangle = other.cangle;
      laglead= other.laglead;
      prop = other.prop;
      alternating = other.alternating;
      constructBase();
      les = other.les;
      fill = other.fill;
      solid = other.solid;
      center = other.center;
      pcPath = other.pcPath.dup;
      xform = other.xform;
      tf = other.tf;
      syncControls();
      dirty = true;
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Regular Polycurve "~to!string(++nextOid);
      super(w, parent, s, AC_REGPOLYCURVE);
      altColor = new RGBA(0,0,0,1);
      les  = true;
      if (width > height)
      {
         target = 0.1*height;
         maxTarget = height;
      }
      else
      {
         target = 0.1*width;
         maxTarget = width;
      }
      inner = 0;
      outer = target*10;
      cangle = 0;
      laglead = 0;
      cpos = Purpose.C11;
      alternating = false;
      prop = 0.2;
      center.x = width/2;
      center.y = height/2;
      sides = w.config.polySides;
      lineWidth = 0.5;
      constructBase();
      tm = new Matrix(&tmData);

      setupControls(3);
      positionControls(true);
   }

   override void extendControls()
   {
      int vp = cSet.cy;

      Label l = new Label("Lobes:");
      cSet.add(l, ICoord(165, vp-38), Purpose.LABEL);
      new MoreLess(cSet, 0, ICoord(275, vp-38), true);
      numSides = new Label("6");
      cSet.add(numSides, ICoord(310, vp-38), Purpose.LABEL);

      l = new Label("Target Radius");
      cSet.add(l, ICoord(165, vp-18), Purpose.LABEL);
      new MoreLess(cSet, 1, ICoord(275, vp-18), true);

      l = new Label("Outer Control");
      cSet.add(l, ICoord(165, vp+2), Purpose.LABEL);
      new MoreLess(cSet, 2, ICoord(275, vp+2), true);

      l = new Label("Inner Control");
      cSet.add(l, ICoord(165, vp+22), Purpose.LABEL);
      new MoreLess(cSet, 3, ICoord(275, vp+22), true);

      l = new Label("Control Spread");
      cSet.add(l, ICoord(165, vp+42), Purpose.LABEL);
      new MoreLess(cSet, 4, ICoord(275, vp+42), true);

      l = new Label("Lag/Lead Angle");
      cSet.add(l, ICoord(165, vp+62), Purpose.LABEL);
      new MoreLess(cSet, 5, ICoord(275, vp+62), true);

      new InchTool(cSet, 0, ICoord(0, vp+5), true);


      l = new Label("Control Points");
      cSet.add(l, ICoord(0, vp+82), Purpose.LABEL);
      RadioButton cpg = new RadioButton("00");
      cSet.add(cpg, ICoord(160, vp+82), Purpose.C00);
      RadioButton gm = new RadioButton(cpg, "01");
      cSet.add(gm, ICoord(200, vp+82), Purpose.C01);
      gm = new RadioButton(cpg, "10");
      cSet.add(gm, ICoord(240, vp+82), Purpose.C10);
      gm = new RadioButton(cpg, "11");
      cSet.add(gm, ICoord(280, vp+82), Purpose.C11);


      vp += 105;
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
      cSet.add(cbb, ICoord(165, vp), Purpose.XFORMCB);
      new MoreLess(cSet, 6, ICoord(275, vp+5), true);

      vp += 33;
      CheckButton check = new CheckButton("Alternating");
      cSet.add(check, ICoord(0, vp), Purpose.ASSTAR);
      l = new Label("Indent");
      cSet.add(l, ICoord(165, vp), Purpose.LABEL);
      new MoreLess(cSet, 7, ICoord(275, vp), true);

      vp += 25;
      check = new CheckButton("Fill with color");
      cSet.add(check, ICoord(0, vp), Purpose.FILL);

      check = new CheckButton("Solid");
      cSet.add(check, ICoord(125, vp), Purpose.SOLID);

      Button b = new Button("Fill Color");
      cSet.add(b, ICoord(240, vp-5), Purpose.FILLCOLOR);

      cSet.cy = vp+30;
   }

   override void afterDeserialize()
   {
      constructBase();
      dirty = true;
   }

   override bool specificNotify(Widget w, Purpose wid)
   {
      focusLayout();
      switch (wid)
      {
      case Purpose.C00:
         lastOp = pushC!int(this, cpos, OP_C00);
         break;
      case Purpose.C01:
         lastOp = pushC!int(this, cpos, OP_C01);
         break;
      case Purpose.C10:
         lastOp = pushC!int(this, cpos, OP_C10);
         break;
      case Purpose.C11:
         lastOp = pushC!int(this, cpos, OP_C11);
         break;
      case Purpose.ASSTAR:
         lastOp = push!bool(this, alternating, OP_ALIGN);
         alternating = !alternating;
         return true;
      default:
         return false;
      }
      cpos = wid;
      constructBase();
      return true;
   }

   override bool specificUndo(CheckPoint cp)
   {
      switch (cp.type)
      {
      case OP_TARGET:
         inner = cp.dVal;
         break;
      case OP_INNER:
         inner = cp.dVal;
         break;
      case OP_OUTER:
         outer = cp.dVal;
         break;
      case OP_CANGLE:
         cangle = cp.dVal;
         break;
      case OP_LAGLEAD:
         laglead = cp.dVal;
         break;
      case OP_PROP:
         prop = cp.dVal;
         break;
      case OP_ALIGN:
         alternating = cp.boolVal;
         cSet.toggling(false);
         cSet.setToggle(Purpose.ASSTAR, alternating);
         cSet.toggling(false);
         break;
      case OP_C00:
      case OP_C01:
      case OP_C10:
      case OP_C11:
         cpos = cast(Purpose) cp.iVal;
         cSet.toggling(false);
         cSet.setToggle(cpos, true);
         cSet.toggling(false);
         break;
      default:
         return false;
      }
      lastOp = OP_UNDEF;
      constructBase();
      dirty = true;
      return true;;
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
         constructBase();
      }

      void doTarget()
      {
         lastOp = pushC!double(this, inner, OP_TARGET);
         double delta = 1;
         if (much) delta *= 5;
         if (more)
         {
            if (target+delta > maxTarget)
               target = maxTarget;
            else
               target += delta;
         }
         else
         {
            if (target-delta < 0)
               target = 0;
            else
               target -= delta;
         }
         constructBase();
      }

      void doOuter()
      {
         lastOp = pushC!double(this, outer, OP_OUTER);
         double delta = 1;
         if (much) delta *= 5;
         if (more)
            outer += delta;
         else
         {
            if (outer-delta < target)
               outer = target;
            else
               outer -= delta;
         }
         constructBase();
      }

      void doInner()
      {
         lastOp = pushC!double(this, inner, OP_INNER);
         double delta = 1;
         if (much) delta *= 5;
         if (more)
         {
            if (inner+delta > target)
               inner = target;
            else
               inner += delta;
         }
         else
         {
            if (inner-delta < 0)
               inner = 0;
            else
               inner -= delta;
         }
         constructBase();
      }

      void doCangle()
      {
         lastOp = pushC!double(this, cangle, OP_CANGLE);
         double delta = 0.01;
         if (much) delta *= 5;
         if (more)
         {
            if (cangle+delta > 1)
               cangle = 1;
            else
               cangle += delta;
         }
         else
         {
            if (cangle-delta < -1)
               cangle = -1;
            else
               cangle -= delta;
         }
         constructBase();
      }

      void doLagLead()
      {
         lastOp = pushC!double(this, laglead, OP_LAGLEAD);
         double delta = 0.01;
         if (much) delta *= 5;
         if (more)
         {
            if (laglead+delta > 1)
               laglead = 1;
            else
               laglead += delta;
         }
         else
         {
            if (laglead-delta < -1)
               laglead = -1;
            else
               laglead -= delta;
         }
         constructBase();
      }

      void doProp()
      {
         lastOp = pushC!double(this, prop, OP_PROP);
         double delta = 0.01;
         if (much) delta *= 5;
         if (more)
         {
            if (prop+delta > 1)
               prop = 1;
            else
               prop += delta;
         }
         else
         {
            if (prop-delta < 0.05)
               prop = 0.05;
            else
               prop -= delta;
         }
         constructBase();
      }

      switch (instance)
      {
         case 0:
            doSides();
            break;
         case 1:
            doTarget();
            break;
         case 2:
            doOuter();
            break;
         case 3:
            doInner();
            break;
         case 4:
            doCangle();
            break;
         case 5:
            doLagLead();
            break;
         case 6:
            modifyTransform(xform, more, much);
            dirty = true;
            break;
         case 7:
            doProp();
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
      int side = 0;
      double theta = (PI*2)/sides;
      double a = 0;
      double ra = cangle*theta;
      double ll = laglead*theta;
      bool c1out = (cpos == Purpose.C10 || cpos == Purpose.C11);
      bool c2out = (cpos == Purpose.C01 || cpos == Purpose.C11);
      double p = alternating? prop: 1;

      bool alt()
      {
         if (!alternating)
            return false;
         return (!(sides & 1) && !(side & 1));
      }

      pcPath.length = sides;
      pcPath[0].start.x = (alt? 1: p)*target*cos(a);
      pcPath[0].start.y = (alt? 1: p)*target*sin(a);
      if (c1out)
      {
         pcPath[0].cp1.x = outer*cos(a+ra+ll);
         pcPath[0].cp1.y = outer*sin(a+ra+ll);
      }
      else
      {
         pcPath[0].cp1.x = inner*cos(a+ra+ll);
         pcPath[0].cp1.y = inner*sin(a+ra+ll);
      }
      for (int i = 1; i < sides; i++)
      {
         a += theta;
         if (c2out)
         {
            pcPath[i-1].cp2.x = outer*cos(a-ra+ll);
            pcPath[i-1].cp2.y = outer*sin(a-ra+ll);
         }
         else
         {
            pcPath[i-1].cp2.x = inner*cos(a-ra+ll);
            pcPath[i-1].cp2.y = inner*sin(a-ra+ll);
         }
         side++;
         pcPath[i-1].end.x = (alt? 1: p)*target*cos(a);
         pcPath[i-1].end.y = (alt? 1: p)*target*sin(a);
         pcPath[i].start.x = (alt? 1: p)*target*cos(a);
         pcPath[i].start.y = (alt? 1: p)*target*sin(a);
         if (c1out)
         {
            pcPath[i].cp1.x = outer*cos(a+ra+ll);
            pcPath[i].cp1.y = outer*sin(a+ra+ll);
         }
         else
         {
            pcPath[i].cp1.x = inner*cos(a+ra+ll);
            pcPath[i].cp1.y = inner*sin(a+ra+ll);
         }
      }
      a += theta;
      int n = pcPath.length-1;
      if (c2out)
      {
         pcPath[n].cp2.x = outer*cos(a-ra+ll);
         pcPath[n].cp2.y = outer*sin(a-ra+ll);
      }
      else
      {
         pcPath[n].cp2.x = inner*cos(a-ra+ll);
         pcPath[n].cp2.y = inner*sin(a-ra+ll);
      }
      side++;
      pcPath[n].end.x = (alt? 1: p)*target*cos(a);
      pcPath[n].end.y = (alt? 1: p)*target*sin(a);
      dirty = true;
   }

   override void transformPath(bool mValid)
   {
      pcRPath = pcPath.dup;
      for (int i = 0; i < pcRPath.length; i++)
      {
         if (mValid)
         {
            tm.transformPoint(pcRPath[i].start.x, pcRPath[i].start.y);
            tm.transformPoint(pcRPath[i].cp1.x, pcRPath[i].cp1.y);
            tm.transformPoint(pcRPath[i].cp2.x, pcRPath[i].cp2.y);
            tm.transformPoint(pcRPath[i].end.x, pcRPath[i].end.y);
         }
         pcRPath[i].start.x += center.x;
         pcRPath[i].start.y += center.y;
         pcRPath[i].cp1.x += center.x;
         pcRPath[i].cp1.y += center.y;
         pcRPath[i].cp2.x += center.x;
         pcRPath[i].cp2.y += center.y;
         pcRPath[i].end.x += center.x;
         pcRPath[i].end.y += center.y;
      }
   }

   override void render(Context c)
   {
      c.setAntialias(cairo_antialias_t.SUBPIXEL);
      c.setLineWidth(lineWidth);
      c.setLineJoin(les? CairoLineJoin.MITER: CairoLineJoin.ROUND);
      if (dirty)
      {
         transformPath(compoundTransform());
         dirty = false;
      }
      c.moveTo(hOff+pcRPath[0].start.x, vOff+pcRPath[0].start.y);
      for (int i = 0; i < pcRPath.length; i++)
      {
         c.curveTo(hOff+pcRPath[i].cp1.x, vOff+pcRPath[i].cp1.y, hOff+pcRPath[i].cp2.x, vOff+pcRPath[i].cp2.y, hOff+pcRPath[i].end.x, vOff+pcRPath[i].end.y);
      }
      c.closePath();
      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);
      if (!(solid || fill))
         c.stroke();
      else
         doFill(c, solid, fill);
      if (!isMoved) cSet.setDisplay(0, reportPosition());
   }
}
