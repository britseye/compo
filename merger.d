
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module merger;

import std.stream;
import std.file;
import std.conv;
import std.path;
import std.stdio;
import std.array;
import std.regex;
import std.string;
import std.datetime;

import acomp;
import tvitem;
import main;
import csv;
import textsrc;
import text;
import common;

import gtkc.gtktypes;
import gtk.Dialog;
import gtk.VBox;
import gtk.Layout;
import gtk.Label;
import gtk.Entry;
import gtk.Button;
import gtk.ToggleButton;
import gtk.RadioButton;
import gtk.CheckButton;
import gtk.Notebook;
import gtk.ComboBoxText;
import gtk.TextView;
import gtk.Frame;
import gtk.FileChooserDialog;
import gtk.FileFilter;

interface MergeSource
{
   void setPerPage(int n);
   void setCols(int n);
   string[] getFirstLine();
   int getColumns();
   string[][] getNextPage(bool skipFirstLine);
   bool valid();
   string getFailReason();
   void disconnect();
}

struct MergeData
{
   bool textMerge, stripLines, stripSpaces, useColNames;
   string fileName, compoFile;
   int validity, perPage, mergeType;
   string delimiter;
   string dataSrc;
   string dataBase;
   string query;
   string spec;
}

// Pages
// 1. Merge spec and method
// 2. CSV setup
// 3. MySQL setup
class MergeDialog: Dialog
{
   AppWindow aw;
   Label fnl;
   RadioButton rb;
   CheckButton sel, ses, ucn;
   TextView spec, tv;
   ComboBoxText mtcb;
   Entry delim;
   MergeSource ms;
   MergeData md;
   string mdFileName;

   this(AppWindow w)
   {
      GtkResponseType rta[2] = [ ResponseType.CANCEL, ResponseType.OK ];
      string[2] sa = [ "Cancel", "OK" ];
      super("Setup for Merge", w, DialogFlags.DESTROY_WITH_PARENT, sa, rta);
      setSizeRequest(500, 500);
      aw = w;
      mdFileName = getConfigPath("COMPOMergeSettings");

      addOnResponse(&responseHandler);
      Notebook nb = new Notebook();
      VBox vb = getContentArea();
      vb.packStart(nb, 1, 1, 0);
      nb.show();

      Layout p1Layout = new Layout(null, null);
      p1Layout.show();
      addP1Gadgets(p1Layout);
      nb.appendPage(p1Layout, "Merge Specification");

      Layout p2Layout = new Layout(null, null);
      p2Layout.show();
      addP2Gadgets(p2Layout);
      nb.appendPage(p2Layout, "Text Source Options");

      Layout p3Layout = new Layout(null, null);
      p3Layout.show();
      nb.appendPage(p3Layout, "MySQL Options");

      if (recoverMD(md))
         syncControls();
      else
      {
         md.stripSpaces = md.stripLines = md.textMerge = true;
         md.textMerge = true;
      }
   }

   void saveMD(MergeData md)
   {
      string s = "";
      s ~= to!string(md.textMerge) ~ "\n";
      s ~= to!string(md.stripLines) ~ "\n";
      s ~= to!string(md.stripSpaces) ~ "\n";
      s ~= to!string(md.useColNames) ~ "\n";
      s ~= md.fileName ~ "\n";
      s ~= md.compoFile ~ "\n";
      s ~= to!string(md.validity) ~ "\n";
      s ~= to!string(md.perPage) ~ "\n";
      s ~= to!string(md.mergeType) ~ "\n";
      s ~= md.delimiter ~ "\n";
      s ~= md.dataSrc ~ "\n";
      s ~= md.dataBase ~ "\n";
      s ~= md.query ~ "\n";
      s ~= "|^^|" ~ md.spec ~ "\n";
      std.file.write(mdFileName, s);
   }

