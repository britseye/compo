
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module main;

import constants;
import config;
import common;
import sheets;
import menus;
import tree;
import acomp;
import tvitem;
import container;
import richtext;
import text;
import uspsib;
import line;
import separator;
import bevel;
import box;
import circle;
import connector;
import corner;
import fader;
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
import picture;
import pglayout;
import treeops;
import serialize;
import deserialize;
import printing;
import controlsdlg;
import merger;
import serial;

import std.stdio;
import std.conv;

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
import gdk.Color;
import gdk.Rectangle;
import pango.PgFontDescription;
import cairo.Surface;
import cairo.Context;
import gdk.Screen;

class AppWindow : MainWindow
{
   COMPOConfig config;
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
   Menu rootMenu;
   ACBase cto;
   ACBase cmCtr;
   ACBase cmItem;
   ACBase copy, sourceCtr;
   Container[] refs;
   double cWidth, cHeight, cWidthMM, cHeightMM;

   ControlsPos controlsPos;

   Grid scrapGrid;
   Sheet scrapSheet;
   Sheet currentSheet;
   bool doingLayout;
   PageLayout pageLayout;
   SheetLib sheetLib;
   PrintHandler printHandler;
   Merger merger;

   string cfn, cfd;

   void setFont()
   {
      dirty = true;
      if (cto.type > AC_RICHTEXT)
         return;
      TextViewItem tvi = cast(TextViewItem) cto;
      FontSelectionDialog fsd = new FontSelectionDialog("Choose a Font");
      fsd.setFontName(tvi.pfd.toString());
      string fname;
      int response = fsd.run();
      if (response != GtkResponseType.GTK_RESPONSE_OK)
      {
         fsd.destroy();
         return;
      }
      fname = fsd.getFontName();
      fsd.destroy();

      TextViewItem item=cast(TextViewItem) cto;
      TextView te = item.te;;
      PgFontDescription pfd;
      switch (cto.type)
      {
         case AC_RICHTEXT:
            {
               TextIter start, end;
               start = new TextIter();
               end = new TextIter();
               TextBuffer tb = te.getBuffer();
               if (tb.getSelectionBounds(start, end))
               {
                  TextTag tt = tb.createTag(null, "font", fname);
                  tb.applyTag(tt, start, end);
                  item.dirty = true;
                  return;
               }
               pfd = PgFontDescription.fromString(fname);
               item.setFont(pfd);
            }
            break;
          case AC_TEXT:
          case AC_SERIAL:
          case AC_USPS:
          case AC_FANCYTEXT:
          case AC_MORPHTEXT:
            pfd = PgFontDescription.fromString(fname);
            item.setFont(pfd);
            break;
          default:
            break;
      }
      te.modifyFont(pfd);
   }

   void setColor(bool alt = false)
   {
      dirty = true;
      Color color = new Color();
      ColorSelectionDialog csd = new ColorSelectionDialog("Choose a Color");
      ColorSelection cs = csd.getColorSelection();
      cs.setCurrentColor(cto.baseColor);
      int response = csd.run();
      if (response != GtkResponseType.GTK_RESPONSE_OK)
      {
         csd.destroy();
         return;
      }
      cs.getCurrentColor(color);
      csd.destroy();

      TextViewItem tvi;
      TextView te;

      switch (cto.type)
      {
         case AC_RICHTEXT:
            {
               tvi = cast(RichText) cto;
               te = tvi.te;
               uint id = RichText.getTagId();
               string tagName = "T" ~ to!string(id);
               TextIter start, end;
               start = new TextIter();
               end = new TextIter();
               TextBuffer tb = te.getBuffer();
               if (tb.getSelectionBounds(start, end))
               {
                  TextTag tt = tb.createTag(tagName, "foreground", color.toString());
                  tb.applyTag(tt, start, end);
                  tvi.dirty = true;
                  return;
               }
            }
            break;
         case AC_TEXT:
            tvi = cast(PlainText) cto;
            te = tvi.te;
            break;
         case AC_USPS:
            tvi = cast(USPS) cto;
            te = tvi.te;
            break;
         case AC_SERIAL:
            tvi = cast(Serial) cto;
            te = tvi.te;
            break;
          case AC_FANCYTEXT:
            tvi = cast(FancyText) cto;
            te = tvi.te;
            break;
          case AC_MORPHTEXT:
            tvi = cast(MorphText) cto;
            te = tvi.te;
            break;
        default:
            if (alt)
               cto.altColor = color;
            else
               cto.baseColor = color;
            cto.reDraw();
            return;
      }
      // text cases
      if (alt)
         cto.altColor = color;
      else
         cto.baseColor = color;
      if (te)
         te.modifyText(GtkStateType.NORMAL, color);
   }

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

