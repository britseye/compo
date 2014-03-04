module lineset;

import std.stdio;
import std.conv;
import std.array;
import std.format;

import acomp;
import mainwin;
import constants;
import types;
import common;
import controlset;

import gtkc.cairotypes;
import cairo.Matrix;
import gdk.RGBA;
import gtk.ComboBox;
import gtk.Widget;
import gtk.RadioButton;
import gtk.CheckButton;
import gtk.ComboBoxText;
import gtk.Label;

class LineSet : ACBase
{
   double lineWidth;

   Coord[] oPath;
   Coord[] rPath;
   Coord center;

   cairo_path_t* cpath;
   bool les, closed;
   bool killAdjust;

   this(AppWindow _aw, ACBase _parent, string _name, uint _type, ACGroups g = ACGroups.UNSPECIFIED)
   {
      super(_aw, _parent, _name, _type, g);
      notifyHandlers ~= &LineSet.notifyHandler;

      lineWidth = 0.5;
      les = cairo_line_cap_t.BUTT;
   }

   override void setName(string newName)
   {
      aw.dirty = true;
      name = newName;
      cSet.setHostName(newName);
      if (aw.tv !is null)
         aw.tv.queueDraw();
   }

   override void setupControls(uint flags = 0)
   {
      bool withLes = (flags & 1) != 0;
      bool sharp = (flags & 2) != 0;
      LineParams tp = new LineParams(cSet, ICoord(0, 0), true, withLes, sharp);

      extendControls();

      if (closed)
      {
         CheckButton check = new CheckButton("Outline");
         check.setActive(1);
         cSet.add(check, ICoord(0, cSet.cy+2), Purpose.OUTLINE);

         fillType = new Label("(N)");
         cSet.add(fillType, ICoord(98, cSet.cy+4), Purpose.FILLTYPE);

         fillOptions = new ComboBoxText(false);
         fillOptions.appendText("Choose Fill Type");
         fillOptions.appendText("Color");
         fillOptions.appendText("None");
         fillOptions.appendText("Refresh Options");
         getFillOptions(this);
         fillOptions.setActive(0);
         fillOptions.setTooltipText("Not filled");
         cSet.add(fillOptions, ICoord(120, cSet.cy-5), Purpose.FILLOPTIONS);
         cSet.cy += 30;
      }

      RenameGadget rg = new RenameGadget(cSet, ICoord(2, cSet.cy), name, true);
      rg.setName(name);
      if (type != AC_CONTAINER)
      {
         CheckButton cb = new CheckButton("Hide Item");
         cb.setActive(0);
         cSet.add(cb, ICoord(210, cSet.cy), Purpose.HIDE, true);
      }
      cSet.setLineWidth(lineWidth);
   }

   override void deserializeComplete()
   {
      if (fillType is null)
         return;
      updateFillOptions(this);
      updateFillUI();
   }

   string formatLT(double lt)
   {
      scope auto w = appender!string();
      formattedWrite(w, "%1.1f", lt);
      return w.data;
   }

