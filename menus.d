
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module menus;

import main;
import config;
import treeops;
import acomp;
import tvitem;
import richtext;
import common;
import constants;
import sheets;
import about;
import container;
import pixelimage;
import keyvals;
import merger;
import csv;
import settings;

import std.stdio;
import std.string;
import std.conv;
import gtk.Widget;
import gdk.Pixbuf;
import gdk.Atoms;
import gtk.Main;
import gtk.AccelMap;
import gtk.MenuBar;
import gtk.Menu;
import gtk.MenuItem;
import gtk.CheckMenuItem;
import gtk.SeparatorMenuItem;
import gtk.AboutDialog;
import gtk.Clipboard;
import gtk.Layout;
import gtk.VBox;
import gtk.Dialog;
import gtk.Label;
import gtk.Entry;
import gtk.RadioButton;
import gtk.MountOperation;
import gtkc.gtktypes;

string[] fileNewSa = [ "Layered Composition", "Standalone Items", ];
string[] cmSa = [ "Append item", "Save Image", "Move up", "Move down", "Add item after", "Add item before",
                  "Duplicate", "Cut", "Copy", "Paste"];
string[] imSa = [ "Move up", "Move down", "Add item after", "Add item before", "Duplicate", "Copy", "Cut", "Paste" ];
string[] rootSa = [ "Append Composition", "Append Standalone Item", "Paste", "Toggle RHS View", "Fill", "Print Immediate"];
/*
string[] itemsSa = [ "Plain Text", "USPS Address", "Serial Number", "Rich Text", "Fancy Text", "Morphed Text", "Pattern", "Picture", "Arrow",
                     "Bevel", "Box", "Circle", "Connector", "Corner", "Fader", "LGradient", "RGradient", "Heart", "Line", "Partition",
                     "Polygon", "Random", "Rectangle", "Regular Polygon", "Separator", "Reference" ];

string[] saveimgSa = [ "PNG", "SVG" ];
*/
string[] mfrsSa = [ "Generic", "Avery" ];
string[] allSa = [ "Plain Text", "USPS Address", "Serial Number", "Rich Text", "Fancy Text", "Morphed Text", "Pattern", "PixelImage", "Arrow",
                   "Bevel", "Circle", "Curve", "Connector", "Corner", "Crescent", "Cross", "Fader", "Mesh", "Moon", "LGradient", "RGradient", "Heart", "Line", "Partition",
                   "PointSet", "Polygon", "Polycurve", "Random", "Rectangle", "Regular Polygon", "Separator", "StrokeSet", "Reference", "Triangle", "Container" ];

// All the things that can appear under 'Add/Append Item'
string[] itemsSa = [ "Text", "Effects", "Geometric", "Image", "Reference", "Shapes", "Drawings" ];
string[] txtSa = [ "Plain Text", "USPS Address", "Serial Number", "Rich Text", "Fancy Text", "Morphed Text" ];
string[] effectsSa = [ "Bevel", "Corner", "Fader", "LGradient", "Mesh", "Partition", "Pattern", "Random", "RGradient", "Separator" ];
string[] geoSa = [ "Curve", "Line", "PointSet", "Polygon", "Polycurve", "Regular Polygon", "Regular Polycurve", "StrokeSet"];
string[] shapesSa = [ "Arrow", "Circle", "Crescent", "Cross", "Heart", "Moon", "Rectangle", "Star", "Triangle" ];
string[] imgSa = ["PixelImage", "SVGImage"];
string[] drawingsSa = ["Cat", "Puppy", "Dove", "Fish", "Whale", "Tree"];

Menu createMenu(void delegate(MenuItem) dg, string[] items)
{
   Menu m = new Menu();
   foreach (string s; items)
   {
      MenuItem t;
      if (s == "---")
         t = new SeparatorMenuItem();
      else
         t = new MenuItem(dg, s);
      m.append(t);
   }
   m.showAll();
   return m;
}

class ContextMenus
{
   AppWindow aw;

   this(AppWindow w)
   {
      aw = w;
   }

   void fixupCMItem(MenuItem mi)
   {
      aw.setItemAddContext(-1);
      aw.cmItem = aw.tm.root;
   }

   Menu createCtrContextMenu(void delegate(MenuItem) dg, void delegate(MenuItem) dgi)
   {
      Menu m = new Menu();
      Menu itemsSm = createItemsMenu(false);
      foreach (int i, string s; cmSa)
      {
         MenuItem t = new MenuItem(dg, s);
         m.append(t);
         if (i == 0)
         {
            t.setSubmenu(itemsSm);
         }
         else if (i== 1)
         {
            Menu sm = createMenu(dgi, imgSa);
            t.setSubmenu(sm);
         }
         else if (i == 4)
         {
            t.setSubmenu(itemsSm);
         }
         else if (i == 5)
         {
            t.setSubmenu(itemsSm);
         }
      }
      m.showAll();
      return m;
   }