   bool recoverMD(ref MergeData md)
   {
      string s;
      try
      {
         s = cast(string) std.file.read(mdFileName);
      }
      catch (Exception x)
      {
         return false;
      }
      string[] sa = split(s, "|^^|");
      md.spec = sa[1];

      sa = split(sa[0], "\n");
      md.textMerge = to!bool(sa[0]);
      md.stripLines = to!bool(sa[1]);
      md.stripSpaces = to!bool(sa[2]);
      md.useColNames = to!bool(sa[3]);
      md.fileName = sa[4];
      md.compoFile = sa[5];
      md.validity = to!int(sa[6]);
      md.perPage = to!int(sa[7]);
      md.mergeType = to!int(sa[8]);
      md.delimiter = sa[9];
      md.dataSrc = sa[10];
      md.dataBase = sa[11];
      md.query = sa[12];

      return true;
   }

   void syncControls()
   {
      fnl.setText(md.fileName);
      bool old = md.textMerge;
      rb.setActive(md.textMerge);
      md.textMerge = old;
      old = md.stripLines;
      int oldmt = md.mergeType;
      mtcb.setActive(md.mergeType);
      md.mergeType = oldmt;
      delim.setText(md.delimiter);
      if (md.mergeType == 2)
         delim.setSensitive(1);
      sel.setActive(md.stripLines);
      md.stripLines = old;
      old = md.stripSpaces;
      ses.setActive(md.stripSpaces);
      md.stripSpaces = old;
      old = md.useColNames;
      ucn.setActive(md.useColNames);
      md.useColNames = old;
      if (md.compoFile == aw.cfn)
      {
         if(timeLastModified(mdFileName) > timeLastModified(aw.cfn, SysTime.min))
            spec.getBuffer().setText(md.spec);
      }
   }

   void responseHandler(int rt, Dialog d)
   {
      if (ms !is null) ms.disconnect();
      if (rt == ResponseType.OK)
      {
         md.validity = 1;  // i.e. to be determined
         md.spec = spec.getBuffer().getText();
         md.delimiter = delim.getText();
         aw.merger.clear();
         aw.merger.setMergeData(md);
         saveMD(md);
      }
   }

   void addP1Gadgets(Layout p1)
   {
      int vp = 10;
      Label l = new Label("Merge specification as loaded is shown.\nYou may modify or create as required");
      p1.put(l, 10, 10);
      l.show();
      vp += 40;

      spec = new TextView();
      spec.setSizeRequest(450, 250);
      spec.show();

      Frame f = new Frame(spec, null);
      f.show();
      p1.put(f, 10, vp);

      string text;
      if (aw.tm.root.children.length > 0)
      {
         ACBase acb = aw.tm.root.children[0];
         if (acb.type < AC_RICHTEXT)
         {
            TextViewItem tvi = cast(TextViewItem) acb;
            text = tvi.tb.getText();
            spec.getBuffer().setText(text);
         }
         md.compoFile = aw.cfn;
      }

      vp += 270;
      rb = new RadioButton("Text file source, e.g. CSV or COMPO format.");
      rb.addOnToggled(&rbToggled);
      p1.put(rb, 10, vp);
      rb.show();
      vp += 20;
      RadioButton rb2 = new RadioButton(rb, "MySQL database lookup");
      rb2.addOnToggled(&rbToggled);
      p1.put(rb2, 10, vp);
      rb2.show();

      vp += 30;

      sel = new CheckButton("Strip out empty lines");
      sel.addOnToggled(&cbLinesToggled);
      p1.put(sel, 10, vp);
      sel.setActive(1);
      sel.show();

      ucn = new CheckButton("Using column names");
      ucn.addOnToggled(&cbColumnNames);
      p1.put(ucn, 250, vp);
      ucn.show();

      if (text !is null)
      {
         if (detectColumnNames(text))
            ucn.setActive(1);
      }

      vp += 20;

      ses = new CheckButton("Strip out extraneous spaces");
      ses.addOnToggled(&cbSpacesToggled);
      p1.put(ses, 10, vp);
      ses.setActive(1);
      ses.show();
   }

