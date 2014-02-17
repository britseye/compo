
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module regpc;

import mainwin;
import config;
import constants;
import acomp;
import common;
import types;
import controlset;
import lineset;

import std.stdio;
import std.math;
import std.conv;

import gtk.DrawingArea;
import gtk.Widget;
import gtk.Button;
import gtk.Layout;
import gtk.Frame;
import gdk.RGBA;
import gtk.ComboBoxText;
import gtk.ToggleButton;
import gtk.RadioButton;
import gtk.CheckButton;
import gtk.Label;
import cairo.Context;
import gtkc.cairotypes;
import cairo.Matrix;

enum
{
   P1 = Purpose.R_RADIOBUTTONS-100,
   P2,
   BOTH,
   AP1,
   AP2,
   ABOTH
}

enum
{
   SS,
   SA,
   DS,
   DA
}

class RegularPolycurve : LineSet
{
   static int nextOid = 0;
   PathItemR[] pcPath, parkPath;
   int sides, activeCP, symmetry;
   bool editMode;
   double target, maxTarget, joinRadius, joinAngle;
   double cp1Radius, cp1Angle, cp2Radius, cp2Angle, cp1ARadius, cp1AAngle, cp2ARadius, cp2AAngle;
   double sho, svo;
   Label numSides;
   Button vb;
   CairoFillRule cfr;

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
      if (symmetry == SS)
      {
         cSet.disable(Purpose.CP1);
         cSet.disable(Purpose.CP2);
         cSet.disable(Purpose.CPBOTH);
         cSet.disable(Purpose.ACP1);
         cSet.disable(Purpose.ACP2);
         cSet.disable(Purpose.ACPBOTH);
      }
      else if (symmetry == SA || symmetry == DS)
      {
         cSet.enable(Purpose.CP1);
         cSet.enable(Purpose.CP2);
         cSet.enable(Purpose.CPBOTH);
         cSet.disable(Purpose.ACP1);
         cSet.disable(Purpose.ACP2);
         cSet.disable(Purpose.ACPBOTH);
      }
      else
      {
         cSet.enable(Purpose.CP1);
         cSet.enable(Purpose.CP2);
         cSet.enable(Purpose.CPBOTH);
         cSet.enable(Purpose.ACP1);
         cSet.enable(Purpose.ACP2);
         cSet.enable(Purpose.ACPBOTH);
      }
      cSet.setToggle(activeCP-Purpose.CP1, true);
      cSet.setComboIndex(Purpose.XFORMCB, xform);
      cSet.setComboIndex(Purpose.PATTERN, symmetry);
      cSet.setComboIndex(Purpose.FILLOPTIONS, 0);
      cSet.setLabel(Purpose.LINEWIDTH, formatLT(lineWidth));
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(RegularPolycurve other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      altColor = other.altColor.copy();
      lineWidth = other.lineWidth;
      sides = other.sides;
      symmetry = other.symmetry;
      activeCP = other.activeCP;
      target = other.target;
      maxTarget = other.maxTarget;
      joinRadius = other.joinRadius;
      joinAngle = other.joinAngle;
      cp1Radius = other.cp1Radius;
      cp2Radius = other.cp2Radius;
      cp1Angle = other.cp1Angle;
      cp2Angle = other.cp2Angle;
      cp1ARadius = other.cp1ARadius;
      cp2ARadius = other.cp2ARadius;
      cp1AAngle = other.cp1AAngle;
      cp2AAngle = other.cp2AAngle;
      constructBase();
      les = other.les;
      fill = other.fill;
      outline = other.outline;
      center = other.center;
      pcPath = other.pcPath.dup;
      xform = other.xform;
      tf = other.tf;
      syncControls();
      dirty = true;
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Regular Polycurve "~to!string(++nextOid);
      super(w, parent, s, AC_REGPOLYCURVE);
      group = ACGroups.GEOMETRIC;
      closed = true;
      altColor = new RGBA(1,1,1,1);
      les  = true;
      fill = false;
      cfr = CairoFillRule.EVEN_ODD;
      if (width > height)
      {
         target = 0.25*height;
         maxTarget = height;
      }
      else
      {
         target = 0.25*width;
         maxTarget = width;
      }
      joinRadius = 2*target;
      joinAngle = 0;
      cp1Radius = 2*target;
      cp1ARadius = 2*target;
      cp1Angle = 0;
      cp1AAngle = 0;
      cp2Radius = 2*target;
      cp2ARadius = 2*target;
      cp2Angle = 0;
      cp2AAngle = 0;
      center.x = 0.5*width;
      center.y = 0.5*height;
      sides = w.config.polySides;
      lineWidth = 0.5;
      constructBase();
      tm = new Matrix(&tmData);

      setupControls(3);
      outline = true;
      positionControls(true);
   }