   Menu createItemsMenu(bool forChild)
   {
      Menu m = new Menu();
      foreach (int i, string s; itemsSa)
      {
         MenuItem t;
         if (forChild)
             t = new MenuItem(&childItemsGroupHandler, s);
         else
            t = new MenuItem(&itemsGroupHandler, s);
         m.append(t);
         switch (i)
         {
            case 0:
               Menu sm = createMenu(&itemsHandler, txtSa);
               t.setSubmenu(sm);
               break;
            case 1:
               Menu sm = createMenu(&itemsHandler, effectsSa);
               t.setSubmenu(sm);
               break;
            case 2:
               Menu sm = createMenu(&itemsHandler, geoSa);
               t.setSubmenu(sm);
               break;
            case 3:
               Menu sm = createMenu(&itemsHandler, imgSa);
               t.setSubmenu(sm);
               break;
            case 4:
               break;
            case 5:
               Menu sm = createMenu(&itemsHandler, shapesSa);
               t.setSubmenu(sm);
               break;
            case 6:
               Menu sm = createMenu(&itemsHandler, drawingsSa);
               t.setSubmenu(sm);
               break;
            default:
               break;
         }
      }
      m.showAll();
      return m;
   }

   void itemsGroupHandler(MenuItem mi)
   {
      string label = mi.getLabel();
      if (label == "Reference")
         aw.doItemInsert(mi, aw.getItemAddContext());
   }

   void childItemsGroupHandler(MenuItem mi)
   {
      string label = mi.getLabel();
      if (label == "Reference")
         aw.doItemInsert(mi, aw.getItemAddContext());
   }

   void itemsHandler(MenuItem mi)
   {
      string label = mi.getLabel();
      switch (label)
      {
         case "Cat":
            aw.popupMsg(label~" is not yet implemented ;=(", MessageType.INFO);
            return;
         case "Dove":
         case "Fish":
         case "Puppy":
         case "Tree":
         case "Whale":
            mi.setLabel("Drawing");
            aw.setDrawing(label);
            aw.doItemInsert(mi, aw.getItemAddContext());
            mi.setLabel(label);
            return;
         case "Star":
            mi.setLabel("Regular Polygon");
            aw.doItemInsert(mi, aw.getItemAddContext());
            string xplain = "To draw a star, use 'Regular Polygon',\ncheck 'Render as Star', and set\n an even number of sides.";
            aw.popupMsg(xplain, MessageType.INFO);
            mi.setLabel(label);
            return;
         default:
            aw.doItemInsert(mi, aw.getItemAddContext());
            break;
      }
   }

   Menu createChildContextMenu(void delegate(MenuItem) dg)
   {
      Menu m = new Menu();
      Menu itemsSm = createItemsMenu(true);
      foreach (int i, string s; imSa)
      {
         MenuItem t = new MenuItem(dg, s);
         m.append(t);
         if (i == 2)
            t.setSubmenu(itemsSm);
         else if (i == 3)
            t.setSubmenu(itemsSm);
      }
      m.showAll();
      return m;
   }

   Menu createRootContextMenu(void delegate(MenuItem) dg)
   {
      Menu m = new Menu();
      Menu itemsSm = createItemsMenu(true);
      foreach (int i, string s; rootSa)
      {
         MenuItem t = new MenuItem(dg, s);
         m.append(t);
         if (i == 1)
         {
            t.addOnActivate(&fixupCMItem);
            t.setSubmenu(itemsSm);
         }
      }
      m.showAll();
      return m;
   }
}

alias MenuItem[] MItems;

enum
{
   FILE_NEW = 0x0000,
   FILE_OPEN,
   FILE_SAVE,
   FILE_SAVEAS,
   FILE_SAVEIMG,
   FILE_PRINT,
   FILE_PRINTIMMEDIATE,
   FILE_PRINTITEM,
   FILE_QUIT,

   EDIT_UNDO  = 0x0100,
   EDIT_COPY,
   EDIT_COPYASIMG,
   EDIT_CUT,
   EDIT_PASTE,
   EDIT_ADDCOMPO,
   EDIT_ADDITEM,
   EDIT_SETTINGS,

   VIEW_OBJECT = 0x0200,
   VIEW_LAYOUT,
   VIEW_CBELOW,
   VIEW_CRIGHT,
   VIEW_CFLOATING,
   VIEW_CSHOW,

   PLACEMENT_FILL = 0x0300,
   PLACEMENT_SEQUENCE,
   PLASEMENT_FILLSEQUENCE,
   PLACEMENT_CLEAR,
   PLACEMENT_OUTLINES,
   PLACEMENT_CROPMARKS,
   PLACEMENT_ALIGN,

   SHEETS_GENERIC,
   SHEETS_USER = 999,
   SHEETS_SCRAP,
   SHEETS_LANDSCAPE,
   SHEETS_DETAIL,
   SHEETS_NEWGDRID,
   SHEETS_NEWSEQUENCE,
   SHEETS_EDITUSER,

   MERGE_SETUP,
   MERGE_PRINTPAGE,
   MERGE_PRINTALL,
   MERGE_DONE,

