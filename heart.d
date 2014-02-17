
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module heart;

import mainwin;
import constants;
import acomp;
import common;
import types;
import controlset;
import lineset;

import std.stdio;
import std.conv;

import gtk.Widget;
import gtk.Label;
import gtk.Button;
import gtk.ComboBoxText;
import gtk.SpinButton;
import gtk.CheckButton;
import gdk.RGBA;
import cairo.Context;
import cairo.Matrix;
import cairo.Surface;

class Heart: LineSet
{
   static int nextOid = 0;
   static Coord[7] crd = [ Coord(0, 0.666), Coord(-1.2, -0.1), Coord(-0.5, -1.1), Coord(0, -0.333),
                           Coord(0.5, -1.1), Coord(1.2, -0.1), Coord(0, 0.666) ];
   double unit;

   override void syncControls()
   {
      cSet.setLineParams(lineWidth);
      cSet.toggling(false);
      if (outline)
         cSet.setToggle(Purpose.OUTLINE, true);
      cSet.setLabel(Purpose.LINEWIDTH, formatLT(lineWidth));
      cSet.toggling(true);
      cSet.setComboIndex(Purpose.XFORMCB, xform);
      cSet.setComboIndex(Purpose.FILLOPTIONS, 0);
      cSet.setHostName(name);
   }

   this(Heart other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      altColor = other.altColor.copy();
      center = other.center;
      lineWidth = other.lineWidth;
      unit = other.unit;
      tf = other.tf;
      fill = other.fill;
      outline = other.outline;
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Heart "~to!string(++nextOid);
      super(w, parent, s, AC_HEART);
      group = ACGroups.SHAPES;
      closed = true;
      hOff = vOff = 0;
      altColor = new RGBA(1,0,0,1);
      center = Coord(0.5*width, 0.5*height);
      lineWidth = 0.5;
      fill = false;
      unit = width > height? height*0.6666: width*0.6666;
      constructBase();
      xform = 0;
      tm = new Matrix(&tmData);

      setupControls();
      outline = true;
      positionControls(true);
   }

   override void extendControls()
   {
      int vp = cSet.cy;
      Label l = new Label("Size");
      cSet.add(l, ICoord(255, vp-24), Purpose.LABEL);
      new MoreLess(cSet, 0, ICoord(295, vp-24), true);

      new InchTool(cSet, 0, ICoord(0, vp), true);

      ComboBoxText cbb = new ComboBoxText(false);
      cbb.setTooltipText("Select transformation to apply");
      cbb.setSizeRequest(100, -1);
      cbb.appendText("Scale");
      cbb.appendText("Rotate");
      cbb.appendText("Flip-H");
      cbb.appendText("Flip-V");
      cbb.setActive(0);
      cSet.add(cbb, ICoord(190, vp), Purpose.XFORMCB);
      new MoreLess(cSet, 0, ICoord(295, vp), true);

      cSet.cy = vp+40;
   }

   override void preResize(int oldW, int oldH)
   {
      double hr = cast(double) width/oldW;
      double vr = cast(double) height/oldH;
      unit = width>height? 0.6666*height: 0.6666*width;
      hOff *= hr;
      vOff *= vr;
   }

   void constructBase()
   {
      oPath = crd.dup;
      for (size_t i = 0; i < oPath.length; i++)
      {
         oPath[i].x *= unit;
         oPath[i].y *= unit;
         oPath[i].x += center.x;
         oPath[i].y += center.y;
      }
   }

   override void onCSMoreLess(int instance, bool more, bool coarse)
   {
      focusLayout();
      if (instance == 0)
      {
         double delta = coarse? 1.05: 1.01;
         if (more)
            unit *= delta;
         else
         {
            if (unit > 0.1)
               unit /= delta;
         }
         constructBase();
      }
      else
      {
         int[] xft = [0,5,6,7];
         int tt = xft[xform];
         modifyTransform(tt, more, coarse);
      }
      dirty = true;
      aw.dirty = true;
      reDraw();
   }

   override void render(Context c)
   {
      c.save();
      c.setLineWidth(0);
      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);

      c.translate(hOff+center.x, vOff+center.y);
      if (compoundTransform())
         c.transform(tm);
      c.translate(-center.x, -center.y);

      c.moveTo(oPath[0].x, oPath[0].y);
      c.curveTo(oPath[1].x, oPath[1].y, oPath[2].x, oPath[2].y, oPath[3].x, oPath[3].y);
      c.curveTo(oPath[4].x, oPath[4].y, oPath[5].x, oPath[5].y, oPath[6].x, oPath[6].y);
      c.closePath();
      strokeAndFill(c, lineWidth, outline, fill);
   }
}


