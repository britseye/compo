
//          Copyright Steve Teale 2011 - 2014.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module acomp;

import mainwin;
import constants;
import types;
import common;
import controlset;
import container;
import controlsdlg;
import sheets;
import graphics;
import interfaces;

import std.stdio;
import std.conv;
import std.math;
import std.array;
import std.format;
import std.uuid;

import core.memory;
import gtkc.gtktypes;
import gtk.Widget;
import gtk.Entry;
import gtk.TextView;
import gtk.TextBuffer;
import gtk.ToggleButton;
import gtk.CheckButton;
import gtk.Button;
import gtk.EventBox;
import gtk.Label;
import gtk.ComboBoxText;
import gdk.Event;
import gdk.RGBA;
import gtk.Layout;
import gtk.DrawingArea;
import gtk.Frame;
import gtk.Range;
import gtk.HScale;
import gtk.VScale;
import gtk.TreeModel;
import gtk.TreeIter;
import gtk.TreePath;
import gdk.Screen;
import pango.PgFontDescription;
import cairo.Surface;
import cairo.ImageSurface;
import cairo.Context;
import cairo.Matrix;
import gtkc.cairotypes;
import cairo.Matrix;
import gtk.ColorSelection;
import gtk.ColorSelectionDialog;

enum ArrowKeys
{
   KEY_LEFT = 0xff51,
   KEY_UP,
   KEY_RIGHT,
   KEY_DOWN
}

enum
{
   OP_NONE,
   OP_NAME,
   OP_MOVE,
   OP_COLOR,
   OP_XCOLOR,
   OP_ALTCOLOR,
   OP_OPACITY,
   OP_FONT,
   OP_FILL,
   OP_SIZE,
   OP_HSIZE,
   OP_VSIZE,
   OP_THICK,
   OP_SOLID,
   OP_RESIZE,
   OP_SCALE,      // We have granularity in our classification of transforms for the benefit
   OP_HSC,        // of the undo system. An undo checkpoint - a copy of the current transform
   OP_VSC,        // is set only if an operation is pushed that is different than the one that
   OP_HSK,        // was previously pushed. So if you've done a bunch of vertical scale ops
   OP_VSK,        // they will all be discarded when you undo.
   OP_ROT,
   OP_HFLIP,
   OP_VFLIP,
   OP_CHOICE,
   OP_REDRAW,
   OP_NEWFILE,
   OP_TEXT,
   OP_IV0,
   OP_IV1,
   OP_IV2,
   OP_IV3,
   OP_DV0,
   OP_DV1,
   OP_DV2,
   OP_DV3,
   OP_DV4,
   OP_DV5,
   OP_DV6,
   OP_DV7,
   OP_BOLD,
   OP_ITALIC,
   OP_ALIGN,
   OP_PATH,
   OP_PARAMS,
   OP_INNER,
   OP_TARGET,
   OP_OUTER,
   OP_CANGLE,
   OP_LAGLEAD,
   OP_ALTRADIUS,
   OP_CP1,
   OP_CP2,
   OP_CPBOTH,
   OP_ACP1,
   OP_ACP2,
   OP_RPCCP,
   OP_ACPBOTH,
   OP_MC0,
   OP_MC1,
   OP_MC2,
   OP_MC3,
   OP_CSEED,
   OP_SSEED,
   OP_PCA,
   OP_ORIENT,
   OP_ROWCOLS,

   OP_UNDEF
}

Coord[] copyPath(Coord[] p)
{
   Coord[] t;
   t.length = p.length;
   t[] = (p)[];
   return t;
}

struct CheckPoint
{
   int type = OP_UNDEF;
   union
   {
      string s;
      RGBA color;
      Coord coord;
      double dVal;
      int iVal;
      uint uiVal;
      bool boolVal;
      ICoord iCoord;
      Coord[] path;
      ubyte[] ubbuf;
      PathItemR pathItemR;
      PathItem[] pcPath;
      Transform transform;
      ParamBlock paramBlock;
      PartColor partColor;
      PartColor[] pca;
      RPCCP rpccp;
      FillSpec fillSpec;
   }
}
alias Coord[] Path_t;

// Push a checkpoint of the specified type
int push(T)(ACBase that, T t, int op)
{
   static if (is( T == RGBA))
   {
      that.lcp.color = t;
      that.lcp.type = op;
   }
   else static if (is(T == ubyte[]))
   {
      that.lcp.ubbuf = t;
      that.lcp.type = op;
   }
   else static if (is(T == Coord[]))
   {
      that.lcp.path = t.dup;
      that.lcp.type = op;
   }
   else static if (is(T == Coord))
   {
      that.lcp.coord = t;
      that.lcp.type = op;
   }
   else static if (is(T == ICoord))
   {
      that.lcp.iCoord = t;
      that.lcp.type = op;
   }
   else static if (is(T == PathItemR))
   {
      that.lcp.pathItemR = t;
      that.lcp.type = op;
   }
   else static if (is(T == PathItem[]))
   {
      that.lcp.pcPath = t.dup;
      that.lcp.type = op;
   }
   else static if (is(T == ParamBlock))
   {
      that.lcp.paramBlock = t;
      that.lcp.type = op;
   }
   else static if (is(T == string))
   {
      that.lcp.s = t;
      that.lcp.type = op;
   }
   else static if (is(T == double))
   {
      that.lcp.dVal = t;
      that.lcp.type = op;
   }
   else static if (is(T == int))
   {
      that.lcp.iVal = t;
      that.lcp.type = op;
   }
   else static if (is(T == uint))
   {
      that.lcp.uiVal = t;
      that.lcp.type = op;
   }
   else static if (is(T == bool))
   {
      that.lcp.boolVal = t;
      that.lcp.type = op;
   }
   else static if (is(T == PartColor))
   {
      that.lcp.partColor = t;
      that.lcp.type = op;
   }
   else static if (is(T == PartColor[]))
   {
      that.lcp.pca = t.dup;
      that.lcp.type = op;
   }
   else static if (is(T == RPCCP))
   {
      that.lcp.rpccp = t;
      that.lcp.type = op;
   }
   else static if (is(T == FillSpec))
   {
      that.lcp.fillSpec = t;
      that.lcp.type = op;
   }
   that.pushOp(that.lcp);
   return op;
}

