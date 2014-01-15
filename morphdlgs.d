
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module morphdlgs;

import main;
import interfaces;
import constants;
import common;
import morphtext;
import morphs;
import controlset;
import types;

import std.stdio;
import std.math;
import std.conv;

import gtk.Widget;
import gtk.Label;
import gtk.Layout;
import gtk.Button;
import gtk.SpinButton;
import gtk.ToggleButton;
import gtk.RadioButton;
import gtk.CheckButton;
import gtk.Dialog;
import gtk.VBox;
import gtk.Entry;
import gdk.Event;

class MorphDlg: Dialog, CSTarget
{
   MorphText po;
   Morpher morph;
   ControlSet cs;
   Layout layout;
   ParamBlock* ppb;

   this(string title, MorphText o, Morpher m)
   {
      GtkResponseType rta[1] = [ ResponseType.OK ];
      string[1] sa = [ "Close" ];
      super(title, o.aw, DialogFlags.DESTROY_WITH_PARENT, sa, rta);
      this.addOnDelete(&catchClose);
      po = o;
      morph = m;
      ppb = &o.mp;
      layout = new Layout(null, null);
      cs=new ControlSet(this);
      VBox vb = getContentArea();
      vb.packStart(layout, 1, 1, 0);
      layout.show();
      addGadgets();
   }

   void onCSNotify(Widget w, Purpose p) {}
   string onCSInch(int instance, int direction, bool coarse) { return ""; }
   void onCSMoreLess(int instance, bool more, bool coarse) {}
   void onCSCompass(int instance, double angle, bool coarse) {}
   void onCSLineWidth(double lw) {}
   void onCSSaveSelection() {}
   void onCSTextParam(Purpose p, string sval, int ival) {}
   void onCSNameChange(string s) {}
   void setNameEntry(Entry e) {}

   bool catchClose(Event e, Widget w)
   {
      hide();
      return true;
   }

   void addGadgets()
   {
      Label l = new Label("No additional operations are available\nfor this morph type");
      layout.put(l, 10, 10);
      l.show();
   }
}

class FitAreaDlg: MorphDlg
{
   FitBox fb;
   int linPc;

   this(MorphText o, Morpher m)
   {
      super("Fit the Area", o, m);
      fb = cast(FitBox) morph;
      linPc = to!int(fb.nl*100);
   }

   void addGadgets()
   {
      int vp = 20;
      Label l = new Label("Adjust Linearity");
      cs.add(l, ICoord(5,vp), Purpose.LABEL);
      new MoreLess(cs, 0, ICoord(150, vp));
      cs.realize(layout);
   }

   void onCSMoreLess(int instance, bool more, bool coarse)
   {
      more = !more;  // Looks more intuitive that way
      int delta = coarse? 5: 2;
      if (more)
      {
         if (linPc+delta > 200)
            linPc = 200;
         else
            linPc += delta;
      }
      else
      {
         if (linPc-delta < 30)
            linPc = 30;
         else
            linPc -= delta;
      }
      fb.nl = linPc*0.01;
      po.refreshMorph();
   }
}

class TaperDlg: MorphDlg
{
   Taper t;
   double h;

   this(MorphText o, Morpher m)
   {
      super("Taper Morph", o, m);
      t = cast(Taper) morph;
      h = po.height;
   }
   void addGadgets()
   {
      int vp = 20;
      Label l = new Label("Adjust the taper");
      cs.add(l, ICoord(5,vp), Purpose.LABEL);
      new MoreLess(cs, 0, ICoord(150, vp));
      cs.realize(layout);
   }

   void onCSMoreLess(int instance, bool more, bool coarse)
   {
      more = !more;  // Looks more intuitive that way
      int delta = coarse? 5: 2;
      double ty = t.tge.y;
      double by = t.bge.y;
      if (more)
      {
         ty -= 0.02*h;
         if (ty <= 0.0)
            return;
         by += 0.02*h;
      }
      else
      {
         ty += 0.02*h;
         if (ty >= h/2)
            return;
         by -= 0.02*h;
      }
      t.tge.y = ty;
      t.bge.y = by;
      po.refreshMorph();
   }
}

