//          Copyright Steve Teale 2013.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language

module tb2pm;

import types;

import std.stdio;
import std.string;
import std.array;
import std.format;
import std.conv;
import gtk.TextBuffer;
import gtk.TextIter;
import gtk.TextTag;
import gdk.Color;
import pango.PgAttribute;
import glib.ListSG;
import gobject.ObjectG;
import gobject.Type;
import gobject.Value;
import gobject.ParamSpec;
import cairo.Context;

import pango.PgCairo;
import pango.PgLayout;
import pango.PgAttribute;
import pango.PgAttributeList;
import pango.PgFontDescription;


/**********************************************************
Takes account of the following TextTag properties only
font
foreground
rise
scale
size
stretch
style
weight
***********************************************************/

enum PType
{
   INT,
   STRING,
   DOUBLE,
   COLOR,
   VOID
}

struct TagProperty
{
   string name;
   int priority;
   PType type;
   union
   {
      string stringv;
      int intv;
      double doublev;
   }
}

struct Fragment
{
   string text;
   TagProperty[string] props;
}

struct PropertyDescription
{
   string name;
   PType type;
   string condition;
}

class TB2PM
{
   static immutable(PropertyDescription)[8] pda = [
      PropertyDescription("font", PType.STRING, ""),
      PropertyDescription("foreground-gdk", PType.COLOR, "foreground-set"),
      PropertyDescription("rise", PType.INT, "rise-set"),
      PropertyDescription("scale", PType.DOUBLE, "scale-set"),
      PropertyDescription("size", PType.INT, "size-set"),
      PropertyDescription("stretch", PType.INT, "stretch-set"),
      PropertyDescription("style", PType.INT, "style-set"),
      PropertyDescription("weight", PType.INT, "weight-set") ];

   TextBuffer tb;
   Fragment[] fa;

   this(TextBuffer b)
   {
      tb = b;
   }
   /*********************************************************************************
   ListSG had me screwed up for some time. It is not really a class representing a
   linked list, but a struct representing an SLL node. sll.next() does not make the
   next data available, it simply returns a pointer to the next node, or null.
   RTFM Steve ;=(
   **********************************************************************************/
   private static TextTag[] getTagArray(TextIter ti)
   {
      TextTag[] tta;
      tta.length = 0;
      ListSG sll = ti.getTags();
      if (sll is null)
         return tta;
      TextTag t;
      for (;;)
      {
         t = new TextTag(cast(GtkTextTag*) sll.data);
         tta ~= t;
         sll = sll.next();
         if (sll is null)
            break;
      }
      return tta;
   }

/********************************************************************************
I use the name getValidProperty because it seems there is no way to get a list of
the property names associated with the tag. The inplication would be that all TextTags
have all properties.

Instead, there are 'shadow' property names. Property xxx will be accompanied by
property xxx-set, which latter I take as an inicator the the value of xxx should be
taken seriously, as opposed to being accidental.
*********************************************************************************/
   private static void getValidProperty(int propID, TextTag tt, TagProperty* tpp)
   {
      PropertyDescription pd = pda[propID];
      scope Value vc = new Value();
      scope Value v = new Value();
      int cv;
      if (pd.condition.length)   // There's an xxx-set property
      {
         vc.init(GType.INT);
         try {
            tt.getProperty(pd.condition, vc);
         } catch {
         }
         if (!vc.getInt())   // not set
         {
            // Mark the text property as being undefined
            tpp.type = PType.VOID;
            return;
         }
      }
      if (pd.type == PType.INT)
         v.init(GType.INT);
      else if (pd.type == PType.STRING)
         v.init(GType.STRING);
      else if (pd.type == PType.DOUBLE)
         v.init(GType.DOUBLE);
      else if (pd.type == PType.COLOR)
         v.init(Type.fromName("GdkColor"));
      else
      {
         // play safe
         tpp.type = PType.VOID;
         return;
      }
      try {
         tt.getProperty(pd.name, v);
      } catch {
      }
      tpp.name = pd.name;
      tpp.type = pd.type;

      if (pd.type == PType.INT)
         tpp.intv = v.getInt();
      else if (pd.type == PType.STRING)
      {
         tpp.stringv = v.getString();
      }
      else if (pd.type == PType.DOUBLE)
         tpp.doublev = v.getDouble();
      else
      {
         // Some fudging required here. In the property list there is foreground, marked as WRITE
         // and foreground-gdk thatis READ/WRITE. I want a string like "#aabb55" not a GdkColor
         // So we get a GdkColor, then convert it and rewrite the property name and type.
         // This would need modification if we wanted background as well, but I don't usually
         // need that - background color can be set on the DrawingArea.
         GdkColor* pc = cast(GdkColor*) v.getBoxed();
         auto writer = appender!string();
         formattedWrite(writer, "#%02x%02x%02x", pc.red >> 8, pc.green >> 8, pc.blue >> 8);
         tpp.stringv = writer.data;
         tpp.type = PType.STRING;
         tpp.name = "foreground";
         tpp.type = PType.STRING;
      }
   }

