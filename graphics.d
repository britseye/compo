
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module graphics;

import acomp;
import main;

import std.stdio;

import gdk.Pixbuf;
import gdkpixbuf.PixbufLoader;
import cairo.ImageSurface;
import gtk.FileChooserDialog;
import gtk.FileFilter;
import cairo.Context;
import cairo.SvgSurface;

void renderPNG(ACBase item)
{
   string fileName = "", folder = "";
   FileChooserDialog fcd = new FileChooserDialog("Save Image to PNG", item.aw, FileChooserAction.SAVE);
   FileFilter filter = new FileFilter();
   filter.setName("PNG files");
   filter.addPattern("*.png");
   fcd.addFilter(filter);
   fcd.setCurrentName(".png");
   fcd.setCurrentFolder(item.aw.recent.lastImageFolder);
   fcd.setDoOverwriteConfirmation (1);
   int response = fcd.run();
   if (response != ResponseType.OK)
   {
      fcd.destroy();
      return;
   }
   fileName = fcd.getFilename();
   folder = fcd.getCurrentFolder();
   item.aw.recent.lastImageFolder = folder;
   fcd.destroy();

   ImageSurface isf = ImageSurface.create(cairo_format_t.ARGB32, item.width, item.height);
   Context isc = Context.create(isf);
   if (item.type != AC_CONTAINER)
   {
      // Make a white background
      isc.rectangle(0, 0, item.width, item.height);
      isc.setSourceRgba(1,1,1,1);
      isc.fill();
   }
   item.render(isc);
   isf.writeToPng(fileName);
}

void renderSVG(ACBase item)
{
   string fileName = "", folder = "";
   FileChooserDialog fcd = new FileChooserDialog("Save Image to SVG", item.aw, FileChooserAction.SAVE);
   FileFilter filter = new FileFilter();
   filter.setName("SVG files");
   filter.addPattern("*.svg");
   fcd.addFilter(filter);
   fcd.setCurrentName(".svg");
   fcd.setCurrentFolder(item.aw.recent.lastImageFolder);
   fcd.setDoOverwriteConfirmation(1);
   int response = fcd.run();
   if (response != ResponseType.OK)
   {
      fcd.destroy();
      return;
   }
   fileName = fcd.getFilename();
   folder = fcd.getCurrentFolder();
   item.aw.recent.lastImageFolder = folder;
   fcd.destroy();
   double w = item.width/item.aw.screenRes*2.83464567, h = item.height/item.aw.screenRes*2.83464567;
   SvgSurface svgs = SvgSurface.create(fileName, w, h);
   Context svgc = Context.create(svgs);
   svgc.scale(w/item.width, h/item.height);
   if (item.type != AC_CONTAINER)
   {
      // Make a white background
      svgc.rectangle(0, 0, item.width, item.height);
      svgc.setSourceRgba(1,1,1,0);
      svgc.fill();
   }
   item.render(svgc);
   svgs.finish();
}