class ArchUpDlg: MorphDlg
{
   ArchUp a;

   this(MorphText o, Morpher m)
   {
      super("Arch Up", o, m);
      a = cast(ArchUp) m;
      addGadgets();
   }

   void addGadgets()
   {
      int vp = 20;
      Label l = new Label("Start Angle");
      cs.add(l, ICoord(5,vp), Purpose.LABEL);
      new MoreLess(cs, 0, ICoord(150, vp));

      vp += 20;
      l = new Label("End angle");
      cs.add(l, ICoord(5,vp), Purpose.LABEL);
      new MoreLess(cs, 1, ICoord(150, vp));

      vp += 20;
      l = new Label("Text Height");
      cs.add(l, ICoord(5,vp), Purpose.LABEL);
      new MoreLess(cs, 2, ICoord(150, vp));

      cs.realize(layout);
   }

   void onCSMoreLess(int instance, bool more, bool coarse)
   {
      double factor = more? 1.05: 0.95;
      if (instance == 2)
      {
         a.depth = a.depth*factor;
         a.radiusb = a.radiust-a.depth;
         po.refreshMorph();
         return;
      }

      double delta = 2*PI/180;  // 2 degrees?
      if (instance == 1)
      {
         if (more)
         {
            if (a.aend < 2*PI)
               a.aend += delta;
         }
         else
         {
            if (a.aend > 0.8*2*PI)
               a.aend -= delta;
         }
      }
      else
      {
         if (more)
         {
            if (a.astart < 0.7*2*PI)
               a.astart += delta;
         }
         else
         {
            if (a.astart > PI)
               a.astart -= delta;
         }
      }
      a.tot = a.aend-a.astart;
      po.refreshMorph();
   }
}

class CircularDlg: MorphDlg
{
   Circular c;

   this(MorphText o, Morpher m)
   {
      super("Circular", o, m);
      c = cast(Circular) m;
      addGadgets();
   }

   void addGadgets()
   {
      int vp = 20;
      Label l = new Label("Start Angle");
      cs.add(l, ICoord(5,vp), Purpose.LABEL);
      new MoreLess(cs, 0, ICoord(150, vp));

      vp += 20;
      l = new Label("End angle");
      cs.add(l, ICoord(5,vp), Purpose.LABEL);
      new MoreLess(cs, 1, ICoord(150, vp));

      vp += 20;
      l = new Label("Text Height");
      cs.add(l, ICoord(5,vp), Purpose.LABEL);
      new MoreLess(cs, 2, ICoord(150, vp));

      vp += 20;
      CheckButton cb = new CheckButton("Anti-clockwise");
      cs.add(cb, ICoord(5,vp), Purpose.ANTI);

      cs.realize(layout);
   }

   void onCSNotify(Widget w, Purpose p)
   {
      if (p == Purpose.ANTI)
      {
         c.anti = !c.anti;
         po.refreshMorph();
      }
   }

   void onCSMoreLess(int instance, bool more, bool coarse)
   {
      double factor = more? 1.05: 0.95;
      if (instance == 2)
      {
         c.depth = c.depth*factor;
         c.radiusi = c.radiuso-c.depth;
         po.refreshMorph();
         return;
      }

      double delta = 2*PI/180;  // 2 degrees?
      if (instance == 1)
      {
         if (more)
         {
            if (c.aend < 2*PI)
               c.aend += delta;
         }
         else
         {
            if (c.aend > c.astart)
               c.aend -= delta;
         }
      }
      else
      {
         if (more)
         {
            if (c.astart < c.aend)
               c.astart += delta;
         }
         else
         {
            if (c.astart > 0)
               c.astart -= delta;
         }
      }
      c.tot = c.aend-c.astart;
      po.refreshMorph();
   }
}

class SineWaveDlg: MorphDlg
{
   SineWave sw;

