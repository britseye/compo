
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module rect;

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

class Rectangle : LineSet
{
   static int nextOid = 0;
   double w, h, ar, size;
   bool rounded, square;
   double rr;
   Coord topLeft, bottomRight;

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
      if (outline)
         cSet.setToggle(Purpose.OUTLINE, true);
      cSet.setComboIndex(Purpose.XFORMCB, xform);
      cSet.setComboIndex(Purpose.FILLOPTIONS, 0);
      cSet.setLabel(Purpose.LINEWIDTH, formatLT(lineWidth));
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   override void afterDeserialize()
   {
      figureWH();
      syncControls();
   }

   this(Rectangle other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      altColor = other.altColor.copy();
      size = other.size;
      w = other.w;
      h = other.h;
      ar = other.ar;
      lineWidth = other.lineWidth;
      les = other.les;
      square = other.square;
      rounded = other.rounded;
      rr = other.rr;
      tf = other.tf;
      fill = other.fill;
      outline = other.outline;
      fillFromPattern = other.fillFromPattern;
      fillUid = other.fillUid;
      updateFillUI();
      figureWH();

      xform = other.xform;
      syncControls();
   }

   this(AppWindow appw, ACBase parent)
   {
      mixin(initString!Rectangle());
      super(appw, parent, sname, AC_RECT, ACGroups.SHAPES, ahdg);

      closed = true;
      hOff = vOff = 0;
      altColor = new RGBA(0,0,0,1);
      fill = false;
      ar = (1.0*width)/height;
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
      outline = true;
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

      l = new Label("Adjust Size");
      cSet.add(l, ICoord(170, vp+20), Purpose.LABEL);
      new MoreLess(cSet, 1, ICoord(270, vp+20), true);

      new InchTool(cSet, 0, ICoord(0, vp+5), true);

      l = new Label("Aspect Ratio");
      l.setTooltipText("Adjust width to height ratio - hold down <Ctrl> for faster action");
      cSet.add(l, ICoord(170, vp+40), Purpose.LABEL);
      new MoreLess(cSet, 2, ICoord(270, vp+40), true);

      vp += 60;

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

      cSet.cy = vp+40;
   }

   override bool notifyHandler(Widget w, Purpose p)
   {
      focusLayout();
      switch (p)
      {
      case Purpose.ROUNDED:
         rounded = !rounded;
         break;
      case Purpose.PIN:
         square = !square;
         figureWH();
         break;
      default:
         return false;
      }
      return true;
   }

   override bool undoHandler(CheckPoint cp)
   {
      switch (cp.type)
      {
      case OP_DV0:
         rr = cp.dVal;
         lastOp = OP_UNDEF;
         break;
      case OP_SIZE:
         size = cp.dVal;
         figureWH();
         break;
      case OP_HSIZE:
         ar = cp.dVal;
         figureWH();
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

   void figureWH(bool arChange = false)
   {
//writefln("size %f, ar %f", size, ar);
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

      if (rounded)
      {
         if (w < 2*rr)
            w = 2*rr;
         if (h < 2*rr)
            h = 2*rr;
         ar = w/h;
      }

      topLeft = square? Coord(center.x-0.5*size, center.y-0.5*size):
                        Coord(center.x-0.5*w, center.y-0.5*h);
      bottomRight = square? Coord(center.x+0.5*size, center.y+0.5*size):
                            Coord(center.x+0.5*w, center.y+0.5*h);
   }

   override void onCSMoreLess(int instance, bool more, bool quickly)
   {
      focusLayout();
      switch (instance)
      {
         case 0:
            double result = rr;
            double lim = ((w > h)? h: w)*0.5 - lineWidth;
            if (!molA!double(more, quickly, result, 0.5, 0, lim))
               return;
            lastOp = pushC!double(this, rr, OP_DV0);
            rr = result;
            break;
         case 1:
            double result = size;
            if (!molG!double(more, quickly, result, 0.01, 2*lineWidth, 1000))
               return;
            lastOp = pushC!double(this, size, OP_SIZE);
            size = result;
            figureWH();
            break;
         case 2:
            double result = ar;
            if (!molA!double(more, quickly, result, 0.02, 0, double.infinity))
               return;
            lastOp = pushC!double(this, ar, OP_HSIZE);
            figureWH();
            ar = result;
            break;
         case 3:
            int[] xft = [0,1,2,5,6,7];
            int tt = xft[xform];
            modifyTransform(tt, more, quickly);
            break;
         default:
            return;
      }
      aw.dirty = true;
      reDraw();
   }

   override void render(Context c)
   {
      c.setLineWidth(lineWidth/((tf.hScale+tf.vScale)/2));
      c.setLineJoin(les? CairoLineJoin.MITER: CairoLineJoin.ROUND);

      c.translate(hOff+center.x, vOff+center.y);
      if (compoundTransform())
         c.transform(tm);
      c.translate(-center.x, -center.y);  // lpX and lpY both zero at design time

      if (rounded)
      {
         c.moveTo(topLeft.x, topLeft.y+rr);
         c.arc(topLeft.x+rr, topLeft.y+rr, rr, PI, (3*PI)/2);
         c.lineTo(bottomRight.x-rr, topLeft.y);
         c.arc(bottomRight.x-rr, topLeft.y+rr, rr, (3*PI)/2, 2*PI);
         c.lineTo(bottomRight.x, bottomRight.y-rr);
         c.arc(bottomRight.x-rr, bottomRight.y-rr, rr, 0, PI/2);
         c.lineTo(topLeft.x+rr, bottomRight.y);
         c.arc(topLeft.x+rr, bottomRight.y-rr, rr, PI/2, PI);
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
      strokeAndFill(c, lineWidth, outline, fill);
   }
}


