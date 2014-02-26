
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module arrow;

import mainwin;
import constants;
import acomp;
import common;
import types;
import controlset;
import lineset;

import std.stdio;
import std.math;
import std.conv;
import std.random;

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
   double size;
   int hw;

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
      if (hw == 0)
         cSet.setToggle(Purpose.MEDIUM, true);
      else if (hw == 1)
         cSet.setToggle(Purpose.NARROW, true);
      else
         cSet.setToggle(Purpose.WIDE, true);
      cSet.setComboIndex(Purpose.XFORMCB, xform);
      cSet.setComboIndex(Purpose.FILLOPTIONS, 0);
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(Arrow other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      altColor = other.altColor.copy();
      lineWidth = other.lineWidth;
      les = other.les;
      size = other.size;
      hw = other.hw;
      fill = other.fill;
      outline = other.outline;
      fillFromPattern = other.fillFromPattern;
      fillUid = other.fillUid;
      updateFillUI();
      center = other.center;
      oPath = other.oPath.dup;
      xform = other.xform;
      tf = other.tf;
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Arrow "~to!string(++nextOid);
      group = ACGroups.SHAPES;
      super(w, parent, s, AC_ARROW);
      altColor = new RGBA(0,0,0,1);
      les = true;
      closed = true;
      fill = false;

      center.x = 0.5*width;
      center.y = 0.5*height;
      size = 2.5;
      hw = 0;  // medium head width
      constructBase();
      tm = new Matrix(&tmData);

      setupControls(3);
      outline = true;
      positionControls(true);
   }

   override void extendControls()
   {
      int vp = cSet.cy;
      Label l = new Label("Size");
      cSet.add(l, ICoord(255, vp-64), Purpose.LABEL);
      new MoreLess(cSet, 0, ICoord(295, vp-64), true);

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
      new MoreLess(cSet, 1, ICoord(295, vp), true);

      cSet.cy = vp+35;
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
      oPath[0] = Coord(-30*size, -5*size);
      oPath[1] = Coord(18*size, -5*size);
      oPath[2] = Coord(18*size, -(5+ho)*size);
      oPath[3] = Coord(30*size, 0);
      oPath[4] = Coord(18*size, (5+ho)*size);
      oPath[5] = Coord(18*size, 5*size);
      oPath[6] = Coord(-30*size, 5*size);
      center.x = 0.5*width;
      center.y = 0.5*height;
      for (size_t i = 0; i < oPath.length; i++)
      {
         oPath[i].x += center.x;
         oPath[i].y += center.y;
      }
   }

   override void onCSMoreLess(int instance, bool more, bool coarse)
   {
      focusLayout();
      if (instance == 1)
         modifyTransform(xform, more, coarse);
      else if (instance == 0)
      {
         double delta = coarse? 1.05: 1.01;
         if (more)
            size *= delta;
         else
         {
            if (size > 0.1)
               size /= delta;
         }
         constructBase();
      }
      else
         return;
      aw.dirty = true;
      reDraw();
   }

   override void render(Context c)
   {
      c.translate(hOff+center.x, vOff+center.y);
      if (compoundTransform())
         c.transform(tm);
      c.translate(-center.x, -center.y);  // lpX and lpY both zero at design time

      c.setLineWidth(0);
      c.setLineJoin(les? CairoLineJoin.MITER: CairoLineJoin.ROUND);
      c.moveTo(oPath[0].x, oPath[0].y);
      for (size_t i = 1; i < oPath.length; i++)
         c.lineTo(oPath[i].x, oPath[i].y);
      c.closePath();
      strokeAndFill(c, lineWidth, outline, fill);
   }
}
