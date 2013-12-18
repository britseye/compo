
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module about;

import std.conv;
import gtk.Dialog;
import gtk.AboutDialog;
import gtk.Version;

class COMPOAbout: AboutDialog
{
   this()
   {
      string gtkver = "GTK+"~to!string(Version.getMajorVersion())~"."~to!string(Version.getMinorVersion());
      addOnResponse(&onResponse);
      setProgramName("COMPO");
      setVersion("2.0 (running with "~gtkver~")");
      setCopyright("Copyright Steve Teale 2011-2013");
      setComments("A rewrite of this graphical composition program for GTK3");
      setLicense("This program is licensed under the terms\nof the Boost License version 3");
      setWebsite("http://britseyeview.com/software/compo");
      setWebsiteLabel("BritsEyeView COMPO page");
   }

   void onResponse(int n, Dialog d)
   {
      destroy();
   }
}