   override void extendControls()
   {
      int vp = cSet.cy;

      Label l = new Label("Lobes:");
      l.setTooltipText("Equivalent to the sides of a plain-old\npolygon.");
      cSet.add(l, ICoord(204, vp-38), Purpose.LABEL);
      new MoreLess(cSet, 0, ICoord(305, vp-38), true);
      numSides = new Label("6");
      cSet.add(numSides, ICoord(310, vp-38), Purpose.LABEL);

      l = new Label("Base Radius");
      l.setTooltipText("The 'radius' of a corresponding polygon.");
      cSet.add(l, ICoord(204, vp-18), Purpose.LABEL);
      new MoreLess(cSet, 1, ICoord(305, vp-18), true);

      ComboBoxText cbb = new ComboBoxText(false);
      cbb.setTooltipText("Select the form of the 'lobes or edges'");
      cbb.setSizeRequest(100, -1);
      cbb.appendText("Single Symmetric Curve");
      cbb.appendText("Single Asymmetric Curve");
      cbb.appendText("Two Symmetric Curves");
      cbb.appendText("Two Asymmetric Curves");
      cbb.setActive(0);
      cSet.add(cbb, ICoord(0, vp), Purpose.PATTERN);

      cbb = new ComboBoxText(false);
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
      cSet.add(cbb, ICoord(204, vp), Purpose.XFORMCB);
      new MoreLess(cSet, 2, ICoord(305, vp+5), true);

      vp += 45;
      l = new Label("Control Points");
      l.setTooltipText("These selections determine which control\npoint(s) will currently be moved by\n'Radius' and 'Angle'.");
      cSet.add(l, ICoord(0, vp), Purpose.LABEL);
      RadioButton cpg = new RadioButton("Cp1");
      cpg.setSensitive(0);
      cSet.add(cpg, ICoord(165, vp), Purpose.CP1);
      RadioButton gm = new RadioButton(cpg, "Cp2");
      gm.setSensitive(0);
      cSet.add(gm, ICoord(215, vp), Purpose.CP2);
      gm = new RadioButton(cpg, "Both");
      gm.setSensitive(0);
      cSet.add(gm, ICoord(275, vp), Purpose.CPBOTH);

      vp += 20;
      l = new Label("Alt Control Points");
      l.setTooltipText("These selections are only used where\nthe curve(s) used are asymmetric.");
      cSet.add(l, ICoord(0, vp), Purpose.LABEL);
      gm = new RadioButton(cpg, "Cp1");
      gm.setSensitive(0);
      cSet.add(gm, ICoord(165, vp), Purpose.ACP1);
      gm = new RadioButton(cpg, "Cp2");
      gm.setSensitive(0);
      cSet.add(gm, ICoord(215, vp), Purpose.ACP2);
      gm = new RadioButton(cpg, "Both");
      gm.setSensitive(0);
      cSet.add(gm, ICoord(275, vp), Purpose.ACPBOTH);

      vp += 20;
      l = new Label("Radius");
      cSet.add(l, ICoord(0, vp), Purpose.LABEL);
      l.setTooltipText("This tool determines the radial position\nof the selected control point(s).");
      new MoreLess(cSet, 3, ICoord(45, vp), true);
      l = new Label("Angle");
      l.setTooltipText("This tool determines the angular position\nof the selected control point(s).");
      cSet.add(l, ICoord(78, vp), Purpose.LABEL);
      new MoreLess(cSet, 4, ICoord(118, vp), true);
      CheckButton cb = new CheckButton("Switch Fill Rule");
      cSet.add(cb, ICoord(0, vp+20), Purpose.ANTI);

      l = new Label("Alt Angle");
      l.setTooltipText("This angle determines the end point\nof the first Bezier curve when 2 are used.");
      cSet.add(l, ICoord(165, vp), Purpose.LABEL);
      new MoreLess(cSet, 5, ICoord(275, vp), true);
      l = new Label("Alt Radius");
      l.setTooltipText("This radius determines the end point\nof the first Bezier curve when 2 are used.");
      cSet.add(l, ICoord(165, vp+20), Purpose.LABEL);
      new MoreLess(cSet, 6, ICoord(275, vp+20), true);

      vb = new Button("SS View");
      vb.setTooltipText("Click here to see a simplified view\nof the curve(s) over a the first\nlobe of a polycurve.");
      cSet.add(vb, ICoord(280, vp+40), Purpose.REDRAW);

      vp += 35;
      new InchTool(cSet, 0, ICoord(0, vp+5), true);

      cSet.cy = vp+38;
   }

