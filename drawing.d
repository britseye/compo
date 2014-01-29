
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module drawing;

import mainwin;
import constants;
import acomp;
import common;
import types;
import controlset;
import lineset;

import std.stdio;
import std.math;
import std.conv;
import std.zlib;
import std.net.curl;

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

struct PartHeader
{
   uint total;
   ubyte type;
   ubyte flags;
   ushort items;
   string name;
   Transform transform;
   Coord position;
   Coord center;
   PartColor baseColor;
   PartColor altColor;
   double lwf;
}

class Drawing : LineSet
{
    static int nextOid = 0;
    Part[] spec;
    ubyte[] data;
    ubyte*[] pspa;
    PartHeader[] pha;
    int nParts;
    string dName;
    bool good;
    cairo_matrix_t ptmData;
    Matrix ptm;

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
        pca.length = nParts;
        foreach (int k, PartHeader ph; pha)
        {
            if (pha[k].flags & 4)
                pca[k] = pha[k].altColor;
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
        pca = other.pca.dup;
        spec = other.spec;
        center = spec[0].center;
        xform = other.xform;
        tf = other.tf;
        dirty = true;
        syncControls();
    }

    this(AppWindow w, ACBase parent, string drawingName)
    {
        dName = drawingName;
        string s = dName~" "~to!string(++nextOid);
        super(w, parent, s, AC_DRAWING);
        group = ACGroups.DRAWING;
        //spec = aw.shapeLib.getEntry(dName);
        afterDeserialize();
        center = pha[0].center;
        lineWidth = 1;
        les = true;
        fill = solid = false;

        tm = new Matrix(&tmData);

        //xlatePath();
        setupFillColors();
        setupControls(3);
        positionControls(true);
    }

    this(AppWindow w, ACBase parent, ubyte[] uuba)
    {
        dName = "Unknown";
        string s = dName~" "~to!string(++nextOid);
        super(w, parent, s, AC_DRAWING);
        group = ACGroups.DRAWING;
        center = Coord(0.5*width, 0.5*height);
        //spec = aw.shapeLib.getEntry(dName);
        data = uuba.dup;
        ubyte* dp = data.ptr;
        good = scanData(dp);
        good = true;
        lineWidth = 1;
        les = true;
        fill = solid = false;

        tm = new Matrix(&tmData);
        ptm = new Matrix(&ptmData);
        //xlatePath();
        setupFillColors();
        setupControls(3);
        positionControls(true);
    }

   uint readPartHeader(ref ubyte* p)
   {
      PartHeader ph;
      uint* uip = cast(uint*) p;
      ph.total =*uip;
      p += uint.sizeof;
      ph.type = *p++;
      ph.flags = *p++;
      ushort* usp = cast(ushort*) p;
      ph.items = *usp;
      p += ushort.sizeof;
      ubyte[32] uba;
      uba[] = p[0..32];
      p += 32;
      uint len = uba[0];
      ph.name = cast(string) uba[1..len+1].idup;

      // Transform
      double* dp = cast(double*) p;
      ph.transform.hScale = *dp++;
      ph.transform.vScale = *dp++;
      ph.transform.hSkew = *dp++;
      ph.transform.vSkew = *dp;
      p += 4*double.sizeof;
      ubyte ub = *p++;
      if (ub & 1)
         ph.transform.hFlip = true;
      if (ub & 2)
         ph.transform.vFlip = true;
      dp = cast(double*) p;
      ph.transform.ra = *dp;
      p += double.sizeof;

      // Mass of doubles!
      dp = cast(double*) p;
      ph.position.x = *dp++;
      ph.position.y = *dp++;
      ph.center.x = *dp++;
      ph.center.y = *dp++;
      ph.baseColor.r = *dp++;
      ph.baseColor.g = *dp++;
      ph.baseColor.b = *dp++;
      ph.baseColor.a = *dp++;
      ph.altColor.r = *dp++;
      ph.altColor.g = *dp++;
      ph.altColor.b = *dp++;
      ph.altColor.a = *dp++;
      ph.lwf = *dp++;
      p += 13*double.sizeof;
/*
writefln("part bytes %d", ph.total);
writefln("type %d", ph.type);
writefln("flags %d", ph.flags);
writefln("items %d", ph.items);
writeln(ph.name);
writefln("transform %f, %f %f, %f %s %s %f", ph.transform.hScale, ph.transform.vScale, ph.transform.hSkew, ph.transform.vSkew,
                                             ph.transform.hFlip, ph.transform.vFlip, ph.transform.ra);
writefln("position %f %f", ph.position.x, ph.position.y);
writefln("center %f %f", ph.center.x, ph.center.y);
writefln("baseColor %f %f %f %f", ph.baseColor.r, ph.baseColor.g, ph.baseColor.b, ph.baseColor.a);
writefln("altColor %f %f %f %f", ph.altColor.r, ph.altColor.g, ph.altColor.b, ph.altColor.a);
writefln("lw %f", ph.lwf);
*/
      pha ~= ph;
      return ph.total;
   }

