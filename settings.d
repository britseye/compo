
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module settings;

import std.stdio;
import std.conv;
import std.array;
import std.string;
import std.path;

import mainwin;
import acomp;
import config;

import gtk.Dialog;
import gtk.VBox;
import gtk.Layout;
import gtk.Label;
import gtk.Entry;
import gtk.Button;
import gtk.ToggleButton;
import gtk.RadioButton;
import gtk.CheckButton;
import gtk.SpinButton;
import gtk.Notebook;
import gtk.ComboBoxText;
import gtk.FileChooserDialog;
import gtk.FontSelectionDialog;
import gtk.TextView;
import gtk.Frame;
import pango.PgFontDescription;

class SettingsDlg: Dialog
{
   AppWindow aw;
   COMPOConfig config;
   RadioButton iso, us;
   CheckButton maximize, useCurrent, landscape;
   SpinButton width, height, undoLen, polySides;
   ComboBoxText controlsPos, defStand, defMorph;
   Entry bcid, st, cid, ptleft, pttop;
   Label p21, p22, p23, p24, p31;
   Button defDir, defISO, defISOStand, defUS, defUSStand;
   Label folder;
   TextView tv;

   this(AppWindow w)
   {
      ResponseType rta[2] = [ ResponseType.CANCEL, ResponseType.OK ];
      string[2] sa = [ "Cancel", "OK" ];
      super("Edit COMPO Settings", w, DialogFlags.DESTROY_WITH_PARENT, sa, rta);
      aw = w;
      config = aw.config;
      setSizeRequest(500, 350);

      addOnResponse(&responseHandler);
      Notebook nb = new Notebook();
      VBox vb = getContentArea();
      vb.packStart(nb, 1, 1, 0);
      nb.show();

      Layout p1Layout = new Layout(null, null);
      p1Layout.show();
      addP1Gadgets(p1Layout);
      nb.appendPage(p1Layout, "General");

      Layout p2Layout = new Layout(null, null);
      p2Layout.show();
      addP2Gadgets(p2Layout);
      nb.appendPage(p2Layout, "Default Items");

      Layout p3Layout = new Layout(null, null);
      p3Layout.show();
      addP3Gadgets(p3Layout);
      nb.appendPage(p3Layout, "Text Editing");

      Layout p4Layout = new Layout(null, null);
      p4Layout.show();
      addP4Gadgets(p4Layout);
      nb.appendPage(p4Layout, "USPS Addresses");

      Layout p5Layout = new Layout(null, null);
      p5Layout.show();
      addP5Gadgets(p5Layout);
      nb.appendPage(p5Layout, "Miscellaneous");
   }


   void responseHandler(int rt, Dialog d)
   {
      if (rt == ResponseType.OK)
      {
         getValues();
         createConfig(config, aw.config.iso);
      }
      destroy();
   }

   void getValues()
   {
      config.maximize = cast(bool) maximize.getActive();
      bool useCur = cast(bool) useCurrent.getActive();
      if (useCur)
      {
         int w, h;
         aw.getSize(w, h);
         config.width = w;
         config.height = h;
      }
      else
      {
         config.width = width.getValueAsInt();
         config.height = height.getValueAsInt();
      }
      config.controlsPos = controlsPos.getActive();
      string at = defStand.getActiveText();
      int dt = aw.getTypeFromName(at);
      if (dt == -1)
         dt = AC_CONTAINER;
      config.defaultSAItemType = dt;
      config.USPSBarcodeID = bcid.getText();
      config.USPSServiceType = st.getText();
      config.USPSCustomerID = cid.getText();
      config.polySides = polySides.getValueAsInt();
      config.defMorph = defMorph.getActive();
      config.printerTrimX = to!double(ptleft.getText());
      config.printerTrimY = to!double(pttop.getText());
   }

