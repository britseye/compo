
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module fancytext;

import types;
import controlset;

import main;
import acomp;
import tvitem;
import common;
import constants;

import std.stdio;
import std.conv;
import std.array;
import std.format;

import gtk.Layout;
import gtk.Frame;
import cairo.Context;
import gtk.Widget;
import gtk.Button;
import gtk.SpinButton;
import gtk.DrawingArea;
import gtk.TextView;
import gtk.TextBuffer;
import gtk.TextIter;
import gtk.Label;
import gtk.ToggleButton;
import gtk.CheckButton;
import gtk.RadioButton;
import gtk.Arrow;
import gtk.Entry;
import gdk.RGBA;
import gtk.Style;
import pango.PgFontDescription;
import gdk.Screen;
import gtkc.gdktypes;
import cairo.Surface;
import pango.PgCairo;
import pango.PgLayout;
import gtkc.pangotypes;

struct FontMeasure
{
   double x;
   double y;
   double height;
   double width;
   double ascent;
   double descent;
}

class FancyText : TextViewItem
{
   static int nextOid = 0;
   enum
   {
      NORMAL,
      UP,
      DOWN,
      UPSIDE,
      ARBITRARY
   }

   Coord center;
   RadioButton rb1, rb2, rb3, rb4;
   CheckButton oo;
   Button fcbtn;
   SpinButton sb;
   int orientation;
   double angle;
   double olt;
   bool angleFixed, fill, solid;
   RGBA saveAltColor;
   //Surface hiddenSurface;
   //Context hidden;
   CairoPath *tpath;
   double ascent, descent;
   bool havePath;

   string formatLT(double lt)
   {
      scope auto w = appender!string();
      formattedWrite(w, "%1.1f", lt);
      return w.data;
   }

   void syncControls()
   {
      cSet.setLineWidth(olt);
      cSet.setTextParams(alignment, pfd.toString());
      cSet.toggling(false);
      if (!angleFixed) cSet.enable(Purpose.MOL, 1);
      if (solid)
      {
         cSet.setToggle(Purpose.SOLID, true);
         cSet.disable(Purpose.FILL);
         cSet.disable(Purpose.FILLCOLOR);
      }
      else if (fill)
         cSet.setToggle(Purpose.FILL, true);
      if (editMode)
      {
         cSet.setToggle(Purpose.EDITMODE, true);
         toggleView();
      }
      cSet.setLabel(Purpose.LINEWIDTH, formatLT(olt));
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(FancyText other)
   {
      this(other.aw, other.parent);
      editMode = other.editMode;

      // Copy the content of the other TextBuffer
      string text = other.tb.getText();
      tb.setText(text);

      baseColor = other.baseColor.copy;
      altColor = other.altColor.copy;
      pfd = other.pfd.copy();
      fill = other.fill;
      solid = other.solid;
      olt = other.olt;
      orientation = other.orientation;
      hOff = other.hOff;
      vOff = other.vOff;
      center = other.center;
      alignment = other.alignment;
      textBlock.setAlignment(cast(PangoAlignment) alignment);
      angle = other.angle;
      angleFixed = other.angleFixed;
      syncControls();
      dirty = true;
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Fancy Text "~to!string(++nextOid);
      super(w, parent, s, AC_FANCYTEXT);
      aw = w;
      altColor = new RGBA();
      angle = 0.0;
      angleFixed = true;
      olt = 0.5;

      int vp = rpTm+height+85;
      int tvp = vp;
      setupControls(1);
      positionControls(true);
   }

   void extendControls()
   {
      int vp = cSet.cy;
      int tvp = vp;

      Label l = new Label("Orientation");
      cSet.add(l, ICoord(0, vp), Purpose.LABEL);

      vp += 20;
      TextOrient to = new TextOrient(cSet, 0, ICoord(0, vp), false);

      l = new Label("Outline\nthickness");
      cSet.add(l, ICoord(167, tvp), Purpose.LABEL);
      MOLLineThick mlt = new MOLLineThick(cSet, 0, ICoord(240, tvp+5), false);

      CheckButton cb = new CheckButton("Fill with color");
      cb.setSensitive(0);
      cSet.add(cb, ICoord(170, tvp+35), Purpose.FILL);

      cb = new CheckButton("Solid");
      cb.setSensitive(0);
      cSet.add(cb, ICoord(170, tvp+55), Purpose.SOLID);

      Button b = new Button("Fill Color");
      b.setSensitive(0);
      cSet.add(b, ICoord(170, tvp+87), Purpose.FILLCOLOR);

      vp += 45;
      l = new Label("Angle");
      cSet.add(l, ICoord(0, vp), Purpose.LABEL);
      new MoreLess(cSet, 1, ICoord(60, vp), false);

      vp += 20;

      new InchTool(cSet, 0, ICoord(0, vp), false);

      cSet.cy=vp+40;
   }

   void preResize(int oldW, int oldH)
   {
      havePath = false;
      center.x = width/2;
      center.y = height/2;
      double vr = cast(double) width/oldW;
      double hr = cast(double) width/oldW;
      hOff *= hr;
      vOff *= vr;
   }

   void bufferChanged(TextBuffer b)
   {
      aw.dirty = true;
      dirty = true;
      havePath = false;
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
         setColor(true);
         break;
      case Purpose.EDITMODE:
         editMode = !editMode;
         toggleView();
         break;
      case Purpose.FILL:
         fill = !fill;
         if (fill)
            cSet.enable(Purpose.FILLCOLOR);
         else
            cSet.disable(Purpose.FILLCOLOR);
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
      default:
         break;
      }
      aw.dirty = true;
      reDraw();
   }

