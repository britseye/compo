
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module printing;

import mainwin;
import acomp;
import container;
import merger;

import std.stdio;
import cairo.Context;
import gtk.PrintContext;
import gtk.PrintOperation;
import gtk.PrintSettings;
import gtk.PageSetup;
import gtk.PaperSize;
import cairo.Context;

class PrintHandler
{
   AppWindow aw;
   double top, left;
   int pages;
   void delegate(PrintContext pc, int pn, PrintOperation po) dlg;
   Merger merger;
   Context cc;
   bool holdContext;

   this(AppWindow w)
   {
      aw = w;
      dlg = &onDrawPage;
   }

   void onDrawPage(PrintContext pc, int pn, PrintOperation po)
   {
      double rx = pc.getDpiX();
      rx /= 25.4;  // to mm
      double ry = pc.getDpiY();
      ry /= 25.4;
      double hscaling = rx/aw.screenRes;     // pixels to pixels
      double vscaling = ry/aw.screenRes;
      cc = pc.getCairoContext();
      cc.translate(aw.config.printerTrimX*rx, aw.config.printerTrimY*ry);
      cc.scale(hscaling, vscaling);
      aw.pageLayout.renderToPrinter(cc);
   }

   void onMergePage(PrintContext pc, int pn, PrintOperation po)
   {
      merger.fillLayout();

      double rx = pc.getDpiX();
      rx /= 25.4;  // to mm
      double ry = pc.getDpiY();
      ry /= 25.4;
      double hscaling = rx/aw.screenRes;     // pixels to pixels
      double vscaling = ry/aw.screenRes;
      cc.translate(aw.config.printerTrimX*rx, aw.config.printerTrimY*ry);
      cc.scale(hscaling, vscaling);
      aw.pageLayout.renderToPrinter(cc);
   }

   void onDrawTest(PrintContext pc, int pn, PrintOperation po)
   {
      double rx = pc.getDpiX();
      rx /= 25.4;  // to mm
      double ry = pc.getDpiY();
      ry /= 25.4;
      cc = pc.getCairoContext();
      cc.translate(aw.config.printerTrimX*rx, aw.config.printerTrimY*ry);
      cc.scale(1, 1);
      cc.save();
      cc.setLineWidth(0.25);
      cc.setSourceRgb(0,0,0);
      for (int i = 0; i <16; i++)
      {
         cc.moveTo(rx, i*ry);
         cc.lineTo(rx+14*rx, i*ry);
         cc.stroke();
      }
      for (int i = 0; i <16; i++)
      {
         cc.moveTo(i*rx, ry);
         cc.lineTo(i*rx,rx+14*ry);
         cc.stroke();
      }
      /*
      cc.moveTo(2*rx, 12*ry);
      cc.lineTo(2*rx, 2*ry);
      cc.lineTo(12*rx, 2*ry);
      cc.stroke();
      cc.moveTo(4*rx, 14*ry);
      cc.lineTo(4*rx, 4*ry);
      cc.lineTo(14*rx, 4*ry);
      cc.stroke();
      cc.moveTo(6*rx, 16*ry);
      cc.lineTo(6*rx, 6*ry);
      cc.lineTo(16*rx, 6*ry);
      cc.stroke();
      cc.moveTo(8*rx, 18*ry);
      cc.lineTo(8*rx, 8*ry);
      cc.lineTo(18*rx, 8*ry);
      cc.stroke();
      cc.restore();
      */
   }

   void setPages(int n)
   {
      pages = n;
   }
   void setMerger(Merger m, bool hold = false)
   {
      merger = m;
      holdContext = hold;
   }

   void dropContext()
   {
      holdContext = false;
      cc = null;
   }

   void onBegin(PrintContext pc, PrintOperation po)
   {
      po.setNPages(pages);
      if (cc is null)
         cc = pc.getCairoContext();
   }

   void print(bool immediate)
   {
      PrintOperation po = new PrintOperation();
      PageSetup ps = new PageSetup();
      ps.setTopMargin(0, Unit.MM);
      ps.setLeftMargin(0, Unit.MM);
      ps.setOrientation(aw.landscape? PageOrientation.LANDSCAPE: PageOrientation.PORTRAIT);
      string pps = aw.config.iso? "iso_a4_210x297mm": "na_letter_8.5x11in";
      PaperSize psz = new PaperSize(pps);
      ps.setPaperSize(psz);
      po.setDefaultPageSetup(ps);
      po.setEmbedPageSetup(1);
      po.addOnDrawPage(&onDrawPage);
      po.setNPages(1);
      PrintOperationAction action = immediate? PrintOperationAction.PRINT: PrintOperationAction.PRINT_DIALOG;
      po.run(action, aw);
      cc = null;
   }

   void printMerge()
   {
      PrintOperation po = new PrintOperation();
      PageSetup ps = new PageSetup();
      ps.setTopMargin(0, Unit.MM);
      ps.setLeftMargin(0, Unit.MM);
      ps.setOrientation(aw.landscape? PageOrientation.LANDSCAPE: PageOrientation.PORTRAIT);
      string pps = aw.config.iso? "iso_a4_210x297mm": "na_letter_8.5x11in";
      PaperSize psz = new PaperSize(pps);
      ps.setPaperSize(psz);
      po.setDefaultPageSetup(ps);
      po.setEmbedPageSetup(1);
      po.addOnBeginPrint(&onBegin);
      po.addOnDrawPage(&onMergePage);
      po.run(PrintOperationAction.PRINT, aw);
      if (!holdContext)
         cc = null;
   }

   void printAlignment()
   {
      PrintOperation po = new PrintOperation();
      PageSetup ps = new PageSetup();
      ps.setTopMargin(0.0, Unit.MM);
      ps.setLeftMargin(0.0, Unit.MM);
      string pps = aw.config.iso? "iso_a4_210x297mm": "na_letter_8.5x11in";
      PaperSize psz = new PaperSize(pps);
      ps.setPaperSize(psz);
      po.setDefaultPageSetup(ps);
      po.setEmbedPageSetup(1);
      po.addOnDrawPage(&onDrawTest);
      po.setNPages(1);
      PrintOperationAction action = PrintOperationAction.PRINT;
      po.run(action, aw);
   }
}
