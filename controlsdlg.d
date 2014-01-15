
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module controlsdlg;

import main;
import controlset;
import acomp;
import menus;
import tvitem;

import std.stdio;
import gtk.Widget;
import gtk.Window;
import gtk.Layout;
import gtk.Dialog;
import gtk.VBox;
import gdk.Event;
import gtkc.gobjecttypes;
import glib.Idle;
import gobject.Value;

extern(C) bool teFocusFunc(void* vp)
{
   writeln("teFocusFunc");
   ACBase acb = cast(ACBase) vp;
   if (acb.getGroup()== ACGroups.TEXT)
   {
      TextViewItem tv = (cast(TextViewItem) acb);
      if (tv.editMode)
         tv.te.grabFocus();
      else
         acb.focusLayout();

   }
   else
      acb.focusLayout();
   return true;
}

class ControlsDlg: Dialog
{
   ACBase owner;
   AppWindow aw;
   Layout layout;

   this(ACBase acb)
   {
      //http://developer.gnome.org/gtk/stable/GtkWindow.html#GtkWindow--accept-focus

      ResponseType rta[1] = [ ResponseType.OK ];
      string[1] sa = [ "Close" ];
      super(acb.typeName ~ " Controls", acb.aw, DialogFlags.DESTROY_WITH_PARENT, sa, rta);
      /*
      Value v = new Value();
      v.init(GType.BOOLEAN);
      v.setBoolean(false);
      setProperty("accept-focus", v);
      */
      owner = acb;
      aw = acb.aw;
      addEvents(GdkEventMask.BUTTON_PRESS_MASK | GdkEventMask.BUTTON_RELEASE_MASK);
      addOnDelete(&catchClose);
      addOnResponse(&onResponse);
      addOnSetFocus(&onShow, GConnectFlags.AFTER);
      layout = new Layout(null, null);
      VBox vb = getContentArea();
      vb.packStart(layout, 1, 1, 0);
      layout.show();
      setSizeRequest(350,350);
      setPosition(GtkWindowPosition.POS_NONE);
      int px, py;
      aw.getPosition(px, py);
      move(px+4, py+300);
   }

   void onShow(Widget w, Window win)
   {
      Idle.add(cast(GSourceFunc) &teFocusFunc, cast(void*) owner);
   }

   void setControls(ControlSet cSet)
   {
      cSet.realize(layout);
   }

   void clear(ControlSet cSet)
   {
      layout.doref();
      cSet.unRealize(layout);
   }

   bool catchClose(Event e, Widget w)
   {
      hide();
      return true;
   }

   void onResponse(int n, Dialog d)
   {
      aw.mm.enable(VIEW_CSHOW);
      hide();
   }

   Layout getLayout()
   {
      return layout;
   }
}
