
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module crescent;

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

// The sensible limita are about these
//r0 = 0.4*height, r1 = 0.24*height, d = 0.705*r1;
//r0 = 0.4*height, r1 = 0.38*height, d = 0.705*r1;

class Crescent : LineSet
{
   static int nextOid = 0;
   double radius, rr, radius2, ha;
   double dmax= 0.705, dmin = 0.3;
   double r1min = 0.24, r1max = 0.38;
   double r0, r1, d;
   double a0, a1;
   double a, b, h;
   int touching;
   bool guidelines;


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
      cSet.setToggle(Purpose.SHOWMARKERS, guidelines);
      cSet.setComboIndex(Purpose.XFORMCB, xform);
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   void afterDeserialize()
   {
      syncControls();
      dirty = true;
   }

   this(Crescent other)
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
      r0 = other.r0;
      r1 = other.r1;
      d = other.d;
      guidelines = other.guidelines;
      dirty = true;
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Crescent "~to!string(++nextOid);
      super(w, parent, s, AC_CRESCENT);
      altColor = new RGBA(0,0,0,1);
      les = true;
      fill = solid = false;

      center.x = 0.5*width;
      center.y = 0.5*height;
      // For classical crescent
      r0 = 0.4*height;
      r1 = 0.3*height;
      d = 0.3*r0;
      guidelines = true;
      tm = new Matrix(&tmData);
      setupControls(3);
      positionControls(true);
      dirty = true;
   }

   override void extendControls()
   {
      int vp = cSet.cy;

      Label l = new Label("Separation");
      cSet.add(l, ICoord(172, vp-40), Purpose.LABEL);
      new MoreLess(cSet, 0, ICoord(275, vp-40), true);
      l = new Label("Inner Radius");
      cSet.add(l, ICoord(172, vp-20), Purpose.LABEL);
      new MoreLess(cSet, 1, ICoord(275, vp-20), true);
      CheckButton cb = new CheckButton("Show GuideLines");
      cb.setActive(1);
      cSet.add(cb, ICoord(172, vp), Purpose.SHOWMARKERS);


      vp += 5;
      new InchTool(cSet, 0, ICoord(0, vp), true);

      vp += 25;
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

   override bool specificNotify(Widget w, Purpose wid)
   {
      switch (wid)
      {
      case Purpose.SHOWMARKERS:
         guidelines = !guidelines;
         break;
      default:
         return false;
      }
      return true;
   }

   override void onCSMoreLess(int instance, bool more, bool coarse)
   {
      focusLayout();
      if (instance == 0) // Distance between centers
      {
         double dd = more? 1: -1;
         d += dd;
      }
      else if (instance == 1)  // Radius of smaller circle
      {
         if (more)
         {
            if (r1+1 > r0)
               r1 = r0;
            else
               r1 += 1;
         }
         else
         {
            if (r1-1 < 5)
               r1 = 5;
            else
               r1 -= 1;
         }
      }
      else if (instance == 2)
         modifyTransform(xform, more, coarse);
      else
         return;
      dirty = true;
      aw.dirty = true;
      reDraw();
   }

   void getAngle2(Coord a, Coord b)
   {
      double hc = (a.y-b.y)/2;
      ha = atan2(hc,radius2);
   }

   void figureIPs()
   {
      double ad = abs(d);
      touching = -1;
      if (ad > r0+r1)
         touching = 4;
      if (ad == r0+r1)
         touching = 3;
      if (ad == r0-r1)
         touching = 2;
      if (ad < abs(r1-r0))
         touching = 1;
      if (ad == 0)
         touching = 0;
      if (touching != -1)
         return;
      b=(r0*r0-r1*r1-d*d)/(2*ad);
      h = sqrt(r1*r1-b*b);
      a=sqrt(r0*r0-h*h);

      a0 = atan2(h,a);
      a1 = atan2(h,b);
   }

   override void render(Context c)
   {
      if (dirty)
      {
         figureIPs();
         dirty = false;
      }
      c.setLineWidth(lineWidth/((tf.hScale+tf.vScale)/2));
      c.setLineJoin(les? CairoLineJoin.MITER: CairoLineJoin.ROUND);
      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);

      c.translate(hOff+center.x, vOff+center.y);
      if (compoundTransform())
         c.transform(tm);
      c.translate(-center.x, -center.y);

      if (touching != -1)
      {

         c.arc(center.x, center.y, r0, 0, PI*2);
         c.closePath();
         c.stroke();
         if (guidelines)
         {
            c.newPath();
            c.arc(center.x+d, center.y, r1, 0, PI*2);
            c.closePath();
            c.setLineWidth(0.5);
            c.setSourceRgb(1,0,0);
            c.stroke();
         }
         return;
      }


      c.setSourceRgb(0,0,0);
      if (d < 0)
      {
         c.arc(center.x, center.y, r0, a0+PI, -(a0+PI));
         c.arcNegative(center.x+d, center.y, r1, -(a1+PI), a1+PI);
      }
      else
      {
         c.arcNegative(center.x, center.y, r0, -a0, a0);
         c.arc(center.x+d, center.y, r1, a1, -a1);
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