   bool scanData(ubyte* dp)
   {
      ushort* usp = cast(ushort*) dp;
      nParts = *usp;
      pspa.length = nParts;
      dp += ushort.sizeof;
      for (int i = 0; i < nParts; i++)
      {
         ubyte* sp = dp;
         uint total = readPartHeader(dp);
         pspa[i] = dp;
         dp = sp+total;
         usp = cast(ushort*) dp;
//writefln("parts %d sentinel %04x", nParts, *usp);
         dp += 2;
      }
      return true;
   }

   override void afterDeserialize()
   {
      bool gotit = false;
      ubyte[] raw;
      try
      {
        raw = get!(AutoProtocol, ubyte)("bev/"~dName~".zlib");
        gotit = true;
      }
      catch (Exception e)
      {
        aw.popupMsg("COMPO tried to get the drawing "~dName~" \nfrom the server, but that failed.\nThe errormesage was:\n"~e.msg, MessageType.ERROR);
        return;
      }
      if (gotit)
      {
         data = cast(ubyte[]) uncompress(raw);
         ubyte* dp = data.ptr;
         scanData(dp);
         good = true;
      }
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
      foreach (PartHeader ph; pha)
      {
         cicb.appendText(ph.name.idup);
      }
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

   override bool specificNotify(Widget w, Purpose p)
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

   bool compoundPartTransform(Transform tf)
   {
      Matrix tmp;
      cairo_matrix_t tmpData;
      tmp = new Matrix(&tmpData);
      ptm.initIdentity();
      bool any = false;
      if (tf.hScale != 1 || tf.vScale != 1)
      {
         any = true;
         tmp.initScale(tf.hScale, tf.vScale);
         ptm.multiply(ptm, tmp);
      }
      if (tf.hSkew != 0)
      {
         any = true;
         tmp.init(1.0, 0.0, -tf.hSkew, 1.0, 0.0, 0.0);
         ptm.multiply(ptm, tmp);
      }
      if (tf.vSkew != 0)
      {
         any = true;
         tmp.init(1.0, -tf.vSkew, 0.0, 1.0, 0.0, 0.0);
         ptm.multiply(ptm, tmp);
      }
      if (tf.ra != 0)
      {
         any = true;
         tmp.initRotate(tf.ra);
         ptm.multiply(ptm, tmp);
      }
      if (tf.hFlip)
      {
         any = true;
         tmp.init(-1.0, 0.0, 0.0, 1.0, 0.0, 0.0);
         ptm.multiply(ptm, tmp);
      }
      if (tf.vFlip)
      {
         any = true;
         tmp.init(1.0, 0.0, 0.0, -1.0, 0.0, 0.0);
         ptm.multiply(ptm, tmp);
      }
      return any;
   }

   void strokeAndFillPart(Context c, PartHeader ph, int pn)
   {
      if (ph.flags & 2)
      {
         c.strokePreserve();
         c.setSourceRgba(ph.baseColor.r, ph.baseColor.g, ph.baseColor.b, 1.0);
         c.fill();
      }
      else if (ph.flags & 4)
      {
         c.strokePreserve();
         c.setSourceRgba(pca[pn].r, pca[pn].g, pca[pn].b, 1.0);
         c.fillPreserve();
         c.setSourceRgb(ph.baseColor.r, ph.baseColor.g, ph.baseColor.b);
         c.setLineWidth(ph.lwf*lineWidth);
         c.stroke();
      }
      else
      {
         c.setSourceRgba(ph.baseColor.r, ph.baseColor.g, ph.baseColor.b, 1.0);
         c.setLineWidth(ph.lwf*lineWidth);
         c.stroke();
      }
   }

   override void render(Context c)
   {
      void renderPolygon(int items, ubyte* dp)
      {
         double* p = cast(double*) dp;
         double t = *p++;
         c.moveTo(t, *p);
         dp += 2*double.sizeof;

         for (int i = 1; i < items; i++)
         {
            p = cast(double*) dp;
            t = *p++;
            c.lineTo(t, *p);
            dp += 2*double.sizeof;
         }
      }

      void renderPointSet(int items, ubyte* dp, int n)
      {
         c.setSourceRgb(pca[n].r, pca[n].g, pca[n].b);
         c.setLineWidth(0);
         double r = pha[n].lwf*lineWidth;
         for (int i=0; i < items; i++)
         {
            double* p = cast(double*) dp;
            double t = *p++;
            c.arc(t, *p, r, 0, PI*2);
            c.strokePreserve();
            c.fill();
            dp += 2*double.sizeof;
         }
      }

      void renderPolycurve(int items, ubyte* dp)
      {
         items++;  // Allow for initial moveTo
         for (int i = 0; i < items; i++)
         {
            ubyte type = *dp++;
            double* p = cast(double*) dp;
            double t;
            if (type == 0)
            {
               t = *p++;
               c.moveTo(t, *p);
               dp += 2*double.sizeof;
            }
            else if (type == 1)
            {
               t = *p++;
               c.lineTo(t, *p);
               dp += 2*double.sizeof;
            }
            else
            {
               Coord cp1, cp2;
               cp1.x = *p++;
               cp1.y = *p++;
               cp2.x = *p++;
               cp2.y = *p++;
               double endx = *p++;
               c.curveTo(cp1.x, cp1.y, cp2.x, cp2.y, endx, *p);
               dp += 6*double.sizeof;
            }
         }
      }

      void renderRegPolycurve(int items, ubyte* dp)
      {
         double* p = cast(double*) dp;
         double t;
         t = *p++;
         c.moveTo(t, *p);
         dp += 2*double.sizeof;

         for (int i = 0; i < items; i++)
         {
            p = cast(double*) dp;
            Coord cp1, cp2, end;
            cp1.x = *p++;
            cp1.y = *p++;
            cp2.x = *p++;
            cp2.y = *p++;
            end.x = *p++;
            end.y = *p++;
            t = *p++;
            c.curveTo(cp1.x, cp1.y, cp2.x, cp2.y, end.x, end.y);
            dp += 6*double.sizeof;
         }
      }

      void renderStrokeSet(int items, ubyte* dp, int n)
      {
         c.setLineWidth(pha[n].lwf*lineWidth);
         for (int i = 0; i < items; i++)
         {
            ubyte type = *dp++;
            double x, y;
            double* p= cast(double*) dp;
            x = *p++;
            y = *p++;
            c.moveTo(x,y);
            if (type == 0)
            {
               x = *p++;
               c.lineTo(x, *p++);
               dp += 4*double.sizeof;
            }
            else
            {
               Coord cp1, cp2;
               double *t = p;
               cp1.x = *p++;
               cp1.y = *p++;
               cp2.x = *p++;
               cp2.y = *p++;
               x = *p++;
               y = *p++;
               c.curveTo(cp1.x, cp1.y, cp2.x, cp2.y, x, y);
               dp += 8*double.sizeof;
            }
            c.stroke();
         }
      }

      void renderCircle(Coord cp, ubyte* p)
      {
         c.newSubPath();
         double* dp = cast(double*) p;
         double r = *dp++;
         double x = *dp++;
         double y = *dp;
         c.arc(x, y, r, 0, PI*2);
      }

      void renderCrescent(Coord cp, ubyte* p)
      {
         c.newSubPath();
         double* dp = cast(double*) p;
         double d = *dp++;
         double r0 = *dp++;
         double r1 = *dp++;
         double a0 = *dp++;
         double a1 = *dp;
         if (d < 0)
         {
            c.arc(cp.x, cp.y, r0, a0+PI, -(a0+PI));
            c.arcNegative(cp.x+d, cp.y, r1, -(a1+PI), a1+PI);
         }
         else
         {
            c.arcNegative(cp.x, cp.y, r0, -a0, a0);
            c.arc(cp.x+d, cp.y, r1, a1, -a1);
         }
      }

      void renderMoon(Coord cp, ubyte* p)
      {
         c.newSubPath();
         byte* psb = cast(byte*) p++;
         int sequence = cast(int) *psb;
         double* dp = cast(double*) p;
         Coord c0;
         c0.x = *dp++;
         c0.y = *dp++;
         double r0 = *dp++;
         double sa0 = *dp++;
         double ea0 = *dp++;
         Coord c1;
         c1.x = *dp++;
         c1.y = *dp++;
         double r1 = *dp++;
         double sa1 = *dp++;
         double ea1 = *dp++;
         switch (sequence)
         {
            case moon.ARCARC:
               c.arc(c0.x, c0.y, r0, sa0, ea0);
               c.arc(c1.x, c1.y, r1, sa1, ea1);
               break;
            case moon.ARCARN:
               c.arc(c0.x, c0.y, r0, sa0, ea0);
               c.arcNegative(c1.x, c1.y, r1, sa1, ea1);
               break;
            case moon.ARNARC:
               c.arcNegative(c0.x, c0.y, r0, sa0, ea0);
               c.arc(c1.x, c1.y, r1, sa1, ea1);
               break;
            case moon.ARNARN:
               c.arcNegative(c0.x, c0.y, r0, sa0, ea0);
               c.arcNegative(c1.x, c1.y, r1, sa1, ea1);
               break;
            case moon.ARCNON:
               c.arc(c0.x, c0.y, r0, sa0, ea0);
               break;
            case moon.ARNNON:
               c.arcNegative(c0.x, c0.y, r0, sa0, ea0);
               break;
            default:
               break;
         }
      }

      void renderRectangle(ubyte* p)
      {
         ubyte rounded= *p++;
         double* dp = cast(double*) p;
         double rr = *dp++;
         Coord topLeft, bottomRight;
         topLeft.x = *dp++;
         topLeft.y = *dp++;
         bottomRight.x=*dp++;
         bottomRight.y = *dp++;
         if (rounded)
         {
            c.moveTo(topLeft.x, topLeft.y+rr);
            c.arc(topLeft.x+rr, topLeft.y+rr, rr, PI, (3*PI)/2);
            c.lineTo(bottomRight.x-rr, topLeft.y);
            c.arc(bottomRight.x-rr, topLeft.y+rr, rr, (3*PI)/2, 2*PI);
            c.lineTo(bottomRight.x, bottomRight.y-rr);
            c.arc(bottomRight.x-rr, bottomRight.y-rr, rr, 0, PI/2);
            c.lineTo(topLeft.x+rr, bottomRight.y);
            c.arc(topLeft.x+rr, bottomRight.y-rr, rr, PI/2, PI);
         }
         else
         {
            c.moveTo(topLeft.x, topLeft.y);
            c.lineTo(bottomRight.x, topLeft.y);
            c.lineTo(bottomRight.x, bottomRight.y);
            c.lineTo(topLeft.x, bottomRight.y);
         }
      }

      c.translate(hOff+center.x, vOff+center.y);
      if (compoundTransform())
         c.transform(tm);
      c.translate(-center.x, -center.y);

      c.setLineJoin(les? CairoLineJoin.MITER: CairoLineJoin.ROUND);
      for (int i = 0; i < nParts; i++)
      {
         ubyte* dp = pspa[i];
         int items = pha[i].items;

         c.save();

         c.translate(pha[i].position.x+pha[i].center.x, pha[i].position.y+pha[i].center.y);
         if (compoundPartTransform(pha[i].transform))
            c.transform(ptm);
         c.translate(-pha[i].center.x, -pha[i].center.y);

         //c.save();
         c.setLineWidth(pha[i].lwf*lineWidth);
         c.setSourceRgb(pha[i].baseColor.r, pha[i].baseColor.g, pha[i].baseColor.b);
         switch (pha[i].type)
         {
         case AC_ARROW:
         case AC_CROSS:
         case AC_LINE:
         case AC_POLYGON:
         case AC_REGPOLYGON:
         case AC_TRIANGLE:
             renderPolygon(items, dp);
             break;
         case AC_POINTSET:
             renderPointSet(items, dp, i);
             break;
         case AC_STROKESET:
             renderStrokeSet(items, dp, i);
             break;
         case AC_CIRCLE:
             renderCircle(pha[i].center, dp);
             break;
         case AC_CRESCENT:
             renderCrescent(pha[i].center, dp);
             break;
         case AC_HEART:
         case AC_POLYCURVE:
             renderPolycurve(items, dp);
             break;
         case AC_MOON:
             renderMoon(pha[i].center, dp);
             break;
         case AC_RECT:
            renderRectangle(dp);
            break;
         case AC_REGPOLYCURVE:
            renderRegPolycurve(items, dp);
            break;
         default:
            break;
         }
         if (pha[i].flags & 1)
            c.closePath();
         if (!(pha[i].type == AC_POINTSET || pha[i].type == AC_STROKESET))
            strokeAndFillPart(c, pha[i], i);
         c.restore();
      }
   }
}