   void onCSLineWidth(double lw)
   {
      olt = lw;
      aw.dirty = true;
      reDraw();
   }

   void onCSMoreLess(int instance, bool more, bool far)
   {
      int direction = more? 1: -1;
      if (instance == 0)
      {
         adjustFontSize(direction, far);
      }
      else if (instance == 1)
      {
         if (far)
            direction *= 5;
            angle += direction;
      }
      else
         return;
      aw.dirty = true;
      reDraw();
   }

   void setOrientation(int o)
   {
      orientation = o;
      switch (orientation)
      {
         case 0:
            angle = 0.0;
            break;
         case 1:
            angle = 270.0;
            break;
         case 2:
            angle = 180.0;
            break;
         case 3:
            angle = 90.0;
            break;
         default:
            angle = 330.0;
            angleFixed = false;
            cSet.enable(Purpose.MOL, 1);
            return;
      }
      angleFixed = false;
      cSet.disable(Purpose.MOL, 1);
      aw.dirty = true;
      reDraw();
   };

   void toggleView()
   {
      if (editMode)
      {
         da.hide();
         dframe.hide();
         te.show();
         cSet.disable(Purpose.TORIENT, 0);
         cSet.disable(Purpose.FILL);
         cSet.disable(Purpose.FILLOUTLINE);
         cSet.disable(Purpose.SOLID);
         cSet.disable(Purpose.MOLLT, 0);
         cSet.disable(Purpose.MOL, 1);
         cSet.disable(Purpose.INCH, 0);
         eframe.show();
         te.grabFocus();
         te.show();
      }
      else
      {
         te.hide();
         eframe.hide();
         cSet.enable(Purpose.TORIENT, 0);
         cSet.enable(Purpose.FILL);
         cSet.enable(Purpose.FILLOUTLINE);
         cSet.enable(Purpose.SOLID);
         cSet.enable(Purpose.MOLLT, 0);
         if (!angleFixed)
            cSet.enable(Purpose.MOL, 1);
         cSet.enable(Purpose.INCH, 0);
         dframe.show();
         da.show();
      }
      aw.dirty = true;
   }
/*
   void adjust(int id, int direction, bool much)
   {
      if (angleFixed)
         return;
      direction = -direction;
      if (much)
         direction *= 5;
      angle += direction;
      reDraw();
   }
*/
   void render(Context c)
   {
      string text = tb.getText();
      if (!text.length)
         return;
      double r = baseColor.red();
      double g = baseColor.green();
      double b = baseColor.blue();
      c.newPath();
      c.translate(hOff+0.5*width, vOff+0.5*height);
      c.rotate(angle*rads);
      c.translate(-0.5*width, -0.5*height);
      PgLayout pgl = PgCairo.createLayout(c);
      pgl.setText(text);
      pgl.setAlignment(cast(PangoAlignment) alignment);
      pgl.setFontDescription(pfd);
      c.moveTo(0.5*width, 0.5*height);
      PgCairo.layoutPath(c, pgl);
      c.setSourceRgb(0,0,0);
      c.setLineWidth(olt);
      c.strokePreserve();
      if (solid)
      {
         c.setSourceRgba(r, g, b, 1.0);
         c.fill();
      }
      else if (fill)
      {
         double fr = altColor.red();
         double fg = altColor.green();
         double fb = altColor.blue();
         c.setSourceRgba(fr, fg, fb, 1.0);
         c.fillPreserve();
      }
      if (!solid)
      {
         c.setSourceRgb(r, g, b);
         c.stroke();
      }

      if (!isMoved) cSet.setDisplay(0, reportPosition());
   }
}


