
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module polycurve;

import mainwin;
import constants;
import acomp;
import common;
import types;
import container;
import controlset;
import lineset;
import interfaces;

import std.stdio;
import std.math;
import std.conv;
import std.string;

import gtk.DrawingArea;
import gtk.Widget;
import gtk.Button;
import gtk.Layout;
import gtk.Frame;
import gtk.Range;
import gtk.HScale;
import gtk.VScale;
import gdk.RGBA;
import gdk.Event;
import gtk.ToggleButton;
import gtk.RadioButton;
import gtk.ComboBoxText;
import gtk.CheckButton;
import gtk.Label;
import gtk.Dialog;
import gtk.VBox;
import gtk.Entry;
import cairo.Context;
import gtkc.cairotypes;
import cairo.Matrix;

enum
{
   SP = Purpose.R_CHECKBUTTONS-100,
   EP,
   CP1,
   CP2,
   BOTHCP,
   SPEP,
   ALL
}

class PolyCurveDlg: Dialog, CSTarget
{
   Polycurve po;
   ControlSet cs;
   Layout layout;
   Button lcb;
   CheckButton cbZoom, cbProtect;
   bool ignoreZoom, ignoreProtect;
   int sides;

   this(string title, Polycurve o)
   {
      GtkResponseType rta[1] = [ ResponseType.OK ];
      string[1] sa;
      super(title, o.aw, DialogFlags.DESTROY_WITH_PARENT, sa, rta);
      this.addOnDelete(&catchClose);
      po = o;
      sides = cast(int) po.pcPath.length;
      layout = new Layout(null, null);
      cs=new ControlSet(this);
      VBox vb = getContentArea();
      vb.packStart(layout, 1, 1, 0);
      layout.show();
      addGadgets();
   }

   string onCSInch(int instance, int direction, bool coarse) { return ""; }
   void onCSInchFill(int instance, int direction, bool coarse) {}
   void onCSLineWidth(double lw) {}
   void onCSSaveSelection() {}
   void onCSTextParam(Purpose p, string sval, int ival) {}
   void onCSNameChange(string s) {}
   void onCSPalette(PartColor[]) {}
   void setNameEntry(Entry e) {}

   bool catchClose(Event e, Widget w)
   {
      hide();
      po.editing = false;
      po.switchMode();
      return true;
   }

   void addGadgets()
   {
      int vi = 18;
      int vp = 5;
      new Compass(cs, 0, ICoord(20, vp));

      vp+= 55;
      RadioButton rb1 = new RadioButton("Start point");
      cs.add(rb1, ICoord(5, vp), cast(Purpose) SP);

      vp += vi;
      RadioButton rb = new RadioButton(rb1, "End point1");
      cs.add(rb, ICoord(5, vp), cast(Purpose) EP);

      vp += vi;
      rb = new RadioButton(rb1, "CP1");
      cs.add(rb, ICoord(5, vp), cast(Purpose) CP1);

      vp += vi;
      rb = new RadioButton(rb1, "CP2");
      cs.add(rb, ICoord(5, vp), cast(Purpose) CP2);

      vp += vi;
      rb = new RadioButton(rb1, "Both CP");
      cs.add(rb, ICoord(5, vp), cast(Purpose) BOTHCP);

      vp += vi;
      rb = new RadioButton(rb1, "All");
      cs.add(rb, ICoord(5, vp), cast(Purpose) ALL);

      vp = 5;
      vi = 26;
      Label l= new Label("Active edge");
      cs.add(l, ICoord(120, vp), Purpose.LABEL);
      MoreLess mol = new MoreLess(cs, 0, ICoord(200, vp), true);
      mol.setIntervals(200, 200);

      vp += 20;
      Button b = new Button("Add a Vertex");
      cs.add(b, ICoord(120, vp), Purpose.NEWVERTEX);

      vp += vi;
      b = new Button("Delete Edge");
      cs.add(b, ICoord(120, vp), Purpose.DELEDGE);

      vp += vi;
      lcb = new Button("To Line");
      lcb.setTooltipText("Switch the edge between line and curve");
      cs.add(lcb, ICoord(120, vp), Purpose.LINE2CURVE);

      vp += vi;
      b = new Button("Undo");
      cs.add(b, ICoord(120, vp), Purpose.UNDO);

      vp += vi+5;
      l = new Label("Opacity");
      cs.add(l, ICoord(120, vp), Purpose.LABEL);
      new MoreLess(cs, 1, ICoord(200, vp), true);

      vp += 17;
      cbProtect = new CheckButton("Protect");
      cbProtect.setTooltipText("Prevent modifications\n by mouse gestures");
      cs.add(cbProtect, ICoord(60, vp), Purpose.PROTECT);
      cbZoom = new CheckButton("Zoom");
      cbZoom.setTooltipText("Zoom in to deal with fine details.\nSwipe the mouse with the control key\ndown to move the viewport");
      cs.add(cbZoom, ICoord(134, vp), Purpose.ZOOMED);
      new MoreLess(cs, 2, ICoord(200, vp), true);

      cs.realize(layout);
   }