   override bool notifyHandler(Widget w, Purpose p)
   {
      switch (p)
      {
      case Purpose.LESROUND:
         if ((cast(RadioButton) w).getActive())
            les = false;
         break;
      case Purpose.LESSHARP:
         if ((cast(RadioButton) w).getActive())
            les = true;
         break;
      case Purpose.OUTLINE:
         FillSpec fs = FillSpec(fill, outline, altColor, fillFromPattern, fillUid);
         lastOp = push!FillSpec(this, fs, OP_FILL);
         outline = !outline;
         break;
      case Purpose.FILLOPTIONS:
         int n = fillOptions.getActive();
         if (n == 0)
         {
            nop = true;
            return true;
         }
         FillSpec fs = FillSpec(fill, outline, altColor, fillFromPattern, fillUid);
         lastOp = push!FillSpec(this, fs, OP_FILL);
         if (n == 1)
         {
            setColor(true);
            fillFromPattern = false;
            fill = true;
         }
         else if (n == 2)
         {
            fillFromPattern = false;
            fill = false;
         }
         else if (n == 3)
         {
            updateFillOptions(this);
            fillOptions.setActive(0);
            nop = true;
            return true;
         }
         else
         {
            fillFromPattern = true;
            fillUid = others[n-4];
            fill = true;
         }
         fillOptions.setActive(0);
         updateFillUI();
         break;
      case Purpose.XFORMCB:
         xform = (cast(ComboBoxText) w).getActive();
         break;
      default:
         return false;
      }
      return true;
   }
/*
   override void onCSNotify(Widget w, Purpose wid)
   {
      switch (wid)
      {
      case Purpose.COLOR:
         lastOp = push!RGBA(this, baseColor, OP_COLOR);
         setColor(false);
         break;
      case Purpose.LESROUND:
         if ((cast(RadioButton) w).getActive())
            les = false;
         break;
      case Purpose.LESSHARP:
         if ((cast(RadioButton) w).getActive())
            les = true;
         break;
      case Purpose.OUTLINE:
         FillSpec fs = FillSpec(fill, outline, altColor, fillFromPattern, fillUid);
         lastOp = push!FillSpec(this, fs, OP_FILL);
         outline = !outline;
         break;
      case Purpose.FILLOPTIONS:
         int n = fillOptions.getActive();
         if (n == 0)
            return;
         FillSpec fs = FillSpec(fill, outline, altColor, fillFromPattern, fillUid);
         lastOp = push!FillSpec(this, fs, OP_FILL);
         if (n == 1)
         {
            setColor(true);
            fillFromPattern = false;
            fill = true;
         }
         else if (n == 2)
         {
            fillFromPattern = false;
            fill = false;
         }
         else if (n == 3)
         {
            updateFillOptions(this);
            fillOptions.setActive(0);
            return;
         }
         else
         {
            fillFromPattern = true;
            fillUid = others[n-4];
            fill = true;
         }
         fillOptions.setActive(0);
         updateFillUI();
         break;
      case Purpose.XFORMCB:
         xform = (cast(ComboBoxText) w).getActive();
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

   override bool specificUndo(CheckPoint cp) { return false; }

   override void undo()
   {
      CheckPoint cp;
      cp = popOp();
      bool here = true;
      if (cp.type == 0)
         return;
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
      case OP_ALTCOLOR:
         altColor = cp.color.copy();
         break;
      case OP_THICK:
         lineWidth = cp.dVal;
         cSet.setLineParams(lineWidth);
         break;
      case OP_PATH:
         oPath = cp.path;
         dirty = true;
         break;
      case OP_SCALE:
      case OP_HSC:
      case OP_VSC:
      case OP_HSK:
      case OP_VSK:
      case OP_ROT:
      case OP_HFLIP:
      case OP_VFLIP:
         dirty = true;  // Must recalculate the render path
         tf = cp.transform;
         break;
      case OP_MOVE:
         Coord t = cp.coord;
         hOff = t.x;
         vOff = t.y;
         break;
      case OP_FILL:
         FillSpec t = cp.fillSpec;
         fill = t.fill, outline = t.outline, fillFromPattern = t.fillFromPattern;
         fillUid = t.fillUid;
         altColor = new RGBA(t.color.r, t.color.g, t.color.b, t.color.a);
         updateFillUI();
         break;
      default:
         here = false;
         if (!specificUndo(cp))
            return;
         break;
      }
      if (here)
         lastOp = OP_UNDEF;
      aw.dirty = true;
      reDraw();
   }

   void changeTransform(ComboBox cb)
   {
      xform = cb.getActive();
   }

   void centerPath()
   {
      for (size_t i = 0; i < oPath.length; i++)
      {
         oPath[i].x -= center.x;
         oPath[i].y -= center.y;
      }
   }

   void transformPath(bool mValid)
   {
      rPath = oPath.dup;
      for (size_t i = 0; i < rPath.length; i++)
      {
         if (mValid)
            tm.transformPoint(rPath[i].x, rPath[i].y);
         rPath[i].x += center.x;
         rPath[i].y += center.y;
      }
   }

   override void onCSLineWidth(double lw)
   {
      focusLayout();
      lastOp = pushC!double(this, lineWidth, OP_THICK);
      lineWidth = lw;
      aw.dirty = true;
      reDraw();
   }
}