   private static TagProperty[] getPropArray(TextTag tt)
   {
      TagProperty[] tpa;
      TagProperty tp;

      for (int i = 0; i < pda.length; i++)
      {
         getValidProperty(i, tt, &tp);
         // Throw away the invalid ones
         if (tp.type == PType.VOID)
            continue;
         tpa ~= tp;
      }
      return tpa;
   }

   private static TagProperty[string] getCompositePropArray(TextTag[] tta)
   {
      TagProperty[string] tpassoc;
      foreach (int i, ref TextTag tt; tta)
      {
         TagProperty[] tpa = getPropArray(tt);
         foreach (TagProperty prop; tpa)
         {
            TagProperty* p = (prop.name in tpassoc);
            if (p is null)
               tpassoc[prop.name] = prop;
            else
            {
               if (p.priority < prop.priority)
                  tpassoc[prop.name] = prop;
            }
         }
      }
      return tpassoc;
   }

   void decodeTextTags()
   {
      TextIter end = new TextIter();
      TextIter cp = new TextIter();
      TextIter follower = new TextIter();
      tb.getIterAtOffset(cp, 0);
      tb.getIterAtOffset(follower, 0);
      tb.getBounds(cp, end);
      int endoff = end.getOffset();

      for (;;)
      {
         Fragment f;
         TextTag[] tta = getTagArray(cp);
         if (tta.length)          // Tag or tags in effect at cp
            f.props = getCompositePropArray(tta);
         if (!cp.forwardToTagToggle(null))
         {
            // No more tags - cp at end of buffer
            f.text = tb.getText(follower, cp, 0);
            fa ~= f;
            break;
         }
         else
         {
            // There are more tags.
            f.text = tb.getText(follower, cp, 0);
            // Move up follower to position of cp
            follower = cp.copy();
            fa ~= f;
            // There can be a tag in force at the point one beyond EOT
            if (cp.getOffset() >= endoff)
               break;
         }
      }
   }

   string encodeMarkup()
   {
      string markup = "";
      foreach (Fragment f; fa)
      {
         if (!f.props.length)
         {
            markup ~= f.text;
            continue;
         }
         auto writer = appender!string();
         formattedWrite(writer, "<span ");
         foreach  (string s, TagProperty tp; f.props)
         {
            if (tp.name == "font" && tp.stringv=="Normal")
               continue;
            formattedWrite(writer, "%s=\"", tp.name);
            if (tp.type == PType.STRING)
               formattedWrite(writer, "%s\" ", tp.stringv);
            else if (tp.type == PType.INT)
               formattedWrite(writer, "%d\" ", tp.intv);
            else if (tp.type == PType.DOUBLE)
               formattedWrite(writer, "%f\" ", tp.doublev);
         }
         formattedWrite(writer, ">%s</span>", f.text);
         markup ~= writer.data;
      }
      return markup;
   }
}

class TextBlock
{
    Context ctx;
    PgLayout pgLayout;
    PangoAlignment alignment;
    PgFontDescription pgfd;
    string text;
    bool instantiated;


    this(string t)
    {
       text = t;
       alignment = PangoAlignment.LEFT;
    }

    void instantiate(Context c)
    {
       ctx = c;
       pgLayout = PgCairo.createLayout(ctx);
       pgLayout.setAlignment(alignment);
       if (pgfd)
          pgLayout.setFontDescription(pgfd);
       PgAttributeList pgal = new PgAttributeList();
       string plaintext;
       if (PgAttribute.parseMarkup (text, text.length, 0, pgal, plaintext, null))
       {
          instantiated = true;
          pgLayout.setText(plaintext);
          pgLayout.setAttributes(pgal);
       }
       else
          pgLayout.setText("Bad markup");
    }

    PangoRectangle getExtent()
    {
       PangoRectangle pr;
       pgLayout.getExtents(null, &pr);
       ICoord[] ca;
       return pr;
    }

    void setText(string t)
    {
       text = t;
    }

    void setAlignment(PangoAlignment al)
    {

       alignment = al;
    }

    void setFont(string fs)
    {
       pgfd = PgFontDescription.fromString(fs);
    }

    void setFont(PgFontDescription fd)
    {
       pgfd = fd;
    }

    void render()
    {
       if (instantiated)
          PgCairo.showLayout(ctx, pgLayout);
    }
}