   override void afterDeserialize()
   {
      constructBase();
      dirty = true;
   }

   override bool specificNotify(Widget w, Purpose p)
   {
      focusLayout();
      if (p >= Purpose.CP1 && p <= Purpose.ACPBOTH)
      {
         if ((cast(ToggleButton) w).getActive())
         {
            if (activeCP == p-Purpose.CP1)
               return true;
            lastOp = push!int(this, activeCP, OP_IV0);
            activeCP = p-Purpose.CP1;
         }
         return true;
      }
      if (p == Purpose.REDRAW)
      {
         if (editMode)
         {
            hOff = sho;
            vOff = svo;
            pcPath = parkPath;
            vb.setLabel("SS View");
         }
         else
         {
            sho = hOff;
            svo = vOff;
            parkPath = pcPath.dup;
            vb.setLabel("Actual");
         }
         editMode = !editMode;
         return true;
      }
      if (p == Purpose.PATTERN)
      {
         lastOp = push!int(this, symmetry, OP_ALIGN);
         symmetry = (cast(ComboBoxText) w).getActive();
         if (symmetry == SS)
         {
            cSet.disable(Purpose.CP1);
            cSet.disable(Purpose.CP2);
            cSet.disable(Purpose.CPBOTH);
            cSet.disable(Purpose.ACP1);
            cSet.disable(Purpose.ACP2);
            cSet.disable(Purpose.ACPBOTH);
         }
         else if (symmetry == SA || symmetry == DS)
         {
            cSet.enable(Purpose.CP1);
            cSet.enable(Purpose.CP2);
            cSet.enable(Purpose.CPBOTH);
            cSet.disable(Purpose.ACP1);
            cSet.disable(Purpose.ACP2);
            cSet.disable(Purpose.ACPBOTH);
         }
         else
         {
            cSet.enable(Purpose.CP1);
            cSet.enable(Purpose.CP2);
            cSet.enable(Purpose.CPBOTH);
            cSet.enable(Purpose.ACP1);
            cSet.enable(Purpose.ACP2);
            cSet.enable(Purpose.ACPBOTH);
         }
         constructBase();
         return true;
      }
      else if (p == Purpose.ANTI)
      {
         if (cfr == CairoFillRule.EVEN_ODD)
            cfr = CairoFillRule.WINDING;
         else
            cfr = CairoFillRule.EVEN_ODD;
         return true;
      }
      else
         return false;
   }

