
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module sheets;

import std.stdio;
import std.conv;
import std.regex;
import std.path;
import std.file;
import std.array;
import std.math;

import avery;
import generic;
import types;
import mainwin;
import common;

import gdk.RGBA;
import gtk.Widget;
import gtk.Dialog;
import gtk.VBox;
import gtk.Layout;
import gtk.Label;
import gtk.TextView;
import gtk.TextBuffer;
import gtk.DrawingArea;
import gtk.Button;
import gtk.ToggleButton;
import gtk.CheckButton;
import gtk.Frame;
import gtk.EditableIF;
import gtk.Entry;
import gtk.MenuItem;
import gtkc.gtktypes;
import cairo.Context;

enum Paper
{
   A4,
   US,
   OTHER
}

enum Category
{
   MAILING = 0,
   BC,
   CARD,
   FOLDED,
   GP,
   SPECIAL,
   SEPARATOR,
   SCRAP,
   USER
}

immutable string[] categoryNames  = [
                                       "Mailing Label",
                                       "Business Card",
                                       "Card Product",
                                       "Folded sheet",
                                       "General Purpose",
                                       "Speciality",
                                       "Separator",
                                       "User Scrap",
                                       "User Defined" ];

immutable string[] gridNames = [
                                  "grid",
                                  "iso",
                                  "mfr",
                                  "id",
                                  "description",
                                  "category",
                                  "paper",
                                  "seq",
                                  "cols",
                                  "rows",
                                  "w",
                                  "h",
                                  "topx",
                                  "topy",
                                  "hstride",
                                  "vstride",
                                  "round" ];

struct Grid
{
   ushort cols, rows;
   double w, h;
   double topx, topy;
   double hstride, vstride;
   bool round;
}

struct LSRect
{
   bool round;
   double x, y, w, h;
}

struct Sequence
{
   int count;
   LSRect[] rects;
}

union SheetLayout
{
   Grid g;
   Sequence s;
}

struct Sheet
{
   bool iso;                       // metric?
   string mfr;                     // Avery, ....
   string id;                       // manufacterers ID
   string description;
   Category category;
   Paper paper;
   bool seq;
   SheetLayout layout;
   bool scaled = false;
}

void getBiggest(Sequence s, out double w, out double h)
{
   double mw = 0, mh = 0;
   foreach (int i, LSRect r; s.rects)
   {
      if (i >= s.count)
         break;
      if (r.w > mw)
         mw = r.w;
      if (r.h > mh)
         mh = r.h;
   }
   w = mw;
   h = mh;
}

class SheetDetailsDlg: Dialog
{
   AppWindow aw;
   Layout layout;
   TextView tv;

   this(AppWindow w)
   {
      GtkResponseType rta[1] = [ ResponseType.OK ];
      string[1] sa = [ "Close" ];
      super("Current Sheet Details", w, DialogFlags.DESTROY_WITH_PARENT, sa, rta);
      aw = w;
      setSizeRequest(350, 200);
      layout = new Layout(null, null);
      VBox vb = getContentArea();
      vb.packStart(layout, 1, 1, 0);
      layout.show();
      addGadgets();
      string s = "The current sheet is:\n\n";
      Sheet current = aw.currentSheet;
      s ~= "Manufacturer: " ~ current.mfr ~ "\n";
      s ~= "Sheet ID: " ~ current.id ~ "\n";
      s ~= "Description: " ~ current.description ~ "\n";
      s ~= "Category: " ~ categoryNames[current.category];
      tv.insertText(s);
   }

   void addGadgets()
   {
      tv = new TextView();
      tv.setSensitive(0);
      Frame f = new Frame(tv, null);
      f.setSizeRequest(330, 150);
      f.show();
      layout.put(f, 10, 10);
      tv.show();
   }
}

class GridDlg: Dialog
{
   AppWindow aw;
   string cfn, sheetName;
   Layout layout;
   DrawingArea da;
   TextView tv;
   RGBA red, black;
   Widget save;
   CheckButton isRound;
   Entry cols, rows, wide, high, leftx, topy, xstep, ystep, name, purpose;
   int tpw, tph;
   Grid g;
   Sheet ns;
   bool editing;

   this (AppWindow w, Sheet s)
   {
      this(w);
      setTitle("Editing a Custom Grid Sheet");
      editing = true;
      cfn = s.id;
      ns = loadSheet(w, cfn);
      g = ns.layout.g;
      cols.setText(to!string(g.cols));
      rows.setText(to!string(g.rows));
      wide.setText(to!string(g.w));
      high.setText(to!string(g.h));
      leftx.setText(to!string(g.topx));
      topy.setText(to!string(g.topy));
      xstep.setText(to!string(g.hstride));
      ystep.setText(to!string(g.vstride));
      name.setText(to!string(ns.id));
      purpose.setText(to!string(ns.description));
      isRound.setActive(g.round);
   }

