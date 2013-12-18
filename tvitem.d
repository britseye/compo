
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module tvitem;

import acomp;
import main;
import config;
import constants;
import types;
import common;
import controlset;
import container;
import controlsdlg;
import tb2pm;
import morphtext;
import richtext;

import std.stdio;
import std.conv;
import core.memory;
import std.variant;

import gtkc.gtktypes;
import gtk.Widget;
import gtk.TextView;
import gtk.TextBuffer;
import gtk.TextTag;
import gtk.TextIter;
import gtk.Button;
import gtk.ToggleButton;
import gtk.CheckButton;
import gtk.Label;
import gdk.RGBA;
import gtk.Layout;
import gtk.Frame;
import gdk.Screen;
import gtk.Clipboard;
import pango.PgFontDescription;
import cairo.Context;
import gtkc.cairotypes;
import cairo.Matrix;

struct TBCheckPoint
{
   int type;
   string value;
}

class TextViewItem : ACBase
{
   static RGBA cursorColor;
   TextView te;
   TextBuffer tb;
   TextBlock textBlock;
   TextParams tp;
   PgFontDescription pfd;
   Frame eframe;
   double screenRes;
   double fontPoints;
   int alignment;
   bool disableHandlers;
   bool editMode;
   TextTag colorTag;
   int ssStart, ssEnd;

   static this()
   {
      cursorColor = new RGBA(0,0,0,1);
   }

   this(AppWindow _aw, ACBase _parent, string _name, uint _type)
   {
      super(_aw, _parent, _name, _type);
      editMode = true;

      te = new TextView();
      tb = te.getBuffer();
      tb.addOnChanged(&bufferChanged);
      tb.addOnInsertText(&textInsertion);;
      tb.addOnDeleteRange(&textDeletion);
      te.setSizeRequest(width, height);
      textBlock = new TextBlock("");
      Screen screen = Screen.getDefault();
      screenRes = screen.getResolution();
      pfd = PgFontDescription.fromString("Sans 10");     // TBD base font from config file
      te.modifyFont(pfd);
      te.setRightMargin(2);
      te.doref();
      lastOp=push!string(this, null, OP_TEXT);  // So we can undo back to nothing

      eframe = new Frame(te, null);
      eframe.setSizeRequest(width+4, height+4);
      eframe.setShadowType(ShadowType.IN);
      eframe.show();
      layout.put(eframe, rpLm, rpTm);
      te.show();
   }

   void setupControls(uint flags = 0)
   {
      bool hasAlign = (flags & 1) != 0;
      bool hasStyle = (flags & 2) != 0;
      int vp = cSet.cy;
      tp = new TextParams(cSet, ICoord(0, vp), true, hasAlign, hasStyle);
      vp += 10;
      CheckButton cb = new CheckButton("Edit the Text");
      cb.setTooltipText("Uncheck this to switch to design mode");
      cb.setActive(1);
      vp += 20;
      cSet.add(cb, ICoord(0, vp), Purpose.EDITMODE);

      if (type != AC_MORPHTEXT)
      {
         Label t = new Label("Font size:");
         cSet.add(t, ICoord(168, vp+2), Purpose.LABEL);
         new MoreLess(cSet, 0, ICoord(240, vp+2), true);
      }

      cSet.cy = vp+25;

      extendControls();
      RenameGadget rg = new RenameGadget(cSet, ICoord(2, cSet.cy), name, true);
      rg.setName(name);
   }

   void dgToggleView(ToggleButton rb) {}

   void resize(int oldW, int oldH)
   {
      te.setSizeRequest(width, height);
      eframe.setSizeRequest(width+4, height+4);
      eframe.queueDraw();
      te.queueDraw();

      commonResize(oldW, oldH);
   }

   void undo()
   {
      CheckPoint cp;
      cp = popOp();
      if (cp.type == 0)
         return;
      switch (cp.type)
      {
      case OP_FONT:
         pfd = PgFontDescription.fromString(cp.s);
         lastOp = OP_UNDEF;
         te.modifyFont(pfd);
         break;
      case OP_COLOR:
         applyColor(cp.color, false);
         lastOp = OP_UNDEF;
         break;
      case OP_TEXT:
         disableHandlers = true;
         if (cp.s is null)
            tb.setText("");
         else
            tb.setText(cp.s);
         disableHandlers = false;
         lastOp = OP_UNDEF;
         te.queueDraw();
         break;
      case OP_MOVE:
         Coord t = cp.coord;
         hOff = t.x;
         vOff = t.y;
         lastOp = OP_UNDEF;
      default:
         break;
      }
      te.grabFocus();
      aw.dirty = true;
      reDraw();
   }

   void pushCheckpoint()  // This will be overidden for rich text
   {
      lastOp = push!string(this, tb.getText(), OP_TEXT);
   }

