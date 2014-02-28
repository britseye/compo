
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module brushdabs;

import mainwin;
import constants;
import acomp;
import common;
import types;
import controlset;

import std.stdio;
import std.math;
import std.conv;
import std.random;

import gtk.DrawingArea;
import gtk.Widget;
import gtk.Button;
import gtk.Layout;
import gtk.Frame;
import gdk.RGBA;
import gtk.ComboBoxText;
import gtk.ToggleButton;
import gtk.RadioButton;
import gtk.CheckButton;
import gtk.Label;
import cairo.Context;
import gtkc.cairotypes;
import cairo.Matrix;
import cairo.Surface;

struct Dab
{
   Coord start, cp10, cp20, end, cp11, cp21;
}

class BrushDabs : ACBase
{
   static int nextOid = 0;
   Coord center;
   PartColor[8] pca;
   Dab base;
   Dab[] dabs;
   size_t nDabs;
   ColorSource cSrc;
   uint colorSeed, shapeSeed, tempSeed;
   int shade;
   cairo_matrix_t ttData;
   Matrix tt;
   double w, tcp, bcp, angle;
   bool pointed, printRandom;

   override void syncControls()
   {
      cSet.toggling(false);
      if (printRandom)
         cSet.setToggle(Purpose.PRINTRANDOM, true);
      cSet.toggling(true);
      cSet.setComboIndex(Purpose.DCOLORS, shade);
      cSet.setHostName(name);
   }

   this(BrushDabs other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      colorSeed = other.colorSeed;
      shapeSeed = other.shapeSeed;
      cSrc.init(baseColor, colorSeed);
      shade = other.shade;
      cSrc.setShadeBand(shade);
      nDabs = other.nDabs;
      dabs = other.dabs.dup;
      pca = other.pca.dup;
      tf = other.tf;
      syncControls();
   }

   this(AppWindow mw, ACBase parent, bool asCopy = false)
   {
      string s = "Brush Dabs "~to!string(++nextOid);
      super(mw, parent, s, AC_BRUSHDABS);
      group = ACGroups.EFFECTS;
      baseColor = new RGBA(0,0,1,1);
      center.x= 0.5*width;
      center.y = 0.5*height;
      w = 8;
      tcp = 1;
      bcp = 0.1666;
      nDabs = 0x1000/4;
      angle = PI/4;
      constructBase();
      tm = new Matrix(&tmData);
      tt = new Matrix(&ttData);
      pca = [PartColor(0,0.6,0,1), PartColor(0,0.64,0,1), PartColor(0,0.68,0,1), PartColor(0,0.72,0,1),
             PartColor(0,0.76,0,1), PartColor(0,0.8,0,1), PartColor(0.8,1,0,1), PartColor(0.6,0.6,0,1)];
      shade = 9;
      colorSeed = shapeSeed = 22;
      if (!asCopy)
      {
         cSrc.init(baseColor, 42);
         cSrc.setShadeBand(shade);
      }
      if (!asCopy)
         generate();

      setupControls();
      positionControls(true);
   }

   override void extendControls()
   {
      int vp = cSet.cy;

      Button b = new Button("Color");
      cSet.add(b, ICoord(0, vp), Purpose.XCOLOR);
      b = new Button("Refresh Dabs");
      cSet.add(b, ICoord(70, vp), Purpose.REDRAW);
      b = new Button("Refresh Colors");
      cSet.add(b, ICoord(0, vp+33), Purpose.REFRESH);

      Label l = new Label("Dab Count");
      cSet.add(l, ICoord(190, vp), Purpose.LABEL);
      new MoreLess(cSet, 0, ICoord(300, vp), true);
      l = new Label("Brush Size");
      cSet.add(l, ICoord(190, vp+20), Purpose.LABEL);
      new MoreLess(cSet, 1, ICoord(300, vp+20), true);
      l = new Label("Brush Shape");
      cSet.add(l, ICoord(190, vp+40), Purpose.LABEL);
      new MoreLess(cSet, 2, ICoord(300, vp+40), true);
      l = new Label("Brushing Angle");
      cSet.add(l, ICoord(190, vp+60), Purpose.LABEL);
      new MoreLess(cSet, 3, ICoord(300, vp+60), true);

      CheckButton cb = new CheckButton("Pointed Brush");
      cSet.add(cb, ICoord(188, vp+80), Purpose.GLWHICH);
      cb = new CheckButton("Print Random");
      cSet.add(cb, ICoord(188, vp+100), Purpose.PRINTRANDOM);

      vp += 45;
      ComboBoxText cbb = new ComboBoxText(false);
      cbb.appendText("Base Color Exact");
      cbb.appendText("Base Color All");
      cbb.appendText("Base Color Light");
      cbb.appendText("Base Color Medium");
      cbb.appendText("Base Color Dark");
      cbb.appendText("Light Colors");
      cbb.appendText("Medium Colors");
      cbb.appendText("Dark Colors");
      cbb.appendText("Random Colors");
      cbb.appendText("Use Palette");
      cbb.setActive(9);
      cSet.add(cbb, ICoord(0, vp+40), Purpose.DCOLORS);

      vp += 85;
      Palette p = new Palette(cSet, ICoord(0, vp), true);
      p.csInstruction("colors", 0, "", 0, 0, pca.ptr);

      cSet.cy = vp+45;
   }

