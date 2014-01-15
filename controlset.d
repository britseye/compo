
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module controlset;

import types;
import interfaces;
import tvitem;
import constants;

import std.stdio;
import std.format;
import std.math;
import std.array;
import std.conv;
import std.variant;

import glib.Timeout;
import gobject.Value;
import gdk.Event;
import gtk.Box;
import gtk.EventBox;
import gtk.DrawingArea;
import gtk.Widget;
import gtk.Layout;
import gtk.Label;
import gtk.Button;
import gtk.FontButton;
import gtk.SpinButton;
import gtk.ToggleButton;
import gtk.RadioButton;
import gtk.CheckButton;
import gtk.ComboBox;
import gtk.Entry;
import gtk.Arrow;
import gdk.RGBA;
import cairo.Context;
import pango.PgFontDescription;

// The range of widgets used in control sets
enum Purpose
{
   VOID,

   R_BUTTONS,
   COLOR,
   OPENFILE,
   FILLCOLOR,
   MORE,
   REVERT,
   GUIDELINE,
   REDRAW,
   NEWVERTEX,
   ADDSTROKE,
   DELEDGE,
   LINE2CURVE,
   RECENTER,
   REMEMBER,
   UNDO,

   R_RADIOBUTTONS = 1000,
   TOPLEFT,
   TOPRIGHT,
   BOTTOMLEFT,
   BOTTOMRIGHT,
   LESROUND,
   LESSHARP,
   MEDIUM,
   NARROW,
   WIDE,
   SCALEPROP,
   SCALEFIT,
   SCALENON,
   HORIZONTAL,
   VERTICAL,
   C00,
   C01,
   C10,
   C11,

   R_CHECKBUTTONS = 2000,
   HIDE,
   EDITMODE,
   CENTERTEXT,
   SHRINK2FIT,
   HRDATA,
   FILL,
   FILLOUTLINE,
   PIN,
   SOLID,
   ROUNDED,
   GLWHICH,
   ASSTAR,
   PRINTRANDOM,
   FADELEFT,
   FADETOP,
   SHOWMARKERS,
   USEFILE,
   ZOOMED,
   PROTECT,
   ANTI,

   R_SPINBUTTONS = 3000,

   R_COMBOBOX = 4000,
   XFORMCB,
   MORPHCB,
   PATTERN,
   LOCALCTR,
   DCOLORS,

   R_GP = 5000,
   ALIGNMENT,
   TEXTSTYLES,
   FONT,
   LABEL,
   LINEWIDTH,
   OPACITY,
   STARINDENT,
   DISPLAY,
   NAMEENTRY,
   INCH,
   MOL,
   MOLLT,
   RENAME,
   SETNAME,
   LINEPARAMS,
   TEXTPARAMS,
   TORIENT,
   INFO1,
   INFO2,
   INFO3,
   COMPASS,
   MLABEL0,
   MLABEL1,
   MLABEL2,
   // Put any new IDs before MAXWID
   MAXWID
}

struct PseudoKey
{
   Purpose p;
   int id;
}

struct WidgetInfo
{
   Widget widget;
   ICoord wpos;
   bool initialState;
   int wid;
}

class ControlSet
{
   CSTarget host;
   Purpose purpose;
   PseudoWidget[PseudoKey] pseudos;
   WidgetInfo[] wia;
   int[] windex;
   ICoord pos;
   int thisId;
   int cx, cy;
   bool noToggle, shift, control;
   Label infoLabel;

   this(CSTarget t)
   {
      windex.length = Purpose.MAXWID;
      purpose = Purpose.VOID;
      windex[] = -1;
      host = t;
   }

   void updateCX(int n)
   {
      cx += n;
   }

   void updateCY(int n)
   {
      cy += n;
   }

   void add(Widget w, ICoord p, Purpose id, bool si = true, bool hasHandler = false)
   {
      w.setData("wid", cast(void*) id);
      if (!hasHandler)
      if (id > Purpose.R_BUTTONS && id < Purpose.R_RADIOBUTTONS)
         (cast(Button) w).addOnButtonPress(&bClick);
      else if (id > Purpose.R_RADIOBUTTONS && id < Purpose.R_CHECKBUTTONS)
         (cast(RadioButton) w).addOnToggled(&rbClick);
      else if (id > Purpose.R_CHECKBUTTONS && id < Purpose.R_SPINBUTTONS)
         (cast(CheckButton) w).addOnToggled(&cbClick);
      else if (id > Purpose.R_SPINBUTTONS && id < Purpose.R_COMBOBOX)
         (cast(SpinButton) w).addOnValueChanged(&sbChange);
      else if (id > Purpose.R_COMBOBOX && id < Purpose.R_GP)
         (cast(ComboBox) w).addOnChanged(&comboChange);
      WidgetInfo ci = WidgetInfo(w, p, si, id);
      wia ~= ci;
      windex[id] = wia.length-1;
   }