// Push a CheckPoint only if the last CheckPoint pushed was not of the same type
int pushC(T)(ACBase that, T t, int op)
{
   if (that.lastOp == op)
      return op;
   static if (is( T == RGBA))
   {
      that.lcp.color = t;
      that.lcp.type = op;
   }
   else static if (is(T == Transform))
   {
      that.lcp.transform = t;
      that.lcp.type = op;
   }
   else static if (is(T == Coord[]))
   {
      that.lcp.path = t.dup;
      that.lcp.type = op;
   }
   else static if (is(T == Coord))
   {
      that.lcp.coord = t;
      that.lcp.type = op;
   }
   else static if (is(T == ICoord))
   {
      that.lcp.iCoord = t;
      that.lcp.type = op;
   }
   else static if (is(T == PathItemR))
   {
      that.lcp.pathItemR = t;
      that.lcp.type = op;
   }
   else static if (is(T == PathItem[]))
   {
      that.lcp.pcPath = t;
      that.lcp.type = op;
   }
   else static if (is(T == ParamBlock))
   {
      that.lcp.paramBlock = t;
      that.lcp.type = op;
   }
   else static if (is(T == string))
   {
      that.lcp.s = t;
      that.lcp.type = op;
   }
   else static if (is(T == double))
   {
      that.lcp.dVal = t;
      that.lcp.type = op;
   }
   else static if (is(T == int))
   {
      that.lcp.iVal = t;
      that.lcp.type = op;
   }
   else static if (is(T == bool))
   {
      that.lcp.boolVal = t;
      that.lcp.type = op;
   }
   else static if (is(T == PartColor))
   {
      that.lcp.partColor = t;
      that.lcp.type = op;
   }
   else static if (is(T == RPCCP))
   {
      that.lcp.rpccp = t;
      that.lcp.type = op;
   }
   that.pushOp(that.lcp);
   return op;
}

enum
{
   AC_TEXT,
   AC_USPS,
   AC_FANCYTEXT,
   AC_MORPHTEXT,
   AC_SERIAL,
   AC_RICHTEXT,
   AC_BRUSHDABS,
   AC_PATTERN,
   AC_PIXBUF,
   AC_LINE,
   AC_RECT,
   AC_CIRCLE,
   AC_CURVE,
   AC_REGPOLYGON,
   AC_REGPOLYCURVE,
   AC_POINTSET,
   AC_POLYGON,
   AC_POLYCURVE,
   AC_ARROW,
   AC_HEART,
   AC_BARCODE,
   AC_SEPARATOR,
   AC_CORNERS,
   AC_CRESCENT,
   AC_CROSS,
   AC_BEVEL,
   AC_FADER,
   AC_LGRADIENT,
   AC_RGRADIENT,
   AC_RANDOM,
   AC_PARTITION,
   AC_REFERENCE,
   AC_SVGIMAGE,
   AC_STROKESET,
   AC_DRAWING,
   AC_MESH,
   AC_MOON,
   AC_TRIANGLE,
   AC_NOISE,
   AC_TILINGS,
   AC_TEARDROP,
   AC_YINYANG,
   AC_SHIELD,
   AC_LINEBORDERS,

   AC_CONTAINER = 1000,
   AC_DUMMY,
   AC_ROOT
}

string[] _ACTypeNames = [ "Text", "USPS Address", "Fancy Text", "Morphed Text", "Serial Number", "Rich Text", "Brush Dabs", "Pattern",
                          "PixelImage", "Line", "Rectangle", "Circle", "Curve", "Regular Polygon", "Regular Polycurve", "PointSet", "Polygon", "Polycurve", "Arrow", "Heart", "Barcode",
                          "Separator", "Corners", "Crescent", "Cross", "Bevel", "Fader", "LGradient", "RGradient",
                          "Random", "Partition", "Reference", "SVGImage", "StrokeSet", "Drawing", "Mesh", "Moon", "Triangle", "Noise",
                          "Color Tilings", "Teardrop", "YinYang", "Shield", "Line Borders" ];
string ACTypeNames(int t)
{
   if (t < AC_CONTAINER)
      return _ACTypeNames[t];
   else if (t == AC_CONTAINER)
      return "Composition";
   else if (t == AC_DUMMY)
      return "Dummy";
   return "AC Root Element";
}

enum ControlsPos
{
   BELOW,
   RIGHT,
   FLOATING
}

enum ACGroups
{
   TEXT,
   GEOMETRIC,
   EFFECTS,
   SHAPES,
   PIXMAP,
   SVG,
   DRAWING,
   REFERENCE,
   DRAWINGS,
   CONTAINER,

   UNSPECIFIED = 100
}

