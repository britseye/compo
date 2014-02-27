
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module drawing;

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

// Drawing is just a specialized reference, where the compo file is read from the .compo hidden folder
// or from a drawing database.
class Drawing : ACBase
{
   static int nextOid = 0;
   Container that;
   string dName;
   Coord center;

   override void syncControls()
   {
      //cSet.toggling(false);
      //cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(Drawing other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      dName = other.dName;
      that = cast(Container) aw.cloneItem(other.that);
      that.setTransparent();
      tf = other.tf;
      cSet.setHostName(dName~" "~to!string(++nextOid));
   }

   this(AppWindow w, ACBase parent)
   {
      super(w, parent, "", AC_DRAWING);
      group = ACGroups.DRAWINGS;
      center = Coord(0.5*width, 0.5*height);
      tm = new Matrix(&tmData);

      setupControls();
      positionControls(true);
   }

   this(AppWindow w, ACBase parent, string drawingName)
   {
      dName = drawingName;
      string s = dName~" "~to!string(++nextOid);
      super(w, parent, s, AC_DRAWING);
      group = ACGroups.DRAWINGS;
      center = Coord(0.5*width, 0.5*height);
      tm = new Matrix(&tmData);
      aw.deserializer.deserializeDrawing(this);

      setupControls();
      positionControls(true);
   }

   override void afterDeserialize()
   {
      name = dName~" "~to!string(++nextOid);
      //aw.deserializer.deserializeDrawing(this);
   }

   override void extendControls()
   {
      int vp = cSet.cy;

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
      cSet.add(cbb, ICoord(167, vp), Purpose.XFORMCB);
      new MoreLess(cSet, 0, ICoord(275, vp+5), true);

      new InchTool(cSet, 0, ICoord(0, vp), true);

      cSet.cy = vp+38;
   }

   override bool specificNotify(Widget w, Purpose wid)
   {
      switch (wid)
      {
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
      case OP_SCALE:
      case OP_HSC:
      case OP_VSC:
      case OP_HSK:
      case OP_VSK:
      case OP_ROT:
      case OP_HFLIP:
      case OP_VFLIP:
         tf = cp.transform;
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

   override void render(Context c)
   {
      if (that !is null)
      {
         c.translate(hOff+center.x, vOff+center.y);
         if (compoundTransform())
            c.transform(tm);
         c.translate(-center.x, -center.y);
         that.render(c);
      }
      else
      {
         c.setSourceRgb(0,0,0);
         c.moveTo(5,20);
         c.showText("Nothing is referenced");
      }
   }
}


