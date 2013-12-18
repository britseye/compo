
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module heart;

import main;
import constants;
import acomp;
import common;
import types;
import controlset;
import lineset;

import std.stdio;
import std.conv;

import gtk.Widget;
import gtk.Label;
import gtk.Button;
import gtk.ComboBoxText;
import gtk.SpinButton;
import gtk.CheckButton;
import gdk.RGBA;
import cairo.Context;
import cairo.Matrix;

class Heart: LineSet
{
   static int nextOid = 0;
   static Coord[7] crd = [ Coord(0, 0.666), Coord(-1.2, -0.1), Coord(-0.5, -1.1), Coord(0, -0.333),
                           Coord(0.5, -1.1), Coord(1.2, -0.1), Coord(0, 0.666) ];
   double unit;
   bool fill, solid;
   int xform;
   Matrix tm;
   cairo_matrix_t tmd;

   void syncControls()
   {
      cSet.setLineParams(lineWidth);
      cSet.toggling(false);
      if (solid)
      {
         cSet.setToggle(Purpose.SOLID, true);
         cSet.disable(Purpose.FILL);
         cSet.disable(Purpose.FILLCOLOR);
      }
      else if (fill)
         cSet.setToggle(Purpose.FILL, true);
      cSet.setLabel(Purpose.LINEWIDTH, formatLT(lineWidth));
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(Heart other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      altColor = other.altColor.copy();
      lineWidth = other.lineWidth;
      unit = other.unit;
      tf = other.tf;
      fill = other.fill;
      solid = other.solid;
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Heart "~to!string(++nextOid);
      super(w, parent, s, AC_HEART);
      hOff = vOff = 0;
      lineWidth = 0.5;
      unit = width > height? height*0.75: width*0.75;
      xform = 0;
      tm = new Matrix(&tmd);

      setupControls();
      positionControls(true);
   }

   void extendControls()
   {
      int vp = cSet.cy;

      new InchTool(cSet, 0, ICoord(0, vp), true);

      ComboBoxText cbb = new ComboBoxText(false);
      cbb.setTooltipText("Select transformation to apply");
      cbb.setSizeRequest(100, -1);
      cbb.appendText("Scale");
      cbb.appendText("Rotate");
      cbb.appendText("Flip-H");
      cbb.appendText("Flip-V");
      cbb.setActive(0);
      cSet.add(cbb, ICoord(209, vp), Purpose.XFORMCB);
      new MoreLess(cSet, 0, ICoord(310, vp), true);

      vp += 40;

      CheckButton check = new CheckButton("Fill with color");
      cSet.add(check, ICoord(0, vp), Purpose.FILL);

      check = new CheckButton("Solid");
      cSet.add(check, ICoord(115, vp), Purpose.SOLID);

      Button b = new Button("Fill Color");
      cSet.add(b, ICoord(210, vp-5), Purpose.FILLCOLOR);

      cSet.cy = vp+30;
   }

   void onCSNotify(Widget w, Purpose wid)
   {
      switch (wid)
      {
      case Purpose.COLOR:
         lastOp = push!RGBA(this, baseColor, OP_COLOR);
         setColor(false);
         break;
      case Purpose.FILLCOLOR:
         lastOp = push!RGBA(this, altColor, OP_ALTCOLOR);
         setColor(true);
         break;
      case Purpose.FILL:
         fill = !fill;
         break;
      case Purpose.SOLID:
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
         return;
      }
      aw.dirty = true;
      reDraw();
   }

   void preResize(int oldW, int oldH)
   {
      double hr = cast(double) width/oldW;
      double vr = cast(double) height/oldH;
      unit = width>height? 0.75*height: 0.75*width;
      hOff *= hr;
      vOff *= vr;
   }

   override void onCSMoreLess(int instance, bool more, bool coarse)
   {
      dummy.grabFocus();
      int[] xft = [0,5,6,7];
      int tt = xft[xform];
      modifyTransform(tt, more, coarse);
      dirty = true;
      aw.dirty = true;
      reDraw();
   }

   void render(Context c)
   {
      c.save();
      c.setLineWidth(lineWidth);
      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);
      double unit = 0.6666*height;
      double xpos = 0.5*width;

      Coord[7] t;
      t[] = crd;
      for (int i = 0; i < 7; i++)
      {
         t[i].x *= unit;
         t[i].y *= unit;
      }
      if (tf.hScale != 1.0)
      {
         tm.initScale(tf.hScale, tf.vScale);
         for (int i = 0; i < 7; i++)
            tm.transformPoint(t[i].x, t[i].y);
      }
      if (tf.ra != 0)
      {
         tm.initRotate(tf.ra);
         for (int i = 0; i < 7; i++)
            tm.transformPoint(t[i].x, t[i].y);
      }
      if (tf.hFlip != 0)
      {
         tm.init(-1.0, 0.0, 0.0, 1.0, 0.0, 0.0);
         for (int i = 0; i < 7; i++)
            tm.transformPoint(t[i].x, t[i].y);
      }
      if (tf.vFlip != 0)
      {
         tm.init(1.0, 0.0, 0.0, -1.0, 0.0, 0.0);
         for (int i = 0; i < 7; i++)
            tm.transformPoint(t[i].x, t[i].y);
      }
      for (int i = 0; i < 7; i++)
      {
         t[i].x += 0.5*width;
         t[i].y += 0.5*height;
      }

      c.moveTo(hOff+t[0].x, vOff+t[0].y);
      c.curveTo(hOff+t[1].x, vOff+t[1].y,     hOff+t[2].x, vOff+t[2].y,     hOff+t[3].x, vOff+t[3].y);
      c.curveTo(hOff+t[4].x, vOff+t[4].y,    hOff+t[5].x, vOff+t[5].y,     hOff+t[6].x, vOff+t[6].y);
      c.closePath();
      if (solid)
      {
         c.setSourceRgba(baseColor.red, baseColor.green, baseColor.blue, 1.0);
         c.fill();
      }
      else if (fill)
      {
         c.setSourceRgba(altColor.red, altColor.green, altColor.blue, 1.0);
         c.fillPreserve();
      }
      if (!solid)
      {
         c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);
         c.stroke();
      }
      if (!isMoved) cSet.setDisplay(0, reportPosition());
   }
}


