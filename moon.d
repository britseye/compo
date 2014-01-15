
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module moon;

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

class Moon : LineSet
{
   static int nextOid = 0;
   double radius, radius2, ha;
   int day;
   Label dl;

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
      cSet.setComboIndex(Purpose.XFORMCB, xform);
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(Moon other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      lineWidth = other.lineWidth;
      les = other.les;
      fill = other.fill;
      solid = other.solid;
      altColor = other.altColor.copy();
      center = other.center;
      xform = other.xform;
      tf = other.tf;
      radius = other.radius;
      radius2 = other.radius2;
      ha = other.ha;
      dirty = true;
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Moon "~to!string(++nextOid);
      super(w, parent, s, AC_MOON);
      altColor = new RGBA(0,0,0,1);
      les = true;
      fill = solid = false;

      center.x = lpX+0.5*width;
      center.y = lpY+0.5*height;
      tm = new Matrix(&tmData);
      radius = (width > height)? 0.4*height: 0.4*width;

      setupControls(3);
      positionControls(true);
      dirty = true;
   }

   override void extendControls()
   {
      int vp = cSet.cy;

      dl = new Label("Phase");
      cSet.add(dl, ICoord(172, vp-40), Purpose.LABEL);
      new MoreLess(cSet, 0, ICoord(275, vp-40), true);
      dl = new Label("New Moon");
      cSet.add(dl, ICoord(172, vp-20), Purpose.INFO1);

      vp += 5;
      new InchTool(cSet, 0, ICoord(0, vp), true);

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

      new MoreLess(cSet, 1, ICoord(275, vp), true);

      vp += 35;

      CheckButton check = new CheckButton("Fill with color");
      cSet.add(check, ICoord(0, vp), Purpose.FILL);

      check = new CheckButton("Solid");
      cSet.add(check, ICoord(115, vp), Purpose.SOLID);

      Button b = new Button("Fill Color");
      cSet.add(b, ICoord(240, vp-5), Purpose.FILLCOLOR);

      vp += 25;
      cSet.cy = vp;

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
      dirty = true;
   }

   void setPhaseDesc()
   {
      switch (day)
      {
         case 0:
         case 28:
            dl.setText("New Moon");
            break;
         case 1:
         case 2:
         case 3:
         case 4:
         case 5:
         case 6:
            dl.setText("Waxing Crescent");
            break;
         case 7:
            dl.setText("First Quarter");
            break;
         case 8:
         case 9:
         case 10:
         case 11:
         case 12:
         case 13:
            dl.setText("Waxing Gibbous");
            break;
         case 14:
            dl.setText("Full Moon");
            break;
         case 15:
         case 16:
         case 17:
         case 18:
         case 19:
         case 20:
            dl.setText("Waning Gibbous");
            break;
         case 21:
            dl.setText("Last Quarter");
            break;
         default:
            dl.setText("Waning Crescent");
            break;
      }
   }

   override void onCSMoreLess(int instance, bool more, bool coarse)
   {
      focusLayout();
      if (instance == 0)
      {
         if (more)
            day = (day+1)%28;
         else
         {
            if (day-1 < 0)
               day = 27;
            else
               day--;
         }
         setPhaseDesc();
      }
      else if (instance == 1)
         modifyTransform(xform, more, coarse);
      else
         return;
      dirty = true;
      aw.dirty = true;
      reDraw();
   }

   void getAngle2(double d)
   {
      radius2 = (radius*radius+d*d)/(2*d);
      ha = atan2(radius, radius2-d);
   }

   override void render(Context c)
   {
      if (day == 0 || day == 28)
         return;
      c.setLineWidth(lineWidth/((tf.hScale+tf.vScale)/2));
      c.setLineJoin(les? CairoLineJoin.MITER: CairoLineJoin.ROUND);
      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);
      c.translate(hOff+center.x, vOff+center.y);
      if (compoundTransform())
         c.transform(tm);
      c.translate(-center.x, -center.y);
      if (day < 7)
      {
         c.arc(center.x, center.y, radius, 3*PI/2, PI/2);
         int td = day;
         double d = radius-td*radius/7;
         getAngle2(d);
         c.arcNegative(center.x+d-radius2, center.y, radius2, ha, -ha);
      }
      else if (day == 7)
         c.arc(center.x, center.y, radius, 3*PI/2, PI/2);
      else if (day < 14)
      {
         c.arc(center.x, center.y, radius, 3*PI/2, PI/2);
         int td = day-7;
         double d = td*radius/7;
         getAngle2(d);
         c.arc(center.x-d+radius2, center.y, radius2, PI-ha, PI+ha);
      }
      else if (day == 14)
         c.arc(center.x, center.y, radius, 0, 2*PI);
      else if (day < 21)
      {
         c.arcNegative(center.x, center.y, radius, 3*PI/2, PI/2);
         int td = day-14;
         double d = radius-td*radius/7;
         getAngle2(d);
         c.arcNegative(center.x+d-radius2, center.y, radius2, ha, -ha);
      }
      else if (day == 21)
         c.arcNegative(center.x, center.y, radius, 3*PI/2, PI/2);
      else
      {
         c.arcNegative(center.x, center.y, radius, 3*PI/2, PI/2);
         double td = day-21;
         double d = td*radius/7;
         getAngle2(d);
         c.arc(center.x-d+radius2, center.y, radius2, PI-ha, PI+ha);
      }
      c.closePath();
      c.setSourceRgba(baseColor.red, baseColor.green, baseColor.blue, 1.0);
      if (!(solid || fill))
         c.stroke();
      else
         doFill(c, solid, fill);
      if (!isMoved) cSet.setDisplay(0, reportPosition());
   }
}


