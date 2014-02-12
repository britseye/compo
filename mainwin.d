
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module mainwin;

import constants;
import config;
import common;
import sheets;
import menus;
import tree;
import interfaces;
import acomp;
import tvitem;
import container;
import richtext;
import text;
import uspsib;
import line;
import separator;
import bevel;
import circle;
import corners;
import fader;
import lgradient;
import rgradient;
import heart;
import polygon;
import random;
import reference;
import rect;
import regpoly;
import arrow;
import fancytext;
import morphtext;
import pattern;
import partition;
import pixelimage;
import pglayout;
import treeops;
import serialize;
import deserialize;
import printing;
import controlsdlg;
import merger;
import serial;
import svgimage;
import crescent;
import cross;
import polycurve;
import strokeset;
import curve;
import drawing;
import pointset;
import regpc;
import mesh;
import moon;
import triangle;
import brushdabs;
import noise;
import tilings;

import std.stdio;
import std.conv;
import std.file;
import std.datetime;
import std.array;
import std.format;
import std.uuid;

import gobject.ObjectG;
import gobject.Value;
import glib.Idle;
import gtk.Main;
import gtk.Widget;
import gtk.Frame;
import gtk.ScrolledWindow;
import gtk.MainWindow;
import gtk.HBox;
import gtk.VBox;
import gtk.AccelGroup;
import gtk.MenuBar;
import gtk.Menu;
import gtk.MenuItem;
import gtk.MessageDialog;
import gtk.HPaned;
import gtkc.gtktypes;
import gtk.TreeView;
import gtk.TextView;
import gtk.TreeIter;
import gtk.TreePath;
import gtk.Layout;
import gtk.DrawingArea;
import gtk.TextBuffer;
import gtk.TextIter;
import gtk.TextTag;
import gtk.FontSelectionDialog;
import gtk.ColorSelectionDialog;
import gtk.ColorSelection;
import gtk.TreeModelIF;
import gtk.TreeSelection;
import gtk.TreeViewColumn;
import cairo.Context;
import gdk.Event;
import gdk.RGBA;
import gdk.Rectangle;
import pango.PgFontDescription;
import cairo.Surface;
import cairo.Context;
import gdk.Screen;

class AppWindow : MainWindow
{
   COMPOConfig config;
   string versionLoaded;
   Recent recent;
   bool iso;
   MainMenu mm;
   AccelGroup acg;
   double screenRes;    // pixels per mm
   double pageW, pageH;
   double plScaleFactor;
   int screenW, screenH;
   Serializer serializer;
   Deserializer deserializer;
   TreeOps treeOps;
   ACTreeModel      tm;
   TreeModelIF dummy;
   ScrolledWindow lp, rp;
   HPaned hp;
   TreeView tv;
   Layout layout;
   bool treeComplete, controlsFloating, landscape, drawOutlines, drawCropMarks, dirty;
   Menu ctrMenu;
   Menu childMenu;
   Menu singletonMenu;
   Menu rootMenu;
   ACBase cto;
   ACBase cmCtr;
   ACBase cmItem;
   ACBase copy, sourceCtr;
   Container[] refs;
   double cWidth, cHeight, cWidthMM, cHeightMM;
   int rpView;
   string drawingName;

   ControlsPos controlsPos;

   Grid scrapGrid;
   Sheet scrapSheet;
   Sheet currentSheet;
   bool doingLayout;
   PageLayout pageLayout;
   SheetLib sheetLib;
   PrintHandler printHandler;
   Merger merger;
   ContextMenus contextMenus;
   int itemAddContext;

   string cfn, cfd;

   void doCtrAppend()
   {
      dirty = true;
      tm.root.children ~= copy;

      treeOps.notifyInsertion(copy);
      for (int i = 0; i < sourceCtr.children.length; i++)
      {
         ACBase x =cloneItem(sourceCtr.children[i]);
         x.parent = copy;
         copy.children ~= x;
         treeOps.notifyInsertion(x);
      }
      //tv.expandAll();
      tv.queueDraw();
      treeOps.select(copy);
      copy = null;
   }

   ACBase getObjectByUid(UUID uid)
   {
      foreach (ACBase acb; tm.root.children)
      {
         if (acb.uuid == uid)
            return acb;
      }
      return null;
   }

   void setDrawing(string dn) { drawingName = dn; }

   int getItemAddContext() { return itemAddContext; }
   void setItemAddContext(int i) { itemAddContext = i; }

   void insertAppendHandler(MenuItem mi)
   {
      doItemInsert(mi, 0);
   }
   void insertAfterHandler(MenuItem mi)
   {
      doItemInsert(mi, 1);
   }
   void insertBeforeHandler(MenuItem mi)
   {
      doItemInsert(mi, 2);
   }

