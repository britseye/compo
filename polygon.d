
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module polygon;

import main;
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

      cs.realize(layout);
   }

   static void moveCoord(ref Coord p, double distance, double angle)
   {
      p.x += cos(angle)*distance;
      p.y -= sin(angle)*distance;
   }

   void onCSMoreLess(int instance, bool more, bool coarse)
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
   }
}

class Polygon : LineSet
{
   static int nextOid = 0;
   Coord[] orig;
   Coord[][] editStack;
   int[] currentStack;
   RGBA saveAltColor;
   bool fill, solid;
   bool constructing, editing;
   int current, next, prev, lastCurrent, lastActive;
   PolyEditDlg md;
   int activeCoords;

   void syncControls()
   {
      cSet.setLineParams(lineWidth);
      cSet.toggling(false);
      if (les)
         cSet.setToggle(Purpose.LESSHARP, true);
      else
         cSet.setToggle(Purpose.LESROUND, true);
      if (solid)
      {
         cSet.setToggle(Purpose.SOLID, true);
         cSet.disable(Purpose.FILL);
         cSet.disable(Purpose.FILLCOLOR);
      }
      else if (fill)
         cSet.setToggle(Purpose.FILL, true);
      cSet.setComboIndex(Purpose.XFORMCB, xform);
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
      solid = other.solid;
      center = other.center;
      oPath = other.oPath.dup;
      xform = other.xform;
      tf = other.tf;
      dirty = true;
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Polygon "~to!string(++nextOid);
      super(w, parent, s, AC_POLYGON);
      constructing = true;
      altColor = new RGBA();
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
      positionControls(true);
   }

   void extendControls()
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

      vp += 40;

      CheckButton check = new CheckButton("Fill with color");
      cSet.add(check, ICoord(0, vp), Purpose.FILL);

      check = new CheckButton("Solid");
      cSet.add(check, ICoord(115, vp), Purpose.SOLID);

      b = new Button("Fill Color");
      cSet.add(b, ICoord(203, vp-5), Purpose.FILLCOLOR);

