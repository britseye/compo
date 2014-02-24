
//          Copyright Steve Teale 2013.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module cross;

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

class Cross : LineSet
{
   static int nextOid = 0;
   double size, cbOff, cbW, urW;
   double h, w, cw, uw, ho, vo, ar, cbPos, drop, rise;

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
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(Cross other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      altColor = other.altColor.copy();
      lineWidth = other.lineWidth;
      les = other.les;
      uw = other.uw;
      cw = other.cw;
      fill = other.fill;
      fillFromPattern = other.fillFromPattern;
      fillUid = other.fillUid;
      updateFillUI();
      outline = other.outline;
      center = other.center;
      oPath = other.oPath.dup;
      xform = other.xform;
      tf = other.tf;

      ar = other.ar;
      cbOff = other.cbOff;
      urW = other.urW;
      cbW = other.cbW;

      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Cross "~to!string(++nextOid);
      super(w, parent, s, AC_CROSS);
      group = ACGroups.SHAPES;
      closed = true;
      altColor = new RGBA(0,0,0,1);
      les = true;
      fill = false;
      oPath.length = 12;
      ar = 1;
      cbOff = 0.5;
      urW = 0.2;
      cbW = 0.2;
      size = 1;
      center.x = width/2;
      center.y = height/2;

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
      cSet.add(l, ICoord(265, vp-64), Purpose.LABEL);
      new MoreLess(cSet, 0, ICoord(300, vp-64), true);

      l = new Label("Upright Width");
      cSet.add(l, ICoord(172, vp-40), Purpose.LABEL);
      new MoreLess(cSet, 1, ICoord(300, vp-40), true);
      l = new Label("Cross Bar Width");
      cSet.add(l, ICoord(172, vp-20), Purpose.LABEL);
      new MoreLess(cSet, 2, ICoord(300, vp-20), true);
      l = new Label("Cross Bar Position");
      cSet.add(l, ICoord(172, vp), Purpose.LABEL);
      new MoreLess(cSet, 3, ICoord(300, vp), true);
      l = new Label("Aspect Ratio");
      cSet.add(l, ICoord(172, vp+20), Purpose.LABEL);
      new MoreLess(cSet, 4, ICoord(300, vp+20), true);

      vp += 5;
      new InchTool(cSet, 0, ICoord(0, vp), true);

      vp += 40;
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
      new MoreLess(cSet, 5, ICoord(300, vp), true);

      cSet.cy = vp+35;

      //RenameGadget rg = new RenameGadget(cSet, ICoord(0, vp), name, true);
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
   }

   void constructBase()
   {
      if (width > height)
         h = height*size;
      else
         h = width*size;
      h *=0.9;
      w = h*ar;
      uw = h*urW;
      cw = h*cbW;
      cbPos = h/2-h*cbOff;
      rise = -h/2;
      drop = h/2;
      ho = uw*0.5;
      vo = cw*0.5;
      makeCoords();
      center.x = 0.5*width;
      center.y = 0.5*height;
      for (size_t i = 0; i < oPath.length; i++)
      {
         oPath[i].x += center.x;
         oPath[i].y += center.y;
      }
   }

   void makeCoords()
   {
      oPath[0] = Coord(ho, cbPos-vo);
      oPath[1] = Coord(w/2, cbPos-vo);
      oPath[2] = Coord(w/2, cbPos+vo);
      oPath[3] = Coord(ho, cbPos+vo);
      oPath[4] = Coord(ho, drop);
      oPath[5] = Coord(-ho, drop);
      oPath[6] = Coord(-ho, cbPos+vo);
      oPath[7] = Coord(-w/2, cbPos+vo);
      oPath[8] = Coord(-w/2, cbPos-vo);
      oPath[9] = Coord(-ho, cbPos-vo);
      oPath[10] = Coord(-ho, rise);
      oPath[11] = Coord(ho, rise);
   }

   override void onCSMoreLess(int instance, bool more, bool coarse)
   {
      if (instance == 0)
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
      else if (instance == 1)  // Upright width
      {
         if (more)
         {
            if (urW+0.05 > 0.8)
               return;
            urW += 0.05;
         }
         else
         {
            if (urW-0.05 <= 0.05)
               return;
            urW -= 0.05;
         }
         constructBase();
      }
      else if (instance == 2)
      {
         if (more)
         {
            if (cbW+0.05 > 0.8)
               return;
            cbW += 0.05;
         }
         else
         {
            if (cbW-0.05 <= 0.05)
               return;
            cbW -= 0.05;
         }
         constructBase();
      }
      else if (instance == 3)
      {
         if (more)
         {
            if (cbPos-vo-0.05*h < rise)
               cbPos = rise+vo;
            else
               cbPos = cbPos-0.05*h;
         }
         else
         {
            if (cbPos+vo+0.05*h > drop)
               cbPos = drop-vo;
            else
               cbPos = cbPos+0.05*h;
         }
         cbOff = (cbPos-h/2)/-h;
         constructBase();
      }
      else if (instance == 4)
      {
         if (more)
         {
            if (ar+0.05 > 2)
               return;
            ar += 0.05;
         }
         else
         {
            if (ar-0.05 <= 0.25)
               return;
            ar -= 0.05;
         }
         constructBase();
      }
      else if (instance == 5)
         modifyTransform(xform, more, coarse);
      else
         return;
      focusLayout();
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