struct ACInit
{
   AppWindow aw;
   ACBase parent;
   string name;
   uint type;
   ACGroups g;
}

class ACBase : CSTarget     // Area Composition base class
{                           // Implements the control set notification methods
   static ACBase lastRemoved;
   static CheckPoint emptyCP;
   static bool svgFlag = false;
   static bool printFlag = false;
   AppWindow aw;
   UUID uuid;
   UUID[] others;
   bool dirty, hidden;
   int lastOp;
   CheckPoint[] cpStack;
   int cpStackLen;
   CheckPoint lcp;
   int csTop;
   string name;   // Name given automatically or by the user - e.g. 'Address label 1"
   uint type;     // ACType of composition element
   ACGroups group;
   string typeName;
   int isActiveChild;
   ControlSet cSet;
   ControlsPos controlsPos;
   Widget[] widgets;
   ICoord[] wpos;
   Frame dframe;
   Layout layout;
   DrawingArea da;
   ComboBoxText fillOptions;
   Label fillType;
   bool fill, outline, fillFromPattern;
   UUID fillUid;
   int renderCalled;
   Surface background;
   ACBase skip;
   RGBA baseColor, altColor;
   Coord mPos;
   bool isMoved, usingCD, cSetRealized, noGC, nameWasSet;

   int width, height;
   double hOff, vOff, lpX, lpY;
   ACBase parent;
   ACBase[] children;
   ACBase fillObject;
   Entry nameEntry;
   ControlsDlg controlsDlg;

   cairo_matrix_t tmData;
   Matrix tm;
   Transform tf;
   int xform;

   alias bool delegate(Widget, Purpose) bdnh;
   bdnh[] notifyHandlers;
   alias bool delegate(CheckPoint) bduh;
   bduh[] undoHandlers;
   bool nop;

   mixin template Preamble(alias NAME, alias GNAME, alias T)
   {
      string s = NAME~" "~to!string(nextOid);
      ACGroups g = mixin("ACGroups."~GNAME);
      static int t = T;
   }

   this(AppWindow w, ACBase _parent, string _name, uint _type, ACGroups = ACGroups.UNSPECIFIED)
   {
      aw = w;
      name = _name;
      type = _type;
      uuid = md5UUID(name~to!string(type)~".COMPO");
      lastOp = OP_NONE;
      if (_type != AC_ROOT && type != AC_DUMMY)
      {
         cpStackLen = w.config.undoStackLength;
         cpStack.length = cpStackLen;
      }
      notifyHandlers ~= &ACBase.notifyHandler;
      undoHandlers ~= &ACBase.undoHandler;
      csTop = -1;
      hOff = vOff = lpX = lpY = 0.0;
      parent = _parent;
      isActiveChild = 0;
      typeName = ACTypeNames(type);
      if (parent)
      {
         width = parent.width;
         height = parent.height;
      }
      baseColor = new RGBA(0,0,0,1);
      altColor = new RGBA(1,1,1,1);

      if (aw !is null)  // The tree root does not need a layout etc
      {
         layout = new Layout(null, null);
         layout.setSize(width+20, height+400);
         layout.setEvents(GdkEventMask.KEY_PRESS_MASK | GdkEventMask.BUTTON_PRESS_MASK);
         layout.addOnKeyPress(&onKeyPress);
         layout.addOnButtonPress(&setFocusLayout);

         da = new DrawingArea(width, height);
         da.setEvents(GdkEventMask.BUTTON_PRESS_MASK | GdkEventMask.BUTTON_RELEASE_MASK |
                      GdkEventMask.POINTER_MOTION_MASK);
         da.addOnDraw(&drawCallback);
         da.addOnButtonPress(&buttonPress);
         da.addOnMotionNotify(&mouseMove);
         da.addOnButtonRelease(&buttonRelease);

         dframe = new Frame(da, null);
         dframe.setSizeRequest(width+2, height+2);
         dframe.setShadowType(ShadowType.IN);
         layout.put(dframe, rpLm, rpTm);
         dframe.show();
         da.show();
         if (aw.controlsFloating)
            controlsDlg = new ControlsDlg(this);
         controlsPos = ControlsPos.BELOW;
         cSet = new ControlSet(this);
      }
   }

   string colorString(bool alt)
   {
      scope auto w = appender!string();
      RGBA t = alt? altColor: baseColor;
      formattedWrite(w, "%f,%f,%f,%f", t.red, t.green, t.blue, t.alpha);
      return w.data;
   }

   bool notifyHandler(Widget w, Purpose p)
   {
      switch (p)
      {
      case Purpose.COLOR:
         focusLayout();
         lastOp = push!RGBA(this, baseColor, OP_COLOR);
         setColor(false);
         break;
      case Purpose.FILLCOLOR:
         focusLayout();
         lastOp = push!RGBA(this, altColor, OP_ALTCOLOR);
         setColor(true);
         break;
      case Purpose.HIDE:
         hidden = !hidden;
         break;
      default:
         return false;
      }
      return true;
   }
   bool undoHandler(CheckPoint cp) { return false; }


   void setNameEntry(Entry e) { nameEntry = e; }
   void onCSCompass(int instance, double angle, bool coarse) {}
   void onCSSaveSelection() {}
   void onCSPalette(PartColor[]) {}
   void deserializeComplete() {}

   final ACBase prevSibling()
   {
      if (parent.type != AC_CONTAINER)
         return null;
      Container ctr = cast(Container) parent;
      if (ctr.children.length == 1)
         return null;
      if (ctr.children[0] is this)
         return null;
      ACBase prev;
      foreach (ACBase child; ctr.children)
      {
         if (child is this)
            return prev;
         prev = child;
      }
      return null;
   }

