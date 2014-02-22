
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module serial;

import mainwin;
import config;
import acomp;
import tvitem;
import common;
import constants;
import types;
import controlset;

import std.stdio;
import std.conv;
import std.array;
import std.format;

import glib.Idle;
import cairo.Context;
import gtk.Widget;
import gtk.Button;
import gtk.TextView;
import gtk.TextBuffer;
import gtk.TextIter;
import gtk.Label;
import gtk.ToggleButton;
import gtk.CheckButton;
import gtk.RadioButton;
import gtk.SpinButton;
import gtk.Entry;
import gdk.RGBA;
import pango.PgFontDescription;
import gtkc.gdktypes;

class Serial : TextViewItem
{
   static int nextOid = 0;
   CheckButton cb1, cb2;
   static string padding = "0000000000";
   uint number;
   string text;
   bool pad;
   int padLength;
   string font;

   string formatLT(double lt)
   {
      scope auto w = appender!string();
      formattedWrite(w, "%1.1f", lt);
      return w.data;
   }

   override void syncControls()
   {
      cSet.setTextParams(alignment, pfd.toString());
      cSet.toggling(false);
      toggleView();
      cSet.setToggle(Purpose.FILL, pad);
      cSet.toggling(true);
      cSet.setHostName(name);
      cSet.setLabel(Purpose.MLABEL0, to!string(padLength));
   }

   this(Serial other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      pfd = other.pfd.copy();
      editMode = other.editMode;

      text = other.text.idup;
      number = other.number;
writefln("number %d text %s", number, text);
      pad = other.pad;
      padLength = other.padLength;
      syncControls();
      string s = other.te.getBuffer().getText();
      te.getBuffer().setText(s);
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Serial Number "~to!string(++nextOid);
      super(w, parent, s, AC_SERIAL);
      number = 0;
      text = "000";
      pad = true;
      padLength = 3;
      setupControls();
      positionControls(true);
   }

   override void extendControls()
   {
      int vp = cSet.cy;

      CheckButton cb = new CheckButton("Pad to fixed number of digits:");
      cb.setSensitive(0);
      cb.setActive(1);
      cSet.add(cb, ICoord(0, vp), Purpose.FILL);

      new MoreLess(cSet, 1, ICoord(240, vp), false);
      Label l = new Label("3");
      cSet.add(l, ICoord(275, vp), Purpose.MLABEL0);

      vp += 30;

      new InchTool(cSet, 0, ICoord(0, vp), false);

      cSet.cy = vp+35;
   }

   override void preResize(int oldW, int oldH)
   {
      double hr = cast(double) width/oldW;
      double vr = cast(double) height/oldH;
      hOff *= hr;
      vOff *= vr;
   }

   void onBufferChanged(TextBuffer b)
   {
      aw.dirty = true;
      dirty = true;
   }

   override bool specificNotify(Widget w, Purpose wid)
   {
      switch (wid)
      {
      case Purpose.FILL:
         pad = !pad;
         break;
      default:
         return false;
      }
      return true;
   }

   override void onCSMoreLess(int instance, bool more, bool far)
   {
      if (instance== 0)
      {
         TextViewItem.onCSMoreLess(instance, more, far);
         return;
      }
      int d = more? 1: -1;
      if (more)
      {
         if (padLength < 10)
            padLength += d;
      }
      else
      {
         if (padLength > 3)
            padLength += d;
      }
      cSet.setLabel(Purpose.MLABEL0, to!string(padLength));
      aw.dirty = true;
      reDraw();
   }

   override void toggleView()
   {
      if (editMode)
      {
         da.hide();
         dframe.hide();
         te.show();
         edButton.setLabel("Design");
         cSet.disable(Purpose.FILL);
         cSet.disable(Purpose.INCH, 0);
         cSet.disable(Purpose.MOL,1);
         eframe.show();
         te.grabFocus();
         te.show();
      }
      else
      {
         string text = te.getBuffer().getText();
         if (text.length == 0)
         {
            number = 0;
            text = "0";
         }
         else
         {
            try
            {
               number = to!uint(text);
            }
            catch (Exception x)
            {
               aw.popupMsg("Could not interpret your entry as an integer number", MessageType.ERROR);
               number = 0;
               editMode = true;
               return;
            }
         }
         if (number > 0)
            number--;      // we increment on printing, so lets start wherever the user said
         te.hide();
         eframe.hide();
         cSet.enable(Purpose.FILL);
         cSet.enable(Purpose.INCH, 0);
         cSet.enable(Purpose.MOL,1);
         dframe.show();
         edButton.setLabel("Edit Text");
         da.show();
      }
      aw.dirty = true;
   }

   string doPad()
   {
      if (padLength == -1)
         return text;
      if (text.length < padLength)
      {
         int d = padLength-cast(int)text.length;
         text = padding[0..d]~text;
      }
      return text;
   }

   override void render(Context c)
   {
writefln("render %s number %d text %s", name, number, text);
      if (printFlag)
         number++;
      text = to!string(number);
      string s = doPad();
      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);
      setCairoFont(c, pfd);
      c.moveTo(hOff, vOff+0.5*height);
      c.showText(text);
   }
}