   this(AppWindow w)
   {
      GtkResponseType rta[1] = [ ResponseType.CANCEL ];
      string[1] sa = [ "Cancel" ];
      super("Set Up a Custom Grid Sheet", w, DialogFlags.DESTROY_WITH_PARENT, sa, rta);
      addOnResponse(&responseHandler);
      save = addButton("Save", ResponseType.OK);
      save.setSensitive(0);
      aw = w;
      black = new RGBA(0,0,0, 1);
      red = new RGBA(1, 0, 0, 1);
      setSizeRequest(780, 420);
      if (aw.config.iso)
      {
         tpw = 210;
         tph = 297;
      }
      else
      {
         tpw = cast(int) (25.4*8.5);
         tph = cast(int) (25.4*11);
      }

      g = Grid(0,0,0,0,0,0,0,0,false);
      ns = Sheet(aw.config.iso, "User", "", "", Category.USER, Paper.A4, false);
      if (!aw.config.iso)
         ns.paper = Paper.US;
      ns.layout.g = g;

      layout = new Layout(null, null);
      VBox vb = getContentArea();
      vb.packStart(layout, 1, 1, 0);
      layout.show();
      addGadgets();
      da.show();
   }

   void responseHandler(int rt, Dialog d)
   {
      if (rt == ResponseType.OK)
      {
         writeSheet();
         if (!editing)
         {
            MenuItem mi = new MenuItem(&aw.mm.ssHandler, "User: "~sheetName);
            aw.mm.udefMenu.append(mi);
            mi.show();
         }
      }
      destroy();
   }

   void addGadgets()
   {
      int vp = 10, sizeRequest = 80;
      Label t = new Label("All grid sheets are designed as Portrait. COMPO will deal with rotating them.");
      t.show();
      layout.put(t, 10, vp);
      vp += 20;
      string s = "Rows and cols are integers, other measurements in decimal " ~ (aw.config.iso? "mm.": "inches.");
      t = new Label(s);
      t.show();
      layout.put(t, 10, vp);

      vp += 30;
      da = new DrawingArea(tpw, tph);
      da.addOnDraw(&drawCallback);
      Frame f = new Frame(da, null);
      f.setSizeRequest(tpw+4, tph+4);
      f.setShadowType(ShadowType.IN);
      layout.put(f, 540, vp);
      f.show();

      isRound = new CheckButton("Items are round.");
      isRound.addOnToggled(&cbToggled);
      isRound.show();
      layout.put(isRound, 10, vp);

      vp += 30;
      t = new Label("Number of columns:");
      t.show();
      layout.put(t, 10, vp);
      cols = new Entry();
      cols.addOnChanged(&entryChanged);
      cols.setWidthChars(12);
      cols.show();
      layout.put(cols, 150, vp);
      t = new Label("Number of rows:");
      t.show();
      layout.put(t, 280, vp);
      rows = new Entry();
      rows.addOnChanged(&entryChanged);
      rows.setWidthChars(12);
      rows.show();
      layout.put(rows, 410, vp);

      vp += 30;
      t = new Label("Width:");
      t.show();
      layout.put(t, 10, vp);
      wide = new Entry();
      wide.addOnChanged(&entryChanged);
      wide.setWidthChars(12);
      wide.show();
      layout.put(wide, 150, vp);
      t = new Label("Height:");
      t.show();
      layout.put(t, 280, vp);
      high = new Entry();
      high.addOnChanged(&entryChanged);
      high.setWidthChars(12);
      high.show();
      layout.put(high, 410, vp);

      vp += 30;
      t = new Label("Left margin:");
      t.show();
      layout.put(t, 10, vp);
      leftx = new Entry();
      leftx.addOnChanged(&entryChanged);
      leftx.setWidthChars(12);
      leftx.show();
      layout.put(leftx, 150, vp);
      t = new Label("Top margin:");
      t.show();
      layout.put(t, 280, vp);
      topy = new Entry();
      topy.addOnChanged(&entryChanged);
      topy.setWidthChars(12);
      topy.show();
      layout.put(topy, 410, vp);

      vp += 30;
      t = new Label("Horizontal stride:");
      t.show();
      layout.put(t, 10, vp);
      xstep = new Entry();
      xstep.addOnChanged(&entryChanged);
      xstep.setWidthChars(12);
      xstep.show();
      layout.put(xstep, 150, vp);
      t = new Label("Vertical stride:");
      t.show();
      layout.put(t, 280, vp);
      ystep = new Entry();
      ystep.addOnChanged(&entryChanged);
      ystep.setWidthChars(12);
      ystep.show();
      layout.put(ystep, 410, vp);

      vp += 30;
      t = new Label("Name of sheet:");
      t.show();
      layout.put(t, 10, vp);
      name = new Entry();
      name.addOnChanged(&entryChanged);
      name.setWidthChars(12);
      name.show();
      layout.put(name, 150, vp);
      t = new Label("Purpose reminder:");
      t.show();
      layout.put(t, 280, vp);
      purpose = new Entry();
      purpose.setWidthChars(12);
      purpose.show();
      layout.put(purpose, 410, vp);

      vp += 40;
      Button b = new Button("Check Entries");
      b.setSizeRequest(100, -1);
      b.addOnPressed(&checkEntries);
      b.show();
      layout.put(b, 10, vp);

      vp += 30;
      tv = new TextView();
      tv.setWrapMode(WrapMode.WORD);
      tv.setSizeRequest(505, 50);
      tv.setSensitive(0);
      f = new Frame(tv, null);
      f.show();
      layout.put(f, 10, vp);
      tv.show();
   }

