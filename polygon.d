
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module polygon;

import mainwin;
import container;
import constants;
import acomp;
import common;
import types;
import controlset;
import lineset;
import interfaces;

import std.stdio;
import std.math;
import std.conv;

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
import gtk.SpinButton;
import gtk.CheckButton;
import gtk.Label;
import gtk.Dialog;
import gtk.VBox;
import gtk.Entry;
import cairo.Context;
import gtkc.cairotypes;
import cairo.Matrix;

class PolyEditDlg: Dialog, CSTarget
{
   enum
   {
      SP = Purpose.R_CHECKBUTTONS-100,
      EP,
      BOTH
   }

   Polygon po;
   ControlSet cs;
   Layout layout;
   int sside, sides;
   CheckButton cbZoom, cbProtect;
   bool ignoreZoom, ignoreProtect;

   this(string title, Polygon o)
   {
      GtkResponseType rta[1] = [ ResponseType.OK ];
      string[1] sa = [];
      super(title, o.aw, DialogFlags.DESTROY_WITH_PARENT, sa, rta);
      this.addOnDelete(&catchClose);
      po = o;
      sides = po.oPath.length;
      layout = new Layout(null, null);
      cs=new ControlSet(this);
      VBox vb = getContentArea();
      vb.packStart(layout, 1, 1, 0);
      layout.show();
      addGadgets();
   }

   string onCSInch(int instance, int direction, bool coarse) { return ""; }
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

      vp+= 60;
      RadioButton rb1 = new RadioButton("Start point");
      cs.add(rb1, ICoord(5, vp), cast(Purpose) SP);

      vp += vi;
      RadioButton rb = new RadioButton(rb1, "End point");
      cs.add(rb, ICoord(5, vp), cast(Purpose) EP);

      vp += vi;
      rb = new RadioButton(rb1, "Both");
      cs.add(rb, ICoord(5, vp), cast(Purpose) BOTH);

      vp = 10;
      Label l= new Label("Active edge");
      cs.add(l, ICoord(120, vp), Purpose.LABEL);
      MoreLess mol = new MoreLess(cs, 0, ICoord(200, vp), true);
      mol.setIntervals(170, 200);

      vp += 45;
      Button b = new Button("Add a Vertex");
      cs.add(b, ICoord(120, vp), Purpose.NEWVERTEX);

      vp += 30;
      b = new Button("Delete Edge");
      cs.add(b, ICoord(120, vp), Purpose.DELEDGE);

      vp += 30;
      b = new Button("Do");
      b.setTooltipText("Remember this state");
      cs.add(b, ICoord(120, vp), Purpose.REMEMBER);
      b = new Button("Undo");
      cs.add(b, ICoord(150, vp), Purpose.UNDO);

      vp += 30;
      l = new Label("Opacity");
      cs.add(l, ICoord(145, vp), Purpose.LABEL);
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

   static void moveCoord(ref Coord p, double distance, double angle)
   {
      p.x += cos(angle)*distance;
      p.y -= sin(angle)*distance;
   }