   HELP_WEB = 0x0500,
   HELP_ABOUT
}

class ScrapDlg: Dialog
{
   Entry eWidth, eHeight;
   RadioButton inches, mm;
   double width;
   double height;
   bool unit;
   Layout layout;

   this(AppWindow w)
   {
      ResponseType rta[2] = [ GtkResponseType.CANCEL, ResponseType.OK ];
      string[2] sa = [ "Cancel", "OK" ];
      super("Size of Scrap", w, DialogFlags.DESTROY_WITH_PARENT, sa, rta);
      addOnResponse(&onResponse);
      setSizeRequest(350, 200);
      layout = new Layout(null, null);
      VBox vb = getContentArea();
      vb.packStart(layout, 1, 1, 0);
      Label l = new Label("A scrap is an arbitrarily sized area in which\nyou can make a composition to create an image");
      layout.put(l, 10, 10);
      l.show();
      l = new Label("Width:");
      layout.put(l, 30, 60);
      l.show();
      eWidth = new Entry();
      layout.put(eWidth, 90, 60);
      eWidth.show();
      l = new Label("Height:");
      layout.put(l, 30, 85);
      l.show();
      eHeight = new Entry();
      layout.put(eHeight, 90, 85);
      eHeight.show();
      inches = new RadioButton("Inches");
      layout.put(inches, 90, 115);
      inches.show();
      mm = new RadioButton(inches, "Millimeters");
      mm.setActive(1);
      layout.put(mm, 90, 135);
      mm.show();
      layout.show();
   }

   void onResponse(int r, Dialog d)
   {
      if (r != cast(int) GtkResponseType.OK)
         return;
      string s = eWidth.getText();
      if (s == "")
         return;
      width = to!double(s);
      s = eHeight.getText();
      if (s == "")
         return;
      height = to!double(s);

      unit = cast(bool) inches.getActive();
   }
}

class MainMenu: MenuBar
{
   AppWindow aw;
   SheetLib sheetLib;
   MenuItem fileMenuItem;
   MItems[] mmItems;
   GdkAtom cbAtom;

   void disable(int md)
   {
      int m = (md & 0xff00) >> 8;
      int i = md & 0xff;
      mmItems[m][i].setSensitive(0);
   }

   void enable(int md)
   {
      int m = (md & 0xff00) >> 8;
      int i = md & 0xff;
      mmItems[m][i].setSensitive(1);
   }

   void setState(int md, int on)
   {
      int m = (md & 0xff00) >> 8;
      int i = md & 0xff;
      mmItems[m][i].setSensitive(on);
   }

   this(AppWindow w, SheetLib sl)
   {
      aw = w;
      cbAtom = atomIntern("CLIPBOARD", 0);
      sheetLib = sl;
      append(createFileMenu());
      append(createEditMenu());
      append(createViewMenu());
      append(createPLMenu());
      append(createMfrsMenu());
      append(createMergeMenu());
      append(createHelpMenu());
   }

   void updateFileMenu()
   {
      remove(fileMenuItem);
      fileMenuItem = createFileMenu();
      //fileMenuItem.show();
      prepend(fileMenuItem);
      fileMenuItem.showAll();
   }

   MenuItem createFileMenu()
   {
      MenuItem[] mits;

      Menu file = new Menu();
      file.addOnShow(&fmShow);
      Menu newOptions = createMenu(&onNew, fileNewSa);
      Menu imgOptions = createMenu(&onImgSave, imgSa);

      MenuItem x = new MenuItem("New");
      mits ~= x;
      x.setSubmenu(newOptions);
      file.append(x);

      x = new MenuItem("_Open");
      mits ~= x;
      x.addOnActivate(&fileMenuHandler);
      x.addAccelerator("activate", aw.acg, KeyVals.o, ModifierType.CONTROL_MASK, AccelFlags.VISIBLE);
      file.append(x);

      x = new MenuItem("_Save");
      mits ~= x;
      x.addOnActivate(&fileMenuHandler);
      x.addAccelerator("activate", aw.acg, KeyVals.s, ModifierType.CONTROL_MASK, AccelFlags.VISIBLE);
      file.append(x);

      x = new MenuItem("Save _As");
      mits ~= x;
      x.addOnActivate(&fileMenuHandler);
      x.addAccelerator("activate", aw.acg, KeyVals.s, ModifierType.SHIFT_MASK | ModifierType.CONTROL_MASK, AccelFlags.VISIBLE);
      file.append(x);

      x = new MenuItem("Sa_ve Image");
      mits ~= x;
      x.setSubmenu(imgOptions);
      file.append(x);
/*
      mits ~= x;
      x.addOnActivate(&fileMenuHandler);
      file.append(x);
*/
      x = new SeparatorMenuItem();
      file.append(x);

      x = new MenuItem("_Print");
      mits ~= x;
      x.addOnActivate(&fileMenuHandler);
      x.addAccelerator("activate", aw.acg, KeyVals.p, ModifierType.CONTROL_MASK, AccelFlags.VISIBLE);
      file.append(x);

      x = new MenuItem("Print I_mmediate");
      mits ~= x;
      x.addOnActivate(&fileMenuHandler);
      x.addAccelerator("activate", aw.acg, KeyVals.p, ModifierType.CONTROL_MASK | ModifierType.SHIFT_MASK, AccelFlags.VISIBLE);
      file.append(x);

      x = new MenuItem("Print _Item");
      mits ~= x;
      x.addOnActivate(&fileMenuHandler);
      file.append(x);

      if (aw.recent.count)
      {
         x = new SeparatorMenuItem();
         file.append(x);
         for (int i = 0; i < aw.recent.count; i++)
         {
            string[] sa = split(aw.recent.recent[i], "/");
            string s = "_"~to!string(i+1)~" "~sa[sa.length-1];
            x = new MenuItem(s);
            x.addOnActivate(&fileMenuHandler);
            file.append(x);
         }
      }

      x = new SeparatorMenuItem();
      file.append(x);

      x = new MenuItem("_Quit");
      mits ~= x;
      x.addOnActivate(&fileMenuHandler);
      x.addAccelerator("activate", aw.acg, KeyVals.q, ModifierType.CONTROL_MASK, AccelFlags.VISIBLE);
      file.append(x);

      fileMenuItem = new MenuItem("_File");
      fileMenuItem.setSubmenu(file);
      mmItems ~= mits;
      return fileMenuItem;
   }

