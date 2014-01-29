
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module config;

import std.stdio;
import std.conv;
import std.path;
import std.array;
import std.string;
import std.file;

import common;
import acomp;

import gdk.Event;
import gtk.Widget;
import gtk.VBox;
import gtk.Layout;
import gtk.Label;
import gtk.Dialog;

immutable string isoGrid =
   "grid=true\niso=true\nmfr=User\nid=GridExample\ndescription=Just to show how\ncategory=8\npaper=0\nseq=false\ncols=2\nrows=8\nw=95\nh=30\ntopx=8\ntopy=10\nhstride=100\nvstride=35\nround=false";

immutable string isoSeq =
   "grid=false\niso=true\nmfr=User\nid=SequenceExample\ndescription=Just to show how\ncategory=8\npaper=0\nseq=true\nscount=3\n0=false:10|10|20|20\n1=false:30|30|30|30\n2=false:10|100|150|150";

immutable string usGrid =
   "grid=true\niso=false\nmfr=User\nid=GridExample\ndescription=Just to show how\ncategory=8\npaper=1\nseq=false\ncols=2\nrows=8\nw=3.5\nh=1.0\ntopx=0.3\ntopy=0.39\nhstride=3.75\nvstride=1.125\nround=false";
immutable string usSeq =
   "grid=false\niso=false\nmfr=User\nid=SequenceExample\ndescription=Just to show how\ncategory=8\npaper=1\nseq=true\nscount=3\n0=false:0.4|0.4|1.0|1.0\n1=false:2.5|2.5|2.0|2.0\n2=false:0.4|5.0|3.0|3.0";

struct COMPOConfig
{
   bool iso = true;
   bool maximize = false;
   bool landscape = false;
   int width = 800;
   int height = 600;
   int defaultSAItemType = cast(int) AC_TEXT;
   int undoStackLength = 20;
   int controlsPos;                                       // 0 below, 1 left, 2 floating
   int polySides = 6;
   int defMorph = 0;                                    // Fit the area
   string defaultISOLayout = "Avery: 7414";     // an ISO business card
   string defaultUSLayout = "Avery: 5371";            // std business card
   string defaultISOStandaloneLayout = "Avery: 7160";
   string defaultUSStandaloneLayout = "Avery: 5160";
   string defaultFont = "Sans 10";
   string USPSFont = "Sans 10";
   string USPSBarcodeID = "00";
   string USPSServiceType = "702";
   string USPSCustomerID = "900000000";
   string defaultFolder = "~";
   double printerTrimX = 0.0;
   double printerTrimY = 0.0;
}

struct Recent
{
   int count;
   string lastOpenFolder;
   string lastSaveFolder;
   string lastImageFolder;
   string[5] recent;
}

void readRecent(Recent* rp)
{
   string cp = getConfigPath("recent");
   if (exists(cast(char[]) cp))
   {
      string recent = cast(string) std.file.read(cp);
      string[] sa = split(recent,"\n");
      foreach (int i, string s; sa)
      {
         if (i >= 9)
            break;
         string[] nv = split(s, "=");
         switch (i)
         {
         case 0:
            assert(nv[0] == "count");
            rp.count = to!int(nv[1]);
            break;
         case 1:
            assert(nv[0] == "lastOpenFolder");
            rp.lastOpenFolder = nv[1].idup;
            break;
         case 2:
            assert(nv[0] == "lastSaveFolder");
            rp.lastSaveFolder = nv[1].idup;
            break;
         case 3:
            assert(nv[0] == "lastImageFolder");
            rp.lastImageFolder = nv[1].idup;
            break;
         default:
            assert(nv[0] == "file" ~ to!string(i-4));
            rp.recent[i-4] = nv[1].idup;
            break;
         }
      }
      eliminateNonExistent(rp);
   }
   else
   {
      string home = expandTilde("~");
      std.file.write(cp, "count=0\nlastOpenFolder="~home~"\nlastSaveFolder="~home~"\nlastImageFolder="~home~"\nfile0=\nfile1=\nfile2=\nfile3=\nfile4=");
   }
}