   this(MorphText o, Morpher m)
   {
      super("Sine Wave", o, m);
      sw = cast(SineWave) m;
   }

   void addGadgets()
   {
      int vp = 20;
      Label l = new Label("Starting point");
      cs.add(l, ICoord(5,vp), Purpose.LABEL);
      new MoreLess(cs, 0, ICoord(150, vp));

      vp += 20;
      l = new Label("Cycles");
      cs.add(l, ICoord(5,vp), Purpose.LABEL);
      new MoreLess(cs, 1, ICoord(150, vp));

      vp += 20;
      l = new Label("Text Height");
      cs.add(l, ICoord(5,vp), Purpose.LABEL);
      new MoreLess(cs, 2, ICoord(150, vp));

      cs.realize(layout);
   }

   void onCSMoreLess(int instance, bool more, bool coarse)
   {
      double factor = more? 1.05: 0.95;
      if (instance == 2)
      {
         sw.depth = sw.depth*factor;
      }
      else if (instance == 1)
      {
         if (more)
            sw.halfCycles++;
         else
         {
            if (sw.halfCycles > 1)
               sw.halfCycles--;
         }
      }
      else
      {
         double delta = 2*PI/180;  // 2 degrees?
         if (more)
            sw.sp += delta;
         else
            sw.sp -= delta;
      }
      po.refreshMorph();
   }
}

class FlareDlg: MorphDlg
{
   Flare f;

   this(MorphText o, Morpher m)
   {
      super("Flare", o, m);
      f = cast(Flare) m;
   }

   void addGadgets()
   {
      int vp = 20;
      Label l = new Label("Top Flare Width");
      cs.add(l, ICoord(5,vp), Purpose.LABEL);
      new MoreLess(cs, 0, ICoord(150, vp));

      vp += 20;
      l = new Label("Bottom Flare Width");
      cs.add(l, ICoord(5,vp), Purpose.LABEL);
      new MoreLess(cs, 1, ICoord(150, vp));

      vp += 20;
      l = new Label("Flare Rate");
      cs.add(l, ICoord(5,vp), Purpose.LABEL);
      new MoreLess(cs, 2, ICoord(150, vp));

      vp += 20;
      l = new Label("Limit Height");
      cs.add(l, ICoord(5,vp), Purpose.LABEL);
      new MoreLess(cs, 3, ICoord(150, vp));

      cs.realize(layout);
   }

   void onCSMoreLess(int instance, bool more, bool coarse)
   {
      double delta = more? -0.05: 0.05;
      if (instance == 0)
      {
         f.tsp += delta;
      }
      else if (instance == 1)
      {
         f.bsp += delta;
      }
      else if (instance == 2)
      {
         double factor = more? 1.05: 0.95;
         f.xfact *= factor;
      }
      else
      {
         f.depth += more? 5: -5;
      }
      po.refreshMorph();
   }
}

class RFlareDlg: MorphDlg
{
   RFlare f;

   this(MorphText o, Morpher m)
   {
      super("Reverse Flare", o, m);
      f = cast(RFlare) m;
   }

   void addGadgets()
   {
      int vp = 20;
      Label l = new Label("Top Flare Width");
      cs.add(l, ICoord(5,vp), Purpose.LABEL);
      new MoreLess(cs, 0, ICoord(150, vp));

      vp += 20;
      l = new Label("Bottom Flare Width");
      cs.add(l, ICoord(5,vp), Purpose.LABEL);
      new MoreLess(cs, 1, ICoord(150, vp));

      vp += 20;
      l = new Label("Flare Rate");
      cs.add(l, ICoord(5,vp), Purpose.LABEL);
      new MoreLess(cs, 2, ICoord(150, vp));

      vp += 20;
      l = new Label("Limit Height");
      cs.add(l, ICoord(5,vp), Purpose.LABEL);
      new MoreLess(cs, 3, ICoord(150, vp));

      cs.realize(layout);
   }