   void setControls()
   {
      cs.toggling(false);
      cs.setToggle(SP+po.activeCoords, true);
      cs.toggling(true);
   }

   static void moveCoord(ref Coord p, double distance, double angle)
   {
      p.x += cos(angle)*distance;
      p.y -= sin(angle)*distance;
   }

   void onCSMoreLess(int instance, bool more, bool coarse)
   {
      if (instance == 0)
      {
         sides = cast(int) po.pcPath.length;
         po.lastCurrent = po.current;
         int n = po.open? 2: 1;
         if (more)
         {
            if (po.current < sides-n)
               po.current++;
            else
               po.current = 0;
         }
         else
         {
            if (po.current == 0)
               po.current = sides-n;
            else
               po.current--;
         }
         onCurrentChanged();
         po.reDraw();
         return;
      }
      if (instance == 1)
      {
         double t = po.editOpacity;
         if (more)
         {
            if (t+0.05 > 1)
               t = 1;
            else
               t += 0.05;
         }
         else
         {
            if (t-0.05 < 0)
               t = 0;
            else
               t -= 0.05;
         }
         po.editOpacity = t;
         po.reDraw();
         return;
      }
      if (instance== 2)
      {
         if (more)
         {
            if (po.esf == 1)
            {
               po.setupZoom(true);
            }
            else
               po.adjustZoom(0.05);
            po.notifyContainer(true);
         }
         else
         {
            if (po.esf-0.05 < 1)
               po.setupZoom(false);
            else
               po.adjustZoom(-0.05);
            po.notifyContainer(false);
         }
      }
   }

   void onCurrentChanged()
   {
      if (po.pcPath[po.current].type == 1)
         lcb.setLabel("To Line");
      else
         lcb.setLabel("To Curve");
   }

   void onCSCompass(int instance, double angle, bool coarse)
   {
      double d = coarse? 2: 0.5;
      Coord dummy = Coord(0,0);
      moveCoord(dummy, d, angle);
      double dx = dummy.x, dy = dummy.y;
      po.figureNextPrev();
      po.adjustPI(dx, dy);
      po.resetCog();
      po.reDraw();
   }

   void onCSNotify(Widget w, Purpose p)
   {
      if (p >= SP && p <= ALL)
      {
         if ((cast(ToggleButton) w).getActive())
         {
            if (po.activeCoords == p-SP)
               return;
            po.activeCoords = p-SP;
         }
         return;
      }
      if (p == Purpose.NEWVERTEX)
      {
         po.editStack ~= po.pcPath.dup;
         po.currentStack ~= po.current;
         po.insertVertex();
         sides++;
         po.dirty = true;
         po.reDraw();
         return;
      }
      if (p == Purpose.DELEDGE)
      {
         po.editStack ~= po.pcPath.dup;
         po.currentStack ~= po.current;
         po.deleteEdge();
         sides--;
         po.dirty = true;
         po.reDraw();
         return;
      }
      if (p == Purpose.LINE2CURVE)
      {
         int t = po.pcPath[po.current].type;
         if (t == 1)
         {
            t = 0;
            lcb.setLabel("To Curve");
         }
         else
         {
            t = 1;
            lcb.setLabel("To Line");
         }


         po.pcPath[po.current].type = t;
         po.dirty = true;
         po.reDraw();
         return;
      }
      if (p == Purpose.UNDO)
      {
         size_t l = po.editStack.length;
         if (l)
         {
            po.pcPath = po.editStack[l-1];
            po.current = po.currentStack[l-1];
            po.editStack.length = l-1;
            po.currentStack.length = l-1;
            po.dirty = true;
            po.reDraw();
         }
         return;
      }
      if (p== Purpose.ZOOMED)
      {
         if (ignoreZoom)
            return;
         if (po.zoomed)
            po.setupZoom(false);
         else
            po.setupZoom(true);
         return;
      }
      if (p== Purpose.PROTECT)
      {
         if (ignoreProtect)
            return;
         po.protect = !po.protect;
         return;
      }
   }
}

class Polycurve : LineSet
{
   static int nextOid = 0;
   PathItem root;
   PathItem[] pcPath, unreflected;
   PathItem[][] editStack;
   Coord topLeft, bottomRight;
   int[] currentStack;
   double editOpacity;
   bool constructing, editing, open;
   int current, prev, next, lastCurrent, lastActive, edits;
   PolyCurveDlg md;
   int activeCoords;
   // For zoomed edting
   double esf, zw, zh;
   Coord vo;
   bool zoomed, protect;
   Button rfb;