   int getTypeFromName(string s)
   {
      int nt = -1;
      switch (s)
      {
      case "Plain Text":
         nt = AC_TEXT;
         break;
      case "USPS Address":
         nt = AC_USPS;
         break;
      case "Serial Number":
         nt = AC_SERIAL;
         break;
      case "Rich Text":
         nt = AC_RICHTEXT;
         break;
      case "Fancy Text":
         nt = AC_FANCYTEXT;
         break;
      case "Morphed Text":
         nt = AC_MORPHTEXT;
         break;
      case "Brush Dabs":
         nt = AC_BRUSHDABS;
         break;
      case "Color Tilings":
         nt = AC_TILINGS;
         break;
      case "Line Patterns":
         nt = AC_PATTERN;
         break;
      case "PixelImage":
         nt = AC_PIXBUF;
         break;
      case "Arrow":
         nt = AC_ARROW;
         break;
      case "Bevel":
         nt = AC_BEVEL;
         break;
      case "Circle":
         nt = AC_CIRCLE;
         break;
      case "Curve":
         nt = AC_CURVE;
         break;
      case "Corners":
         nt = AC_CORNERS;
         break;
      case "Crescent":
         nt = AC_CRESCENT;
         break;
      case "Cross":
         nt = AC_CROSS;
         break;
      case "Fader":
         nt = AC_FADER;
         break;
      case "LGradient":
         nt = AC_LGRADIENT;
         break;
      case "RGradient":
         nt = AC_RGRADIENT;
         break;
      case "Moon":
         nt = AC_MOON;
         break;
      case "Noise":
         nt = AC_NOISE;
         break;
      case "Heart":
         nt = AC_HEART;
         break;
      case "Line":
         nt = AC_LINE;
         break;
      case "Partition":
         nt = AC_PARTITION;
         break;
      case "PointSet":
         nt = AC_POINTSET;
         break;
      case "Polygon":
         nt = AC_POLYGON;
         break;
      case "Polycurve":
         nt = AC_POLYCURVE;
         break;
      case "Random Patterns":
         nt = AC_RANDOM;
         break;
      case "Rectangle":
         nt = AC_RECT;
         break;
      case "Regular Polygon":
         nt = AC_REGPOLYGON;
         break;
      case "Regular Polycurve":
         nt = AC_REGPOLYCURVE;
         break;
      case "Separator":
         nt = AC_SEPARATOR;
         break;
      case "SVGImage":
         nt = AC_SVGIMAGE;
         break;
      case "Reference":
         nt = AC_REFERENCE;
         break;
      case "StrokeSet":
         nt = AC_STROKESET;
         break;
      case "Drawing":
         nt = AC_DRAWING;
         break;
      case "Mesh Patterns":
         nt = AC_MESH;
         break;
      case "Triangle":
         nt = AC_TRIANGLE;
         break;
      default:
         break;
      }
      return nt;
   }

   void doItemInsert(MenuItem mi, int where, ACBase newItem = null)
   {
      bool inCtr = false;
      dirty = true;
      ACBase ni;
      uint nt;
      string label = "";
      if (mi !is null)
         label = mi.getLabel();
      nt = getTypeFromName(label);
      if (newItem !is null)
         ni = newItem;
      else
      {
         if (cmItem.type == AC_ROOT)  // Standalone item
         {
            ni = createItem(nt, RelTo.ROOT);
         }
         else if (cmCtr !is null)     // Right click on container
         {
            ni = createItem(nt, RelTo.CONTAINER);
         }
         else if (cmItem.parent.type == AC_CONTAINER)
         {
            cmCtr = cmItem.parent;
            ni = createItem(nt, RelTo.CONTAINER);
         }
      }
      if (where == 1)      // after
      {
         ACBase.insertChild(cmItem, ni, true);
      }
      else if (where == 2)  // before
      {
         ACBase.insertChild(cmItem, ni, false);
      }
      else if (where == 0)
      {
         cmCtr.children ~= ni;
      }
      else
      {
         tm.appendRoot(ni);
      }
      if (where != -1)
         treeOps.notifyInsertion(ni);
      // Show new item in rightpane
      switchLayouts(ni, true, true);
      if (ni.parent is tm.root)
         ni.reDraw();
      else
      {
         ni.parent.reDraw();
         treeOps.expand(ni.parent);
      }
      // Now fix up the TreeView
      tv.queueDraw();
      treeOps.select(ni);
   }

