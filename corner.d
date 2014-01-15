
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module corner;

import main;
import constants;
import acomp;
import common;
import types;
import controlset;
import lineset;

import std.stdio;
import std.conv;

import gtk.DrawingArea;
import gtk.Widget;
import gtk.Label;
import gtk.Button;
import gtk.SpinButton;
import gtk.RadioButton;
import gtk.ToggleButton;
import gtk.Layout;
import gtk.Frame;
import gtk.Range;
import gdk.RGBA;
import cairo.Context;
import gtkc.cairotypes;
import cairo.Matrix;

class Corner : LineSet
{
   static int nextOid = 0;
   enum
   {
      TL,
      TR,
      BL,
      BR
   }
   double cw, ch, inset;
   int relto;
   int which;

   override void syncControls()
   {
      cSet.setLineParams(lineWidth);
      cSet.toggling(false);
      if (les)
         cSet.setToggle(Purpose.LESSHARP, true);
      else
         cSet.setToggle(Purpose.LESROUND, true);
      switch (which)
      {
      case 0:
         cSet.setToggle(Purpose.TOPLEFT, true);
         break;
      case 1:
         cSet.setToggle(Purpose.TOPRIGHT, true);
         break;
      case 2:
         cSet.setToggle(Purpose.BOTTOMLEFT, true);
         break;
      default:
         cSet.setToggle(Purpose.BOTTOMRIGHT, true);
         break;
      }
      cSet.setLabel(Purpose.LINEWIDTH, formatLT(lineWidth));
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(Corner other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      cw = other.cw;
      ch = other.ch;
      inset = other.inset;
      lineWidth = other.lineWidth;
      les = other.les;
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Corner "~to!string(++nextOid);
      super(w, parent, s, AC_CORNER);
      hOff = vOff = 0;
      cw = 0.2*width;
      ch = 0.2*height;
      //relto = width>height? height: width;
      inset = 3;
      lineWidth = 0.5;
      les = true;

      setupControls(3);
      positionControls(true);
   }

   override int getNextOid()
   {
      return ++nextOid;
   }

   override void extendControls()
   {
      int vp = cSet.cy;;

      Label l = new Label("Width");
      l.setTooltipText("Adjust width - hold down <Ctrl> for faster action");
      cSet.add(l, ICoord(180, vp-38), Purpose.LABEL);
      new MoreLess(cSet, 0, ICoord(245, vp-38), true);

      l = new Label("Height");
      l.setTooltipText("Adjust height - hold down <Ctrl> for faster action");
      cSet.add(l, ICoord(180, vp-18), Purpose.LABEL);
      new MoreLess(cSet, 1, ICoord(245, vp-18), true);

      new InchTool(cSet, 0, ICoord(0, vp), true);

      l = new Label("Inset");
      cSet.add(l, ICoord(180, vp+7), Purpose.LABEL);
      new MoreLess(cSet, 2, ICoord(245, vp+7), true);

      vp += 40;

      RadioButton rb = new RadioButton("Top left");
      cSet.add(rb, ICoord(0, vp), Purpose.TOPLEFT);
      RadioButton rb2 = new RadioButton(rb, "Top Right");
      cSet.add(rb2, ICoord(142, vp), Purpose.TOPRIGHT);
      vp += 20;
      rb2 = new RadioButton(rb, "Bottom left");
      cSet.add(rb2, ICoord(0, vp), Purpose.BOTTOMLEFT);
      rb2 = new RadioButton(rb, "Bottom right");
      cSet.add(rb2, ICoord(142, vp), Purpose.BOTTOMRIGHT);

      cSet.cy = vp+30;
   }

   override bool specificNotify(Widget w, Purpose wid)
   {
      switch (wid)
      {
      case Purpose.TOPLEFT:
         if (which == TL)
            return true;
         lastOp = push!int(this, which, OP_IV0);
         which = TL;
         break;
      case Purpose.TOPRIGHT:
         if (which == TR)
            return true;
         lastOp = push!int(this, which, OP_IV1);
         which = TR;
         break;
      case Purpose.BOTTOMLEFT:
         if (which == BL)
            return true;
         lastOp = push!int(this, which, OP_IV2);
         which = BL;
         break;
      case Purpose.BOTTOMRIGHT:
         if (which == BR)
            return true;
         lastOp = push!int(this, which, OP_IV3);
         which = BR;
         break;
      default:
         return false;
      }
      return true;
   }

   override void onCSMoreLess(int instance, bool more, bool coarse)
   {
      focusLayout();
      int n = more? 1: -1;
      if (coarse)
         n *= 10;
      if (instance == 0)
      {
         lastOp = pushC!double(this, cw, OP_HSIZE);
         cw += n;
      }
      else if (instance == 1)
      {
         lastOp = pushC!double(this, ch, OP_VSIZE);
         ch += n;
      }
      else
      {
         lastOp = pushC!double(this, inset, OP_DV1);
         n = more? 1: -1;
         inset += n;;
      }
      aw.dirty = true;
      reDraw();
   }

   override bool specificUndo(CheckPoint cp)
   {
      switch (cp.type)
      {
      case OP_HSIZE:
         cw = cp.dVal;
         lastOp = OP_UNDEF;
         break;
      case OP_DV1:
         inset = cp.dVal;
         lastOp = OP_UNDEF;
         break;
      case OP_VSIZE:
         ch = cp.dVal;
         lastOp = OP_UNDEF;
         break;
      case OP_IV0:
      case OP_IV1:
      case OP_IV2:
      case OP_IV3:
         which = cp.iVal;
         break;
      default:
         return false;;
      }
      return true;
   }

   override void render(Context c)
   {
      c.setLineWidth(lineWidth);
      c.setLineJoin(les? CairoLineJoin.MITER: CairoLineJoin.ROUND);
      c.setLineCap(les? CairoLineCap.BUTT: CairoLineCap.ROUND);
      double r = baseColor.red();
      double g = baseColor.green();
      double b = baseColor.blue();
      c.setSourceRgb(r, g, b);
      switch (which)
      {
      case TL:
         c.moveTo(hOff+inset, vOff+inset+ch);
         c.lineTo(hOff+inset, vOff+inset);
         c.lineTo(hOff+inset+cw, vOff+inset);
         c.stroke();
         break;
      case TR:
         c.moveTo(hOff+width-inset-cw, vOff+inset);
         c.lineTo(hOff+width-inset, vOff+inset);
         c.lineTo(hOff+width-inset, vOff+inset+ch);
         c.stroke();
         break;
      case BL:
         c.moveTo(hOff+inset, vOff+height-inset-ch);
         c.lineTo(hOff+inset, vOff+height-inset);
         c.lineTo(hOff+inset+cw, vOff+height-inset);
         c.stroke();
         break;
      default:
         c.moveTo(hOff+width-inset-cw, vOff+height-inset);
         c.lineTo(hOff+width-inset, vOff+height-inset);
         c.lineTo(hOff+width-inset, vOff+height-inset-ch);
         c.stroke();
         break;
      }
      if (!isMoved) cSet.setDisplay(0, reportPosition());
   }
}


