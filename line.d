
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module line;

import main;
import constants;
import acomp;
import lineset;
import common;
import types;
import controlset;
import lineset;

import std.stdio;
import std.conv;

import gdk.RGBA;
import gtk.Widget;
import gtk.RadioButton;
import gtk.SpinButton;
import gtk.ComboBoxText;
import cairo.Context;
import gtkc.cairotypes;
import cairo.Matrix;

class Line : LineSet
{
   static int nextOid = 0;
   ComboBoxText cbb;

   void syncControls()
   {
      cSet.setLineParams(lineWidth);
      cSet.toggling(false);
      if (les)
         cSet.setToggle(Purpose.LESSHARP, true);
      else
         cSet.setToggle(Purpose.LESROUND, true);
      cSet.setLabel(Purpose.LINEWIDTH, formatLT(lineWidth));
      cSet.toggling(true);
      if (!xform)
         cSet.setComboIndex(Purpose.XFORMCB, 0);
      else
         cSet.setComboIndex(Purpose.XFORMCB, 1);
      cSet.setHostName(name);
   }

   this(Line other)
   {
      this(other.aw, other.parent);
      baseColor = other.baseColor.copy();
      lineWidth = other.lineWidth;
      les = other.les;
      center = other.center;
      oPath = other.oPath.dup;
      xform = other.xform;
      tf=other.tf;
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Line "~to!string(++nextOid);
      super(w, parent, s, AC_LINE);
      aw = w;

      center.x = width/2;
      center.y = height/2;
      les = true;
      oPath.length = 2;
      oPath[0].x = -width/3;
      oPath[0].y = 0.0;
      oPath[1].x = width/3;
      oPath[1].y = 0.0;
      dirty = true;
      tm = new Matrix(&tmData);

      setupControls(3);
      positionControls(true);
   }

   void extendControls()
   {
      int vp = cSet.cy;

      new InchTool(cSet, 0, ICoord(0, vp), true);

      ComboBoxText cbb = new ComboBoxText(false);
      cbb.setTooltipText("Select transformation to apply");
      cbb.setSizeRequest(100, -1);
      cbb.appendText("Scale");
      cbb.appendText("Rotate");
      cbb.setActive(0);
      cSet.add(cbb, ICoord(175, vp), Purpose.XFORMCB);
      new MoreLess(cSet, 0, ICoord(280, vp+3), true);

      cSet.cy = vp+40;
   }

   void onCSNotify(Widget w, Purpose wid)
   {
      switch (wid)
      {
      case Purpose.COLOR:
         lastOp = push!RGBA(this, baseColor, OP_COLOR);
         setColor(false);
         break;
      case Purpose.LESROUND:
         if ((cast(RadioButton) w).getActive())
            les = false;
         break;
      case Purpose.LESSHARP:
         if ((cast(RadioButton) w).getActive())
            les = true;
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

   void preResize(int oldW, int oldH)
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

   void onCSLineWidth(double lt)
   {
      lastOp = pushC!double(this, lineWidth, OP_THICK);
      lineWidth = lt;
      aw.dirty = true;
      reDraw();
   }

   override void onCSMoreLess(int instance, bool more, bool coarse)
   {
      dummy.grabFocus();
      if (xform == 0)        // Scale
      {
         double factor;
         if (more)
            factor = coarse? 1.1: 1.01;
         else
            factor = coarse? 0.9: 0.99;
         lastOp = pushC!Transform(this, tf, OP_SCALE);
         tf.hScale *= factor;
         tf.vScale *= factor;
      }
      else if (xform == 1) // Rotate
      {
         double ra = coarse? rads*5: rads/3;
         if (!more)
            ra = -ra;
         lastOp = pushC!Transform(this, tf, OP_ROT);
         tf.ra += ra;
      }
      dirty = true;
      aw.dirty = true;
      reDraw();
   }

   void render(Context c)
   {
      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);
      c.setLineWidth(lineWidth);
      c.setAntialias(CairoAntialias.SUBPIXEL);
      c.setLineCap(les? CairoLineCap.BUTT: CairoLineCap.ROUND);
      if (dirty)
      {
         transformPath(compoundTransform());
         dirty = false;
      }
      c.moveTo(hOff+rPath[0].x, vOff+rPath[0].y);
      for (int i = 1; i < rPath.length; i++)
         c.lineTo(hOff+rPath[i].x, vOff+rPath[i].y);
      c.stroke();
      if (!isMoved) cSet.setDisplay(0, reportPosition());
   }
}


