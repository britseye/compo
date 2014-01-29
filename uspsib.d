
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module uspsib;

import mainwin;
import config;
import acomp;
import tvitem;
import common;
import constants;
import types;
import controlset;
import tb2pm;

import std.stdio;
import std.array;
import std.string;
import std.conv;

import glib.Idle;
import gtk.Layout;
import gtk.Frame;
import cairo.Context;
import cairo.Surface;
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
import gtk.PopupBox;

extern(C) int USPS4CB( char *TrackPtr, char *RoutePtr, char *BarPtr);

class USPS : TextViewItem
{
   static int nextOid = 0;
   CheckButton cb1, cb2;
   string[] linetext;
   string font;
   int justification;
   bool shrink2Fit, showData;
   bool gotLines, xlateFailed;
   char[66] strokeData;
   string bcStrokes, bcData;

   override void syncControls()
   {
      cSet.setTextParams(alignment, pfd.toString());
      cSet.toggling(false);
      cSet.setToggle(Purpose.HRDATA, showData);
      if (editMode)
      {
         cSet.setToggle(Purpose.EDITMODE, true);
         toggleView();
      }
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(USPS other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      pfd = other.pfd.copy();
      editMode = other.editMode;
      showData = other.showData;
      syncControls();

      string text = other.tb.getText();
      tb.setText(text);
      dirty = true;
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "USPS Address "~to!string(++nextOid);
      super(w, parent, s, AC_USPS);
      shrink2Fit = showData = true;
      strokeData[0] = '!';
      pfd = PgFontDescription.fromString(aw.config.USPSFont);     // TBD base font from config file
      setupControls();
      positionControls(true);
   }

   override void extendControls()
   {
      int vp = cSet.cy;

      CheckButton cb = new CheckButton("Show human readable barcode data");
      cb.setSensitive(0);
      cb.setActive(1);
      cSet.add(cb, ICoord(0, vp), Purpose.HRDATA);

      vp += 25;

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
      gotLines = false;
      bcStrokes = null;
      aw.dirty = true;
      dirty = true;
   }

   override bool specificNotify(Widget w, Purpose wid)
   {
      switch (wid)
      {
      case Purpose.HRDATA:
         showData = !showData;
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
         cSet.disable(Purpose.HRDATA);
         cSet.disable(Purpose.INCH, 0);
         eframe.show();
         te.grabFocus();
         te.show();
      }
      else
      {
         te.hide();
         eframe.hide();
         cSet.enable(Purpose.HRDATA);
         cSet.enable(Purpose.INCH, 0);
         dframe.show();
         da.show();
      }
      aw.dirty = true;
   }

   void getLines()
   {
      if (gotLines)
         return;
      int [] loffs;
      int[] lims;
      TextBuffer tb = te.getBuffer();
      string s = tb.getText();
      if (!s.length)
      {
         linetext.length = 0;
         return;
      }
      int lines = tb.getLineCount();
      loffs.length = lines;
      lims.length = lines;
      TextIter cp = new TextIter();
      TextIter end = new TextIter();
      TextIter follower = new TextIter();
      tb.getBounds(cp, end);
      // Get an array of offsets marking the lines of text
      loffs[0] = 0;
      int i = 1;
      for (; i < lines; i++)
      {
         int nc = cp.getCharsInLine();
         cp.forwardLine();
         lims[i-1] = cp.getOffset()-1;
         loffs[i] = cp.getOffset();
      }
      lims[lines-1] = end.getOffset();

      linetext.length = lines;
      for (i = 0; i < lines; i++)
      {
         tb.getIterAtOffset(follower, loffs[i]);
         tb.getIterAtOffset(cp, lims[i]);
         linetext[i] = tb.getText(follower, cp, 0);
      }
   }

   string[] splitText()
   {
      string[] rv;
      string first, rest;
      TextBuffer tb = te.getBuffer();
      string s = tb.getText();
      if (!s.length)
      {
         rv.length = 0;
         return rv;
      }
      rv.length = 2;
      int lines = tb.getLineCount();
      if (lines == 1)
      {
         rv[0] = s;
         rv[1] = "";
         return rv;
      }
      TextIter start = new TextIter();
      tb.getIterAtOffset(start, 0);
      TextIter cp = new TextIter();
      tb.getIterAtOffset(cp, 0);
      cp.forwardLine();
      int off = cp.getOffset();
      first = s[0..off];
      rest = s[off..$];
      first = stripRight(first);
      rv[0] = first;
      rv[1] = rest;
      return rv;
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

// 0070290000000000000007840
   string xlateData(string data, char* dest)
   {
      string t = "";
      string route = "";
      string bbde = "Bad barcode data entered";
      if (data.indexOf(',')  >= 0)
      {
         string[] sa = split(data, ",");
         if (sa.length != 5)
            return(bbde~" - wrong number of items in comma separated list, should be 5");
         route = sa[4];
         if (sa[0] == "-")
            t ~= aw.config.USPSBarcodeID;
         else
         {
            if (sa[0].length != 2)
               return(bbde~" - Bar Code identifier part must be 2 digits");
            t ~= sa[0];
         }

         if (sa[1] == "-")
            t ~= aw.config.USPSServiceType;
         else
         {
            if (sa[1].length != 3)
               return(bbde~" - Service Type must be 3 digits");
            t ~= sa[1];
         }

         bool longid = true;     // assume the unwashed masses
         if (sa[2] == "-")
         {
            string id = aw.config.USPSCustomerID;
            if (id.length == 6)
               longid = false;
            t ~= id;
         }
         else
         {
            if (!(sa[2].length == 9 || sa[2].length == 6))
               return(bbde~" - Customer Identifier must be 6 or 9 digits");
            if (sa[2].length == 6)
               longid = false;
            t ~= sa[2];
         }

         if (sa[3] == "-")
         {
            if (longid)
               t ~= "000000";
            else
               t ~= "000000000";
         }
         else
         {
            string tt = sa[3];
            if (longid)
            {
               if (tt.length > 6)
                  return(bbde~" - Serial number is too long");
               while (tt.length < 6)
                  tt = "0"~tt;
               t ~= tt;
            }
            else
            {
               if (tt.length > 9)
                  return(bbde~" - Serial Number is too long");
               while (tt.length < 9)
                  tt = "0"~tt;
               t ~= tt;
            }
         }
      }
      else
      {
         if (data.length > 20)
         {
            t = data[0..20];
            route = data[20..$];
         }
         else
         {
            t = "00702900000000000000";
            route = data;
         }
      }
      string srv = t.idup;
      t ~= "\0";
      if (!(route.length == 5 || route.length == 9 || route.length == 11))
         return("Input routing code must be of length 0, 5, 9, or 11");
      srv ~= route.idup;
      route ~= "\0";

      int rv = USPS4CB(cast (char*) t.ptr, cast(char*) route.ptr, dest);
      if (rv != 0)
      {
         xlateFailed = true;
         switch(rv)
         {
         case 10:
            return "Non-digit character in tracking code";
         case 11:
            return "Second digit of tracking code must be in range 0 - 4";
         case 12:
            return "Input routing code must be of length 0, 5, 9, or 11";
         case 13:
            return "Non-digit character in routing code";
         default:
            return "Internal error";
         }
      }
      return srv.idup;
   }

   ICoord doShrink(Context c, double w, double h)
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
         if (tbw < w && tbh < h)
         {
            rv =ICoord(tbw, tbh);
            break;
         }
      }
      return rv;
   }