   override void afterDeserialize()
   {
      cSrc.init(baseColor, colorSeed);
      cSrc.setShadeBand(shade);
      constructBase();
      generate();
   }

   override bool specificNotify(Widget w, Purpose p)
   {
      focusLayout();
      switch (p)
      {
      case Purpose.REFRESH:
         lastOp = push!uint(this, colorSeed, OP_CSEED);
         colorSeed += cSet.control? -1: 1;
         break;
      case Purpose.REDRAW:
         lastOp = push!uint(this, colorSeed, OP_SSEED);
         shapeSeed += cSet.control? -1: 1;
         generate();
         break;
      case Purpose.PRINTRANDOM:
         printRandom = !printRandom;
         break;
      case Purpose.GLWHICH:
         pointed = !pointed;
         constructBase();
         generate();
         break;
      case Purpose.XCOLOR:   // We need to augment the default handling associated with Purpose.COLOR
         lastOp = push!RGBA(this, baseColor, OP_XCOLOR);
         setColor(false);
         cSrc.setBase(baseColor);
         break;
      case Purpose.DCOLORS:
         int n = (cast(ComboBoxText) w).getActive();
         if (shade == n)
            return false;
         lastOp = push!int(this, shade, OP_IV0);
         shade = n;
         cSrc.setShadeBand(shade);
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
      case OP_CSEED:
         colorSeed = cp.uiVal;
         cSrc.setSeed(colorSeed);
         break;
      case OP_SSEED:
         lastOp = push!uint(this, colorSeed, OP_SSEED);
         shapeSeed = cp.uiVal;
         generate();
         break;
      case OP_XCOLOR:
         baseColor = cp.color;
         cSrc.setBase(baseColor);
         break;
      case OP_IV0:
         shade = cp.iVal;
         cSrc.setShadeBand(shade);
         cSet.setComboIndex(Purpose.DCOLORS, shade);
         break;
      case OP_IV1:
         nDabs = cp.iVal;
         generate();
         break;
      case OP_DV0:
         w = cp.dVal;
         constructBase();
         generate();
         break;
      case OP_DV1:
         tcp = cp.dVal;
         constructBase();
         generate();
         break;
      case OP_DV2:
         angle = cp.dVal;
         constructBase();
         generate();
         break;
      case OP_PCA:
         pca = cp.pca;
         cSet.setPalette(pca.ptr);
         break;
      default:
         break;
      }
      lastOp = OP_UNDEF;
      return true;
   }

   override void preResize(int oldW, int oldH)
   {
      double hr = cast(double) width/oldW;
      double vr = cast(double) height/oldH;
      tm.initScale(hr, vr);
      hOff *= hr;
      vOff *= vr;
   }

   override void onCSPalette(PartColor[] npa)
   {
      focusLayout();
      lastOp = push!(PartColor[])(this, pca, OP_PCA);
      pca[] = npa[];
      reDraw();
   }