   void fmShow(Widget w)
   {
      if (aw.dirty)
      {
         enable(FILE_SAVE);
         enable(FILE_SAVEAS);
         if (aw.cto is null)
            return;
         if (aw.cto.parent is aw.tm.root)
         {
            enable(FILE_PRINTITEM);
            enable(FILE_SAVEIMG);
            return;
         }
         if (aw.cto.type == AC_CONTAINER && aw.cto.children.length > 0)
         {
            enable(FILE_PRINTITEM);
            enable(FILE_SAVEIMG);
            return;
         }
         enable(FILE_PRINTITEM);
         enable(FILE_SAVEIMG);
      }
   }

   void onNew(MenuItem mi)
   {
      if (aw.dirty)
      {
         int rv = aw.willSave();
         if (rv == ResponseType.OK)
            aw.serializer.serialize(false);
         else if (rv == ResponseType.CANCEL)
            return;
      }
      string label = mi.getLabel();
      aw.setFileName(null);
      aw.merger.clear();
      switch (label)
      {
      case "Layered Composition":
         string s = aw.config.iso? aw.config.defaultISOLayout:
                    aw.config.defaultUSLayout;
         aw.newTV(AC_CONTAINER, s);
         break;
      case "Standalone Items":
         string s = aw.config.iso? aw.config.defaultISOStandaloneLayout:
                    aw.config.defaultUSStandaloneLayout;
         aw.newTV(aw.config.defaultSAItemType, s);
         break;
      default:
         aw.popupMsg("Unrecognized  Option"~label, MessageType.ERROR);
         break;
      }
   }

   void onImgSave(MenuItem mi)
   {
      if (aw.cto is null)
         return;
      string label = mi.getLabel();
      if (label == "PNG")
      {
         if (aw.cto.type == AC_CONTAINER)
            aw.cto.renderToPNG();
         else
         {
            if (aw.cto.parent.type == AC_CONTAINER)
               aw.cto.parent.renderToPNG();
            else
               aw.cto.renderToPNG();
         }
      }
      else
      {
         if (aw.cto.type == AC_CONTAINER)
            aw.cto.renderToSVG();
         else
         {
            if (aw.cto.parent.type == AC_CONTAINER)
               aw.cto.parent.renderToSVG();
            else
               aw.cto.renderToSVG();
         }
      }
   }

   void fileMenuHandler(MenuItem mi)
   {
      string label = mi.getLabel();
      switch (label)
      {
      case "New":
         break;
      case "_Open":
         if (aw.dirty)
         {
            int rv = aw.willSave();
            if (rv == ResponseType.OK)
               if (!aw.serializer.serialize(false))
                  return;
               else if (rv == ResponseType.CANCEL)
                  return;
         }
         aw.merger.clear();
         aw.deserializer.deserialize();
         aw.dirty = false;
         break;
      case "_Save":
         aw.serializer.serialize(false);
         aw.dirty = false;
         break;
      case "Save _As":
         aw.serializer.serialize(true);
         aw.dirty = false;
         break;
      case "Sa_ve Image":
         break;
      case "_Print":
         aw.printHandler.print(false);
         break;
      case "Print I_mmediate":
         aw.printHandler.print(true);
         break;
      case "Print _Item":
         aw.pageLayout.placeOne();
         aw.printHandler.print(true);
         break;
      case "_Quit":
         writeRecent(aw.recent);
         if (aw.dirty)
         {
            int rv = aw.willSave();
            if (rv == ResponseType.OK)
            {
               bool rv2 = aw.serializer.serialize(false);
               if (!rv2)
                  return;
            }
            else if (rv == ResponseType.CANCEL)
               return;
         }
         Main.quit();
         return;
      default:
         string fn = label[1..2];
         fn = aw.recent.recent[to!int(fn)-1];
         if (aw.dirty)
         {
            int rv = aw.willSave();
            if (rv == ResponseType.OK)
               if (!aw.serializer.serialize(false))
                  return;
               else if (rv == ResponseType.CANCEL)
                  return;
         }
         aw.merger.clear();
         aw.deserializer.deserialize(fn);
         aw.dirty = false;
         break;
      }
   }

