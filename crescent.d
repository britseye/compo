
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

class Crescent : LineSet
{
   static int nextOid = 0;
   double radius, rr, radius2, ha;
   bool fill, solid;
   RGBA saveAltColor;

   void syncControls()
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
      oPath = other.oPath.dup;
      xform = other.xform;
      tf = other.tf;
      radius = other.radius;
      rr = other.rr;
      radius2 = other.radius2;
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

      center.x = width/2;
      center.y = height/2;
      tm = new Matrix(&tmData);
      radius = (width > height)? 0.4*height: 0.4*width;
      rr = -2;
      radius2 = (1+exp(rr))*radius;
//writefln("%f %f %f", rr, exp(rr), radius);

      setupControls(3);
      positionControls(true);
      dirty = true;
   }

   override void extendControls()
   {
      int vp = cSet.cy;

      Label l = new Label("Phase");
      cSet.add(l, ICoord(172, vp-40), Purpose.LABEL);
      new MoreLess(cSet, 0, ICoord(275, vp-40), true);

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

      //RenameGadget rg = new RenameGadget(cSet, ICoord(0, vp), name, true);
   }

   void preResize(int oldW, int oldH)
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

   void onCSNotify(Widget w, Purpose wid)
   {
      switch (wid)
      {
      case Purpose.COLOR:
         lastOp = push!RGBA(this, baseColor, OP_COLOR);
         setColor(false);
         dummy.grabFocus();
         break;
      case Purpose.FILLCOLOR:
         lastOp = push!RGBA(this, altColor, OP_ALTCOLOR);
         setColor(true);
         break;
      case Purpose.LESROUND:
         if ((cast(RadioButton) w).getActive())
            les = false;
         break;
      case Purpose.LESSHARP:
         if ((cast(RadioButton) w).getActive())
            les = true;
         break;
      case Purpose.FILL:
         fill = !fill;
         break;
      case Purpose.SOLID:
         if (lastOp != OP_SOLID)
            solid = !solid;
         if (solid)
         {
            cSet.disable(Purpose.FILL);
            cSet.disable(Purpose.FILLCOLOR);
         }
         else
         {
            cSet.enable(Purpose.FILL);
            cSet.enable(Purpose.FILLCOLOR);
         }
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

   void onCSMoreLess(int instance, bool more, bool coarse)
   {
      dummy.grabFocus();
      if (instance == 0)
      {
         if (more)
         {
            if (rr < 3)
               rr += 0.1;
            else
               return;
         }
         else
         {
            rr -= 0.1;
         }
         radius2 = (1+exp(rr))*radius;
      }
      else if (instance == 1)
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
      ha = asin(hc/radius2);
   }

   void render(Context c)
   {
      c.setLineWidth(lineWidth);
      c.setLineJoin(les? CairoLineJoin.MITER: CairoLineJoin.ROUND);
      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);
      c.translate(hOff+width/2, vOff+height/2);
      if (compoundTransform())
         c.transform(tm);
      c.translate(-(width/2), -(height/2));
      c.newSubPath();
      c.arc(width/2, height/2, radius, 3*PI/2, PI/2);
      if (dirty)
      {
         double x, y, sx, sy;
         c.getCurrentPoint(x, y);
         sx = x; sy = y-2*radius;
         getAngle2(Coord(x, y), Coord(sx, sy));
         dirty = false;
      }
      c.arcNegative(width/2-radius2*cos(ha), height/2, radius2, ha, -ha);
      c.closePath();
      if (solid)
      {
         c.setSourceRgba(baseColor.red, baseColor.green, baseColor.blue, 1.0);
         c.fill();
      }
      else
      {
         c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);
         if (fill)
         {
            c.strokePreserve();
            c.setSourceRgba(altColor.red, altColor.green, altColor.blue, 1.0);
            c.fill();
         }
         else
            c.stroke();
      }
      if (!isMoved) cSet.setDisplay(0, reportPosition());
   }
}