   void addInfo(string info)
   {
      info = "<span foreground=\"#aa6666\">"~info~"</span>";
      infoLabel = new Label("");
      infoLabel.setMarkup(info);
      add(infoLabel, ICoord(0, cy+35), Purpose.INFO1);
   }

   void setInfo(string info)
   {
      if (infoLabel is null)
         return;
      info = "<span foreground=\"#aa6666\">"~info~"</span>";
      infoLabel.setMarkup(info);
   }

   void addPseudo(PseudoWidget pw, Purpose p, int instance)
   {
      pw.purpose = p;
      pseudos[PseudoKey(p, instance)] = pw;
   }

   PseudoWidget pseudo(Purpose p, int id)
   {
      PseudoWidget* ppw = (PseudoKey(p, id) in pseudos);
      return (ppw is null)? null: *ppw;
   }

   void setPos(ICoord p)
   {
      pos = p;
   }

   void move(int dx, int dy)
   {
      for (int i = 0; i < wia.length; i++)
      {
         wia[i].wpos.x += dx;
         wia[i].wpos.y += dy;
      }
   }

   void setDisplay(int id, string s)
   {
      PseudoWidget p = pseudo(Purpose.INCH, id);
      if (p !is null)
         p.csInstruction("display", 0, s, 0, 0.0);
   }

   void setHostName(string s)
   {
      PseudoWidget p = pseudo(Purpose.RENAME, 0);
      if (p !is null)
         p.csInstruction("hostname",0, s, 0, 0.0);
   }

   void setLineParams(double lt)
   {
      PseudoWidget p = pseudo(Purpose.LINEPARAMS, 0);
      if (p !is null)
         p.csInstruction("linewidth", 0, "", 0, lt);
   }

   void setLineWidth(double lt)
   {
      PseudoWidget p = pseudo(Purpose.MOLLT, 0);
      if (p !is null)
         p.csInstruction("linewidth", 0, "", 0, lt);
   }

   void setTextParams(int alignment, string fontName)
   {
      PseudoWidget p = pseudo(Purpose.TEXTPARAMS, 0);
      if (p !is null)
         p.csInstruction("setup", 0, fontName, alignment, 0.0);
   }

   void enable() {}
   void disable() {}

   void enable(Purpose p, int id)
   {
      PseudoWidget* pw = (PseudoKey(p, id) in pseudos);
      if (pw !is null)
         pw.enable();
   }

   void disable(Purpose p, int id)
   {
      PseudoWidget* pw = (PseudoKey(p, id) in pseudos);
      if (pw !is null)
         pw.disable();
   }

   void enable(int wid)
   {
      if (windex[wid] == -1)
         return;
      Widget w = wia[windex[wid]].widget;
      w.setSensitive(1);
   }

   void disable(int wid)
   {
      if (windex[wid] == -1)
         return;
      Widget w = wia[windex[wid]].widget;
      w.setSensitive(0);
   }

   void setToggle(int wid, bool bv)
   {
      if (windex[wid] == -1)
         return;
      Widget w = wia[windex[wid]].widget;
      int b = bv? 1: 0;
      (cast(ToggleButton) w).setActive(b);
   }

   void setSpinButton(int wid, double v)
   {
      if (windex[wid] == -1)
         return;
      Widget w = wia[windex[wid]].widget;
      (cast(SpinButton) w).setValue(v);
   }

   void setComboIndex(int wid, int i)
   {
      if (windex[wid] == -1)
         return;
      Widget w = wia[windex[wid]].widget;
      (cast(ComboBox) w).setActive(i);
   }

   void setLabel(int wid, string text)
   {
      if (windex[wid] == -1)
         return;
      Widget w = wia[windex[wid]].widget;
      TypeInfo_Class ti = w.classinfo;
      if (ti.name == "gtk.Button.Button")
      {
         Button b = cast(Button) w;
         b.setLabel(text);
      }
      else if (ti.name == "gtk.Label.Label")
      {
         Label l = cast(Label) w;
         l.setText(text);
      }
   }

   void realize(Layout layout)
   {
      foreach (WidgetInfo wi; wia)
      {
         layout.put(wi.widget, pos.x+wi.wpos.x, pos.y+wi.wpos.y);
         wi.widget.show();
      }
      /*
      foreach (ControlSet cs; groups)
      {
         cs.pos = pos;
         cs.realize(layout);
      }
      */
   }

   void setPosition(ICoord newPos)
   {
      pos = newPos;
   }