   void cbToggled(ToggleButton b)
   {
      save.setSensitive(0);
      tv.getBuffer().setText("");
   }

   void entryChanged(EditableIF e)
   {
      save.setSensitive(0);
      tv.getBuffer().setText("");
   }

   Grid normalize(Grid og)
   {
      Grid t = og;
      if (aw.config.iso)
         return t;
      float inch = 25.4;
      t.w *= inch;
      t.h *= inch;
      t.topx *= inch;
      t.topy *= inch;
      t.hstride *= inch;
      t.vstride *= inch;
      return t;
   }

   bool drawCallback(Context c, Widget widget)
   {
      c.setSourceRgba(1,1,1,1);
      c.paint();
      c.setSourceRgb(0, 0, 0);
      c.setLineWidth(0.5);
      Grid lg = normalize(g);
      double xoff = lg.topx, yoff = lg.topy;
      for (int i = 0; i < lg.rows; i++)
      {
         for (int j = 0; j < lg.cols; j++)
         {
            if (lg.round)
            {
               c.arc(xoff+lg.w/2, yoff+lg.w/2, lg.w/2, 0, 2*PI);
            }
            else
            {
               c.moveTo(xoff, yoff);
               c.lineTo(xoff+lg.w, yoff);
               c.lineTo(xoff+lg.w, yoff+lg.h);
               c.lineTo(xoff, yoff+lg.h);
               c.closePath();
            }
            c.stroke();
            xoff += lg.hstride;
         }
         xoff = lg.topx;
         yoff += lg.vstride;
      }
      return true;
   }

   void report(string s, bool alert)
   {
      tv.getBuffer().setText(s);
      tv.overrideColor(tv.getStateFlags(), alert? red: black);
   }

   void checkEntries(Button b)
   {
      auto intrex = regex("^[1-9][0-9]{0,2}$");
      string s = cols.getText();
      if (!s.length)
      {
         report("You have not entered a value for Cols.", true);
         return;
      }
      auto im = match(s, intrex);
      if (im.empty())
      {
         cols.overrideColor(cols.getStateFlags(), red);
         report("The entry for Cols is not an integral number", true);
         return;
      }
      else
         cols.overrideColor(cols.getStateFlags(), black);
      g.cols = to!ushort(s);
      s = rows.getText();
      if (!s.length)
      {
         report("You have not entered a value for Rows.", true);
         return;
      }
      im = match(s, intrex);
      if (im.empty())
      {
         rows.overrideColor(rows.getStateFlags(), red);
         report("The entry for Rows is not an integral number", true);
         return;
      }
      else
         rows.overrideColor(rows.getStateFlags(), black);
      g.rows = to!ushort(s);
      double t;
      s = wide.getText();
      if (!s.length)
      {
         report("You have not entered a value for Width", true);
         return;
      }
      if (!getDecimal(wide, s, t))
      {
         report("The entry for Width is not a valid decimal number.", true);
         return;
      }
      g.w = t;
      s = high.getText();
      if (!s.length)
      {
         report("You have not entered a value for Height", true);
         return;
      }
      if (!getDecimal(high, s, t))
      {
         report("The entry for Height is not a valid decimal number.", true);
         return;
      }
      g.h = t;
      s = leftx.getText();
      if (!s.length)
      {
         report("You have not entered a value for Left margin", true);
         return;
      }
      if (!getDecimal(leftx, s, t))
      {
         report("The entry for Left margin is not a valid decimal number.", true);
         return;
      }
      g.topx = t;
      s = topy.getText();
      if (!s.length)
      {
         report("You have not entered a value for Top margin", true);
         return;
      }
      if (!getDecimal(topy, s, t))
      {
         report("The entry for Top margin is not a valid decimal number.", true);
         return;
      }
      g.topy = t;
      s = xstep.getText();
      if (!s.length)
      {
         report("You have not entered a value for Horizontal stride", true);
         return;
      }
      if (!getDecimal(xstep, s, t))
      {
         report("The entry for Horizontal stride is not a valid decimal number.", true);
         return;
      }
      g.hstride = t;
      s = ystep.getText();
      if (!s.length)
      {
         report("You have not entered a value for Vertical stride", true);
         return;
      }
      if (!getDecimal(ystep, s, t))
      {
         report("The entry for Vertical stride is not a valid decimal number.", true);
         return;
      }
      g.vstride = t;

      string rv = checkGrid();
      if (rv !is null)
      {
         report(rv, true);
         return;
      }
      g.round = (isRound.getActive() != 0);
      if (g.round && g.w != g.h)
      {
         report("You have specified that the items are round, but the width is different than the height!", true);
         return;
      }
      da.queueDraw();
      s = name.getText();
      if (!s.length)
      {
         report("You have not entered a name for the custom grid", true);
         return;
      }
      string fileName = expandTilde("~/.COMPO/userdef/");
      if (aw.config.iso)
         fileName ~= "ISO/";
      else
         fileName ~= "US/";
      fileName ~= s;
      save.setSensitive(1);
      if (!editing && exists(cast(char[]) fileName))
      {
         name.overrideColor(name.getStateFlags(), red);
         report("The name you have entered is already in use. You can save, but if you do you will overwrite the existing design.", true);
         return;
      }
      sheetName = s;
      ns.id = s;
      s = purpose.getText();
      ns.description = s;

      report("Everything is technically OK, you are good to save.", false);
   }

