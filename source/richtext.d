
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module richtext;

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
import std.array;

import glib.ListSG;
import gtk.Layout;
import gtk.Frame;
import gtk.DrawingArea;
import cairo.Context;
import cairo.Surface;
import gtk.Widget;
import gtk.Label;
import gtk.Button;
import gtk.TextView;
import gtk.TextBuffer;
import gtk.TextIter;
import gtk.TextTag;
import gtk.TextTagTable;
import gtk.Range;
import gtk.HScale;
import gtk.VScale;
import gtk.ToggleButton;
import gtk.RadioButton;
import gdk.RGBA;
import gobject.ObjectG;
import gobject.Value;
import gtk.Style;
import pango.PgFontDescription;
import gobject.Value;
import gobject.Boxed;
import gobject.Type;
import gtkc.gdktypes;
import gtkc.gobjecttypes;

class RichText : TextViewItem
{
   static int nextOid = 0;
   static uint tagId;
   static GType colorType;
   Fragment[] fa;
   ubyte[][] rtStack;
   size_t rtSP;

   override void syncControls()
   {
      cSet.setTextParams(alignment, pfd.toString());
      cSet.toggling(false);
      toggleView();
      cSet.toggling(true);
      cSet.setHostName(name);
      cSet.setTextParams(alignment, sensibleFontName());
   }

   ubyte[] serialize()
   {
      TextIter start = new TextIter();
      TextIter end = new TextIter();
      tb.getBounds(start, end);
      GdkAtom atom = tb.registerSerializeTagset(null);
      ubyte[] buffer = tb.serialize(tb, atom, start, end);
      return buffer;
   }

   void deserialize(ubyte[] buffer)
   {
      if (buffer.length == 0)
         tb.setText("");
      TextIter start = new TextIter();
      GdkAtom atom = tb.registerDeserializeTagset(null);
      tb.getIterAtOffset(start, 0);
      tb.deserializeSetCanCreateTags (atom, 1);
      tb.deserialize(tb, atom, start, buffer);
   }

   this(RichText other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor= other.baseColor.copy();
      pfd = other.pfd.copy();
      if (other.fa !is null)
         fa = other.fa.dup;
      ubyte[] buffer = other.serialize();
      deserialize(buffer);
      editMode = other.editMode;
      alignment = other.alignment;
      textBlock.setAlignment(cast(PangoAlignment) alignment);
      syncControls();
      dirty = true;
   }

   static uint getTagId()
   {
      return tagId++;
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Rich Text "~to!string(++nextOid);
      super(w, parent, s, AC_RICHTEXT);
      notifyHandlers ~= &RichText.notifyHandler;
      undoHandlers ~= &RichText.undoHandler;

      tb.addOnApplyTag(&tagApplied);
      rtStack.length = 20;
      rtSP = 0;
      alignment = 0;
      setupControls(3);
      positionControls(true);
   }

   override void preResize(int oldW, int oldH)
   {
      double hr = cast(double) width/oldW;
      double vr = cast(double) height/oldH;
      hOff *= hr;
      vOff *= vr;
   }

   override void extendControls()
   {
      int vp = cSet.cy;

      new InchTool(cSet, 0, ICoord(0, vp+8), false);

      cSet.cy = vp+40;
   }

   override bool notifyHandler(Widget w, Purpose p) { return false; }

   override void pushCheckpoint()
   {
      ubyte[] buf = serialize();
      if (rtSP >= 19)
      {
         ubyte[][18] t;
         t[] = rtStack[2..$];
         rtStack[1..19] = t[];
         rtStack[19] = buf;
      }
      else
         rtStack[++rtSP] = buf;
   }

   ubyte[] popRTS()
   {

      if (rtSP == 0)
      {
         aw.popupMsg("Sorry, there are no more items in the undo stack.\nIf you meant to undo some other change\nswitch to design mode and try again.",
                        MessageType.WARNING);
         return null;
      }
      return rtStack[rtSP--];
   }

   override void textInsertion(TextIter ti, string s, int len, TextBuffer tb)
   {
      if (disableHandlers)
         return;

      // If length > 1 the presumption is that it's a paste.
      // Maybe we should check for 2 or 3 utf8 chars
      if (s.length > 1 || s == " " || s == "\t" || s == "\n")
      {
         pushCheckpoint();
      }
   }

   override void textDeletion(TextIter ti1, TextIter ti2, TextBuffer tb)
   {
      if (disableHandlers)
         return;
      pushCheckpoint();
   }

   override bool installColor(RGBA c)
   {
      string sc = RGBA2hex(c);
      if (setSelectionAttribute("foreground", sc, 1))
         return false;

      te.overrideColor(GtkStateFlags.NORMAL, c);
      te.overrideCursor(cursorColor, cursorColor);
      return true;
   }

   void rtUndo()
   {
      ubyte[] a = popRTS();
      if (a is null)
         return;
      disableHandlers = true;
      tb.setText("");
      deserialize(a);
      disableHandlers = false;
      te.queueDraw();
   }

   override bool undoHandler(CheckPoint)
   {
      if (editMode)
      {
         rtUndo();
         te.grabFocus();
         return true;
      }
      return false;
   }

   override void toggleView()
   {
      if (editMode)
      {
         da.hide();
         dframe.hide();
         te.show();
         edButton.setLabel("Design");
         cSet.disable(Purpose.INCH, 0);
         eframe.show();
         te.grabFocus();
         te.show();
      }
      else
      {
         te.hide();
         eframe.hide();
         cSet.enable(Purpose.INCH, 0);
         string txt=tb.getText();
         if (txt.length)
         {
            string[] a = split(txt, "\n");
            txt = a[0];
            if (txt.length > 20)
               txt = txt[0..17] ~ "...";
            setName(txt);
         }
         edButton.setLabel("Edit Text");
         dframe.show();
         da.show();
      }
      aw.dirty = true;
   }

   override bool setSelectionAttribute(string property, string value, int type = 0)
   {
      uint id = getTagId();
      string tagName = property ~ to!string(id);
      if (ssEnd > ssStart)  // There was a selection at the time the font button was clicked
      {
         TextTag tt;
         TextIter start = new TextIter();
         tb.getIterAtOffset(start, ssStart);
         TextIter end = new TextIter();
         tb.getIterAtOffset(end, ssEnd);
         if (property == "")
         {
            tb.removeAllTags(start, end);
            return true;
         }
         switch (type)
         {

            case 1:  // string
               tt = tb.createTag(tagName, property, value);
               break;
            case 2:  // double
               double d = to!double(value);
               tt = tb.createTag(tagName, property, d);
               break;
            case 3:  // This is not used has to be PgFontDescription?
               double d = to!double(value);
               tt = tb.createTag(tagName, property, value);
               break;
            default:  // integer
               int n = to!int(value);
               tt = tb.createTag(tagName, property, n);
               break;
         }
         pushCheckpoint();
         tb.applyTag(tt, start, end);
         ssStart = ssEnd = 0;         // Forget the selection
         dirty = true;
         return true;
      }
      return false;
   }

   override void render(Context c)
   {
      if (dirty)
      {
         TB2PM x = new TB2PM(tb);
         textBlock.setFont(pfd.toString());
         x.decodeTextTags();
         string s = x.encodeMarkup();
         textBlock.setText(s);
         textBlock.setFont(pfd);
         dirty = false;
      }

      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);
      textBlock.instantiate(c);
      c.moveTo(hOff, vOff);
      textBlock.render();
      if (!isMoved) cSet.setDisplay(0, reportPosition());
   }
}
