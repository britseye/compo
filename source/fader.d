
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module fader;

import mainwin;
import constants;
import acomp;
import common;
import types;
import controlset;
import mol;

import std.stdio;
import std.math;
import std.conv;

import gtk.Widget;
import gtk.Label;
import gtk.Button;
import gtk.SpinButton;
import gtk.CheckButton;
import gtk.ComboBoxText;
import gdk.RGBA;
import cairo.Context;
import cairo.Pattern;
import gtkc.cairotypes;

class Fader: ACBase
{
   static int nextOid = 0;
   double rw, rh;
   double opacity;
   bool pin, outline;
   int gType;
   Pattern pat;
   Label ov;

   override void syncControls()
   {
      cSet.toggling(false);
      cSet.setToggle(Purpose.SOLID, pin);
      cSet.setToggle(Purpose.FILLOUTLINE, outline);
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(Fader other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      rw = other.rw;
      rh = other.rh;
      outline = other.outline;
      pin = other.pin;
      opacity = other.opacity;
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      mixin(initString!Fader());
      super(w, parent, sname, AC_FADER, ACGroups.EFFECTS, ahdg);

      hOff = width/4;
      vOff = height/4;
      rw = width/2;
      rh = height/2;
      baseColor = new RGBA(1,1,1);
      opacity = 0.95*0.95;
      pin = false;
      outline = true;

      setupControls();
      positionControls(true);
      outline = true;
   }

   override int getNextOid()
   {
      return ++nextOid;
   }

   override void extendControls()
   {
      int vp = cSet.cy;

      Button b = new Button("Color");
      cSet.add(b, ICoord(0, vp), Purpose.COLOR);

      Label l = new Label("Opacity");
      cSet.add(l, ICoord(195, vp), Purpose.LABEL);
      new MoreLess(cSet, 0, ICoord(260, vp), true);
      ov = new Label(to!string(opacity));
      cSet.add(ov, ICoord(300, vp), Purpose.OPACITY);

      vp += 30;
      CheckButton cb = new CheckButton("Show Outline");
      cb.setActive(true);
      cSet.add(cb, ICoord(0, vp), Purpose.FILLOUTLINE);

      vp += 20;
      cb = new CheckButton("Pin to Size");
      cb.setActive(false);
      cSet.add(cb, ICoord(0, vp), Purpose.PIN);

      l = new Label("Width");
      l.setTooltipText("Adjust width - hold down <Ctrl> for faster action");
      cSet.add(l, ICoord(195, vp), Purpose.LABEL);
      new MoreLess(cSet, 1, ICoord(260, vp), true);

      vp += 20;
      l = new Label("Height");
      l.setTooltipText("Adjust height - hold down <Ctrl> for faster action");
      cSet.add(l, ICoord(195, vp), Purpose.LABEL);
      new MoreLess(cSet, 2, ICoord(260, vp), true);

      vp += 20;
      new InchTool(cSet, 0, ICoord(0, vp+5), true);

      cSet.cy = vp+40;
   }

   override void afterDeserialize()
   {
      string t = to!string(opacity);
      if (t.length > 4)
      t = t[0..4];
      ov.setText(t);
   }

   override void preResize(int oldW, int oldH)
   {
      hOff = width/4;
      vOff = height/4;
      rw = width/2;
      rh = height/2;
   }

   override bool notifyHandler(Widget w, Purpose p)
   {
      switch (p)
      {
      case Purpose.PIN:
         pin = !pin;
         if (pin)
            outline= false;
         break;
      case Purpose.FILLOUTLINE:
         outline = !outline;
         break;
      default:
         return false;
      }
      return true;
   }

   override bool undoHandler(CheckPoint cp)
   {
      switch (cp.type)
      {
      case OP_OPACITY:
         opacity = cp.dVal;
         ov.setText(to!string(opacity));
         lastOp = OP_UNDEF;
         break;
      case OP_HSIZE:
         rw = cp.dVal;
         lastOp = OP_UNDEF;
         break;
      case OP_VSIZE:
         rw = cp.dVal;
         lastOp = OP_UNDEF;
         break;
      default:
         return false;
      }
      lastOp = OP_UNDEF;
      return true;
   }

   override void onCSMoreLess(int instance, bool more, bool quickly)
   {
      focusLayout();
      switch (instance)
      {
         case 0:
            double result = opacity;
            if (!molA!double(more, quickly, result, 0.01, 0, 1))
               return;
            lastOp = pushC!double(this, opacity, OP_OPACITY);
            opacity = result;
            string t = to!string(opacity);
            if (t.length > 4)
            t = t[0..4];
            ov.setText(t);
            break;
         case 1:
            double result = rw;
            if (!molA!double(more, quickly, result, 0.01, 0, cast(double) width))
               return;
            lastOp = pushC!double(this, rw, OP_HSIZE);
            rw = result;
            break;
         case 2:
            double result = rh;
            if (!molA!double(more, quickly, result, 0.01, 0, cast(double) height))
               return;
            lastOp = pushC!double(this, rh, OP_VSIZE);
            rh = result;
            break;
         default:
            return;
      }
      aw.dirty = true;
      reDraw();
   }

   override void render(Context c)
   {
      double r = baseColor.red();
      double g = baseColor.green();
      double b = baseColor.blue();
      c.setSourceRgba(r,g,b, opacity);
      if (pin)
      {
         c.paint();
      }
      else
      {
         c.moveTo(hOff, vOff);
         c.lineTo(hOff, vOff+rh);
         c.lineTo(hOff+rw, vOff+rh);
         c.lineTo(hOff+rw, vOff);
         c.closePath();
         c.fillPreserve();
      }
      if (outline)
      {
         c.setSourceRgb(0,0,0);
         c.setLineWidth(0.3);
         c.stroke();
      }

      if (!isMoved) cSet.setDisplay(0, reportPosition());
   }
}


