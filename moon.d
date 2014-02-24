
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module moon;

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

enum
{
   ARCARC,
   ARCARN,
   ARNARC,
   ARNARN,
   ARCNON,
   ARNNON
}

struct MoonData
{
   int day;
   int sequence;
   Coord c0;
   double r0;
   double sa0, ea0;
   Coord c1;
   double r1;
   double sa1, ea1;
}
class Moon : LineSet
{
   static int nextOid = 0;
   MoonData[] mda;
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
      if (outline)
         cSet.setToggle(Purpose.OUTLINE, true);
      cSet.setComboIndex(Purpose.XFORMCB, xform);
      cSet.setComboIndex(Purpose.FILLOPTIONS, 0);
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(Moon other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      altColor = other.altColor.copy();
      lineWidth = other.lineWidth;
      les = other.les;
      fill = other.fill;
      outline = other.outline;
      fillFromPattern = other.fillFromPattern;
      fillUid = other.fillUid;
      updateFillUI();
      center = other.center;
      xform = other.xform;
      tf = other.tf;
      radius = other.radius;
      radius2 = other.radius2;
      ha = other.ha;
      day = other.day;
      dirty = true;
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Moon "~to!string(++nextOid);
      super(w, parent, s, AC_MOON);
      group = ACGroups.SHAPES;
      closed = true;
      altColor = new RGBA(0,0,0,1);
      les = true;
      fill = false;

      center.x = 0.5*width;
      center.y = 0.5*height;
      radius = (width > height)? 0.4*height: 0.4*width;
      constructTable();
      day = 1;
      tm = new Matrix(&tmData);

      setupControls(3);
      outline = true;
      positionControls(true);
      dirty = true;
   }

   override void extendControls()
   {
      int vp = cSet.cy;
      Label l = new Label("Size");
      cSet.add(l, ICoord(245, vp-64), Purpose.LABEL);
      new MoreLess(cSet, 0, ICoord(275, vp-64), true);

      dl = new Label("Phase");
      cSet.add(dl, ICoord(172, vp-40), Purpose.LABEL);
      new MoreLess(cSet, 1, ICoord(275, vp-40), true);
      dl = new Label("Waxing Crescent");
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
      new MoreLess(cSet, 2, ICoord(275, vp), true);

      cSet.cy = vp+35;
   }

   override void afterDeserialize()
   {
      constructTable();
      setPhaseDesc();
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
         double delta = coarse? 1.05: 1.01;
         if (more)
            radius *= delta;
         else
         {
            if (radius > 10)
               radius /= delta;
         }
         constructTable();
      }
      else if (instance == 1)
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
      else if (instance == 2)
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

   void constructTable()
   {
      mda.length = 0;
      for (int i = 0; i < 28; i++)
      {
         MoonData md;
         md.day = i;
         if (i == 0)
         {
            mda ~= md;
            continue;
         }
         if (i < 7)
         {
            md.sequence = ARCARN;
            md.c0 = center;
            md.r0 = radius;
            md.sa0 = 3*PI/2;
            md.ea0 = PI/2;
            int td = i;
            double d = radius-td*radius/7;
            getAngle2(d);
            md.c1 = Coord(center.x+d-radius2, center.y);
            md.r1 = radius2;
            md.sa1 = ha;
            md.ea1 = -ha;
         }
         else if (i == 7)
         {
            md.sequence = ARCNON;
            md.c0 = center;
            md.r0 = radius;
            md.sa0 = 3*PI/2;
            md.ea0 = PI/2;
         }
         else if (i < 14)
         {
            md.sequence = ARCARC;
            md.c0 = center;
            md.r0 = radius;
            md.sa0 = 3*PI/2;
            md.ea0 = PI/2;
            int td = i-7;
            double d = td*radius/7;
            getAngle2(d);
            md.c1 = Coord(center.x-d+radius2, center.y);
            md.r1 = radius2;
            md.sa1 = PI-ha;
            md.ea1 = PI+ha;
         }
         else if (i == 14)
         {
            md.sequence = ARCNON;
            md.c0 = center;
            md.r0 = radius;
            md.sa0 = 0;
            md.ea0 = 2*PI;
         }
         else if (i < 21)
         {
            md.sequence = ARNARN;
            md.c0 = center;
            md.r0 = radius;
            md.sa0 = 3*PI/2;
            md.ea0 = PI/2;
            int td = i-14;
            double d = radius-td*radius/7;
            getAngle2(d);
            md.c1 = Coord(center.x+d-radius2, center.y);
            md.r1 = radius2;
            md.sa1 = ha;
            md.ea1 = -ha;

         }
         else if (i == 21)
         {
            md.sequence = ARNNON;
            md.c0 = center;
            md.r0 = radius;
            md.sa0 = 3*PI/2;
            md.ea0 = PI/2;
         }
         else
         {
            md.sequence = ARNARC;
            md.c0 = center;
            md.r0 = radius;
            md.sa0 = 3*PI/2;
            md.ea0 = PI/2;
            double td = i-21;
            double d = td*radius/7;
            getAngle2(d);
            md.c1 = Coord(center.x-d+radius2, center.y);
            md.r1 = radius2;
            md.sa1=PI-ha;
            md.ea1 = PI+ha;
         }
         mda ~= md;
      }
   }

   override void render(Context c)
   {
      if (day == 0 || day == 28)
         return;
      c.setLineWidth(0);
      c.setLineJoin(les? CairoLineJoin.MITER: CairoLineJoin.ROUND);
      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);
      c.translate(hOff+center.x, vOff+center.y);
      if (compoundTransform())
         c.transform(tm);
      c.translate(-center.x, -center.y);

      with (mda[day])
      {
         switch (sequence)
         {
            case ARCARC:
               c.arc(c0.x, c0.y, r0, sa0, ea0);
               c.arc(c1.x, c1.y, r1, sa1, ea1);
               break;
            case ARCARN:
               c.arc(c0.x, c0.y, r0, sa0, ea0);
               c.arcNegative(c1.x, c1.y, r1, sa1, ea1);
               break;
            case ARNARC:
               c.arcNegative(c0.x, c0.y, r0, sa0, ea0);
               c.arc(c1.x, c1.y, r1, sa1, ea1);
               break;
            case ARNARN:
               c.arcNegative(c0.x, c0.y, r0, sa0, ea0);
               c.arcNegative(c1.x, c1.y, r1, sa1, ea1);
               break;
            case ARCNON:
               c.arc(c0.x, c0.y, r0, sa0, ea0);
               break;
            case ARNNON:
               c.arcNegative(c0.x, c0.y, r0, sa0, ea0);
               break;
            default:
               break;
         }
         c.closePath();
      }
      strokeAndFill(c, lineWidth, outline, fill);
   }
}
