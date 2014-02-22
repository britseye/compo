
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

   override void syncControls()
   {
      cSet.setTextParams(alignment, pfd.toString());
      cSet.toggling(false);
      toggleView();
      cSet.toggling(true);
      cSet.setHostName(name);
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
      if (other.fa !is null)
         fa = other.fa[];
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
      tb.addOnApplyTag(&tagApplied);
      lastOp = push!(ubyte[])(this, null, OP_TEXT);
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

   override void pushCheckpoint()
   {
      ubyte[] buf = serialize();
      lastOp = push!(ubyte[])(this, buf, OP_TEXT);
   }

   override void tagApplied(TextTag tt, TextIter  ti1, TextIter ti2, TextBuffer b)
   {
      //pushCheckpoint();
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

   override void undo()
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
         te.queueDraw();
         break;
      case OP_TEXT:
         disableHandlers = true;
         tb.setText("");
         if (cp.ubbuf !is null)
            deserialize(cp.ubbuf);
         disableHandlers = false;
         lastOp = OP_UNDEF;
         te.queueDraw();
         break;
      case OP_MOVE:
         Coord t = cp.coord;
         hOff = t.x;
         vOff = t.y;
         lastOp = OP_UNDEF;
         break;
      default:
         break;
      }
      te.grabFocus();
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