void eliminateNonExistent(Recent* rp)
{
   int ac = 0;
   string[5] ta;
   for (int i = 0; i < rp.count; i++)
   {
      if (exists(rp.recent[i]))
      {
         ta[ac]= rp.recent[i].idup;
         ac++;
      }
   }
   rp.recent[] = ta[0..$];
   rp.count = ac;
}

void writeRecent(Recent r)
{
   string s = "count=" ~ to!string(r.count) ~ "\n";
   s ~= "lastOpenFolder=" ~ r.lastOpenFolder ~ "\n";
   s ~= "lastSaveFolder=" ~ r.lastSaveFolder ~ "\n";
   s ~= "lastImageFolder=" ~ r.lastImageFolder ~ "\n";
   s ~= "file0=" ~ r.recent[0] ~ "\n";
   s ~= "file1=" ~ r.recent[1] ~ "\n";
   s ~= "file2=" ~ r.recent[2] ~ "\n";
   s ~= "file3=" ~ r.recent[3] ~ "\n";
   s ~= "file4=" ~ r.recent[4] ~ "\n";
   std.file.write(getConfigPath("recent"), s);
}

class ISODlg: Dialog
{
   Layout layout;

   this()
   {
      string[2] sa = [ "ISO/Metric", "US/Inches" ];
      super("COMPO First Run", null, DialogFlags.DESTROY_WITH_PARENT, sa, [ResponseType.NO, ResponseType.YES]);
      setSizeRequest(300, 100);
      this.addOnDelete(&catchClose);
      layout = new Layout(null, null);
      VBox vb = getContentArea();
      vb.packStart(layout, 1, 1, 0);
      layout.show();
      addGadgets();
   }

   bool catchClose(Event e, Widget w)
   {
      return true;
   }

   void addGadgets()
   {
      Label l = new Label("Please choose a system.");
      layout.put(l, 50, 15);
      l.show();
   }
}

COMPOConfig getConfig()
{
   COMPOConfig cfg;
   string cp = getConfigPath("config");
   if (exists(cast(char[]) cp))
      return readConfig(cp);
   else
   {
      bool iso;
      ISODlg d = new ISODlg();
      int response = d.run();
      d.destroy();
      if (response == 1)
         iso = true;
      createConfig(cfg, iso);
      cp = getConfigPath("userdef/");
      std.file.write(cp~"ISO/GridExample", isoGrid);
      std.file.write(cp~"ISO/SequenceExample", isoSeq);
      std.file.write(cp~"US/GridExample", usGrid);
      std.file.write(cp~"US/SequenceExample", usSeq);
      return cfg;
   }
}

immutable string[] pNames = [
                               "iso",
                               "maximize",
                               "landscape",
                               "width",
                               "height",
                               "defaultSAItemType",
                               "undoStackLength",
                               "controlsPos",
                               "polySides",
                               "defMorph",
                               "defaultISOLayout",
                               "defaultUSLayout",
                               "defaultISOStandaloneLayout",
                               "defaultUSStandaloneLayout",
                               "defaultFont",
                               "USPSFont",
                               "USPSBarcodeID",
                               "USPSServiceType",
                               "USPSCustomerID",
                               "defaultFolder",
                               "printerTrimX",
                               "printerTrimY"
                            ];



