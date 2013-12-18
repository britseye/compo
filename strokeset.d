
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module strokeset;

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
import gtk.SpinButton;
import gtk.CheckButton;
import gtk.Label;
import gtk.Dialog;
import gtk.VBox;
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

class StrokesDlg: Dialog, CSTarget
{
   StrokeSet po;
   ControlSet cs;
   Layout layout;
   Button lcb;
   int sides;

   this(string title, StrokeSet o)
   {
      GtkResponseType rta[1] = [ ResponseType.OK ];
      string[1] sa;
      super(title, o.aw, DialogFlags.DESTROY_WITH_PARENT, sa, rta);
      this.addOnDelete(&catchClose);
      po = o;
      sides = po.pcPath.length;
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
      Button b = new Button("Add a Stroke");
      cs.add(b, ICoord(120, vp), Purpose.ADDSTROKE);

      vp += vi;
      b = new Button("Delete Dtroke");
      cs.add(b, ICoord(120, vp), Purpose.DELEDGE);

      vp += vi;
      lcb = new Button("To Line");
      lcb.setTooltipText("Switch the stroke between line and curve");
      cs.add(lcb, ICoord(120, vp), Purpose.LINE2CURVE);

      vp += vi;
      b = new Button("Recenter");
      cs.add(b, ICoord(120, vp), Purpose.RECENTER);

      vp += vi;
      b = new Button("Do");
      b.setTooltipText("Remember this state");
      cs.add(b, ICoord(120, vp), Purpose.REMEMBER);
      b = new Button("Undo");
      cs.add(b, ICoord(150, vp), Purpose.UNDO);

      vp += vi;
      l = new Label("Opacity");
      cs.add(l, ICoord(120, vp), Purpose.LABEL);
      new MoreLess(cs, 1, ICoord(200, vp), true);

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
         sides = po.pcPath.length;
         po.lastCurrent = po.current;
         if (more)
         {
            if (po.current < sides-1)
               po.current++;
            else
               po.current = 0;
         }
         else
         {
            if (po.current == 0)
               po.current = sides-1;
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
      if (p == Purpose.ADDSTROKE)
      {
         po.editStack ~= po.pcPath.dup;
         po.currentStack ~= po.current;
         po.addStroke();
         sides++;
         po.reDraw();
         return;
      }
      if (p == Purpose.DELEDGE)
      {
         po.editStack ~= po.pcPath.dup;
         po.currentStack ~= po.current;
         po.deleteStroke();
         sides--;
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
         po.reDraw();
         return;
      }
      if (p == Purpose.RECENTER)
      {
         po.editStack ~= po.pcPath.dup;
         po.currentStack ~= po.current;
         po.centerPath();
         po.reDraw();
         return;
      }
      if (p == Purpose.REMEMBER)
      {
         po.editStack ~= po.pcPath.dup;
         po.currentStack ~= po.current;
         return;
      }
      if (p == Purpose.UNDO)
      {
         int l= po.editStack.length;
         if (l)
         {
            po.pcPath = po.editStack[l-1];
            po.current = po.currentStack[l-1];
            po.editStack.length = l-1;
            po.currentStack.length = l-1;
            po.reDraw();
         }
         return;
      }
   }
}

class StrokeSet : LineSet
{
   static int nextOid = 0;
   PathItem[] pcPath, pcRPath;
   PathItem[][] editStack;
   double editOpacity;
   int[] currentStack;
   bool constructing, editing;
   int current, prev, next, lastCurrent, lastActive;
   StrokesDlg md;
   int activeCoords;

