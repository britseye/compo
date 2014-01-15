
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
   double w, h, ar, size;
   bool rounded, square;
   double rr;
   Coord xTopLeft;

   override void syncControls()
   {
      cSet.setLineParams(lineWidth);
      cSet.toggling(false);
      if (les)
         cSet.setToggle(Purpose.LESSHARP, true);
      else
         cSet.setToggle(Purpose.LESROUND, true);
      if (square)
         cSet.setToggle(Purpose.PIN, true);
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

   void afterDeserialize()
   {
      figureWH();
      syncControls();
   }

   this(Rect other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      altColor = other.altColor.copy();
      w = other.w;
      h = other.h;
      ar = other.ar;
      lineWidth = other.lineWidth;
      les = other.les;
      square = other.square;
      rounded = other.rounded;
      fill = other.fill;
      solid = other.solid;
      rr = other.rr;
      tf = other.tf;

      xform = other.xform;
      syncControls();
   }

   this(AppWindow appw, ACBase parent)
   {
      string s = "Rectangle "~to!string(++nextOid);
      super(appw, parent, s, AC_RECT);
      hOff = vOff = 0;
      altColor = new RGBA(0,0,0,1);
      ar = 2;
      size = (width > height)? 0.75*height: 0.75*width;
      center = Coord(0.5*width, 0.5*height);
      figureWH();

      tm = new Matrix(&tmData);

      les = cairo_line_cap_t.ROUND;
      if (w > h)
         rr = 0.05*h;
      else
         rr = 0.05*w;
      rounded = false;

      setupControls(3);
      positionControls(true);
   }

   override void extendControls()
   {
      int vp = cSet.cy;

      CheckButton check = new CheckButton("Make Square");
      cSet.add(check, ICoord(168, vp-40), Purpose.PIN);

      check = new CheckButton("Rounded corners");
      cSet.add(check, ICoord(168, vp-20), Purpose.ROUNDED);

      Label l = new Label("Corner radius");
      l.setTooltipText("Adjust corner radius\nmax is oval, min is rectangle");
      cSet.add(l, ICoord(170, vp), Purpose.LABEL);
      new MoreLess(cSet, 0, ICoord(270, vp), true);

      new InchTool(cSet, 0, ICoord(0, vp+5), true);

      l = new Label("Aspect Ratio");
      l.setTooltipText("Adjust width to height ratio - hold down <Ctrl> for faster action");
      cSet.add(l, ICoord(170, vp+20), Purpose.LABEL);
      new MoreLess(cSet, 1, ICoord(270, vp+20), true);

      vp += 45;

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
      cSet.add(cbb, ICoord(167, vp), Purpose.XFORMCB);
      new MoreLess(cSet, 3, ICoord(270, vp+4), true);

      vp += 40;

      check = new CheckButton("Fill with color");
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
      case Purpose.ROUNDED:
         rounded = !rounded;
         break;
      case Purpose.PIN:
         square = !square;
         break;
      default:
         return false;
      }
      return true;
   }

   override bool specificUndo(CheckPoint cp)
   {
      switch (cp.type)
      {
      case OP_SIZE:
         rr = cp.dVal;
         lastOp = OP_UNDEF;
         break;
      case OP_HSIZE:
         ar = cp.dVal;
         lastOp = OP_UNDEF;
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

   string reportPosition(int id = 0)
   {
      return formatCoord(Coord(hOff, vOff));
   }

   void figureWH()
   {
      if (width > height)
      {
         w = size*ar;
         h = size;
      }
      else
      {
         w = size;
         h = size*ar;
      }
   }

   override void onCSMoreLess(int instance, bool more, bool coarse)
   {
      int direction = more? 1: -1;
      focusLayout();
      if (instance == 0)
      {
         lastOp = pushC!double(this, rr, OP_SIZE);
         double cw, ch;
         double lim = ((w > h)? h: w)*0.5 - lineWidth;
         double t = rr+direction;
         if (t > lim || t < 0)
            return;
         rr = t;
      }
      else if (instance == 1)
      {
         lastOp = pushC!double(this, ar, OP_HSIZE);
         double factor = more? (coarse? 1.05: 1.01): (coarse? 0.95: 0.99);
         ar *= factor;
         figureWH();
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

   override void render(Context c)
   {
      c.setLineWidth(lineWidth/((tf.hScale+tf.vScale)/2));
      c.setLineJoin(les? CairoLineJoin.MITER: CairoLineJoin.ROUND);
      c.translate(hOff+width/2, vOff+height/2);
      if (tf.hScale != 1.0 || tf.vScale != 1.0)
         c.scale(tf.hScale, tf.vScale);
      if (tf.ra != 0.0)
         c.rotate(tf.ra);
      c.translate(-(hOff+width/2), -(vOff+height/2));
      Coord topLeft = square? Coord(hOff+center.x-0.5*size, vOff+center.y-0.5*size):
                              Coord(hOff+center.x-0.5*w, vOff+center.y-0.5*h);
      Coord bottomRight = square? Coord(hOff+center.x+0.5*size, vOff+center.y+0.5*size):
                                  Coord(hOff+center.x+0.5*w, vOff+center.y+0.5*h);
      if (rounded)
      {
         double delta = rr;
         c.moveTo(topLeft.x, topLeft.y+delta);
         c.arc(topLeft.x+delta, topLeft.y+delta, delta, PI, (3*PI)/2);
         c.lineTo(bottomRight.x-delta, topLeft.y);
         c.arc(bottomRight.x-delta, topLeft.y+delta, delta, (3*PI)/2, 2*PI);
         c.lineTo(bottomRight.x, bottomRight.y-delta);
         c.arc(bottomRight.x-delta, bottomRight.y-delta, delta, 0, PI/2);
         c.lineTo(topLeft.x+delta, bottomRight.y);
         c.arc(topLeft.x+delta, bottomRight.y-delta, delta, PI/2, PI);
         c.closePath();
      }
      else
      {
         c.moveTo(topLeft.x, topLeft.y);
         c.lineTo(bottomRight.x, topLeft.y);
         c.lineTo(bottomRight.x, bottomRight.y);
         c.lineTo(topLeft.x, bottomRight.y);
         c.closePath();
      }
      c.setSourceRgb(baseColor.red,baseColor.green, baseColor.blue);
      if (!(solid || fill))
         c.stroke();
      else
         doFill(c, solid, fill);
      if (!isMoved) cSet.setDisplay(0, reportPosition());
   }
}


