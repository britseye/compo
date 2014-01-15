
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module arrow;

import main;
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
import gtk.Range;
import gtk.HScale;
import gtk.VScale;
import gdk.RGBA;
import gtk.ComboBoxText;
import gtk.Button;
import gtk.SpinButton;
import gtk.ToggleButton;
import gtk.RadioButton;
import gtk.CheckButton;
import gtk.Label;
import cairo.Context;
import gtkc.cairotypes;
import cairo.Matrix;

class Arrow : LineSet
{
   static int nextOid = 0;
   int hw;

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
      if (hw == 0)
         cSet.setToggle(Purpose.MEDIUM, true);
      else if (hw == 1)
         cSet.setToggle(Purpose.NARROW, true);
      else
         cSet.setToggle(Purpose.WIDE, true);
      cSet.setComboIndex(Purpose.XFORMCB, xform);
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(Arrow other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      lineWidth = other.lineWidth;
      les = other.les;
      hw = other.hw;
      fill = other.fill;
      solid = other.solid;
      altColor = other.altColor.copy();
      center = other.center;
      oPath = other.oPath.dup;
      xform = other.xform;
      tf = other.tf;
      dirty = true;
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Arrow "~to!string(++nextOid);
      super(w, parent, s, AC_ARROW);
      altColor = new RGBA(0,0,0,1);
      les = true;
      fill = solid = false;

      center.x = width/2;
      center.y = height/2;
      hw = 0;  // medium head width
      constructBase();
      tm = new Matrix(&tmData);

      setupControls(3);
      positionControls(true);
      dirty = true;
   }

   override void extendControls()
   {
      int vp = cSet.cy;

      RadioButton rb = new RadioButton("Head width medium");
      cSet.add(rb, ICoord(172, vp-40), Purpose.MEDIUM);
      RadioButton rbc = new RadioButton(rb, "Head width narrow");
      cSet.add(rbc, ICoord(172, vp-20), Purpose.NARROW);
      rbc = new RadioButton(rb, "Head width wide");
      cSet.add(rbc, ICoord(172, vp), Purpose.WIDE);

      vp += 5;
      new InchTool(cSet, 0, ICoord(0, vp), true);

      vp += 20;
      ComboBoxText cbb = new ComboBoxText(false);
      cbb.appendText("Scale");
      cbb.appendText("Stretch-H");
      cbb.appendText("Stretch-V");
      cbb.appendText("Skew-H");
      cbb.appendText("Skew-V");
      cbb.appendText("Rotate");
      cbb.appendText("Flip-H");
      cbb.appendText("Flip-V");
      cbb.setActive(0);
      cbb.setSizeRequest(100, -1);
      cSet.add(cbb, ICoord(172, vp-5), Purpose.XFORMCB);

      new MoreLess(cSet, 0, ICoord(275, vp), true);

      vp += 35;

      CheckButton check = new CheckButton("Fill with color");
      cSet.add(check, ICoord(0, vp), Purpose.FILL);

      check = new CheckButton("Solid");
      cSet.add(check, ICoord(115, vp), Purpose.SOLID);

      Button b = new Button("Fill Color");
      cSet.add(b, ICoord(240, vp-5), Purpose.FILLCOLOR);

      vp += 25;
      cSet.cy = vp;
   }

   override void preResize(int oldW, int oldH)
   {
      center.x = width/2;
      center.y = height/2;
      double hr = cast(double) width/oldW;
      double vr = cast(double) height/oldH;
      tf.hScale *= hr;
      tf.vScale *= vr;
      hOff *= hr;
      vOff *= vr;
      dirty = true;
   }

   override bool specificNotify(Widget w, Purpose wid)
   {
      switch (wid)
      {
      case Purpose.MEDIUM:
      case Purpose.NARROW:
      case Purpose.WIDE:
         if (hw == wid-Purpose.MEDIUM)
            // Don'y go through the whole preformance for nothing
            return true;
         lastOp = push!(Coord[])(this, oPath, OP_PATH);
         if (wid == Purpose.MEDIUM)
            hw = 0;
         else if (wid == Purpose.NARROW)
            hw = 1;
         else
            hw = 2;
         constructBase();
         break;
      default:
         return false;
      }
      return true;
   }

   void constructBase()
   {
      oPath.length = 7;
      int ho = 5;
      if (hw == 1)
         ho = 2;
      else if (hw == 2)
         ho = 8;
      oPath[0] = Coord(-30, -5);
      oPath[1] = Coord(18, -5);
      oPath[2] = Coord(18, -(5+ho));
      oPath[3] = Coord(30, 0);
      oPath[4] = Coord(18, 5+ho);
      oPath[5] = Coord(18, 5);
      oPath[6] = Coord(-30, 5);
      dirty = true;
   }

   override void onCSMoreLess(int instance, bool more, bool coarse)
   {
      focusLayout();
      if (instance == 0)
         modifyTransform(xform, more, coarse);
      else
         return;
      dirty = true;
      aw.dirty = true;
      reDraw();
   }

   override void render(Context c)
   {
      if (dirty)
      {
         transformPath(compoundTransform());

         dirty = false;
      }
      c.setLineWidth(lineWidth);
      c.setLineJoin(les? CairoLineJoin.MITER: CairoLineJoin.ROUND);
      c.moveTo(hOff+rPath[0].x, vOff+rPath[0].y);
      for (int i = 1; i < rPath.length; i++)
         c.lineTo(hOff+rPath[i].x, vOff+rPath[i].y);
      c.closePath();
      c.setSourceRgba(baseColor.red, baseColor.green, baseColor.blue, 1.0);
      if (!(solid || fill))
         c.stroke();
      else
         doFill(c, solid, fill);
      if (!isMoved) cSet.setDisplay(0, reportPosition());
   }
}