   void onCSMoreLess(int instance, bool more, bool coarse)
   {
      if (instance == 0)
      {
         sides = po.oPath.length;
         po.lastCurrent = po.current;
         if (more)
         {
            if (po.current < sides-1)
               po.current++;
            else
               po.current=0;
         }
         else
         {
            if (po.current == 0)
               po.current = sides-1;
            else
               po.current--;
         }
         sside = po.current;
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
               po.adjustZoom(0.1);
            po.notifyContainer(true);
         }
         else
         {
            if (po.esf-0.05 < 1)
               po.setupZoom(false);
            else
               po.adjustZoom(-0.1);
            po.notifyContainer(false);
         }
      }
   }

   void onCSCompass(int instance, double angle, bool coarse)
   {
      double d = coarse? 2: 0.5;
      Coord dummy = Coord(0,0);
      moveCoord(dummy, d, angle);
      double dx = dummy.x, dy = dummy.y;
      po.adjustPI(dx, dy);
      po.reDraw();
   }

   void onCSNotify(Widget w, Purpose p)
   {
      if (p >= SP && p <= BOTH)
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
         po.editStack ~= po.oPath.dup;
         po.currentStack ~= po.current;
         po.insertVertex();
         sides++;
         po.reDraw();
         return;
      }
      if (p == Purpose.DELEDGE)
      {
         po.editStack ~= po.oPath.dup;
         po.currentStack ~= po.current;
         po.deleteEdge();
         sides--;
         po.reDraw();
         return;
      }
      if (p == Purpose.REMEMBER)
      {
         po.editStack ~= po.oPath.dup;
         po.currentStack ~= po.current;
         return;
      }
      if (p == Purpose.UNDO)
      {
         int l= po.editStack.length;
         if (l)
         {
            po.oPath = po.editStack[l-1];
            po.current = po.currentStack[l-1];
            po.editStack.length = l-1;
            po.currentStack.length = l-1;
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

class Polygon : LineSet
{
   static int nextOid = 0;
   Coord[][] editStack;
   Coord topLeft, bottomRight;
   int[] currentStack;
   double editOpacity;
   bool constructing, editing;
   int current, next, prev, lastCurrent, lastActive;
   PolyEditDlg md;
   int activeCoords;
   // For zoomed edting
   double esf, zw, zh;
   Coord vo;
   bool zoomed, protect;

   override void syncControls()
   {
      cSet.setLineParams(lineWidth);
      cSet.toggling(false);
      if (les)
         cSet.setToggle(Purpose.LESSHARP, true);
      else
         cSet.setToggle(Purpose.LESROUND, true);
      if (outline)
         cSet.setToggle(Purpose.OUTLINE, true);
      cSet.setComboIndex(Purpose.XFORMCB, xform);
      cSet.setComboIndex(Purpose.FILLOPTIONS, 0);
      cSet.setLabel(Purpose.LINEWIDTH, formatLT(lineWidth));
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(Polygon other)
   {
      this(other.aw, other.parent);
      constructing = false;
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      altColor = other.altColor.copy();
      lineWidth = other.lineWidth;
      les = other.les;
      fill = other.fill;
      outline = other.outline;
      center = other.center;
      oPath = other.oPath.dup;
      xform = other.xform;
      tf = other.tf;
      editing = other.editing;
      cSet.enable(Purpose.REDRAW);
      cSet.setInfo("Click the Edit button to move, add, or delete edges");
      dirty = true;
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Polygon "~to!string(++nextOid);
      super(w, parent, s, AC_POLYGON);
      group = ACGroups.GEOMETRIC;
      closed = true;
      constructing = true;
      altColor = new RGBA(1,1,1,1);
      editOpacity = 0.5;
      esf = 1;
      zw = 0;
      zh = 0;
      les = true;
      md = new PolyEditDlg("Edit "~s, this);
      md.setSizeRequest(240, 200);
      md.setPosition(GtkWindowPosition.POS_NONE);
      int px, py;
      current = 0;
      activeCoords = 0;
      aw.getPosition(px, py);
      md.move(px+4, py+300);
      tm = new Matrix(&tmData);

      setupControls(3);
      outline = true;
      cSet.addInfo("Click in the Drawing Area to add edges.\nRight-click when finished - the\n last edge will be added then.");
      positionControls(true);
      dirty = true;
   }

   override void extendControls()
   {
      int vp = cSet.cy;

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

      Button b = new Button("Edit");
      b.setSizeRequest(70, -1);
      b.setSensitive(0);
      cSet.add(b, ICoord(203, vp+2), Purpose.REDRAW);

      cSet.cy = vp+40;
   }

   override void afterDeserialize()
   {
      constructing = editing = false;
      dirty = true;
      cSet.setInfo("Click the Edit button to move, add, or delete points");
   }

   void setComplete()
   {
      center = figureCenter();
      constructing = false;
      cSet.enable(Purpose.REDRAW);
      cSet.setInfo("Click the Edit button to move, add, or delete edges");
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

   override bool specificNotify(Widget w, Purpose wid)
   {
      switch (wid)
      {
      case Purpose.REDRAW:
         lastOp = push!Path_t(this, oPath, OP_REDRAW);
         editing = !editing;
         switchMode();
         focusLayout();
         return true;
      default:
         return false;
      }
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
         cSet.setInfo("Click the Edit button to move, add, or delete edges");
      }
      reDraw();
   }

   override bool specificUndo(CheckPoint cp)
   {
      switch (cp.type)
      {
      case OP_REDRAW:
         constructing = false;
         oPath = cp.path.dup;
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
      for (int i = 0; i < oPath.length; i++)
      {
         tm.transformPoint(oPath[i].x, oPath[i].y);
      }
      hOff *= hr;
      vOff *= vr;
   }

   static pure double distance(Coord a, Coord b)
   {
      double dx = a.x-b.x, dy = a.y-b.y;
      return sqrt(dx*dx+dy*dy);
   }

   double scaledDistance(Coord a, Coord b)
   {
//writefln("w %f h %f zw %f zh %f", 1.0*width, 1.0*height, zbr.x-zo.x, zbr.y-zo.y);
//writefln("%f - %f %f",esf, vo.x,vo.y);
//writefln("cog %f %f mouse %f %f", a.x, a.y, b.x, b.y);
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

   override bool buttonPress(Event e, Widget w)
   {
      GdkModifierType state;
      e.getState(state);
      if (constructing)
      {
         bool prev = (oPath.length > 0);
         focusLayout();
         Coord last;
         if (prev)
            last = oPath[oPath.length-1];
         if (e.button.button == 1)
         {
            if (prev && (state & GdkModifierType.CONTROL_MASK))
               oPath ~= Coord(last.x, e.motion.y);
            else if (prev && (state & GdkModifierType.SHIFT_MASK))
               oPath ~= Coord(e.motion.x, last.y);
            else
               oPath ~= Coord(e.motion.x, e.motion.y);
            reDraw();
            return true;
         }
         else if (e.button.button == 3)
         {
            if (oPath.length < 3)
            {
               aw.popupMsg("You must draw at least two sides before you close the polygon", MessageType.WARNING);
               return true;
            }
            if (state & GdkModifierType.CONTROL_MASK)
            {
               double x0 = oPath[0].x;
               oPath[oPath.length-1].x = x0;
            }
            else if (state & GdkModifierType.SHIFT_MASK)
            {
               double y0 = oPath[0].y;
               oPath[oPath.length-1].y = y0;
            }
            setComplete();
            dirty = true;
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
            double minsep = double.max;
            int best = 0;
            int last = oPath.length-1;
            foreach (int i, Coord c; oPath)
            {
               Coord nextv;
               if (i == last)
                  nextv = oPath[0];
               else
                  nextv = oPath[i+1];
               Coord half;
               half.x = c.x+(nextv.x-c.x)/2;
               half.y = c.y+(nextv.y-c.y)/2;

               double d = scaledDistance(half, m);
               if (d < minsep)
               {
                  best = i;
                  minsep = d;
               }
            }
            if (current != best)
            {
               lastCurrent = current;
               current = best;
            }
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
      int next = (current == oPath.length-1)? 0: current+1;
      Coord a = oPath[current], b = oPath[next];
      bool last = (current == oPath.length-1);
      double x = a.x+(b.x-a.x)/2;
      double y = a.y+(b.y-a.y)/2;
      oPath.length = oPath.length+1;
      if (last)
         oPath[$-1] = Coord(x, y);
      else
      {
         Coord[] t;
         t.length = oPath.length;
         t[] = oPath[];
         t[current+2..$] = oPath[current+1.. $-1];
         t[current+1] = Coord(x, y);
         oPath=t;
      }
      dirty = true;
   }

   void deleteEdge()
   {
      if (oPath.length == 3)
         return;
      if (current == oPath.length-1)
      {
         oPath.length = oPath.length-1;
         current--;
      }
      else
      {
         Coord[] t;
         t.length = oPath.length-1;
         t[0..current] = oPath[0..current];
         t[current..$] = oPath[current+1..$];
         oPath.length = oPath.length-1;
         oPath = t;
      }
      dirty = true;
   }


   void getBounding()
   {
      Coord tl, br;
      double left = width, right = 0, top = height, bottom = 0;
      foreach (Coord point; oPath)
      {
         if (point.x > right)
            right = point.x;
         if (point.x < left)
            left = point.x;
         if (point.y > bottom)
            bottom = point.y;
         if (point.y < top)
            top = point.y;
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

   void renderActual(Context c)
   {
      if (constructing)
      {
         c.setSourceRgba(1,1,1,0.9);
         c.paint();
         if (oPath.length < 2)
            return;
         c.setSourceRgb(1,0,0);
         c.moveTo(oPath[0].x, oPath[0].y);
         for (int i = 1; i < oPath.length; i++)
            c.lineTo(oPath[i].x, oPath[i].y);
         c.stroke();
         return;
      }
      if (oPath.length <  3)
         return;

      c.translate(hOff+center.x, vOff+center.y);
      if (compoundTransform())
         c.transform(tm);
      c.translate(-center.x, -center.y);

      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);
      c.setLineWidth(0);
      c.setLineJoin(les? CairoLineJoin.MITER: CairoLineJoin.ROUND);

      c.moveTo(oPath[0].x, oPath[0].y);
      for (int i = 1; i < oPath.length; i++)
      {
         c.lineTo(oPath[i].x, oPath[i].y);
      }
      c.closePath();
      strokeAndFill(c, lineWidth, outline, fill);
   }

   void adjustPI(double dx, double dy)
   {
      figureNextPrev();
      if (current != lastCurrent || activeCoords != lastActive )
      {
         editStack ~= oPath.dup;
         currentStack ~= current;
         lastCurrent = current;
         lastActive = activeCoords;
      }
      int next = (current == oPath.length-1)? 0: current+1;
      switch (activeCoords)
      {
         case 0:
            oPath[current].x += dx;
            oPath[current].y += dy;
            break;
         case 1:
            oPath[next].x += dx;
            oPath[next].y += dy;
            break;
         case 2:
            oPath[current].x += dx;
            oPath[current].y += dy;
            oPath[next].x += dx;
            oPath[next].y += dy;
            break;
         default:
            break;
      }
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
      adjustPI(dx, dy);
      dirty = true;
   }


   void figureNextPrev()
   {
      int l = oPath.length;
      if (current == 0)
         prev = l-1;
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
      c.setSourceRgba(1,1,1,editOpacity);
      c.paint();
      c.setSourceRgb(0,0,0);
      double lw = 0.5;
      if (zoomed) lw /= esf;
      c.setLineWidth(lw);
      c.moveTo(oPath[0].x, oPath[0].y);
      for (int i = 1; i < oPath.length; i++)
         c.lineTo(oPath[i].x, oPath[i].y);
      if (oPath.length > 2)
         c.closePath();
      c.stroke();
      figureNextPrev();
      c.setSourceRgb(1,0,0);
      c.setLineWidth(lw*2);
      c.moveTo(oPath[current].x, oPath[current].y);
      c.lineTo(oPath[next].x, oPath[next].y);
      c.stroke();
      c.setSourceRgb(0,1,0);
      c.moveTo(oPath[prev].x, oPath[prev].y);
      c.lineTo(oPath[current].x, oPath[current].y);
      c.stroke();
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