   void textInsertion(TextIter ti, string s, int len, TextBuffer tb)
   {
      if (disableHandlers)
         return;
      // Ensure we can undo back to nothing
      if (tb.getText().length == 0)
      {
         lastOp = push!string(this, null, OP_TEXT);
         return;
      }

      // If length > 1 the presumption is that it's a paste.
      // Maybe we should check for 2 or 3 utf8 chars
      if (s.length > 1 || s == " " || s == "\t" || s == "\n")
      {
         pushCheckpoint();
      }
   }

   void tagApplied(TextTag tt, TextIter  ti1, TextIter ti2, TextBuffer b)
   {
   }

   void textDeletion(TextIter ti1, TextIter ti2, TextBuffer tb)
   {
      if (disableHandlers)
         return;
      string s = tb.getText();
      lastOp = push!string(this, s, OP_TEXT);
   }

   void bufferChanged(TextBuffer b)
   {
      aw.dirty = true;
      dirty = true;
   }

   void focus()
   {
      if (editMode) te.grabFocus();
   }

   void setFont(PgFontDescription fd)
   {
      aw.dirty = true;
      pfd = fd;
   }

   void setCairoFont(Context c, PgFontDescription pfd)
   {
      string face = pfd.getFamily();
      PangoStyle ps = pfd.getStyle();
      cairo_font_slant_t style = (ps == PangoStyle.NORMAL)? cairo_font_slant_t.NORMAL:
                                 cairo_font_slant_t.ITALIC;
      cairo_font_weight_t weight = cairo_font_weight_t.NORMAL;
      double size = pfd.getSize()/1024.0;
      size = (size*screenRes)/72.0;
      c.selectFontFace(face, style, weight);
      c.setFontSize(size);
   }

   void adjustFontSize(int direction, int far)
   {
      if (direction > 0)
      {
         int fs = pfd.getSize();
         if (far)
            fs *= 1.5;
         else
            fs *= 1.05;
         pfd.setSize(fs);
      }
      else
      {
         int fs = pfd.getSize();
         if (far)
            fs *= 0.66;
         else
            fs *= 0.95;
         pfd.setSize(fs);
      }
      te.modifyFont(pfd);
   }

   bool setSelectionAttribute(string property, string value, int type = 0) { return false; }
   void setOrientation(int o) {};

   void onCSSaveSelection()
   {
      TextIter start, end;
      start = new TextIter();
      end = new TextIter();
      if (tb.getSelectionBounds(start, end))
      {
         ssStart = start.getOffset();
         ssEnd = end.getOffset();
         return;
      }
      ssStart = ssEnd = 0;
   }

   void onCSTextParam(Purpose p, string sv, int iv)
   {
      if (p == Purpose.FONT)
      {
         if (setSelectionAttribute("font", sv, 1))
         {
            // SetSelectionAttribute only overridden by AC_RICHTEXT
            dirty = true;
            reDraw();
            te.grabFocus();
            return;
         }
         lastOp = push!string(this, pfd.toString(), OP_FONT);
         pfd = PgFontDescription.fromString(sv);
         te.modifyFont(pfd);
         if (type == AC_MORPHTEXT)
            (cast(MorphText) this).onFontChange();
         dirty = true;
         reDraw();
      }
      else if (p == Purpose.ALIGNMENT)
      {
         if (type == AC_SERIAL || type == AC_MORPHTEXT)
            return;
         lastOp = push!int(this, alignment, OP_ALIGN);
         alignment = iv;
         textBlock.setAlignment(cast(PangoAlignment) iv);
         dirty = true;
         reDraw();
         te.grabFocus();
      }
      else if (p == Purpose.TEXTSTYLES)
      {
         if (type != AC_RICHTEXT)
            return;
         if (sv == "bold")
            setSelectionAttribute("weight", "800");
         else if (sv == "italic")
            setSelectionAttribute("style", "2");
         else
            setSelectionAttribute("", "");
         dirty = true;
         reDraw();
      }
      else if (p == Purpose.TORIENT)
      {
         if (type != AC_FANCYTEXT)
            return;
         setOrientation(iv);
         dirty = true;
         reDraw();
      }
   }

   void onCSMoreLess(int instance, bool more, bool far)
   {
      if (instance == 0)
      {
         int direction = more? 1: -1;
         adjustFontSize(direction, far);
         aw.dirty = true;
         reDraw();
      }
   }

   double fontSize()
   {
      return (pfd.getSize()/1024) * (screenRes/72.0);
   }

   bool installColor()
   {
      if (type == AC_RICHTEXT)
      {
         string sc = RGBA2hex(baseColor);
         RichText rti = cast(RichText) this;
         // This following may cause things to be pushed to undo stacks
         if (rti.setSelectionAttribute("foreground", sc, 1))
            return false;
      }

      te.overrideColor(GtkStateFlags.NORMAL, baseColor);
      te.overrideCursor(cursorColor, cursorColor);
      return true;
   }
}