   void reposition(ICoord newPos, Layout layout)
   {
      pos = newPos;
      foreach (WidgetInfo wi; wia)
      {
         layout.move(wi.widget, pos.x+wi.wpos.x, pos.y+wi.wpos.y);
      }
   }

   void unRealize(Layout layout)
   {
      foreach (WidgetInfo wi; wia)
      {
         wi.widget.doref();
         layout.remove(wi.widget);
      }
   }

   void toggling(bool state)
   {
      noToggle = !state;
   }
/*************************************************************
  Individual widgets send raw data - the widget and the event
  to the host
**************************************************************/
   bool bClick(Event e, Widget w)
   {
      GdkModifierType state;
      e.getState(state);
      control = (state & GdkModifierType.CONTROL_MASK)? true: false;
      shift = (state & GdkModifierType.SHIFT_MASK)? true: false;
      Purpose id = cast(Purpose) w.getData("wid");
      host.onCSNotify(w, id);
      return true;
   }

   void rbClick(ToggleButton b)
   {
      if (noToggle)
         return;
      Purpose id = cast(Purpose) b.getData("wid");
      host.onCSNotify(b, id);
   }

   void cbClick(ToggleButton b)
   {
      if (noToggle)
         return;
      Purpose id = cast(Purpose) b.getData("wid");
      host.onCSNotify(b, id);
   }

   void sbChange(SpinButton b)
   {
      Purpose id = cast(Purpose) b.getData("wid");
      host.onCSNotify(b, id);
   }

   void comboChange(ComboBox cb)
   {
      Purpose id = cast(Purpose) cb.getData("wid");
      host.onCSNotify(cb, id);
   }

   void getModifiers(out bool controlState, out bool shiftState)
   {
      controlState = control;
      shiftState = shift;
      control = shift = false;
   }
}

class PseudoWidget
{
   ControlSet cs;
   CSTarget target;
   Purpose purpose;
   ICoord pos;
   int cx, cy, thisId;

   this(ControlSet cset, int instance, ICoord p)
   {
      cs = cset;
      target = cset.host;
      thisId = instance;
      pos = p;
      cx= pos.x;
      cy = pos.y;
   }

   void csInstruction(string name, int type, string sval, int ival, double dval) {}
   void enable() {}
   void disable() {}
}

class LineParams: MOLLineThick
{
   ICoord selection;
   bool initState, withLineCap;

   this(ControlSet cs, ICoord position, bool initialState, bool withLes, bool sharp = true)
   {
      ICoord ic = ICoord(position.x+170, position.y+5);
      super(cs, 0, ic);
      withLineCap = withLes;
      cs.addPseudo(this, Purpose.LINEPARAMS, 0);  // Only 1 instance of this
      initState = initialState;
      cx = 0;

      Button b = new Button("_Color");
      // add with no handler
      cs.add(b, ICoord(cx, cy-5), Purpose.COLOR, initState);

      Label l = new Label("Line Thickness:");
      cs.add(l, ICoord(cx+60, cy), Purpose.LABEL, initState);

      cy += 24;
      if (withLineCap)
      {
         RadioButton rb1 = new RadioButton("Line ends round", true);
         RadioButton rb2 = new RadioButton(rb1, "Line ends sharp", true);
         if (sharp)
            rb2.setActive(1);
         else
            rb1.setActive(1);
         // No handlers
         cs.add(rb1, ICoord(cx, cy), Purpose.LESROUND, initState);
         cs.add(rb2, ICoord(cx, cy+20), Purpose.LESSHARP, initState);
         cy += 40;
      }
      cs.cy = cy;
   }

}

class TextParams: PseudoWidget
{
   bool enabled, withAlign, withStyle;
   FontButton fontB;
   string font;
   int alignment;
   Button colorB;
   DrawingArea alignTool;
   Box sContainer;
   EventBox eb1, eb2, eb3;
   Label lBold, lItalic, lNormal;

   this(ControlSet cs, ICoord position, bool initialState, bool hasAlign, bool hasStyle)
   {
      super(cs, 0, position);
      cs.addPseudo(this, Purpose.TEXTPARAMS, 0);
      enabled = initialState;
      withAlign = hasAlign;
      withStyle = hasStyle;

      colorB = new Button("_Color");
      // No handler
      cs.add(colorB, ICoord(cx, cy), Purpose.COLOR, enabled);
      cx += 50;

      if (withAlign)
      {
         alignTool = new DrawingArea(57, 12);
         alignTool.addOnDraw(&onDraw);
         alignTool.addOnButtonPress(&mouseButtonPress);

         // The DrawingArea is an implementation artefact - it has
         // handlers, only its coordinates are used
         cs.add(alignTool, ICoord(cx, cy+5), Purpose.ALIGNMENT, enabled, true);
         cx += 62;
      }
      if (withStyle)
      {
         sContainer = setupStyles();
         // The contaning Box is an implementation artefact - it has
         // handlers, only its coordinates are used
         cs.add(sContainer, ICoord(cx, cy), Purpose.TEXTSTYLES, enabled, true);
         cx += 65;
      }

      fontB = new FontButton();
      fontB.setShowStyle(0);
      fontB.addOnFontSet(&onFontSet);
      fontB.addOnClicked(&onFBClicked);
      // Has a handler
      cs.add(fontB, ICoord(cx, cy), Purpose.FONT, true, true);
      cs.cy = 30;
   }

