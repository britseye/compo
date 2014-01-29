
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module triangle;

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

class Triangle : LineSet
{
   static int nextOid = 0;
   int ttype; // Right Right, Equilateral, Isosceles
   double w, h;

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
      cSet.setLabel(Purpose.LINEWIDTH, formatLT(lineWidth));
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   override void afterDeserialize()
   {
      figurePath();
      syncControls();
   }

   this(Triangle other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      altColor = other.altColor.copy();
      center = other.center;
      w = other.w;
      h = other.h;
      lineWidth = other.lineWidth;
      les = other.les;
      ttype = other.ttype;
      fill = other.fill;
      solid = other.solid;
      tf = other.tf;

      xform = other.xform;
      syncControls();
   }

   this(AppWindow appw, ACBase parent)
   {
      string s = "Triangle "~to!string(++nextOid);
      super(appw, parent, s, AC_TRIANGLE);
      group = ACGroups.SHAPES;
      hOff = vOff = 0;
      altColor = new RGBA(1,1,1,1);
      h = 0.75*height;
      w = 0.75*width;
      center = Coord(0.5*width, 0.5*height);

      tm = new Matrix(&tmData);
      ttype = 0;

      les = cairo_line_cap_t.ROUND;
      dirty = true;

      setupControls(3);
      positionControls(true);
   }

   override void extendControls()
   {
      int vp = cSet.cy;

      ComboBoxText cbb = new ComboBoxText(false);
      cbb.setTooltipText("Select transformation to apply");
      cbb.setSizeRequest(100, -1);
      cbb.appendText("Right, Right");      // Options here limited - it's a rectangle - if you want
      cbb.appendText("Right, Left");    // a quadrilateral, use polygon.
      cbb.appendText("Equilateral");
      cbb.appendText("Isosceles");
      cbb.setActive(0);
      cSet.add(cbb, ICoord(167, vp), Purpose.PATTERN);

      new InchTool(cSet, 0, ICoord(0, vp+5), true);

      vp += 45;

      cbb = new ComboBoxText(false);
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
      cSet.add(cbb, ICoord(167, vp), Purpose.XFORMCB);
      new MoreLess(cSet, 0, ICoord(270, vp+4), true);

      vp += 40;

      CheckButton check = new CheckButton("Fill with color");
      cSet.add(check, ICoord(0, vp), Purpose.FILL);

      check = new CheckButton("Solid");
      cSet.add(check, ICoord(115, vp), Purpose.SOLID);

      Button b = new Button("Fill Color");
      cSet.add(b, ICoord(195, vp-5), Purpose.FILLCOLOR);

      cSet.cy = vp+30;
   }

   override bool specificNotify(Widget w, Purpose wid)
   {
      focusLayout();
      switch (wid)
      {
      case Purpose.PATTERN:
         ttype = (cast(ComboBoxText) w).getActive();
         dirty = true;
         break;
      default:
         return false;
      }
      return true;
   }

   override void preResize(int oldW, int oldH)
   {
      double hr = cast(double) width/oldW;
      double vr = cast(double) height/oldH;
      hOff *= hr;
      vOff *= vr;
   }

   void figurePath()
   {
      oPath.length = 3;
      switch (ttype)
      {
         case 0:  // Right, Right
            oPath[0].x = center.x+w/2;
            oPath[0].y = center.y-h/2;
            oPath[1].x = center.x+w/2;
            oPath[1].y = center.y+h/2;
            oPath[2].x = center.x-w/2;
            oPath[2].y = center.y+h/2;
            break;
         case 1:  // Right, Left
            oPath[0].x = center.x-w/2;
            oPath[0].y = center.y-h/2;
            oPath[1].x = center.x-w/2;
            oPath[1].y = center.y+h/2;
            oPath[2].x = center.x+w/2;
            oPath[2].y = center.y+h/2;
            break;
         case 2:  // Equilateral
            double side = (width > height)? h: w;
            double hs = side/2;
            double xb = sqrt(side*side-hs*hs);
            oPath[0].x = center.x+xb/2;
            oPath[0].y = center.y-side/2;
            oPath[1].x = center.x+xb/2;
            oPath[1].y = center.y+side/2;
            oPath[2].x = center.x-xb/2;
            oPath[2].y = center.y;
            break;
         default:
            oPath[0].x = center.x;
            oPath[0].y = center.y-h/2;
            oPath[1].x = center.x+w/2;
            oPath[1].y = center.y+h/2;
            oPath[2].x = center.x-w/2;
            oPath[2].y = center.y+h/2;
            break;
      }
   }

   override void onCSMoreLess(int instance, bool more, bool coarse)
   {
      focusLayout();
      if (instance == 0)
         modifyTransform(xform, more, coarse);
      else
         return;
      aw.dirty = true;
      reDraw();
   }

   override void render(Context c)
   {
      if (dirty)
      {
         figurePath();
         dirty = false;
      }
      c.setLineWidth(lineWidth/((tf.hScale+tf.vScale)/2));
      c.setLineJoin(les? CairoLineJoin.MITER: CairoLineJoin.ROUND);

      c.translate(hOff+center.x, vOff+center.y);
      if (compoundTransform())
         c.transform(tm);
      c.translate(-center.x, -center.y);

      c.moveTo(oPath[0].x, oPath[0].y);
      c.lineTo(oPath[1].x, oPath[1].y);
      c.lineTo(oPath[2].x, oPath[2].y);
      c.closePath();
      strokeAndFill(c, lineWidth, solid, fill);
   }
}


