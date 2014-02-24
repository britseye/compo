
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module morphtext;

import mainwin;
import acomp;
import tvitem;
import types;
import constants;
import common;
import controlset;
import morphs;
import morphdlgs;

import std.stdio;
import std.string;
import std.conv;
import std.array;
import std.format;

import cairo.Context;
import gtk.Widget;
import gtk.Label;
import gtk.TextBuffer;
import gtk.Button;
import gtk.SpinButton;
import gtk.CheckButton;
import gtk.ToggleButton;
import gtk.RadioButton;
import gtk.ComboBoxText;
import gtk.Dialog;
import pango.PgFontDescription;
import gtkc.gdktypes;
import gtkc.cairotypes;
import cairo.Matrix;
import gdk.RGBA;
import cairo.Surface;
import pango.PgCairo;
import pango.PgLayout;
import gtkc.pangotypes;

class MorphText : TextViewItem
{
   static int nextOid = 0;
   int cm;
   Morpher morpher;
   CairoPath* morphed;
   RGBA saveAltColor;
   bool doXform;
   double olt;
   MorphDlg md;
   bool mdShowing;
   ParamBlock mp, given;
   string paramString;

   string formatLT(double lt)
   {
      scope auto w = appender!string();
      formattedWrite(w, "%1.1f", lt);
      return w.data;
   }

   override void syncControls()
   {
      cSet.setLineWidth(olt);
      cSet.setTextParams(alignment, pfd.toString());
      cSet.toggling(false);
      if (outline)
         cSet.setToggle(Purpose.OUTLINE, true);
      cSet.setComboIndex(Purpose.XFORMCB, xform);
      cSet.setComboIndex(Purpose.MORPHCB, cm);
      toggleView();
      cSet.setLabel(Purpose.LINEWIDTH, formatLT(olt));
      cSet.toggling(true);
      cSet.setComboIndex(Purpose.XFORMCB, xform);
      cSet.setComboIndex(Purpose.FILLOPTIONS, 0);
      cSet.setHostName(name);
   }

   this(MorphText other)
   {
      this(other.aw, other.parent);
      other.updateParams();  // just in case not saved ;=)
      editMode = other.editMode;
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      altColor = other.altColor.copy();
      pfd = other.pfd.copy();
      mp = other.mp;
      olt = other.olt;
      xform = other.xform;
      tf = other.tf;
      cm = other.cm;
      fill = other.fill;
      outline = other.outline;
      fillFromPattern = other.fillFromPattern;
      fillUid = other.fillUid;
      updateFillUI();
      syncControls();

      string text = other.tb.getText();
      tb.setText(text);
   }

   this(AppWindow w, ACBase parent, bool delayCM = false)
   {
      string s = "Morphed Text "~to!string(++nextOid);
      super(w, parent, s, AC_MORPHTEXT);
      altColor = new RGBA(0,0,0,1);
      fill = false;
      olt = 0.5;
      editMode = true;
      xform = 0;
      tm = new Matrix(&tmData);
      int vp = rpTm+height+90;
      mdShowing = false;
      cm = aw.config.defMorph;
      setupControls();
      outline = true;
      positionControls(true);
      toggleView();
      pfd = PgFontDescription.fromString("Sans 30");
      cSet.setTextParams(0, "Sans 30");
      if (!delayCM)
      {
         changeMorph();
         createMorphDlg();
      }
   }

   override void preResize(int oldW, int oldH)
   {
      morphed = null;
      double hr = cast(double) width/oldW;
      double vr = cast(double) height/oldH;
      tf.hScale *= hr;
      tf.vScale *= vr;
      hOff *= hr;
      vOff *= vr;
   }

