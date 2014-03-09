
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module mesh;

import mainwin;
import constants;
import acomp;
import common;
import types;
import controlset;
import lineset;

import std.math;
import std.stdio;
import std.conv;
import std.random;

import gtk.DrawingArea;
import gtk.Widget;
import gtk.Label;
import gtk.Button;
import gtk.SpinButton;
import gtk.CheckButton;
import gtk.RadioButton;
import gtk.ToggleButton;
import gtk.Layout;
import gtk.Frame;
import gtk.Range;
import gtk.ComboBoxText;
import gdk.RGBA;
import cairo.Context;
import gtkc.cairotypes;
import cairo.Matrix;
import cairo.MeshPattern;
import cairo.Version;
import cairo.Surface;

class Mesh : ACBase
{
   static uint[4][] preDefined;
   static int nextOid = 0;
   MeshPattern mesh;
   Coord center;
   ComboBoxText cicb;
   PartColor[4] pca;
   double diagonal;
   Coord p0, p1, p2, p3;
   int pattern, activeCP;
   Mt19937 gen;
   uint tempSeed, instanceSeed = 42;
   bool printRandom;

   static this()
   {
      preDefined ~= [ 0xfcf3ac, 0xcfae44, 0xfcf3ac, 0xcfae44 ];
      preDefined ~= [ 0xfcf09f, 0xf60b11, 0xfcf09f, 0xba1829 ];
      preDefined ~= [ 0x7cf3f2, 0x1c8ee2, 0x7cf3f2, 0x1c8ee2 ];
      preDefined ~= [ 0xf61613, 0x631d1b, 0x631d1b, 0xf61613 ];
      preDefined ~= [ 0,0,0,0 ];
      preDefined ~= [ 0,0,0,0 ];
      preDefined ~= [ 0xfcf3ac, 0xcfae44, 0xfcf3ac, 0xcfae44 ];
   }

   static PartColor uint2PartColor(uint u)
   {
      double r, g, b;
      uint t = u & 0xff;
      b = t/255.0;
      u >>= 8;
      t = u &0xff;
      g = t/255.0;
      u >>= 8;
      t = u &0xff;
      r = t/255.0;
      return PartColor(r,g,b,1);
   }

   static PartColor[4] predefPC(int n)
   {
      PartColor[4] pca;
      uint[] uic = preDefined[n];
      foreach (int i, uint u; uic)
         pca[i] = uint2PartColor(u);
      return pca;
   }

   override void syncControls()
   {
      cSet.toggling(false);
      if (printRandom)
         cSet.setToggle(Purpose.PRINTRANDOM, true);
      cSet.toggling(true);
      cSet.setComboIndex(Purpose.PATTERN, pattern);
      cSet.setHostName(name);
   }

   this(Mesh other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      pca = other.pca.dup;
      instanceSeed = other.instanceSeed;
      pattern = other.pattern;
      printRandom = other.printRandom;
      xform = other.xform;
      tf = other.tf;
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      mixin(initString!Mesh());
      super(w, parent, sname, AC_MESH, ACGroups.EFFECTS, ahdg);

      center = Coord(0.5*width, 0.5*height);
      tm = new Matrix(&tmData);
      pca = predefPC(0);
      diagonal = 1.1*sqrt(cast(double)(width*width+height*height));
      tempSeed = unpredictableSeed();

      p0 = Coord(0, center.y+1000);
      p1 = Coord(center.x-1000, 0);
      p2 = Coord(0, center.y-1000);
      p3 = Coord(center.x+1000, 0);

      setupControls(3);
      positionControls(true);
   }

