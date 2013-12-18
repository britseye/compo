
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module lgradient;

import main;
import constants;
import acomp;
import common;
import types;
import controlset;

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

class LGradient: ACBase
{
   static int nextOid = 0;
   double rw, rh, lastH, lastV;
   double[50] opStops;
   int nStops;
   double maxOpacity;
   bool pin, outline, revfade, orient;
   int gType;
   Pattern pat;
   Label ov;
   CheckButton outlineCB;

   void syncControls()
   {
      cSet.toggling(false);
      cSet.setToggle(Purpose.SOLID, pin);
      cSet.setToggle(Purpose.FILLOUTLINE, outline);
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(LGradient other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      maxOpacity = other.maxOpacity;
      rw = other.rw;
      rh = other.rh;
      gType = other.gType;
      pin = other.pin;
      outline = other.outline;
      revfade = other.revfade;
      orient = other.orient;
      nStops = other.nStops;
      setupStops();
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "LGradient "~to!string(++nextOid);
      super(w, parent, s, AC_LGRADIENT);
      hOff = width/4;
      vOff = height/4;
      rw = width/2;
      rh = height/2;
      baseColor = new RGBA(1,1,1);
      maxOpacity = 1.0;
      gType = 0;
      nStops = 50;

      setupControls();
      positionControls(true);
      outline = false;
      pin = true;
      revfade = false;
      orient = false;
      setupStops();
   }

   override int getNextOid()
   {
      return ++nextOid;
   }

   void extendControls()
   {
      int vp = cSet.cy;

      Button b = new Button("Color");
      cSet.add(b, ICoord(0, vp), Purpose.COLOR);

      Label l = new Label("Max Opacity");
      cSet.add(l, ICoord(153, vp), Purpose.LABEL);
      new MoreLess(cSet, 0, ICoord(260, vp), true);
      ov = new Label("1.0");
      cSet.add(ov, ICoord(300, vp), Purpose.LABEL);

      vp += 35;
      CheckButton cb = new CheckButton("Pin to full size");
      cb.setActive(1);
      cSet.add(cb, ICoord(0, vp), Purpose.SOLID);

      l = new Label("Width");
      l.setTooltipText("Adjust width - hold down <Ctrl> for faster action");
      cSet.add(l, ICoord(195, vp), Purpose.LABEL);
      new MoreLess(cSet, 1, ICoord(260, vp), true);

      vp += 20;
      outlineCB = new CheckButton("Show Outline");
      cSet.add(outlineCB, ICoord(0, vp), Purpose.FILLOUTLINE);

      l = new Label("Height");
      l.setTooltipText("Adjust height - hold down <Ctrl> for faster action");
      cSet.add(l, ICoord(195, vp), Purpose.LABEL);
      new MoreLess(cSet, 2, ICoord(260, vp), true);

      vp += 25;
      new InchTool(cSet, 0, ICoord(0, vp), true);

      vp += 35;
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
      cbb.setActive(0);
      cSet.add(cbb, ICoord(195, vp), Purpose.XFORMCB);

      vp += 35;
      cb = new CheckButton("Reverse fade");
      cSet.add(cb, ICoord(0, vp), Purpose.FADELEFT);
      cb = new CheckButton("Vertical");
      cSet.add(cb, ICoord(150, vp), Purpose.FADETOP);

      cSet.cy = vp+30;
   }

   void preResize(int oldW, int oldH)
   {
      hOff = width/4;
      vOff = height/4;
      rw = width/2;
      rh = height/2;
   }

   void onCSNotify(Widget w, Purpose wid)
   {

      switch (wid)
      {
      case Purpose.COLOR:
         dummy.grabFocus();
         lastOp = push!RGBA(this, baseColor, OP_COLOR);
         setColor(false);
         dirty = true;
         break;
      case Purpose.SOLID:
         pin = !pin;
         if (pin)
         {
            outlineCB.setActive(0);
         }
         else
         {
            outlineCB.setActive(1);
         }
         dirty = true;
         break;
      case Purpose.FILLOUTLINE:
         outline = !outline;
         break;
      case Purpose.XFORMCB:
         gType = (cast(ComboBoxText) w).getActive();
         setupStops();
         dirty = true;
         break;
      case Purpose.FADELEFT:
         revfade = !revfade;
         dirty = true;
         break;
      case Purpose.FADETOP:
         orient = !orient;
         dirty = true;
         break;
      default:
         return;
      }
      aw.dirty = true;
      reDraw();
   }

   void onCSMoreLess(int instance, bool more, bool coarse)
   {
      dummy.grabFocus();
      double n = more? 1: -1;
      if (coarse)
         n *= 10;
      if (instance == 0)
      {
         lastOp = pushC!double(this, maxOpacity, OP_OPACITY);
         double nv;
         if (more)
         {
            if (maxOpacity == 0)
               nv = 0.1;
            else
            {
               nv = maxOpacity*1.05;
               if (nv > 1)
                  nv = 1;
            }
         }
         else
         {
            nv = maxOpacity*0.95;
            if (nv <= 0.1)
               nv = 0;
         }
         maxOpacity = nv;
         string t = to!string(maxOpacity);
         if (t.length > 4)
         t = t[0..4];
         ov.setText(t);
         dirty = true;
      }
      else if (instance == 1)
      {
         lastOp = pushC!double(this, rw, OP_HSIZE);
         rw += n;
         dirty = true;
      }
      else if (instance == 2)
      {
         lastOp = pushC!double(this, rh, OP_VSIZE);
         rh += n;
         dirty = true;
      }
      aw.dirty = true;
      reDraw();
   }

   void undo()
   {
      CheckPoint cp;
      cp = popOp();
      if (cp.type == 0)
         return;
      switch (cp.type)
      {
      case OP_COLOR:
         baseColor = cp.color.copy();
         lastOp = OP_UNDEF;
         break;
      case OP_OPACITY:
         maxOpacity = cp.dVal;
         ov.setText(to!string(maxOpacity));
         lastOp = OP_UNDEF;
         break;
      case OP_HSIZE:
         rw = cp.dVal;
         lastOp = OP_UNDEF;
         break;
      case OP_VSIZE:
         rh = cp.dVal;
         lastOp = OP_UNDEF;
         break;
      case OP_MOVE:
         Coord t = cp.coord;
         hOff = t.x;
         vOff = t.y;
         lastOp = OP_UNDEF;
      default:
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
      if (orient)
      {
         if (pin)
            pat = Pattern.createLinear(width/2, 0, width/2, height);
         else
            pat = Pattern.createLinear(hOff+rw/2, vOff, hOff+rw/2, vOff+rh);
      }
      else
      {
         if (pin)
            pat = Pattern.createLinear(0, height/2, width, height/2);
         else
            pat = Pattern.createLinear(hOff, vOff+rh/2, hOff+rw, vOff+rh/2);
      }
   }

   void render(Context c)
   {
      if (!pin && (hOff != lastH || vOff != lastV))
         dirty = true;
      if (dirty || pat is null)
      {
         createPattern();
         double r = baseColor.red();
         double g = baseColor.green();
         double b = baseColor.blue();
         addStops(r, g, b);
         dirty = false;
         lastH = hOff;
         lastV = vOff;
      }
      // for testing
      c.setSourceRgb(0,0,0);
      c.paint();

      c.setSource(pat);
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

   }
}


