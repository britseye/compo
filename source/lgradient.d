
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module lgradient;

import mainwin;
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
   double fw, fp, angle;
   double[50] opStops;
   Coord start, end, cp1, cp2;
   int nStops;
   double maxOpacity;
   bool revfade, showGuides;
   int gType, orient;
   Pattern pat;
   Label ov;

   this(LGradient other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      maxOpacity = other.maxOpacity;
      fw = other.fw;
      fp = other.fp;
      gType = other.gType;
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
      group = ACGroups.EFFECTS;
      fw = 0.3333333;
      fp = 0.3333333;
      angle = atan2(-1.0*height, 1.0*width);
      baseColor = new RGBA(1,1,1);
      maxOpacity = 1.0;
      gType = 0;
      nStops = 50;

      setupControls();
      positionControls(true);
      revfade = false;
      orient = 0;
      showGuides = true;
      setOrientation(0);
      dirty = true;
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
      cSet.add(l, ICoord(195, vp), Purpose.LABEL);
      new MoreLess(cSet, 0, ICoord(285, vp), true);
      ov = new Label("1.0");
      cSet.add(ov, ICoord(320, vp), Purpose.LABEL);

      vp += 20;
      l = new Label("Fade Width");
      l.setTooltipText("Adjust width - hold down <Ctrl> for faster action");
      cSet.add(l, ICoord(195, vp), Purpose.LABEL);
      new MoreLess(cSet, 1, ICoord(285, vp), true);

      vp += 20;
      l = new Label("Fade Position");
      l.setTooltipText("Adjust height - hold down <Ctrl> for faster action");
      cSet.add(l, ICoord(195, vp), Purpose.LABEL);
      new MoreLess(cSet, 2, ICoord(285, vp), true);

      new InchTool(cSet, 0, ICoord(0, vp-7), true);

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
      cbb.setActive(0);
      cSet.add(cbb, ICoord(195, vp), Purpose.PATTERN);

      vp += 20;
      TextOrient to = new TextOrient(cSet, 0, ICoord(0, vp), true);
      l = new Label("Angle");
      cSet.add(l, ICoord(60, vp+15), Purpose.LABEL);
      new MoreLess(cSet, 3, ICoord(120, vp+15),false);

      vp += 43;
      CheckButton cb = new CheckButton("Reverse fade");
      cSet.add(cb, ICoord(0, vp), Purpose.FADELEFT);
      cb = new CheckButton("Show Guidelines");
      cSet.add(cb, ICoord(120, vp), Purpose.SHOWMARKERS);

      cSet.cy = vp+50;
   }

   override void afterDeserialize()
   {
      cSet.setComboIndex(Purpose.PATTERN, gType);
      setOrientation(orient);
      setupStops();
   }

   override void preResize(int oldW, int oldH)
   {
      hOff = width/4;
      vOff = height/4;
      fw = width/3;
      fp = height/3;
   }

   override bool specificNotify(Widget w, Purpose wid)
   {

      switch (wid)
      {
      case Purpose.FADELEFT:
         revfade = !revfade;
         dirty = true;
         break;
      case Purpose.SHOWMARKERS:
         showGuides = !showGuides;
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

   void setOrientation(int o)
   {
      void figureSE(double a)
      {
         double r = 0.5*sqrt(1.0*width*width+1.0*height*height);
         start.x = lpX+width/2-r*cos(a);
         start.y = lpY+height/2+r*sin(a);
         end.x = lpX+width/2+r*cos(a);
         end.y = lpY+height/2-r*sin(a);
         cp1.x = start.x+(end.x-start.x)*fp;
         cp1.y = start.y+(end.y-start.y)*fp;
         cp2.x = start.x+(end.x-start.x)*(fp+fw);
         cp2.y = start.y+(end.y-start.y)*(fp+fw);
      }

      switch (o)
      {
         case 0:
            // left to right
            start.x = lpX;
            start.y = lpY+height/2;
            end.x = lpX+width;
            end.y = lpY+height/2;
            cp1.x = lpX+fp*width;
            cp1.y = lpY+0.5*height;
            cp2.x = lpX+(fp+fw)*width;
            cp2.y = lpY+0.5*height;
            break;
         case 1:
            // bottom to top
            start.x = lpX+width/2;
            start.y = lpY+height;
            end.x = start.x;
            end.y = lpY;
            cp1.x = lpX+0.5*width;
            cp1.y = lpY+height-fp*height;
            cp2.x = lpX+0.5*width;
            cp2.y = lpY+height-(fp+fw)*height;
            break;
         case 2:
            // right to left
            start.x = lpX+width;
            start.y = lpY+height/2;
            end.x = lpX;
            end.y = lpY+height/2;
            cp1.x = lpX+width-fp*width;
            cp1.y = lpY+0.5*height;
            cp2.x = lpX+width-(fp+fw)*width;
            cp2.y = lpY+0.5*height;
            break;
         case 3:
            // top to bottom
            start.x = lpX+width/2;
            start.y = lpY;
            end.x = start.x;
            end.y = lpY+height;
            cp1.x = lpX+0.5*width;
            cp1.y = lpY+fp*height;
            cp2.x = lpX+0.5*width;
            cp2.y = lpY+(fp+fw)*height;
            break;
         default:
            figureSE(angle);
            cSet.enable(Purpose.MOL, 3);
            aw.dirty = true;
            reDraw();
            return;
      }
      cSet.disable(Purpose.MOL, 3);
   }

   override void onCSTextParam(Purpose p, string sv, int iv)
   {
      if (p == Purpose.TORIENT)
      {
         lastOp = push!int(this, orient, OP_ORIENT);
         orient = iv;
         setOrientation(iv);
         dirty = true;
         aw.dirty = true;
         reDraw();
      }
   }

   override void onCSMoreLess(int instance, bool more, bool coarse)
   {
      focusLayout();
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
         double delta = coarse? 0.05: 0.01;
         lastOp = pushC!double(this, fw, OP_HSIZE);
         if (more)
         {
            if (fw+delta > 1)
               fw = 1;
            else
               fw += delta;
         }
         else
         {
            if (fw-delta < 0.05)
               fw = 0.05;
            else
               fw -= delta;
         }
         dirty = true;
      }
      else if (instance == 2)
      {
         double delta = coarse? 0.05: 0.01;
         lastOp = pushC!double(this, fp, OP_VSIZE);
         if (more)
         {
            if (fp+delta > 1-fw)
               fp = 1-fw;
            else
               fp += delta;
         }
         else
         {
            if (fp-delta < 0)
               fp = 0;
            else
               fp -= delta;
         }
         dirty = true;
      }
      else if (instance == 3)
      {
         double theta = coarse? 5*rads: 1*rads;
         lastOp = pushC!double(this, angle, OP_DV0);
         if (!more) theta = -theta;
         angle -= theta;
         setOrientation(4);
         dirty = true;
      }
      aw.dirty = true;
      reDraw();
   }

   override bool specificUndo(CheckPoint cp)
   {
      if (cp.type == 0)
         return false;
      switch (cp.type)
      {
      case OP_OPACITY:
         maxOpacity = cp.dVal;
         ov.setText(to!string(maxOpacity));
         break;
      case OP_ORIENT:
         orient = cp.iVal;
         setOrientation(orient);
         break;
      case OP_HSIZE:
         fw = cp.dVal;
         setOrientation(orient);
         break;
      case OP_VSIZE:
         fp = cp.dVal;
         setOrientation(orient);
         break;
      case OP_DV0:
         angle = cp.dVal;
         setOrientation(4);
         break;
      default:
         return false;
      }
      lastOp = OP_UNDEF;
      return true;
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
         pat.addColorStopRgba (0, r, g, b, 0);
         if (isNaN(opStops[0]))
         {
            pat.addColorStopRgba (fp, r, g, b, 0);
            pat.addColorStopRgba ((fp+fw), r, g, b, 1);
         }
         else
         {
            pat.addColorStopRgba (fp, r, g, b, 0);
            offset = fp;
            for (int i = nStops-1; i >= 0; i--)
            {
               pat.addColorStopRgba (offset, r, g, b, opStops[i]*maxOpacity);
               offset += 0.02*fw;
            }
            pat.addColorStopRgba (fp+fw, r, g, b, 1);
         }
         pat.addColorStopRgba (1, r, g, b, 1);
      }
      else
      {
         pat.addColorStopRgba (0, r, g, b, 1);
         if (isNaN(opStops[0]))
         {
            pat.addColorStopRgba (fp, r, g, b, 1);
            pat.addColorStopRgba ((fp+fw), r, g, b, 0);
         }
         else
         {
            pat.addColorStopRgba (fp, r, g, b, 1);
            offset = fp;
            for (int i = 0; i < nStops; i++)
            {
               pat.addColorStopRgba (offset, r, g, b, opStops[i]*maxOpacity);
               offset += 0.02*fw;
            }
            pat.addColorStopRgba (fp+fw, r, g, b, 0);
         }
         pat.addColorStopRgba (1, r, g, b, 0);
      }
   }

   void createPattern()
   {
         pat = Pattern.createLinear(start.x, start.y, end.x, end.y);
   }

   void renderGuides(Context c)
   {
      c.setSourceRgb(0.8,0.8,0.8);
      c.setLineWidth(1);
      c.moveTo(start.x, start.y);
      c.lineTo(end.x, end.y);
      c.stroke();
      c.moveTo(cp1.x-3, cp1.y+3);
      c.lineTo(cp1.x, cp1.y-3);
      c.lineTo(cp1.x+3, cp1.y+3);
      c.closePath();
      c.setSourceRgb(0,0,0);
      c.fill();
      c.moveTo(cp2.x-3, cp2.y+3);
      c.lineTo(cp2.x, cp2.y-3);
      c.lineTo(cp2.x+3, cp2.y+3);
      c.closePath();
      c.setSourceRgb(0,0,1);
      c.fill();
   }

   override void render(Context c)
   {
      if (dirty)
      {
         setOrientation(orient);
         setupStops();
         dirty = false;
      }
      createPattern();
      addStops(baseColor.red, baseColor.green, baseColor.blue);

      c.setSource(pat);
      c.moveTo(lpX, lpY);
      c.lineTo(lpX, lpY+height);
      c.lineTo(lpX+width, lpY+height);
      c.lineTo(lpX+width, lpY);
      c.closePath();
      c.fill();

      if (showGuides)
         renderGuides(c);
      if (!isMoved) cSet.setDisplay(0, reportPosition());
   }
}
