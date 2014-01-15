module lineset;

import std.stdio;
import std.array;
import std.format;

import acomp;
import main;
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

class LineSet : ACBase
{
   double lineWidth;

   Coord[] oPath;
   Coord[] rPath;
   Coord center;
   bool fill, solid;

   cairo_path_t* cpath;
   bool les;
   bool killAdjust;

   this(AppWindow _aw, ACBase _parent, string _name, uint _type)
   {
      super(_aw, _parent, _name, _type);

      lineWidth = 0.5;
      les = cairo_line_cap_t.BUTT;
   }

   void setName(string newName)
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
      RenameGadget rg = new RenameGadget(cSet, ICoord(2, cSet.cy), name, true);
      rg.setName(name);
      cSet.setLineWidth(lineWidth);
   }

   string formatLT(double lt)
   {
      scope auto w = appender!string();
      formattedWrite(w, "%1.1f", lt);
      return w.data;
   }

   override void onCSNotify(Widget w, Purpose wid)
   {
      switch (wid)
      {
      case Purpose.COLOR:
         focusLayout();
         lastOp = push!RGBA(this, baseColor, OP_COLOR);
         setColor(false);
         break;
      case Purpose.FILLCOLOR:
         focusLayout();
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
      case Purpose.FILL:
         fill = !fill;
         break;
      case Purpose.SOLID:
         if (lastOp != OP_SOLID)
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


   bool specificUndo(CheckPoint cp) { return false; }

   void undo()
   {
      CheckPoint cp;
      cp = popOp();
      if (cp.type == 0)
         return;
      switch (cp.type)
      {
      case OP_COLOR:
         baseColor = cp.color.copy();
         lastOp = OP_UNDEF;
         break;
      case OP_ALTCOLOR:
         altColor = cp.color.copy();
         lastOp = OP_UNDEF;
         break;
      case OP_THICK:
         lineWidth = cp.dVal;
         cSet.setLineParams(lineWidth);
         lastOp = OP_UNDEF;
         break;
      case OP_PATH:
         oPath = cp.path;
         dirty = true;
         lastOp = OP_UNDEF;
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
         lastOp = OP_UNDEF;
         break;
      case OP_MOVE:
         Coord t = cp.coord;
         hOff = t.x;
         vOff = t.y;
         lastOp = OP_UNDEF;
         break;
      default:
         if (!specificUndo(cp))
            return;
         break;
      }
      aw.dirty = true;
      reDraw();
   }

   void changeTransform(ComboBox cb)
   {
      xform = cb.getActive();
   }
/*
   void modifyTransform(int tt, bool more, bool coarse)
   {
      // We rather arbitrarily do anisotropic scaling first, then transformations
      // that change the shape - squash and skew, then rotation, then finally flip
      // of the finished object
      if (tt <= 2)        // Scale
      {
         double factor;
         if (more)
            factor = coarse? 1.1: 1.01;
         else
            factor = coarse? 0.9: 0.99;
         switch (tt)
         {
            case 1:
               lastOp = pushC!Transform(this, tf, OP_HSC);
               tf.hScale *= factor;
               break;
            case 2:
               lastOp = pushC!Transform(this, tf, OP_VSC);
               tf.vScale *= factor;
               break;
            default:
               lastOp = pushC!Transform(this, tf, OP_SCALE);
               tf.hScale *= factor;
               tf.vScale *= factor;
               break;
         }
      }
      else if (tt == 3 || tt == 4) // Skew/shear horizontal/vertical
      {
         double delta = coarse? 0.1: 0.01;
         if (!more)
            delta = -delta;
         if (tt == 3)
         {
            lastOp = pushC!Transform(this, tf, OP_HSK);
            tf.hSkew += delta;
         }
         else
         {
            lastOp = pushC!Transform(this, tf, OP_VSK);
            tf.vSkew += delta;
         }
      }
      else if (tt == 5) // Rotate
      {
         double ra = coarse? rads*5: rads/3;
         if (more)
            ra = -ra;
         lastOp = pushC!Transform(this, tf, OP_ROT);
         tf.ra -= ra;
      }
      else if (tt == 6)
      {
         lastOp = pushC!Transform(this, tf, OP_HFLIP);
         tf.hFlip = !tf.hFlip;
      }
      else
      {
         lastOp = pushC!Transform(this, tf, OP_VFLIP);
         tf.vFlip = !tf.vFlip;
      }
   }

   bool compoundTransform()
   {
      Matrix tmp;
      cairo_matrix_t tmpData;
      tmp = new Matrix(&tmpData);
      tm.initIdentity();
      bool any = false;
      if (tf.hScale != 1 || tf.vScale != 1)
      {
         any = true;
         tmp.initScale(tf.hScale, tf.vScale);
         tm.multiply(tm, tmp);
      }
      if (tf.hSkew != 0)
      {
         any = true;
         tmp.init(1.0, 0.0, -tf.hSkew, 1.0, 0.0, 0.0);
         tm.multiply(tm, tmp);
      }
      if (tf.vSkew != 0)
      {
         any = true;
         tmp.init(1.0, -tf.vSkew, 0.0, 1.0, 0.0, 0.0);
         tm.multiply(tm, tmp);
      }
      if (tf.ra != 0)
      {
         any = true;
         tmp.initRotate(tf.ra);
         tm.multiply(tm, tmp);
      }
      if (tf.hFlip)
      {
         any = true;
         tmp.init(-1.0, 0.0, 0.0, 1.0, 0.0, 0.0);
         tm.multiply(tm, tmp);
      }
      if (tf.vFlip)
      {
         any = true;
         tmp.init(1.0, 0.0, 0.0, -1.0, 0.0, 0.0);
         tm.multiply(tm, tmp);
      }
      return any;
   }
*/
   void centerPath()
   {
      for (int i = 0; i < oPath.length; i++)
      {
         oPath[i].x -= center.x;
         oPath[i].y -= center.y;
      }
   }

   void transformPath(bool mValid)
   {
      rPath = oPath.dup;
      for (int i = 0; i < rPath.length; i++)
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

