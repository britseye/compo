
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module circle;

import main;
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
   RGBA saveAltColor;
   double radius;
   bool fill, solid;

   void syncControls()
   {
      cSet.setLineParams(lineWidth);
      cSet.toggling(false);
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

   this(Circle other)
   {
      this(other.aw, other.parent,);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      altColor = other.altColor.copy();
      lineWidth = other.lineWidth;
      radius = other.radius;
      fill = other.fill;
      solid = other.solid;
      tf = other.tf;

      xform = other.xform;
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Circle "~to!string(++nextOid);
      super(w, parent, s, AC_CIRCLE);
      hOff = vOff = 0;
      altColor = new RGBA();
      center = Coord(0.5*width, 0.5*height);
      radius = (width > height)? 0.4*height: 0.4*width;
      lineWidth = 1.0;
      tm = new Matrix(&tmData);

      setupControls();
      positionControls(true);
   }

   void extendControls()
   {
      int vp = cSet.cy;

      new InchTool(cSet, 0, ICoord(10, vp), true);

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
      new MoreLess(cSet, 0, ICoord(275, vp+5), true);

      vp+=40;
      CheckButton check = new CheckButton("Fill with color");
      cSet.add(check, ICoord(0, vp), Purpose.FILL);

      check = new CheckButton("Solid");
      cSet.add(check, ICoord(115, vp), Purpose.SOLID);

      Button b = new Button("Fill Color");
      cSet.add(b, ICoord(240, vp), Purpose.FILLCOLOR);

      cSet.cy = vp+30;
   }

   void onCSNotify(Widget w, Purpose wid)
   {
      switch (wid)
      {
      case Purpose.COLOR:
         dummy.grabFocus();
         lastOp = push!RGBA(this, baseColor, OP_COLOR);
         pushOp(lcp);
         setColor(false);
         break;
      case Purpose.FILLCOLOR:
         lastOp = push!RGBA(this, altColor, OP_ALTCOLOR);
         setColor(true);
         break;
         /*
      case Purpose.LINEWIDTH:
         lastOp = pushC!double(this, lineWidth, OP_THICK);
         lineWidth = (cast(SpinButton) w).getValue();
         break;
         */
      case Purpose.FILL:
         fill = !fill;
         break;
      case Purpose.SOLID:
         solid = !solid;
         if (solid)
         {
            cSet.disable(Purpose.FILL);
            cSet.disable(Purpose.FILLCOLOR);
         }
         else
         {
            cSet.enable(Purpose.FILL);
            cSet.enable(Purpose.FILLCOLOR);
         }
         break;
      case Purpose.XFORMCB:
         xform = (cast(ComboBoxText) w).getActive();
         break;
      default:
         break;
      }
      aw.dirty = true;
      reDraw();
   }

   override void onCSMoreLess(int instance, bool more, bool coarse)
   {
      dummy.grabFocus();
      int[] xft = [0,2,5,6,7];
      int tt = xft[xform];
      modifyTransform(tt, more, coarse);
      dirty = true;
      aw.dirty = true;
      reDraw();
   }

   void preResize(int oldW, int oldH)
   {
      double hr = cast(double) width/oldW;
      double vr = cast(double) height/oldH;
      hOff *= hr;
      vOff *= vr;
   }

   string reportPosition(int id = 0)
   {
      return formatCoord(Coord(center.x+hOff, center.y+vOff));
   }

   void render(Context c)
   {
      c.setLineWidth(lineWidth);
      c.setLineJoin(les? CairoLineJoin.MITER: CairoLineJoin.ROUND);
      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);
      c.translate(hOff+width/2, vOff+height/2);
      if (compoundTransform())
         c.transform(tm);
      c.translate(-(width/2), -(height/2));
      c.newSubPath();
      c.arc(width/2, height/2, radius, 0, PI*2);
      c.strokePreserve();
      if (solid)
      {
         // fill with same color
         c.fill();
      }
      else if (fill)
      {
         c.setSourceRgb(altColor.red, altColor.green, altColor.blue);
         c.fill();
      }
      // else don't fill at all
      if (!isMoved) cSet.setDisplay(0, reportPosition());
   }
}