   string checkGrid()
   {
      if (g.topx < 0)
         return "The current design hangs over the left edge of the page.";
      if (g.topy < 0)
         return "The current design hangs over the top edge of the page.";
      double lim = aw.config.iso? 210: 8.5;
      double t = g.topx;
      for (int i = 0; i < g.cols-1; i++)
      {
         t += g.hstride;
      }
      t += g.w;
      if (t > lim)
         return "The current design hangs over the right edge of the page.";

      lim = aw.config.iso? 297: 11;
      t = g.topy;
      for (int i = 0; i < g.rows-1; i++)
      {
         t += g.vstride;
      }
      t += g.h;
      if (t > lim)
         return "The current design hangs over the bottom edge of the page.";
      return null;
   }

   bool getDecimal(Entry e, string s, out double val)
   {
      double d;
      bool problem;
      try
      {
         d = to!double(s);
      }
      catch (Exception x)
      {
         problem = true;
      }
      if (problem)
      {
         e.overrideColor(e.getStateFlags(), red);
         return false;
      }
      else
      {
         e.overrideColor(e.getStateFlags(), black);
         val = d;
         return true;
      }
   }

   void writeSheet()
   {
      string s = "";
      s ~= "grid=true\n";
      s ~= "iso=" ~ to!string(aw.config.iso) ~ "\n";
      s ~= "mfr=" ~ "User" ~ "\n";
      s ~= "id=" ~ ns.id ~ "\n";
      s ~= "description=" ~ ns.description ~ "\n";
      s ~= "category=" ~ to!string(cast(int) ns.category) ~ "\n";
      s ~= "paper=" ~ to!string(cast(int) ns.paper) ~ "\n";
      s ~= "seq=" ~ "false\n";

      s ~= "cols=" ~ to!string(g.cols) ~ "\n";
      s ~= "rows=" ~ to!string(g.rows) ~ "\n";
      s ~= "w=" ~ to!string(g.w) ~ "\n";
      s ~= "h=" ~ to!string(g.h) ~ "\n";
      s ~= "topx=" ~ to!string(g.topx) ~ "\n";
      s ~= "topy=" ~ to!string(g.topy) ~ "\n";
      s ~= "hstride=" ~ to!string(g.hstride) ~ "\n";
      s ~= "vstride=" ~ to!string(g.vstride) ~ "\n";
      s ~= "round=" ~ to!string(g.round) ~ "\n";

      string fileName = expandTilde("~/.COMPO/userdef/");
      if (aw.config.iso)
         fileName ~= "ISO/";
      else
         fileName ~= "US/";
      fileName ~= ns.id;
      std.file.write(fileName, s);
   }
}

class SequenceDlg: Dialog
{
   AppWindow aw;
   Layout layout;
   DrawingArea da;
   TextView tv;
   RGBA red, green, black, selectedColor;
   Widget save;
   Label ci;
   int pos;
   Entry xpos, ypos, wide, high, name, purpose;
   CheckButton isRound;
   Button add, remove, prev, next, vdate;
   LSRect[] rects;
   LSRect r;
   int tpw, tph;
   Sheet ns;
   string fileName;
   string sheetName;
   bool editing, adding, pending;

   this(AppWindow w, Sheet s)
   {
      editing = true;
      this(w);
      setTitle("Editing a Custom Grid Sheet");
      ns = loadSheet(w, s.id);
      rects = ns.layout.s.rects;
      name.setText(to!string(ns.id));
      purpose.setText(to!string(ns.description));
      setInfo(1, cast(int) rects.length);
      xpos.setText(to!string(rects[0].x));
      ypos.setText(to!string(rects[0].y));
      wide.setText(to!string(rects[0].w));
      high.setText(to!string(rects[0].h));
      add.setSensitive(1);
      remove.setSensitive(1);
      prev.setSensitive(1);
      next.setSensitive(1);
   }

   this(AppWindow w)
   {
      GtkResponseType rta[1] = [ ResponseType.CANCEL ];
      string[1] sa = [ "Cancel" ];
      super("Set Up a Sequence Sheet", w, DialogFlags.DESTROY_WITH_PARENT, sa, rta);
      addOnResponse(&responseHandler);
      save = addButton("Save", ResponseType.OK);
      save.setSensitive(0);
      aw = w;
      pos = 1;
      black = new RGBA(0,0,0,1);
      red = new RGBA(1,0,0,1);
      green = new RGBA(0,1,0,1);
      selectedColor = black;
      setSizeRequest(760, 390);
      if (aw.config.iso)
      {
         tpw = 210;
         tph = 297;
      }
      else
      {
         tpw = cast(int) (25.4*8.5);
         tph = cast(int) (25.4*11);
      }
      ns = Sheet(aw.config.iso, "User", "", "", Category.USER, Paper.A4, true);
      if (!aw.config.iso)
         ns.paper = Paper.US;

      layout = new Layout(null, null);
      VBox vb = getContentArea();
      vb.packStart(layout, 1, 1, 0);
      layout.show();
      addGadgets();
      add.setSensitive(0);
      remove.setSensitive(0);
      prev.setSensitive(0);
      next.setSensitive(0);
      da.show();
   }