   void enable()
   {
      enabled = false;
      alignTool.queueDraw();
      fontB.setSensitive(0);
      colorB.setSensitive(0);
      eb1.setSensitive(0);
      eb2.setSensitive(0);
      eb2.setSensitive(0);
      lBold.setMarkup("<span foreground=\"#aaaaaa\" font=\"Sans bold 14\">A</span>");
      lItalic.setMarkup("<span foreground=\"#aaaaaa\" font=\"Sans italic 14\">A</span>");
      lNormal.setMarkup("<span foreground=\"#aaaaaa\" font=\"Sans 14\">A</span>");
   }

    void disable()
   {
      enabled = true;
      alignTool.queueDraw();
      fontB.setSensitive(1);
      colorB.setSensitive(1);
      eb1.setSensitive(1);
      eb2.setSensitive(1);
      eb2.setSensitive(1);
      lBold.setMarkup("<span font=\"Sans bold 14\">A</span>");
      lItalic.setMarkup("<span font=\"Sans italic 14\">A</span>");
      lNormal.setMarkup("<span font=\"Sans 14\">A</span>");
   }

   void csInstruction(string name, int type, string sval, int ival, double dval)
   {
      if (name != "setup")
         return;
      alignment = ival;
      font = sval;
      fontB.setFontName(sval);
      if (alignTool is null)
         return;
      alignTool.queueDraw();
   }
/*
   void setUp(int a, string f)
   {
      alignment = a;
      font = f;
      fontB.setFontName(f);
      if (alignTool is null)
         return;
      alignTool.queueDraw();
   }
*/
   Box setupStyles()
   {
      Box b = new Box(GtkOrientation.HORIZONTAL, 0);
      b.setSizeRequest(60, 20);

      // Labels are not clickable, so we wrap them in an EventBox.
      eb1 = new EventBox();
      eb1.setSizeRequest(20, 20);
      eb1.addOnButtonPress(&onChooseStyle);
      lBold = new Label("");
      // Set some Pango markup text for the label - bold A
      lBold.setMarkup("<span font=\"Sans bold 14\">A</span>");
      eb1.add(lBold);
      b.packStart(eb1, 1, 1, 0);

      eb2 = new EventBox();
      eb2.setSizeRequest(20, 20);
      eb2.addOnButtonPress(&onChooseStyle);
      lItalic = new Label("");
      // Italic A
      lItalic.setMarkup("<span font=\"Sans italic 14\">A</span>");
      eb2.add(lItalic);
      b.packStart(eb2, 1, 1, 0);

      eb3 = new EventBox();
      eb3.setSizeRequest(20, 20);
      eb3.addOnButtonPress(&onChooseStyle);
      lNormal = new Label("");
      // Normal A
      lNormal.setMarkup("<span font=\"Sans 14\">A</span>");
      eb3.add(lNormal);
      b.packStart(eb3, 1, 1, 0);
      b.showAll();

      return b;
   }

   void onFBClicked(Button b)
   {
      (cast(TextViewItem) target).onCSSaveSelection();
   }

   void onFontSet(FontButton b)
   {
      target.onCSTextParam(Purpose.FONT, b.getFontName, 0);
   }

   bool onChooseStyle(Event e, Widget w)
   {
      (cast(TextViewItem) target).onCSSaveSelection();
      if (w is eb1)
         target.onCSTextParam(Purpose.TEXTSTYLES, "bold", 0);
      else if (w is eb2)
         target.onCSTextParam(Purpose.TEXTSTYLES, "italic", 0);
      else
         target.onCSTextParam(Purpose.TEXTSTYLES, "normal", 0);
      return true;
   }