   void rbToggled(ToggleButton b)
   {
      md.textMerge = false;
      if (rb.getActive())
         md.textMerge = true;
   }

   void cbLinesToggled(ToggleButton b)
   {
      md.stripLines = !md.stripLines;
   }

   void cbSpacesToggled(ToggleButton b)
   {
      md.stripSpaces = !md.stripSpaces;
   }

   void cbColumnNames(ToggleButton b)
   {
      md.useColNames = !md.useColNames;
   }

   void addP2Gadgets(Layout p2)
   {
      int vp = 10;
      Label l = new Label("Choose file format:");
      p2.put(l, 10, 10);
      l.show();
      mtcb = new ComboBoxText();
      mtcb.addOnChanged(&cbChanged);
      mtcb.appendText("COMPO delimited text");
      mtcb.appendText("Classic commas and quotes CSV");
      mtcb.appendText("User defined delimiter");
      mtcb.show();
      p2.put(mtcb, 150, vp);

      vp += 30;

      l = new Label("Arbitrary delimiter\n(if required):");
      l.setTooltipText("You can enter \\t for tab delimited text");
      p2.put(l, 10, vp);
      l.show();
      delim = new Entry();
      delim.setSensitive(0);
      delim.setSizeRequest(160, -1);
      delim.show();
      p2.put(delim, 150, vp+10);

      mtcb.setActive(0);

      vp += 45;

      Button b = new Button("Choose Merge Source");
      b.addOnPressed(&chooseSrc);
      b.setSizeRequest(160, -1);
      b.show();
      p2.put(b, 150, vp);

      vp += 30;

      b = new Button("Test Merge Source");
      b.addOnPressed(&testSrc);
      b.setSizeRequest(160, -1);
      b.show();
      p2.put(b, 150, vp);

      vp += 35;

      fnl = new Label("Selected file: ");
      p2.put(fnl, 10, vp);
      fnl.show();

      vp += 25;

      l = new Label("First line values:");
      p2.put(l, 10, vp);
      l.show();
      tv = new TextView();
      tv.setSizeRequest(400, 200);
      tv.setSensitive(0);
      tv.show();

      Frame f = new Frame(tv, null);
      f.show();
      p2.put(f, 10, vp+20);
   }

   void cbChanged(ComboBoxText cb)
   {
      md.mergeType= cb.getActive();
      if (md.mergeType == 0)
         delim.setText("|^~|");

      else if (md.mergeType == 1)
      {
         delim.setText("");
      }
      else
      {
         delim.setSensitive(1);
         delim.setText("");
      }
   }

   void chooseSrc(Button b)
   {
      FileChooserDialog fcd = new FileChooserDialog("Choose Text Source File", aw, FileChooserAction.OPEN);
      FileFilter filter = new FileFilter();
      filter.setName("CSV files (*.compo)");
      filter.addPattern("*.csv");
      filter.addPattern("*.addresses");
      filter.addPattern("*.txt");
      fcd.setFilter(filter);
      fcd.setCurrentFolder(expandTilde("~"));

      int response = fcd.run();
      if (response != ResponseType.OK)
      {
         fcd.destroy();
         return;
      }
      md.fileName = fcd.getFilename();
      fcd.destroy();
      fnl.setText("Selected File: " ~ md.fileName);
   }

