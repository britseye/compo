
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module rect;

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

class Rect : LineSet
{
   static int nextOid = 0;
   RGBA saveAltColor;
   Coord topLeft, bottomRight, origTopLeft, origBottomRight;
   bool rounded, fill, solid;
   double rr;
   Coord xTopLeft;

   void syncControls()
   {
      cSet.setLineParams(lineWidth);
      cSet.toggling(false);
      if (les)
         cSet.setToggle(Purpose.LESSHARP, true);
      else
         cSet.setToggle(Purpose.LESROUND, true);
      if (rounded)
         cSet.setToggle(Purpose.ROUNDED, true);
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

   this(Rect other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      altColor = other.altColor.copy();
      topLeft = other.topLeft;
      bottomRight = other.bottomRight;
      lineWidth = other.lineWidth;
      les = other.les;
      rounded = other.rounded;
      fill = other.fill;
      solid = other.solid;
      rr = other.rr;
      tf = other.tf;

      xform = other.xform;
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Rectangle "~to!string(++nextOid);
      super(w, parent, s, AC_RECT);
      hOff = vOff = 0;
      altColor = new RGBA();
      topLeft.x = 0.2*width;
      topLeft.y = 0.2*height;
      bottomRight.x = width*0.8;
      bottomRight.y = height*0.8;
      origTopLeft = topLeft;
      origBottomRight = bottomRight;
      lineWidth = 1.0;

      tm = new Matrix(&tmData);
      xTopLeft = topLeft;;

      les = cairo_line_cap_t.ROUND;
      if (width > height)
         rr = 0.05*height;
      else
         rr = 0.05*width;
      rounded = false;

      setupControls(3);
      positionControls(true);
   }

   void extendControls()
   {
      int vp = cSet.cy;

      CheckButton check = new CheckButton("Rounded corners");
      cSet.add(check, ICoord(168, vp-40), Purpose.ROUNDED);

      Label l = new Label("Corner radius");
      l.setTooltipText("Adjust corner radius\nmax is oval, min is rectangle");
      cSet.add(l, ICoord(170, vp-20), Purpose.LABEL);
      new MoreLess(cSet, 0, ICoord(270, vp-18), true);

      new InchTool(cSet, 0, ICoord(0, vp+5), true);

      l = new Label("Width");
      l.setTooltipText("Adjust width - hold down <Ctrl> for faster action");
      cSet.add(l, ICoord(170, vp), Purpose.LABEL);
      new MoreLess(cSet, 1, ICoord(270, vp), true);

      vp += 20;

      l = new Label("Height");
      l.setTooltipText("Adjust height - hold down <Ctrl> for faster action");
      cSet.add(l, ICoord(170, vp-2), Purpose.LABEL);
      new MoreLess(cSet, 2, ICoord(270, vp-2), true);

      vp += 30;

      ComboBoxText cbb = new ComboBoxText(false);
      cbb.setTooltipText("Select transformation to apply");
      cbb.setSizeRequest(100, -1);
      cbb.appendText("Scale");      // Options here limited - it's a rectangle - if you want
      cbb.appendText("Scale-H");    // a quadrilateral, use polygon.
      cbb.appendText("Scale-V");
      cbb.appendText("Rotate");
      cbb.appendText("Flip-H");
      cbb.appendText("Flip-V");
      cbb.setActive(0);
      cSet.add(cbb, ICoord(162, vp-4), Purpose.XFORMCB);
      new MoreLess(cSet, 3, ICoord(270, vp), true);

      vp += 35;

      check = new CheckButton("Fill with color");
      cSet.add(check, ICoord(0, vp), Purpose.FILL);

      check = new CheckButton("Solid");
      cSet.add(check, ICoord(115, vp), Purpose.SOLID);

      Button b = new Button("Fill Color");
      cSet.add(b, ICoord(190, vp-5), Purpose.FILLCOLOR);

      cSet.cy = vp+30;
   }

   void onCSNotify(Widget w, Purpose wid)
   {
      switch (wid)
      {
      case Purpose.COLOR:
         lastOp = push!RGBA(this, baseColor, OP_COLOR);
         pushOp(lcp);
         setColor(false);
         break;
      case Purpose.FILLCOLOR:
         lastOp = push!RGBA(this, altColor, OP_ALTCOLOR);
         setColor(true);
         break;
      case Purpose.LINEWIDTH:
         lastOp = pushC!double(this, lineWidth, OP_THICK);
         lineWidth = (cast(SpinButton) w).getValue();
         break;
      case Purpose.LESROUND:
         if ((cast(RadioButton) w).getActive())
            les = false;
         break;
      case Purpose.LESSHARP:
         if ((cast(RadioButton) w).getActive())
            les = true;
         break;
      case Purpose.ROUNDED:
         rounded = !rounded;
         break;
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
         return;
      }
      dummy.grabFocus();
      aw.dirty = true;
      reDraw();
   }

   bool specificUndo(CheckPoint cp)
   {
      switch (cp.type)
      {
      case OP_SIZE:
         rr = cp.dVal;
         lastOp = OP_UNDEF;
         break;
      case OP_HSIZE:
         bottomRight.x = cp.dVal;
         lastOp = OP_UNDEF;
         break;
      case OP_VSIZE:
         bottomRight.y = cp.dVal;
         lastOp = OP_UNDEF;
         break;
      default:
         return false;
      }
      return true;
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
      tm.initTranslate(hOff+width/2, vOff+height/2);
      if (tf.hScale != 1.0 || tf.vScale != 1.0)
         tm.scale(tf.hScale, tf.vScale);
      if (tf.ra != 0.0)
         tm.rotate(tf.ra);
      tm.translate(-width/2, -height/2);
      double x = topLeft.x;
      double y = topLeft.y;
      tm.transformPoint(x, y);
      xTopLeft = Coord(x, y);
      return formatCoord(Coord(xTopLeft.x, xTopLeft.y));
   }

   void onCSMoreLess(int instance, bool more, bool coarse)
   {
      int direction = more? 1: -1;
      dummy.grabFocus();
      if (instance == 0)
      {
         lastOp = pushC!double(this, rr, OP_SIZE);
         double cw, ch;
         cw = bottomRight.x - topLeft.x;
         ch = bottomRight.y - topLeft.y;
         double lim = ((cw > ch)? ch: cw)*0.5 - lineWidth;
         double t = rr+direction;
         if (t > lim || t < 0)
            return;
         rr = t;
      }
      else if (instance == 1)
      {
         lastOp = pushC!double(this, bottomRight.x, OP_HSIZE);
         if (coarse)
            direction *= 10;
         bottomRight.x += direction;
      }
      else if (instance == 2)
      {
         lastOp = pushC!double(this, bottomRight.y, OP_VSIZE);
         if (coarse)
            direction *= 10;
         bottomRight.y += direction;
      }
      else
      {
         int[] xft = [0,1,2,5,6,7];
         int tt = xft[xform];
         modifyTransform(tt, more, coarse);
      }
      aw.dirty = true;
      reDraw();
   }

   void render(Context c)
   {
      c.setLineWidth(lineWidth);
      c.setLineJoin(les? CairoLineJoin.MITER: CairoLineJoin.ROUND);
      c.setSourceRgb(baseColor.red,baseColor.green, baseColor.blue);
      c.translate(hOff+width/2, vOff+height/2);
      if (tf.hScale != 1.0 || tf.vScale != 1.0)
         c.scale(tf.hScale, tf.vScale);
      if (tf.ra != 0.0)
         c.rotate(tf.ra);
      c.translate(-(hOff+width/2), -(vOff+height/2));
      if (rounded)
      {
         double delta = rr;//+lineWidth;
         c.moveTo(hOff+topLeft.x, vOff+topLeft.y+delta);
         c.arc(hOff+topLeft.x+delta, vOff+topLeft.y+delta, delta, PI, (3*PI)/2);
         c.lineTo(hOff+bottomRight.x-delta, vOff+topLeft.y);
         c.arc(hOff+bottomRight.x-delta, vOff+topLeft.y+delta, delta, (3*PI)/2, 2*PI);
         c.lineTo(hOff+bottomRight.x, vOff+bottomRight.y-delta);
         c.arc(hOff+bottomRight.x-delta, vOff+bottomRight.y-delta, delta, 0, PI/2);
         c.lineTo(hOff+topLeft.x+delta, vOff+bottomRight.y);
         c.arc(hOff+topLeft.x+delta, vOff+bottomRight.y-delta, delta, PI/2, PI);
         c.closePath();
      }
      else
      {
         c.moveTo(hOff+topLeft.x, vOff+topLeft.y);
         c.lineTo(hOff+bottomRight.x, vOff+topLeft.y);
         c.lineTo(hOff+bottomRight.x, vOff+bottomRight.y);
         c.lineTo(hOff+topLeft.x, vOff+bottomRight.y);
         c.closePath();
      }
      if (solid)
      {
         c.setSourceRgba(baseColor.red, baseColor.green, baseColor.blue, 1.0);
         c.fill();
      }
      else if (fill)
      {
         c.setSourceRgba(altColor.red, altColor.green, altColor.blue, 1.0);
         c.fillPreserve();
      }
      if (!solid)
      {
         c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);
         c.stroke();
      }
      if (!isMoved) cSet.setDisplay(0, reportPosition());
   }
}


