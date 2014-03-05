
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module noise;

import mainwin;
import constants;
import acomp;
import common;
import types;
import controlset;
import lineset;

import std.stdio;
import std.conv;
import std.random;

import gtk.Widget;
import gtk.Label;
import gtk.Button;
import gtk.CheckButton;
import gtk.ComboBoxText;
import gdk.RGBA;
import cairo.Context;
import cairo.Surface;

class Noise : LineSet
{
   static int nextOid = 0;
   static int[5] ndots = [ 500, 2000, 5000, 10000, 20000 ];
   int level, dots;
   uint instanceSeed, tempSeed;
   bool printRandom;
   Random gen;

   override void syncControls()
   {
      cSet.setLineParams(lineWidth);
      cSet.toggling(false);
      cSet.setToggle(Purpose.PRINTRANDOM, printRandom);
      cSet.setComboIndex(Purpose.PATTERN, level);
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(Noise other)
   {
      this(other.aw, other.parent);
      baseColor = other.baseColor.copy();
      lineWidth = other.lineWidth;
      level = other.level;
      dots = other.dots;
      instanceSeed = other.instanceSeed;
      printRandom = other.printRandom;
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Noise "~to!string(++nextOid);
      super(w, parent, s, AC_NOISE, ACGroups.EFFECTS);
      notifyHandlers ~= &Noise.notifyHandler;

      lineWidth = 1.0;
      level = 2;
      dots = 5000;
      instanceSeed = 42;
      tempSeed=unpredictableSeed();
      gen.seed(instanceSeed);
      setupControls(0);
      positionControls(true);
   }

   override void afterDeserialize()
   {
      gen.seed(instanceSeed);
   }

   override void extendControls()
   {
      int vp = cSet.cy;

      ComboBoxText cbb = new ComboBoxText(false);
      cbb.appendText("Barely");
      cbb.appendText("Quiet");
      cbb.appendText("Moderate");
      cbb.appendText("Loud");
      cbb.appendText("Deafening");
      cbb.setActive(2);
      cbb.setSizeRequest(100, -1);
      cSet.add(cbb, ICoord(0, vp), Purpose.PATTERN);

      Button b = new Button("Regenerate");
      cSet.add(b, ICoord(160, vp), Purpose.REDRAW);

      vp += 28;
      CheckButton cb = new CheckButton("Print Random");
      cSet.add(cb, ICoord(158, vp), Purpose.PRINTRANDOM);

      cSet.cy = vp+24;
   }

   override bool notifyHandler(Widget w, Purpose p)
   {
      switch (p)
      {
      case Purpose.PATTERN:
         level = (cast(ComboBoxText) w).getActive();
         dots = ndots[level];
         break;
      case Purpose.REDRAW:
         instanceSeed += cSet.control? -1: 1;
         break;
      case Purpose.PRINTRANDOM:
         printRandom = !printRandom;
         break;
      default:
         return false;
      }
      return true;
   }

   override void render(Context c)
   {
      c.translate(hOff, vOff);
      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);
      c.setLineWidth(lineWidth);
      c.setLineCap(CairoLineCap.ROUND);
      double step = 0.1*lineWidth;
      uint sv = instanceSeed;
      if (printRandom && printFlag)
         sv = tempSeed;
      gen.seed(sv);
      for (int i = 0; i < dots; i++)
      {
         double ho = uniform(0.0, 1.0*width, gen);
         double vo = uniform(0.0, 1.0*height, gen);
         c.moveTo(ho,vo);
         c.lineTo(ho,vo+step);
         c.stroke();
      }
      if (printRandom && printFlag)
         tempSeed++;
   }
}
