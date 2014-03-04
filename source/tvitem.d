
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module tvitem;

import acomp;
import mainwin;
import config;
import constants;
import types;
import common;
import controlset;
import controlsdlg;
import tb2pm;
import morphtext;
import richtext;
import mol;

import std.stdio;
import std.conv;
import std.format;
import core.memory;
//import std.variant;
import std.array;

import gtkc.gtktypes;
import gtk.Widget;
import gtk.TextView;
import gtk.TextBuffer;
import gtk.TextTag;
import gtk.TextIter;
import gtk.Button;
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
   string[] teStack;
   string dummy;
   size_t teSP;
   Frame eframe;
   Button edButton;
   double screenRes;
   double fontPoints;
   int alignment, orientation;;
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
      group = ACGroups.TEXT;
      editMode = true;
      if (type != AC_RICHTEXT)
         teStack.length = 20;
      teSP = 0;
      dummy = " ";
      te = new TextView();
      tb = te.getBuffer();
      tb.addOnChanged(&bufferChanged);
      tb.addOnInsertText(&textInsertion);
      tb.addOnDeleteRange(&textDeletion);
      te.setSizeRequest(width, height);
      textBlock = new TextBlock("");
      Screen screen = Screen.getDefault();
      screenRes = screen.getResolution();
      pfd = PgFontDescription.fromString("Sans 10");     // TBD base font from config file
      te.modifyFont(pfd);
      te.setRightMargin(2);
      te.doref();

      eframe = new Frame(te, null);
      eframe.setSizeRequest(width+4, height+4);
      eframe.setShadowType(ShadowType.IN);
      eframe.show();
      layout.put(eframe, rpLm, rpTm);
      te.show();
   }

   override void setupControls(uint flags = 0)
   {
      bool hasAlign = (flags & 1) != 0;
      bool hasStyle = (flags & 2) != 0;
      int vp = cSet.cy;
      tp = new TextParams(cSet, ICoord(0, vp), true, hasAlign, hasStyle);
      vp += 10;
      edButton = new Button("Design");
      edButton.setTooltipText("Click this to switch between text\nediting and design modes.");
      vp += 20;
      cSet.add(edButton, ICoord(0, vp), Purpose.EDITMODE);

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
      if (type != AC_CONTAINER)
      {
         CheckButton cb = new CheckButton("Hide Item");
         cb.setActive(0);
         cSet.add(cb, ICoord(210, cSet.cy), Purpose.HIDE, true);
      }
      cSet.addInfo("Enter the required text in the drawing area,\nand then click the \"Design\"\nbutton to continue.");
   }

   void dgToggleView(Button rb) {}
   void toggleView() {}

   override void onCSNotify(Widget w, Purpose wid)
   {
      switch (wid)
      {
      case Purpose.COLOR:
         lastOp = push!RGBA(this, baseColor, OP_COLOR);
         onCSSaveSelection();
         setColor(false);
         focusLayout();
         break;
      case Purpose.EDITMODE:
         if (editMode)
            cSet.setInfo("Design mode: Set parameters for the layer.");
         else
            cSet.setInfo("Edit mode: Modify the text as required.");
         editMode = !editMode;
         toggleView();
         break;
      default:
         if (!specificNotify(w, wid))
         return;
      }
      aw.dirty = true;
      reDraw();
   }

   void pushTS(string s)
   {
      if (teSP >= 19)
      {
         string[18] t;
         t[] = teStack[2..$];
         teStack[1..19] = t[];
         teStack[19] = s;
      }
      else
         teStack[++teSP] = s;
   }

   string popTS()
   {

      if (teSP == 0)
      {
         aw.popupMsg("Sorry, there are no more items in the undo stack.\nIf you meant to undo some other change\nswitch to design mode and try again.",
                        MessageType.WARNING);
         return dummy;
      }
      return teStack[teSP--];
   }

   override void afterDeserialize()
   {
      if (editMode)
         cSet.setInfo("Edit mode: Modify the text as required.");
      else
         cSet.setInfo("Design mode: Set parameters for the layer.");
      toggleView();
      dirty = true;
   }

   override void resize(int oldW, int oldH)
   {
      te.setSizeRequest(width, height);
      eframe.setSizeRequest(width+4, height+4);
      eframe.queueDraw();
      te.queueDraw();

      commonResize(oldW, oldH);
   }

   void teUndo()
   {
      string s = popTS();
      disableHandlers = true;
      if (s.ptr != dummy.ptr)
         tb.setText(s);
      disableHandlers = false;
      te.queueDraw();
   }

   override void undo()
   {
      if (editMode)
      {
         teUndo();
         return;
      }
      CheckPoint cp;
      cp = popOp();
      if (cp.type == 0)
         return;
      switch (cp.type)
      {
      case OP_NAME:
         name = cp.s;
         nameEntry.setText(name);
         aw.tv.queueDraw();
         lastOp = OP_UNDEF;
         break;
      case OP_FONT:
         pfd = PgFontDescription.fromString(cp.s);
         lastOp = OP_UNDEF;
         te.modifyFont(pfd);
         cSet.setTextParams(alignment, sensibleFontName());
         dirty = true;
         break;
      case OP_COLOR:
         applyColor(cp.color, false);
         lastOp = OP_UNDEF;
         break;
      case OP_MOVE:
         Coord t = cp.coord;
         hOff = t.x;
         vOff = t.y;
         lastOp = OP_UNDEF;
         break;
      case OP_SIZE:
         pfd.setSize(cp.iVal);
         te.modifyFont(pfd);
         cSet.setTextParams(alignment, sensibleFontName());
         break;
      case OP_ALIGN:
         alignment = cp.iVal;
         textBlock.setAlignment(cast(PangoAlignment) alignment);
         dirty = true;
         cSet.setTextParams(alignment, sensibleFontName());
         break;
      case OP_ORIENT:
         orientation = cp.iVal;
         setOrientation(orientation);
         break;
      default:
         if (!specificUndo(cp))
            return;
         break;
      }
      te.grabFocus();
      aw.dirty = true;
      reDraw();
   }

   void textInsertion(TextIter ti, string s, int len, TextBuffer tb)
   {
      if (disableHandlers)
         return;

      // If length > 1 the presumption is that it's a paste.
      // Maybe we should check for 2 or 3 utf8 chars
      if (s.length > 1 || s == " " || s == "\t" || s == "\n")
      {
         pushTS(tb.getText());
      }
   }

   void tagApplied(TextTag tt, TextIter  ti1, TextIter ti2, TextBuffer b)
   {
   }

   void textDeletion(TextIter ti1, TextIter ti2, TextBuffer tb)
   {
      if (disableHandlers)
         return;
      pushTS(tb.getText());
   }

   void bufferChanged(TextBuffer b)
   {
      aw.dirty = true;
      dirty = true;
   }

   override void focus()
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

   string sensibleFontName()
   {
      string family = pfd.getFamily();
      auto writer = appender!string();
      int sz = pfd.getSize();
      double dsz = cast(double) sz/1024.0;
      formattedWrite(writer, "%s %1.2f", family, dsz);
      return writer.data;
   }

   void adjustFontSize(bool more, bool quickly)
   {
      int fs = pfd.getSize();
      double result = fs;
      if (!molG!double(more, quickly, result, 0.01, 0.1, double.infinity))
         return;
      lastOp = pushC!int(this, fs, OP_SIZE);
      fs = to!int(result);
      pfd.setSize(fs);
      te.modifyFont(pfd);
      cSet.setTextParams(alignment, sensibleFontName());
   }

   bool setSelectionAttribute(string property, string value, int type = 0) { return false; }
   void setOrientation(int o) {};

   override void onCSSaveSelection()
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

   void pushCheckpoint() {}

   override void onCSTextParam(Purpose p, string sv, int iv)
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
         pushCheckpoint();
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
         pushCheckpoint();
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

   override void onCSMoreLess(int instance, bool more, bool far)
   {
      if (instance == 0)
      {
         adjustFontSize(more, far);
         aw.dirty = true;
         reDraw();
      }
   }

   double fontSize()
   {
      return (pfd.getSize()/1024) * (screenRes/72.0);
   }
}

