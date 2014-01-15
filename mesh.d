
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module mesh;

import main;
import constants;
import acomp;
import common;
import types;
import controlset;
import lineset;

import std.math;
import std.stdio;
import std.conv;

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

class Mesh : ACBase
{
   static uint[4][] preDefined;
   static int nextOid = 0;
   ComboBoxText cicb;
   PartColor[4] pca;
   int pattern;

   static this()
   {
      preDefined ~= [ 0xfcf3ac, 0xcfae44, 0xfcf3ac, 0xcfae44 ];
      preDefined ~= [ 0xfcf09f, 0xf60b11, 0xfcf09f, 0xba1829 ];
      preDefined ~= [ 0x7cf3f2, 0x1c8ee2, 0x7cf3f2, 0x1c8ee2 ];
      preDefined ~= [ 0xf61613, 0x631d1b, 0x631d1b, 0xf61613 ];
   }

   static PartColor[4] predefPC(int n)
   {
      PartColor[4] pca;
      uint[4] uic = preDefined[n];
      foreach (int i, uint u; uic)
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
         pca[i] = PartColor(r,g,b,1);
      }
      return pca;
   }

   void syncControls()
   {
      cSet.toggling(false);
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(Mesh other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      /*
      altColor = other.altColor.copy();
      topLeft = other.topLeft;
      bottomRight = other.bottomRight;
      lineWidth = other.lineWidth;
      les = other.les;
      rounded = other.rounded;
      fill = other.fill;
      solid = other.solid;
      rr = other.rr;
      tf = other.tf;
      */
      xform = other.xform;
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Mesh "~to!string(++nextOid);
      super(w, parent, s, AC_MESH);
      hOff = vOff = 0;
      tm = new Matrix(&tmData);
      pca = predefPC(0);

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


      cSet.cy = vp+35;
   }

   override bool specificNotify(Widget w, Purpose wid)
   {
      focusLayout();
      switch (wid)
      {
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
               return false;
            }
            lastOp = push!PartColor(this, pca[index], OP_MC0+index);
            pca[index] = PartColor(rgba.red, rgba.green, rgba.blue, 1);
            cicb.setActive(0);
         }
         else
            return false;
         break;
      case Purpose.XFORMCB:
         xform = (cast(ComboBoxText) w).getActive();
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
      case OP_MC0:
      case OP_MC1:
      case OP_MC2:
      case OP_MC3:
         pca[cp.type-OP_MC0] = cp.partColor;
         lastOp = OP_UNDEF;
         break;
      case OP_SCALE:
      case OP_HSC:
      case OP_VSC:
      case OP_HSK:
      case OP_VSK:
      case OP_ROT:
      case OP_HFLIP:
      case OP_VFLIP:
         tf = cp.transform;
         lastOp = OP_UNDEF;
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
   void setCC(MeshPattern p)
   {
      for (int i = 0; i < 4; i++)
         p.setCornerColorRgba(i, pca[i].r, pca[i].g, pca[i].b, pca[i].a);
   }

   MeshPattern testbed()
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
      return mesh;
   }

   MeshPattern spheres(double r)
   {
      double x = r+2, y = r+2;
      double m = 0.55191502449;
      int hlim = to!int(width*1.5/(r+4));
      int vlim = to!int(height*1.5/(r+4));

      MeshPattern mesh = new MeshPattern();
      for (int j = 0; j < vlim; j++)
      {
         for (int i = 0; i < hlim; i++)
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
         x = r+2;
         y += 2*r+4;

      }
      return mesh;
   }

   MeshPattern diamonds(double w, double h)
   {
      double x = 0, y = 0;
      int hlim = to!int(width*1.5/w)+1;
      int vlim = to!int(height*1.5/h)+1;

      MeshPattern mesh = new MeshPattern();
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
         x = 0;
         y += h;
      }
      return mesh;
   }

   MeshPattern chequers(double w, double h)
   {
      double x = 0, y = 0;
      int hlim = to!int(width/w)+1;
      int vlim = to!int(height/h)+1;

      MeshPattern mesh = new MeshPattern();
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
         x = (j & 1)? 0: 10;
         y += h;
      }
      return mesh;
   }

   MeshPattern tester()
   {
      double x = 30, y = 50, r = 100;
      MeshPattern mesh = new MeshPattern();
      mesh.beginPatch();
      mesh.moveTo(x,y);
      //mesh.lineTo(x+r, y);
      //mesh.curveTo(x+25, y-25, x+100-25, y+25, x+r,y);
      //mesh.curveTo(x-25, y-25, x+100-25, y+25, x+r,y);
      mesh.curveTo(x, y-50, x+r, y-50, x+r,y);
      mesh.curveTo(x+r+50, y, x+r+50, y+r, x+r, y+r);
      //mesh.lineTo(x+r, y+r);
      mesh.lineTo(x, y+r);
      mesh.lineTo(x, y);
      mesh.setControlPoint(0,x,y-1000);
      mesh.setControlPoint(1,x+1000,y);
      mesh.setCornerColorRgba(0,0,0,0,1);
      mesh.setCornerColorRgba(1,1,1,0,1);
      for (int i = 2; i < 4; i++)
         mesh.setCornerColorRgba(i,0,0,0,1);
      mesh.endPatch();
      return mesh;
   }

   MeshPattern rectangles(double w, double h)
   {
      double x = 0, y = 0;
      int hlim = to!int(width*1.5/w)+1;
      int vlim = to!int(height*1.5/h)+1;

      MeshPattern mesh = new MeshPattern();
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
            setCC(mesh);
            mesh.endPatch();
            x += w;
         }
         x = 0;
         y += h;
      }
      return mesh;
   }

   override void render(Context c)
   {
      MeshPattern mesh;
      switch (pattern)
      {
         case 0:
            mesh = rectangles(20, 20);
            break;
         case 1:
            mesh = chequers(10,10);
            break;
         case 2:
            mesh = diamonds(10,20);
            break;
         case 3:
            mesh = spheres(20);
            break;
         default:
            return;
      }
      c.save();
      c.translate(hOff, vOff);
      if (compoundTransform())
         c.transform(tm);
      c.setSource(mesh);
      c.paint();
      c.restore();
      if (!isMoved) cSet.setDisplay(0, reportPosition());
   }
}