   override bool specificUndo(CheckPoint cp)
   {
      switch (cp.type)
      {
      case OP_IV1:
         sides = cp.iVal;
         break;
      case OP_TARGET:
         target = cp.dVal;
         break;
      case OP_LAGLEAD:
         joinAngle = cp.dVal;
         break;
      case OP_ALTRADIUS:
         joinRadius = cp.dVal;
         break;
      case OP_RPCCP:
         restoreCPState(cp.rpccp);
         break;
      case OP_ALIGN:
         symmetry = cp.iVal;
         cSet.setComboIndex(Purpose.PATTERN, symmetry);
         break;
      case OP_IV0:
         activeCP = cp.iVal;
         cSet.toggling(false);
         cSet.setToggle(Purpose.CP1+activeCP, true);
         cSet.toggling(false);
         break;
      default:
         return false;
      }
      lastOp = OP_UNDEF;
      constructBase();
      dirty = true;
      return true;
   }

   void restoreCPState(RPCCP rpccp)
   {
      if (rpccp.radial)
      {
         cp1Radius = rpccp.d1;
         cp2Radius = rpccp.d2;
         cp1ARadius = rpccp.d3;
         cp2ARadius = rpccp.d4;
      }
      else
      {
         cp1Angle = rpccp.d1;
         cp2Angle = rpccp.d2;
         cp1AAngle = rpccp.d3;
         cp2AAngle = rpccp.d4;
      }
   }

   void modifyRadius(double d)
   {
      if (symmetry == SS)
      {
         cp1Radius += d;
         cp2Radius += d;
      }
      else if (symmetry == SA)
      {
         switch (activeCP)
         {
            case 0:
               cp1Radius += d;
               break;
            case 1:
               cp2Radius += d;
               break;
            case 2:
               cp1Radius += d;
               cp2Radius += d;
               break;
            default:
               break;
         }
      }
      else if (symmetry == DS)
      {
         switch (activeCP)
         {
            case 0:
               cp1Radius += d;
               cp2ARadius += d;
               break;
            case 1:
               cp2Radius += d;
               cp1ARadius += d;
               break;
            case 2:
               cp1Radius += d;
               cp2ARadius += d;
               cp1ARadius += d;
               cp2Radius += d;
               break;
            default:
               break;
         }
      }
      else
      {
         switch (activeCP)
         {
            case 0:
               cp1Radius += d;
               break;
            case 1:
               cp2Radius += d;
               break;
            case 2:
               cp1Radius += d;
               cp2Radius += d;
               break;
            case 3:
               cp1ARadius += d;
               break;
            case 4:
               cp2ARadius += d;
               break;
            case 5:
               cp1ARadius += d;
               cp2ARadius += d;
               break;
            default:
               break;
         }
      }
   }

   void modifyAngle(double d)
   {
      if (symmetry == SS)
      {
         cp1Angle += d;
         cp2Angle -= d;
      }
      else if (symmetry == SA)
      {
         switch (activeCP)
         {
            case 0:
               cp1Angle += d;
               break;
            case 1:
               cp2Angle += d;
               break;
            case 2:
               cp1Angle += d;
               cp2Angle += d;
               break;
            case 3:
               cp1AAngle += d;
               break;
            case 4:
               cp2AAngle += d;
               break;
            case 5:
               cp1AAngle += d;
               cp2AAngle += d;
               break;
            default:
               break;
         }
      }
      else if (symmetry == DS)
      {
         switch (activeCP)
         {
            case 0:
               cp1Angle += d;
               cp2AAngle -= d;
               break;
            case 1:
               cp2Angle += d;
               cp1AAngle -= d;
               break;
            case 2:
               cp1Angle += d;
               cp2AAngle -= d;
               cp2Angle += d;
               cp1AAngle -= d;
               break;
            default:
               break;
         }
      }
      else
      {
         switch (activeCP)
         {
            case 0:
               cp1Angle += d;
               break;
            case 1:
               cp2Angle += d;
               break;
            case 2:
               cp1Angle += d;
               cp2Angle += d;
               break;
            case 3:
               cp1AAngle += d;
               break;
            case 4:
               cp2AAngle += d;
               break;
            case 5:
               cp1AAngle += d;
               cp2AAngle += d;
               break;
            default:
               break;
         }
      }
   }