   override void onCSMoreLess(int instance, bool more, bool much)
   {
      focusLayout();
      if (instance == 0)
      {
         if (more)
         {
            if (nDabs < 0x2000)
            {
               lastOp = pushC!int(this, nDabs, OP_IV1);
               nDabs *= 2;
            }
            else
               return;
         }
         else
         {
            if (nDabs > 1)
            {
               lastOp = pushC!int(this, nDabs, OP_IV1);
               nDabs /=2;
            }
            else
               return;
         }
      }
      else if (instance == 1)
      {
         if (more)
         {
            if (w < 100)
            {
               lastOp = pushC!double(this, w, OP_DV0);
               w++;
            }
            else
               return;
         }
         else
         {
            if (w > 3)
            {
               lastOp = pushC!double(this, w, OP_DV0);
               w--;
            }
            else
               return;
         }
         constructBase();
      }
      else if (instance == 2)
      {
         if (more)
         {
            if (tcp < 4)
            {
               lastOp = pushC!double(this, tcp, OP_DV1);
               tcp += 0.05;
            }
            else
               return;
         }
         else
         {
            if (tcp > 0.1)
            {
               lastOp = pushC!double(this, tcp, OP_DV1);
               tcp -= 0.05;
            }
            else
               return;
         }
         constructBase();
      }
      else if (instance == 3)
      {
         lastOp = pushC!double(this, angle, OP_DV2);
         if (more)
         {
            if (angle < 2*PI)
               angle += PI/8;
            else
               angle = PI/8;
         }
         else
         {
            if (angle > 0)
               angle -= PI/8;
            else
               angle = 7*PI/8;
         }
         constructBase();
      }
      generate();
      aw.dirty = true;
      reDraw();
   }

   Dab transformBase(Coord pos, double angle)
   {
      Dab d = base;
      tm.initTranslate(pos.x, pos.y);
      tt.initRotate(angle);
      tt.multiply(tt, tm);
      tt.transformPoint(d.start.x, d.start.y);
      tt.transformPoint(d.cp10.x, d.cp10.y);
      tt.transformPoint(d.cp20.x, d.cp20.y);
      tt.transformPoint(d.end.x, d.end.y);
      tt.transformPoint(d.cp11.x, d.cp11.y);
      tt.transformPoint(d.cp21.x, d.cp21.y);
      return d;
   }

   void generate(bool forprint = false)
   {
      uint sv;
      if (forprint)
         sv = tempSeed++;
      else
         sv = shapeSeed;
      dabs.length = nDabs;
      Mt19937 gen;
      gen.seed(sv);
      for (int i = 0; i < nDabs; i++)
      {
         uint n = gen.front;
         gen.popFront();
         int wn = n & 0xf;
         n >>= 4;
         double wobble = (wn > 7)? rads*(wn-7): -rads*wn;
         uint ix = n & 0b11111111111111;
         n >>= 14;
         uint iy = n & 0b11111111111111;
         double xf = to!double(ix)/to!double(0b11111111111111);
         double yf = to!double(iy)/to!double(0b11111111111111);
         double x = xf*width;
         double y = yf*height;
         double a = 1.5*wobble+angle;
         dabs[i] = transformBase(Coord(x, y), a);
      }
      dirty = true;
   }

   void constructBase()
   {
      if (pointed)
      {
         base.start = Coord(0, w);
         base.cp10 = Coord(-tcp*w, w);
         base.cp20 = Coord(-bcp*w, -w/2);
         base.end = Coord(0, -w);
         base.cp11 = Coord(bcp*w, -w/2);
         base.cp21 = Coord(tcp*w, w);
      }
      else
      {
         base.start = Coord(-0.5*w, 0);
         base.cp10 = Coord(-w, -w*tcp);
         base.cp20 = Coord(w, -w*tcp);
         base.end = Coord(0.5*w, 0);
         base.cp11 = Coord(0.25*w, w*bcp);
         base.cp21 = Coord(-0.25*w, w*bcp);
      }
      dirty = true;
   }

   override void render(Context c)
   {
      c.translate(hOff, vOff);
      uint sv = colorSeed;
      if (printRandom && printFlag)
      {
         generate(true);
         sv = tempSeed;
      }
      cSrc.setSeed(sv);
      foreach (int i, Dab d; dabs)
      {
         c.moveTo(d.start.x, d.start.y);
         c.curveTo(d.cp10.x, d.cp10.y, d.cp20.x, d.cp20.y, d.end.x, d.end.y);
         c.curveTo(d.cp11.x, d.cp11.y, d.cp21.x, d.cp21.y, d.start.x, d.start.y);
         c.closePath();
         PartColor pc;
         if (shade == 9)
            pc = pca[i%8];
         else
            pc = cSrc.getColor();
         c.setSourceRgb(pc.r,pc.g,pc.b);
         c.fill();
      }
   }
}