   void responseHandler(int rt, Dialog d)
   {
      if (rt == ResponseType.OK)
      {
         writeSheet();
         if (!editing)
         {
            MenuItem mi = new MenuItem(&aw.mm.ssHandler, "User: "~sheetName);
            aw.mm.udefMenu.append(mi);
            mi.show();
         }
      }
      destroy();
   }

   void addGadgets()
   {
      int vp = 10;
      string s = "measurements in decimal " ~ (aw.config.iso? "mm.": "inches.");
      string s2 = "All sequence sheets are designed as Portrait. COMPO will deal with rotating them.\n";
      if (editing)
         s2 ~= "Edit as required, then validate. Use 'Add' to append an item to the list - ";
      else
         s2 ~= "Specify each separate area in turn, validate it, then add it - ";
      s2 ~= s;
      Label t = new Label(s2);
      t.show();
      layout.put(t, 10, vp);

      vp += 60;
      da = new DrawingArea(tpw, tph);
      da.addOnDraw(&drawCallback);

      Frame f = new Frame(da, null);
      f.setSizeRequest(204, 264);
      f.setShadowType(ShadowType.IN);
      layout.put(f, 540, vp);
      f.show();

      t = new Label("X position:");
      t.show();
      layout.put(t, 10, vp);
      xpos = new Entry();
      xpos.setWidthChars(14);
      xpos.show();
      layout.put(xpos, 150, vp);
      t = new Label("Y position:");
      t.show();
      layout.put(t, 290, vp);
      ypos = new Entry();
      ypos.setWidthChars(14);
      ypos.show();
      layout.put(ypos, 400, vp);

      vp += 30;
      t = new Label("Width:");
      t.show();
      layout.put(t, 10, vp);
      wide = new Entry();
      wide.setWidthChars(14);
      wide.show();
      layout.put(wide, 150, vp);
      t = new Label("Height:");
      t.show();
      layout.put(t, 290, vp);
      high = new Entry();
      high.setWidthChars(14);
      high.show();
      layout.put(high, 400, vp);

      vp += 25;
      isRound = new CheckButton("Item is round");
      isRound.show();
      layout.put(isRound, 10, vp);

      vp += 30;
      add = new Button("Add");
      add.addOnPressed(&bPressed);
      add.show();
      layout.put(add, 10, vp);
      remove = new Button("Remove");
      remove.addOnPressed(&bPressed);
      remove.show();
      layout.put(remove, 60, vp);
      prev = new Button("Prev");
      prev.addOnPressed(&bPressed);
      prev.show();
      layout.put(prev, 140, vp);
      next = new Button("Next");
      next.addOnPressed(&bPressed);
      next.show();
      layout.put(next, 190, vp);
      vdate = new Button("Validate");
      vdate.addOnPressed(&bPressed);
      vdate.show();
      layout.put(vdate, 240, vp);

      ci = new Label("");
      setInfo(1, cast(int)rects.length);
      ci.show();
      layout.put(ci, 350, vp);

      vp += 35;
      t = new Label("Name of sheet:");
      t.show();
      layout.put(t, 10, vp);
      name = new Entry();
      name.setSizeRequest(180, -1);
      name.show();
      layout.put(name, 150, vp);
      vp += 30;
      t = new Label("Purpose reminder:");
      t.show();
      layout.put(t, 10, vp);
      purpose = new Entry();
      purpose.setSizeRequest(180, -1);
      purpose.show();
      layout.put(purpose, 150, vp);

      vp +=25;
      Button b = new Button("Check Name");
      b.setSizeRequest(100, -1);
      b.addOnPressed(&checkName);
      b.show();
      layout.put(b, 10, vp);

      vp += 35;
      tv = new TextView();
      tv.setWrapMode(WrapMode.WORD);
      tv.setSizeRequest(505, 45);
      tv.setSensitive(0);
      f = new Frame(tv, null);
      f.show();
      layout.put(f, 10, vp);
      tv.show();
   }

   LSRect normalize(LSRect r)
   {
      if (aw.config.iso)
         return r;
      r.x *= 25.4;
      r.y *= 25.4;
      r.w *= 25.4;
      r.h *= 25.4;
      return r;
   }

   bool drawCallback(Context c, Widget widget)
   {
      void drawOne(LSRect lsr)
      {
         LSRect tr = normalize(lsr);
         if (tr.round)
         {
            c.arc(tr.x+tr.w/2, tr.y+tr.h/2, tr.w/2, 0, 2*PI);
         }
         else
         {
            c.moveTo(tr.x, tr.y);
            c.lineTo(tr.x+tr.w, tr.y);
            c.lineTo(tr.x+tr.w, tr.y+tr.h);
            c.lineTo(tr.x, tr.y+tr.h);
            c.closePath();
         }
         c.stroke();
      }

      c.setSourceRgba(1,1,1,1);
      c.paint();
      c.setLineWidth(0.5);
      foreach (int i, LSRect cr; rects)
      {
         c.setSourceRgb(0, 0, 0);
         drawOne(cr);
      }
      if (pending)
      {
         c.setSourceRgb(selectedColor.red, selectedColor.green, selectedColor.blue);
         drawOne(r);
      }
      selectedColor = black;
      return true;
   }