   void addP1Gadgets(Layout p1)
   {
      int vp = 10;

      maximize = new CheckButton("Open maximised.");
      maximize.setActive(config.maximize);
      maximize.show();
      p1.put(maximize, 10, vp);

      vp += 25;
      Label t = new Label("Main window width when opened:");
      t.show();
      p1.put(t, 10, vp);
      width = new SpinButton(300, 1500, 10);
      width.setValue(config.width);
      width.show();
      p1.put(width, 260, vp);

      vp += 30;
      t = new Label("Main window height when opened:");
      t.show();
      p1.put(t, 10, vp);
      height = new SpinButton(300, 1500, 10);
      height.setValue(config.height);
      height.show();
      p1.put(height, 260, vp);

      vp += 30;
      useCurrent = new CheckButton("Use current size when opened.");
      useCurrent.show();
      p1.put(useCurrent, 10, vp);

      vp+= 25;
      t = new Label("Position of design controls:");
      t.show();
      p1.put(t, 10, vp);
      controlsPos = new ComboBoxText();
      controlsPos.appendText("Below");
      controlsPos.appendText("Right");
      controlsPos.appendText("Floating");
      controlsPos.setActive(config.controlsPos);
      controlsPos.show();
      p1.put(controlsPos, 260, vp);

      vp+= 35;
      t = new Label("Default item type at startup:");
      t.show();
      p1.put(t, 10, vp);
      defStand = new ComboBoxText();
      defStand.appendText("Container");
      defStand.appendText("Plain Text");
      defStand.appendText("USPS Address");
      defStand.appendText("Rich Text");
      defStand.appendText("PixelImage");
      defStand.setActive(config.defaultSAItemType);
      defStand.setActive(0);
      defStand.show();
      p1.put(defStand, 260, vp);

      vp += 30;
      folder = new Label("Default working folder:\n"~config.defaultFolder);
      folder.show();
      p1.put(folder, 10, vp);
      defDir = new Button("Set default folder");
      defDir.addOnPressed(&chooseDefDir);
      defDir.show();
      p1.put(defDir, 260, vp+5);

      vp = 235;
      t = new Label("Undo stack length:");
      t.show();
      p1.put(t, 10, vp);
      undoLen = new SpinButton(5, 50, 1);
      undoLen.setValue(config.undoStackLength);
      undoLen.show();
      p1.put(undoLen, 260, vp);
   }

   void chooseDefDir(Button b)
   {
      FileChooserDialog fcd = new FileChooserDialog("Choose Default Folder", aw, FileChooserAction.SELECT_FOLDER);
      fcd.setCurrentFolder(expandTilde("~"));

      int response = fcd.run();
      if (response != ResponseType.OK)
      {
         fcd.destroy();
         return;
      }
      config.defaultFolder = fcd.getFilename();
      folder.setText("Default working folder:\n" ~  config.defaultFolder);
      fcd.destroy();
   }

   void addP2Gadgets(Layout p2)
   {
      int vp = 10;

      p21 = new Label("Set current layout as ISO default for compositions\n"~
                      "(current is " ~ config.defaultISOLayout ~ ")");
      p2.put(p21, 10, vp);
      p21.show();
      defISO= new Button("Set Now");
      defISO.addOnPressed(&p2BtnPress);
      defISO.show();
      p2.put(defISO, 400, vp);

      vp += 40;
      p22 = new Label("Set current layout as US default for compositions\n"~
                      "(current is " ~ config.defaultUSLayout ~ ")");
      p2.put(p22, 10, vp);
      p22.show();
      defUS= new Button("Set Now");
      defUS.addOnPressed(&p2BtnPress);
      defUS.show();
      p2.put(defUS, 400, vp);

      vp += 40;
      p23 = new Label("Set current layout as ISO default for standalone items\n"~
                      "(current is " ~ config.defaultISOStandaloneLayout ~ "}");
      p2.put(p23, 10, vp);
      p23.show();
      defISOStand= new Button("Set Now");
      defISOStand.addOnPressed(&p2BtnPress);
      defISOStand.show();
      p2.put(defISOStand, 400, vp);

      vp += 40;
      p24 = new Label("Set current layout as US default for standalone items\n"~
                      "(current is " ~ config.defaultUSStandaloneLayout ~ "}");
      p2.put(p24, 10, vp);
      p24.show();
      defUSStand= new Button("Set Now");
      defUSStand.addOnPressed(&p2BtnPress);
      defUSStand.show();
      p2.put(defUSStand, 400, vp);
   }

   void p2BtnPress(Button b)
   {
      string curLayout = aw.currentSheet.mfr ~ ": " ~ aw.currentSheet.id;
      if (b is defISO)
      {
         config.defaultISOLayout = curLayout;
         p21.setText("Set current layout as ISO default for compositions\n"~
                     "(current is " ~ config.defaultISOLayout ~ ")");
      }
      else if (b is defUS)
      {
         config.defaultUSLayout = curLayout;
         p22.setText("Set current layout as US default for compositions\n"~
                     "(current is " ~ config.defaultUSLayout ~ ")");
      }
      else if (b is defISOStand)
      {
         config.defaultISOStandaloneLayout = curLayout;
         p23.setText("Set current layout as ISO default for standalone items\n"~
                     "(current is " ~ config.defaultISOStandaloneLayout ~ "}");
      }
      else
      {
         config.defaultUSStandaloneLayout = curLayout;
         p24.setText("Set current layout as US default for standalone items\n"~
                     "(current is " ~ config.defaultUSStandaloneLayout ~ "}");
      }
   }
   void addP3Gadgets(Layout p3)
   {
      int vp = 10;
      Button b = new Button("Choose default font for text-type items");
      b.show();
      b.addOnPressed(&p3BtnPress);
      p3.put(b, 10, vp);

      p31 = new Label("(" ~ config.defaultFont ~ ")");
      p31.show();
      p3.put(p31, 300, vp+5);
   }