   override void onCSMoreLess(int instance, bool more, bool much)
   {
      focusLayout();
      int direction = more? 1: -1;

      void doSides()
      {
         if (more)
            sides++;
         else
         {
            if (sides > 3)
               sides--;
         }
         numSides.setText(to!string(sides));
         constructBase();
      }

      void doTarget()
      {
         double delta = 1;
         if (much) delta *= 5;
         if (more)
         {
            if (target+delta > maxTarget)
               target = maxTarget;
            else
               target += delta;
         }
         else
         {
            if (target-delta < 0)
               target = 0;
            else
               target -= delta;
         }
         constructBase();
      }

      void doCpRadius()
      {
         double delta = 1;
         if (much) delta *= 5;
         if (more)
         {
            modifyRadius(delta);
         }
         else
         {
            if (target-delta < 0)
               modifyRadius(0);
            else
               modifyRadius(-delta);
         }
         constructBase();
      }

      void doCpAngle()
      {
         double delta = rads;  // One degree
         if (much) delta *= 5;
         if (more)
         {
            modifyAngle(delta);
         }
         else
         {
            modifyAngle(-delta);
         }
         constructBase();
      }

      void doJoinAngle()
      {
         double delta = rads;  // One degree
         if (much) delta *= 5;
         if (more)
            joinAngle += delta;
         else
            joinAngle -= delta;
         constructBase();
      }

      void doJoinRadius()
      {
         double delta = 1;
         if (much) delta *= 5;
         if (more)
         {
               joinRadius += delta;
         }
         else
         {
            if (joinRadius-delta < 0.1)
               joinRadius = 0.1;
            else
               joinRadius -= delta;
         }
         constructBase();
      }


      switch (instance)
      {
         case 0:
            lastOp = pushC!int(this, sides, OP_IV1);
            doSides();
            break;
         case 1:
            lastOp = pushC!double(this, target, OP_TARGET);
            doTarget();
            break;
         case 2:
            modifyTransform(xform, more, much);
            dirty = true;
            break;
         case 3:
            RPCCP rpccp = RPCCP(true, cp1Radius, cp2Radius, cp1ARadius, cp2ARadius);
            lastOp = pushC!(RPCCP)(this, rpccp, OP_RPCCP);
            doCpRadius();
            break;
         case 4:
            RPCCP rpccp = RPCCP(false, cp1Angle, cp2Angle, cp1AAngle, cp2AAngle);
            lastOp = pushC!(RPCCP)(this, rpccp, OP_RPCCP);
            doCpAngle();
            break;
         case 5:
            lastOp = pushC!double(this, joinAngle, OP_LAGLEAD);
            doJoinAngle();
            break;
         case 6:
            lastOp = pushC!double(this, joinRadius, OP_ALTRADIUS);
            doJoinRadius();
            break;
         default:
            return;
      }

      aw.dirty = true;
      reDraw();
   }

   static void moveCoord(ref Coord p, double distance, double angle)
   {
      p.x += cos(angle)*distance;
      p.y -= sin(angle)*distance;
   }

   override void preResize(int oldW, int oldH)
   {
      center.x = width/2;
      center.y = height/2;
      double hr = cast(double) width/oldW;
      double vr = cast(double) height/oldH;
      tm.initScale(hr, vr);
      hOff *= hr;
      vOff *= vr;
   }

