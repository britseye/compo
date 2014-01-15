
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module box;

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
import gtk.CheckButton;
import gtk.RadioButton;
import gdk.RGBA;
import cairo.Context;
import cairo.Matrix;

class Box : LineSet
{
   static int nextOid = 0;
   bool solid, fill;

   void syncControls()
   {
      cSet.setLineParams(lineWidth);
      cSet.toggling(false);
      if (les)
         cSet.setToggle(Purpose.LESSHARP, true);
      else
         cSet.setToggle(Purpose.LESROUND, true);
      cSet.setLabel(Purpose.LINEWIDTH, formatLT(lineWidth));
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(Box other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      lineWidth = other.lineWidth;
      les = other.les;
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Box "~to!string(++nextOid);
      super(w, parent, s, AC_BOX);
      hOff = vOff = 0;
      lineWidth = 0.5;
      les = true;
      tm = new Matrix(&tmData);

      setupControls(3);
      positionControls(true);
   }

   override int getNextOid()
   {
      return ++nextOid;
   }

   void extendControls()
   {
      int vp = cSet.cy;

      new InchTool(cSet, 0, ICoord(0, vp+5), true);

      ComboBoxText cbb = new ComboBoxText(false);
      cbb.appendText("Scale");
      cbb.appendText("Stretch-H");
      cbb.appendText("Stretch-V");
      cbb.appendText("Rotate");
      cbb.setActive(0);
      cbb.setSizeRequest(100, -1);
      cSet.add(cbb, ICoord(172, vp-35), Purpose.XFORMCB);
      new MoreLess(cSet, 0, ICoord(288, vp-30), true);

      vp += 40;
      CheckButton check = new CheckButton("Fill with color");
      cSet.add(check, ICoord(0, vp), Purpose.FILL);

      check = new CheckButton("Solid");
      cSet.add(check, ICoord(115, vp), Purpose.SOLID);

      Button b = new Button("Fill Color");
      cSet.add(b, ICoord(247, vp-5), Purpose.FILLCOLOR);

      cSet.cy = vp+25;
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

   override void onCSMoreLess(int instance, bool more, bool coarse)
   {
      dummy.grabFocus();
      int[] xft = [0,1,2,5];
      int tt = xft[xform];
      modifyTransform(tt, more, coarse);
      dirty = true;
      aw.dirty = true;
      reDraw();
   }

   void render(Context c)
   {
      c.setLineWidth(lineWidth);
      c.translate(hOff+width/2, vOff+height/2);
      if (compoundTransform())
         c.transform(tm);
      c.translate(-lpX-(width/2), -lpY-(height/2));
      c.setLineJoin(les? CairoLineJoin.MITER: CairoLineJoin.ROUND);
      c.moveTo(lpX+0.2*width, lpY+0.2*height);
      c.lineTo(lpX+0.8*width, lpY+0.2*height);
      c.lineTo(lpX+0.8*width, lpY+0.8*height);
      c.lineTo(lpX+0.2*width, lpY+0.8*height);
      c.closePath();
      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);
      c.strokePreserve();
      if (solid)
      {
         c.fill();
      }
      else if (fill)
      {
         c.setSourceRgb(altColor.red, altColor.green, altColor.blue);
         c.fill();
      }

      if (!isMoved) cSet.setDisplay(0, reportPosition());
   }
}