   void insertAppendHandler(MenuItem mi) { doItemInsert(mi, 0); }
   void insertAfterHandler(MenuItem mi) { doItemInsert(mi, 1); }
   void insertBeforeHandler(MenuItem mi) { doItemInsert(mi, 2); }

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
         case "Pattern":
            nt = AC_PATTERN;
            break;
         case "Picture":
            nt = AC_PIXBUF;
            break;
         case "Arrow":
            nt = AC_ARROW;
            break;
         case "Bevel":
            nt = AC_BEVEL;
            break;
         case "Box":
            nt = AC_BOX;
            break;
         case "Circle":
            nt = AC_CIRCLE;
            break;
         case "Connector":
            nt = AC_CONNECTOR;
            break;
         case "Corner":
            nt = AC_CORNER;
            break;
         case "Fader":
            nt = AC_FADER;
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
         case "Polygon":
            nt = AC_POLYGON;
            break;
         case "Random":
            nt = AC_RANDOM;
            break;
         case "Rectangle":
            nt = AC_RECT;
            break;
         case "Regular Polygon":
            nt = AC_REGPOLYGON;
            break;
         case "Separator":
            nt = AC_SEPARATOR;
            break;
         case "Reference":
            nt = AC_REFERENCE;
            break;
         default:
            break;
      }
      return nt;
   }

   void doItemInsert(MenuItem mi, int where, ACBase newItem = null)
   {
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
         if (cmCtr !is null)     // Right click on container
            ni = createItem(nt, RelTo.CONTAINER);
         else if (cmItem.parent.type == AC_CONTAINER)
         {
            cmCtr = cmItem.parent;
            ni = createItem(nt, RelTo.CONTAINER);
         }
         else
            ni = createItem(nt, RelTo.ROOT);
      }
      if (where == 1)      // after
      {
         ACBase.insertChild(cmItem, ni, true);
      }
      else if (where == 2)  // before
      {
         ACBase.insertChild(cmItem, ni, false);
      }
      else
      {
         cmCtr.children ~= ni;
      }
      treeOps.notifyInsertion(ni);
      // Show new item in rightpane
      switchLayouts(ni, true, true);
      if (ni.parent is tm.root)
          ni.reDraw();
      else
          ni.parent.reDraw();
      // Now fix up the TreeView
		tv.expandAll();
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

   void ctrMenuHandler(MenuItem mi)
   {
      ACBase ni;
      uint nt;
      string label = mi.getLabel();
      switch (label)
      {
         case "Append item":
            break;
         case "Save Image to PNG":
            {
               if (cto is null)
                  return;
               cto.renderToPNG();
            }
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
            break;
         case "Add item after":
            break;
         case "Duplicate":
            ACBase x = cloneItem(cmCtr);
            doItemInsert(null, 1, x);
            break;

         case "Cut":
            {
               doCut(cmCtr);
               dirty = true;
            }
            break;
         case "Copy":
            copy = cloneItem(cmCtr);
            sourceCtr = cmCtr;
            break;
         /*
         case "Delete":
            {
               dirty = true;
               TreePath tp = treeOps.getPath(cmCtr);
               ACBase oldCto = cto;
               treeOps.pushDeleted(cmCtr, tp);
               if (controlsPos == ControlsPos.FLOATING)
                  cmItem.controlsDlg.hide();
               tm.root.removeChild(this, cmCtr);
               treeOps.notifyDeletion(tp);
               if (cto !is null && cto != oldCto)
                  treeOps.select(cto);
            }
            break;
         */
         case "Paste":
            if (copy is null)
               return;     // nothing to paste
            if (copy.type == AC_CONTAINER)
            {
               ni = cloneItem(copy);
               doItemInsert(null, 2, ni);
            }
            else
            {
               // Adjust parent for new container
               copy.parent = cmCtr;
               // paste the object into this container - we don't know where so just append
               doItemInsert(null, 0, copy);
            }
            break;
         default:
            popupMsg(label, MessageType.ERROR);
      }
   }

   void doCut(ACBase ci)
   {
      TreePath tp = treeOps.getPath(ci);
      copy = ci;
      ACBase oldCto = cto;
      if (controlsPos == ControlsPos.FLOATING)
         cmItem.controlsDlg.hide();
      ACBase.removeChild(this, ci);
      treeOps.notifyDeletion(tp);
      if (cto !is null && cto != oldCto)
         treeOps.select(cto);
   }

   void childMenuHandler(MenuItem mi)
   {
      string label = mi.getLabel();
      switch (label)
      {
         case "Save Image to PNG":
            if (cto !is null)
               cto.renderToPNG();
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
         case "Add layer before":
            break;
         case "Add layer after":
            break;
         case "Duplicate":
            ACBase t = cloneItem(cmItem);
            doItemInsert(mi, 1, t);
            break;
         case "Copy":
            copy = cloneItem(cmItem);
            break;
         case "Cut":
            {
               doCut(cmItem);
               dirty = true;
            }
            break;
         case "Paste":
            if (copy !is null)
            {
               ACBase ni = cloneItem(copy);
               doItemInsert(mi, 2, ni);
            }
            break;
         default:
            break;
      }
   }

   void rootMenuHandler(MenuItem mi)
   {
      childMenuHandler(mi);
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
	      ni = new RichText(this, p, "");
	      break;
	   case AC_FANCYTEXT:
	      ni = new FancyText(this, p, "");
	      break;
	   case AC_MORPHTEXT:
	      ni = new MorphText(this, p, "");
	      break;
	   case AC_TEXT:
	      ni = new PlainText(this, p, "");
	      break;
	   case AC_USPS:
	      ni = new USPS(this, p, "");
	      break;
	   case AC_SERIAL:
	      ni = new Serial(this, p, "");
	      break;
	   case AC_PATTERN:
	      ni = new Pattern(this, p, "");
	      break;
	   case AC_PIXBUF:
	      ni = new Picture(this, p, "");
	      break;
	   case AC_FADER:
	      ni = new Fader(this, p, "");
	      break;
	   case AC_HEART:
	      ni = new Heart(this, p, "");
	      break;
	   case AC_LINE:
	      ni = new Line(this, p, "");
	      break;
	   case AC_REFERENCE:
	      ni = new Reference(this, p, "");
	      break;
	   case AC_SEPARATOR:
	      ni = new Separator(this, p, "");
	      break;
	   case AC_BEVEL:
	      ni = new Bevel(this, p, "");
	      break;
	   case AC_BOX:
	      ni = new Box(this, p, "");
	      break;
	   case AC_CIRCLE:
	      ni = new Circle(this, p, "");
	      break;
	   case AC_CONNECTOR:
	      ni = new Connector(this, p, "");
	      break;
	   case AC_CORNER:
	      ni = new Corner(this, p, "");
	      break;
	   case AC_PARTITION:
	      ni = new Partition(this, p, "");
	      break;
	   case AC_POLYGON:
	      ni = new Polygon(this, p, "");
	      break;
	   case AC_RANDOM:
	      ni = new Random(this, p, "");
	      break;
	   case AC_RECT:
	      ni = new Rect(this, p, "");
	      break;
	   case AC_REGPOLYGON:
	      ni = new RegularPolygon(this, p, "");
	      break;
	   case AC_ARROW:
	      ni = new Arrow(this, p, "");
	      break;
	   default:
	      return null;
	   }
	   ni.setName(ACTypeNames(it)~" "~to!string(ni.oid));
	   return ni;
   }

   ACBase cloneItem(ACBase x)
   {
      ACBase rv;
	   switch (x.type)
	   {
	   case AC_CONTAINER:
	      return new Container(cast(Container) x);
	      break;
	   case AC_RICHTEXT:
	      return new RichText(cast(RichText) x);
	   case AC_TEXT:
	      return new PlainText(cast(PlainText) x);
	   case AC_USPS:
	      return new USPS(cast(USPS) x);
	   case AC_SERIAL:
	      return new Serial(cast(Serial) x);
      case AC_PATTERN:
	      return new Pattern(cast(Pattern) x);
      case AC_PIXBUF:
	      return new Picture(cast(Picture) x);
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
	   case AC_BOX:
	      return new Box(cast(Box) x);
	   case AC_CIRCLE:
	      return new Circle(cast(Circle) x);
	   case AC_CONNECTOR:
	      return new Connector(cast(Connector) x);
	   case AC_CORNER:
	      return new Corner(cast(Corner) x);
	   case AC_FADER:
	      return new Fader(cast(Fader) x);
	   case AC_HEART:
	      return new Heart(cast(Heart) x);
	   case AC_ARROW:
	      return new Arrow(cast(Arrow) x);
	   case AC_PARTITION:
	      return new Partition(cast(Partition) x);
	   case AC_POLYGON:
	      return new Polygon(cast(Polygon) x);
	      break;
	   case AC_RANDOM:
	      return new Random(cast(Random) x);
	      break;
	   case AC_RECT:
	      return new Rect(cast(Rect) x);
	      break;
	   case AC_REGPOLYGON:
	      return new RegularPolygon(cast(RegularPolygon) x);
	      break;
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

	static extern(C) int onTreeSelect(GtkTreeSelection* ts, GtkTreeModel* m, GtkTreePath* p,
	                                  int isSelected, void* userData)
	{
	   AppWindow rtw = cast(AppWindow) userData;
	   if (isSelected)
	   {
	      if (!rtw.doingLayout)
	         return 1;
	   }

	   TreePath tp = new TreePath(p);
	   TreeIter tti = new TreeIter();
	   rtw.tm.getIter(tti, tp);

	   ACBase x = cast(ACBase) tti.userData;
	   //rtw.cto = x;
	   x.zapBackground();

      if (rtw.doingLayout)
         return 1;
      rtw.switchLayouts(x, true, true);
      return 1;
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
	   if (cto !is null && cto.usingCD)
	   {
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
         Sheet s = sheetLib.getSheet(sheetName);
         setSheet(s, false);
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
         if (layout !is null)
         {
            layout.doref();
            rp.remove(layout);
         }
         rp.add(pageLayout);
         pageLayout.show();
         mm.enable(VIEW_OBJECT);
         mm.disable(VIEW_LAYOUT);
	   }
	   else
	   {
	      pageLayout.doref();
	      rp.remove(pageLayout);
         if (layout !is null)
            rp.add(layout);
         mm.enable(VIEW_LAYOUT);
         mm.disable(VIEW_OBJECT);
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
	   scrapSheet.layout.g = Grid(1, 1, w, h, 10, 10, 0, 0,false);
	   setSheet(scrapSheet);
	}

	bool onTreeClick(GdkEventButton* event, Widget t)
	{
      if (event.type == GdkEventType.BUTTON_PRESS)
      {
         if (event.button == 1)
         {
            TreePath tp;
            TreeViewColumn tvc;
            int cellX, cellY;
            if (!tv.getPathAtPos (cast(int) event.x, cast(int) event.y, tp, tvc, cellX, cellY))
               return false;
            if (tvc.getTitle() != "Active")
               return false;
            if (tp is null)
               return false;
            TreeIter ti = new TreeIter();
            tm.getIter(ti, tp);
            ACBase x = cast(ACBase)ti.userData;
            x.setOthersInactive();
            tv.queueDraw();
            if (event.x > 10)
               return true;
            return false;
         }
         else if (event.button == 3)
         {
            TreePath tp;
            TreeViewColumn tvc;
            int cellX, cellY;
            if (!tv.getPathAtPos (cast(int) event.x, cast(int) event.y, tp, tvc, cellX, cellY))
               return false;
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
               cmCtr = null;
               cmItem = x;
               rootMenu.popup(3,0);
            }
            return true;
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
                               [ ResponseType.GTK_RESPONSE_CLOSE, ResponseType.GTK_RESPONSE_CANCEL,
                                  ResponseType.GTK_RESPONSE_OK ]);
      md.setMarkup("This COMPO document has been changed\ndo you want to save the changes?");
      md.setDefaultResponse (ResponseType.GTK_RESPONSE_OK );
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
         recent.recent[] = t;
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

	bool windowDelete(Event event, Widget widget)
	{
	   writeRecent(recent);
      if (dirty)
      {
         int rv = willSave();
         if (rv == ResponseType.GTK_RESPONSE_OK)
         {
            bool rv2 = serializer.serialize(false);
            if (!rv2)
               return true;
         }
         else if (rv == ResponseType.GTK_RESPONSE_CANCEL)
         {
            return true;
         }
      }
      Main.exit(0);
      return false;
	}

	this()
	{
		super("COMPO - Untitled");
		/*
		addOnDelete(&hideOnDelete);
      */
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

	   ctrMenu = createCtrContextMenu(&ctrMenuHandler, &insertAppendHandler, &insertAfterHandler, &insertBeforeHandler);
		childMenu = createChildContextMenu(&childMenuHandler, &insertAfterHandler, &insertBeforeHandler);
		rootMenu = createRootContextMenu(&rootMenuHandler, &insertAfterHandler, &insertBeforeHandler);

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
		hp.setPosition(300);

		vb.packStart(hp, 1, 1, 0);

		serializer = new Serializer(this);
		deserializer = new Deserializer(this);

		showAll();
		// Setting up the default container will have set this flag,
		// but that should be ignored.
		dirty = false;
	}
}

void main (string[] arg)
{
	Main.init(arg);

	new AppWindow();
	Main.run();
}