   override void extendControls()
   {
      int vp = cSet.cy;
      new InchTool(cSet, 0, ICoord(0, vp+4), false);

      Label l = new Label("Outline thickness");
      cSet.add(l, ICoord(162, vp-18), Purpose.LABEL);
      MOLLineThick mlt = new MOLLineThick(cSet, 0, ICoord(286, vp-18), false);

      ComboBoxText cbb = new ComboBoxText(false);
      cbb.setTooltipText("Select transformation to apply");
      cbb.setSizeRequest(120, -1);
      cbb.appendText("Scale");
      cbb.appendText("Stretch-H");
      cbb.appendText("Stretch-V");
      cbb.appendText("Skew-H");
      cbb.appendText("Skew-V");
      cbb.appendText("Rotate");
      cbb.appendText("Flip-H");
      cbb.appendText("Flip-V");
      cbb.setSizeRequest(100, -1);
      cbb.setActive(0);
      cSet.add(cbb, ICoord(175, vp), Purpose.XFORMCB);
      new MoreLess(cSet, 0, ICoord(286, vp+5), false);

      vp += 40;
      l = new Label("Morph Type");
      cSet.add(l, ICoord(0, vp), Purpose.LABEL);
      cbb = new ComboBoxText(false);
      cbb.appendText("Fit the area");
      cbb.appendText("Taper");
      cbb.appendText("Arch Up");
      cbb.appendText("Sine Wave");
      cbb.appendText("Twisted");
      cbb.appendText("Flare");
      cbb.appendText("Reverse Flare");
      cbb.appendText("Circular");
      cbb.appendText("Catenary");
      cbb.appendText("Convex");
      cbb.appendText("Concave");
      cbb.appendText("Bezier Curves");
      cbb.setSizeRequest(100, -1);
      cbb.setActive(aw.config.defMorph);
      cSet.add(cbb, ICoord(151, vp-5), Purpose.MORPHCB);

      vp +=20;
      Button b = new Button("More");
      b.setTooltipText("Additional controls for particular morphs");
      b.setSizeRequest(80, -1);
      cSet.add(b, ICoord(0, vp), Purpose.MORE);

      vp += 30;
      CheckButton check = new CheckButton("Outline");
      check.setActive(1);
      cSet.add(check, ICoord(0, vp+2), Purpose.OUTLINE);

      fillType = new Label("(N)");
      cSet.add(fillType, ICoord(98, vp+4), Purpose.FILLTYPE);

      fillOptions = new ComboBoxText(false);
      fillOptions.appendText("Choose Fill Type");
      fillOptions.appendText("Color");
      fillOptions.appendText("None");
      fillOptions.appendText("Refresh Options");
      getFillOptions(this);
      fillOptions.setActive(0);
      cSet.add(fillOptions, ICoord(120, vp-5), Purpose.FILLOPTIONS);

      cSet.cy = vp+30;
   }

   void updateParams()
   {
      morpher.updateParams();
   }

   void pushParams()
   {
      updateParams();
      lastOp = push!ParamBlock(this, mp, OP_PARAMS);
   }

   override void deserializeComplete()
   {
      if (fillType is null)
         return;
      updateFillOptions(this);
      updateFillUI();
   }

   override bool specificNotify(Widget w, Purpose wid)
   {
      switch (wid)
      {
      case Purpose.FILLCOLOR:
         setColor(true);
         break;
      case Purpose.FILL:
         fill = !fill;
         break;
      case Purpose.OUTLINE:
         outline = !outline;
         break;
      case Purpose.FILLOPTIONS:
         int n = fillOptions.getActive();
         if (n == 0)
            return false;
         if (n == 1)
         {
            lastOp = push!RGBA(this, altColor, OP_ALTCOLOR);
            setColor(true);
            fillFromPattern = false;
            fill = true;
            fillType.setText("(C)");
         }
         else if (n == 2)
         {
            fillFromPattern = false;
            fill = false;
            fillType.setText("(N)");
         }
         else if (n == 3)
         {
            updateFillOptions(this);
            fillOptions.setActive(0);
            return false;
         }
         else
         {
            fillFromPattern = true;
            fillUid = others[n-4];
            fill = true;
            fillType.setText("(P)");
         }
         fillOptions.setActive(0);
         updateFillUI();
         break;
      case Purpose.MORE:
         if (mdShowing)
         {
            md.hide();
            mdShowing = false;
            cSet.setLabel(Purpose.MORE, "More");
         }
         else
         {
            md.showAll();
            mdShowing = true;
            cSet.setLabel(Purpose.MORE, "Less");
         }
         break;
      case Purpose.MORPHCB:
         cm = (cast(ComboBoxText) w).getActive();
         changeMorph();
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
      case OP_FONT:
         pfd = PgFontDescription.fromString(cp.s);
         lastOp = OP_UNDEF;
         te.modifyFont(pfd);
         break;
      case OP_COLOR:
         applyColor(cp.color, false);
         lastOp = OP_UNDEF;
         break;
      case OP_TEXT:
         disableHandlers = true;
         if (cp.s is null)
            tb.setText("");
         else
            tb.setText(cp.s);
         disableHandlers = false;
         lastOp = OP_UNDEF;
         te.queueDraw();
         break;
      case OP_SCALE:
      case OP_HSC:
      case OP_VSC:
      case OP_HSK:
      case OP_VSK:
      case OP_ROT:
      case OP_HFLIP:
      case OP_VFLIP:
         //dirty = true;  // Must recalculate the render path
         tf = cp.transform;
         lastOp = OP_UNDEF;
         break;
      case OP_PARAMS:
         mp = cp.paramBlock;
         lastOp = OP_UNDEF;
         break;
      case OP_MOVE:
         Coord t = cp.coord;
         hOff = t.x;
         vOff = t.y;
         lastOp = OP_UNDEF;
         break;
      default:
         break;
      }
      te.grabFocus();
      aw.dirty = true;
      reDraw();
   }