   void replaceItem(DeletedItem di)
   {
      dirty = true;
      ACBase ni = di.item;
      int where = to!int(di.lastPos);
      ACBase.insertChildAt(tm.root, ni, where);
      // Show new item in rightpane
      switchLayouts(ni, true, true);
      ni.reDraw();
      // Now fix up the TreeView
      treeOps.notifyInsertion(ni);
      tv.expandAll();
      tv.queueDraw();
      treeOps.select(ni);
   }

   void addContainer()
   {
      dirty = true;
      ACBase nc = new Container(this, tm.root);
      tm.appendRoot(nc);
      treeOps.select(nc);
   }

   void addSingleton(uint type)
   {
      dirty = true;
      ACBase acb = createItem(type, RelTo.ROOT);
      tm.appendRoot(acb);
      treeOps.select(acb);
   }

   void imgSaveHandler(MenuItem mi)
   {
      string label = mi.getLabel();
      if (label == "PixelImage")
      {
         if (cto is null)
            return;
         cto.renderToPNG();
      }
      else if (label == "SVGImage")
      {
         if (cto is null)
            return;
         cto.renderToSVG();
      }
   }

   void ctrMenuHandler(MenuItem mi)
   {
      ACBase ni;
      uint nt;
      string label = mi.getLabel();
      switch (label)
      {
      case "Append item":
         itemAddContext = 0;
         break;
      case "Save Image":
         break;
      case "Make Drawing":
      /*
         Flattener f =new Flattener(this, cmCtr);
         if (!f.valid)
         {
            popupMsg("The items in this container are not\nsuitable for making a Drawing.", MessageType.WARNING);
            return;
         }
         ubyte[] flat = f.flatten();
         Drawing d = new Drawing(this, tm.root, flat);
         doItemInsert(null, -1, d);
         */
         break;
      case "Move up":
         dirty = true;
         ACBase.moveChild(cmItem, true);
         tv.queueDraw();
         break;
      case "Move down":
         dirty = true;
         ACBase.moveChild(cmItem, false);
         tv.queueDraw();
         break;
      case "Add item before":
         itemAddContext = 2;
         break;
      case "Add item after":
      itemAddContext = 1;
         break;
      case "Duplicate":
         ni = cloneItem(cmCtr);
         tm.insertRoot(ni, cmCtr, true);
         switchLayouts(ni, true, true);
         ni.reDraw();
         // Now fix up the TreeView
         tv.queueDraw();
         treeOps.select(ni);
         break;

      case "Cut":
         if (!doCut(cmCtr, true))
            return;
         dirty = true;
         break;
      case "Copy":
         copy = cloneItem(cmCtr);
         sourceCtr = cmCtr;
         break;
      case "Delete":
         if (!doCut(cmCtr, false))
            return;
         dirty = true;
         break;
      case "Paste":
         if (copy is null)
         {
            popupMsg("There is no copied or cut item to paste.", MessageType.INFO);
            return;
         }
         if (copy.type == AC_CONTAINER)
         {
            popupMsg("Can't paste a Container into a Container.\nUse a Reference instead.", MessageType.WARNING);
            return;
         }
         else
         {
            ni = cloneItem(copy);
            // paste the object into this container - we don't know where so just append
            doItemInsert(null, 0, ni);
         }
         break;
      default:
         popupMsg(label, MessageType.ERROR);
      }
   }

   bool doCut(ACBase ci, bool keep)
   {
      TreePath tp = treeOps.getPath(ci);
      if (keep)
         copy = ci;
      ACBase oldCto = cto;
      cto.hideDialogs();
      if (controlsPos == ControlsPos.FLOATING)
         cmItem.controlsDlg.hide();
      ACBase.removeChild(this, ci);
      treeOps.notifyDeletion(tp);
      if (cto !is null && cto != oldCto)
         treeOps.select(cto);
      return true;
   }

   void childMenuHandler(MenuItem mi)
   {
      string label = mi.getLabel();
      switch (label)
      {
      case "Move up":
         dirty = true;
         ACBase.moveChild(cmItem, true);
         tv.queueDraw();
         break;
      case "Move down":
         dirty = true;
         ACBase.moveChild(cmItem, false);
         tv.queueDraw();
         break;
      case "Add item before":
         itemAddContext = 2;
         break;
      case "Add item after":
         itemAddContext = 1;
         break;
      case "Duplicate":
         ACBase t = cloneItem(cmItem);
         doItemInsert(mi, 1, t);
         dirty = true;
         break;
      case "Copy":
         copy = cloneItem(cmItem);
         break;
      case "Cut":
         if (!doCut(cmItem, true))
            return;
         dirty = true;
         break;
      case "Delete":
         if (!doCut(cmItem, false))
            return;
         dirty = true;
         break;
      case "Paste":
         if (copy is null)
         {
            popupMsg("There is no copied or cut item to paste.", MessageType.INFO);
            return;
         }
         if (copy.type == AC_CONTAINER)
         {
            popupMsg("Can't paste a Container into a Container.\nUse a Reference instead.", MessageType.WARNING);
            return;
         }
         else
         {
            ACBase ni = cloneItem(copy);
            doItemInsert(mi, 2, ni);
         }
         break;
      default:
         break;
      }
   }