   final void updateFillUI()
   {
      auto writer = appender!string();
      if (!fill && !fillFromPattern)
      {
         fillType.setText("(N)");
         fillOptions.setTooltipText("Not filled");
         fillObject = null;
      }
      else if (fill && !fillFromPattern)
      {
         fillObject = null;
         fillType.setText("(C)");
         formattedWrite(writer, "RGBA: %d, %d, %d, %d",
                        to!int(altColor.red*100), to!int(altColor.green*100), to!int(altColor.blue*100), to!int(altColor.alpha*100));
         fillOptions.setTooltipText(writer.data);
      }
      else
      {
         fillObject = aw.getObjectByUid(fillUid);
         fillType.setText("(P)");
         formattedWrite(writer, "Pattern: %s - (%s)", fillObject.name, fillUid);
         fillOptions.setTooltipText(writer.data);
      }
      cSet.setToggleUI(Purpose.OUTLINE, outline);
   }

   void pushOp(CheckPoint cp)
   {
      if (csTop < cpStackLen-1)
      {
         csTop++;
         cpStack[csTop] = cp;
      }
      else
      {
         csTop = cpStackLen-1;
         for (int i = 0; i < cpStackLen-1; i++)
            cpStack[i] = cpStack[i+1];
         cpStack[csTop] = cp;
      }
   }

   CheckPoint popOp()
   {
      if (csTop < 0)
      {
         aw.popupMsg("Sorry, no further undo actions are available", MessageType.INFO);
         return emptyCP;
      }
      CheckPoint cp = cpStack[csTop--];
      return cp;
   }

   bool specificUndo(CheckPoint cp) { return false; }

   void undo()
   {
      CheckPoint cp;
      cp = popOp();
      if (cp.type == 0)
         return;
      focusLayout();
      switch (cp.type)
      {
      case OP_NAME:
         name = cp.s;
         nameEntry.setText(name);
         aw.tv.queueDraw();
         lastOp = OP_UNDEF;
         break;
      case OP_COLOR:
         baseColor = cp.color.copy();
         break;
      case OP_MOVE:
         Coord t = cp.coord;
         hOff = t.x;
         vOff = t.y;
         lastOp = OP_UNDEF;
         break;
      case OP_SCALE:
      case OP_HSC:
      case OP_VSC:
      case OP_HSK:
      case OP_VSK:
      case OP_ROT:
      case OP_HFLIP:
      case OP_VFLIP:
         tf = cp.transform;
         break;
      default:
         if (!specificUndo(cp))
            return;
         break;
      }
      aw.dirty = true;
      reDraw();
   }

   bool setFocusLayout(Event e, Widget w)
   {
      focusLayout();
      return true;
   }

   void focusLayout()
   {
      if (nameEntry !is null)
      {
         nameEntry.grabFocus();
         if (nameWasSet)
            nameEntry.selectRegion(0,0);
      }
   }

   bool onKeyPress(Event e, Widget w)
   {
      uint kv = e.key.keyval;
      switch (kv)
      {
      case ArrowKeys.KEY_LEFT:
         move(kv-ArrowKeys.KEY_LEFT, false);
         break;
      case ArrowKeys.KEY_UP:
         move(kv-ArrowKeys.KEY_LEFT, false);
         break;
      case ArrowKeys.KEY_RIGHT:
         move(kv-ArrowKeys.KEY_LEFT, false);
         break;
      case ArrowKeys.KEY_DOWN:
         move(kv-ArrowKeys.KEY_LEFT, false);
         break;
      default:
         return false;
      }
      return true;
   }

   ACGroups getGroup()
   {
      return group;
   }

   void syncControls()
   {
   }

   void positionControls(bool inCtor)
   {
      if (aw.controlsPos == ControlsPos.FLOATING)
      {
         if (usingCD)
            return;
         if (controlsDlg is null)
            controlsDlg = new ControlsDlg(this);
         if (!inCtor)
            cSet.unRealize(layout);
         cSet.setPosition(ICoord(0, 10));
         controlsDlg.setControls(cSet);
         usingCD = true;
         if (this == aw.cto)
            controlsDlg.show();
      }
      else
      {
         if (usingCD)
         {
            controlsDlg.hide();
            if (!inCtor)
               controlsDlg.clear(cSet);
            usingCD = false;
         }
         else
         {
            if (!inCtor)
               cSet.unRealize(layout);
         }
         if (aw.controlsPos == ControlsPos.BELOW)
            cSet.setPosition(ICoord(rpLm, rpTm+height+10));
         else
            cSet.setPosition(ICoord(rpLm+width+10, rpTm+10));
         cSet.realize(layout);
         layout.queueDraw();
      }
   }

   static void setControlPositions(ACBase root)
   {
      // only two levels below root - so explicitly
      foreach (ACBase child; root.children)
      {
         child.positionControls(false);
         foreach (ACBase child2; child.children)
         {
            child2.positionControls(false);
         }
      }
   }

   void preResize(int oldW, int oldH) {}

   final void commonResize(int oldW, int oldH)
   {
      preResize(oldW, oldH);

      da.setSizeRequest(width, height);
      dframe.setSizeRequest(width+4, height+4);
      //dframe.queueDraw();
      //da.queueDraw();
      cSet.reposition(ICoord(rpLm, rpTm+height+10), layout);
      layout.queueDraw();

      postResize(oldW, oldH);
      aw.dirty = true;
   }

