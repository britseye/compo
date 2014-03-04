
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
import mol;

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
      if (outline)
         cSet.setToggle(Purpose.OUTLINE, true);
      cSet.setComboIndex(Purpose.XFORMCB, xform);
      cSet.setComboIndex(Purpose.FILLOPTIONS, 0);
      cSet.setComboIndex(Purpose.PATTERN, ttype);
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
      outline = other.outline;
      fillFromPattern = other.fillFromPattern;
      fillUid = other.fillUid;
      updateFillUI();
      tf = other.tf;

      xform = other.xform;
      syncControls();
   }

   this(AppWindow appw, ACBase parent)
   {
      string s = "Triangle "~to!string(++nextOid);
      super(appw, parent, s, AC_TRIANGLE);
      group = ACGroups.SHAPES;
      closed = true;
      hOff = vOff = 0;
      altColor = new RGBA(1,1,1,1);
      fill = false;
      h = 0.75*height;
      w = 0.75*width;
      center = Coord(0.5*width, 0.5*height);

      tm = new Matrix(&tmData);
      ttype = 0;

      les = cairo_line_cap_t.ROUND;
      dirty = true;

      setupControls(3);
      outline = true;
      positionControls(true);
   }

   override void extendControls()
   {
      int vp = cSet.cy;

      Label l = new Label("Adjust Size");
      cSet.add(l, ICoord(167, vp-40), Purpose.LABEL);
      new MoreLess(cSet, 0, ICoord(275, vp-40), true);

      ComboBoxText cbb = new ComboBoxText(false);
      cbb.setTooltipText("Select transformation to apply");
      cbb.setSizeRequest(100, -1);
      cbb.appendText("Right, Right");      // Options here limited - it's a rectangle - if you want
      cbb.appendText("Right, Left");    // a quadrilateral, use polygon.
      cbb.appendText("Equilateral");
      cbb.appendText("Isosceles");
      cbb.setActive(0);
      cSet.add(cbb, ICoord(167, vp-20), Purpose.PATTERN);

      new InchTool(cSet, 0, ICoord(0, vp+5), true);

      vp += 17;

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
      new MoreLess(cSet, 1, ICoord(275, vp+4), true);

      cSet.cy = vp+40;
   }

   override bool notifyHandler(Widget w, Purpose p)
   {
      focusLayout();
      switch (p)
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
/*
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
*/
   override bool specificUndo(CheckPoint cp)
   {
      switch (cp.type)
      {
      case OP_SIZE:
         Coord t = cp.coord;
         w = t.x;
         h = t.y;
         figurePath();
         break;
      default:
         return false;
      }
      lastOp = OP_UNDEF;
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

   override void onCSMoreLess(int instance, bool more, bool quickly)
   {
      focusLayout();
      switch (instance)
      {
         case 0:
            double result = 1;
            if (!molG!double(more, quickly, result, 0.01, 0.01, 5000))
               return;
            Coord t = Coord(w, h);
            lastOp = pushC!Coord(this, t, OP_SIZE);
            w *= result;
            h *= result;
            figurePath();
            break;
         case 1:
            modifyTransform(xform, more, quickly);
            break;
         default:
            return;
      }
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
      strokeAndFill(c, lineWidth, outline, fill);
   }
}