   void constructBase()
   {
      double theta = (PI*2)/sides;
      double ha = theta/2;
      double a = 0;

      if (symmetry == SS || symmetry == SA)
      {
         pcPath.length = sides;
         for (int i = 0; i < sides; i++)
         {
            pcPath[i].start.x = target*cos(a);
            pcPath[i].start.y = target*sin(a);
            pcPath[i].cp1.x = cp1Radius*cos(a+cp1Angle);
            pcPath[i].cp1.y = cp1Radius*sin(a+cp1Angle);
            a += theta;
            pcPath[i].cp2.x = cp2Radius*cos(a+cp2Angle);
            pcPath[i].cp2.y = cp2Radius*sin(a+cp2Angle);
            pcPath[i].end.x = target*cos(a);
            pcPath[i].end.y = target*sin(a);
         }
      }
      else
      {
         pcPath.length = sides*2;
         int j = 0;
         for (int i = 0; i < sides; i++)
         {
            pcPath[j].start.x = target*cos(a);
            pcPath[j].start.y = target*sin(a);
            pcPath[j].cp1.x = cp1Radius*cos(a+cp1Angle);
            pcPath[j].cp1.y = cp1Radius*sin(a+cp1Angle);
            a += ha;
            pcPath[j].cp2.x = cp2Radius*cos(a+cp2Angle);
            pcPath[j].cp2.y = cp2Radius*sin(a+cp2Angle);
            pcPath[j].end.x = joinRadius*cos(a+joinAngle);
            pcPath[j].end.y = joinRadius*sin(a+joinAngle);
            j++;
            pcPath[j].start.x = joinRadius*cos(a+joinAngle);
            pcPath[j].start.y = joinRadius*sin(a+joinAngle);
            pcPath[j].cp1.x = cp1ARadius*cos(a+joinAngle+cp1AAngle);
            pcPath[j].cp1.y = cp1ARadius*sin(a+joinAngle+cp1AAngle);
            a += ha;
            pcPath[j].cp2.x = cp2ARadius*cos(a+cp2AAngle);
            pcPath[j].cp2.y = cp2ARadius*sin(a+cp2AAngle);
            pcPath[j].end.x = target*cos(a);
            pcPath[j].end.y = target*sin(a);
            j++;
         }
      }
      for (size_t i = 0; i < pcPath.length; i++)
      {
         pcPath[i].start.x += center.x;
         pcPath[i].start.y += center.y;
         pcPath[i].cp1.x += center.x;
         pcPath[i].cp1.y += center.y;
         pcPath[i].cp2.x += center.x;
         pcPath[i].cp2.y += center.y;
         pcPath[i].end.x += center.x;
         pcPath[i].end.y += center.y;
      }
   }

   void renderActual(Context c)
   {
      c.setAntialias(cairo_antialias_t.SUBPIXEL);
      c.setLineWidth(0);
      c.setLineJoin(les? CairoLineJoin.MITER: CairoLineJoin.ROUND);

      c.translate(hOff+center.x, vOff+center.y);
      if (compoundTransform())
         c.transform(tm);
      c.translate(-center.x, -center.y);

      c.moveTo(pcPath[0].start.x, pcPath[0].start.y);
      for (size_t i = 0; i < pcPath.length; i++)
         c.curveTo(pcPath[i].cp1.x, pcPath[i].cp1.y, pcPath[i].cp2.x, pcPath[i].cp2.y, pcPath[i].end.x, pcPath[i].end.y);
      c.closePath();
      c.setFillRule(cfr);
      strokeAndFill(c, lineWidth, outline, fill);

   }

   void renderEditS(Context c)
   {
      double u = 0.25*height;
      double w = width, h = height;
      double hw = w/2, hh = h/2;
      double a0 = 0;
      double theta=2*PI/6;
      c.setLineWidth(0.5);
      c.translate(hOff, vOff);

      Coord start = Coord(target*cos(0), target*sin(0));
      Coord end = Coord(target*cos(theta), target*sin(theta));
      Coord cp1 = Coord(cp1Radius*cos(cp1Angle), cp1Radius*sin(cp1Angle));
      Coord cp2 = Coord(cp2Radius*cos(theta+cp2Angle), cp2Radius*sin(theta+cp2Angle));
      start.y += u;
      cp1.y += u;
      cp2.y += u;
      end.y += u;


      c.moveTo(0, u);
      c.lineTo(start.x, start.y);
      c.lineTo(end.x, end.y);
      c.closePath();
      c.stroke();

      c.moveTo(cp1.x-3, cp1.y+3);
      c.lineTo(cp1.x+3, cp1.y+3);
      c.lineTo(cp1.x, cp1.y-3);
      c.closePath();
      c.setSourceRgb(0,0,0);
      c.strokePreserve();
      c.fill();

      c.moveTo(cp2.x-3, cp2.y+3);
      c.lineTo(cp2.x+3, cp2.y+3);
      c.lineTo(cp2.x, cp2.y-3);
      c.closePath();
      c.setSourceRgb(0,0,1);
      c.strokePreserve();
      c.fill();

      c.moveTo(start.x, start.y);
      c.curveTo(cp1.x, cp1.y, cp2.x, cp2.y, end.x, end.y);
      c.setSourceRgb(1,0,0);
      c.stroke();
   }