      cSet.cy = vp+30;
   }

   void onCSNotify(Widget w, Purpose wid)
   {
      switch (wid)
      {
      case Purpose.COLOR:
         lastOp = push!RGBA(this, baseColor, OP_COLOR);
         setColor(false);
         break;
      case Purpose.FILLCOLOR:
         lastOp = push!RGBA(this, altColor, OP_ALTCOLOR);
         setColor(true);
         break;
      case Purpose.LESROUND:
         if ((cast(RadioButton) w).getActive())
            les = false;
         break;
      case Purpose.LESSHARP:
         if ((cast(RadioButton) w).getActive())
            les = true;
         break;
      case Purpose.XFORMCB:
         xform = (cast(ComboBoxText) w).getActive();
         break;
      case Purpose.FILL:
         fill = !fill;
         break;
      case Purpose.SOLID:
         solid = !solid;
         if (solid)
         {
            cSet.disable(Purpose.FILL);
            cSet.disable(Purpose.FILLCOLOR);
         }
         else
         {
            cSet.enable(Purpose.FILL);
            cSet.enable(Purpose.FILLCOLOR);
         }
         break;
      case Purpose.REDRAW:
         lastOp = push!Path_t(this, oPath, OP_REDRAW);
         editing = !editing;
         switchMode();
         dummy.grabFocus();
         return;
      default:
         break;
      }
      aw.dirty = true;
      reDraw();
   }

   void switchMode()
   {
      if (editing)
      {
         md.showAll();
         cSet.setLabel(Purpose.REDRAW, "Design");
      }
      else
      {
         md.hide();
         cSet.setLabel(Purpose.REDRAW, "Edit");
      }
      reDraw();
   }

   bool specificUndo(CheckPoint cp)
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

   void preResize(int oldW, int oldH)
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

   bool buttonPress(Event e, Widget w)
   {
      GdkModifierType state;
      e.getState(state);
      if (constructing)
      {
         bool prev = (oPath.length > 0);
         dummy.grabFocus();
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
            constructing = false;
            setPath();
            cSet.enable(Purpose.REDRAW);
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
            double distance(Coord a, Coord b)
            {
               double dx = a.x-b.x, dy = a.y-b.y;
               return sqrt(dx*dx+dy*dy);
            }

            Coord m = Coord(e.button.x-center.x, e.button.y-center.y);
            double minsep = 100000;
            int best = 0;
            int last = oPath.length-1;
            foreach (int i, Coord c; oPath)
            {
               Coord nextv;
               if (i == last)
                  nextv=oPath[0];
               else
                  nextv = oPath[i+1];
               Coord half;
               half.x = c.x+(nextv.x-c.x)/2;
               half.y = c.y+(nextv.y-c.y)/2;

               double d = distance(half, m);
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

   bool buttonRelease(Event e, Widget w)
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

   bool mouseMove(Event e, Widget w)
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

   void setPath()
   {
      double cx = 0.0, cy = 0.0;
      foreach (Coord p; oPath)
      {
         cx += p.x;
         cy += p.y;
      }
      cx /= oPath.length;
      cy /= oPath.length;
      center.x = cx;
      center.y = cy;
      foreach (int i, ref Coord p; oPath)
      {
         p.x -= cx;
         p.y -= cy;
      }
   }

   void onCSMoreLess(int instance, bool more, bool coarse)
   {
      dummy.grabFocus();
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

   void renderActual(Context c)
   {
      if (constructing)
      {
         if (oPath.length < 2)
            return;
         c.setSourceRgb(0.8, 0.8, 0.8);
         c.moveTo(oPath[0].x, oPath[0].y);
         for (int i = 1; i < oPath.length; i++)
            c.lineTo(oPath[i].x, oPath[i].y);
         c.setLineWidth(1.0);
         c.stroke();
         return;
      }
      if (oPath.length <   2)
         return;
      if (dirty)
      {
         transformPath(compoundTransform());
         dirty = false;
      }
      c.setLineWidth(lineWidth);
      c.setLineJoin(les? CairoLineJoin.MITER: CairoLineJoin.ROUND);
      c.moveTo(hOff+rPath[0].x, vOff+rPath[0].y);
      for (int i = 1; i < rPath.length; i++)
         c.lineTo(hOff+rPath[i].x, vOff+rPath[i].y);
      c.closePath();
      if (solid)
      {
         c.setSourceRgba(baseColor.red, baseColor.green, baseColor.blue, 1.0);
         c.fill();
      }
      else if (fill)
      {
         c.setSourceRgba(altColor.red, altColor.green, altColor.blue, 1.0);
         c.fillPreserve();
      }
      if (!solid)
      {
         c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);
         c.stroke();
      }
      if (!isMoved) cSet.setDisplay(0, reportPosition());
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

   void mouseMoveOp(double dx, double dy)
   {
      if (!editing)
      {
         hOff += dx;
         vOff += dy;
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
      c.setSourceRgba(1,1,1,1);
      c.paint();
      c.setSourceRgb(0,0,0);
      c.setLineWidth(0.5);
      c.moveTo(center.x+oPath[0].x, center.y+oPath[0].y);
      for (int i = 1; i < oPath.length; i++)
         c.lineTo(center.x+oPath[i].x, center.y+oPath[i].y);
      if (oPath.length > 2)
         c.closePath();
      c.stroke();
      figureNextPrev();
      c.setSourceRgb(1,0,0);
      c.setLineWidth(1);
      c.moveTo(center.x+oPath[current].x, center.y+oPath[current].y);
      c.lineTo(center.x+oPath[next].x, center.y+oPath[next].y);
      c.stroke();
      c.setSourceRgb(0,1,0);
      c.moveTo(center.x+oPath[prev].x, center.y+oPath[prev].y);
      c.lineTo(center.x+oPath[current].x, center.y+oPath[current].y);
      c.stroke();
   }

   void render(Context c)
   {
      if (editing)
         renderForEdit(c);
      else
         renderActual(c);
   }
}


