
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

import std.stdio;
import std.math;
import gtk.DrawingArea;
import gtk.Widget;
import gtk.Button;
import gtk.Layout;
import gtk.Frame;
import gtk.Range;
import gtk.HScale;
import gtk.VScale;
import gdk.Color;
import gdk.Event;
import gtk.RadioButton;
import gtk.ComboBoxText;
import gtk.SpinButton;
import gtk.CheckButton;
import gtk.Label;
import cairo.Context;
import gtkc.cairotypes;
import cairo.Matrix;

class Plot : LineSet
{
   string srcFile;
   Coord[] orig;
   double tra = 0.0;
   double tscfh = 1.00;
   double tscfv = 1.00;
   double thshear = 0.0;
   double tvshear = 0.0;
   bool thflip, tvflip;
   Color saveAltColor;

   void syncControls()
   {
      cSet.toggling(false);
      cSet.setSpinButton(LINEWIDTH, lineWidth);
      if (les)
         cSet.setToggle(LESSHARP, true);
      else
         cSet.setToggle(LESROUND, true);
      if (solid)
      {
         cSet.setToggle(SOLID, true);
         cSet.disable(FILL);
         cSet.disable(FILLCOLOR);
      }
      else if (fill)
         cSet.setToggle(FILL, true);
      cSet.setComboIndex(XFORMCB, xform);
      cSet.toggling(true);
      cSet.setHostName(CSTypes.RENAME, name);
   }

   this(Plot other)
   {
      this(other.aw, other.parent, other.name ~ "*");
      constructing = false;
      baseColor = copyColor(other.baseColor);
      altColor = copyColor(other.altColor);
      lineWidth = other.lineWidth;
      les = other.les;
      fill = other.fill;
      center = other.center;
      path.length = other.path.length;
      rpath.length = other.rpath.length;
      path[] = other.path[0..$];
      rpath[] = other.rpath[0..$];
      xform = other.xform;
      tra = other.tra;
      tscfh = other.tscfh;
      tscfv = other.tscfv;
      thshear = other.thshear;
      tvshear = other.tvshear;
      thflip = other.thflip;
      tvflip = other.tvflip;
      syncControls();
   }

   this(AppWindow w, ACBase parent, string name)
   {
      super(w, parent, name, AC_POLYGON);
      constructing = true;
      altColor = new Color();
      les = true;

      tm = new Matrix(&tmData);

      setupControls();
      positionControls(true);
   }

   void setupControls()
   {
      int vp = 0;

      LineParams lp = new LineParams(ICoord(rpLm, vp), true, true, true);
      cSet.add(lp);

      vp += 30;
      Button b = new Button("Choose picture file");
      cSet.add(b, ICoord(rpLm, vp), OPENFILE);

      vp += 30;
      ComboBoxText cbb = new ComboBoxText(false);
      cbb.setTooltipText("Select transformation to apply");
      cbb.setSizeRequest(100, -1);
      cbb.appendText("Scale");
      cbb.appendText("Rotate");
      cbb.appendText("Stretch-H");
      cbb.appendText("Stretch-V");
      cbb.appendText("Skew-H");
      cbb.appendText("Skew-V");
      cbb.appendText("Flip-H");
      cbb.appendText("Flip-V");
      cbb.setActive(0);
      cSet.add(cbb, ICoord(rpLm+160, vp+35), XFORMCB);
      MOLGadget mol = new MOLGadget(0, ICoord(rpLm+275, vp+40) , 20, true);
      cSet.add(mol);

      vp += 68;
      XlateGadget xg = new XlateGadget(0, ICoord(rpLm, vp), 30, true);
      cSet.add(xg);
      cSet.setGroupDisplay(CSTypes.XLG, 0, reportPosition(0));

      Button b = new Button("Redraw ");
      cSet.add(b, ICoord(rpLm+260, vp+10), REDRAW);

      vp += 55;

      RenameGadget rg = new RenameGadget(0, ICoord(rpLm, vp), name, true);
      cSet.add(rg);
   }

   bool readFile()
   {

   }

   void onCSNotify(Widget w, int wid)
   {
      switch (wid)
      {
      case COLOR:
         lastOp = push!Color(this, baseColor, OP_COLOR);
         aw.setColor(false);
         break;
      case LINEWIDTH:
         lastOp = pushC!double(this, lineWidth, OP_THICK);
         lineWidth = (cast(SpinButton) w).getValue();
         break;
      case LESROUND:
         if ((cast(RadioButton) w).getActive())
            les = false;
         break;
      case LESSHARP:
         if ((cast(RadioButton) w).getActive())
            les = true;
         break;
      case XFORMCB:
         xform = (cast(ComboBoxText) w).getActive();
         break;
         break;
      case REDRAW:
         lastOp = push!Path_t(this, path, OP_REDRAW);
         path.length = 0;
         rpath.length = 0;
         readFile();
         dummy.grabFocus();
         break;
      default:
         break;
      }
      reDraw();
   }

   void undo()
   {
      CheckPoint cp;
      cp = popOp();
      if (cp.type == 0)
         return;
      switch (cp.type)
      {
      case OP_COLOR:
         CompoColor cc = cp.color;
         baseColor = new Color(cc.red, cc.green, cc.blue);
         lastOp = OP_UNDEF;
         break;
      case OP_THICK:
         lineWidth = cp.dVal;
         cSet.setSpinButton(LINEWIDTH, lineWidth);
         lastOp = OP_UNDEF;
         break;
      case OP_SCALE:
      case OP_ROTATE:
      case OP_HSTRETCH:
      case OP_VSTRETCH:
      case OP_HSKEW:
      case OP_VSKEW:
      case OP_HFLIP:
      case OP_VFLIP:
         path[] = copyPath(cp.path);
         lastOp = OP_UNDEF;
         break;
      case OP_MOVE:
         Coord t = cp.coord;
         hOff = t.x;
         vOff = t.y;
         lastOp = OP_UNDEF;
         break;
      case OP_REDRAW:
         constructing = false;
         path.length = cp.path.length;
         rpath.length = path.length;
         path[] = copyPath(cp.path);
         lastOp = OP_UNDEF;
         break;
      default:
         break;
      }
      aw.dirty = true;
      reDraw();
   }