   void singletonMenuHandler(MenuItem mi)
   {
      string label = mi.getLabel();
      switch (label)
      {
      case "Duplicate":
         ACBase t = cloneItem(cmItem);
         doItemInsert(mi, -1, t);
         dirty = true;
         break;
      case "Copy":
         copy = cloneItem(cmItem);
         break;
      case "Cut":
         if (!doCut(cmItem, true))
            return;
         dirty = true;
         break;
      case "Delete":
         if (!doCut(cmItem, false))
            return;
         dirty = true;
         break;
      default:
         break;
      }
   }

   void rootMenuHandler(MenuItem mi)
   {
      string label = mi.getLabel();
      switch (label)
      {
      case "Append Composition":
         addContainer();
         break;
      case "Append Standalone Item":
         break;
      case "Paste":
         if (copy is null)
         {
            popupMsg("There is no copied or cut item to paste.", MessageType.INFO);
            return;
         }
         ACBase ni = cloneItem(copy);
         doItemInsert(mi, -1, ni);
         break;
      case "Expand All":
         tv.expandAll();
         break;
      case "Collapse All":
         tv.collapseAll();
         break;
      case "Toggle RHS View":
         if (rpView == 1)
            onPageLayout(false);
         else
            onPageLayout(true);
         break;
      case "Fill":
         pageLayout.fill(true);
         break;
      case "Print Immediate":
         printHandler.print(true);
         break;
      default:
         break;
      }
   }

   enum RelTo
   {
      ROOT,
      CONTAINER,
      EXISTING
   }

   ACBase createItem(uint it, RelTo relTo)
   {
      ACBase p;
      if (relTo == RelTo.CONTAINER)
         p = cmCtr;
      else if (relTo == RelTo.EXISTING)
         p = cmItem.parent;
      else
         p = tm.root;
      ACBase ni;
      switch (it)
      {
      case AC_CONTAINER:
         ni = new Container(this, p);
         break;
      case AC_RICHTEXT:
         ni = new RichText(this, p);
         break;
      case AC_FANCYTEXT:
         ni = new FancyText(this, p);
         break;
      case AC_MORPHTEXT:
         ni = new MorphText(this, p);
         break;
      case AC_TEXT:
         ni = new PlainText(this, p);
         break;
      case AC_USPS:
         ni = new USPS(this, p);
         break;
      case AC_SERIAL:
         ni = new Serial(this, p);
         break;
      case AC_BRUSHDABS:
         ni = new BrushDabs(this, p);
         break;
      case AC_PATTERN:
         ni = new Pattern(this, p);
         break;
      case AC_PIXBUF:
         ni = new PixelImage(this, p);
         break;
      case AC_FADER:
         ni = new Fader(this, p);
         break;
      case AC_LGRADIENT:
         ni = new LGradient(this, p);
         break;
      case AC_RGRADIENT:
         ni = new RGradient(this, p);
         break;
      case AC_MOON:
         ni = new Moon(this, p);
         break;
      case AC_NOISE:
         ni = new Noise(this, p);
         break;
      case AC_HEART:
         ni = new Heart(this, p);
         break;
      case AC_LINE:
         ni = new Line(this, p);
         break;
      case AC_REFERENCE:
         ni = new Reference(this, p);
         break;
      case AC_SEPARATOR:
         ni = new Separator(this, p);
         break;
      case AC_BEVEL:
         ni = new Bevel(this, p);
         break;
      case AC_CIRCLE:
         ni = new Circle(this, p);
         break;
      case AC_CURVE:
         ni = new Curve(this, p);
         break;
      case AC_CORNERS:
         ni = new Corners(this, p);
         break;
      case AC_CRESCENT:
         ni = new Crescent(this, p);
         break;
      case AC_CROSS:
         ni = new Cross(this, p);
         break;
      case AC_PARTITION:
         ni = new Partition(this, p);
         break;
      case AC_POINTSET:
         ni = new PointSet(this, p);
         break;
      case AC_POLYGON:
         ni = new Polygon(this, p);
         break;
      case AC_POLYCURVE:
         ni = new Polycurve(this, p);
         break;
      case AC_RANDOM:
         ni = new Random(this, p);
         break;
      case AC_RECT:
         ni = new rect.Rectangle(this, p);
         break;
      case AC_REGPOLYGON:
         ni = new RegularPolygon(this, p);
         break;
      case AC_REGPOLYCURVE:
         ni = new RegularPolycurve(this, p);
         break;
      case AC_ARROW:
         ni = new Arrow(this, p);
         break;
      case AC_SVGIMAGE:
         ni = new SVGImage(this, p);
         break;
      case AC_STROKESET:
         ni = new StrokeSet(this, p);
         break;
      case AC_DRAWING:
         ni = new Drawing(this, p, drawingName);
         break;
      case AC_MESH:
         ni = new Mesh(this, p);
         break;
      case AC_TILINGS:
         ni = new Tilings(this, p);
         break;
      case AC_TRIANGLE:
         ni = new Triangle(this, p);
         break;
      default:
         return null;
      }
      return ni;
   }