   MenuItem createEditMenu()
   {
      MenuItem[] mits;

      ContextMenus cms = new ContextMenus(aw);
      Menu edit = new Menu();
      Menu itemOptions = cms.createItemsMenu(false);

      MenuItem em = new MenuItem("_Edit");
      em.setSubmenu(edit);

      MenuItem x = new MenuItem("_Undo");
      mits ~= x;
      x.addOnActivate(&editMenuHandler);
      x.addAccelerator("activate", aw.acg, KeyVals.z, ModifierType.CONTROL_MASK, AccelFlags.VISIBLE);
      edit.append(x);

      x = new MenuItem("_Copy");
      mits ~= x;
      x.addOnActivate(&editMenuHandler);
      x.addAccelerator("activate", aw.acg, KeyVals.c, ModifierType.CONTROL_MASK, AccelFlags.VISIBLE);
      edit.append(x);

      x = new MenuItem("Copy as _Image");
      mits ~= x;
      x.addOnActivate(&editMenuHandler);
      edit.append(x);

      x = new MenuItem("Cu_t");
      mits ~= x;
      x.addOnActivate(&editMenuHandler);
      x.addAccelerator("activate", aw.acg, KeyVals.x, ModifierType.CONTROL_MASK, AccelFlags.VISIBLE);
      edit.append(x);

      x = new MenuItem("_Paste");
      mits ~= x;
      x.addOnActivate(&editMenuHandler);
      x.addAccelerator("activate", aw.acg, KeyVals.v, ModifierType.CONTROL_MASK, AccelFlags.VISIBLE);
      edit.append(x);

      x = new SeparatorMenuItem();
      edit.append(x);

      x = new MenuItem("_Add a Composition");
      mits ~= x;
      x.addOnActivate(&editMenuHandler);
      edit.append(x);

      x = new MenuItem("Add a Standalone _Item");
      mits ~= x;
      x.addOnActivate(&fixupCMItem);
      x.setSubmenu(itemOptions);
      edit.append(x);

      x = new SeparatorMenuItem();
      edit.append(x);

      x = new MenuItem("_Settings");
      mits ~= x;
      x.addOnActivate(&editMenuHandler);
      edit.append(x);

      mmItems ~= mits;
      return em;
   }

   void fixupCMItem(MenuItem mi)
   {
      aw.setItemAddContext(-1);
      aw.cmItem = aw.tm.root;
   }

