
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module minimal;

import mainwin;
import acomp;
import common;
import types;
import controlset;

import std.stdio;
import std.conv;

import gtk.DrawingArea;
import gtk.Widget;
import gtk.ComboBoxText;
import gdk.RGBA;
import gtk.Button;
import cairo.Context;
import cairo.Matrix;

class Minimal: ACBase
{
   static int nextOid = 0;
   double size;
   Coord center;

   override void syncControls()
   {
   }

   this(Minimal other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();

      syncControls();
   }

   this(AppWindow aw, ACBase parent)
   {
      mixin(initString!Minimal());
      super(aw, parent, sname, AC_MINIMAL, ACGroups.SHAPES, ahdg);

      size = 20;
      tm = new Matrix(&tmData);
      center = Coord(60, 10);

      setupControls();
      positionControls(true);
   }

   override void extendControls()
   {
      int vp = cSet.cy;
      Button b = new Button("Size");
      cSet.add(b, ICoord(0, vp), Purpose.COLOR);

      vp += 25;
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
      new MoreLess(cSet, 1, ICoord(295, vp), true);

      cSet.cy = vp+35;
   }

   override bool notifyHandler(Widget w, Purpose p) { return false; }
   override bool undoHandler(CheckPoint cp) { return false; }

   override void onCSMoreLess(int instance, bool more, bool quickly)
   {
      focusLayout();
      modifyTransform(xform, more, quickly);
      aw.dirty = true;
      reDraw();
   }

   override void render(Context c)
   {
      c.translate(hOff+center.x, vOff+center.y);
      if (compoundTransform())
         c.transform(tm);
      c.translate(-center.x, -center.y);

      c.setLineWidth(size/20);
      c.moveTo(10, 10);
      c.lineTo(100, 10);
      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);
      c.stroke();
   }
}
