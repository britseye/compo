
//          Copyright Steve Teale 2011 - 2013.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module svgimage;

import mainwin;
import acomp;
import common;
import constants;
import types;
import controlset;
import rsvgwrap;
import mol;

import std.stdio;
import std.conv;
import std.string;
import std.file;

import gdk.Cairo;
import cairo.Context;
import cairo.Surface;
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

   override void syncControls()
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
      hOff = other.hOff;
      vOff = other.vOff;
      fileName = other.fileName;
      svgData = other.svgData.dup;
      scaleType = other.scaleType;
      scaleX = other.scaleX;
      useFile = other.useFile;
      syncControls();
      svgr = new SVGRenderer(svgData.ptr, svgData.length);
   }

   this(AppWindow w, ACBase parent)
   {
      mixin(initString!SVGImage());
      super(w, parent, sname, AC_SVGIMAGE, ACGroups.SVG, ahdg);

      scaleType = 0;
      scaleX = 1.0;
      useFile = false;
      setupControls();
      positionControls(true);
   }

   override void extendControls()
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

   override bool notifyHandler(Widget w, Purpose p)
   {
      switch (p)
      {
      case Purpose.OPENFILE:
         onCFB();
         focusLayout();
         return true;
      case Purpose.SCALEPROP:
         if ((cast(RadioButton) w).getActive())
         {
            scaleType = 0;
            return true;
         }
         break;
      case Purpose.SCALEFIT:
         if ((cast(RadioButton) w).getActive())
         {
            scaleType = 1;
            return true;
         }
         break;
      case Purpose.SCALENON:
         if ((cast(RadioButton) w).getActive())
         {
            scaleType = 2;
            return true;
         }
         break;
      case Purpose.USEFILE:
         useFile = !useFile;
         break;
      default:
         return false;
      }
      return true;
   }

   override void onCSMoreLess(int id, bool more, bool quickly)
   {
      focusLayout();
      if (scaleType != 0)
         return;
      double result = scaleX;
      if (!molG!double(more, quickly, result, 0.01, 0.1, 1000))
         return;
      lastOp = pushC!double(this, scaleX, OP_DV0);
      scaleX = result;
      aw.dirty = true;
      reDraw();
   }

   override bool undoHandler(CheckPoint cp)
   {
      switch (cp.type)
      {
      case OP_DV0:
         scaleX = cp.dVal;
         break;
      default:
         return false;
      }
      lastOp = OP_UNDEF;
      return true;
   }

   override void preResize(int oldW, int oldH)
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

   override void render(Context c)
   {
      if (fileName is null)
         return;
      c.translate(hOff, vOff);

      // Some jiggery-pokery required here - rsvg does not do a good job
      // rendering directly to the context
      Surface s = c.getTarget().createSimilar(cairo_content_t.COLOR_ALPHA, width, height);
      Context sc = c.create(s);
      sc.setSourceRgba(1,1,1,0);
      sc.paint();

      svgr.setContext(sc);
      svgr.render(cast(double) width, cast(double) height, scaleType, scaleX);

      c.setSourceSurface(s, 0, 0);
      c.paint();
   }
}
