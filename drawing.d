
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module drawing;

import main;
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
import gtk.Button;
import gtk.SpinButton;
import gtk.ToggleButton;
import gtk.RadioButton;
import gtk.CheckButton;
import gtk.Label;
import cairo.Context;
import gtkc.cairotypes;
import cairo.Matrix;


class Drawing : LineSet
{
   static int nextOid = 0;
   Part[] spec;
   string dName;

   Part[] rpa;
   PartColor[] pca;
   ComboBoxText cicb;

   override void syncControls()
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
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   void setupFillColors()
   {
      pca.length = spec.length;
      foreach (int k, Part p; spec)
      {
         if (p.closed)
            pca[k] = p.color;
         else
            pca[k] = PartColor(double.nan, double.nan, double.nan, double.nan);
      }
   }

   this(Drawing other)
   {
      this(other.aw, other.parent, other.dName);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      lineWidth = other.lineWidth;
      les = other.les;
      fill = other.fill;
      solid = other.solid;
      //altColor = other.altColor.copy();
      pca = other.pca.dup;
      spec = other.spec;
      center = spec[0].center;
      xlatePath();
      xform = other.xform;
      tf = other.tf;
      dirty = true;
      syncControls();
   }

   this(AppWindow w, ACBase parent, string name)
   {
      dName = name;
      string s = name~" "~to!string(++nextOid);
      if (name != "")  // We'll do it later if reading from file
         spec = aw.shapeLib.getEntry(name);
      super(w, parent, s, AC_DRAWING);
      //altColor = new RGBA(1,1,1,1);
      lineWidth = 1;
      les = true;
      fill = solid = false;

      tm = new Matrix(&tmData);

      center = spec[0].center;
      xlatePath();
      setupFillColors();
      setupControls(3);
      positionControls(true);
      if (tf != tf.init)
         dirty = true;
   }

   override void extendControls()
   {
      int vp = cSet.cy;


      vp += 5;
      new InchTool(cSet, 0, ICoord(0, vp), true);

      ComboBoxText cbb = new ComboBoxText(false);
      cbb.appendText("Scale");
      cbb.appendText("Stretch-H");
      cbb.appendText("Stretch-V");
      cbb.appendText("Skew-H");
      cbb.appendText("Skew-V");
      cbb.appendText("Rotate");
      cbb.appendText("Flip-H");
      cbb.appendText("Flip-V");
      cbb.setActive(0);
      cbb.setSizeRequest(100, -1);
      cSet.add(cbb, ICoord(180, vp-40), Purpose.XFORMCB);
      new MoreLess(cSet, 0, ICoord(283, vp-35), true);

      cicb = new ComboBoxText(false);
      cicb.appendText("Part colors");
      foreach (Part p; spec)
         cicb.appendText(p.name);
      cicb.setActive(0);
      cicb.setSizeRequest(100, -1);
      cSet.add(cicb, ICoord(180, vp-5), Purpose.DCOLORS);

      cSet.cy = vp+35;
   }

   override void preResize(int oldW, int oldH)
   {
      center.x = width/2;
      center.y = height/2;
      double hr = cast(double) width/oldW;
      double vr = cast(double) height/oldH;
      tf.hScale *= hr;
      tf.vScale *= vr;
      hOff *= hr;
      vOff *= vr;
      dirty = true;
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

   bool specificNotify(Widget w, Purpose p)
   {
      switch (p)
      {
      case Purpose.DCOLORS:
         int index = (cast(ComboBoxText) w).getActive();
         if (index > 0)
         {
            index--;
            RGBA current = new RGBA(pca[index].r, pca[index].g, pca[index].b, 1);
            RGBA rgba = getDColor(current);
            if (rgba is null)
            {
               cicb.setActive(0);
               return false;
            }
            pca[index] = PartColor(rgba.red, rgba.green, rgba.blue, 1);
            cicb.setActive(0);
         }
         else
            return false;
         break;
      default:
         return false;
      }
      return true;
   }

   void xlatePath()
   {
      rpa.length = spec.length;
      for (int i = 0; i < rpa.length; i++)
         rpa[i].copy(spec[i]);
   }

   override void render(Context c)
   {
      void renderPolygon(Part p)
      {
         with (p)
         {
            c.moveTo(ia[0].end.x, ia[0].end.y);
            for (int i = 1; i < ia.length; i++)
               c.lineTo(ia[i].end.x, ia[i].end.y);
         }
      }

      void renderPointSet(Part p, int n)
      {
         with (p)
         {
            c.setSourceRgb(pca[n].r, pca[n].g, pca[n].b);
            c.setLineWidth(0);
            foreach (PathItemR pi; ia)
            {
               //c.arc(pi.end.x, pi.end.y, 0.2*lineWidth+0.5, 0, PI*2);
               c.arc(pi.end.x, pi.end.y, lineWidth*p.lwf, 0, PI*2);
               c.strokePreserve();
               c.fill();
            }
         }
      }

      void renderPolycurve(Part p)
      {
         with (p)
         {
            c.moveTo(ia[0].start.x, ia[0].start.y);
            foreach (PathItemR pi; ia)
            {
               if (pi.type == 0)
                  c.lineTo(pi.end.x, pi.end.y);
               else
                  c.curveTo(pi.cp1.x, pi.cp1.y, pi.cp2.x, pi.cp2.y, pi.end.x, pi.end.y);
            }
         }
      }

      void renderStrokeSet(Part p)
      {
         with (p)
         {
            foreach (PathItemR pi; ia)
            {
               c.moveTo(pi.start.x, pi.start.y);
               if (pi.type == 0)
                  c.lineTo(pi.end.x, pi.end.y);
               else
                  c.curveTo(pi.cp1.x, pi.cp1.y, pi.cp2.x, pi.cp2.y, pi.end.x, pi.end.y);
            }
         }
      }

      void renderCircle(Part p)
      {
         with (p)
         {
            c.newSubPath();
            c.arc(ia[0].end.x, ia[0].end.y, ia[0].cp2.x, 0, PI*2);
         }
      }

      c.save();
      c.translate(hOff+center.x, vOff+center.y);
      if (compoundTransform())
         c.transform(tm);
      c.translate(-center.x, -center.y);

      c.setLineJoin(les? CairoLineJoin.MITER: CairoLineJoin.ROUND);
      foreach (int k, Part part; rpa)
      {
         //c.save();
         c.setLineWidth(lineWidth*part.lwf);
         c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);
         switch (part.type)
         {
            case 0:
               renderPolygon(part);
               break;
            case 1:
               renderPointSet(part, k);
               break;
            case 3:
               // It seems that the fill covers half the line thickness
               c.setLineWidth(lineWidth/2);
               renderStrokeSet(part);
               break;
            case 4:
               renderCircle(part);
               break;
            default:
               renderPolycurve(part);
               break;
         }
         if (part.type != 1)
         {
            if (part.closed)
            {
               if (part.type != 4)
                  c.closePath();
               c.strokePreserve();
               c.setSourceRgba(pca[k].r, pca[k].g, pca[k].b, pca[k].a);
               c.fill();
            }
            else
               c.stroke();
         }
         //c.restore();
      }
      c.restore();
      if (!isMoved) cSet.setDisplay(0, reportPosition());
   }
}