   override void syncControls()
   {
      cSet.setLineParams(lineWidth);
      cSet.toggling(false);
      if (les)
         cSet.setToggle(Purpose.LESSHARP, true);
      else
         cSet.setToggle(Purpose.LESROUND, true);
      cSet.setToggle(Purpose.OUTLINE, outline);
      cSet.setToggle(Purpose.OPEN, open);
      cSet.setComboIndex(Purpose.XFORMCB, xform);
      cSet.setComboIndex(Purpose.FILLOPTIONS, 0);
      cSet.setLabel(Purpose.LINEWIDTH, formatLT(lineWidth));
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(Polycurve other)
   {
      this(other.aw, other.parent);
      if (other.constructing)
      {
         aw.popupMsg("The Polycurve you are copying is not complete.\nCreating blank Polycurve in construct mode.",MessageType.WARNING);
         constructing = true;
         return;
      }
      if (other.unreflected.length)
      {
         unreflected = other.unreflected.dup;
         rfb.setLabel("Unreflect");
      }
      constructing = false;
      hOff = other.hOff;
      vOff = other.vOff;
      open = other.open;
      baseColor = other.baseColor.copy();
      altColor = other.altColor.copy();
      lineWidth = other.lineWidth;
      les = other.les;
      fill = other.fill;
      outline = other.outline;
      fillFromPattern = other.fillFromPattern;
      fillUid = other.fillUid;
      center = other.center;
      activeCoords = other.activeCoords;
      cSet.enable(Purpose.REDRAW);
      cSet.enable(Purpose.REFLECT);
      pcPath = other.pcPath.dup;
      current = other.current;
      xform = other.xform;
      tf = other.tf;
      editStack ~= other.pcPath.dup;
      currentStack ~= current;
      dirty = true;
      editing = other.editing;
      syncControls();
      if (other.editing)
      {
         other.hideDialogs();
         other.editing = false;
         other.switchMode();
         md.setControls();
         switchMode();
      }
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Polycurve "~to!string(++nextOid);
      super(w, parent, s, AC_POLYCURVE, ACGroups.GEOMETRIC);
      notifyHandlers ~= &Polycurve.notifyHandler;
      closed = true;
      center.x = 0.5*width;
      center.y = 0.5*height;
      constructing = true;
      altColor = new RGBA(1,1,1,1);
      fill = false;
      editOpacity = 0.5;
      esf = 1;
      les = true;
      md = new PolyCurveDlg("Edit "~s, this);
      md.setSizeRequest(240, 200);
      md.setPosition(GtkWindowPosition.POS_NONE);
      int px, py;
      root.type= -2;
      aw.getPosition(px, py);
      md.move(px+4, py+300);
      tm = new Matrix(&tmData);
      edits = 0;

      setupControls(3);
      outline = true;
      cSet.addInfo(
"Click in the Drawing Area to add curves.\nThese will initially be shown as straight\n lines. Right-click when finished - the\nlast curve will be added then.");
      positionControls(true);
   }

   override void extendControls()
   {
      int vp = cSet.cy;
      CheckButton cb = new CheckButton("Open");
      cSet.add(cb, ICoord(240, vp-67), Purpose.OPEN);

      ComboBoxText cbb = new ComboBoxText(false);
      cbb.setTooltipText("Select transformation to apply");
      cbb.setSizeRequest(100, -1);
      cbb.appendText("Scale");
      cbb.appendText("Stretch-H");
      cbb.appendText("Stretch-V");
      cbb.appendText("Skew-H");
      cbb.appendText("Skew-V");
      cbb.appendText("Rotate");
      cbb.appendText("Flip-H");
      cbb.appendText("Flip-V");
      cbb.setActive(0);
      cSet.add(cbb, ICoord(175, vp-35), Purpose.XFORMCB);
      new MoreLess(cSet, 0, ICoord(285, vp-30), true);

      new InchTool(cSet, 0, ICoord(0, vp), true);

      rfb = new Button("Reflect");
      rfb.setSizeRequest(80, -1);
      rfb.setSensitive(!constructing);
      cSet.add(rfb, ICoord(176, vp+2), Purpose.REFLECT);
      Button b = new Button("Edit");
      b.setSizeRequest(70, -1);
      b.setSensitive(!constructing);
      cSet.add(b, ICoord(260, vp+2), Purpose.REDRAW);

      cSet.cy = vp+40;
   }

   override void afterDeserialize()
   {
      constructing = editing = false;
      dirty = true;
      cSet.enable(Purpose.REDRAW);
      cSet.setInfo("Click the Edit button to move, add, or delete curves");
   }

   override void hideDialogs()
   {
      if (editing)
      {
         editing = false;
         md.hide();
         switchMode();
      }
   }

   override bool notifyHandler(Widget w, Purpose p)
   {
      switch (p)
      {
      case Purpose.REDRAW:
         lastOp = push!(PathItem[])(this, pcPath, OP_REDRAW);
         editing = !editing;
         switchMode();
         focusLayout();
         break;
      case Purpose.REFLECT:
         lastOp = push!Path_t(this, oPath, OP_REDRAW);
         if (unreflected !is null)
         {
            pcPath = unreflected;
            unreflected = null;
            rfb.setLabel("Reflect");
         }
         else
         {
            reflect();
            rfb.setLabel("Unreflect");
         }
         break;
      case Purpose.OPEN:
         open = !open;
         if (open)
            cSet.disable(Purpose.FILLTYPE);
         else
            cSet.enable(Purpose.FILLTYPE);
         if (!constructing)
            correctEnd();
         current = 0;
         figureNextPrev();
         break;
      default:
         return false;
      }
      return true;
   }
/*
   override bool specificNotify(Widget w, Purpose wid)
   {
      switch (wid)
      {
      case Purpose.REDRAW:
         lastOp = push!(PathItem[])(this, pcPath, OP_REDRAW);
         editing = !editing;
         switchMode();
         focusLayout();
         return true;
      case Purpose.REFLECT:
         lastOp = push!Path_t(this, oPath, OP_REDRAW);
         if (unreflected !is null)
         {
            pcPath = unreflected;
            unreflected = null;
            rfb.setLabel("Reflect");
         }
         else
         {
            reflect();
            rfb.setLabel("Unreflect");
         }
         return true;
      case Purpose.OPEN:
         open = !open;
         if (open)
            cSet.disable(Purpose.FILLTYPE);
         else
            cSet.enable(Purpose.FILLTYPE);
         if (!constructing)
            correctEnd();
         current = 0;
         figureNextPrev();
         return true;
      default:
         return false;
      }
   }
*/
   void correctEnd()
   {
      double dx = pcPath[0].start.x-pcPath[$-1].end.x;
      double dy = pcPath[0].start.y-pcPath[$-1].end.y;
      adjustEnd(pcPath[$-1], EP, dx, dy);
   }

   void switchMode()
   {
      if (editing)
      {
         md.showAll();
         cSet.setLabel(Purpose.REDRAW, "Design");
         cSet.setInfo("Click the Design button, or close the edit\ndialog to exit edit mode.");
      }
      else
      {
         setupZoom(false);
         md.hide();
         cSet.setLabel(Purpose.REDRAW, "Edit");
         cSet.setInfo("Click the Edit button to move, add, or delete curves");
      }
      reDraw();
   }

   override bool specificUndo(CheckPoint cp)
   {
      switch (cp.type)
      {
      case OP_REDRAW:
         constructing = false;
         pcPath = cp.pcPath.dup;
         lastOp = OP_UNDEF;
         dirty = true;
         break;
      default:
         return false;
      }
      return true;
   }

   override void preResize(int oldW, int oldH)
   {
      center.x = width/2;
      center.y = height/2;
      double hr = cast(double) width/oldW;
      double vr = cast(double) height/oldH;
      tm.initScale(hr, vr);
      for (int i = 0; i < pcPath.length; i++)
      {
         tm.transformPoint(pcPath[i].end.x, pcPath[i].end.y);
         tm.transformPoint(pcPath[i].cp1.x, pcPath[i].cp1.y);
         tm.transformPoint(pcPath[i].cp2.x, pcPath[i].cp2.y);
      }
      hOff *= hr;
      vOff *= vr;
   }

   static PathItem makePathItem(PathItem last, double x, double y)
   {
      PathItem pi;
      pi.type = 1;
      pi.start = last.end;
      pi.end = Coord(x, y);
      pi.cp1 = Coord(last.end.x+(x-last.end.x)/3, last.end.y+(y-last.end.y)/3);
      pi.cp2 = Coord(last.end.x+2*(x-last.end.x)/3, last.end.y+2*(y-last.end.y)/3);
      pi.cog = Coord(last.end.x+(x-last.end.x)/2, last.end.y+(y-last.end.y)/2);
      return pi;
   }

   static pure double distance(Coord a, Coord b)
   {
      double dx = a.x-b.x, dy = a.y-b.y;
      return sqrt(dx*dx+dy*dy);
   }

   double scaledDistance(Coord a, Coord b)
   {
//writefln("w %f h %f zw %f zh %f", 1.0*width, 1.0*height, zbr.x-zo.x, zbr.y-zo.y);
//writefln("%f - %f %f, %f %f",esf, zo.x,zo.y,vo.x,vo.y);
//writefln("cog %f %f mouse %f %f", a.x, a.y, b.x,b.y);
      Coord as = a, bs = b;
      if (zoomed)
      {
         as.x = a.x*esf;
         as.y = a.y*esf;
         bs.x = vo.x+b.x;
         bs.y = vo.y+b.y;
//writefln("scog %f %f mouse %f %f", as.x, as.y, bs.x, bs.y);
      }
      double d = distance(as,bs);
      return d;
   }

   void reflect()
   {
      unreflected = pcPath.dup;
      Coord s = Coord(pcPath[0].start.x, pcPath[0].start.y), e = Coord(pcPath[$-1].start.x, pcPath[$-1].start.y);
      double m = (e.y-s.y)/(e.x-s.x);
      double c = s.y-m*s.x;
      Coord mp(Coord p)
      {
         double d = (p.x + (p.y - c)*m)/(1 + m*m);
         return Coord(2*d-p.x, 2*d*m - p.y + 2*c);
      }
      PathItem[] half2;
      half2.length = pcPath.length-1;
      for (size_t i = pcPath.length-2, j = 0;; i--, j++)
      {
         with (half2[j])
         {
            type = pcPath[i].type;
            start = mp(pcPath[i].end);
            cp1 = mp(pcPath[i].cp2);
            cp2 = mp(pcPath[i].cp1);
            end = mp(pcPath[i].start);
            double tx = start.x+cp1.x+cp2.x+end.x;
            double ty = start.y+cp1.y+cp2.y+end.y;
            cog = Coord(tx/4, ty/4);
         }
         if (i == 0) break;
      }
      pcPath.length = pcPath.length-1;
      pcPath ~= half2;
   }

   static movePoint(ref Coord c, double dx, double dy, double factor = 1)
   {
      if (factor == 1)
      {
         c.x += dx*factor;
         c.y += dy*factor;
      }
      else
      {
         c.x += dx;
         c.y += dy;
      }
   }

   void setComplete()
   {
      constructing = false;
      center = figureCenter();
      cSet.enable(Purpose.REDRAW);
      cSet.enable(Purpose.REFLECT);
      cSet.setInfo("Click the Edit button to move, add, or delete curves");
      figureNextPrev();
   }

   override bool buttonPress(Event e, Widget w)
   {
      GdkModifierType state;
      e.getState(state);
      if (constructing)
      {
         focusLayout();
         PathItem last;
         bool started;
         if (root.type == -2)
         {
            root.type = -1;
            root.end = Coord(e.motion.x, e.motion.y);
            return true;
         }
         else if (root.type == -1)
         {
            last = root;
         }
         else
         {
            last = pcPath[pcPath.length-1];
         }
         if (e.button.button == 1)
         {
            if (state & GdkModifierType.CONTROL_MASK)
               pcPath ~= makePathItem(last, last.end.x, e.motion.y);
            else if (state & GdkModifierType.SHIFT_MASK)
               pcPath ~= makePathItem(last, e.motion.x, last.end.y);
            else
               pcPath ~= makePathItem(last, e.motion.x, e.motion.y);
            root.type = 0;
            reDraw();
            return true;
         }
         else if (e.button.button == 3)
         {
            if (open)
            {
               if (pcPath.length < 1)
               {
                  aw.popupMsg("You should add at least one curve before you finish", MessageType.WARNING);
                  return true;
               }
            }
            else
            {
               if (pcPath.length < 1)
               {
                  aw.popupMsg("You must draw at least edge before you close the polycurve", MessageType.WARNING);
                  return true;
               }
            }
            PathItem pi = makePathItem(last, root.end.x, root.end.y);
            pcPath ~= pi;
            dirty = true;
            editStack ~= pcPath.dup;
            setComplete();
            currentStack ~= 0;
            aw.dirty = true;
            reDraw();
            return true;
         }
         return false;
      }
      else if (editing)
      {
         if (e.button.button == 3)
         {
            Coord m = Coord(e.button.x, e.button.y);
            double cogoffx = 0, cogoffy = 0;
            double minsep = double.max;
            int best = 0;
            size_t last = pcPath.length;
            if (open)
               last--;
            foreach (size_t i, PathItem pi; pcPath)
            {
               if (i >= last)
                  break;
               Coord ccog = Coord(pi.cog.x, pi.cog.y);
               double d = scaledDistance(ccog, m);
               if (d < minsep)
               {
                  best = cast(int) i;
                  minsep = d;
               }
            }
            if (current != best)
            {
               lastCurrent = current;
               current = best;
               md.onCurrentChanged();
            }
            else
               return true;
            reDraw();
            return true;
         }
      }
      return ACBase.buttonPress(e, w);
   }

   override bool buttonRelease(Event e, Widget w)
   {
      if (constructing)
      {
         return true;
      }
      else
      {
         return ACBase.buttonRelease(e, w);
      }
   }

   override bool mouseMove(Event e, Widget w)
   {
      if (constructing)
      {
         return true;
      }
      else
      {
         return ACBase.mouseMove(e, w);
      }
   }

   void resetCog()
   {
      PathItem* p = &pcPath[current];
      double tx = p.start.x+p.cp1.x+p.cp2.x+p.end.x;
      double ty = p.start.y+p.cp1.y+p.cp2.y+p.end.y;
      pcPath[current].cog = Coord(tx/4, ty/4);
   }

   override void onCSMoreLess(int instance, bool more, bool coarse)
   {
      focusLayout();
      if (instance == 0)
         modifyTransform(xform, more, coarse);
      else
         return;
      dirty = true;
      aw.dirty = true;
      reDraw();
   }

   void insertVertex()
   {
      bool last = (current == pcPath.length-1);
      PathItem pi = pcPath[current];
      PathItem* a = &pcPath[current];
      Coord oldEnd = a.end;
      a.cp1 = Coord((pi.start.x+pi.cp1.x)/2, (pi.start.y+pi.cp1.y)/2);
      a.cp2 = Coord((pi.start.x+2*pi.cp1.x+pi.cp2.x)/4, (pi.start.y+2*pi.cp1.y+pi.cp2.y)/4);    // (p0+2p1+p2)/4
      a.end = Coord((pi.start.x+3*(pi.cp1.x+pi.cp2.x)+pi.end.x)/8, (pi.start.y+3*(pi.cp1.y+pi.cp2.y)+pi.end.y)/8);   // (p0+3(p1+p2)+p3)/8
      double tx = a.start.x+a.cp1.x+a.cp2.x+a.end.x;
      double ty = a.start.y+a.cp1.y+a.cp2.y+a.end.y;
      a.cog = Coord(tx/4, ty/4);
      PathItem b;
      b.start = a.end;
      b.cp1 = Coord((pi.end.x+2*pi.cp2.x+pi.cp1.x)/4, (pi.end.y+2*pi.cp2.y+pi.cp1.y)/4);           // (p3+2p2+p1)/4
      b.cp2 = Coord((pi.cp2.x+pi.end.x)/2, (pi.cp2.y+pi.end.y)/2);   // (p2+p3)/2
      b.end = pi.end;
      tx = b.start.x+b.cp1.x+b.cp2.x+b.end.x;
      ty = b.start.y+b.cp1.y+b.cp2.y+b.end.y;
      b.cog = Coord(tx/4, ty/4);

      pcPath.length = pcPath.length+1;
      if (last)
         pcPath[$-1] = b;
      else
      {
         PathItem[] t;
         t.length = pcPath.length;
         t[] = pcPath[];
         t[current+2..$] = pcPath[current+1.. $-1];
         t[current+1] = b;
         pcPath=t;
      }
      dirty = true;
   }

   void deleteEdge()
   {
      if (pcPath.length == 1)
         return;
      figureNextPrev();
      PathItem* p = &pcPath[current];
      Coord halfPoint = Coord(p.start.x+(p.end.x-p.start.x)/2, p.start.y+(p.end.y-p.start.y)/2);
      if (prev != -1)
         adjustEnd(pcPath[prev], EP, halfPoint.x-pcPath[prev].end.x, halfPoint.y-pcPath[prev].end.y);
      if (pcPath.length > 1)
         adjustEnd(pcPath[next], SP, halfPoint.x-pcPath[next].start.x, halfPoint.y-pcPath[next].start.y);
      if (current == pcPath.length-1)
      {
         pcPath.length = pcPath.length-1;
         current--;
      }
      else
      {
         PathItem[] t;
         t.length = pcPath.length-1;
         t[0..current] = pcPath[0..current];
         t[current..$] = pcPath[current+1..$];
         pcPath.length = pcPath.length-1;
         pcPath = t;
      }
      figureNextPrev();
      dirty = true;
   }

   void adjustEnd(ref PathItem pi, int te, double dx, double dy)
   {
      Coord* pt, pref;
      if (te == SP)
      {
         pt = &pi.start;
         pref = &pi.end;
      }
      else
      {
         pt = &pi.end;
         pref = &pi.start;
      }
      double rd = distance(*pt, *pref);
      movePoint(*pt, dx, dy);
      double d = distance(pi.cp1, *pref);
      movePoint(pi.cp1, dx, dy, d/rd);
      d = distance(pi.cp2, *pref);
      movePoint(pi.cp2, dx, dy, d/rd);
   }

   void getBounding()
   {
      Coord tl, br;
      double left = width, right = 0, top = height, bottom = 0;
      foreach (PathItem pi; pcPath)
      {
         if (pi.start.x > right)
            right = pi.start.x;
         if (pi.start.x < left)
            left = pi.start.x;
         if (pi.start.y > bottom)
            bottom = pi.start.y;
         if (pi.start.y < top)
            top = pi.start.y;
         if (pi.end.x > right)
            right = pi.cp1.x;
         if (pi.end.x < left)
            left = pi.end.x;
         if (pi.end.y > bottom)
            bottom = pi.end.y;
         if (pi.end.y < top)
            top = pi.end.y;
         if (pi.type == 1)
         {
            if (pi.cp1.x > right)
               right = pi.cp1.x;
            if (pi.cp1.x < left)
               left = pi.cp1.x;
            if (pi.cp1.y > bottom)
               bottom = pi.cp1.y;
            if (pi.cp1.y < top)
               top = pi.cp1.y;
            if (pi.cp2.x > right)
               right = pi.cp2.x;
            if (pi.cp2.x < left)
               left = pi.cp2.x;
            if (pi.cp2.y > bottom)
               bottom = pi.cp2.y;
            if (pi.cp2.y < top)
               top = pi.cp2.y;
         }
      }
      topLeft = Coord(left, top);
      bottomRight = Coord(right, bottom);
   }

   Coord figureCenter()
   {
      getBounding();
      Coord c = Coord(topLeft.x+0.5*(bottomRight.x-topLeft.x), topLeft.y+0.5*(bottomRight.y-topLeft.y));
      return c;
   }

   void rSegTo(Context c, PathItem pi)
   {
      if (pi.type == 1)
         c.curveTo(pi.cp1.x, pi.cp1.y, pi.cp2.x, pi.cp2.y, pi.end.x, pi.end.y);
      else
         c.lineTo(pi.end.x, pi.end.y);
   }

   void eSegTo(Context c, PathItem pi)
   {
      if (pi.type == 1)
         c.curveTo(pi.cp1.x, pi.cp1.y, pi.cp2.x, pi.cp2.y, pi.end.x, pi.end.y);
      else
         c.lineTo(pi.end.x, pi.end.y);
   }

   void colorEdge(Context c, double r, double g, double b, PathItem pi)
   {
      c.setSourceRgb(r,g,b);
      double lw = 1;
      if (zoomed) lw /= esf;
      c.setLineWidth(lw);
      c.moveTo(pi.start.x, pi.start.y);
      if (pi.type == 1)
         c.curveTo(pi.cp1.x, pi.cp1.y, pi.cp2.x, pi.cp2.y, pi.end.x, pi.end.y);
      else
         c.lineTo(pi.end.x, pi.end.y);
      c.stroke();
   }

   void renderActual(Context c)
   {
      if (constructing)
      {
         c.setSourceRgba(1,1,1, editOpacity);
         c.paint();
         if (pcPath.length < 1)
            return;
         c.setSourceRgb(0.8, 0.8, 0.8);
         c.moveTo(root.end.x, root.end.y);
         for (int i = 0; i < pcPath.length; i++)
            c.curveTo(pcPath[i].cp1.x, pcPath[i].cp1.y, pcPath[i].cp2.x, pcPath[i].cp2.y, pcPath[i].end.x, pcPath[i].end.y);
         c.setLineWidth(1.0);
         c.stroke();
         return;
      }
      if (pcPath.length < 1)
         return;

      c.translate(hOff+center.x, vOff+center.y);
      if (compoundTransform())
         c.transform(tm);
      c.translate(-center.x, -center.y);

      c.setLineWidth(lineWidth);
      c.setLineJoin(les? CairoLineJoin.MITER: CairoLineJoin.ROUND);
      c.moveTo(pcPath[0].start.x, pcPath[0].start.y);
      size_t lim = pcPath.length;
      if (open)
         lim--;
      for (size_t i = 0; i < lim; i++)
         rSegTo(c, pcPath[i]);
      if (!open)
         c.closePath();
      if (open)
         fill = false;
      strokeAndFill(c, lineWidth, outline, fill);
   }

   void adjustPI(double dx, double dy)
   {
      edits++;
      size_t len = pcPath.length;
      if (current != lastCurrent || activeCoords != lastActive )
      {
         editStack ~= pcPath.dup;
         currentStack ~= current;
         lastCurrent = current;
         lastActive = activeCoords;
      }
//writefln("curr %d prev %d next %d", current,prev,next);
      switch (activeCoords)
      {
         case 0:  // SP
            adjustEnd(pcPath[current], SP, dx, dy);
            if ((open && prev != -1) || !open)
               adjustEnd(pcPath[prev], EP, dx, dy);
            break;
         case 1:  // EP
            adjustEnd(pcPath[current], EP, dx, dy);
            if ((open && current < len-2) || !open)
               adjustEnd(pcPath[next], SP, dx, dy);
            break;
         case 2:  // CP1
            if (pcPath[current].type != 1)
               return;
            movePoint(pcPath[current].cp1, dx, dy);
            break;
         case 3:  // CP2
            if (pcPath[current].type != 1)
               return;
            movePoint(pcPath[current].cp2, dx, dy);
            break;
         case 4:  // BOTHCP
            if (pcPath[current].type != 1)
               return;
            movePoint(pcPath[current].cp1, dx, dy);
            movePoint(pcPath[current].cp2, dx, dy);
            break;
         case 5: // SPEP
            adjustEnd(pcPath[current], SP, dx, dy);
            if ((open && prev != -1) || !open)
               adjustEnd(pcPath[prev], EP, dx, dy);
            adjustEnd(pcPath[current], EP, dx, dy);
            if ((open && current < len-2) || !open)
               adjustEnd(pcPath[next], SP, dx, dy);
            break;
         case 6: // All
            movePoint(pcPath[current].start, dx, dy);
            movePoint(pcPath[current].end, dx, dy);
            movePoint(pcPath[current].cp1, dx, dy);
            movePoint(pcPath[current].cp2, dx, dy);
            if ((open && current < len-2) || !open)
               adjustEnd(pcPath[next], SP, dx, dy);
            if ((open && prev != -1) || !open)
               adjustEnd(pcPath[prev], EP, dx, dy);
            break;
         default:
            break;
      }
      dirty = true;
   }

   override void mouseMoveOp(double dx, double dy, GdkModifierType state)
   {
      if (constructing)  // Only interested in clicks
         return;
      if (!editing)
      {
         hOff += dx;
         vOff += dy;
         return;
      }
      if (state & GdkModifierType.CONTROL_MASK)
      {
         adjustView(dx, dy);
         reDraw();
         return;
      }

      if (protect)
      {
         aw.popupMsg("You were zooming or moving the viewport, and so protect\nhas been turned on automatically.\nUncheck 'Protect' to proceed.", MessageType.INFO);
         return;
      }
      figureNextPrev();
      adjustPI(dx, dy);
      resetCog();
   }

   void figureNextPrev()
   {
      size_t l = pcPath.length;
      if (current == 0)
         prev = open? -1: cast(int)(l-1);
      else
         prev = current-1;
      if (current == l-1)
         next = 0;
      else
         next = current+1;
   }

   void renderForEdit(Context c)
   {
      doZoom(c);
      c.setSourceRgba(1,1,1, editOpacity);
      c.paint();
      c.setSourceRgb(0,0,0);
      double lw = 1;
      if(zoomed) lw /= esf;
      c.setLineWidth(lw);
      c.moveTo(pcPath[0].start.x, pcPath[0].start.y);
      size_t lim = pcPath.length;
      if (open)
         lim--;
      for (int i = 0; i < lim; i++)
         eSegTo(c, pcPath[i]);
      if (!open && pcPath.length > 0)
         c.closePath();
      c.stroke();

      figureNextPrev();

      lw *= 2;
      c.setLineWidth(lw);
      colorEdge(c, 1, 0, 0, pcPath[current]);

      if (prev != -1)
         colorEdge(c, 0, 1, 0, pcPath[prev]);
      if (pcPath[current].type == 1)
      {
         double cpd = 3;
         if (zoomed) cpd /= esf;
         // Render the current control points
         c.setSourceRgb(0,0,0);
         c.moveTo(pcPath[current].cp1.x, pcPath[current].cp1.y-cpd);
         c.lineTo(pcPath[current].cp1.x+cpd, pcPath[current].cp1.y+cpd);
         c.lineTo(pcPath[current].cp1.x-cpd, pcPath[current].cp1.y+cpd);
         c.closePath();
         c.fill();

         c.setSourceRgb(0,0,1);
         c.moveTo(pcPath[current].cp2.x, pcPath[current].cp2.y+cpd);
         c.lineTo(pcPath[current].cp2.x+cpd, pcPath[current].cp2.y-cpd);
         c.lineTo(pcPath[current].cp2.x-cpd, pcPath[current].cp2.y-cpd);
         c.closePath();
         c.fill();
      }
   }

   override void render(Context c)
   {
      if (editing)
         renderForEdit(c);
      else
         renderActual(c);
   }

   void notifyContainer(bool ofWhat)
   {

   }

   void adjustView(double dx, double dy)
   {
      if (dx > 0)
      {
         if (vo.x-dx > 0)
            vo.x -= dx;
         else
            vo.x = 0;
      }
      else
      {
         dx = -dx;
         if (vo.x+width+dx < zw)
            vo.x += dx;
         else
            vo.x = zw-width;
      }
      if (dy > 0)
      {
         if (vo.y-dy > 0)
            vo.y -= dy;
         else
            vo.y = 0;
      }
      else
      {
         dy = -dy;
         if (vo.y+height+dy < zh)
            vo.y += dy;
         else
            vo.y = zh-height;
      }
   }

   void adjustZoom(double by)
   {
      double oldEsf = esf;
      esf += by;
      zw = width*esf;
      zh = height*esf;
      vo.x *= esf/oldEsf;
      vo.y *= esf/oldEsf;
      reDraw();
   }

   void setupZoom(bool b)
   {
      if (b)
      {
         zoomed = true;
         protect = true;
         if (esf == 1)
            adjustZoom(1);
         vo=Coord(zw/2-0.5*width, zh/2-0.5*height);
         md.ignoreZoom = true;
         md.cbZoom.setActive(1);
         md.ignoreZoom = false;
         md.ignoreProtect = true;
         md.cbProtect.setActive(1);
         md.cbProtect.setSensitive(1);
         md.ignoreProtect = false;
         reDraw();
      }
      else
      {
         md.ignoreZoom = true;
         md.cbZoom.setActive(0);
         md.ignoreZoom = false;
         md.ignoreProtect = true;
         md.cbProtect.setActive(0);
         md.ignoreProtect = false;
         zoomed = false;
         protect = false;
         md.cbProtect.setSensitive(0);
         if (parent !is null && parent.type == AC_CONTAINER)
            (cast(Container) parent).unZoom();
         reDraw();
      }
   }

   override void doZoom(Context c)
   {
      if (zoomed)
      {
         c.scale(esf,esf);
         c.translate(-vo.x/esf, -vo.y/esf);
      }
   }
}


