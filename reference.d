
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module reference;

import main;
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
import cairo.Surface;
import gtk.Widget;
import gtk.Label;
import gtk.Button;
import gtk.ToggleButton;
import gtk.RadioButton;
import gtk.FileFilter;
import gtk.FileChooserDialog;

class Reference : ACBase
{
   static int nextOid = 0;
   Container that;
   string fileName;
   double scf;

   void syncControls()
   {
      //cSet.toggling(false);
      //cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(Reference other)
   {
      this(other.aw, other.parent);
      fileName = other.fileName;
      that = cast(Container) aw.cloneItem(other.that);
      scf = other.scf;
   }

   this(AppWindow w, ACBase parent)
   {
      string s = "Reference "~to!string(++nextOid);
      super(w, parent, s, AC_REFERENCE);
      scf = 1.0;

      setupControls();
      positionControls(true);
   }

   void extendControls()
   {
      int vp = cSet.cy;

      Button b = new Button("Choose COMPO File");
      cSet.add(b, ICoord(0, vp), Purpose.OPENFILE);

      Label l = new Label("Scale");
      l.setTooltipText("Scale larger or smaller - hold down <Ctrl> for faster action");
      cSet.add(l, ICoord(200, vp+5), Purpose.LABEL);
      new MoreLess(cSet, 0, ICoord(260, vp+5), true);

      vp += 35;
      new InchTool(cSet, 0, ICoord(0, vp), true);

      cSet.cy = vp+35;
   }

   void onCSNotify(Widget w, Purpose wid)
   {
      switch (wid)
      {
      case Purpose.OPENFILE:
         onCFB();
         dummy.grabFocus();
         return;
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
      case OP_SCALE:
         scf = cp.dVal;
         lastOp = OP_UNDEF;
         break;
      case OP_MOVE:
         Coord t = cp.coord;
         hOff = t.x;
         vOff = t.y;
         lastOp = OP_UNDEF;
      default:
         return;
      }
      aw.dirty = true;
      reDraw();
   }

   void preResize(int oldW, int oldH)
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

   void onCSMoreLess(int instance, bool more, bool much)
   {
      dummy.grabFocus();
      lastOp = pushC!double(this, scf, OP_SCALE);
      int direction = more? 1: -1;
      if (much)
      {
         if (direction > 0)
            scf *= 1.05;
         else
            scf *= 0.95;
      }
      else
      {
         if (direction > 0)
            scf *= 1.01;
         else
            scf *= 0.99;
      }

      aw.dirty = true;
      if (that !is null)
         reDraw();
   }

   void render(Context c)
   {
      if (that !is null)
      {
         c.translate(hOff, vOff);
         c.scale(scf, scf);
         that.render(c);
      }
      if (!isMoved) cSet.setDisplay(0, reportPosition());
   }
}


