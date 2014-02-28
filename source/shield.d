
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module shield;

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

class Shield: LineSet
{
   enum {PLAIN, POINTED, FANCY }
   static int nextOid = 0;
   static Coord[10] plain = [ Coord(-1, -1.25), Coord(-0.5, -1.1), Coord(0.5, -1.1), Coord(1, -1.25),
                             Coord(1, 0), Coord(1.2, 1.25), Coord(0, 1.25),
                             Coord(-1.2, 1.25), Coord(-1, 0), Coord(-1, -1.25) ];
   static Coord[10] pointed = [ Coord(-1, -1.25), Coord(-0.5, -1.1), Coord(0.5, -1.1), Coord(1, -1.25),
                             Coord(1, 0), Coord(1.1, 1.0), Coord(0, 1.25),
                             Coord(-1.1, 1.0), Coord(-1, 0), Coord(-1, -1.25) ];
   static Coord[13] fancy = [ Coord(-1, -1.25), Coord(-0.75, -1.1), Coord(-0.25, -1.1), Coord(0, -1.3),
                             Coord(0.25, -1.1), Coord(0.75, -1.1), Coord(1, -1.25),
                             Coord(1, 0), Coord(1.1, 1.0), Coord(0, 1.25),
                             Coord(-1.1, 1.0), Coord(-1, 0), Coord(-1, -1.25) ];
   double unit;
   int style;

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

   this(Shield other)
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
      fillFromPattern = other.fillFromPattern;
      fillUid = other.fillUid;
      updateFillUI();
      style = other.style;
      constructBase();
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Shield "~to!string(++nextOid);
      super(w, parent, s, AC_SHIELD);
      group = ACGroups.SHAPES;
      closed = true;
      hOff = vOff = 0;
      altColor = new RGBA(1,0,0,1);
      center = Coord(0.5*width, 0.5*height);
      lineWidth = 0.5;
      fill = false;
      unit = width > height? height*0.3: width*0.3;
      constructBase();
      xform = 0;
      tm = new Matrix(&tmData);
      style = PLAIN;

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
      cbb.setSizeRequest(104, -1);
      cbb.appendText("Plain");
      cbb.appendText("Pointed");
      cbb.appendText("Scalloped");
      cbb.setActive(0);
      cSet.add(cbb, ICoord(190, vp), Purpose.PATTERN);

      cbb = new ComboBoxText(false);
      cbb.setTooltipText("Select transformation to apply");
      cbb.setSizeRequest(104, -1);
      cbb.appendText("Scale");
      cbb.appendText("Stretch-H");
      cbb.appendText("Stretch-V");
      cbb.appendText("Skew-H");
      cbb.appendText("Skew-V");
      cbb.appendText("Rotate");
      cbb.appendText("Flip-H");
      cbb.appendText("Flip-V");
      cbb.setActive(0);
      cSet.add(cbb, ICoord(190, vp+30), Purpose.XFORMCB);
      new MoreLess(cSet, 1, ICoord(295, vp+35), true);

      cSet.cy = vp+70;
   }

   override void afterDeserialize()
   {
      constructBase();
   }

   override void preResize(int oldW, int oldH)
   {
      double hr = cast(double) width/oldW;
      double vr = cast(double) height/oldH;
      unit = width>height? 0.6666*height: 0.6666*width;
      hOff *= hr;
      vOff *= vr;
   }

   override bool specificNotify(Widget w, Purpose wid)
   {
      focusLayout();
      switch (wid)
      {
      case Purpose.PATTERN:
         style = (cast(ComboBoxText) w).getActive();
         constructBase();
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
         unit = cp.dVal;
         constructBase();
         break;
      default:
         return false;
      }
      lastOp = OP_UNDEF;
      return true;
   }

   void constructBase()
   {
      if (style == 0)
         oPath = plain.dup;
      else if (style == POINTED)
         oPath = pointed.dup;
      else
         oPath = fancy.dup;
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
         {
            lastOp = pushC!double(this, unit, OP_SIZE);
            unit *= delta;
         }
         else
         {
            if (unit > 0.1)
            {
               lastOp = pushC!double(this, unit, OP_SIZE);
               unit /= delta;
            }
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
      c.setLineWidth(0);
      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);

      c.translate(hOff+center.x, vOff+center.y);
      if (compoundTransform())
         c.transform(tm);
      c.translate(-center.x, -center.y);
      if (style == FANCY)
      {
         c.moveTo(oPath[0].x, oPath[0].y);
         c.curveTo(oPath[1].x, oPath[1].y, oPath[2].x, oPath[2].y, oPath[3].x, oPath[3].y);
         c.curveTo(oPath[4].x, oPath[4].y, oPath[5].x, oPath[5].y, oPath[6].x, oPath[6].y);
         c.curveTo(oPath[7].x, oPath[7].y, oPath[8].x, oPath[8].y, oPath[9].x, oPath[9].y);
         c.curveTo(oPath[10].x, oPath[10].y, oPath[11].x, oPath[11].y, oPath[12].x, oPath[12].y);
      }
      else
      {
         c.moveTo(oPath[0].x, oPath[0].y);
         c.curveTo(oPath[1].x, oPath[1].y, oPath[2].x, oPath[2].y, oPath[3].x, oPath[3].y);
         c.curveTo(oPath[4].x, oPath[4].y, oPath[5].x, oPath[5].y, oPath[6].x, oPath[6].y);
         c.curveTo(oPath[7].x, oPath[7].y, oPath[8].x, oPath[8].y, oPath[9].x, oPath[9].y);
      }
      c.closePath();
      strokeAndFill(c, lineWidth, outline, fill);
   }
}