   void testSrc(Button b)
   {
      if (md.fileName is null)
      {
         aw.popupMsg("No file name chosen yet!", MessageType.WARNING);
      }
      switch (md.mergeType)
      {
      case 0:
         ms = new COMPOSrc(aw, md.fileName, "|^~|");
         break;
      case 1:
         ms = new CSVArray(aw, md.fileName);
         break;
      case 2:
         string dt = delim.getText();
         if (dt.length == 0)
         {
            aw.popupMsg("You need to enter a delimiter for this type of file", MessageType.WARNING);
            return;
         }
         if (dt == "\\t")
            dt = "\t";
         ms = new COMPOSrc(aw, md.fileName, dt);
         break;
      default:
         return;
      }
      if (ms.valid())
      {
         string[] fl = ms.getFirstLine();
         string disp = to!string(fl.length) ~ " columns:\n";
         foreach (string s; fl)
         disp ~= s ~ "\n";
         tv.insertText(disp);
      }
      else
         aw.popupMsg("Error instantiating source: " ~ ms.getFailReason(), MessageType.ERROR);
   }

   bool detectColumnNames(string s)
   {
      auto a = regex("[A-Za-z_ ]");
      auto all = regex(r"\[[A-Za-z0-9_][A-Za-z0-9_ ]*\]");
      foreach(m; match(s, all))
      {
         auto xm = match(m.hit, a);
         if (!xm.empty())
         {
            return true;
         }
      }
      return false;
   }
}

struct SpecFragment
{
   bool isFixed;
   union
   {
      int colno;
      string fixed;
   }
}

class Merger
{
   AppWindow aw;
   MergeData md;
   int perPage, cols;
   MergeSource ms;
   string[][] pgItems;
   string[] firstLine;
   int[string] colLookup;
   SpecFragment[] fa;
   PlainText[] pageItems;
   string[] texts;
   int total, curPos, pages;
   bool loaded;

   this(AppWindow w)
   {
      aw= w;
   }

   void setMergeData(MergeData d)
   {
      md = d;
   }

   bool beginMerge()
   {
      if (md.validity == 0)
      {
         aw.popupMsg("There is no information about what kind of\nMerge is required. Did you do Merge Setup?",
                     MessageType.WARNING);
         return false;
      }
      if (md.textMerge)
      {
         if (md.fileName is null || md.fileName.length == 0)
         {
            aw.popupMsg("There is no information about what kind of\nMerge is required. Did you do Merge Setup?",
                        MessageType.WARNING);
            return false;
         }
         if (md.mergeType == 2 && (md.delimiter is null || md.delimiter.length == 0))
         {
            aw.popupMsg("You set up for a merge using a user-defined delimiter,\nbut did not enter the delimiter to be used.",
                        MessageType.WARNING);
            return false;
         }
         switch (md.mergeType)
         {
         case 0:
            ms = new COMPOSrc(aw, md.fileName, "|^~|");
            break;
         case 1:
            ms = new CSVArray(aw, md.fileName);
            break;
         case 2:
            string delim = md.delimiter;
            if (delim == "\\t")
               delim = "\t";
            ms = new COMPOSrc(aw, md.fileName, delim);
            break;
         default:
            return false;
         }
      }
      else
      {
         // MySQL case TBD
         return false;
      }
      firstLine = ms.getFirstLine();
      cols = ms.getColumns();
      if (md.useColNames)
      {
         foreach (int i, string s; firstLine)
         colLookup[s] = i;
      }
      fa = parseSpec();
      if (fa is null)
      {
         md.validity = 0;
         return false;
      }

      perPage = aw.pageLayout.perPage();
      pageItems.length = perPage;
      ms.setPerPage(perPage);
      md.validity = 2;


      total = 0;
      for (;;)
      {
         pgItems = ms.getNextPage(md.useColNames);
         if (!ms.valid())
         {
            string s = ms.getFailReason();
            aw.popupMsg("Failed to get page of items from file: " ~ s, MessageType.ERROR);
            return false;
         }
         if (!pgItems.length)
            break;
         foreach (string[] sa; pgItems)
         {
            string s = instantiate(sa);
            texts ~= s;
            total++;
         }
         if (pgItems.length < perPage)
            break;
      }
      pages = total/perPage;
      if (total%perPage)
         pages++;

      bool awDirty = aw.dirty;
      for (int i = 0; i < perPage; i++)
      {
         pageItems[i] = new PlainText(aw, null);
         pageItems[i].width = cast(int) aw.cWidth;
         pageItems[i].height = cast(int) aw.cHeight;
         // Keep PageLayout happy
         pageItems[i].parent = pageItems[i];
      }
      aw.dirty = awDirty;
      curPos = 0;
      loaded = true;
      return true;
   }

