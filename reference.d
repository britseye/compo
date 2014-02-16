
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module reference;

import mainwin;
import acomp;
import common;
import constants;
import types;
import controlset;
import container;

import std.stdio;
import std.string;
import std.conv;

import cairo.Context;
import cairo.Matrix;
import gtk.Widget;
import gtk.Label;
import gtk.Button;
import gtk.ToggleButton;
import gtk.RadioButton;
import gtk.FileFilter;
import gtk.FileChooserDialog;
import gtk.ComboBoxText;

class Reference : ACBase
{
   static int nextOid = 0;
   ComboBoxText cbb;
   ACBase base;
   ACBase that;
   string fileName;
   Coord center;
   double scf;
   bool local;

   override void syncControls()
   {
      //cSet.toggling(false);
      //cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(Reference other)
   {
      this(other.aw, other.parent);
      fileName = other.fileName;
      that = other.that;   // It's a reference - no need to copy
      scf = other.scf;
      local = other.local;
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Reference "~to!string(++nextOid);
      super(w, parent, s, AC_REFERENCE);
      group = ACGroups.REFERENCE;
      tm = new Matrix(&tmData);

      setupControls();
      positionControls(true);
   }

   void getLocalCtrs()
   {
      string thisName = name;
      int count = 0;
      if (parent.type == AC_CONTAINER)
      {
         base = parent.parent;
         thisName = parent.name;
      }
      else
         base = parent;
      foreach (ACBase x; base.children)
      {
         if (x.name == thisName)
            continue;
         cbb.appendText(x.name);
         count++;
      }
      if (!count)
         cbb.appendText("No Locals");
   }

   void setThat(string thatName)
   {
      if (thatName == "Use File")
         return;
      foreach (ACBase x; base.children)
      {
         if (x.name == thatName)
         {
            that = x;
            if (that.type == AC_CONTAINER)
               (cast(Container) that).noBG = true;
            break;
         }
      }
   }

   override void extendControls()
   {
      int vp = cSet.cy;

      Button b = new Button("Choose COMPO File");
      cSet.add(b, ICoord(0, vp), Purpose.OPENFILE);

      cbb = new ComboBoxText(false);
      cbb.appendText("Use File");
      getLocalCtrs();
      cbb.setActive(0);
      cbb.setSizeRequest(194, -1);
      cSet.add(cbb, ICoord(150, vp-2), Purpose.LOCALCTR);

      b = new Button("Refresh List");
      b.setSizeRequest(100, -1);
      cSet.add(b, ICoord(187, vp+32), Purpose.REDRAW);

      vp += 62;
      ComboBoxText cbb1 = new ComboBoxText(false);
      cbb1.appendText("Scale");
      cbb1.appendText("Stretch-H");
      cbb1.appendText("Stretch-V");
      cbb1.appendText("Skew-H");
      cbb1.appendText("Skew-V");
      cbb1.appendText("Rotate");
      cbb1.appendText("Flip-H");
      cbb1.appendText("Flip-V");
      cbb1.setActive(0);
      cbb1.setSizeRequest(100, -1);
      cSet.add(cbb1, ICoord(187, vp), Purpose.XFORMCB);
      new MoreLess(cSet, 0, ICoord(290, vp+5), true);

      new InchTool(cSet, 0, ICoord(0, vp), true);

      cSet.cy = vp+38;
   }

   override bool specificNotify(Widget w, Purpose wid)
   {
      switch (wid)
      {
      case Purpose.OPENFILE:
         onCFB();
         focusLayout();
         return true;
      case Purpose.LOCALCTR:
         string s = (cast(ComboBoxText) w).getActiveText();
         if (s == "Use File")
         {
            that = null;
            return true;
         }
         setThat(s);
         break;
      case Purpose.REDRAW:
         cbb.removeAll;
         cbb.appendText("Use File");
         getLocalCtrs();
         cbb.setActive(0);
         break;
      case Purpose.XFORMCB:
         xform = (cast(ComboBoxText) w).getActive();
         break;
      default:
         return false;
      }
      return true;
   }

   override void undo()
   {
      CheckPoint cp;
      cp = popOp();
      if (cp.type == 0)
         return;
      switch (cp.type)
      {
      case OP_MOVE:
         Coord t = cp.coord;
         hOff = t.x;
         vOff = t.y;
         lastOp = OP_UNDEF;
         break;
      default:
         return;
      }
      aw.dirty = true;
      reDraw();
   }

   override void preResize(int oldW, int oldH)
   {
      double hr = cast(double) width/oldW;
      double vr = cast(double) height/oldH;
      hOff *= hr;
      vOff *= vr;
   }

   void onCFB()
   {
      aw.deserializer.deserializeReference(this);
      aw.dirty = true;
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

   override void modifyTransform(int tt, bool more, bool coarse)
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
         if (!more)
            ra = -ra;
         lastOp = pushC!Transform(this, tf, OP_ROT);
         tf.ra += ra;
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

   override bool compoundTransform()
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

   override void render(Context c)
   {
      c.setSourceRgb(0,0,0);
      if (that !is null)
      {
         c.translate(hOff+width/2, vOff+height/2);
         if (compoundTransform())
            c.transform(tm);
         c.translate(-(width/2), -(height/2));
         that.render(c);
      }
      else
      {
         c.moveTo(5,20);
         c.showText("Nothing is referenced");
      }
      if (!isMoved) cSet.setDisplay(0, reportPosition());
   }
}