   ACBase cloneItem(ACBase x)
   {
      ACBase rv;
      switch (x.type)
      {
      case AC_CONTAINER:
         return new Container(cast(Container) x);
      case AC_RICHTEXT:
         return new RichText(cast(RichText) x);
      case AC_TEXT:
         return new PlainText(cast(PlainText) x);
      case AC_USPS:
         return new USPS(cast(USPS) x);
      case AC_SERIAL:
         return new Serial(cast(Serial) x);
      case AC_BRUSHDABS:
         return new BrushDabs(cast(BrushDabs) x);
      case AC_PATTERN:
         return new Pattern(cast(Pattern) x);
      case AC_PIXBUF:
         return new PixelImage(cast(PixelImage) x);
      case AC_LINE:
         return new Line(cast(Line) x);
      case AC_FANCYTEXT:
         return new FancyText(cast(FancyText) x);
      case AC_MORPHTEXT:
         return new MorphText(cast(MorphText) x);
      case AC_REFERENCE:
         return new Reference(cast(Reference) x);
      case AC_SEPARATOR:
         return new Separator(cast(Separator) x);
      case AC_BEVEL:
         return new Bevel(cast(Bevel) x);
      case AC_CIRCLE:
         return new Circle(cast(Circle) x);
      case AC_CURVE:
         return new Curve(cast(Curve) x);
      case AC_CORNERS:
         return new Corners(cast(Corners) x);
      case AC_CRESCENT:
         return new Crescent(cast(Crescent) x);
      case AC_CROSS:
         return new Cross(cast(Cross) x);
      case AC_FADER:
         return new Fader(cast(Fader) x);
      case AC_LGRADIENT:
         return new LGradient(cast(LGradient) x);
      case AC_RGRADIENT:
         return new RGradient(cast(RGradient) x);
      case AC_MOON:
         return new Moon(cast(Moon) x);
      case AC_NOISE:
         return new Noise(cast(Noise) x);
      case AC_HEART:
         return new Heart(cast(Heart) x);
      case AC_ARROW:
         return new Arrow(cast(Arrow) x);
      case AC_PARTITION:
         return new Partition(cast(Partition) x);
      case AC_POINTSET:
         return new PointSet(cast(PointSet) x);
      case AC_POLYGON:
         return new Polygon(cast(Polygon) x);
      case AC_POLYCURVE:
         return new Polycurve(cast(Polycurve) x);
      case AC_RANDOM:
         return new Random(cast(Random) x);
      case AC_RECT:
         return new rect.Rectangle(cast(rect.Rectangle) x);
      case AC_REGPOLYGON:
         return new RegularPolygon(cast(RegularPolygon) x);
      case AC_REGPOLYCURVE:
         return new RegularPolycurve(cast(RegularPolycurve) x);
      case AC_SVGIMAGE:
         return new SVGImage(cast(SVGImage) x);
      case AC_STROKESET:
         return new StrokeSet(cast(StrokeSet) x);
      case AC_DRAWING:
         return new Drawing(cast(Drawing) x);
      case AC_MESH:
         return new Mesh(cast(Mesh) x);
      case AC_TILINGS:
         return new Tilings(cast(Tilings) x);
      case AC_TRIANGLE:
         return new Triangle(cast(Triangle) x);
      default:
         break;
      }
      return null;
   }

   void popupMsg(string msg, MessageType mt)
   {
      MessageDialog md = new MessageDialog(this, DialogFlags.DESTROY_WITH_PARENT,
                                           mt, ButtonsType.OK, null, null);
      md.setMarkup(msg);
      int rv = md.run();
      md.destroy();
   }