   override void extendControls()
   {
      int vp = cSet.cy;

      cicb = new ComboBoxText(false);
      cicb.appendText("Corner Colors");
      cicb.appendText("Top");
      cicb.appendText("Right");
      cicb.appendText("Bottom");
      cicb.appendText("Left");
      cicb.setActive(0);
      cicb.setSizeRequest(100, -1);
      cSet.add(cicb, ICoord(200, vp), Purpose.DCOLORS);

      new InchTool(cSet, 0, ICoord(0, vp+5), true);

      vp += 40;
      ComboBoxText cbb = new ComboBoxText(false);
      cbb.appendText("Basketwork");
      cbb.appendText("Chequers");
      cbb.appendText("Diamonds");
      cbb.appendText("Shaded Spheres");
      cbb.appendText("Random");
      cbb.appendText("Corrugated");
      cbb.appendText("Dunes");
      cbb.setActive(0);
      cbb.setSizeRequest(100, -1);
      cSet.add(cbb, ICoord(0, vp), Purpose.PATTERN);

      cbb = new ComboBoxText(false);
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
      cSet.add(cbb, ICoord(200, vp), Purpose.XFORMCB);
      new MoreLess(cSet, 0, ICoord(300, vp+5), true);

      vp += 35;
      Button b=new Button("Refresh Random");
      cSet.add(b, ICoord(200, vp), Purpose.REDRAW);
      CheckButton cb=new CheckButton("Print Random");
      cSet.add(cb, ICoord(200, vp+25), Purpose.PRINTRANDOM);

      vp += 5;
      new Compass(cSet, 0, ICoord(0, vp));
      RadioButton rbg = new RadioButton("P0");
      rbg.setActive(1);
      cSet.add(rbg, ICoord(70, vp+5), Purpose.CP1);
      RadioButton rb = new RadioButton(rbg, "P1");
      cSet.add(rb, ICoord(70, vp+25), Purpose.CP2);
      rb = new RadioButton(rbg, "P2");
      cSet.add(rb, ICoord(110, vp+5), Purpose.ACP1);
      rb = new RadioButton(rbg, "P3");
      cSet.add(rb, ICoord(110, vp+25), Purpose.ACP2);

      cSet.cy = vp+60;


   }

   override bool notifyHandler(Widget w, Purpose p)
   {
      focusLayout();
      switch (p)
      {
      case Purpose.CP1:
      case Purpose.CP2:
      case Purpose.ACP1:
      case Purpose.ACP2:
         activeCP = p-Purpose.CP1;
         if (p > Purpose.CP2)
            activeCP--;
         Coord[] t = [p0, p1, p2, p3];
         lastOp = push!(Coord[])(this, t, OP_PARAMS);
         nop = true;
         return true;
      case Purpose.PATTERN:
         pattern = (cast(ComboBoxText) w).getActive();
         pca = predefPC(pattern);
         break;
      case Purpose.DCOLORS:
         int index = (cast(ComboBoxText) w).getActive();
         if (index > 0)
         {
            index--;
            RGBA current = new RGBA(pca[index].r, pca[index].g, pca[index].b, 1);
            RGBA rgba = getDColor(current);
            if (rgba is null)
            {
               cicb.setActive(0);
               nop = true;
               return true;
            }
            lastOp = push!PartColor(this, pca[index], OP_MC0+index);
            pca[index] = PartColor(rgba.red, rgba.green, rgba.blue, 1);
            reDraw();
            cicb.setActive(0);
         }
         else
         {
            nop = true;
            return true;
         }
         break;
      case Purpose.REDRAW:
         instanceSeed++;
         break;
      case Purpose.PRINTRANDOM:
         printRandom = !printRandom;
         break;
      case Purpose.XFORMCB:
         xform = (cast(ComboBoxText) w).getActive();
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
      case OP_MC0:
      case OP_MC1:
      case OP_MC2:
      case OP_MC3:
         pca[cp.type-OP_MC0] = cp.partColor;
         lastOp = OP_UNDEF;
         break;
      case OP_PARAMS:
         Coord[] t = cp.path;
         p0 = t[0], p1 = t[1], p2= t[2], p3 = t[3];
         break;
      default:
         return false;
      }
      return true;
   }

   override void preResize(int oldW, int oldH)
   {
      double hr = cast(double) width/oldW;
      double vr = cast(double) height/oldH;
      hOff *= hr;
      vOff *= vr;
   }

   override void onCSMoreLess(int instance, bool more, bool coarse)
   {
      focusLayout();
      modifyTransform(xform, more, coarse);
      aw.dirty = true;
      reDraw();
   }

   static pure void moveCoord(ref Coord p, double distance, double angle)
   {
      p.x += cos(angle)*distance;
      p.y -= sin(angle)*distance;
   }

   override void onCSCompass(int instance, double angle, bool coarse)
   {
      double d = coarse? 200: 40;
      Coord[] t = [p0, p1, p2, p3];
      lastOp = push!(Coord[])(this, t, OP_PARAMS);
      Coord dummy = Coord(0,0);
      moveCoord(dummy, d, angle);
      switch (activeCP)
      {
         case 0:
            p0.x += dummy.x;
            p0.y += dummy.y;
            break;
         case 1:
            p1.x += dummy.x;
            p1.y += dummy.y;
            break;
         case 2:
            p2.x += dummy.x;
            p2.y += dummy.y;
            break;
         case 3:
            p3.x += dummy.x;
            p3.y += dummy.y;
            break;
         default:
            break;
      }
      reDraw();
   }