   IBCD adjustForTarget(double mmRes)
   {
      IBCD initial;
      initial.barHeight *= mmRes;
      initial.barWidth *= mmRes;
      initial.center *= mmRes;
      initial.spacing *= mmRes;
      initial.shortHeight *= mmRes;
      initial.medHeight *= mmRes;
      initial.c2c *= mmRes;
      initial.width *= mmRes;
      initial.totWidth *= mmRes;
      initial.totHeight *= mmRes;
      initial.tbPadding *= mmRes;
      return initial;
   }

//
// The following are the average values according to the spec (mm)
//
// Full bar height 3.683
// Bar width 0.508
// Spacing 0.6605
// Center to center 1.1633
// Bar code width 75.126
//
// Top/bottom clearance 0.7112
// End clearance 3.175
//
// Overall width 81.476
// Overall height 5.107
//
// Using Pango Layout
// If you disagree with my interpretation of the spec, you should just be able to make changes here
   struct IBCD
   {
      // dimensions in mm
      double barHeight = 3.683;
      double barWidth = 0.508;
      double center = 1.8415;
      double spacing = 0.6605;
      double shortHeight = 1.2192;
      double medHeight = 2.451;
      double c2c = 1.1633;
      double width = 75.126;
      double totWidth = 81.476;
      double totHeight = 5.107;
      double tbPadding = 0.7112;
   }