   void onCSMoreLess(int instance, bool more, bool coarse)
   {
      double delta = more? 0.05: -0.05;
      if (instance == 0)
      {
         f.tsp += delta;
      }
      else if (instance == 1)
      {
         f.bsp += delta;
      }
      else if (instance == 2)
      {
         double factor = more? 1.05: 0.95;
         f.xfact *= factor;
      }
      else
      {
         f.depth += more? 5: -5;
      }
      po.refreshMorph();
   }
}

class CatenaryDlg: MorphDlg
{
   Catenary cat;

   this(MorphText o, Morpher m)
   {
      super("Catenary", o, m);
      cat = cast(Catenary) m;
   }

   void addGadgets()
   {
      int vp = 20;
      CheckButton cb = new CheckButton("Inverted");
      cs.add(cb, ICoord(5,vp), Purpose.SOLID);

      vp += 25;
      Label l = new Label("Droop Factor");
      cs.add(l, ICoord(5,vp), Purpose.LABEL);
      new MoreLess(cs, 0, ICoord(150, vp));

      vp += 20;
      l = new Label("Text Height");
      cs.add(l, ICoord(5,vp), Purpose.LABEL);
      new MoreLess(cs, 1, ICoord(150, vp));

      cs.realize(layout);
   }

   void onCSNotify(Widget w, Purpose p)
   {
      cat.invert();
      po.refreshMorph();
   }

   void onCSMoreLess(int instance, bool more, bool coarse)
   {
      if (instance == 1)
      {
         double factor = more? 1.05: 0.95;
         cat.depth *= factor;
      }
      else
      {
         double delta = more? 0.05: -0.05;
         cat.b += delta;
      }
      po.refreshMorph();
   }
}

class ConvexDlg: MorphDlg
{
   Convex cv;
   SpinButton ec;

   this(MorphText o, Morpher m)
   {
      super("Convex", o, m);
      cv = cast(Convex) m;
   }

   void addGadgets()
   {
      int vp = 20;
      Label l = new Label("Curvature");
      cs.add(l, ICoord(5,vp), Purpose.LABEL);
      new MoreLess(cs, 0, ICoord(150, vp));

      cs.realize(layout);
   }

   void onCSMoreLess(int instance, bool more, bool coarse)
   {
      double delta = cv.height*0.05;
      if (!more)
         delta= -delta;
      cv.b += delta;
      po.refreshMorph();
   }
}

class ConcaveDlg: MorphDlg
{
   Concave cc;
   SpinButton ec;

   this(MorphText o, Morpher m)
   {
      super("Concave", o, m);
      cc = cast(Concave) m;
   }

   void addGadgets()
   {
      int vp = 20;
      Label l = new Label("Curvature");
      cs.add(l, ICoord(5,vp), Purpose.LABEL);
      new MoreLess(cs, 0, ICoord(150, vp));

      cs.realize(layout);
   }

   void onCSMoreLess(int instance, bool more, bool coarse)
   {
      double delta = cc.height*0.05;
      if (!more)
         delta= -delta;
      cc.b += delta;
      po.refreshMorph();
   }
}

class BezierDlg: MorphDlg
{
   BezierMorph bm;
   int active;
   bool paired, anti;

   enum
   {
      TSP = Purpose.R_CHECKBUTTONS-100,
      TCP1,
      TCP2,
      TEP,
      BSP,
      BCP1,
      BCP2,
      BEP,
      BOTHSP,
      BOTHCP1,
      BOTHCP2,
      BOTHEP,
      ALLCP
   }

   this(MorphText o, Morpher m)
   {
      bm = cast(BezierMorph) m;
      super("BezierMorph", o, m);
      active = BOTHSP;
   }

   static void moveCoord(ref Coord p, double distance, double angle)
   {
      p.x += cos(angle)*distance;
      p.y -= sin(angle)*distance;
   }