   void report(string s, bool alert)
   {
      tv.getBuffer().setText(s);
      tv.overrideColor(tv.getStateFlags(), alert? red: black);
   }

   void undo(Button b)
   {
      if (rects.length)
         rects.length = rects.length-1;
      da.queueDraw();
   }

   void setInfo(int pos, int n)
   {
      if (editing)
         ci.setText("Editing #"~to!string(pos)~" of "~to!string(n));
      else
         ci.setText("Creating item "~to!string(pos));
   }

   void bPressed(Button b)
   {
      string label = b.getLabel();
      double t;
      switch (label)
      {
      case "Add":
         if (editing)
         {
            adding = true;
            setInfo(cast(int)rects.length+1, cast(int)rects.length);
         }
         else
         {
            rects.length = rects.length+1;
            rects[rects.length-1] = r;
            pos = cast(int)rects.length;
            setInfo(pos+1, cast(int)rects.length);
         }
         pending = false;
         r.round = false;
         r.x = 0.0;
         r.y = 0.0;
         r.w = 0.0;
         r.h = 0.0;
         xpos.setText("");
         ypos.setText("");
         wide.setText("");
         high.setText("");
         add.setSensitive(0);
         remove.setSensitive(0);
         prev.setSensitive(0);
         next.setSensitive(0);
         selectedColor = black;
         da.queueDraw();
         break;
      case "Remove":
      {
         if (rects.length == 1)
         {
            xpos.setText("");
            ypos.setText("");
            wide.setText("");
            high.setText("");
            add.setSensitive(0);
            setInfo(pos, 1);
         }
         int apos = pos-1;
         if (apos == rects.length-1)
         {
            rects.length = rects.length-1;
            pos--;
            apos--;
         }
         else
         {
            for (int i = apos; i < rects.length-1; i++)
            {
               rects[i] = rects[i+1];
            }
         }
         xpos.setText(to!string(rects[apos].x));
         ypos.setText(to!string(rects[apos].y));
         wide.setText(to!string(rects[apos].w));
         high.setText(to!string(rects[apos].h));
         da.queueDraw();
         setInfo(pos, cast(int)rects.length);
      }
      break;
      case "Prev":
      {
         if (pos == 1)
            break;
         pos--;
         int apos = pos-1;
         xpos.setText(to!string(rects[apos].x));
         ypos.setText(to!string(rects[apos].y));
         wide.setText(to!string(rects[apos].w));
         high.setText(to!string(rects[apos].h));
         setInfo(pos, cast(int)rects.length);
         da.queueDraw();
      }
      break;
      case "Next":
      {
         if (pos == rects.length)
            break;
         pos++;
         int apos = pos-1;
         xpos.setText(to!string(rects[apos].x));
         ypos.setText(to!string(rects[apos].y));
         wide.setText(to!string(rects[apos].w));
         high.setText(to!string(rects[apos].h));
         setInfo(pos, cast(int) rects.length);
         da.queueDraw();
      }
      break;
      case "Validate":
      {
         pending = true;
         selectedColor = red;
         string s = xpos.getText();
         if (!s.length)
         {
            report("You have not entered a value for X position", true);
            da.queueDraw();
            return;
         }
         if (!getDecimal(xpos, s, t))
         {
            report("The entry for X position is not a valid decimal number.", true);
            return;
         }
         r.x = t;
         s = ypos.getText();
         if (!s.length)
         {
            report("You have not entered a value for Y position", true);
            da.queueDraw();
            return;
         }
         if (!getDecimal(ypos, s, t))
         {
            report("The entry for Y position is not a valid decimal number.", true);
            da.queueDraw();
            return;
         }
         r.y = t;
         s = wide.getText();
         if (!s.length)
         {
            report("You have not entered a value for Width", true);
            da.queueDraw();
            return;
         }
         if (!getDecimal(wide, s, t))
         {
            report("The entry for Width is not a valid decimal number.", true);
            return;
         }
         r.w = t;
         s = high.getText();
         if (!s.length)
         {
            report("You have not entered a value for Height", true);
            da.queueDraw();
            return;
         }
         if (!getDecimal(high, s, t))
         {
            report("The entry for Height is not a valid decimal number.", true);
            da.queueDraw();
            return;
         }
         r.h = t;
         string rv = checkRect(r);
         if (rv !is null)
         {
            report(rv, true);
            da.queueDraw();
            return;
         }

         if (isRound.getActive())
         {
            if (r.w != r.h)
            {
               report("You have specified the item to be round, but the width is not equal to the height!", true);
               return;
            }
            r.round = true;
         }
         //next.setSensitive(1);
         //prev.setSensitive(1);
         if (editing && !adding)
         {
            rects[pos-1] = r;
            report("Item updated", false);
            selectedColor = black;
         }
         else
         {
            if (adding)
            {
               rects.length = rects.length+1;
               pos = cast(int)rects.length;
               rects[pos-1] = r;
               report("Item validated and added", false);
               setInfo(pos, cast(int)rects.length);
               selectedColor = black;
               add.setSensitive(1);
               remove.setSensitive(1);
               prev.setSensitive(1);
               next.setSensitive(1);
            }
            else
            {
               report("Item validated", false);
               add.setSensitive(1);
               selectedColor = green;
            }
         }
         adding = false;
         da.queueDraw();
      }
      break;
      default:
         break;
      }
   }