   override void render(Context c)
   {
      string[] split;
      split = splitText();
      if (!split.length)  // Nothing there
         return;
      if (dirty)
         strokeData[0..$] = '\0';
      if (dirty || strokeData[0] == '\0')
      {
         bcData = split[0];
         bcData = xlateData(bcData, &strokeData[0]);
      }
      bcStrokes = cast(string) strokeData[0..$-1];

      TextBlock ttb= new TextBlock(bcData);
      ttb.setFont(pfd);
      ttb.instantiate(c);
      PangoRectangle prect = ttb.getExtent();
      double hrtw = (cast(double) prect.width)/1024;
      double hrth = (cast(double) prect.height)/1024;

      double mmRes = aw.screenRes;    // Printer?
      IBCD dims = adjustForTarget(mmRes);
      double availableHeight = height-dims.totHeight;
      if (showData)
         availableHeight -= hrth;

      if (dirty)
      {
         textBlock.setText(split[1]);
         textBlock.setFont(pfd);
         dirty = false;
      }
      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);
      textBlock.instantiate(c);
      PgFontDescription oldFont = pfd.copy();

      // Size the text, shinking as required
      PangoRectangle pr = textBlock.getExtent();
      int tbw = pr.width/1024;
      int tbh = pr.height/1024;
      if (tbw > width || tbh > availableHeight)
      {
         ICoord t = doShrink(c, width, availableHeight);
         tbw = t.x;
         tbh = t.y;
      }

      double totalHeight = dims.totHeight+tbh;
      if (showData)
         totalHeight += hrth;
      double tm = 0.5*(height-totalHeight);

      double t = vOff+tm;              // t is the position for the top of the full bars and the ascenders
      if (showData)                    // Make room for the human readable line if required
         t += hrth;
      double b = t+dims.barHeight;     // b is the position for the bottom of the full bars and the descenders
      double mb = t+dims.medHeight;    // mb is the position for the bottom of the short bars and the ascenders
      double mt = mb-dims.shortHeight; // mt is the position for the top of the short bars and the descenders
      double step = dims.c2c;
      double cx = hOff + 0.5*(width-dims.width);

      c.save();
      c.setLineWidth(dims.barWidth);
      foreach (char sc; bcStrokes)
      {
         switch (sc)
         {
         case 'F':
            c.moveTo(cx, t);
            c.lineTo(cx, b);
            break;
         case 'A':
            c.moveTo(cx, t);
            c.lineTo(cx, mb);
            break;
         case 'T':
            c.moveTo(cx, mt);
            c.lineTo(cx, mb);
            break;
         case 'D':
            c.moveTo(cx, mt);
            c.lineTo(cx, b);
            break;
         default:
            continue;
         }
         c.stroke();
         cx += step;
      }
      c.restore;
      cx = 0.5*(width-tbw);
      double cy = b+dims.tbPadding;  // Note that the total height for the barcode includes the minimum padding
      c.moveTo(hOff+cx, vOff-lpY+cy);    // but we double that here so as not to be cramped
      textBlock.render();

      if (showData)
      {
         cx = 0.5*(width-hrtw);
         c.moveTo(hOff+cx, vOff+tm);
         ttb.render();
      }
      if (!isMoved) cSet.setDisplay(0, reportPosition());
   }
}