   void setName(string newName)
   {
      aw.dirty = true;
      name = newName;
      cSet.setHostName(CSTypes.RENAME, newName);
      if (aw.tv !is null)
         aw.tv.queueDraw();
   }

   void preResize(int oldW, int oldH)
   {
      center.x = width/2;
      center.y = height/2;
      double hr = cast(double) width/oldW;
      double vr = cast(double) height/oldH;
      tm.initScale(hr, vr);
      for (int i = 0; i < path.length; i++)
      {
         tm.transformPoint(path[i].x, path[i].y);
      }
      hOff *= hr;
      vOff *= vr;
   }

   void setPath()
   {
      double cx = 0.0, cy = 0.0;
      path.length = rpath.length;
      foreach (Coord p; rpath)
      {
         cx += p.x;
         cy += p.y;
      }
      cx /= rpath.length;
      cy /= rpath.length;
      center.x = cx;
      center.y = cy;
      foreach (int i, Coord p; rpath)
      {
         path[i].x = p.x-cx;
         path[i].y = p.y-cy;
      }
      orig = path[];
   }

   void onCSAdjust(int id, int direction, bool much)
   {
      dummy.grabFocus();
      if (xform == 0)        // Scale
      {
         lastOp = pushC!Path_t(this, path, OP_SCALE);
         double factor;
         if (much)
            factor = direction*0.1;
         else
            factor = direction*0.03;
         double scx = 1+factor;
         double scy = 1+factor;
         tm.initScale(scx, scy);
         for (int i = 0; i < path.length; i++)
            tm.transformPoint(path[i].x, path[i].y);
      }
      else if (xform == 1) // Rotate
      {
         lastOp = pushC!Path_t(this, path, OP_ROTATE);
         double ra = much? rads*5: rads/3;
         ra *= direction;
         tm.initRotate(ra);
         for (int i = 0; i < path.length; i++)
            tm.transformPoint(path[i].x, path[i].y);
      }
      else if (xform == 2)        // Stretch -
      {
         lastOp = pushC!Path_t(this, path, OP_HSTRETCH);
         double factor;
         if (much)
            factor = direction*0.1;
         else
            factor = direction*0.03;
         double scx = 1+factor;
         double scy = 1.0;
         tm.initScale(scx, scy);
         for (int i = 0; i < path.length; i++)
            tm.transformPoint(path[i].x, path[i].y);
      }
      else if (xform == 3)        // Stretch |
      {
         lastOp = pushC!Path_t(this, path, OP_VSTRETCH);
         double factor;
         if (much)
            factor = direction*0.1;
         else
            factor = direction*0.03;
         double scx = 1.0;
         double scy = 1+factor;
         tm.initScale(scx, scy);
         for (int i = 0; i < path.length; i++)
            tm.transformPoint(path[i].x, path[i].y);
      }
      else if (xform == 4) // Skew/shear horizontal
      {
         lastOp = pushC!Path_t(this, path, OP_HSKEW);
         tm.init(1.0, 0.0, -direction/20.0,1.0, 0.0, 0.0);
         for (int i = 0; i < path.length; i++)
            tm.transformPoint(path[i].x, path[i].y);
      }
      else if (xform == 5)// vertical
      {
         lastOp = pushC!Path_t(this, path, OP_VSKEW);
         tm.init(1.0, -direction/20.0, 0.0, 1.0, 0.0, 0.0);
         for (int i = 0; i < path.length; i++)
            tm.transformPoint(path[i].x, path[i].y);
      }
      else if (xform == 6)
      {
         lastOp = pushC!Path_t(this, path, OP_HFLIP);
         tm.init(-1.0, 0.0, 0.0, 1.0, 0.0, 0.0);
         for (int i = 0; i < path.length; i++)
            tm.transformPoint(path[i].x, path[i].y);
      }
      else
      {
         lastOp = pushC!Path_t(this, path, OP_VFLIP);
         tm.init(1.0, 0.0, 0.0, -1.0, 0.0, 0.0);
         for (int i = 0; i < path.length; i++)
            tm.transformPoint(path[i].x, path[i].y);
      }
      aw.dirty = true;
      reDraw();
   }

   void render(Context c)
   {
      if (path.length <   2)
         return;
      convert2DA();
      double r = cast(double)baseColor.red()/ushort.max;
      double g = cast(double)baseColor.green()/ushort.max;
      double b = cast(double)baseColor.blue()/ushort.max;
      c.setLineWidth(lineWidth);
      c.setLineJoin(les? CairoLineJoin.MITER: CairoLineJoin.ROUND);
      c.moveTo(hOff+rpath[0].x, vOff+rpath[0].y);
      for (int i = 1; i < rpath.length; i++)
         c.lineTo(hOff+rpath[i].x, vOff+rpath[i].y);
      c.closePath();
      c.setSourceRgb(r, g, b);
      c.stroke();
      if (!isMoved) cSet.setGroupDisplay(CSTypes.XLG, 0, reportPosition());
   }
}


