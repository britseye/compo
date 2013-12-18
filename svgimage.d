
//          Copyright Steve Teale 2011 - 2013.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module svgimage;

import main;
import acomp;
import common;
import constants;
import types;
import controlset;
import rsvgwrap;

import std.stdio;
import std.conv;
import std.string;
import std.file;

import gdk.Cairo;
import cairo.Context;
import gtk.Widget;
import gtk.Label;
import gtk.Button;
import gtk.ToggleButton;
import gtk.RadioButton;
import gtk.CheckButton;
import gtk.FileFilter;
import gtk.FileChooserDialog;

class SVGImage : ACBase
{
   static int nextOid = 0;
   ubyte[] svgData;
   SVGRenderer svgr;
   int scaleType;
   string fileName;
   double scaleX;
   bool useFile, realized;

   void syncControls()
   {
      cSet.toggling(false);
      if (scaleType == 0)
         cSet.setToggle(Purpose.SCALEPROP, true);
      else if (scaleType == 1)
         cSet.setToggle(Purpose.SCALEFIT, true);
      else
         cSet.setToggle(Purpose.SCALENON, true);
      cSet.setToggle(Purpose.USEFILE, useFile);
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(SVGImage other)
   {
      this(other.aw, other.parent);
      fileName = other.fileName;
      scaleType = other.scaleType;
      scaleX = other.scaleX;
      useFile = other.useFile;
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "SVGImage "~to!string(++nextOid);
      super(w, parent, s, AC_SVGIMAGE);
      scaleType = 0;
      scaleX = 1.0;
      useFile = false;
      setupControls();
      positionControls(true);
   }

   void extendControls()
   {
      int vp = cSet.cy;

      Button b = new Button("Choose SVG file");
      cSet.add(b, ICoord(0, vp), Purpose.OPENFILE);

      RadioButton rb1 = new RadioButton("Scale in proportion");
      cSet.add(rb1, ICoord(150, vp), Purpose.SCALEPROP);
      RadioButton rb2 = new RadioButton(rb1, "Scale to fit");
      cSet.add(rb2, ICoord(150, vp+20), Purpose.SCALEFIT);
      rb2 = new RadioButton(rb1, "Do not scale");
      cSet.add(rb2, ICoord(150, vp+40), Purpose.SCALENON);

      vp += 65;
      new InchTool(cSet, 0, ICoord(0, vp-20), true);

      Label l = new Label("Additional scaling");
      l.setTooltipText("Scale larger or smaller - hold down <Ctrl> for faster action");
      cSet.add(l, ICoord(160, vp),Purpose. LABEL);
      new MoreLess(cSet, 0, ICoord(290, vp), true);
      CheckButton cb = new CheckButton("Reference the File");
      cSet.add(cb, ICoord(150, vp+20), Purpose.USEFILE);

      cSet.cy = vp+50;
   }

   void onCSNotify(Widget w, Purpose wid)
   {
      switch (wid)
      {
      case Purpose.OPENFILE:
         onCFB();
         dummy.grabFocus();
         return;
      case Purpose.SCALEPROP:
         if ((cast(RadioButton) w).getActive())
         {
            scaleType = 0;
            return;
         }
         break;
      case Purpose.SCALEFIT:
         if ((cast(RadioButton) w).getActive())
         {
            scaleType = 1;
            return;
         }
         break;
      case Purpose.SCALENON:
         if ((cast(RadioButton) w).getActive())
         {
            scaleType = 2;
            return;
         }
      case Purpose.USEFILE:
         useFile = !useFile;
         break;
      default:
         break;
      }
      reDraw();
   }

   void onCSMoreLess(int id, bool more, bool coarse)
   {
      dummy.grabFocus();
      if (scaleType != 0)
         return;
      lastOp = pushC!double(this, scaleX, OP_SCALE);
      if (lastOp != OP_SCALE)
      {
         lcp.dVal = scaleX;
         lcp.type = lastOp = OP_SCALE;
         pushOp(lcp);
      }
      if (coarse)
      {
         if (more)
            scaleX *= 1.05;
         else
            scaleX *= 0.95;
      }
      else
      {
         if (more)
            scaleX *= 1.01;
         else
            scaleX *= 0.99;
      }

      aw.dirty = true;
      reDraw();
   }


   void undo()
   {
      CheckPoint cp;
      cp = popOp();
      if (cp.type == 0)
         return;
      switch (cp.type)
      {
      case OP_SCALE:
         scaleX = cp.dVal;
         lastOp = OP_UNDEF;
         break;
      case OP_MOVE:
         Coord t = cp.coord;
         hOff = t.x;
         vOff = t.y;
         lastOp = OP_UNDEF;
      default:
         break;
      }
      aw.dirty = true;
      reDraw();
   }

   void preResize(int oldW, int oldH)
   {
      double hr = cast(double) width/oldW;
      double vr = cast(double) height/oldH;
      hOff *= hr;
      vOff *= vr;
   }

   void onCFB()
   {
      FileChooserDialog fcd = new FileChooserDialog("Choose SVG File", aw, FileChooserAction.OPEN);
      FileFilter filter = new FileFilter();
      filter.setName("SVG files");
      filter.addPattern("*.svg");

      fcd.setFilter(filter);
      int response = fcd.run();
      if (response != ResponseType.OK)
      {
         fcd.destroy();
         return;
      }
      fileName = fcd.getFilename();
      fcd.destroy();
      svgData = cast(ubyte[]) std.file.read(fileName);
      svgr = new SVGRenderer(fileName);
      reDraw();
   }

   void render(Context c)
   {
      if (fileName is null)
         return;
      svgr.setContext(c);
      svgr.render(hOff, vOff, cast(double) width, cast(double) height, scaleType, scaleX);
   }
}