   void resize(int oldW, int oldH)
   {
      commonResize(oldW, oldH);
   }

   void postResize(int oldW, int oldH) {}

   int getNextOid()
   {
      return 0;
   }

   final void setSize(int w, int h)
   {
      width = w;
      height = h;
      if (layout !is null)
         layout.setSize(w+20, h+400);
   }

   final void setSizeRecursive(int w, int h)
   {
      int oldW = width, oldH = height;
      setSize(w, h);

      // only two levels below root - so explicitly
      foreach (ACBase child; children)
      {
         child.setSize(w, h);
         child.resize(oldW, oldH);
         foreach (ACBase child2; child.children)
         {
            child2.setSize(w, h);
            child2.resize(oldW, oldH);
         }
      }
   }

   void onCSNameChange(string s)
   {
      lastOp = push!string(this, name, OP_NAME);
      aw.dirty = true;
      name = s;
      nameWasSet = true;
      if (aw.tv !is null)
         aw.tv.queueDraw();
   }

   void setName(string newName)
   {
      aw.dirty = true;
      name = newName;
      nameWasSet = true;
      cSet.setHostName(name);
      if (aw.tv !is null)
         aw.tv.queueDraw();
   }

   final void setOthersInactive()
   {
      if (type == AC_CONTAINER)
      {
         foreach (ACBase x; children)
         {
            x.hideDialogs();
            x.isActiveChild = 0;
         }
         setSelectedChild(null);
         isActiveChild = 1;
         return;
      }
      ACBase ctr = parent;
      parent.isActiveChild = 0;
      foreach (ACBase x; ctr.children)
      {
         if (x !is this)
         {
            x.hideDialogs();
            x.isActiveChild = 0;
         }
      }
      ctr.setSelectedChild(this);
      isActiveChild = 1;
   }

   static void insertChildAt(ACBase parent, ACBase child, int pos)
   {
      if (pos >= parent.children.length)
      {
         //append
         parent.children ~= child;
      }
      else
      {
         size_t len = parent.children.length+1;
         parent.children.length = len;
         for (size_t j = len-1; j > pos; j--)
            parent.children[j] = parent.children[j-1];
         parent.children[pos] = child;
      }
   }

   static int insertChild(ACBase refChild, ACBase newChild, bool rel)
   {
      ACBase p = refChild.parent;
      size_t i;
      for (i = 0; i < p.children.length; i++)
      {
         if (p.children[i] is refChild)
            break;
      }
      if (i >= p.children.length)
         return -1;  // Or throw an exception!
      size_t len = p.children.length+1;
      p.children.length = len;
      if (rel)       // insert after
      {
         for (size_t j = len-1; j > i+1; j--)
            p.children[j] = p.children[j-1];
         p.children[i+1] = newChild;
      }
      else          // insert before
      {
         for (size_t j = len-1; j > i; j--)
            p.children[j] = p.children[j-1];
         p.children[i] = newChild;
      }
      return cast(int) i;
   }

   static void moveChild(ACBase child, bool up)
   {
      ACBase p = child.parent;
      size_t i;
      for (i = 0; i < p.children.length; i++)
      {
         if (p.children[i] is child)
            break;
      }
      if (i >= p.children.length)
         return;  // Or throw an exception!
      if (up)
      {
         if (i > 0)
         {
            ACBase t = p.children[i-1];
            p.children[i-1] = child;
            p.children[i] = t;
         }
      }
      else
      {
         if (i < p.children.length-1)
         {
            ACBase t = p.children[i+1];
            p.children[i+1] = child;
            p.children[i] = t;
         }
      }
      if (p.type == AC_CONTAINER)
         p.reDraw();
   }

   static void removeChild(AppWindow w, ACBase child)
   {
      TreePath tp = w.treeOps.getPath(child);
      ACBase p = child.parent;
      bool inCtr = (p.type == AC_CONTAINER);
      bool isCto = (w.cto is child);
      size_t len = p.children.length;
      if (len == 1)
      {
         // Removing last child  from container, ot last item from tree
         // caller to adjust the tree
         p.children.length = 0;
         if (isCto)
         {
            if (inCtr)
            {
               w.cto = p;
               w.rp.remove(w.layout);
               w.layout = p.layout;
               w.rp.add(w.layout);
            }
            else
            {
               w.cto = null;
               w.rp.remove(w.layout);
               w.layout = null;
            }
         }
         return;
      }
      size_t i;
      for (i = 0; i < len; i++)
      {
         if (p.children[i] is child)
            break;
      }
      if (i < len-1)
      {
         for (size_t j = i; j < len-1; j++)
            p.children[j] = p.children[j+1];
      }
      p.children.length = len-1;
      if (isCto)
      {
         if (i == p.children.length)
            i--;
         w.cto = p.children[i];
         w.layout.doref();
         w.rp.remove(w.layout);
         w.layout = w.cto.layout;
         w.rp.add(w.layout);
         w.cto.zapBackground();
         w.cto.reDraw();
      }
      if (p.type == AC_CONTAINER)
         p.reDraw();
   }

   void setSelectedChild(ACBase acb) {}

   void reDraw()
   {
      da.queueDraw();
   }

   void onChildChanged() {};