   void onCursorChanged(TreeView ttv)
   {
      if (tm.root.children.length == 0)
         return;
      if (doingLayout)
         return;
      TreePath tp;
      TreeViewColumn tc;
      ttv.getCursor (tp, tc);
      TreeIter tti = new TreeIter();
      tm.getIter(tti, tp);

      if (tp is null)
         return;

      ACBase x = cast(ACBase) tti.userData;
      if (x is cto)
         return;
      x.zapBackground();

      switchLayouts(x, true, true);
   }

   void positionControls(ControlsPos cp)
   {
      if (cp == controlsPos)
         return;
      mm.enable(0x0202+controlsPos);
      controlsPos = cp;
      mm.disable(0x0202+controlsPos);
      ACBase.setControlPositions(tm.root);
   }

   void switchLayouts(ACBase acb, bool setCTO, bool setCS)
   {
      if (acb is cto)
         return;
      if (cto !is null)
      {
         cto.hideDialogs();
         if (cto.usingCD)
            cto.controlsDlg.hide();
      }
      if (setCTO)
         cto = acb;
      if (layout !is null)
      {
         layout.doref();
         rp.remove(layout);
      }
      layout = acb.layout;
      if (acb.usingCD)
      {
         acb.controlsDlg.show();
         onTVSelectionChanged(null);
      }
      if (layout !is null)
      {
         rp.add(layout);
         layout.show();
      }
      if (setCS)
      {
         TreeSelection tso = tv.getSelection();
         tso.addOnChanged(&onTVSelectionChanged, GConnectFlags.AFTER);
      }
   }

   static extern(C) bool idleFunc(void* vp)
   {
      ACBase x = cast(ACBase) vp;
      if (x !is null)
         x.focus();
      return false;
   }

   void setLandscape(bool b)
   {
      landscape = b;
      if (landscape)
         setLandscapeSheet(currentSheet);
      else
         setSheet(currentSheet);
   }


   void newTV(int initType, string sheetName = null)
   {
      cmItem = cmCtr = copy = sourceCtr = null;
      if (sheetName !is null)
      {
         if (sheetName[0..7] == "COMPO: ")
         {
            string ss = sheetName[7..$];
            string[] sa = ss.split(",");
            double w = to!double(sa[0]);
            double h = to!double(sa[1]);
            setScrapSheet(w, h);
         }
         else
         {
            Sheet s = sheetLib.getSheet(sheetName);
            setSheet(s, false);
         }
      }
      treeComplete = false;
      rp.remove(layout);
      lp.remove(tv);
      tv = treeOps.createViewAndModel(initType, cWidth, cHeight);
      tm = treeOps.getModel();
      lp.add(tv);
      treeComplete = true;
      tv.expandAll();
      tv.show();

      if (initType >= 0)
      {
         cto = tm.root.children[0];
         layout = cto.layout;
         layout.doref();
         rp.add(layout);
         layout.show();
         treeOps.select(cto);
      }

      serializer.refresh(this);
      dirty = false;
   }

   ACBase getRenderItem()
   {
      ACBase co = cto;
      if (co.type != AC_CONTAINER)
      {
         if (co.parent.type == AC_CONTAINER)
         {
            co = co.parent;
            (cast(Container) co).surface = null;
         }
         return co;
      }
      (cast(Container) co).surface = null;
      return co;
   }

   Surface renderCtrForPL(ACBase acb, Context c)
   {
      return (cast(Container) acb).renderForPL(c);
   }

   void renderCtrToPL(ACBase ctr, Context c, double xpos, double ypos)
   {
      (cast(Container) ctr).renderToPL(c, xpos, ypos);
   }


   void onPageLayout(bool showit)
   {
      if (showit)
      {
         if (rpView == 1)
            return;
         if (layout !is null)
         {
            layout.doref();
            rp.remove(layout);
         }
         rp.add(pageLayout);
         pageLayout.show();
         mm.enable(VIEW_OBJECT);
         mm.disable(VIEW_LAYOUT);
         rpView = 1;
      }
      else
      {
         if (rpView == 0)
            return;
         pageLayout.doref();
         rp.remove(pageLayout);
         if (layout !is null)
            rp.add(layout);
         mm.enable(VIEW_LAYOUT);
         mm.disable(VIEW_OBJECT);
         rpView = 0;
      }
   }

   void setFileName(string fn)
   {
      if (fn is null)
      {
         setTitle("COMPO - Untitled");
         cfn = null;
      }
      else
      {
         cfn = fn;
         setTitle("COMPO - "~fn);
      }
   }