   bool onDraw(Context c, Widget w)
   {
      if (enabled)
      {
         c.save();
         if (alignment == 0)
         {
            c.rectangle(0,0,18,12);
         }
         else if (alignment == 1)
         {
            c.rectangle(21,0,18,12);
         }
         else
         {
            c.rectangle(41,0,18,12);
         }
         c.setSourceRgb(0.8,0.8,0.8);
         c.fill();
         c.restore();
      }
      c.setSourceRgb(0.5, 0.5, 0.5);
      c.moveTo(2, 2);
      c.lineTo(17, 2);
      c.moveTo(2, 5);
      c.lineTo(12, 5);
      c.moveTo(2, 8);
      c.lineTo(17, 8);
      c.moveTo(2, 11);
      c.lineTo(12, 11);
      c.stroke();

      c.moveTo(22, 2);
      c.lineTo(37, 2);
      c.moveTo(24, 5);
      c.lineTo(35, 5);
      c.moveTo(22, 8);
      c.lineTo(37, 8);
      c.moveTo(24, 11);
      c.lineTo(35, 11);
      c.stroke();

      c.moveTo(42, 2);
      c.lineTo(57, 2);
      c.moveTo(47, 5);
      c.lineTo(57, 5);
      c.moveTo(42, 8);
      c.lineTo(57, 8);
      c.moveTo(47, 11);
      c.lineTo(57, 11);
      c.stroke();

      return true;
   }

   bool mouseButtonPress(Event e, Widget w)
   {
      if (!enabled)
         return true;
      double x = e.button.x;
      int which;
      if (x < 18)
         which = 0;
      else if (x > 18 && x < 38)
         which = 1;
      else
         which = 2;
      if (alignment == which)
         return true;  // No change
      alignTool.queueDraw();
      alignment = which;
      target.onCSTextParam(Purpose.ALIGNMENT, "", alignment);
      return true;
   }
}

class InchTool: PseudoWidget
{
   bool initState;
   Label display;
   DrawingArea da;
   int tstate;
   Timeout t;
   int direction;
   uint interval;
   uint sensitive;
   bool coarse;

   this(ControlSet cset, int id, ICoord position, bool initialState = true)
   {
      super(cset, id, position);
      cs.addPseudo(this, Purpose.INCH, id);
      sensitive = initialState;

      da = new DrawingArea(34, 34);
      da.addOnDraw(&drawIt);
      da.addOnButtonPress(&onBD);
      da.addOnButtonRelease(&onBR);
      cs.add(da, ICoord(cx, cy), Purpose.INCH, initialState, true);

      display = new Label("");
      cs.add(display, ICoord(cx+40, cy+8), Purpose.DISPLAY);
   }

   void csInstruction(string name, int type, string sval, int ival, double dval)
   {
      if (name == "display")
         display.setText(sval);
   }

   void setDisplay(string s)
   {
      display.setText(s);
   }

   bool drawIt(Context c, Widget w)
   {
      if (sensitive)
         c.setSourceRgb(0.35, 0.35, 0.35);
      else
         c.setSourceRgb(0.7, 0.7, 0.7);
      c.moveTo(2, 17);
      c.lineTo(12, 12);
      c.lineTo(12, 22);
      c.closePath();
      c.fill();

      c.moveTo(12, 12);
      c.lineTo(17, 2);
      c.lineTo(22, 12);
      c.closePath();
      c.fill();

      c.moveTo(22, 12);
      c.lineTo(32, 17);
      c.lineTo(22, 22);
      c.closePath();
      c.fill();

      c.moveTo(22, 22);
      c.lineTo(17, 32);
      c.lineTo(12, 22);
      c.closePath();
      c.fill();
      return true;
   }

   void enable()
   {
      sensitive = true;
      da.queueDraw();
   }

   void disable()
   {
      sensitive = false;
      da.queueDraw();
   }

   bool onBD(Event e, Widget w)
   {
      if (!(e.type == GdkEventType.BUTTON_PRESS  &&  e.button.button == 1))
         return false;
      if (!sensitive)
         return true;
      double x = e.button.x;
      double y = e.button.y;
      GdkModifierType state;
      e.getState(state);
      coarse = (state & GdkModifierType.SHIFT_MASK)? true: false;
      interval = coarse? 100: 50;
      if (x < 12 && y > 12 && y < 22)  // left
      {
         direction = 0;
      }
      else if (x > 12 &&  x < 22 && y < 12)  // up
      {
         direction = 1;
      }
      else if (x > 22 && y > 12 && y < 22)  // right
      {
         direction = 2;
      }
      else if (x > 12 &&  x < 22 && y > 22)  // down
      {
         direction = 3;
      }

      tstate = 0;
      doMove();
      return true;
   }

   bool onBR(Event e, Widget w)
   {
      if (!sensitive)
         return true;
      if (e.type == GdkEventType.BUTTON_RELEASE  &&  e.button.button == 1)
      {
         t.stop();
         t = null;
         return true;
      }
      return false;
   }

