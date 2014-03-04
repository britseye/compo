
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module rgradient;

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

class RGradient: ACBase
{
   static int nextOid = 0;
   double outrad, inrad;
   double[50] opStops;
   Coord center;
   int nStops;
   double maxOpacity;
   bool mark, revfade;
   int gType;
   Pattern pat;
   Label ov;
   CheckButton outlineCB;

   override void syncControls()
   {
      cSet.toggling(false);
      cSet.setToggle(Purpose.SOLID, mark);
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(RGradient other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      outrad = other.outrad;
      inrad = other.inrad;
      gType = other.gType;
      nStops = other.nStops;
      center = other.center;
      maxOpacity= other.maxOpacity;
      mark = other.mark;
      revfade = other.revfade;
      setupStops();
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "RGradient "~to!string(++nextOid);
      super(w, parent, s, AC_RGRADIENT, ACGroups.EFFECTS);
      notifyHandlers ~= &RGradient.notifyHandler;

      baseColor = new RGBA(1,1,1);
      maxOpacity = 1.0;
      gType = 0;
      nStops = 50;
      center.x = width/2;
      center.y = height/2;
      if (width > height)
      {
         outrad = 0.5*height;
         inrad = 0.3*height;
      }
      else
      {
         outrad = 0.5*width;
         inrad = 0.3*width;
      }
      setupControls();
      positionControls(true);
      mark = true;
      revfade = false;
      setupStops();
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

      Label l = new Label("Max Opacity");
      cSet.add(l, ICoord(163, vp), Purpose.LABEL);
      new MoreLess(cSet, 0, ICoord(270, vp), true);
      ov = new Label("1.0");
      cSet.add(ov, ICoord(310, vp), Purpose.LABEL);

      vp += 30;
      CheckButton cb = new CheckButton("Show Guidelines");
      cb.setActive(1);
      cSet.add(cb, ICoord(0, vp), Purpose.SOLID);

      l = new Label("Inner Radius");
      l.setTooltipText("Adjust the radius at which the gradient starts");
      cSet.add(l, ICoord(177, vp+3), Purpose.LABEL);
      new MoreLess(cSet, 1, ICoord(270, vp+3), true);

      l = new Label("Outer Radius");
      l.setTooltipText("Adjust the radius at which the gradient ends");
      cSet.add(l, ICoord(177, vp+23), Purpose.LABEL);
      new MoreLess(cSet, 2, ICoord(270, vp+23), true);

      vp += 25;
      new InchTool(cSet, 0, ICoord(0, vp), true);

      vp += 20;
      l = new Label("Gradient Rule");
      cSet.add(l, ICoord(95, vp+5), Purpose.LABEL);
      ComboBoxText cbb = new ComboBoxText(false);
      cbb.setTooltipText("Select Gradient Type");
      cbb.setSizeRequest(148, -1);
      cbb.appendText("Gamma 2.2");
      cbb.appendText("Gamma 1.5");
      cbb.appendText("Gamma 3.0");
      cbb.appendText("Cosine 90");
      cbb.appendText("Cosine 180");
      cbb.appendText("Exponential");
      cbb.appendText("Linear");
      cbb.appendText("Bezier");
      cbb.setActive(0);
      cSet.add(cbb, ICoord(195, vp), Purpose.PATTERN);

      vp += 30;
      cb = new CheckButton("Reverse fade");
      cSet.add(cb, ICoord(0, vp), Purpose.FADELEFT);
      cSet.cy = vp+30;
   }

   override void afterDeserialize()
   {
      cSet.setComboIndex(Purpose.PATTERN, gType);
      setupStops();
   }

   override void preResize(int oldW, int oldH)
   {
      if (width > height)
         outrad = height;
      else
         outrad = width;
   }

   override bool notifyHandler(Widget w, Purpose p)
   {
      switch (p)
      {
      case Purpose.SOLID:
         mark = !mark;
         break;
      case Purpose.FADELEFT:
         revfade = !revfade;
         dirty = true;
         break;
      case Purpose.PATTERN:
         gType = (cast(ComboBoxText) w).getActive();
         dirty = true;
         break;
      default:
         return false;
      }
      return true;
   }
/*
   override bool specificNotify(Widget w, Purpose wid)
   {
      switch (wid)
      {
      case Purpose.SOLID:
         mark = !mark;
         break;
      case Purpose.FADELEFT:
         revfade = !revfade;
         dirty = true;
         break;
      case Purpose.PATTERN:
         gType = (cast(ComboBoxText) w).getActive();
         dirty = true;
         break;
      default:
         return false;
      }
      return true;
   }
*/
   override bool specificUndo(CheckPoint cp)
   {
      switch (cp.type)
      {
      case OP_OPACITY:
         maxOpacity = cp.dVal;
         break;
      case OP_VSIZE:
         inrad = cp.dVal;
         break;
      case OP_HSIZE:
         outrad = cp.dVal;
         break;
      default:
         return false;
      }
      dirty = true;
      lastOp = OP_UNDEF;
      return true;
   }

   override void onCSMoreLess(int instance, bool more, bool quickly)
   {
      focusLayout();
      dirty = true;
      switch (instance)
      {
         case 0:
            double result = maxOpacity;
            if (!molA!double(more, quickly, result, 0.01, 0, 1))
               return;
            lastOp = pushC!double(this, maxOpacity, OP_OPACITY);
            maxOpacity = result;
            string t = to!string(maxOpacity);
            if (t.length > 4)
            t = t[0..4];
            ov.setText(t);
            break;
         case 1:
            double result = inrad;
            if (!molA!double(more, quickly, result, 0.5, 5, outrad))
               return;
            lastOp = pushC!double(this, inrad, OP_VSIZE);
            inrad = result;
            break;
         case 2:
            double result = outrad;
            if (!molA!double(more, quickly, result, 0.5, 5, 1000))
               return;
            lastOp = pushC!double(this, outrad, OP_HSIZE);
            outrad = result;
            break;
         default:
            dirty = false;
            return;
      }
      aw.dirty = true;
      reDraw();
   }

   void setupStops()
   {
      double delta = 1.0/nStops;

      void gtkDefault()
      {
         opStops[0] = double.init;
      }

      void linear()
      {
         double op = 1;
         for (int i = 0; i < nStops; i++)
         {
            opStops[i] = op;
            op -= delta;
         }
      }

      void gamma(double g)
      {
         double x = 0;
         for (int i = 0; i < nStops; i++)
         {
            opStops[i] = 1-pow(x, g);
            x += delta;
         }
      }

      void cosine90()
      {
         double a = 0;
         double op;
         for (int i=0; i < nStops; i++)
         {
            op = cos(a);
            opStops[i] = op;
            a += PI/2/nStops;
         }
      }

      void cosine180()
      {
         double a = 0;
         double op;
         for (int i=0; i < nStops; i++)
         {
            op = cos(a);
            opStops[i] = (op+1)/2;
            a += PI/nStops;
         }
      }

      Coord bezierPoint(double t, Coord p0, Coord p1, Coord p2)
      {
         Coord c;
         c.x = pow(1-t, 2) * p0.x + 2 * (1-t) * t * p1.x + pow(t, 2) * p2.x;
         c.y = pow(1-t, 2) * p0.y + 2 * (1-t) * t * p1.y + pow(t, 2) * p2.y;
         return c;
      }

      void quadbezier(double x, double y)
      {
         Coord start = Coord(0, 1), end = Coord(1, 0), control = Coord(x, y);
         double t = 0;
         for (int i = 0; i < nStops; i++)
         {
            Coord a = bezierPoint(t, start, control, end);
            opStops[i] = a.y;
            t += delta;
         }
      }

      void exponential(double howClose)
      {
         double x = 0;
         double op;
         for (int i=0; i < nStops; i++)
         {
            op = exp(x);
            opStops[i] = op;
            x -= howClose;
         }
      }

      switch (gType)
      {
         case 0:
            gamma(2.2);
            break;
         case 1:
            gamma(1.5);
            break;
         case 2:
            gamma(3.0);
            break;
         case 3:
            cosine90();
            break;
         case 4:
            cosine180();
            break;
         case 5:
            exponential(0.02);
            break;
         case 6:
            quadbezier(0.8, 0);
            break;
         default:
            gtkDefault();
            break;
      }
   }

   void addStops(double r, double g, double b)
   {
      double offset = 0;
      if (revfade)
      {
         if (isNaN(opStops[0]))
         {
            pat.addColorStopRgba (0, r, g, b, 0);
            pat.addColorStopRgba (1, r, g, b, 1);
            return;
         }
         for (int i = 49; i >= 0; i--)
         {
            pat.addColorStopRgba (offset, r, g, b, opStops[i]*maxOpacity);
            offset += 0.02;
         }
      }
      else
      {
         if (isNaN(opStops[0]))
         {
            pat.addColorStopRgba (0, r, g, b, 1);
            pat.addColorStopRgba (1, r, g, b, 0);
            return;
         }
         for (int i = 0; i < nStops; i++)
         {
            pat.addColorStopRgba (offset, r, g, b, opStops[i]*maxOpacity);
            offset += 0.02;
         }
      }
   }

   void createPattern()
   {
      pat = Pattern.createRadial(hOff+center.x, vOff+center.y, inrad, hOff+center.x, vOff+center.y, outrad);
   }

   override void render(Context c)
   {
      if (dirty)
      {
         setupStops();
         dirty = false;
      }
      createPattern();
      double r = baseColor.red();
      double g = baseColor.green();
      double b = baseColor.blue();
      addStops(r, g, b);

      c.rectangle(hOff, vOff, width, height);
      c.setSource(pat);
      c.fill();

      double[2] da = [2,2];
      if (!printFlag && mark)
      {
         c.save();
         c.setDash(da, 0);
         c.setOperator(CairoOperator.SOURCE);
         c.setSourceRgb(0,0,0);
         c.moveTo(hOff+center.x-10, vOff+center.y);
         c.lineTo(hOff+center.x+10, vOff+center.y);
         c.moveTo(hOff+center.x, vOff+center.y-10);
         c.lineTo(hOff+center.x, vOff+center.y+10);
         c.setLineWidth(1);
         c.stroke();
         c.arc(hOff+center.x, vOff+center.y, inrad, 0, 2*PI);
         c.stroke();
         c.arc(hOff+center.x, vOff+center.y, outrad, 0, 2*PI);
         c.stroke();
         c.setSourceRgb(1,1,1);
         c.setDash(da, 2);
         c.moveTo(hOff+center.x-10, vOff+center.y);
         c.lineTo(hOff+center.x+10, vOff+center.y);
         c.moveTo(hOff+center.x, vOff+center.y-10);
         c.lineTo(hOff+center.x, vOff+center.y+10);
         c.setLineWidth(1);
         c.stroke();
         c.arc(hOff+center.x, vOff+center.y, inrad, 0, 2*PI);
         c.stroke();
         c.arc(hOff+center.x, vOff+center.y, outrad, 0, 2*PI);
         c.stroke();
         c.restore();
      }
   }
}