   void setCC(MeshPattern p, bool random = false)
   {
      if (random)
      {
         uint n;
         for (int i = 0; i < 4; i++)
         {
            n = gen.front;
            gen.popFront();
            PartColor pc = uint2PartColor(n);
            p.setCornerColorRgba(i, pc.r, pc.g, pc.b, 1);
         }
      }
      else
      {
         for (int i = 0; i < 4; i++)
            p.setCornerColorRgba(i, pca[i].r, pca[i].g, pca[i].b, pca[i].a);
      }
   }

   void testbed()
   {
      double x = 80, y = 80, r = 50;
      double m = 0.55191502449;
      MeshPattern mesh = new MeshPattern();
      mesh.beginPatch();
      mesh.moveTo(x, y-r);
      mesh.curveTo(x+m*r, y-r, x+r, y-m*r, x+r, y);
      mesh.curveTo(x+r, y+m*r, x+m*r, y+r, x, y+r);
      mesh.curveTo(x-m*r, y+r, x-r, y+m*r, x-r, y);
      mesh.curveTo(x-r, y-m*r, x-m*r, y-r, x, y-r);
/*
      mesh.setControlPoint(0,x+w/2,y+h/2);
      mesh.curveTo(x-w, y-h, x+w+w, y-h, x+w, y);
      mesh.setControlPoint(1,x+w-w/2,y+h/2);
      mesh.curveTo(x+w+w, y-h, x+w+w, y+h+h, x+w, y+h);
      mesh.setControlPoint(2,x+w-w/2,y+h-h/2);
      mesh.curveTo(x+w+w, y+h+h, x-w, y+h+h, x, y+h);
      mesh.setControlPoint(3,x+w/2,y+h-h/2);
      mesh.curveTo(x-w, y+h+h, x-w, y-h, x,y);
*/
      setCC(mesh);
      mesh.endPatch();
   }

   void spheres(double r)
   {
      double x = center.x-diagonal/2+r+2, y = center.y-diagonal/2+r+2;
      double m = 0.55191502449;
      int lim = to!int(diagonal/(2*r+4));

      mesh = new MeshPattern();
      for (int j = 0; j < lim; j++)
      {
         for (int i = 0; i < lim; i++)
         {
            mesh.beginPatch();
            mesh.moveTo(x, y-r);
            mesh.curveTo(x+m*r, y-r, x+r, y-m*r, x+r, y);
            mesh.curveTo(x+r, y+m*r, x+m*r, y+r, x, y+r);
            mesh.curveTo(x-m*r, y+r, x-r, y+m*r, x-r, y);
            mesh.curveTo(x-r, y-m*r, x-m*r, y-r, x, y-r);
            setCC(mesh);
            mesh.endPatch();
            x += 2*r+4;
         }
         x = center.x-diagonal/2+r+2;
         y += 2*r+4;

      }
   }

   void diamonds(double w, double h)
   {
      double x = center.x-diagonal/2, y = center.y-diagonal/2;
      int hlim = to!int(diagonal/w)+1;
      int vlim = to!int(diagonal/h)+1;

      mesh = new MeshPattern();
      for (int j = 0; j < vlim; j++)
      {
         for (int i = 0; i < hlim; i++)
         {
            mesh.beginPatch();
            mesh.moveTo(x+w/2,y);
            mesh.lineTo(x+w, y+h/2);
            mesh.lineTo(x+w/2, y+h);
            mesh.lineTo(x,y+h/2);
            mesh.lineTo(x+w/2,y);
            setCC(mesh);
            mesh.endPatch();
            x += w;
         }
         x = center.x-diagonal/2;
         y += h;
      }
   }

   void chequers(double w, double h)
   {
      double x = center.x-diagonal/2, y = center.y-diagonal/2;
      int hlim = to!int(diagonal/w)/2;
      int vlim = to!int(diagonal/h);

      mesh = new MeshPattern();
      for (int j = 0; j < vlim; j++)
      {
         for (int i = 0; i < hlim; i++)
         {
            mesh.beginPatch();
            mesh.moveTo(x,y);
            mesh.lineTo(x+w,y);
            mesh.lineTo(x+w,y+h);
            mesh.lineTo(x,y+h);
            mesh.lineTo(x,y+h);
            setCC(mesh);
            mesh.endPatch();
            x += 2*w;
         }
         x = center.x-diagonal/2+((j & 1)? 0: 10);
         y += h;
      }
   }