   void p3BtnPress(Button b)
   {
      FontSelectionDialog fsd = new FontSelectionDialog("Choose Default Font");
      fsd.setFontName(config.defaultFont);
      int response = fsd.run();
      if (response != ResponseType.OK)
      {
         fsd.destroy();
         return;
      }
      string fname = fsd.getFontName();
      fsd.destroy();
      config.defaultFont = fname;
      p31.setText("(" ~ config.defaultFont ~ ")");
   }

   void addP4Gadgets(Layout p4)
   {
      tv = new TextView();
      PgFontDescription pfd = PgFontDescription.fromString(config.USPSFont);
      tv.setSizeRequest(346, 25);
      tv.modifyFont(pfd);
      tv.insertText("John Doe, 42 Washington Avenue");

      int vp = 10;

      ComboBoxText cb = new ComboBoxText();
      cb.addOnChanged(&p4FontChange);
      cb.appendText("Andale Mono 10");
      cb.appendText("Arial 10");
      cb.appendText("DejaVu Sans 10");
      cb.appendText("DejaVu Sans Mono 10");
      cb.appendText("FreeSans 10");
      cb.appendText("Garuda 10");
      cb.appendText("Liberation Sans 10");
      cb.appendText("Loma 10");
      cb.appendText("Meera 10");
      cb.appendText("Nimbus Sans L 10");
      cb.appendText("Ubuntu 10");
      cb.appendText("Sans 10");
      cb.appendText("Vermana2000 10");
      cb.appendText("Verdana 10");
      cb.setActiveText(config.USPSFont);
      cb.show();
      p4.put(cb, 10, vp);

      vp += 40;
      tv.show();
      Frame f = new Frame(tv, null);
      //f.setSizeRequest(width+4, height+4);
      p4.put(f, 10, vp);
      f.show();

      vp += 40;
      Label t = new Label("Bar code ID:");
      t.show();
      p4.put(t, 10, vp);
      bcid = new Entry(config.USPSBarcodeID);
      bcid.show();
      p4.put(bcid, 200, vp);

      vp += 30;
      t = new Label("Service type:");
      t.show();
      p4.put(t, 10, vp);
      st = new Entry(config.USPSServiceType);
      st.show();
      p4.put(st, 200, vp);

      vp += 30;
      t = new Label("Customer ID:");
      t.show();
      p4.put(t, 10, vp);
      cid = new Entry(config.USPSCustomerID);
      cid.show();
      p4.put(cid, 200, vp);
   }

   void p4FontChange(ComboBoxText cb)
   {
      string s = cb.getActiveText();
      PgFontDescription pfd = PgFontDescription.fromString(s);
      tv.modifyFont(pfd);
      config.USPSFont = s;
   }

   void addP5Gadgets(Layout p5)
   {
      int vp = 10;
      Label t = new Label("Regular polygon default sides:");
      t.show();
      p5.put(t, 10, vp);
      polySides = new SpinButton(3, 20, 1);
      polySides.setValue(config.polySides);
      polySides.show();
      p5.put(polySides, 240, vp);

      vp += 35;
      t = new Label("Morphed text default style:");
      t.show();
      p5.put(t, 10, vp);
      defMorph = new ComboBoxText();
      defMorph.appendText("Fit the area");
      defMorph.appendText("Taper");
      defMorph.appendText("Arch Up");
      defMorph.appendText("Sine Wave");
      defMorph.appendText("Twisted");
      defMorph.appendText("Top Flare");
      defMorph.appendText("Bottom Flare");
      defMorph.appendText("Flare");
      defMorph.appendText("Reverse Flare");
      defMorph.appendText("Circular");
      defMorph.appendText("Catenary");
      defMorph.appendText("Convex");
      defMorph.appendText("Concave");
      defMorph.setSizeRequest(174, -1);
      defMorph.setActive(config.defMorph);
      defMorph.show();
      p5.put(defMorph, 240, vp);

      vp += 170;
      t = new Label("Printer alignment corrections");
      t.show();
      p5.put(t, 10, vp);
      vp += 20;
      t = new Label("Left:");
      t.show();
      p5.put(t, 10, vp);
      ptleft = new Entry();
      ptleft.setSizeRequest(60, -1);
      ptleft.setText(to!string(config.printerTrimX));
      ptleft.show();
      p5.put(ptleft, 60, vp);
      t = new Label("Top:");
      t.show();
      p5.put(t, 180, vp);
      pttop = new Entry();
      pttop.setSizeRequest(60, -1);
      pttop.setText(to!string(config.printerTrimY));
      pttop.show();
      p5.put(pttop, 230, vp);
   }
}