   bool doMove()
   {
      if (tstate == 0)
      {
         t = new Timeout(200, &doMove, false);
         tstate = 1;
      }
      else if (tstate == 1)
      {
         t.stop();
         t = new Timeout(interval, &doMove, false);
         tstate = 2;
      }
      setDisplay(target.onCSInch(thisId, direction, coarse));
      return true;
   }
}

class Compass: PseudoWidget
{
   DrawingArea da;
   int tstate;
   Timeout t;
   double angle;
   uint interval;
   uint sensitive;
   bool initState, coarse, alt, ctrl;
   double pointerX, pointerY;

   this(ControlSet cset, int id, ICoord position, bool initialState = true)
   {
      super(cset, id, position);
      cs.addPseudo(this, Purpose.COMPASS, id);
      sensitive = initialState;

      da = new DrawingArea(52, 52);
      da.addOnDraw(&drawIt);
      da.addOnButtonPress(&onBD);
      da.addOnButtonRelease(&onBR);
      da.addOnMotionNotify(&mouseMove);
      cs.add(da, ICoord(cx, cy), Purpose.COMPASS, initialState, true);
      pointerX = 50;
      pointerY = 26;
   }
/*
   void csInstruction(string name, int type, string sval, int ival, double dval)
   {
      if (name == "display")
         display.setText(sval);
   }

   void setDisplay(string s)
   {
      display.setText(s);
   }
*/
   bool drawIt(Context c, Widget w)
   {
      if (sensitive)
         c.setSourceRgb(0.35, 0.35, 0.35);
      else
         c.setSourceRgb(0.7, 0.7, 0.7);
      c.arc(26, 26, 25, 0, PI*2);
      c.stroke();
      c.moveTo(22, 12);
      c.showText("N");
      c.moveTo(42, 30);
      c.showText("E");
      c.moveTo(22, 48);
      c.showText("S");
      c.moveTo(3, 30);
      c.showText("W");
      if (sensitive)
      {
         c.setSourceRgb(0.7, 0.3, 0.3);
         c.moveTo(26, 26);
         c.lineTo(pointerX, pointerY);
         c.stroke();
      }
      return true;
   }

   void enable()
   {
      sensitive = true;
      da.queueDraw();
   }

   void disable()
   {
      sensitive = false;
      da.queueDraw();
   }

   bool mouseMove(Event e, Widget w)
   {
      double x = e.motion.x, y = e.motion.y;
      angle = atan2(-(y-26), x-26);
      pointerX = 26+25*cos(-angle);
      pointerY = 26+25*sin(-angle);
      da.queueDraw();
      return true;
   }

   bool onBD(Event e, Widget w)
   {
      if (!(e.type == GdkEventType.BUTTON_PRESS))
         return false;
      if (!sensitive)
         return true;
      bool ortho = false;
      if (e.button.button != 1)
         ortho = true;
      double x = e.button.x;
      double y = e.button.y;
      GdkModifierType state;
      e.getState(state);
      coarse = (state & GdkModifierType.SHIFT_MASK)? true: false;
      ctrl = (state & GdkModifierType.CONTROL_MASK)? true: false;
      interval = coarse? 100: 50;
      // Think about NaN payload for implementing this
      if (ctrl && ortho)         // Interpret as move up or down
         angle = (y < 26)? PI/2: -PI/2;
      else if (ortho)            // Interpret as left/right
         angle = (x < 26)? PI: 0;
      else
         angle = atan2(-(y-26), x-26);
      tstate = 0;
      doMove();
      return true;
   }

   bool onBR(Event e, Widget w)
   {
      if (!sensitive)
         return true;
      if (e.type == GdkEventType.BUTTON_RELEASE)
      {
         t.stop();
         t = null;
         return true;
      }
      return false;
   }

   bool doMove()
   {
      if (tstate == 0)
      {
         t = new Timeout(200, &doMove, false);
         tstate = 1;
      }
      else if (tstate == 1)
      {
         t.stop();
         t = new Timeout(interval, &doMove, false);
         tstate = 2;
      }
      target.onCSCompass(thisId, angle, coarse);
      return true;
   }
}

class MoreLess: PseudoWidget
{
   DrawingArea da;
   Timeout t;
   int tstate;
   bool more;
   uint interval, longInterval, shortInterval;
   int size;
   int unit;
   bool coarse;
   bool sensitive;

   this(ControlSet cs, int id, ICoord position, bool initialState = true)
   {
      super(cs, id, position);
      cs.addPseudo(this, Purpose.MOL, id);
      pos = cs.pos;
      cx = position.x;
      cy = position.y;
      thisId = id;
      sensitive = initialState;
      longInterval = 100;
      shortInterval = 50;

      da= new DrawingArea(32, 18);
      da.addOnDraw(&drawIt);
      da.addOnButtonPress(&onBD);
      da.addOnButtonRelease(&onBR);
      cs.add(da, ICoord(cx, cy), Purpose.MOL, initialState, true);

   }

