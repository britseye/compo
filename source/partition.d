
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module partition;

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
import gtk.ToggleButton;
import gtk.ComboBoxText;
import gdk.RGBA;
import cairo.Context;
import gtkc.cairotypes;
import cairo.Matrix;

class Partition: ACBase
{
   static int nextOid = 0;
   enum
   {
      VERTICAL,
      HORIZONTAL,
      ARCLEFT,
      ARCRIGHT,
      WAVE,
      EXPLEFT,
      EXPRIGHT,
      HILLNDALE
   }

   double lineWidth;
   double x, y;
   int choice;
   bool outline, vertical;

   override void syncControls()
   {
      cSet.toggling(false);
      cSet.setToggle(Purpose.FILLOUTLINE, outline);
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(Partition other)
   {
      this(other.aw, other.parent,);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      lineWidth = other.lineWidth;
      x = other.x;
      y = other.y;
      choice =other.choice;
      outline = other.outline;
      vertical = other.vertical;
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Partition "~to!string(++nextOid);
      super(w, parent, s, AC_PARTITION);
      group = ACGroups.EFFECTS;
      hOff = vOff = 0;
      lineWidth = 0.5;
      x = 0.25*width;
      y = 0.75*height;
      baseColor = new RGBA(0.8125, 0.8125, 0.8125, 1.0);
      choice = 0;

      setupControls();
      positionControls(true);
   }

   override void extendControls()
   {
      int vp = cSet.cy;

      Button b = new Button("Color");
      cSet.add(b, ICoord(0, vp), Purpose.COLOR);

      CheckButton cb = new CheckButton("Draw partition edge.");
      cSet.add(cb, ICoord(100, vp), Purpose.FILLOUTLINE);

      vp +=  30;
      Label l = new Label("Position");
      cSet.add(l, ICoord(0, vp), Purpose.LABEL);
      new MoreLess(cSet, 0, ICoord(100, vp), true);

      vp += 30;
      ComboBoxText cbb = new ComboBoxText(false);
      cbb.appendText("Vertical");
      cbb.appendText("Horizontal");
      cbb.appendText("Arc Left");
      cbb.appendText("Arc Right");
      cbb.appendText("Wave");
      cbb.appendText("Exponential -");
      cbb.appendText("Exponential +");
      cbb.appendText("Hill'N Dale");
      cbb.setSizeRequest(120, -1);
      cbb.setActive(0);
      cSet.add(cbb, ICoord(0, vp), Purpose.PATTERN);

      cSet.cy= vp+40;
   }

   override bool specificNotify(Widget w, Purpose wid)
   {
      switch (wid)
      {
      case Purpose.FILLOUTLINE:
         outline = !outline;
         break;
      case Purpose.PATTERN:
         choice = (cast(ComboBoxText) w).getActive();
         switch (choice)
         {
         case VERTICAL:
            y = 0.75*height;
            hOff = 0;
            break;
         case HORIZONTAL:
            x = 0.25*width;
            vOff = 0;
            break;
         case ARCLEFT:
            x = 0.25*width;
            vOff = 0;
            break;
         case ARCRIGHT:
            x = 0.75*width;
            vOff = 0;
            break;
         case WAVE:
            y = 0.6*height;
            hOff = 0;
            break;
         case EXPLEFT:
         case EXPRIGHT:
            x = 0.5*width;
            vOff = 0;
            break;
         case HILLNDALE:
            break;
         default:
            return false;
         }
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
      case OP_RESIZE:
         Coord t = cp.coord;
         hOff = t.x;
         vOff = t.y;
         break;
      default:
         return false;
      }
      lastOp = OP_UNDEF;
      return true;
   }

   override void onCSMoreLess(int instance, bool more, bool coarse)
   {
      focusLayout();
      int direction = more? 1: -1;
      if (coarse)
         direction *= 2;
      lastOp = pushC!Coord(this, Coord(hOff, vOff), OP_RESIZE);
      switch (choice)
      {
         case VERTICAL:
            vOff += direction;
            break;
         case HORIZONTAL:
            hOff += direction;
            break;
         case ARCLEFT:
         case ARCRIGHT:
            hOff += direction;
            break;
         case WAVE:
            vOff += direction;
            break;
         case EXPLEFT:
         case EXPRIGHT:
            hOff += direction;
            break;
         default:
            return;
      }
      aw.dirty = true;
      reDraw();
   }

   // For keyboard arrow keys
   override void move(int direction, bool far)
   {
      focusLayout();
      lastOp = pushC!Coord(this, Coord(hOff, vOff), OP_MOVE);
      double d = far? 10.0: 1.0;
      if (direction == 0 || direction == 2)
      {
         if (direction == 0)
            d = -d;
         switch (choice)
         {
            case HORIZONTAL:
            case ARCLEFT:
            case ARCRIGHT:
            case EXPLEFT:
            case EXPRIGHT:
               hOff += direction;
               break;
            default:
               return;
         }
      }
      else
      {
         if (direction == 1)
            d = -d;
         switch (choice)
         {
            case VERTICAL:
            case WAVE:
               vOff += direction;
               break;
            default:
               return;
         }

      }
      aw.dirty = true;
      reDraw();
   }

   void pathVertical(Context c)
   {
      c.moveTo(hOff+x, lpY-0.5);
      c.lineTo(hOff+x, lpY+height+0.5);
      c.lineTo(lpX-0.5, lpY+height+0.5);
      c.lineTo(lpX-0.5, lpY-0.5);
      c.closePath();
   }

   void pathHorizontal(Context c)
   {
      c.moveTo(lpX-0.5, vOff+y);
      c.lineTo(lpX+width+0.5, vOff+y);
      c.lineTo(lpX+width+0.5, lpY+height+0.5);
      c.lineTo(lpX-0.5, lpY+height+0.5);
      c.closePath();
   }

   void pathArcLeft(Context c)
   {
      double angle = atan((0.55*(height)) /(1.5*height));
      c.arc(hOff+x+1.5*height, lpY+height/2, 1.5*height, PI-angle, PI+angle);
      c.lineTo(lpX-0.5, lpY-0.5);
      c.lineTo(lpX+0.5, lpY+height+0.5);
      c.closePath();
   }

   void pathArcRight(Context c)
   {
      double angle = atan((0.55*(height)) /(1.5*height));
      c.arc(hOff+x-1.5*height, lpY+height/2, 1.5*height, -angle, angle);
      c.lineTo(lpX+width+0.5, lpY+height+0.5);
      c.lineTo(lpX+width+0.5, lpY-0.5);
      c.closePath();
   }

   void pathWave(Context c)
   {
      double vx = 0;
      c.moveTo(lpX-1, vOff+y);
      double d = 0;
      for (int i = 0; i*2.0 <= width; i++, vx += 2)
      {
         d =  sin(vx/(PI*width*0.01));
         c.lineTo(lpX+vx, vOff+y+0.04*d*height);
      }
      c.lineTo(lpX+width+1, lpY+height+1);
      c.lineTo(lpX-1, lpY+height+1);
      c.closePath();
   }

   void pathNegExp(Context c)
   {
      double ex = 0;
      c.moveTo(hOff+x, lpY+height+1);
      double d = 0;
      for (int i = 0; height+2-d >= 0; i++, ex += 0.14)
      {
         d = pow(E, ex);
         c.lineTo(hOff+x-i*4.0, lpY+height+2-d);
      }
      c.lineTo(lpX-1, lpY+height+2-d);
      c.lineTo(lpX-1, lpY+height+1);
      c.closePath();
   }

   void pathExp(Context c)
   {
      double ex = 0;
      c.moveTo(hOff+x, lpY+height+1);
      double d = 0;
      for (int i = 0; height+2-d >= 0; i++, ex += 0.14)
      {
         d = pow(E, ex);
         c.lineTo(hOff+x+i*4.0, lpY+height+2-d);
      }
      c.lineTo(lpX+width+1, lpY+height+2-d);
      c.lineTo(lpX+width+1, lpY+height+1);
      c.closePath();
   }

   void pathHillNDale(Context c, bool outline = false)
   {
      Coord s0, cp10, cp20, e0, cp11, cp21, e1, cp12, cp22, e2;
      s0 = Coord(lpX-1, vOff+0.4*height);
      cp10 = Coord(lpX+0.2*width, vOff+0.1*height);
      cp20 = Coord(lpX+0.4*width, vOff+0.1*height);
      e0 = Coord(lpX+0.55*width, vOff+0.5*height);
      cp11 = Coord(lpX+0.6*width, vOff+0.3*height);
      cp21 = Coord(lpX+0.8*width, vOff+0.25*height);
      e1 = Coord(lpX+width+1, vOff+0.25*height);
      cp12 = Coord(lpX+0.6*width, vOff+0.6*height);
      cp22 = Coord(lpX+0.65*width, vOff+0.6*height);
      e2 = Coord(lpX+0.65*width, vOff+0.6*height);
      if (outline)
      {
         c.moveTo(s0.x, s0.y);
         c.curveTo(cp10.x, cp10.y, cp20.x,cp20.y, e0.x, e0.y);
         c.curveTo(cp12.x, cp12.y, cp22.x,cp22.y, e2.x, e2.y);
         c.stroke();
      }
      else
      {
         c.moveTo(s0.x, s0.y);
         c.curveTo(cp10.x, cp10.y, cp20.x,cp20.y, e0.x, e0.y);
         c.curveTo(cp11.x, cp11.y, cp21.x,cp21.y, e1.x, e1.y);
         c.lineTo(lpX+width+1, vOff+height*1.5);
         c.lineTo(lpX-1, vOff+height*1.5);
         c.closePath();
      }
   }

   override void render(Context c)
   {
      bool old = outline;
      c.setLineWidth(0.5);
      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);
      switch (choice)
      {
      case 0:
         pathHorizontal(c);
         break;
      case 1:
         pathVertical(c);
         break;
      case 2:
         pathArcLeft(c);
         break;
      case 3:
         pathArcRight(c);
         break;
      case 4:
         pathWave(c);
         break;
      case 5:
         pathNegExp(c);
         break;
      case 6:
         pathExp(c);
         break;
      case 7:
         outline = true;
         pathHillNDale(c);
         break;
      default:
         return;
      }

      if (outline)
      {
         c.fillPreserve();
         c.setSourceRgb(0,0,0);
         c.stroke();
         if (choice == 7)
            pathHillNDale(c, true);
      }
      else
         c.fill();
      outline = old;
   }
}



