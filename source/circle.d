
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module circle;

import mainwin;
import constants;
import acomp;
import common;
import types;
import controlset;
import lineset;

import std.math;
import std.stdio;
import std.conv;

import gtk.DrawingArea;
import gtk.Widget;
import gtk.Label;
import gtk.Button;
import gtk.SpinButton;
import gtk.CheckButton;
import gtk.RadioButton;
import gtk.ToggleButton;
import gtk.Layout;
import gtk.Frame;
import gtk.Range;
import gtk.ComboBoxText;
import gdk.RGBA;
import cairo.Context;
import gtkc.cairotypes;
import cairo.Matrix;

class Circle : LineSet
{
   static int nextOid = 0;
   double radius;

   override void syncControls()
   {
      cSet.setLineParams(lineWidth);
      cSet.toggling(false);
      if (outline)
         cSet.setToggle(Purpose.OUTLINE, true);
      cSet.setComboIndex(Purpose.XFORMCB, xform);
      cSet.setComboIndex(Purpose.FILLOPTIONS, 0);
      cSet.setLabel(Purpose.LINEWIDTH, formatLT(lineWidth));
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(Circle other)
   {
      this(other.aw, other.parent,);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      altColor = other.altColor.copy();
      lineWidth = other.lineWidth;
      center = other.center;
      radius = other.radius;
      fill = other.fill;
      outline = other.outline;
      fillFromPattern = other.fillFromPattern;
      fillUid = other.fillUid;
      updateFillUI();
      tf = other.tf;

      xform = other.xform;
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Circle "~to!string(++nextOid);
      super(w, parent, s, AC_CIRCLE);
      group = ACGroups.SHAPES;
      closed = true;
      hOff = vOff = 0;
      altColor = new RGBA(0,0,0,1);
      center = Coord(0.5*width, 0.5*height);
      radius = (width > height)? 0.4*height: 0.4*width;
      tm = new Matrix(&tmData);

      setupControls();
      outline = true;
      positionControls(true);
   }

   override void extendControls()
   {
      int vp = cSet.cy;

      new InchTool(cSet, 0, ICoord(10, vp), true);

      Label l = new Label("Radius");
      cSet.add(l, ICoord(165, vp), Purpose.LABEL);
      new MoreLess(cSet, 0, ICoord(275, vp), true);

      vp += 20;
      ComboBoxText cbb = new ComboBoxText(false);
      cbb.setTooltipText("Select transformation to apply");
      cbb.setSizeRequest(100, -1);
      cbb.appendText("Scale");
      cbb.appendText("Squash");
      cbb.appendText("Rotate");
      cbb.appendText("Flip-H");
      cbb.appendText("Flip-V");
      cbb.setActive(0);
      cSet.add(cbb, ICoord(165, vp), Purpose.XFORMCB);
      new MoreLess(cSet, 1, ICoord(275, vp+5), true);

      cSet.cy = vp+40;
   }

   override bool specificUndo(CheckPoint cp)
   {
      switch (cp.type)
      {
      case OP_SIZE:
         radius = cp.dVal;
         break;
      default:
         return false;
      }
      lastOp = OP_UNDEF;
      return true;
   }

   override void onCSMoreLess(int instance, bool more, bool coarse)
   {
      focusLayout();
      if (instance == 0)
      {
         double factor = coarse? 1.2: 1.05;
         if (more)
         {
            lastOp = pushC!double(this, radius, OP_SIZE);
            radius *= factor;
         }
         else
         {
            if (radius/factor < lineWidth)
               return;
            lastOp = pushC!double(this, radius, OP_SIZE);
            radius /= factor;
         }
      }
      else
      {
         int[] xft = [0,2,5,6,7];
         int tt = xft[xform];
         modifyTransform(tt, more, coarse);
      }
      dirty = true;
      aw.dirty = true;
      reDraw();
   }

   override void preResize(int oldW, int oldH)
   {
      double hr = cast(double) width/oldW;
      double vr = cast(double) height/oldH;
      hOff *= hr;
      vOff *= vr;
   }

   override string reportPosition(int id = 0)
   {
      return formatCoord(Coord(center.x+hOff, center.y+vOff));
   }

   override void render(Context c)
   {
      c.translate(hOff+center.x, vOff+center.y);
      if (compoundTransform())
         c.transform(tm);
      c.translate(-center.x, -center.y);
      c.setLineWidth(0);
      c.setLineJoin(les? CairoLineJoin.MITER: CairoLineJoin.ROUND);
      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);
      c.newSubPath();
      c.arc(center.x, center.y, radius, 0, PI*2);
      strokeAndFill(c, lineWidth, outline, fill);
   }
}