   void setSheet(Sheet s, bool recurse = true)
   {
      currentSheet = s;
      if (currentSheet.seq)
         mm.disable(FILE_PRINTITEM);
      if (landscape)
         pageLayout.setLandscapeSheet(s);
      else
         pageLayout.setSheet(s);
      pageLayout.queueDraw();
      if (s.seq)
      {
         double w, h;
         getBiggest(s.layout.s, w, h);
         cWidth = w;
         cHeight = h;
      }
      else
      {
         cWidth = s.layout.g.w;
         cHeight = s.layout.g.h;
      }
      if (recurse)
         tm.root.setSizeRecursive(cast(int) cWidth, cast(int) cHeight);
      if (cto !is null)
      {
         cto.zapBackground();
         cto.da.queueDraw();
      }
   }

   void setLandscapeSheet(Sheet s, bool recurse = true)
   {
      pageLayout.setLandscapeSheet(s);
      pageLayout.queueDraw();
      if (s.seq)
      {
         double w, h;
         getBiggest(s.layout.s, w, h);
         cWidth = h;
         cHeight = w;
      }
      else
      {
         cWidth = s.layout.g.h;
         cHeight = s.layout.g.w;
      }
      if (recurse)
         tm.root.setSizeRecursive(cast(int) cWidth, cast(int) cHeight);
      if (cto !is null)
         cto.zapBackground();
      cto.da.queueDraw();
   }

   void setScrapSheet(double w, double h)
   {
      scrapGrid.w = w;
      scrapGrid.h = h;
      scrapSheet.layout.g = Grid(1, 1, w*screenRes, h*screenRes, 10, 10, 0, 0,false);
      setSheet(scrapSheet);
   }

   bool onTreeClick(Event event, Widget t)
   {
      if (event.type == GdkEventType.BUTTON_PRESS)
      {
         int cellX, cellY;
         TreePath tp;
         TreeViewColumn tvc;
         if (!tv.getPathAtPos (cast(int) event.motion.x, cast(int) event.motion.y, tp, tvc, cellX, cellY))
         {
            if (event.button.button == 3)
            {
               rootMenu.popup(3,0);
               return true;
            }
            else
               return false;
         }
         if (event.button.button == 1)
         {
            if (tvc.getTitle() != "Active")
               return false;
            if (tp is null)
               return false;
            TreeIter ti = new TreeIter();
            tm.getIter(ti, tp);
            ACBase x = cast(ACBase)ti.userData;
            x.setOthersInactive();
            tv.queueDraw();
            if (event.motion.x > 10)
               return true;
            return false;
         }
         else if (event.button.button == 3)
         {
            cmCtr = cmItem = null;
            TreeIter ti = new TreeIter();
            tm.getIter(ti, tp);
            ACBase x = cast(ACBase) ti.userData;
            if (x.type == AC_CONTAINER)
            {
               cmCtr = x;
               cmItem = x;
               ctrMenu.popup(3, 0);
            }
            else if (x.parent.type == AC_CONTAINER)
            {
               cmCtr = null;
               cmItem = x;
               childMenu.popup(3, 0);
            }
            else
            {
               // Singleton
               cmCtr = null;
               cmItem = x;
               singletonMenu.popup(3, 0);
            }
            return false;
         }
         else
            return false;
      }
      return false;
   }

   void onTVSelectionChanged(TreeSelection ts)
   {
      if (treeComplete)
         Idle.add(cast(GSourceFunc) &idleFunc, cast(void*) cto);
   }

   int willSave()
   {
      MessageDialog md = new MessageDialog(this, DialogFlags.DESTROY_WITH_PARENT,
                                           MessageType.QUESTION, ButtonsType.NONE, null, null);
      md.addButtons(["_Don't Save", "_Cancel", "_Save"],
                    [ ResponseType.CLOSE, ResponseType.CANCEL,
                      ResponseType.OK ]);
      md.setMarkup("This COMPO document has been changed\ndo you want to save the changes?");
      md.setDefaultResponse (ResponseType.OK );
      int rv = md.run();
      md.destroy();
      return rv;
   }

   void adjustRecent(string fn)
   {
      int pos = -1;
      for (int i = 0; i < 5; i++)
      {
         if (recent.recent[i] == fn)
         {
            pos = i;
            break;
         }
      }
      if (pos < 0)
      {
         string[5] t;
         t[1..$] = recent.recent[0..4];
         t[0] = fn.idup;
         recent.recent[] = (t)[];
         if (recent.count < 5)
            recent.count++;
      }
      else if (pos > 0)
      {
         string t = recent.recent[pos];
         while (pos > 0)
         {
            recent.recent[pos] = recent.recent[pos-1];
            pos--;
         }
         recent.recent[0] = t;
      }
      mm.updateFileMenu();
   }