   void setIntervals(int li, int si)
   {
      longInterval = li;
      shortInterval = si;
   }

   bool drawIt(Context c, Widget w)
   {
      if (sensitive)
         c.setSourceRgb(0.35, 0.35, 0.35);
      else
         c.setSourceRgb(0.7, 0.7, 0.7);
      c.moveTo(4, 9);
      c.lineTo(14, 4);
      c.lineTo(14, 14);
      c.closePath();
      c.fill();

      c.moveTo(18, 4);
      c.lineTo(28, 9);
      c.lineTo(18, 14);
      c.closePath();
      c.fill();
      return true;
   }

   void enable()
   {
      sensitive= true;
      da.queueDraw();
   }

   void disable()
   {
      sensitive = false;
      da.queueDraw();
   }

   bool onBD(Event e, Widget w)
   {
      if (!(e.type == GdkEventType.BUTTON_PRESS  &&  e.button.button == 1))
         return false;
      if (!sensitive)
         return true;
      double x = e.button.x;
      double y = e.button.y;
      GdkModifierType state;
      e.getState(state);
      coarse = (state & GdkModifierType.SHIFT_MASK)? true: false;
      interval = coarse? longInterval: shortInterval;
      more = (x >= 16);

      tstate = 0;
      doMove();
      return true;
   }

   bool onBR(Event e, Widget w)
   {
      if (e.type == GdkEventType.BUTTON_RELEASE  &&  e.button.button == 1)
      {
         if (tstate && (t  !is null))
         {
            t.stop();
            t = null;
         }
         return true;
      }
      return false;
   }

   bool doMove()
   {
      if (tstate == 0)
      {
         t = new Timeout(200, &doMove, false);
         tstate = 1;
      }
      else if (tstate == 1)
      {
         t.stop();
         t = new Timeout(interval, &doMove, false);
         tstate = 2;
      }
      target.onCSMoreLess(thisId, more, coarse);
      return true;
   }
}

class MOLLineThick: PseudoWidget
{
   DrawingArea da;
   Label txt;
   Timeout t;
   double current = 0.5;
   double lt;
   int tstate;
   int direction;
   uint interval;
   int size;
   bool far;
   bool sensitive;

   this(ControlSet cs, int id, ICoord position, bool initialState = true)
   {
      super(cs, id, position);
      cs.addPseudo(this, Purpose.MOLLT, id);
      thisId = id;
      sensitive = initialState;

      da= new DrawingArea(32, 18);
      da.addOnDraw(&drawIt);
      da.addOnButtonPress(&onBD);
      da.addOnButtonRelease(&onBR);
      cs.add(da, ICoord(cx, cy), Purpose.MOL, initialState, true);

      txt = new Label("0.5");
      cs.add(txt, ICoord(cx+40, cy), Purpose.LINEWIDTH, initialState, true);
   }

   void csInstruction(string name, int type, string sval, int ival, double dval)
   {
      if (name == "linewidth")
      {
         lt = dval;
         scope auto w = appender!string();
         formattedWrite(w, "%1.1f", lt);
         txt.setText(w.data);
      }
   }

   bool drawIt(Context c, Widget w)
   {
      if (sensitive)
         c.setSourceRgb(0.35, 0.35, 0.35);
      else
         c.setSourceRgb(0.7, 0.7, 0.7);
      c.moveTo(4, 9);
      c.lineTo(14, 4);
      c.lineTo(14, 14);
      c.closePath();
      c.fill();

      c.moveTo(18, 4);
      c.lineTo(28, 9);
      c.lineTo(18, 14);
      c.closePath();
      c.fill();
      return true;
   }

   void enable()
   {
      sensitive= true;
      da.queueDraw();
   }

   void disable()
   {
      sensitive = false;
      da.queueDraw();
   }

   bool onBD(Event e, Widget w)
   {
      if (!(e.type == GdkEventType.BUTTON_PRESS  &&  e.button.button == 1))
         return false;
      if (!sensitive)
         return true;
      double x = e.button.x;
      double y = e.button.y;
      GdkModifierType state;
      e.getState(state);
      far = (state & GdkModifierType.SHIFT_MASK)? true: false;
      interval = far? 100: 50;
      if (x < 16)
         direction = -1;
      else
         direction = 1;

      tstate = 0;
      doMove();
      return true;
   }

