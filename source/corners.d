
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module corners;

import mainwin;
import constants;
import acomp;
import common;
import types;
import controlset;
import lineset;
import mol;

import std.stdio;
import std.conv;

import gtk.DrawingArea;
import gtk.Widget;
import gtk.Label;
import gtk.Button;
import gtk.CheckButton;
import gtk.Layout;
import gdk.RGBA;
import cairo.Context;
import gtkc.cairotypes;
import cairo.Matrix;

class Corners : LineSet
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
   bool tl, tr, bl, br;

   override void syncControls()
   {
      cSet.setLineParams(lineWidth);
      cSet.toggling(false);
      if (les)
         cSet.setToggle(Purpose.LESSHARP, true);
      else
         cSet.setToggle(Purpose.LESROUND, true);
      if (tl)
         cSet.setToggle(Purpose.TOPLEFT, true);
      if (tr)
         cSet.setToggle(Purpose.TOPRIGHT, true);
      if (bl)
         cSet.setToggle(Purpose.BOTTOMLEFT, true);
      if (br)
         cSet.setToggle(Purpose.BOTTOMRIGHT, true);
      cSet.setLabel(Purpose.LINEWIDTH, formatLT(lineWidth));
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(Corners other)
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
      tl = other.tl;
      tr = other.tr;
      bl = other.bl;
      br = other.br;
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Corners "~to!string(++nextOid);
      super(w, parent, s, AC_CORNERS, ACGroups.EFFECTS);
      notifyHandlers ~= &Corners.notifyHandler;
      undoHandlers ~= &Corners.undoHandler;

      hOff = vOff = 0;
      cw = 0.2*width;
      ch = 0.2*height;
      tl = true;
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
      int vp = cSet.cy;

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

      CheckButton cb = new CheckButton("Top left");
      cb.setActive(1);
      cSet.add(cb, ICoord(0, vp), Purpose.TOPLEFT);
      cb = new CheckButton("Top Right");
      cSet.add(cb, ICoord(142, vp), Purpose.TOPRIGHT);
      vp += 20;
      cb = new CheckButton("Bottom left");
      cSet.add(cb, ICoord(0, vp), Purpose.BOTTOMLEFT);
      cb = new CheckButton("Bottom right");
      cSet.add(cb, ICoord(142, vp), Purpose.BOTTOMRIGHT);

      cSet.cy = vp+30;
   }

   int toBits()
   {
      int n = 0;
      if (tl)
         n |= 1;
      if (tr)
         n |= 2;
      if (bl)
         n |= 4;
      if (br)
         n |= 8;
      return n;
   }

   void fromBits(int n)
   {
      tl = tr = bl = br = false;
      if (n & 1)
         tl = true;
      if (n & 2)
         tr = true;
      if (n & 4)
         bl = true;
      if (n & 8)
         br = true;
   }

   override bool notifyHandler(Widget w, Purpose p)
   {
      switch (p)
      {
      case Purpose.TOPLEFT:
         tl = ! tl;
         lastOp = push!int(this, toBits(), OP_IV0);
         break;
      case Purpose.TOPRIGHT:
         tr = !tr;
         lastOp = push!int(this, toBits(), OP_IV0);
         break;
      case Purpose.BOTTOMLEFT:
         bl = !bl;
         lastOp = push!int(this, toBits(), OP_IV0);
         break;
      case Purpose.BOTTOMRIGHT:
         br = !br;
         lastOp = push!int(this, toBits(), OP_IV0);
         break;
      default:
         return false;
      }
      return true;
   }

   override void onCSMoreLess(int instance, bool more, bool quickly)
   {
      focusLayout();
      double result;
      switch (instance)
      {
         case 0:
            result = cw;
            if (!molA!double(more, quickly, result, 1, 1, cast(double) width))
               return;
            lastOp = pushC!double(this, cw, OP_HSIZE);
            cw = result;
            break;
         case 1:
            result = ch;
            if (!molA!double(more, quickly, result, 1, 1, cast(double) height))
               return;
            lastOp = pushC!double(this, ch, OP_VSIZE);
            ch = result;
            break;
         case 2:
            double lim = ((width < height)? width: height)/3;
            result = inset;
            if (!molA!double(more, quickly, result, 1, 1, lim))
               return;
            lastOp = pushC!double(this, ch, OP_DV1);
            inset = result;
            break;
         default:
            return;
      }
      aw.dirty = true;
      reDraw();
   }

   override bool undoHandler(CheckPoint cp)
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
         fromBits(cp.iVal);
         break;
      default:
         return false;
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
      if (tl)
      {
         c.moveTo(hOff+inset, vOff+inset+ch);
         c.lineTo(hOff+inset, vOff+inset);
         c.lineTo(hOff+inset+cw, vOff+inset);
         c.stroke();
      }
      if (tr)
      {
         c.moveTo(hOff+width-inset-cw, vOff+inset);
         c.lineTo(hOff+width-inset, vOff+inset);
         c.lineTo(hOff+width-inset, vOff+inset+ch);
         c.stroke();
      }
      if (bl)
      {
         c.moveTo(hOff+inset, vOff+height-inset-ch);
         c.lineTo(hOff+inset, vOff+height-inset);
         c.lineTo(hOff+inset+cw, vOff+height-inset);
         c.stroke();
      }
      if (br)
      {
         c.moveTo(hOff+width-inset-cw, vOff+height-inset);
         c.lineTo(hOff+width-inset, vOff+height-inset);
         c.lineTo(hOff+width-inset, vOff+height-inset-ch);
         c.stroke();
      }
   }
}


