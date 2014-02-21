
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module yinyang;

import mainwin;
import constants;
import acomp;
import common;
import types;
import controlset;
import lineset;

import std.stdio;
import std.conv;
import std.math;

import gtk.Widget;
import gtk.Label;
import gtk.Button;
import gtk.ComboBoxText;
import gtk.CheckButton;
import gdk.RGBA;
import cairo.Context;
import cairo.Matrix;

class YinYang: LineSet
{
   static int nextOid = 0;
   static immutable double m = 0.55191502449/2;
   static immutable Coord[40] crd = [
                           Coord(0, 0), Coord(m, 0), Coord(0.5, -0.5+m), Coord(0.5, -0.5),
                           Coord(0.5, -0.5-m), Coord(m, -1), Coord(0, -1),
                           Coord(2*m, -1), Coord(1, -2*m), Coord(1, 0),
                           Coord(1, 2*m), Coord(2*m, 1), Coord(0, 1),
                           Coord(-m, 1), Coord(-0.5, 0.5+m), Coord(-0.5, 0.5),
                           Coord(-0.5, 0.5-m), Coord(-m, 0), Coord(0, 0),

                           Coord(0, 0), Coord(m, 0), Coord(0.5, -0.5+m), Coord(0.5, -0.5),
                           Coord(0.5, -0.5-m), Coord(m, -1), Coord(0, -1),
                           Coord(-2*m, -1), Coord(-1, -2*m), Coord(-1, 0),
                           Coord(-1, 2*m), Coord(-2*m, 1), Coord(0, 1),
                           Coord(-m, 1), Coord(-0.5, 0.5+m), Coord(-0.5, 0.5),
                           Coord(-0.5, 0.5-m), Coord(-m, 0), Coord(0, 0),

                           Coord(0, -0.5), Coord(0, 0.5) ];
   double unit;

   override void syncControls()
   {
      cSet.setLineParams(lineWidth);
      cSet.toggling(false);
      cSet.setToggle(Purpose.OUTLINE, outline);
      cSet.setLabel(Purpose.LINEWIDTH, formatLT(lineWidth));
      cSet.toggling(true);
      cSet.setComboIndex(Purpose.XFORMCB, xform);
      cSet.setComboIndex(Purpose.FILLOPTIONS, 0);
      cSet.setHostName(name);
   }

   this(YinYang other)
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
      string s = "YinYang "~to!string(++nextOid);
      super(w, parent, s, AC_YINYANG);
      group = ACGroups.SHAPES;
      closed = true;
      hOff = vOff = 0;
      altColor = new RGBA(1,1,1,1);
      center = Coord(0.5*width, 0.5*height);
      lineWidth = 0.5;
      fill = true;
      unit = width > height? height*0.4: width*0.4;
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
      cbb.appendText("Stretch-H");
      cbb.appendText("Stretch-V");
      cbb.appendText("Skew-H");
      cbb.appendText("Skew-V");
      cbb.appendText("Rotate");
      cbb.appendText("Flip-H");
      cbb.appendText("Flip-V");
      cbb.setActive(0);
      cSet.add(cbb, ICoord(190, vp), Purpose.XFORMCB);
      new MoreLess(cSet, 1, ICoord(295, vp), true);

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
         modifyTransform(xform, more, coarse);
      }
      dirty = true;
      aw.dirty = true;
      reDraw();
   }

   override void render(Context c)
   {
      c.setLineWidth(lineWidth);

      c.translate(hOff+center.x, vOff+center.y);
      if (compoundTransform())
         c.transform(tm);
      c.translate(-center.x, -center.y);

      c.moveTo(oPath[0].x, oPath[0].y);
      c.curveTo(oPath[1].x, oPath[1].y, oPath[2].x, oPath[2].y, oPath[3].x, oPath[3].y);
      c.curveTo(oPath[4].x, oPath[4].y, oPath[5].x, oPath[5].y, oPath[6].x, oPath[6].y);
      c.curveTo(oPath[7].x, oPath[7].y, oPath[8].x, oPath[8].y, oPath[9].x, oPath[9].y);
      c.curveTo(oPath[10].x, oPath[10].y, oPath[11].x, oPath[11].y, oPath[12].x, oPath[12].y);
      c.curveTo(oPath[13].x, oPath[13].y, oPath[14].x, oPath[14].y, oPath[15].x, oPath[15].y);
      c.curveTo(oPath[16].x, oPath[16].y, oPath[17].x, oPath[17].y, oPath[18].x, oPath[18].y);
      c.closePath();
      c.setSourceRgba(baseColor.red, baseColor.green, baseColor.blue, baseColor.alpha);
      if (outline)
      {
         c.fillPreserve();
         c.stroke();
      }
      else
         c.fill();

      c.moveTo(oPath[19].x, oPath[19].y);
      c.curveTo(oPath[20].x, oPath[20].y, oPath[21].x, oPath[21].y, oPath[22].x, oPath[22].y);
      c.curveTo(oPath[23].x, oPath[23].y, oPath[24].x, oPath[24].y, oPath[25].x, oPath[25].y);
      c.curveTo(oPath[26].x, oPath[26].y, oPath[27].x, oPath[27].y, oPath[28].x, oPath[28].y);
      c.curveTo(oPath[29].x, oPath[29].y, oPath[30].x, oPath[30].y, oPath[31].x, oPath[31].y);
      c.curveTo(oPath[32].x, oPath[32].y, oPath[33].x, oPath[33].y, oPath[34].x, oPath[34].y);
      c.curveTo(oPath[35].x, oPath[35].y, oPath[36].x, oPath[36].y, oPath[37].x, oPath[37].y);
      c.closePath();
      c.setSourceRgba(altColor.red, altColor.green, altColor.blue, altColor.alpha);
      if (outline)
      {
         c.fillPreserve();
         c.setSourceRgba(baseColor.red, baseColor.green, baseColor.blue, baseColor.alpha);
         c.stroke();
      }
      else
         c.fill();

      c.arc(oPath[38].x, oPath[38].y, unit*0.15, 0, 2*PI);
      c.closePath();
      c.setSourceRgba(baseColor.red, baseColor.green, baseColor.blue, baseColor.alpha);
      c.fill();
      c.arc(oPath[39].x, oPath[39].y, unit*0.15, 0, 2*PI);
      c.closePath();
      c.setSourceRgba(altColor.red, altColor.green, altColor.blue, altColor.alpha);
      c.fill();
   }
}