   // For keyboard arrow keys and moving parts within a container
   void move(int direction, bool far)
   {
      focusLayout();
      lastOp = pushC!Coord(this, Coord(hOff, vOff), OP_MOVE);
      double d = far? 10.0: 1.0;
      switch (direction)
      {
      case 0:
         hOff -= d;
         break;
      case 1:
         vOff -= d;
         break;
      case 2:
         hOff += d;
         break;
      case 3:
         vOff += d;
         break;
      default:
         return;
      }
      aw.dirty = true;
      reDraw();
   }

   bool specificNotify(Widget w, Purpose p) { return false; }

   final void onCSNotify(Widget w, Purpose p)
   {
      bool handled = false;
      nop = false;
      foreach (bdnh nh; notifyHandlers)
      {
         if (nh(w, p))
         {
            handled = true;
            break;
         }
      }
      assert(!handled, "No handler for "~to!string(p));
      if (!nop)   // nop to be set for operations that don't require save or a repaint
      {
         aw.dirty = true;
         reDraw();
      }
   }

/*
   void onCSNotify(Widget w, Purpose wid)
   {
      switch (wid)
      {
      case Purpose.COLOR:
         focusLayout();
         lastOp = push!RGBA(this, baseColor, OP_COLOR);
         setColor(false);
         break;
      case Purpose.FILLCOLOR:
         focusLayout();
         lastOp = push!RGBA(this, altColor, OP_ALTCOLOR);
         setColor(true);
         break;
      case Purpose.HIDE:
         hidden = !hidden;
         break;
      default:
         if (!specificNotify(w, wid))
            return;  // Ingore whatever
         break;
      }
      aw.dirty = true;
      reDraw();
   }
*/
   void onCSTextParam(Purpose p, string sv, int iv) {}
   void onCSLineWidth(double lw) {}
   void onCSMoreLess(int instance, bool more, bool coarse) {}
   void hideDialogs() {};

   string onCSInch(int id, int direction, bool coarse)
   {
      focusLayout();
      lastOp = pushC!Coord(this, Coord(hOff, vOff), OP_MOVE);
      bool skip = false;
      double d = coarse? 5.0: 0.5;
      switch (direction)
      {
      case 0:
         hOff -= d;
         break;
      case 1:
         vOff -= d;
         break;
      case 2:
         hOff += d;
         break;
      case 3:
         vOff += d;
         break;
      default:
         skip = true;
         break;
      }
      if (!skip)
      {
         aw.dirty = true;
         reDraw();
      }
      return reportPosition();
   }

   void onCSInchFill(int id, int direction, bool coarse)
   {
      if (fillObject is null)
         return;
      if (fillObject.type == AC_CONTAINER)
         (cast(Container) fillObject).inchAll(direction, coarse);
      else
         fillObject.onCSInch(id, direction, coarse);
      reDraw();
   }

   static string RGBA2hex(RGBA c)
   {
      ubyte r = cast(ubyte) (c.red*255.0);
      ubyte g = cast(ubyte) (c.green*255.0);
      ubyte b = cast(ubyte) (c.blue*255.0);
      auto writer = appender!string();
      formattedWrite(writer, "#%02x%02x%02x", r, g, b);
      return writer.data;
   }

   bool installColor(RGBA c) { return true; }

   bool applyColor(RGBA c, bool alt)
   {
      bool rv = installColor(c);
      if (rv)
      {
         if (alt)
            altColor = c;
         else
            baseColor = c;
      }
      reDraw();
      return rv;
   }

   // returns true if the color was applied to base or alt,
   // false if it was used for something else.
   bool setColor(bool alt = false)
   {
      dirty = true;
      RGBA color = new RGBA();
      ColorSelectionDialog csd = new ColorSelectionDialog("Choose a Color");
      ColorSelection cs = csd.getColorSelection();
      cs.setHasOpacityControl (1);
      if (alt)
      {
         cs.setCurrentRgba(altColor);
         cs.setCurrentAlpha(to!ushort(altColor.alpha*ushort.max));
      }
      else
      {
         cs.setCurrentRgba(baseColor);
         cs.setCurrentAlpha(to!ushort(baseColor.alpha*ushort.max));
      }
      int response = csd.run();
      if (response != ResponseType.OK)
      {
         csd.destroy();
         return false;
      }
      cs.getCurrentRgba(color);
      ushort us = cs.getCurrentAlpha();
      double a = (cast(double) us)/ushort.max;
      color.alpha(a);
      csd.destroy();
      return applyColor(color, alt);
   }

   RGBA getDColor(RGBA current)
   {
      dirty = true;
      RGBA color = new RGBA();
      ColorSelectionDialog csd = new ColorSelectionDialog("Choose a Color");
      ColorSelection cs = csd.getColorSelection();
      cs.setHasOpacityControl (1);
      cs.setCurrentRgba(current);
      int response = csd.run();
      if (response != ResponseType.OK)
      {
         csd.destroy();
         return null;
      }
      cs.getCurrentRgba(color);
      ushort us = cs.getCurrentAlpha();
      double a = (cast(double) us)/ushort.max;
      color.alpha(a);
      csd.destroy();
      return color;
   }

   string reportPosition(int id = 0)
   {
      return formatCoord(Coord(hOff, vOff));
   }

   void adjust(int id, int direction, bool much) {}
   void zapBackground()
   {
      background = null;
   }
   void focus() {}

   Widget getWidget()
   {
      return layout;
   }

// Basic stuff for mouse drag gestures
   bool buttonPress(Event e, Widget w)
   {
      GdkModifierType state;
      e.getState(state);
      if ((!state & GdkModifierType.BUTTON1_MASK))
         return true;
      focusLayout();
      lastOp = pushC!Coord(this, Coord(hOff, vOff), OP_MOVE);
      mPos.x = e.button.x;
      mPos.y = e.button.y;
      return true;
   }