   bool onBR(Event e, Widget w)
   {
      if (e.type == GdkEventType.BUTTON_RELEASE  &&  e.button.button == 1)
      {
         if (tstate && (t  !is null))
         {
            t.stop();
            t = null;
         }
         return true;
      }
      return false;
   }

   bool doMove()
   {
      if (tstate == 0)
      {
         t = new Timeout(200, &doMove, false);
         tstate = 1;
      }
      else if (tstate == 1)
      {
         t.stop();
         t = new Timeout(interval, &doMove, false);
         tstate = 2;
      }
      if (direction > 0)
      {
         if (lt < 2)
            lt += 0.1;
         else
            lt += 0.5;
      }
      else
      {
         if (lt > 2)
         {
            if (lt-0.5 < 2)
               lt = 2;
            else lt -= 0.5;
         }
         else
         {
            if (lt-0.1 < 0)
               lt = 0;
            else
               lt -= 0.1;
         }
      }
      scope auto w = appender!string();
      formattedWrite(w, "%1.1f", lt);
      txt.setText(w.data);
      target.onCSLineWidth(lt);
      return true;
   }
}


class TextOrient: PseudoWidget
{
   DrawingArea da;
   int orient;
   bool sensitive;

   this(ControlSet cs, int id, ICoord position, bool initialState = false)
   {
      super(cs, id, position);
      cs.addPseudo(this, Purpose.TORIENT, id);
      pos = cs.pos;
      cx = position.x;
      cy = position.y;
      sensitive = initialState;

      da= new DrawingArea(40, 40);
      da.addOnDraw(&drawIt);
      da.addOnButtonPress(&onBD);
      cs.add(da, ICoord(cx, cy), Purpose.MOL, initialState, true);
   }

   bool drawIt(Context c, Widget w)
   {
      if (sensitive)
         c.setSourceRgb(0.35, 0.35, 0.35);
      else
         c.setSourceRgb(0.7, 0.7, 0.7);
      c.moveTo(5, 35);
      c.lineTo(5, 39);
      c.lineTo(35, 39);

      c.moveTo(35, 35);
      c.lineTo(39, 35);
      c.lineTo(39, 5);

      c.moveTo(35, 5);
      c.lineTo(35, 1);
      c.lineTo(5, 1);

      c.moveTo(5, 5);
      c.lineTo(1, 5);
      c.lineTo(1, 35);

      c.moveTo(7, 31);
      c.lineTo(10, 34);
      c.lineTo(32, 7);

      c.stroke();

      return true;
   }

   void enable()
   {
      sensitive= true;
      da.queueDraw();
   }

   void disable()
   {
      sensitive = false;
      da.queueDraw();
   }

   bool onBD(Event e, Widget w)
   {
      if (!(e.type == GdkEventType.BUTTON_PRESS  &&  e.button.button == 1))
         return false;
      if (!sensitive)
         return true;
      double x = e.button.x;
      double y = e.button.y;
      GdkModifierType state;
      int which;
      if (x < 5 && y > 5 && y < 35)
         which = 3;
      else if (x > 5 && x < 35 && y < 5)
         which = 2;
      else if (x > 35 && y > 5 && y < 35)
         which = 1;
      else if (x > 5 && x < 35 && y > 35)
         which = 0;
      else
         which = 4;
      if (orient == which)
         return true;
      orient = which;
      target.onCSTextParam(Purpose.TORIENT, "", orient);
      return true;
   }
}

class RenameGadget: PseudoWidget
{
   Entry entry;
   Button ok;
   bool initState;

   this(ControlSet cs, ICoord position, string origName, bool initialState = true)
   {
      super(cs, 0, position);
      cs.addPseudo(this, Purpose.RENAME, 0);
      initState = initialState? 1: 0;

      Label nnl = new Label("Name");
      cs.add(nnl, ICoord(cx, cy+3), Purpose.LABEL, initState);
      entry = new Entry();
      entry.setSizeRequest(150, -1);
      entry.setText(origName);
      entry.setTooltipText("Choose a name for this item/layer.\nPress enter to set it.");
      entry.addOnActivate(&onSetName);
      cs.host.setNameEntry(entry);
      cs.add(entry, ICoord(cx+45, cy), Purpose.NAMEENTRY, initState);
   }

   void enable()
   {
      ok.setSensitive(true);
   }

   void disable()
   {
      ok.setSensitive(false);
   }

   void csInstruction(string name, int type, string sval, int ival, double dval)
   {
      if (name == "hostname")
         entry.setText(sval);
   }

   void setName(string s)
   {
      entry.setText(s);
   }

   void focus()
   {
      entry.grabFocus();
   }

   void onSetName(Entry e)
   {
      string s = e.getText();
      target.onCSNameChange(s);
   }
}