   void syncControls()
   {
      cSet.setLineParams(lineWidth);
      cSet.toggling(false);
      if (les)
         cSet.setToggle(Purpose.LESSHARP, true);
      else
         cSet.setToggle(Purpose.LESROUND, true);
      cSet.setComboIndex(Purpose.XFORMCB, xform);
      cSet.setLabel(Purpose.LINEWIDTH, formatLT(lineWidth));
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(StrokeSet other)
   {
      this(other.aw, other.parent);
      constructing = false;
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      lineWidth = other.lineWidth;
      les = other.les;
      center = other.center;
      activeCoords = other.activeCoords;
      pcPath = other.pcPath.dup;
      current = other.current;
      xform = other.xform;
      tf = other.tf;
      editStack ~= pcPath.dup;
      currentStack ~= current;
      dirty = true;
      syncControls();
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "StrokeSet "~to!string(++nextOid);
      super(w, parent, s, AC_STROKESET);
      center.x = width/2;
      center.y = height/2;
      constructing = true;
      les = true;
      md = new StrokesDlg("Edit "~s, this);
      md.setSizeRequest(240, 200);
      md.setPosition(GtkWindowPosition.POS_NONE);
      editOpacity = 0.5;
      int px, py;
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
      cSet.add(b, ICoord(203, vp+2), Purpose.REDRAW, false);

      cSet.cy = vp+30;
   }

   void hideDialogs()
   {
      if (editing)
      {
         editing = false;
         md.hide();
         switchMode();
      }
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
      case Purpose.REDRAW:
         lastOp = push!(PathItem[])(this, pcPath, OP_REDRAW);
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
         pcPath = cp.pcPath.dup;
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
      for (int i = 0; i < pcPath.length; i++)
      {
         tm.transformPoint(pcPath[i].end.x, pcPath[i].end.y);
         tm.transformPoint(pcPath[i].cp1.x, pcPath[i].cp1.y);
         tm.transformPoint(pcPath[i].cp2.x, pcPath[i].cp2.y);
      }
      hOff *= hr;
      vOff *= vr;
   }

   static PathItem makePathItem(Coord tc, double x, double y)
   {
      PathItem pi;
      pi.type = 1;
      pi.start = tc;
      pi.end = Coord(x, y);
      pi.cp1 = Coord(tc.x+(x-tc.x)/3, tc.y+(y-tc.y)/3);
      pi.cp2 = Coord(tc.x+2*(x-tc.x)/3, tc.y+2*(y-tc.y)/3);
      pi.cog = Coord(tc.x+(x-tc.x)/2, tc.y+(y-tc.y)/2);
      return pi;
   }

   static double distance(Coord a, Coord b)
   {
      double dx = a.x-b.x, dy = a.y-b.y;
      return sqrt(dx*dx+dy*dy);
   }

   static movePoint(ref Coord c, double dx, double dy, double factor = 1)
   {
      c.x += dx*factor;
      c.y += dy*factor;
   }

   bool buttonPress(Event e, Widget w)
   {
      static bool gotFirst;
      static Coord tc;
      GdkModifierType state;
      e.getState(state);
      if (constructing)
      {
         dummy.grabFocus();
         if (e.button.button == 1)
         {
            if (!gotFirst)
            {
               tc.x = e.motion.x;
               tc.y =  e.motion.y;
               gotFirst= true;
               return true;
            }
            if (state & GdkModifierType.CONTROL_MASK)
               pcPath ~= makePathItem(tc, tc.x, e.motion.y);
            else if (state & GdkModifierType.SHIFT_MASK)
               pcPath ~= makePathItem(tc, e.motion.x, tc.y);
            else
               pcPath ~= makePathItem(tc, e.motion.x, e.motion.y);
            gotFirst = false;
            reDraw();
            return true;
         }
         else if (e.button.button == 3)
         {
            constructing = false;
            centerPath(true);
            editStack ~= pcPath.dup;
            cSet.enable(Purpose.REDRAW);
            currentStack ~= 0;
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
            Coord m = Coord(e.button.x-center.x, e.button.y-center.y);
            double minsep = 100000;
            int best = 0;
            foreach (int i, PathItem pi; pcPath)
            {
               double d = distance(pi.cog, m);
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

   void resetCog()
   {
      PathItem* p = &pcPath[current];
      double tx = p.start.x+p.cp1.x+p.cp2.x+p.end.x;
      double ty = p.start.y+p.cp1.y+p.cp2.y+p.end.y;
      pcPath[current].cog = Coord(tx/4, ty/4);
   }

   void centerPath(bool firstTime = false)
   {
      double cx = 0, cy = 0;
      foreach (PathItem pi; pcPath)
      {
         cx += pi.start.x+pi.cp1.x+pi.cp2.x+pi.end.x;
         cy += pi.start.y+pi.cp1.y+pi.cp2.y+pi.end.y;
      }
      cx /= pcPath.length*4;
      cy /= pcPath.length*4;

      foreach (ref PathItem pi; pcPath)
      {
         pi.start.x -= cx;
         pi.cp1.x -= cx;
         pi.cp2.x -= cx;
         pi.end.x -= cx;
         pi.start.y -= cy;
         pi.cp1.y -= cy;
         pi.cp2.y -= cy;
         pi.end.y -= cy;

         pi.cog.x -= cx;
         pi.cog.y -= cy;
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

   void addStroke()
   {
      bool last = (current == pcPath.length-1);
      PathItem x = pcPath[current];
      double dx = 4; double dy = 4;
      movePoint(x.start, dx, dy);
      movePoint(x.end, dx, dy);
      movePoint(x.cp1, dx, dy);
      movePoint(x.cp2, dx, dy);
      movePoint(x.cog, dx, dy);

      pcPath.length = pcPath.length+1;
      if (last)
      {
         pcPath[$-1] = x;
      }
      else
      {
         PathItem[] t;
         t.length = pcPath.length;
         t[] = pcPath[];
         t[current+2..$] = pcPath[current+1.. $-1];
         t[current+1] = x;
         pcPath = t;
      }
      current++;
      dirty = true;
   }


   void deleteStroke()
   {
      if (pcPath.length == 1)
         return;
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

   void transformPath(bool mValid)
   {
      pcRPath = pcPath.dup;

      for (int i = 0; i < pcRPath.length; i++)
      {
         if (mValid)
         {
            tm.transformPoint(pcRPath[i].start.x, pcRPath[i].start.y);
            tm.transformPoint(pcRPath[i].cp1.x, pcRPath[i].cp1.y);
            tm.transformPoint(pcRPath[i].cp2.x, pcRPath[i].cp2.y);
            tm.transformPoint(pcRPath[i].end.x, pcRPath[i].end.y);
         }
         pcRPath[i].start.x += center.x;
         pcRPath[i].start.y += center.y;
         pcRPath[i].cp1.x += center.x;
         pcRPath[i].cp1.y += center.y;
         pcRPath[i].cp2.x += center.x;
         pcRPath[i].cp2.y += center.y;
         pcRPath[i].end.x += center.x;
         pcRPath[i].end.y += center.y;
      }
   }

   void rSegTo(Context c, PathItem pi)
   {
      if (pi.type == 1)
         c.curveTo(hOff+pi.cp1.x, vOff+pi.cp1.y, hOff+pi.cp2.x, vOff+pi.cp2.y, hOff+pi.end.x, vOff+pi.end.y);
      else
         c.lineTo(hOff+pi.end.x, vOff+pi.end.y);
   }

   void eSegTo(Context c, PathItem pi)
   {
      if (pi.type == 1)
         c.curveTo(center.x+pi.cp1.x, center.y+pi.cp1.y, center.x+pi.cp2.x, center.y+pi.cp2.y, center.x+pi.end.x, center.y+pi.end.y);
      else
         c.lineTo(center.x+pi.end.x, center.y+pi.end.y);
   }

   void colorEdge(Context c, double r, double g, double b, PathItem pi)
   {
      c.setSourceRgb(r,g,b);
      c.setLineWidth(1);
      c.moveTo(center.x+pi.start.x, center.y+pi.start.y);
      if (pi.type == 1)
         c.curveTo(center.x+pi.cp1.x, center.y+pi.cp1.y, center.x+pi.cp2.x,
                   center.y+pi.cp2.y, center.x+pi.end.x, center.y+pi.end.y);
      else
         c.lineTo(center.x+pi.end.x, center.y+pi.end.y);
      c.stroke();
   }

   void renderActual(Context c)
   {
      if (constructing)
      {
         if (pcPath.length < 1)
            return;
         c.setSourceRgb(0.8, 0.8, 0.8);
         for (int i = 0; i < pcPath.length; i++)
         {
            c.moveTo(pcPath[i].start.x, pcPath[i].start.y);
            c.curveTo(pcPath[i].cp1.x, pcPath[i].cp1.y, pcPath[i].cp2.x, pcPath[i].cp2.y, pcPath[i].end.x, pcPath[i].end.y);
         }
         c.setLineWidth(1.0);
         c.stroke();
         return;
      }
      if (pcPath.length < 2)
         return;
      if (dirty)
      {
         transformPath(compoundTransform());
         dirty = false;
      }
      c.setLineWidth(lineWidth);
      c.setLineJoin(les? CairoLineJoin.MITER: CairoLineJoin.ROUND);
      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);

      for (int i = 0; i < pcRPath.length; i++)
      {
         c.moveTo(hOff+pcRPath[i].start.x, vOff+pcRPath[i].start.y);
         rSegTo(c, pcRPath[i]);
         c.stroke();
      }
      if (!isMoved) cSet.setDisplay(0, reportPosition());
   }

   void adjustPI(double dx, double dy)
   {
      if (current != lastCurrent || activeCoords != lastActive )
      {
         editStack ~= pcPath.dup;
         currentStack ~= current;
         lastCurrent = current;
         lastActive = activeCoords;
      }
      switch (activeCoords)
      {
         case 0:  // SP
            movePoint(pcPath[current].start, dx, dy);
            break;
         case 1:  // EP
            movePoint(pcPath[current].end, dx, dy);
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
            movePoint(pcPath[current].start, dx, dy);
            movePoint(pcPath[current].end, dx, dy);
            break;
         case 6: // All
            movePoint(pcPath[current].start, dx, dy);
            movePoint(pcPath[current].end, dx, dy);
            movePoint(pcPath[current].cp1, dx, dy);
            movePoint(pcPath[current].cp2, dx, dy);
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
      figureNextPrev();
      adjustPI(dx, dy);
      resetCog();
      dirty = true;
   }

   void figureNextPrev()
   {
      int l = pcPath.length;
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
      c.setSourceRgba(1,1,1, editOpacity);
      c.paint();
      c.setSourceRgb(0,0,0);
      c.setLineWidth(0.5);
      for (int i = 0; i < pcPath.length; i++)
      {
         c.moveTo(center.x+pcPath[i].start.x, center.y+pcPath[i].start.y);
         eSegTo(c, pcPath[i]);
         c.stroke();
      }

      figureNextPrev();
      c.setLineWidth(1);
      colorEdge(c, 1, 0, 0, pcPath[current]);
      if (pcPath[current].type == 1)
      {
         // Render the current control points
         c.setSourceRgb(0,0,0);
         c.moveTo(center.x+pcPath[current].cp1.x, center.y+pcPath[current].cp1.y-3);
         c.lineTo(center.x+pcPath[current].cp1.x+3, center.y+pcPath[current].cp1.y+3);
         c.lineTo(center.x+pcPath[current].cp1.x-3, center.y+pcPath[current].cp1.y+3);
         c.closePath();
         c.fill();
         c.setSourceRgb(0,0,1);
         c.moveTo(center.x+pcPath[current].cp2.x, center.y+pcPath[current].cp2.y+3);
         c.lineTo(center.x+pcPath[current].cp2.x+3, center.y+pcPath[current].cp2.y-3);
         c.lineTo(center.x+pcPath[current].cp2.x-3, center.y+pcPath[current].cp2.y-3);
         c.closePath();
         c.fill();
      }
   }

   void render(Context c)
   {
      if (editing)
         renderForEdit(c);
      else
         renderActual(c);
   }
}


