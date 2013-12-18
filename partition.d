
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module partition;

import main;
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
      EXPRIGHT
   }

   double bt;
   double lineWidth;
   double x, y;
   int choice;
   bool outline, vertical;

   void syncControls()
   {
      cSet.toggling(false);
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(Partition other)
   {
      this(other.aw, other.parent,);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      bt = other.bt;
      lineWidth = other.lineWidth;
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Partition "~to!string(++nextOid);
      super(w, parent, s, AC_PARTITION);
      hOff = vOff = 0;
      bt = 10.0;
      lineWidth = 0.5;
      x = 0.25*width;
      y = 0.75*height;
      baseColor = new RGBA(0.8125, 0.8125, 0.8125, 1.0);
      choice = 0;

      setupControls();
      positionControls(true);
   }

   void extendControls()
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
      cbb.setSizeRequest(120, -1);
      cbb.setActive(0);
      cSet.add(cbb, ICoord(0, vp), Purpose.PATTERN);

      cSet.cy= vp+40;
   }

   void preResize(int oldW, int oldH)
   {
   }

   void onCSNotify(Widget w, Purpose wid)
   {
      switch (wid)
      {
      case Purpose.COLOR:
         dummy.grabFocus();
         lastOp = push!RGBA(this, baseColor, OP_COLOR);
         setColor(false);
         break;
      case Purpose.FILLCOLOR:
         lastOp = push!RGBA(this, altColor, OP_ALTCOLOR);
         setColor(true);
         break;
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
         default:
            return;
         }
         break;
      default:
         return;
      }
      aw.dirty = true;
      reDraw();
   }

   void onCSMoreLess(int instance, bool more, bool coarse)
   {
      dummy.grabFocus();
      int direction = more? 1: -1;
      if (coarse)
         direction *= 2;
      lastOp = pushC!Coord(this, Coord(hOff, vOff), OP_MOVE);
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

   void undo()
   {
      CheckPoint cp;
      cp = popOp();
      if (cp.type == 0)
         return;
      switch (cp.type)
      {
      case OP_COLOR:
         baseColor = cp.color.copy();
         lastOp = OP_UNDEF;
         break;
      case OP_ALTCOLOR:
         altColor = cp.color.copy();
         lastOp = OP_UNDEF;
         break;
      default:
         return;
      }
      aw.dirty = true;
      reDraw();
   }

   // For keyboard arrow keys
   void move(int direction, bool far)
   {
      dummy.grabFocus();
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
      c.moveTo(hOff+x, -0.5);
      c.lineTo(hOff+x, height+0.5);
      c.lineTo(-0.5, height+0.5);
      c.lineTo(-0.5, -0.5);
      c.closePath();
   }

   void pathHorizontal(Context c)
   {
      c.moveTo(-0.5, vOff+y);
      c.lineTo(width+0.5, vOff+y);
      c.lineTo(width+0.5, height+0.5);
      c.lineTo(-0.5, height+0.5);
      c.closePath();
   }

   void pathArcLeft(Context c)
   {
      double angle = atan((0.55*(height)) /(1.5*height));
      c.arc(hOff+x+1.5*height, height/2, 1.5*height, PI-angle, PI+angle);
      c.lineTo(-0.5, -0.5);
      c.lineTo(0.5, height+0.5);
      c.closePath();
   }

   void pathArcRight(Context c)
   {
      double angle = atan((0.55*(height)) /(1.5*height));
      c.arc(hOff+x-1.5*height, height/2, 1.5*height, -angle, angle);
      c.lineTo(width+0.5, height+0.5);
      c.lineTo(width+0.5, -0.5);
      c.closePath();
   }

   void pathWave(Context c)
   {
      double vx = 0;
      c.moveTo(-1, vOff+y);
      double d = 0;
      for (int i = 0; i*2.0 <= width; i++, vx += 2)
      {
         d =  sin(vx/(PI*width*0.01));
         c.lineTo(vx, vOff+y+0.04*d*height);
      }
      c.lineTo(width+1, height+1);
      c.lineTo(-1, height+1);
      c.closePath();
   }

   void pathNegExp(Context c)
   {
      double ex = 0;
      c.moveTo(hOff+x, height+1);
      double d = 0;
      for (int i = 0; height+2-d >= 0; i++, ex += 0.14)
      {
         d = pow(E, ex);
         c.lineTo(hOff+x-i*4.0, height+2-d);
      }
      c.lineTo(-1, height+2-d);
      c.lineTo(-1, height+1);
      c.closePath();
   }

   void pathExp(Context c)
   {
      double ex = 0;
      c.moveTo(hOff+x, height+1);
      double d = 0;
      for (int i = 0; height+2-d >= 0; i++, ex += 0.14)
      {
         d = pow(E, ex);
         c.lineTo(hOff+x+i*4.0, height+2-d);
      }
      c.lineTo(width+1, height+2-d);
      c.lineTo(width+1, height+1);
      c.closePath();
   }

   void render(Context c)
   {
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
      default:
         c.restore();
         return;
      }

      if (outline)
      {
         c.fillPreserve();
         c.setSourceRgb(0,0,0);
         c.stroke();
      }
      else
         c.fill();
   }
}