   void editMenuHandler(MenuItem mi)
   {
      string label = mi.getLabel();
      switch (label)
      {
      case "_Undo":
         if (aw.tv.isFocus())
         {
            DeletedItem di = aw.treeOps.popDeleted();
            if (di.item is null)
               return;
            aw.replaceItem(di);
            return;
         }
         if (aw.cto is null)
            return;
         /*
         if (aw.cto.type < AC_RICHTEXT)
         {
            TextViewItem tvi = cast(TextViewItem) aw.cto;
            if (tvi.editMode)
            {
               tvi.undoTB();
               tvi.te.queueDraw();
            }
            else
               aw.cto.undo();
         }
         else if (aw.cto.type == AC_RICHTEXT)
         {
            RichText rt = cast(RichText) aw.cto;
            if (rt.editMode)
            {
               rt.undoTB();
               rt.te.queueDraw();
            }
            else
               aw.cto.undo();
         }
         else
         {
            aw.cto.undo();
         }
         */
         aw.cto.undo();
         break;
      case "_Copy":
      {
         if (aw.tv.hasFocus())
         {
            if (aw.cto !is null)
               aw.copy = aw.cloneItem(aw.cto);
            return;
         }
         ACGroups group = aw.cto.getGroup();
         if (group == ACGroups.TEXT)
         {
            Clipboard cb = Clipboard.get(cbAtom);
            TextViewItem tvi = cast(TextViewItem) aw.cto;
            tvi.tb.copyClipboard(cb);
         }
         else if (group == ACGroups.PICTURE)
         {
            Clipboard cb = Clipboard.get(cbAtom);
            PixelImage pixelImage = cast(PixelImage) aw.cto;
            cb.setImage(pixelImage.pxb);
         }
      }
      break;
      case "Copy as _Image":
         Pixbuf pb = (cast(Container) aw.getRenderItem()).getPixbuf();
         Clipboard cb = Clipboard.get(cbAtom);
         cb.setImage(pb);
         break;
      case "Cu_t":
      {
         if (aw.tv.hasFocus())
         {
            if (aw.cto !is null)
               aw.doCut(aw.cto);
         }
         else
         {
            ACGroups group = aw.cto.getGroup();
            if (group == ACGroups.TEXT)
            {
               Clipboard cb = Clipboard.get(cbAtom);
               TextViewItem tvi = cast(TextViewItem) aw.cto;
               tvi.tb.cutClipboard(cb, true);
            }
         }
      }
      break;
      case "_Paste":
      {
         if (aw.tv.hasFocus())
         {
            if (aw.copy !is null)
            {
               if (aw.tm.root.children.length == 0)
               {
                  ACBase ni = aw.cloneItem(aw.copy);
                  ni.parent = aw.tm.root;
                  aw.tm.appendRoot(ni);
                  aw.switchLayouts(ni, true, true);
                  ni.reDraw();
                  // Now fix up the TreeView
                  aw.tv.expandAll();
                  aw.tv.queueDraw();
                  aw.treeOps.select(ni);
               }
               else
               {
                  aw.cmItem = aw.cto;
                  ACBase ni = aw.cloneItem(aw.copy);
                  aw.doItemInsert(null, 2, ni);
               }
            }
            return;
         }
         ACGroups group = aw.cto.getGroup();
         if (group == ACGroups.TEXT)
         {
            Clipboard cb = Clipboard.get(cbAtom);
            string cbtext = cb.waitForText();
            if (!cbtext)
               return;
            TextViewItem tvi = cast(TextViewItem) aw.cto;
            tvi.tb.insertAtCursor(cbtext);
            aw.cto.reDraw();
         }
         else if (group == ACGroups.PICTURE)
         {
            Clipboard cb = Clipboard.get(cbAtom);
            Pixbuf img = cb.waitForImage();
            PixelImage pixelImage = cast(PixelImage) aw.cto;
            pixelImage.pasteImg(img);
         }
      }
      break;
      case "_Add a Composition":
         aw.addContainer();
         break;
      case "Add a Standalone _Item":
         break;
      case "_Settings":
         SettingsDlg sd = new SettingsDlg(aw);
         sd.run();
         break;
      default:
         aw.popupMsg("Unrecognized  Option"~label, MessageType.ERROR);
         break;
      }
   }

   MenuItem createViewMenu()
   {
      MenuItem[] mits;

      Menu view = new Menu();

      MenuItem vm = new MenuItem("_View");
      vm.setSubmenu(view);

      MenuItem x = new MenuItem("_Object Design");
      mits ~= x;
      x.addOnActivate(&viewMenuHandler);
      x.addAccelerator("activate", aw.acg, KeyVals.o, ModifierType.MOD1_MASK, AccelFlags.VISIBLE);
      view.append(x);

      x = new MenuItem("_Layout Page");
      mits ~= x;
      x.addOnActivate(&viewMenuHandler);
      x.addAccelerator("activate", aw.acg, KeyVals.l, ModifierType.MOD1_MASK, AccelFlags.VISIBLE);
      view.append(x);

      x = new SeparatorMenuItem();
      view.append(x);

      x = new MenuItem("Object Controls _Below");
      mits ~= x;
      x.addOnActivate(&viewMenuHandler);
      view.append(x);

      x = new MenuItem("Object Controls _Right");
      mits ~= x;
      x.addOnActivate(&viewMenuHandler);
      view.append(x);

      x = new MenuItem("Object Controls _Floating");
      mits ~= x;
      x.addOnActivate(&viewMenuHandler);
      view.append(x);

      x = new MenuItem("_Show Controls");
      mits ~= x;
      x.addAccelerator("activate", aw.acg, KeyVals.s, ModifierType.MOD1_MASK, AccelFlags.VISIBLE);
      x.addOnActivate(&viewMenuHandler);
      view.append(x);

      mmItems ~= mits;
      return vm;
   }

   void viewMenuHandler(MenuItem mi)
   {
      string label = mi.getLabel();
      switch (label)
      {
      case "_Object Design":
         aw.onPageLayout(false);
         break;
      case "_Layout Page":
         aw.onPageLayout(true);
         break;
      case "Object Controls _Below":
         aw.positionControls(ControlsPos.BELOW);
         break;
      case "Object Controls _Right":
         aw.positionControls(ControlsPos.RIGHT);
         break;
      case "Object Controls _Floating":
         aw.positionControls(ControlsPos.FLOATING);
         break;
      case "_Show Controls":
         if (aw.cto && aw.controlsPos == ControlsPos.FLOATING && aw.cto.controlsDlg !is null)
         {
            aw.cto.controlsDlg.show();
            aw.mm.disable(VIEW_CSHOW);
         }
         break;
      default:
         aw.popupMsg("Unrecognized  Option"~label, MessageType.ERROR);
         break;
      }
   }

