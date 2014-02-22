
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module fancytext;

import types;
import controlset;

import mainwin;
import acomp;
import tvitem;
import common;
import constants;

import std.stdio;
import std.conv;
import std.array;
import std.format;
import std.math;

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
import gtk.ComboBoxText;
import gtk.Arrow;
import gtk.Entry;
import gdk.RGBA;
import gtk.Style;
import pango.PgFontDescription;
import gdk.Screen;
import gtkc.gdktypes;
import cairo.Surface;
import cairo.Matrix;
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
   double lastHo = double.min_normal, lastVo = double.max;
   bool angleFixed;
   RGBA saveAltColor;
   CairoPath* tPath;
   CairoPath pathCopy;
   double ascent, descent;
   bool textChanged, angleChanged;

   string formatLT(double lt)
   {
      scope auto w = appender!string();
      formattedWrite(w, "%1.1f", lt);
      return w.data;
   }

   override void syncControls()
   {
      cSet.setLineWidth(olt);
      cSet.setTextParams(alignment, pfd.toString());
      cSet.toggling(false);
      if (!angleFixed) cSet.enable(Purpose.MOL, 1);
      cSet.setToggle(Purpose.OUTLINE, outline);
      toggleView();
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

      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy;
      altColor = other.altColor.copy;
      pfd = other.pfd.copy();
      fill = other.fill;
      outline = other.outline;
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
      textChanged = true;
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Fancy Text "~to!string(++nextOid);
      super(w, parent, s, AC_FANCYTEXT);
      aw = w;
      olt = 0.2;
      altColor = new RGBA(0,0,0,1);
      fill = false;
      angle = 0.0;
      angleFixed = true;
      tm = new Matrix(&tmData);

      int vp = rpTm+height+85;
      int tvp = vp;
      setupControls(1);
      outline = true;
      cSet.setLineWidth(olt);
      positionControls(true);
   }

   override void extendControls()
   {
      int vp = cSet.cy;
      int tvp = vp;

      Label l = new Label("Orientation");
      cSet.add(l, ICoord(0, vp+3), Purpose.LABEL);

      vp += 22;
      TextOrient to = new TextOrient(cSet, 0, ICoord(0, vp), false);

      l = new Label("Outline\nthickness");
      cSet.add(l, ICoord(167, tvp+3), Purpose.LABEL);
      MOLLineThick mlt = new MOLLineThick(cSet, 0, ICoord(240, tvp+5), false);


      vp += 45;
      l = new Label("Angle");
      cSet.add(l, ICoord(0, vp), Purpose.LABEL);
      new MoreLess(cSet, 1, ICoord(60, vp), false);

      vp += 20;

      new InchTool(cSet, 0, ICoord(0, vp), false);

      vp += 35;
      CheckButton check = new CheckButton("Outline");
      check.setActive(1);
      cSet.add(check, ICoord(0, vp+2), Purpose.OUTLINE);

      fillType = new Label("(N)");
      cSet.add(fillType, ICoord(98, vp+4), Purpose.FILLTYPE);

      fillOptions = new ComboBoxText(false);
      fillOptions.appendText("Choose Fill Type");
      fillOptions.appendText("Color");
      fillOptions.appendText("None");
      fillOptions.appendText("Refresh Options");
      getFillOptions(this);
      fillOptions.setActive(0);
      cSet.add(fillOptions, ICoord(120, vp-5), Purpose.FILLOPTIONS);

      cSet.cy = vp+30;
   }

   override void afterDeserialize()
   {
      textBlock.setAlignment(cast(PangoAlignment) alignment);
      te.modifyFont(pfd);
      te.overrideColor(te.getStateFlags(), baseColor);
      if (editMode)
         cSet.setInfo("Edit mode: Modify the text as required.");
      else
         cSet.setInfo("Design mode: Set parameters for the layer.");
      toggleView();
      dirty = true;
   }

   override void deserializeComplete()
   {
      if (fillType is null)
         return;
      updateFillOptions(this);
      updateFillUI();
   }

   override void preResize(int oldW, int oldH)
   {
      lastHo = double.min_normal, lastVo = double.max;
      double vr = cast(double) width/oldW;
      double hr = cast(double) width/oldW;
      hOff *= hr;
      vOff *= vr;
   }

   override void bufferChanged(TextBuffer b)
   {
      aw.dirty = true;
      textChanged = true;
   }

   override bool specificNotify(Widget w, Purpose wid)
   {
      switch (wid)
      {
      case Purpose.FILLCOLOR:
         setColor(true);
         break;
      case Purpose.OUTLINE:
         outline = !outline;
         break;
      case Purpose.FILLOPTIONS:
         int n = fillOptions.getActive();
         if (n == 0)
            return false;
         if (n == 1)
         {
            lastOp = push!RGBA(this, altColor, OP_ALTCOLOR);
            setColor(true);
            fillFromPattern = false;
            fill = true;
            fillType.setText("(C)");
         }
         else if (n == 2)
         {
            fillFromPattern = false;
            fill = false;
            fillType.setText("(N)");
         }
         else if (n == 3)
         {
            updateFillOptions(this);
            fillOptions.setActive(0);
            return false;
         }
         else
         {
            fillFromPattern = true;
            fillUid = others[n-4];
            fill = true;
            fillType.setText("(P)");
         }
         fillOptions.setActive(0);
         updateFillUI();
         break;
      default:
         return false;
      }
      return true;
   }

   override void onCSLineWidth(double lw)
   {
      olt = lw;
      aw.dirty = true;
      reDraw();
   }

   override void onCSMoreLess(int instance, bool more, bool far)
   {
      int direction = more? 1: -1;
      if (instance == 0)
      {
         adjustFontSize(direction, far);
         textChanged = true;
      }
      else if (instance == 1)
      {
         double ra = far? rads*5: rads/3;
         if (more)
            ra = -ra;
         //lastOp = pushC!Transform(this, tf, OP_ROT);
         angle -= ra;
      }
      else
         return;
      aw.dirty = true;
      reDraw();
   }

   override void setOrientation(int o)
   {
      orientation = o;
      angleChanged = true;
      switch (orientation)
      {
         case 0:
            angle = 0.0;
            break;
         case 1:
            angle = 3*PI/2;
            break;
         case 2:
            angle = PI;
            break;
         case 3:
            angle = PI/2;
            break;
         default:
            angle = 7*PI/4;
            angleFixed = false;
            cSet.enable(Purpose.MOL, 1);
            return;
      }
      angleFixed = false;
      cSet.disable(Purpose.MOL, 1);
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
         edButton.setLabel("Edit Text");
         string txt=tb.getText();
         if (txt.length)
         {
            string[] a = split(txt, "\n");
            txt = a[0];
            if (txt.length > 20)
               txt = txt[0..17] ~ "...";
            setName(txt);
         }
         da.show();
      }
      aw.dirty = true;
   }

   void transformEachPath()
   {
      CairoPathData* data;
      if (angle != 0)
         tm.initRotate(angle);

      void rotate(int n)
      {
         for (int i = 1; i < n; i++)  // First item in a CairoPathData sequence is the header
         {
            if (angle != 0)
               tm.transformPoint(data[i].point.x, data[i].point.y);
            data[i].point.x += hOff;
            data[i].point.y += vOff;
         }
      }

      for (int i = 0; i < pathCopy.numData; i += pathCopy.data[i].header.length)
      {
         data = &pathCopy.data[i];
         switch (data.header.type)
         {
         case cairo_path_data_type_t.MOVE_TO:
         case cairo_path_data_type_t.LINE_TO:
            rotate(2);
            break;
         case cairo_path_data_type_t.CURVE_TO:
            rotate(4);
            break;
         case cairo_path_data_type_t.CLOSE_PATH:
            break;
         default:
            break;
         }
      }
   }

   void getTextPath(string text, Context c)
   {
      scope Surface surface = c.getTarget().createSimilar(cairo_content_t.COLOR_ALPHA, width, height);
      scope Context tc = c.create(surface);
      PgLayout pgl = PgCairo.createLayout(tc);
      pgl.setSpacing(0);
      pgl.setFontDescription(pfd);
      pgl.setText(text);
      PgCairo.layoutPath(tc, pgl);
      tc.strokePreserve();
      tPath = cast(CairoPath*) tc.copyPath();
   }

   override void render(Context c)
   {
      string text = tb.getText();
      if (!text.length)
         return;
      c.save();
      c.newPath();
      c.translate(hOff+0.5*width, vOff+0.5*height);
      c.rotate(angle);
      c.translate(-lpX-0.5*width, -lpY-0.5*height);
      PgLayout pgl = PgCairo.createLayout(c);
      pgl.setText(text);
      pgl.setAlignment(cast(PangoAlignment) alignment);
      pgl.setFontDescription(pfd);
      PangoRectangle pr;
      pgl.getExtents(null, &pr);
      c.moveTo(lpX+0.5*width-pr.width/2048, lpY+.5*height-pr.height/2048);
      PgCairo.layoutPath(c, pgl);
      strokeAndFill(c, olt, outline, fill);
      c.restore();
   }
}
