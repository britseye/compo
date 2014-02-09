
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module text;

import container;
import mainwin;
import acomp;
import tvitem;
import common;
import constants;
import types;
import controlset;
import tb2pm;

import std.stdio;
import std.conv;

import glib.Idle;
import gtk.Layout;
import gtk.Frame;
import cairo.Context;
import gtk.Widget;
import gtk.Button;
import gtk.DrawingArea;
import gtk.TextView;
import gtk.TextBuffer;
import gtk.TextIter;
import gtk.Label;
import gtk.ToggleButton;
import gtk.CheckButton;
import gtk.RadioButton;
import gtk.Entry;
import gdk.RGBA;
import gtk.Style;
import pango.PgFontDescription;
import gdk.Screen;
import gtkc.gdktypes;
import cairo.Surface;

class PlainText : TextViewItem
{
   static int nextOid = 0;
   string[] linetext;
   string font;
   bool centerText, shrink2Fit;
   bool gotLines;

   override void syncControls()
   {
      cSet.setTextParams(alignment, pfd.toString());
      cSet.toggling(false);
      cSet.setToggle(Purpose.CENTERTEXT, centerText);
      cSet.setToggle(Purpose.SHRINK2FIT, shrink2Fit);
      if (editMode)
      {
         cSet.setToggle(Purpose.EDITMODE, true);
         toggleView();
      }
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(PlainText other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy;
      pfd = other.pfd.copy();
      editMode = other.editMode;
      alignment = other.alignment;
      centerText = other.centerText;
      shrink2Fit = other.shrink2Fit;
      syncControls();
      te.setWrapMode(GtkWrapMode.WORD);

      string text = other.tb.getText();
      tb.setText(text);
      textBlock.setAlignment(cast(PangoAlignment) alignment);
      dirty = true;
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Text "~to!string(++nextOid);
      super(w, parent, s, AC_TEXT);
      centerText = shrink2Fit = true;
      setupControls(1);
      positionControls(true);
      alignment = 0;
      te.setWrapMode(GtkWrapMode.WORD);
   }

   override void extendControls()
   {
      int vp = cSet.cy;

      new InchTool(cSet, 0, ICoord(0, vp+6), false);

      CheckButton cb = new CheckButton("Center Text");
      cb.setSensitive(0);
      cb.setActive(1);
      cSet.add(cb, ICoord(165, vp), Purpose.CENTERTEXT);

      vp += 20;
      cb = new CheckButton("Shrink to fit");
      cb.setSensitive(0);
      cb.setActive(1);
      cSet.add(cb, ICoord(165, vp), Purpose.SHRINK2FIT);

      cSet.cy = vp+25;
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
      gotLines = false;
      aw.dirty = true;
      dirty = true;
   }

   override bool specificNotify(Widget w, Purpose wid)
   {
      switch (wid)
      {
      case Purpose.CENTERTEXT:
         centerText = !centerText;
         break;
      case Purpose.SHRINK2FIT:
         shrink2Fit = !shrink2Fit;
         break;
      default:
         return false;
      }
      return true;
   }

   override void toggleView()
   {
      if (editMode)
      {
         da.hide();
         dframe.hide();
         te.show();
         cSet.disable(Purpose.CENTERTEXT);
         cSet.disable(Purpose.SHRINK2FIT);
         cSet.disable(Purpose.INCH, 0);
         eframe.show();
         te.grabFocus();
         te.show();
      }
      else
      {
         te.hide();
         eframe.hide();
         cSet.enable(Purpose.CENTERTEXT);
         cSet.enable(Purpose.SHRINK2FIT);
         cSet.enable(Purpose.INCH, 0);
         dframe.show();
         string txt=tb.getText();
         if (txt.length)
         {
            if (txt.length > 20)
               txt = txt[0..20];
            setName(txt);
         }
         da.show();
      }
      aw.dirty = true;
   }

   ICoord doShrink(Context c)
   {
      ICoord rv;
      PgFontDescription tpfd = pfd.copy();
      for (;;)
      {
         double fs = tpfd.getSize();
         fs *= 0.95;
         tpfd.setSize(cast(int) fs);
         textBlock.setFont(tpfd);
         textBlock.instantiate(c);
         PangoRectangle pr = textBlock.getExtent();
         int tbw = pr.width/1024;
         int tbh = pr.height/1024;
         if (tbw < 0.97*width && tbh < 0.97*height)
         {
            rv =ICoord(tbw, tbh);
            break;
         }
      }
      return rv;
   }

   override void render(Context c)
   {
      int xoff, yoff;
      if (dirty)
      {
         string s = tb.getText();
         textBlock.setText(s);
         textBlock.setFont(pfd);
         dirty = false;
      }

      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);
      textBlock.instantiate(c);
      if (centerText)
      {
         PangoRectangle pr = textBlock.getExtent();
         int tbw = pr.width/1024;
         int tbh = pr.height/1024;
         if (shrink2Fit)
         {
            if (tbw > width || tbh > height)
            {
               ICoord t = doShrink(c);
               tbw = t.x;
               tbh = t.y;
            }
         }
         xoff = (width-tbw)/2;
         yoff = (height-tbh)/2;
      }
      c.moveTo(hOff+xoff, vOff+yoff);
      textBlock.render();
      textBlock.setFont(pfd);
   }
}