   void renderEditD(Context c)
   {
      double u = 0.25*height;
      double w = width, h = height;
      double hw = w/2, hh = h/2;
      double theta = 2*PI/6;
      double ha = theta/2;
      c.setLineWidth(0.5);
      c.translate(hOff, vOff);

      Coord start = Coord(target*cos(0), target*sin(0));
      Coord cp1 = Coord(cp1Radius*cos(cp1Angle), cp1Radius*sin(cp1Angle));
      Coord cp2 = Coord(cp2Radius*cos(theta/2+cp2Angle), cp2Radius*sin(theta/2+cp2Angle));
      Coord join = Coord(joinRadius*cos(theta/2+joinAngle), joinRadius*sin(theta/2+joinAngle));
      Coord cp1A = Coord(cp1ARadius*cos(theta/2+joinAngle+cp1AAngle), cp1ARadius*sin(theta/2+joinAngle+cp1AAngle));
      Coord cp2A = Coord(cp2ARadius*cos(theta+cp2AAngle), cp2ARadius*sin(theta+cp2AAngle));
      Coord end = Coord(target*cos(theta), target*sin(theta));
      start.y += u;
      cp1.y += u;
      cp2.y += u;
      join.y += u;
      cp1A.y += u;
      cp2A.y += u;
      end.y += u;


      c.moveTo(0, u);
      c.lineTo(start.x, start.y);
      c.lineTo(end.x, end.y);
      c.closePath();
      c.stroke();

      c.moveTo(cp1.x-3, cp1.y+3);
      c.lineTo(cp1.x+3, cp1.y+3);
      c.lineTo(cp1.x, cp1.y-3);
      c.closePath();
      c.setSourceRgb(0,0,0);
      c.strokePreserve();
      c.fill();

      c.moveTo(cp2.x-3, cp2.y+3);
      c.lineTo(cp2.x+3, cp2.y+3);
      c.lineTo(cp2.x, cp2.y-3);
      c.closePath();
      c.setSourceRgb(0,0,1);
      c.strokePreserve();
      c.fill();

      c.moveTo(cp1A.x-3, cp1A.y+3);
      c.lineTo(cp1A.x+3, cp1A.y+3);
      c.lineTo(cp1A.x, cp1A.y-3);
      c.closePath();
      c.setSourceRgb(1,1,0);
      c.strokePreserve();
      c.fill();

      c.moveTo(cp2A.x-3, cp2A.y+3);
      c.lineTo(cp2A.x+3, cp2A.y+3);
      c.lineTo(cp2A.x, cp2A.y-3);
      c.closePath();
      c.setSourceRgb(0,1,1);
      c.strokePreserve();
      c.fill();

      c.moveTo(start.x, start.y);
      c.curveTo(cp1.x, cp1.y, cp2.x, cp2.y, join.x, join.y);
      c.setSourceRgb(0,1,0);
      c.stroke();
      c.moveTo(join.x, join.y);
      c.curveTo(cp1A.x, cp1A.y, cp2A.x, cp2A.y, end.x, end.y);
      c.setSourceRgb(1,0,0);
      c.stroke();
   }

   override void render(Context c)
   {
      if (editMode && !printFlag)
      {
         if (symmetry == SS || symmetry == SA)
            renderEditS(c);
         else
            renderEditD(c);
      }
      else
         renderActual(c);
   }
}