   void checkName(Button b)
   {
      string s = name.getText();
      if (!s.length)
      {
         report("You have not entered a name for the custom sequence", true);
         return;
      }
      sheetName = s;
      string fileName = expandTilde("~/.COMPO/userdef/");
      if (aw.config.iso)
         fileName ~= "ISO/";
      else
         fileName ~= "US/";
      fileName ~= s;
      if (!editing && exists(cast(char[]) fileName))
      {
         name.overrideColor(name.getStateFlags(), red);
         report("The name you have entered is already in use. You can save, but you will overwrite the existing design.", true);
         return;
      }
      ns.id = s;
      s = purpose.getText();
      ns.description = s;

      report("Everything is technically OK, you are good to save.", false);

      save.setSensitive(1);
   }

   string checkRect(LSRect r)
   {
      if (r.x < 0)
         return "The current design hangs over the left edge of the page.";
      if (r.y < 0)
         return "The current design hangs over the top edge of the page.";
      double lim = aw.config.iso? 210: 8.5;
      if (r.x+r.w > lim)
         return "The current design hangs over the right edge of the page.";

      lim = aw.config.iso? 297: 11;
      if (r.y+r.h > lim)
         return "The current design hangs over the bottom edge of the page.";
      return null;
   }

   bool getDecimal(Entry e, string s, out double val)
   {
      double d;
      bool problem;
      try
      {
         d = to!double(s);
      }
      catch (Exception x)
      {
         problem = true;
      }
      if (problem)
      {
         e.overrideColor(e.getStateFlags(), red);
         return false;
      }
      else
      {
         e.overrideColor(e.getStateFlags(), black);
         val = d;
         return true;
      }
   }

   void writeSheet()
   {
      string s = "";
      s ~= "grid=false\n";
      s ~= "iso=" ~ to!string(aw.config.iso) ~ "\n";
      s ~= "mfr=" ~ "User" ~ "\n";
      s ~= "id=" ~ ns.id ~ "\n";
      s ~= "description=" ~ ns.description ~ "\n";
      s ~= "category=" ~ to!string(cast(int) ns.category) ~ "\n";
      s ~= "paper=" ~ to!string(cast(int) ns.paper) ~ "\n";
      s ~= "seq=" ~ "true\n";

      s ~= "scount=" ~ to!string(rects.length) ~ "\n";
      foreach (int i, LSRect r; rects)
      {
         s ~= to!string(i)~"="~to!string(r.round)~":";
         s ~= to!string(r.x)~"|"~to!string(r.y)~"|"~to!string(r.w)~"|"~to!string(r.h)~"\n";
      }
      string fileName = expandTilde("~/.COMPO/userdef/");
      if (aw.config.iso)
         fileName ~= "ISO/";
      else
         fileName ~= "US/";
      fileName ~= ns.id;
      std.file.write(fileName, s);
   }
}

Sheet scaleSheet(AppWindow aw, Sheet s)
{
   double sf = aw.screenRes;
   if (!s.iso)
      sf *= 24.5;

   if (s.seq)
   {
      Sequence seq = s.layout.s;
      foreach (ref LSRect r; seq.rects)
      {
         r.x *= sf;
         r.y *= sf;
         r.w *= sf;
         r.h *= sf;
      }
      s.layout.s = seq;
   }
   else
   {
      Grid g = s.layout.g;
      g.w *= sf;
      g.h *=sf;
      g.topx *= sf;
      g.topy *=sf;
      g.hstride *= sf;
      g.vstride *=sf;
      s.layout.g = g;
   }
   return s;
}