   override void onCSCompass(int instance, double angle, bool coarse)
   {
      double d = coarse? 10.0: 2;
      switch (active)
      {
         case BOTHSP:
            moveCoord(bm.sp1, d, angle);
            moveCoord(bm.sp2, d, angle);
            break;
         case BOTHEP:
            moveCoord(bm.ep1, d, angle);
            moveCoord(bm.ep2, d, angle);
            break;
         case BOTHCP1:
            moveCoord(bm.c11, d, angle);
            moveCoord(bm.c21, d, angle);
            break;
         case BOTHCP2:
            moveCoord(bm.c12, d, angle);
            moveCoord(bm.c22, d, angle);
            break;
         case ALLCP:
            moveCoord(bm.c11, d, angle);
            moveCoord(bm.c12, d, angle);
            moveCoord(bm.c21, d, angle);
            moveCoord(bm.c22, d, angle);
            break;
         case TSP:
            moveCoord(bm.sp1, d, angle);
            break;
         case BSP:
            moveCoord(bm.sp2, d, angle);
            break;
         case TEP:
            moveCoord(bm.ep1, d, angle);
            break;
         case BEP:
            moveCoord(bm.ep2, d, angle);
            break;
         case TCP1:
            moveCoord(bm.c11, d, angle);
            break;
         case BCP1:
            moveCoord(bm.c21, d, angle);
            break;
         case TCP2:
            moveCoord(bm.c12, d, angle);
            break;
         case BCP2:
            moveCoord(bm.c22, d, angle);
            break;

         default:
            return;
      }
      po.refreshMorph();
   }

   void onCSNotify(Widget w, Purpose p)
   {
      if (p == Purpose.REVERT)
      {
         // If the user has made something she likes, but wants to experiment further
         // save it for an undo
         po.pushParams();
         return;
      }
      if ((cast(ToggleButton) w).getActive())
         active = p;
   }

   void addGadgets()
   {
      int vi = 18;
      int vp = 5;
      new Compass(cs, 0, ICoord(20, vp));

      vp+= 60;
      RadioButton rb1 = new RadioButton("Both SP");
      cs.add(rb1, ICoord(5, vp), cast(Purpose) BOTHSP);

      vp += vi;
      RadioButton rb = new RadioButton(rb1, "Both EP");
      cs.add(rb, ICoord(5, vp), cast(Purpose) BOTHEP);

      vp += vi;
      rb = new RadioButton(rb1, "Both CP1");
      cs.add(rb, ICoord(5, vp), cast(Purpose) BOTHCP1);

      vp += vi;
      rb = new RadioButton(rb1, "Both CP2");
      cs.add(rb, ICoord(5, vp), cast(Purpose) BOTHCP2);

      vp += vi;
      rb = new RadioButton(rb1, "All CP");
      cs.add(rb, ICoord(5, vp), cast(Purpose) ALLCP);

      vp = 11;
      int hp = 130;
      rb = new RadioButton(rb1, "TSP");
      cs.add(rb, ICoord(hp, vp), cast(Purpose) TSP);

      vp += vi;
      rb = new RadioButton(rb1, "BSP");
      cs.add(rb, ICoord(hp, vp), cast(Purpose) BSP);

      vp += vi;
      rb = new RadioButton(rb1, "TEP");
      cs.add(rb, ICoord(hp, vp), cast(Purpose) TEP);

      vp += vi;
      rb = new RadioButton(rb1, "BEP");
      cs.add(rb, ICoord(hp, vp), cast(Purpose) BEP);

      vp += vi;
      rb = new RadioButton(rb1, "TCP1");
      cs.add(rb, ICoord(hp, vp), cast(Purpose) TCP1);

      vp += vi;
      rb = new RadioButton(rb1, "BCP1");
      cs.add(rb, ICoord(hp, vp), cast(Purpose) BCP1);

      vp += vi;
      rb = new RadioButton(rb1, "TCP2");
      cs.add(rb, ICoord(hp, vp), cast(Purpose) TCP2);

      vp += vi;
      rb = new RadioButton(rb1, "BCP2");
      cs.add(rb, ICoord(hp, vp), cast(Purpose) BCP2);

      Button b = new Button("Remember");
      cs.add(b, ICoord(205, 30), cast(Purpose) Purpose.REVERT);

      cs.realize(layout);
   }
}