   bool buttonRelease(Event e, Widget w)
   {
      isMoved = false;
      cSet.setDisplay(0, reportPosition());
      return true;
   }

   void mouseMoveOp(double dx, double dy, GdkModifierType state)
   {
      hOff += dx;
      vOff += dy;
   }

   bool mouseMove(Event e, Widget w)
   {
      GdkModifierType state;
      e.getState(state);
      if (!(state & GdkModifierType.BUTTON1_MASK))
         return true;
      double x = e.motion.x, y = e.motion.y;
      double dx = x-mPos.x, dy = y-mPos.y;
      if (abs(dx) < 5.0 && abs(dy) < 5.0)
         return true;
      mPos.x = x;
      mPos.y = y;
      mouseMoveOp(dx, dy, state);
      isMoved = true;
      da.queueDraw();
      aw.dirty = true;
      return true;
   }

   void setPosition(double x, double y)
   {
      if (lastOp != OP_MOVE)
      {
         lcp.coord = Coord(hOff, vOff);
         lastOp = lcp.type = OP_MOVE;
         pushOp(lcp);
      }
      aw.dirty = true;
      hOff = x;
      vOff = y;
   }

   void decorateSheet(Context c)
   {
      Sheet sheet = aw.currentSheet;
      c.setSourceRgb(0, 0, 0);
      c.setLineWidth(0.5);
      if (sheet.seq)
      {
         bool[double] ca;
         Sequence seq = sheet.layout.s;
         foreach (int i, LSRect r; seq.rects)
         {
            if (i >= seq.count)
               break;
            if (ca.get(r.w+r.h+r.w/r.h, false))
               continue;
            ca[r.w+r.h+r.w/r.h] = true;
            if (aw.landscape)
            {
               c.moveTo(0, 0);
               c.lineTo(seq.rects[i].h, 0);
               c.lineTo(seq.rects[i].h, seq.rects[i].w);
               c.lineTo(0, seq.rects[i].w);
            }
            else
            {
               c.moveTo(0, 0);
               c.lineTo(seq.rects[i].w, 0);
               c.lineTo(seq.rects[i].w, seq.rects[i].h);
               c.lineTo(0, seq.rects[i].h);
            }
            c.closePath();
            c.stroke();
            if (seq.rects[i].round)
            {
               c.arc(0.5*seq.rects[i].w, 0.5*seq.rects[i].w, 0.5*seq.rects[i].w, 0, 2*PI);
               c.stroke();
            }
         }
      }
      else
      {
         if (sheet.layout.g.round)
         {
            c.arc(0.5*width, 0.5*height, 0.5*width, 0, 2*PI);
            c.stroke();
         }
      }
   }

   void doZoom(Context c) {}

   final void getFillOptions(ACBase that)
   {
      FillOptions fo;
      fo.init(that);
      FillOption[] foa = fo.get();
      that.others.length = foa.length;
      foreach (int i, FillOption o; foa)
      {
         that.others[i] = o.uuid;
         fillOptions.appendText(o.name);
      }
   }


   final void updateFillOptions(ACBase that)
   {
      FillOptions fo;
      fo.init(that);
      FillOption[] foa = fo.get();

      bool exists(UUID uid)
      {
         for (int i = 0; i < that.others.length; i++)
         {
            if (that.others[i] == uid)
               return true;
         }
         return false;
      }

      foreach (int i, FillOption o; foa)
      {
         if (exists(o.uuid))
            continue;
         that.others ~= o.uuid;
         fillOptions.appendText(o.name);
      }
   }