   override bool windowDelete(Event event, Widget widget)
   {
      writeRecent(recent);
      if (dirty)
      {
         int rv = willSave();
         if (rv == ResponseType.OK)
         {
            bool rv2 = serializer.serialize(false);
            if (!rv2)
               return true;
         }
         else if (rv == ResponseType.CANCEL)
         {
            return true;
         }
      }
      Main.quit();
      return true;
   }

   this()
   {
      super("COMPO - Untitled");
      config = getConfig();
      readRecent(&recent);
      controlsPos = cast(ControlsPos) config.controlsPos;
      scrapGrid = Grid(1, 1, 75, 50, 10, 10, 0, 0, false);
      scrapSheet = Sheet(true, "COMPO", "", "scrap", Category.SPECIAL, Paper.A4, false);
      scrapSheet.layout.g = scrapGrid;

      setDefaultSize(config.width, config.height);
      /*
      Grid tg  = Grid(2, 5, 255.1, 147.4, 0, 0,0,0,0, 42.51, 52.44, 255.1, 147.4, false);
      currentSheet = Sheet(true, "Avery", "7414", "Business Card", Category.BC, Paper.A4, Measure.PT, false);
      currentSheet.layout.g = tg;
      */
      Screen screen = Screen.getDefault();
      screenRes = screen.getResolution();
      screenRes /= 25.4;  // dots per mm
      if (config.iso)
      {
         pageW = 210*screenRes;
         pageH = 297*screenRes;
      }
      else
      {
         pageW = 215.9*screenRes;
         pageH = 279.4*screenRes;
      }
      screenW = screen.getWidth();
      screenW = cast(int) (cast(double) screenW/screenRes);
      screenH = screen.getHeight();
      screenH = cast(int) (cast(double) screenH/screenRes);
      plScaleFactor = 0.8*pageH/screenRes;

      sheetLib = new SheetLib(this, config.iso);
      currentSheet = sheetLib.getSheet(config.iso? config.defaultISOLayout: config.defaultUSLayout);

      cWidth = currentSheet.layout.g.w;
      cHeight = currentSheet.layout.g.h;

      pageLayout= new PageLayout(this);
      pageLayout.setSize(cast(uint) pageW+10, cast(uint) pageH+10);
      pageLayout.doref();
      pageLayout.setSheet(currentSheet);

      VBox vb = new VBox(false, 0);
      add(vb);

      contextMenus = new ContextMenus(this);
      ctrMenu = contextMenus.createCtrContextMenu(&ctrMenuHandler, &imgSaveHandler);
      childMenu = contextMenus.createChildContextMenu(&childMenuHandler);
      singletonMenu = contextMenus.createSingletonContextMenu(&singletonMenuHandler);
      rootMenu = contextMenus.createRootContextMenu(&rootMenuHandler);

      acg = new AccelGroup();
      addAccelGroup (acg);
      mm = new MainMenu(this, sheetLib);
      mm.disable(FILE_SAVE);
      mm.disable(FILE_SAVEAS);
      mm.disable(FILE_SAVEIMG);
      mm.disable(FILE_PRINT);                               // No printing until something on pgLayout.
      mm.disable(FILE_PRINTIMMEDIATE);
      mm.disable(FILE_PRINTITEM);
      mm.disable(VIEW_OBJECT);                            // Design view is default
      mm.disable(VIEW_CBELOW);                           // default positioning is below.
      mm.disable(VIEW_CSHOW);                            // Not hidden - not even present

      vb.packStart(mm, 0, 0, 0);

      printHandler = new PrintHandler(this);
      merger = new Merger(this);

      lp = new ScrolledWindow(PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
      treeOps = new TreeOps(this);
      tv = treeOps.createViewAndModel(AC_CONTAINER, cWidth, cHeight);
      Value v = new Value();
      v.init(GType.INT);
      v.setInt(5);
      tv.setProperty("margin-left", v);
      cto = tm.root.children[0];
      lp.add(tv);
      tv.expandAll();
      treeComplete = true;
      layout = cto.layout;
      layout.doref();

      rp = new ScrolledWindow(PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
      if (layout !is null)
      {
         rp.add(layout);
         layout.show();
      }
      treeOps.select(cto);


      hp = new HPaned(lp, rp);
      hp.setPosition(250);

      vb.packStart(hp, 1, 1, 0);

      serializer = new Serializer(this);
      deserializer = new Deserializer(this);

      showAll();
      // Setting up the default container will have set this flag,
      // but that should be ignored.
      dirty = false;
   }
}