   void clear()
   {
      texts.length = 0;
      total = 0;
      curPos = 0;
      pageItems.length = 0;
      aw.pageLayout.fill(false);
   }

   void mergeOnePage()
   {
      if (curPos >= total)
      {
         aw.popupMsg("The merge is complete", MessageType.INFO);
         clear();
         aw.printHandler.dropContext();
         return;
      }
      aw.printHandler.setPages(1);
      pages--;
      aw.printHandler.setMerger(this, true);
      aw.printHandler.printMerge();
   }

   void mergeAll()
   {
      aw.printHandler.setPages(pages);
      aw.printHandler.setMerger(this);
      aw.printHandler.printMerge();
      clear();
   }

   void fillLayout()
   {
      int toFill;
      if (total - curPos >= perPage)
         toFill = perPage;
      else
         toFill = total-curPos;
      for (int i = 0; i < toFill; i++)
         pageItems[i].tb.setText(texts[curPos++]);
      aw.pageLayout.fillFrom(toFill, pageItems);
   }

   string instantiate(string[] a)
   {
      string s = "";
      foreach (SpecFragment sf; fa)
      {
         if (sf.isFixed)
            s ~= sf.fixed;
         else
            s ~= a[sf.colno];
      }
      string[] lines = split(s, "\n");
      if (md.stripSpaces)
      {
         for (int i = 0; i < lines.length; i++)
         {
            if (lines[i].length == 0)
               continue;
            lines[i] = strip(lines[i]);
            lines[i] = replace(lines[i], regex(r"\s\s*", "g"), " ");
            if (lines[i] == " ")
               lines[i] = "";
         }
      }
      string stripped = "";
      bool first = true;
      foreach (ts; lines)
      {
         if (md.stripLines && ts.length == 0)
            continue;
         if (!first)
            stripped ~= "\n";
         first = false;
         stripped ~= ts;
      }

      return stripped;
   }

   SpecFragment[] parseSpec()
   {
      SpecFragment[] lfa;
      SpecFragment temp;
      auto rex = md.useColNames? regex(r"\[[A-Za-z0-9_][A-Za-z0-9_ ]*\]"):
                 regex(r"\[[1-9][0-9]*\]");
      int lastPos = 0, index = -1;
      foreach (m; match(md.spec, rex))
      {
         string colSpec = m.hit;
         string actual = colSpec[1..$-1];
         if (md.useColNames)
         {
            foreach (int i, string s; firstLine)
            {
               // columns can be in any order. There may be more columns than
               // references in the marge spec, or of course, fewer. We need to store a column number.
               if (s == actual)
               {
                  index = i;
                  break;
               }
            }
            if (index == -1)
            {
               aw.popupMsg("Column name from merge specification not in the first line", MessageType.ERROR);
               return null;
            }
         }
         else
         {
            index = to!int(actual);
            if (index > cols)
            {
               aw.popupMsg("Column number from merge specification greater\nthan number of columns in first line", MessageType.ERROR);
               return null;
            }
         }
         int pos = md.spec.indexOf(colSpec);
         temp.isFixed = true;
         temp.fixed = md.spec[lastPos..pos].idup;
         lfa ~= temp;
         temp.isFixed = false;
         temp.colno = index;
         lfa ~= temp;
         lastPos = pos+colSpec.length;
      }
      if (lastPos < md.spec.length)
      {
         temp.isFixed = true;
         temp.fixed = md.spec[lastPos..$].idup;
         lfa ~= temp;
      }
      return lfa;
   }
}