   override void onCSLineWidth(double lt)
   {
      olt = lt;
      aw.dirty = true;
      reDraw();
   }

   override void toggleView()
   {
      if (editMode)
      {
         da.hide();
         dframe.hide();
         te.show();
         edButton.setLabel("Design");
         cSet.disable(Purpose.MOLLT, 0);
         cSet.disable(Purpose.XFORMCB);
         cSet.disable(Purpose.MORPHCB);
         cSet.disable(Purpose.MOL, 0);
         cSet.disable(Purpose.INCH, 0);
         eframe.show();
         te.grabFocus();
         te.show();
      }
      else
      {
         te.hide();
         eframe.hide();
         cSet.enable(Purpose.MOLLT, 0);
         cSet.enable(Purpose.XFORMCB);
         cSet.enable(Purpose.MORPHCB);
         cSet.enable(Purpose.MOL, 0);
         cSet.enable(Purpose.INCH, 0);
         dframe.show();
         edButton.setLabel("Edit Text");
         string txt=tb.getText();
         if (txt.length)
         {
            string[] a = split(txt, "\n");
            txt = a[0];
            if (txt.length > 20)
               txt = txt[0..17] ~ "...";
            setName(txt);
         }
         da.show();
      }
      aw.dirty = true;
   }

   override void bufferChanged(TextBuffer b)
   {
      aw.dirty = true;
      dirty = true;
      morphed = null;
   }

   override void afterDeserialize()
   {
      changeMorph();
      createMorphDlg();
   }

   void refreshMorph()
   {
      morphed = null;
      aw.dirty = true;
      reDraw();
   }

   void createMorphDlg()
   {
      switch (cm)
      {
      case 0:
         md = new FitAreaDlg(this, morpher);
         break;
      case 1:
         md = new TaperDlg(this, morpher);
         break;
      case 2:
         md = new ArchUpDlg(this, morpher);
         break;
      case 3:
         md = new SineWaveDlg(this, morpher);
         break;
      case 5:
         md = new FlareDlg(this, morpher);
         break;
      case 6:
         md = new RFlareDlg(this, morpher);
         break;
      case 7:
         md = new CircularDlg(this, morpher);
         break;
      case 8:
         md = new CatenaryDlg(this, morpher);
         break;
      case 9:
         md = new ConvexDlg(this, morpher);
         break;
      case 10:
         md = new ConcaveDlg(this, morpher);
         break;
      case 11:
         md = new BezierDlg(this, morpher);
         break;
      default:
         md = new MorphDlg("Morph Dialog", this, null);
         break;
      }
      md.setSizeRequest(300, 200);
      md.setPosition(GtkWindowPosition.POS_NONE);
      int px, py;
      aw.getPosition(px, py);
      md.move(px+4, py+300);
      md.addOnResponse(&onPdResponse);
      mdShowing = false;
   }