   void strokeAndFill(Context c, double lw, bool outline, bool fill)
   {
      void doFill()
      {
         if (fillFromPattern)
         {
            ACBase acb = aw.getObjectByUid(fillUid);
            if (acb is null)
               c.setSourceRgb(0,0,0);
            else
               c.setSourceSurface(acb.getPaintedSurface(c), 0, 0);
         }
         else
            c.setSourceRgba(altColor.red, altColor.green, altColor.blue, altColor.alpha);
         if (outline)
            c.fillPreserve();
         else
            c.fill();
      }

      if (fill)
      {
         doFill();
         if (outline)
         {
            c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);
            c.setLineWidth(lw);
            c.stroke();
         }
      }
      else
      {
         c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);
         c.setLineWidth(lw);
         c.stroke();
      }
   }

   void doFill(Context c, bool solid, bool fill)
   {
      c.strokePreserve();
      if (solid)
         c.fill();
      else if (fill)
      {
         c.setSourceRgba(altColor.red, altColor.green, altColor.blue, 1.0);
         c.fill();
      }
   }

   bool drawCallback(Context c, Widget widget)
   {

      // This is where we draw on the design drawing area
      bool inCtr = (parent.type == AC_CONTAINER);
      if (inCtr)
      {
         // When in a multi-layer composition, we will be working on a particular layer
         // that we will see on top of the other layers, so we cache the other layers onto
         // a cairo surface so we can just quickly paint them onto the drawing area
         if (background is null)
         {
            // Need to make the cached background
            Container ctr  = cast(Container) parent;
            background = c.getTarget().createSimilar(cairo_content_t.COLOR_ALPHA, width, height);
            Context t = c.create(background);
            t.setSourceRgba(1,1,1,1);
            t.paint();
            ctr.skip = this;
            c.save();
            ctr.renderOther(this, t);
            c.restore();
         }
      }

      if (inCtr)
      {
         c.save();
         doZoom(c);
         // paint the image of the other layers
         c.setSourceSurface(background, 0, 0);
         c.paint();
         c.restore();
      }
      else
      {
         // Just paint the background white
         c.setSourceRgba(1,1,1,1);
         c.paint();
         decorateSheet(c);
      }
      c.save();
      render(c);
      if (!isMoved) cSet.setDisplay(0, reportPosition());
      c.restore();

      return true;
   }

   // Rendition for individual object types - all will override
   void render(Context c)
   {
   }

   void setupControls(uint flags = 0)
   {
      cSet.cy = 0;
      extendControls();
      RenameGadget rg = new RenameGadget(cSet, ICoord(0, cSet.cy), name, true);
      rg.setName(name);
      if (type != AC_CONTAINER)
      {
         CheckButton cb = new CheckButton("Hide Item");
         cb.setActive(0);
         cSet.add(cb, ICoord(210, cSet.cy), Purpose.HIDE, true);
      }
   }
   void extendControls() {}

   void afterDeserialize() {}

   // Render to the page layout
   void renderToPL(Context c, double xpos, double ypos)
   {
      c.setSourceRgb(1.0, 1.0, 1.0);
      c.rectangle(xpos, ypos, width, height);
      c.fill();
      cRender(c, xpos, ypos);
   }

   void renderToPNG()
   {
      renderPNG(this);
   }

   void renderToSVG()
   {
      renderSVG(this);
   }

   void modifyTransform(int tt, bool more, bool coarse)
   {
      // We rather arbitrarily do anisotropic scaling first, then transformations
      // that change the shape - squash and skew, then rotation, then finally flip
      // of the finished object
      if (tt <= 2)        // Scale
      {
         double factor;
         if (more)
            factor = coarse? 1.1: 1.01;
         else
            factor = coarse? 0.9: 0.99;
         switch (tt)
         {
            case 1:
               lastOp = pushC!Transform(this, tf, OP_HSC);
               tf.hScale *= factor;
               break;
            case 2:
               lastOp = pushC!Transform(this, tf, OP_VSC);
               tf.vScale *= factor;
               break;
            default:
               lastOp = pushC!Transform(this, tf, OP_SCALE);
               tf.hScale *= factor;
               tf.vScale *= factor;
               break;
         }
      }
      else if (tt == 3 || tt == 4) // Skew/shear horizontal/vertical
      {
         double delta = coarse? 0.1: 0.01;
         if (!more)
            delta = -delta;
         if (tt == 3)
         {
            lastOp = pushC!Transform(this, tf, OP_HSK);
            tf.hSkew += delta;
         }
         else
         {
            lastOp = pushC!Transform(this, tf, OP_VSK);
            tf.vSkew += delta;
         }
      }
      else if (tt == 5) // Rotate
      {
         double ra = coarse? rads*5: rads/3;
         if (more)
            ra = -ra;
         lastOp = pushC!Transform(this, tf, OP_ROT);
         tf.ra -= ra;
      }
      else if (tt == 6)
      {
         lastOp = pushC!Transform(this, tf, OP_HFLIP);
         tf.hFlip = !tf.hFlip;
      }
      else
      {
         lastOp = pushC!Transform(this, tf, OP_VFLIP);
         tf.vFlip = !tf.vFlip;
      }
   }

   bool compoundTransform()
   {
      Matrix tmp;
      cairo_matrix_t tmpData;
      tmp = new Matrix(&tmpData);
      tm.initIdentity();
      bool any = false;
      if (tf.hScale != 1 || tf.vScale != 1)
      {
         any = true;
         tmp.initScale(tf.hScale, tf.vScale);
         tm.multiply(tm, tmp);
      }
      if (tf.hSkew != 0)
      {
         any = true;
         tmp.init(1.0, 0.0, -tf.hSkew, 1.0, 0.0, 0.0);
         tm.multiply(tm, tmp);
      }
      if (tf.vSkew != 0)
      {
         any = true;
         tmp.init(1.0, -tf.vSkew, 0.0, 1.0, 0.0, 0.0);
         tm.multiply(tm, tmp);
      }
      if (tf.ra != 0)
      {
         any = true;
         tmp.initRotate(tf.ra);
         tm.multiply(tm, tmp);
      }
      if (tf.hFlip)
      {
         any = true;
         tmp.init(-1.0, 0.0, 0.0, 1.0, 0.0, 0.0);
         tm.multiply(tm, tmp);
      }
      if (tf.vFlip)
      {
         any = true;
         tmp.init(1.0, 0.0, 0.0, -1.0, 0.0, 0.0);
         tm.multiply(tm, tmp);
      }
      return any;
   }

   // Used to render at some arbitrary position
   void cRender(Context c, double ho, double vo)
   {
      double savedVOff, savedHOff;
      savedHOff = hOff;
      savedVOff = vOff;
      lpX = ho;
      lpY = vo;
      hOff = hOff+ho;
      vOff = vOff+vo;
      noGC = true;
      render(c);
      noGC = false;
      hOff = savedHOff;
      vOff = savedVOff;
      lpX = lpY = 0.0;
   }

   Surface getPaintedSurface(Context c)
   {
      Surface pattern = c.getTarget().createSimilar(cairo_content_t.COLOR_ALPHA, width, height);
      Context sc = Context.create(pattern);
      dirty = false;
      render(sc);
      return pattern;
   }
}