Sheet loadSheet(AppWindow aw, string name)
{
   string fileName = expandTilde("~/.COMPO/userdef/");
   if (aw.config.iso)
      fileName ~= "ISO/";
   else
      fileName ~= "US/";
   fileName ~= name;
   string s = cast(string) std.file.read(fileName);
   Sheet sheet;
   Grid g;
   string[] lines = split(s, "\n");
   string[] nv;
   if (lines[0] == "grid=true")
   {
      foreach (int i, string line; lines)
      {
         if (i >= 17) break;
         nv = split(line,"=");
         assert(nv.length == 2);
         assert(nv[0] == gridNames[i]);
         switch (i)
         {
         case 0:
            break;
         case 1:
            sheet.iso = to!bool(nv[1]);
            break;
         case 2:
            sheet.mfr = nv[1];
            break;
         case 3:
            sheet.id = nv[1];
            break;
         case 4:
            sheet.description = nv[1];
            break;
         case 5:
            sheet.category = cast(Category) to!int(nv[1]);
            break;
         case 6:
            sheet.paper = cast(Paper) to!int(nv[1]);
            break;
         case 7:
            sheet.seq = to!bool(nv[1]);
            break;
         case 8:
            g.cols = to!ushort(nv[1]);
            break;
         case 9:
            g.rows = to!ushort(nv[1]);
            break;
         case 10:
            g.w = to!double(nv[1]);
            break;
         case 11:
            g.h = to!double(nv[1]);
            break;
         case 12:
            g.topx = to!double(nv[1]);
            break;
         case 13:
            g.topy = to!double(nv[1]);
            break;
         case 14:
            g.hstride = to!double(nv[1]);
            break;
         case 15:
            g.vstride = to!double(nv[1]);
            break;
         case 16:
            g.round = to!bool(nv[1]);
            break;
         default:
            break;
         }
      }
      sheet.layout.g = g;
   }
   else
   {
      Sequence seq;
      foreach (int i, string line; lines)
      {
         if (i >= 8) break;
         nv = split(line,"=");
         assert(nv.length == 2);
         assert(nv[0] == gridNames[i]);
         switch (i)
         {
         case 0:
            break;
         case 1:
            sheet.iso = to!bool(nv[1]);
            break;
         case 2:
            sheet.mfr = nv[1];
            break;
         case 3:
            sheet.id = nv[1];
            break;
         case 4:
            sheet.description = nv[1];
            break;
         case 5:
            sheet.category = cast(Category) to!int(nv[1]);
            break;
         case 6:
            sheet.paper = cast(Paper) to!int(nv[1]);
            break;
         case 7:
            sheet.seq = to!bool(nv[1]);
            break;
         default:
            break;
         }
      }
      nv = split(lines[8],"=");
      assert(nv.length == 2);
      assert(nv[0] == "scount");
      int scount = to!int(nv[1]);
      seq.count = scount;
      int n = 0;

      for (size_t i = 9; i < lines.length; i++, n++)
      {
         LSRect r;
         if (lines[i].length == 0)
            break;
         nv = split(lines[i],"=");
         assert(nv.length == 2);
         assert(nv[0] == to!string(i-9));
         nv = split(nv[1], ":");
         r.round = to!bool(nv[0]);
         nv = split(nv[1], "|");
         assert(nv.length == 4);
         r.x = to!double(nv[0]);
         r.y = to!double(nv[1]);
         r.w = to!double(nv[2]);
         r.h = to!double(nv[3]);
         seq.rects ~= r;
      }
      assert(n == scount);
      sheet.layout.s = seq;
   }
   return sheet;
}

interface Portfolio
{
   int sheetCount();
   Sheet* sheetPtr();
}

class SheetLib
{
   Sheet[] all;
   string[][string] mfrParts;
   int[string] specific;
   int[string][8] byCats;
   string[] menuStrings;
   AppWindow aw;

   this(AppWindow w, bool iso)
   {
      aw = w;
      Portfolio p;
      if (iso)
      {
         p = new GenericISO();
         addSheets(p);
         p = new AveryISO();
         addSheets(p);
      }
      else
      {
         p = new GenericUS();
         addSheets(p);
         p = new AveryUS();
         addSheets(p);
      }
   }

   void addSheets(Portfolio p)
   {
      int n = p.sheetCount();
      Sheet* sp = p.sheetPtr();
      size_t j = all.length;
      all.length = all.length+n;
      for (int i = 0; i < n; i++, sp++, j++)
      {
         if (sp.category == Category.SEPARATOR)
         {
            mfrParts[sp.mfr] ~= "---".idup;
            continue;
         }
         all[j] = *sp;
         string key = sp.mfr~": "~sp.id ;
         mfrParts[sp.mfr] ~= sp.id~" - "~sp.description;
         specific[key] = cast(int) j;
         byCats[sp.category][key] = cast(int) j;
      }
   }

   string[] getMenuForMfr(string mfr)
   {
      string[] t = mfrParts[mfr];
      return t;
   }

   // Most sheets will probably never be used, so just scale them when asked for.
   void realizeSheet(Sheet* s)
   {
      if (s.scaled)
         return;
      double sf = aw.screenRes;
      if (!s.iso)
         sf *= 25.4;  // from inches
      if (s.seq)
      {
         for (int i = 0; i < s.layout.s.count; i++)
         {
            s.layout.s.rects[i].x *= sf;
            s.layout.s.rects[i].y *= sf;
            s.layout.s.rects[i].w *= sf;
            s.layout.s.rects[i].h *= sf;
         }
      }
      else
      {
         s.layout.g.w *= sf;
         s.layout.g.h *= sf;
         s.layout.g.topx *=sf;
         s.layout.g.topy *= sf;
         s.layout.g.hstride *= sf;
         s.layout.g.vstride *= sf;
      }
      s.scaled = true;
   }

   Sheet getSheet(string mfrPart)
   {
      int i = specific[mfrPart];
      Sheet t =  all[i];
      realizeSheet(&t);
      return t;
   }

   string[] getMenuForUser()
   {
      string xlate(string fp)
      {
         string[] a =fp.split("/");
         string s = a[$-1];
         return "User: "~s;
      }

      string[] list;
      string path = "userdef/"~(aw.config.iso? "ISO": "US");
      string cfp = getConfigPath(path);
      foreach (string fp; dirEntries(cfp, SpanMode.depth))
      {
         list ~= xlate(fp);
      }
      return list;
   }
}