   void dunes()
   {
      mesh = new MeshPattern();
      mesh.beginPatch();
      mesh.moveTo(0,0);
      mesh.lineTo(width, 0);
      mesh.lineTo(width, height);
      mesh.lineTo(0, height);
      mesh.lineTo(0, 0);
      mesh.setControlPoint(0,p0.x, p0.y);
      mesh.setControlPoint(1, p1.x, p1.y);
      mesh.setControlPoint(2, p2.x, p2.y);
      mesh.setControlPoint(3, p3.x, p3.y);
      setCC(mesh);
      mesh.endPatch();
   }

   void corrugated()
   {
      double sz = (width > height)? width*2: height*2;
      Coord tl = Coord(-0.5*sz, -0.5*sz);
      Coord br = Coord(1.5*sz, 1.5*sz);
      Coord c0, c1, c2, cp12, c3;
      double pitch = sz/20;
      double xPos = tl.x;

      void movePoints(double d)
      {
         c0.x += d; c1.x += d;
         c2.x += d; c3.x += d;
         xPos += d;
      }

      c0 = Coord(tl.x, br.y);
      c1 = Coord(tl.x, tl.y);
      c2 = Coord(tl.x+pitch, tl.y);
      c3 = Coord(tl.x+pitch, br.y);
      mesh = new MeshPattern();
      for (int i = 0; xPos < br.x; i++)
      {
         mesh.beginPatch();
         mesh.moveTo(c0.x, c0.y);
         mesh.lineTo(c1.x, c1.y);
         mesh.lineTo(c2.x, c2.y);
         mesh.lineTo(c3.x, c3.y);
         mesh.lineTo(c0.x, c0.y);
         mesh.setCornerColorRgba(0, 0,0,0,1);
         mesh.setCornerColorRgba(1, 0,0,0,1);
         mesh.setCornerColorRgba(2, 1,1,1,1);
         mesh.setCornerColorRgba(3, 1,1,1,1);
         mesh.endPatch();
         mesh.beginPatch();
         movePoints(pitch);
         mesh.moveTo(c0.x, c0.y);
         mesh.lineTo(c1.x, c1.y);
         mesh.lineTo(c2.x, c2.y);
         mesh.lineTo(c3.x, c3.y);
         mesh.lineTo(c0.x, c0.y);
         mesh.setCornerColorRgba(0, 1,1,1,1);
         mesh.setCornerColorRgba(1, 1,1,1,1);
         mesh.setCornerColorRgba(2, 0,0,0,1);
         mesh.setCornerColorRgba(3, 0,0,0,1);
         mesh.endPatch();
         movePoints(pitch);
      }
   }


   void rectangles(double w, double h, bool random = false)
   {
      double x = center.x-diagonal/2, y = center.y-diagonal/2;
      int hlim = to!int(diagonal/w)+1;
      int vlim = to!int(diagonal/h)+1;

      mesh = new MeshPattern();
      for (int j = 0; j < vlim; j++)
      {
         for (int i = 0; i < hlim; i++)
         {
            mesh.beginPatch();
            mesh.moveTo(x,y);
            mesh.lineTo(x+w,y);
            mesh.lineTo(x+w,y+h);
            mesh.lineTo(x,y+h);
            mesh.lineTo(x,y);
            setCC(mesh, random);
            mesh.endPatch();
            x += w;
         }
         x = center.x-diagonal/2;
         y += h;
      }
   }

   override void render(Context c)
   {
      uint sv = instanceSeed;
      switch (pattern)
      {
         case 0:
            rectangles(20, 20);
            break;
         case 1:
            chequers(10,10);
            break;
         case 2:
            diamonds(10,20);
            break;
         case 3:
            spheres(20);
            break;
         case 4:
            if (printRandom && printFlag)
               sv = tempSeed++;
            gen.seed(sv);
            rectangles(20, 20, true);
            break;
         case 5:
            corrugated();
            break;
         case 6:
            dunes();
            break;
         default:
            return;
      }

      c.translate(hOff+center.x, vOff+center.y);
      if (compoundTransform())
         c.transform(tm);
      c.translate(-center.x, -center.y);

      c.setSource(mesh);
      c.paint();
   }
}