   void onMoreLess(Button b)
   {
      if (mdShowing)
      {
         md.hide();
         mdShowing = false;
         b.setLabel("More");
      }
      else
      {
         md.showAll();
         mdShowing = true;
         b.setLabel("Less");
      }
   }

   override void hideDialogs()
   {
         md.destroy();
   }

   void changeMorph()
   {
      if (md !is null)
         md.destroy();
      switch (cm)
      {
      case 0:
         morpher = new FitBox(width, height, &mp);
         break;
      case 1:
         morpher = new Taper(width, height, &mp);
         break;
      case 2:
         morpher = new ArchUp(width, height, &mp);
         break;
      case 3:
         morpher = new SineWave(width, height, &mp);
         break;
      case 4:
         morpher = new Twisted(width, height,&mp);
         break;
      case 5:
         morpher = new Flare(width, height, &mp);
         break;
      case 6:
         morpher = new RFlare(width, height, &mp);
         break;
      case 7:
         morpher = new Circular(width, height, &mp);
         break;
      case 8:
         morpher = new Catenary(width, height, &mp);
         break;
      case 9:
         morpher = new Convex(width, height, &mp);
         break;
      case 10:
         morpher = new Concave(width, height, &mp);
         break;
      case 11:
         morpher = new BezierMorph(width, height, &mp);
         break;
      default:
         morpher = null;
         break;
      }
      morphed = null;
      createMorphDlg();
      aw.dirty = true;
      if (!editMode)
         reDraw();
   }

   void onPdResponse(int n, Dialog d)
   {
      d.hide();
      cSet.setLabel(Purpose.MORE, "More");
      mdShowing = false;
   }

   override void onCSMoreLess(int instance, bool more, bool coarse)
   {
      if (instance == 0)
      {
         modifyTransform(xform, more, coarse);
         aw.dirty = true;
         if (!editMode)
            reDraw();
      }
   }

   Rect getTextRect(PgLayout pl)
   {
      Rect r;
      PangoRectangle ink, logic;
      pl.getExtents (&ink, &logic);
      r.topX = logic.x/1024.0;
      r.topY = logic.y/1024;
      r.bottomX = (logic.x+logic.width)/1024.0;
      r.bottomY = (logic.y+logic.height)/1024.0;
      return r;
   }

   int foreachPath(Morpher m, Rect extent)
   {
      CairoPathData* data;
      int n = 0;
      for (int i = 0; i < morphed.numData; i += morphed.data[i].header.length)
      {
         data = &morphed.data[i];
         switch (data.header.type)
         {
         case cairo_path_data_type_t.MOVE_TO:
            m.transform(data, 0, extent);
            n += 1;
            break;
         case cairo_path_data_type_t.LINE_TO:
            m.transform(data, 1, extent);
            n += 1;
            break;
         case cairo_path_data_type_t.CURVE_TO:
            m.transform(data, 2, extent);
            n += 3;
            break;
         case cairo_path_data_type_t.CLOSE_PATH:
            break;
         default:
            break;
         }
      }
      return n;
   }

   void onFontChange()
   {
      morphed = null;
   }

   override void render(Context c)
   {
      string text = tb.getText();
      if (!text.length)
         return;
      double r = baseColor.red();
      double g = baseColor.green();
      double b = baseColor.blue();
      if (morphed is null)
      {
         Surface hiddenSurface = c.getTarget().createSimilar(cairo_content_t.COLOR_ALPHA, width*10, height);
         Context hidden = c.create(hiddenSurface);
         PgLayout pgl = PgCairo.createLayout(hidden);
         pgl.setSpacing(0);
         pgl.setFontDescription(pfd);
         pgl.setText(text);
         PgCairo.layoutPath(hidden, pgl);
         hidden.strokePreserve();
         Rect xt = getTextRect(pgl);
         morphed = cast(CairoPath*) hidden.copyPath();
         foreachPath(morpher, xt);
      }

      c.newPath();

      c.translate(hOff+width/2, vOff+height/2);
      if (compoundTransform())
         c.transform(tm);
      c.translate(-width/2, -height/2);

      c.appendPath(cast(cairo_path_t*) morphed);
      strokeAndFill(c, olt, outline, fill);
   }
}
