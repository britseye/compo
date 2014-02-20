
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module pointset;

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

class PointSetEditDlg: Dialog, CSTarget
{
   PointSet po;
   ControlSet cs;
   Layout layout;
   CheckButton cbZoom, cbProtect;
   bool ignoreZoom, ignoreProtect;

   this(string title, PointSet o)
   {
      GtkResponseType rta[1] = [ ResponseType.OK ];
      string[1] sa = [];
      super(title, o.aw, DialogFlags.DESTROY_WITH_PARENT, sa, rta);
      this.addOnDelete(&catchClose);
      po = o;
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

      vp = 10;
      Label l= new Label("Active Point");
      cs.add(l, ICoord(120, vp), Purpose.LABEL);
      MoreLess mol = new MoreLess(cs, 0, ICoord(200, vp), true);
      mol.setIntervals(170, 200);

      vp += 30;
      Button b = new Button("Add Point");
      cs.add(b, ICoord(120, vp), Purpose.NEWVERTEX);

      vp += 30;
      b = new Button("Delete Point");
      cs.add(b, ICoord(120, vp), Purpose.DELEDGE);

      vp += 30;
      b = new Button("Undo");
      cs.add(b, ICoord(120, vp), Purpose.UNDO);

      vp += 30;
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

   static void moveCoord(ref Coord p, double distance, double angle)
   {
      p.x += cos(angle)*distance;
      p.y -= sin(angle)*distance;
   }

   void onCSMoreLess(int instance, bool more, bool coarse)
   {
      if (instance == 0)
      {
         int sides = cast(int) po.oPath.length;
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
      if (p == Purpose.NEWVERTEX)
      {
         po.editStack ~= po.oPath.dup;
         po.currentStack ~= po.current;
         po.insertPoint();
         po.reDraw();
         return;
      }
      if (p == Purpose.DELEDGE)
      {
         po.editStack ~= po.oPath.dup;
         po.currentStack ~= po.current;
         po.deletePoint();
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
         size_t l= po.editStack.length;
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

class PointSet : LineSet
{
   static int nextOid = 0;
   Coord[][] editStack;
   Coord topLeft, bottomRight;
   int[] currentStack;
   double editOpacity;
   bool constructing, editing;
   int current, next, prev, lastCurrent, lastActive;
   PointSetEditDlg md;
   // For zoomed edting
   double esf, zw, zh;
   Coord vo;
   bool zoomed, protect;

   override void syncControls()
   {
      cSet.setLineParams(lineWidth);
      //cSet.toggling(false);
      cSet.setLabel(Purpose.LINEWIDTH, formatLT(lineWidth));
      //cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(PointSet other)
   {
      this(other.aw, other.parent);
      constructing = false;
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      lineWidth = other.lineWidth;
      dirty = true;
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "PointSet "~to!string(++nextOid);
      super(w, parent, s, AC_POINTSET);
      group = ACGroups.GEOMETRIC;
      constructing = true;
      les = true;
      current = 0;
      esf = 1;
      md = new PointSetEditDlg("Edit "~s, this);
      md.setSizeRequest(240, 200);
      md.setPosition(GtkWindowPosition.POS_NONE);
      int px, py;
      aw.getPosition(px, py);
      md.move(px+4, py+300);
      tm = new Matrix(&tmData);
      editOpacity=0.8;

      setupControls(0);
      cSet.addInfo("Click in the Drawing Area to add points.\nRight-click when finished.");
      positionControls(true);
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
      cSet.add(cbb, ICoord(175, vp), Purpose.XFORMCB);
      new MoreLess(cSet, 0, ICoord(285, vp+5), true);

      new InchTool(cSet, 0, ICoord(0, vp+10), true);

      vp += 35;
      Button b = new Button("Edit");
      b.setSizeRequest(70, -1);
      b.setSensitive(0);
      cSet.add(b, ICoord(203, vp), Purpose.REDRAW);

      cSet.cy = vp+30;
   }

   override bool specificNotify(Widget w, Purpose wid)
   {
      switch (wid)
      {
      case Purpose.REDRAW:
         focusLayout();
         lastOp = push!Path_t(this, oPath, OP_REDRAW);
         editing = !editing;
         switchMode();
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
         cSet.setInfo("Click the Edit button to move, add, or delete points");
      }
      reDraw();
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

   static pure double distance(Coord a, Coord b)
   {
      double dx = a.x-b.x, dy = a.y-b.y;
      return sqrt(dx*dx+dy*dy);
   }

   static movePoint(ref Coord c, double dx, double dy, double factor = 1)
   {
      c.x += dx*factor;
      c.y += dy*factor;
   }

   override void afterDeserialize()
   {
      constructing = editing = false;
      dirty = true;
      cSet.enable(Purpose.REDRAW);
      cSet.setInfo("Click the Edit button to move, add, or delete points");
   }

   void setComplete()
   {
      constructing = false;
      figureCenter();
      cSet.enable(Purpose.REDRAW);
      cSet.setInfo("Click the Edit button to move, add, or delete points");
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
         focusLayout();
         bool prev = (oPath.length > 0);
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
            foreach (int i, Coord c; oPath)
            {
               c.x += center.x;
               c.y += center.y;
               double d = scaledDistance(c, m);
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

   void insertPoint()
   {
      int next = (current == oPath.length-1)? 0: current+1;
      Coord a = oPath[current];
      bool last = (current == oPath.length-1);
      double x = a.x+5;
      double y = a.y+5;
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
      current = (current == oPath.length-1)? 0: current+1;
      dirty = true;
   }

   void deletePoint()
   {
      if (oPath.length == 1)
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
         c.setSourceRgba(1,1,1,editOpacity);
         c.paint();
         c.setOperator(CairoOperator.XOR);
         c.setLineWidth(3);
         c.setSourceRgb(1,1,1);
         for (size_t i = 0; i < oPath.length; i++)
         {
            c.arc(oPath[i].x, oPath[i].y, lineWidth/2, 0, PI*2);
            c.strokePreserve();
            c.fill();
         }
         return;
      }

      c.translate(hOff+center.x, vOff+center.y);
      if (compoundTransform())
         c.transform(tm);
      c.translate(-center.x, -center.y);

      c.setLineWidth(0);
      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);
      for (size_t i = 0; i < oPath.length; i++)
      {
         c.arc(oPath[i].x, oPath[i].y, lineWidth, 0, PI*2);
         c.strokePreserve();
         c.fill();
      }
      if (!isMoved) cSet.setDisplay(0, reportPosition());
   }

   void adjustPI(double dx, double dy)
   {
      if (current != lastCurrent)
      {
         editStack ~= oPath.dup;
         currentStack ~= current;
         lastCurrent = current;
      }
      oPath[current].x += dx;
      oPath[current].y += dy;
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

   void renderForEdit(Context c)
   {
      doZoom(c);
      c.setSourceRgba(1,1,1,editOpacity);
      c.paint();
      c.setSourceRgb(0,0,0);
      c.setLineWidth(3);
      for (size_t i = 0; i < oPath.length; i++)
      {
         c.arc(center.x+oPath[i].x, center.y+oPath[i].y, lineWidth/2, 0, PI*2);
         c.strokePreserve();
         c.fill();
      }
      c.setSourceRgb(1,0,0);
      c.arc(center.x+oPath[current].x, center.y+oPath[current].y, lineWidth/2, 0, PI*2);
      c.strokePreserve();
      c.fill();
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