   MenuItem createPLMenu()
   {
      MenuItem[] mits;

      Menu placement = new Menu();

      MenuItem pl = new MenuItem("_Placement");
      pl.setSubmenu(placement);

      MenuItem x = new MenuItem("_Fill");
      mits ~= x;
      x.addOnActivate(&plMenuHandler);
      x.addAccelerator("activate", aw.acg, KeyVals.F2, cast(ModifierType) 0, AccelFlags.VISIBLE);
      placement.append(x);

      x = new MenuItem("_Place in Sequence");
      mits ~= x;
      x.addOnActivate(&plMenuHandler);
      x.addAccelerator("activate", aw.acg, KeyVals.F3, cast(ModifierType) 0, AccelFlags.VISIBLE);
      placement.append(x);

      x = new MenuItem("Fill in _Sequence");
      mits ~= x;
      x.addOnActivate(&plMenuHandler);
      x.addAccelerator("activate", aw.acg, KeyVals.F4, cast(ModifierType) 0, AccelFlags.VISIBLE);
      placement.append(x);

      x = new MenuItem("_Clear All");
      mits ~= x;
      x.addOnActivate(&plMenuHandler);
      x.addAccelerator("activate", aw.acg, KeyVals.F5, cast(ModifierType) 0, AccelFlags.VISIBLE);
      placement.append(x);

      x = new SeparatorMenuItem();
      placement.append(x);

      x = new CheckMenuItem("Draw _Outlines");
      mits ~= x;
      x.addOnActivate(&plMenuHandler);
      placement.append(x);

      x = new CheckMenuItem("Draw Crop _Marks");
      mits ~= x;
      x.addOnActivate(&plMenuHandler);
      placement.append(x);

      x = new SeparatorMenuItem();
      placement.append(x);

      x = new MenuItem("Printer _Alignment Test");
      mits ~= x;
      x.addOnActivate(&plMenuHandler);
      placement.append(x);

      mmItems ~= mits;
      return pl;
   }

   void plMenuHandler(MenuItem mi)
   {
      string label = mi.getLabel();
      switch (label)
      {
      case "_Fill":
         aw.pageLayout.fill(true);
         break;
      case "_Place in Sequence":
         aw.pageLayout.placeSequence();
         break;
      case "Fill in _Sequence":
         aw.pageLayout.fillSequence();
         break;
      case "_Clear All":
         aw.pageLayout.fill(false);
         break;
      case "Draw _Outlines":
         aw.drawOutlines = !aw.drawOutlines;
         aw.pageLayout.queueDraw();
         break;
      case "Draw Crop _Marks":
         aw.drawCropMarks  = !aw.drawCropMarks;
         aw.pageLayout.queueDraw();
         break;
      case "Printer _Alignment Test":
         aw.printHandler.printAlignment();
         break;
         break;
      default:
         aw.popupMsg("Unrecognized  Option"~label, MessageType.ERROR);
         break;
      }
   }

   MenuItem createMfrsMenu()
   {
      MenuItem[] mits;

      Menu mfrs = new Menu();

      MenuItem mm = new MenuItem("_Sheets");
      mm.setSubmenu(mfrs);

      MenuItem x;
      foreach (string s; mfrsSa)
      {
         x = new MenuItem(s);
         mits ~= x;
         string[] list = sheetLib.getMenuForMfr(s);
         string[] tl;
         foreach (string ts; list)
         {
            if (ts == "---")
               tl ~= "---";
            else
               tl ~= s~": "~ts;
         }
         Menu sub = createMenu(&ssHandler, tl);
         x.setSubmenu(sub);
         mfrs.append(x);
      }

      x = new MenuItem("_User");
      x.setSubmenu(createMenu(&ssHandler, [ "User: GridExample", "User: SequenceExample" ]));
      mfrs.append(x);

      x = new SeparatorMenuItem();
      mfrs.append(x);

      x = new MenuItem("_Scrap...");
      mits ~= x;
      x.addOnActivate(&scrapHandler);
      mfrs.append(x);

      x = new SeparatorMenuItem();
      mfrs.append(x);

      x = new CheckMenuItem();
      x.setUseUnderline(1);
      x.setLabel("_Landscape");
      mits ~= x;
      x.addOnActivate(&landscapeHandler);
      mfrs.append(x);

      x = new SeparatorMenuItem();
      mfrs.append(x);

      x = new MenuItem("_Current Sheet Details");
      mits ~= x;
      x.addOnActivate(&sheetHandler);
      mfrs.append(x);

      x = new MenuItem("Custom _Grid Design");
      mits ~= x;
      x.addOnActivate(&sheetHandler);
      mfrs.append(x);

      x = new MenuItem("Custom Sequence _Design");
      mits ~= x;
      x.addOnActivate(&sheetHandler);
      mfrs.append(x);

      x = new MenuItem("_Edit Current Design");
      mits ~= x;
      x.addOnActivate(&sheetHandler);
      mfrs.append(x);

      mmItems ~= mits;
      return mm;
   }