COMPOConfig readConfig(string cp)
{
   COMPOConfig cfg;
   string s = cast(string) std.file.read(cp);
   string[] lines = split(s, "\n");
   int i = 0;
   foreach (string pv; lines)
   {
      if (pv.indexOf("//") == 0 || pv.strip().length == 0)
         continue;
      string[] sa = split(pv, "=");
      if (sa.length != 2)
         throw new Exception("Broken config file missing '='");
      if (sa[0]  != pNames[i])
         throw new Exception("Broken config file unexpected property name");
      switch (i)
      {
      case 0:
         cfg.iso = to!bool(sa[1]);
         break;
      case 1:
         cfg.maximize = to!bool(sa[1]);
         break;
      case 2:
         cfg.landscape = to!bool(sa[1]);
         break;
      case 3:
         cfg.width = to!int(sa[1]);
         break;
      case 4:
         cfg.height = to!int(sa[1]);
         break;
      case 5:
         cfg.defaultSAItemType = to!int(sa[1]);
         break;
      case 6:
         cfg.undoStackLength = to!int(sa[1]);
         break;
      case 7:
         cfg.controlsPos = to!int(sa[1]);
         break;
      case 8:
         cfg.polySides = to!int(sa[1]);
         break;
      case 9:
         cfg.defMorph = to!int(sa[1]);
         break;
      case 10:
         cfg.defaultISOLayout = sa[1];
         break;
      case 11:
         cfg.defaultUSLayout = sa[1];
         break;
      case 12:
         cfg.defaultISOStandaloneLayout = sa[1];
         break;
      case 13:
         cfg.defaultUSStandaloneLayout = sa[1];
         break;
      case 14:
         cfg.defaultFont = sa[1];
         break;
      case 15:
         cfg.USPSFont = sa[1];
         break;
      case 16:
         cfg.USPSBarcodeID = sa[1];
         break;
      case 17:
         cfg.USPSServiceType = sa[1];
         break;
      case 18:
         cfg.USPSCustomerID = sa[1];
         break;
      case 19:
         cfg.defaultFolder = sa[1];
         break;
      case 20:
         cfg.printerTrimX = to!double(sa[1]);
         break;
      case 21:
         cfg.printerTrimY = to!double(sa[1]);
         break;
      default:
         throw new Exception("Config file broken - too many entries");
      }
      i++;
   }

   return cfg;
}

void createConfig(COMPOConfig cfg, bool iso)
{
   string cp = "~/.COMPO";
   cp = expandTilde(cp);
   if (!exists(cp))
   {
      mkdir(cp);
      string more = cp ~ "/userdef";
      mkdir(more);
      string nextdir = more ~ "/ISO";
      mkdir(nextdir);
      nextdir = more ~ "/US";
      mkdir(nextdir);
   }
   string s = "// Don't edit this file. If you do, COMPO may well be broken!!!\n";
   s ~= "iso="~ to!string(iso) ~ "\n";
   s ~= "maximize="~ to!string(cfg.maximize) ~ "\n";
   s ~= "landscape="~ to!string(cfg.landscape) ~ "\n";
   s ~= "width="~ to!string(cfg.width) ~ "\n";
   s ~= "height="~ to!string(cfg.height) ~ "\n";
   s ~= "defaultSAItemType="~ to!string(cfg.defaultSAItemType) ~ "\n";
   s ~= "undoStackLength="~ to!string(cfg.undoStackLength) ~ "\n";
   s ~= "controlsPos="~ to!string(cfg.controlsPos) ~ "\n";
   s ~= "polySides="~ to!string(cfg.polySides) ~ "\n";
   s ~= "defMorph="~ to!string(cfg.defMorph) ~ "\n";
   s ~= "defaultISOLayout="~ cfg.defaultISOLayout ~ "\n";
   s ~= "defaultUSLayout="~ cfg.defaultUSLayout ~ "\n";
   s ~= "defaultISOStandaloneLayout="~ cfg.defaultISOStandaloneLayout ~ "\n";
   s ~= "defaultUSStandaloneLayout="~ cfg.defaultUSStandaloneLayout ~ "\n";
   s ~= "defaultFont="~ cfg.defaultFont ~ "\n";
   s ~= "USPSFont="~ cfg.USPSFont ~ "\n";
   s ~= "USPSBarcodeID="~ cfg.USPSBarcodeID ~ "\n";
   s ~= "USPSServiceType="~ cfg.USPSServiceType ~ "\n";
   s ~= "USPSCustomerID="~ cfg.USPSCustomerID ~ "\n";
   s ~= "defaultFolder="~ expandTilde(cfg.defaultFolder) ~ "\n";
   s ~= "printerTrimX="~ to!string(cfg.printerTrimX) ~ "\n";
   s ~= "printerTrimY="~ to!string(cfg.printerTrimY) ~ "\n";
   std.file.write(cp~"/config", s);
}