   void sheetHandler(MenuItem mi)
   {
      string label = mi.getLabel();
      switch (label)
      {
      case "_Current Sheet Details":
         SheetDetailsDlg sd = new SheetDetailsDlg(aw);
         sd.run();
         sd.destroy();
         break;
      case "Custom _Grid Design":
         GridDlg gd = new GridDlg(aw);
         gd.run();
         gd.destroy();
         break;
      case "Custom Sequence _Design":
         SequenceDlg sd = new SequenceDlg(aw);
         sd.run();
         sd.destroy();
         break;
      case "_Edit Current Design":
         if (aw.currentSheet.mfr != "User")
         {
            aw.popupMsg("The current sheet is not a user defined one.\nSelect the user-defined sheet you want to edit first.",
                        MessageType.WARNING);
            break;
         }

         if (aw.currentSheet.seq)
         {
            SequenceDlg sd = new SequenceDlg(aw, aw.currentSheet);
            sd.run();
            sd.destroy();
         }
         else
         {
            GridDlg gd = new GridDlg(aw, aw.currentSheet);
            gd.run();
            gd.destroy();
         }
         break;
      default:
         aw.popupMsg("Unrecognized Option "~label, MessageType.ERROR);
         break;
      }
   }

   void scrapHandler(MenuItem mi)
   {
      ScrapDlg sd = new ScrapDlg(aw);
      int rv = sd.run();
      if (rv != ResponseType.OK)
      {
         sd.destroy();
         return;
      }
      double w = sd.width;
      double h = sd.height;
      bool inches = sd.unit;
      sd.destroy();
      if (inches)
      {
         w *= 25.4;
         h *= 25.4;
      }
      aw.setScrapSheet(w, h);
   }

   void landscapeHandler(MenuItem mi)
   {
      aw.setLandscape(cast(bool) (cast(CheckMenuItem) mi).getActive());
   }

   void ssHandler(MenuItem mi)
   {
      string label = mi.getLabel();
      Sheet s;
      if (label.indexOf("User:") == 0)
      {
         s = scaleSheet(aw, loadSheet(aw, label[6..$]));
      }
      else
      {
         string[] sa = split(label, " - ");
         s = sheetLib.getSheet(sa[0]);
      }
      aw.setSheet(s);
   }

   MenuItem createMergeMenu()
   {
      MenuItem[] mits;

      Menu merge = new Menu();
      MenuItem mm = new MenuItem("_Merge");
      mm.setSubmenu(merge);

      MenuItem x = new MenuItem("Merge _Setup");
      mits ~= x;
      x.addOnActivate(&mergeMenuHandler);
      merge.append(x);

      x = new SeparatorMenuItem();
      merge.append(x);

      x = new MenuItem("Merge/Print a _Page");
      mits ~= x;
      x.addOnActivate(&mergeMenuHandler);
      merge.append(x);

      x = new MenuItem("Merge/Print _All");
      mits ~= x;
      x.addOnActivate(&mergeMenuHandler);
      merge.append(x);

      x = new MenuItem("_Done Merging");
      mits ~= x;
      x.addOnActivate(&mergeMenuHandler);
      merge.append(x);

      mmItems ~= mits;
      return mm;
   }

   void mergeMenuHandler(MenuItem mi)
   {
      string label = mi.getLabel();
      switch (label)
      {
      case "Merge _Setup":
         MergeDialog md = new MergeDialog(aw);
         md.run();
         md.destroy();
         break;
      case "Merge/Print a _Page":
         if (!aw.merger.loaded)
         {
            if (!aw.merger.beginMerge())
               return;
         }
         aw.merger.mergeOnePage();
         break;
      case "Merge/Print _All":
         if (!aw.merger.loaded)
         {
            if (!aw.merger.beginMerge())
               return;
         }
         aw.merger.mergeAll();
         break;
      case "_Done Merging":
         aw.merger.clear();
         break;
      default:
         aw.popupMsg("Unrecognized  Option"~label, MessageType.ERROR);
         break;
      }
   }

   MenuItem createHelpMenu()
   {
      MenuItem[] mits;

      Menu help = new Menu();
      MenuItem hm = new MenuItem("_Help");
      hm.setSubmenu(help);

      MenuItem x = new MenuItem("_COMPO Help Online");
      mits ~= x;
      x.addOnActivate(&helpMenuHandler);
      x.addAccelerator("activate", aw.acg, KeyVals.F1, cast(ModifierType) 0, AccelFlags.VISIBLE);
      help.append(x);

      x = new MenuItem("_About COMPO");
      mits ~= x;
      x.addOnActivate(&helpMenuHandler);
      help.append(x);

      mmItems ~= mits;
      return hm;
   }

   void helpMenuHandler(MenuItem mi)
   {
      string label = mi.getLabel();
      switch (label)
      {
      case "_COMPO Help Online":
         MountOperation.showUri(null, "http://britseyeview.com/software/compo/", 0);
         break;
      case "_About COMPO":
         COMPOAbout about = new COMPOAbout();
         about.show();
         break;
      default:
         aw.popupMsg("Unrecognized  Option"~label, MessageType.ERROR);
         break;
      }
   }

}
