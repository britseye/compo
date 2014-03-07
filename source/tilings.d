
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module tilings;

import mainwin;
import constants;
import acomp;
import common;
import types;
import controlset;
import lineset;

import std.stdio;
import std.math;
import std.random;
import std.conv;
import std.algorithm;

import gtk.Widget;
import gtk.Label;
import gtk.Button;
import gtk.CheckButton;
import gtk.ComboBoxText;
import gdk.RGBA;
import cairo.Context;
import cairo.Matrix;
import gtkc.cairotypes;
import cairo.Surface;

struct TriCoords
{
   Coord A;
   Coord B;
   Coord C;
}

class Tilings: ACBase
{
   static int nextOid = 0;
   Coord center;
   int rows, cols;
   double rowInc, colInc;
   int pattern, shade;
   ColorSource cSrc;
   uint colorSeed, shapeSeed;
   Coord[][] points;
   PartColor[] colors;
   PartColor[] pca;
   bool printRandom, irregular;
   Random colorGen, shapeGen;

   override void syncControls()
   {
      cSet.toggling(false);
      cSet.setComboIndex(Purpose.PATTERN, pattern);
      cSet.setComboIndex(Purpose.DCOLORS, shade);
      if (printRandom)
         cSet.setToggle(Purpose.PRINTRANDOM, true);
      cSet.toggling(true);
      cSet.setHostName(name);
   }

   this(Tilings other)
   {
      this(other.aw, other.parent);
      hOff = other.hOff;
      vOff = other.vOff;
      baseColor = other.baseColor.copy();
      pca = other.pca.dup;
      rows = other.rows;
      cols = other.cols;
      rowInc= other.rowInc;
      colors.length = rows*(cols*2+1);
      colInc= other.colInc;
      points = other.points.dup;
      colorSeed = other.colorSeed;
      shapeSeed = other.shapeSeed;
      shapeGen.seed(shapeSeed);
      cSrc.init(baseColor, colorSeed);
      shade = other.shade;
      cSrc.setShadeBand(shade);
      setupColors();
      pattern = other.pattern;
      printRandom = other.printRandom;
      irregular = other.irregular;
      dirty = true;
      syncControls();
   }

   this(AppWindow w, ACBase parent, bool asCopy = false)
   {
      mixin(initString!Tilings());
      super(w, parent, sname, AC_TILINGS, ACGroups.EFFECTS, ahdg);

      rows = 9;
      cols = 10;
      if (!asCopy)
         colors.length = rows*(cols*2+1);
      baseColor = new RGBA(0,1,0,1);
      pca = [PartColor(0.333333,0.333333,0.333333,1), PartColor(0.466667,0.466667,0.466667,1),
             PartColor(0.6,0.6,0.6,1), PartColor(0.733333,0.733333,0.733333,1),
             PartColor(0.666667,0,0,1), PartColor(1,0.8,0.8,1),
             PartColor(1,0.866667,0.866667,1), PartColor(1,1,1,1)];
      shapeGen.seed(42);
      pattern = 1;
      shade = 9;
      if (!asCopy)
      {
         cSrc.init(baseColor, 42);
         setupColors();
      }
      irregular = true;
      dirty = true;

      setupControls();
      positionControls(true);
   }

   override void afterDeserialize()
   {
      cSrc.init(baseColor, colorSeed);
      cSrc.setShadeBand(shade);
      setupColors();
      dirty = true;
      reBuild();
   }

   override void extendControls()
   {
      int vp = cSet.cy;

      Button b = new Button("Color");
      cSet.add(b, ICoord(0, vp), Purpose.XCOLOR);
      b = new Button("Refresh Colors");
      cSet.add(b, ICoord(80, vp), Purpose.REFRESH);

      Label t = new Label("More/Less");
      cSet.add(t, ICoord(215, vp), Purpose.LABEL);
      new MoreLess(cSet, 0, ICoord(295, vp), true);

      ComboBoxText cb = new ComboBoxText(false);
      cb.appendText("Rectangles");
      cb.appendText("Triangles");
      cb.appendText("Circles");
      cb.setActive(1);
      cSet.add(cb, ICoord(215, vp+20), Purpose.PATTERN);

      vp += 30;
      new InchTool(cSet, 0, ICoord(0, vp), true);

      vp += 35;
      cb = new ComboBoxText(false);
      cb.appendText("Base Color Exact");
      cb.appendText("Base Color All");
      cb.appendText("Base Color Light");
      cb.appendText("Base Color Medium");
      cb.appendText("Base Color Dark");
      cb.appendText("Light Colors");
      cb.appendText("Medium Colors");
      cb.appendText("Dark Colors");
      cb.appendText("Random Colors");
      cb.appendText("Use Palette");
      cb.setActive(9);
      cSet.add(cb, ICoord(0, vp), Purpose.DCOLORS);

      b = new Button("Regenerate Shapes");
      cSet.add(b, ICoord(195, vp+3), Purpose.REDRAW);

      vp += 40;
      Palette p = new Palette(cSet, ICoord(5, vp), true);
      p.csInstruction("colors", 0, "", 0, 0, pca.ptr);

      vp += 40;
      CheckButton check = new CheckButton("Print random");
      cSet.add(check, ICoord(100, vp), Purpose.PRINTRANDOM);
      check = new CheckButton("Irregular tiles");
      check.setActive(1);
      cSet.add(check, ICoord(215, vp), Purpose.PIN);

      cSet.cy = vp+25;
   }

   override bool notifyHandler(Widget w, Purpose p)
   {
      focusLayout();
      switch (p)
      {
      case Purpose.XCOLOR:
         lastOp = push!RGBA(this, baseColor, OP_COLOR);
         setColor(false);
         cSrc.setBase(baseColor);
         setupColors();
         break;
      case Purpose.PATTERN:
         int n = (cast(ComboBoxText) w).getActive();
         if (pattern == n)
         {
            nop = true;
            return true;
         }
         pattern = n;
         dirty = true;
         reBuild();
         break;
      case Purpose.DCOLORS:
         int n = (cast(ComboBoxText) w).getActive();
         if (shade == n)
         {
            nop =true;
            return true;
         }
         shade = n;
         setupColors();
         break;
      case Purpose.PIN:
         irregular = !irregular;
         dirty = true;
         break;
      case Purpose.PRINTRANDOM:
         printRandom = !printRandom;
         break;
      case Purpose.REFRESH:
         colorSeed += cSet.control? -1: 1;
         setupColors();
         break;
      case Purpose.REDRAW:
         shapeSeed += cSet.control? -1: 1;
         dirty = true;
         reBuild();
         break;
      default:
         return false;
      }
      return true;
   }

   override bool undoHandler(CheckPoint cp)
   {
      switch (cp.type)
      {
      case OP_CSEED:
         colorSeed = cp.uiVal;
         cSrc.setSeed(colorSeed);
         break;
      case OP_SSEED:
         lastOp = push!uint(this, colorSeed, OP_SSEED);
         shapeSeed = cp.uiVal;
         break;
      case OP_XCOLOR:
         baseColor = cp.color;
         cSrc.setBase(baseColor);
         break;
      case OP_IV0:
         shade = cp.iVal;
         cSrc.setShadeBand(shade);
         cSet.setComboIndex(Purpose.DCOLORS, shade);
         break;
      case OP_ROWCOLS:
         ICoord ic = cp.iCoord;
         rows = ic.x;
         cols = ic.y;
         colors.length = rows*(cols*2+1);
         setupColors();
         dirty = true;
         reBuild();
         break;
      case OP_PCA:
         pca = cp.pca;
         cSet.setPalette(pca.ptr);
         setupColors();
         break;
      default:
         return false;
      }
      lastOp = OP_UNDEF;
      return true;
   }

   override void onCSPalette(PartColor[] npa)
   {
      focusLayout();
      lastOp = push!(PartColor[])(this, pca, OP_PCA);
      pca[] = npa[];
      if (shade == 9)
         setupColors();
      reDraw();
   }

   override void onCSMoreLess(int instance, bool more, bool coarse)
   {
      focusLayout();
      ICoord ic = ICoord(rows, cols);
      if (more)
      {

         lastOp = push!ICoord(this, ic, OP_ROWCOLS);
         rows++;
         cols++;
      }
      else
      {
         if (rows > 0 && cols > 0)
         {
            lastOp = push!ICoord(this, ic, OP_ROWCOLS);
            rows--;
            cols--;
         }
      }
      colors.length = rows*(cols*2+1);
      setupColors();
      dirty = true;
      reBuild();
      aw.dirty = true;
      reDraw();
   }

   static void moveCoord(ref Coord p, double distance, double angle)
   {
      p.x += cos(angle)*distance;
      p.y -= sin(angle)*distance;
   }


   void setupColors()
   {
      if (shade == 9)  // Using palette - round robin
      {
         colorGen.seed(colorSeed);

         for (size_t i = 0; i < colors.length; i++)
         {
            size_t n = uniform(0, pca.length, colorGen);
            colors[i] = pca[n];
         }
         return;
      }
      cSrc.setSeed(colorSeed);
      cSrc.setShadeBand(shade);
      for (size_t i = 0; i < colors.length; i++)
         colors[i] = cSrc.getColor();
   }

   void buildTriangles()
   {
      colInc = (cast(double) width)/cols;
      rowInc = (cast(double) height)/rows;
      points.length = 0;
      for (int i = 0; i <= rows; i++)
      {
         Coord[] rp;
         rp.length = cols+2;
         points ~= rp;
      }
      double rowPos = 0, colPos =0;
      for (int i = 0; i <= rows; i++)
      {
         if (i & 1)
         {
            points[i][0] = Coord(0, rowPos);
            colPos = colInc/2;
            for (int j = 1; j <= cols; j++)
            {
               points[i][j] = Coord(colPos, rowPos);
               colPos += colInc;
            }
            colPos -= colInc/2;
            points[i][cols+1] = Coord(colPos, rowPos);
         }
         else
         {
            colPos = 0;
            for (int j = 0; j <= cols; j++)
            {
               points[i][j] = Coord(colPos, rowPos);
               colPos += colInc;
            }
         }
         rowPos += rowInc;
      }
      if (!irregular)
         return;
      Random shapeGen;
      shapeGen.seed(shapeSeed);
      double angle, d, maxMove = colInc/2;
      for (int j = 1; j < cols; j++)
      {
         d = uniform(-colInc, colInc, shapeGen);
         d /= 3;
         points[0][j].x += d;
      }
      for (int i = 1; i < rows; i++)
      {
         d = uniform(-colInc, colInc, shapeGen);
         d /= 3;
         points[i][0].y += d;

         if (i & 1)
         {
            for (int j = 1; j < cols+1; j++)
            {
               angle = uniform(0, PI*2, shapeGen);
               d = uniform(0.0, maxMove, shapeGen);
               moveCoord(points[i][j], d, angle);
            }
            d = uniform(-colInc, colInc, shapeGen);
            d /= 3;
            points[i][cols+1].y += d;
         }
         else
         {
            for (int j = 1; j < cols; j++)
            {
               angle = uniform(0, PI*2, shapeGen);
               d = uniform(0.0, maxMove, shapeGen);
               moveCoord(points[i][j], d, angle);
            }
            d = uniform(-colInc, colInc, shapeGen);
            d /= 3;
            points[i][cols].y += d;
         }
      }
      int lim = (cols & 1)? cols: cols-1;
      for (int j = 1; j < lim; j++)
      {
         d = uniform(-colInc, colInc, shapeGen);
         d /= 3;
         points[rows][j].x += d;
      }
   }

   void buildSquares()
   {
      colInc = (cast(double) width)/cols;
      rowInc = (cast(double) height)/rows;
      points.length = 0;
      for (int i = 0; i <= rows; i++)
      {
         Coord[] rp;
         rp.length = cols+1;
         points ~= rp;
      }
      double rowPos = 0, colPos =0;
      for (int i = 0; i <= rows; i++)
      {
         colPos = 0;
         for (int j = 0; j <= cols; j++)
         {
            points[i][j] = Coord(colPos, rowPos);
            colPos += colInc;
         }
         rowPos += rowInc;
      }
      if (!irregular)
         return;
      Random shapeGen;
      shapeGen.seed(shapeSeed);
      double angle, d, maxMove = colInc/2;
      for (int j = 1; j < cols; j++)
      {
         d = uniform(-colInc, colInc, shapeGen);
         d /= 3;
         points[0][j].x += d;
      }
      for (int i = 1; i < rows; i++)
      {
         d = uniform(-colInc, colInc, shapeGen);
         d /= 3;
         points[i][0].y += d;

         for (int j = 1; j < cols; j++)
         {
            angle = uniform(0, PI*2, shapeGen);
            d = uniform(0.0, maxMove, shapeGen);
            moveCoord(points[i][j], d, angle);
         }
         d = uniform(-colInc, colInc, shapeGen);
         d /= 3;
         points[i][cols].y += d;
      }
      for (int j = 1; j < cols; j++)
      {
         d = uniform(-colInc, colInc, shapeGen);
         d /= 3;
         points[rows][j].x += d;
      }
   }

   void reBuild()
   {
      if (!printRandom && !dirty)
         return;
      if (pattern == 0)
         buildSquares();
      else
         buildTriangles();
      dirty = false;
   }

   override void render(Context c)
   {
      c.translate(hOff, vOff);
      void apply()
      {
         if (shade == 0)
         {
            c.fillPreserve();
            c.setSourceRgb(0,0,0);
            c.stroke();
         }
         else
            c.fill();
      }

      reBuild();
      c.setSourceRgb(baseColor.red, baseColor.green, baseColor.blue);
      c.setLineWidth(0.5);
      int ci = 0;
      if (pattern == 1)
      {
         for (int i = 0; i < rows; i++)
         {
            if (i & 1)
            {
               c.moveTo(points[i][0].x, points[i][0].y);
               c.lineTo(points[i][1].x, points[i][1].y);
               c.lineTo(points[i+1][0].x, points[i+1][0].y);
               c.closePath();
               c.setSourceRgb(colors[ci].r, colors[ci].g, colors[ci].b);
               ci++;
               apply();
               for (int j = 1; j <= cols; j++)
               {
                  c.moveTo(points[i][j].x, points[i][j].y);
                  c.lineTo(points[i+1][j].x, points[i+1][j].y);
                  c.lineTo(points[i+1][j-1].x, points[i+1][j-1].y);
                  c.closePath();
                  c.setSourceRgb(colors[ci].r, colors[ci].g, colors[ci].b);
                  ci++;
                  apply();
               }
               for (int j = 1; j < cols; j++)
               {
                  c.moveTo(points[i][j].x, points[i][j].y);
                  c.lineTo(points[i+1][j].x, points[i+1][j].y);
                  c.lineTo(points[i][j+1].x, points[i][j+1].y);
                  c.closePath();
                  c.setSourceRgb(colors[ci].r, colors[ci].g, colors[ci].b);
                  ci++;
                  apply();
               }
               c.moveTo(points[i][cols].x, points[i][cols].y);
               c.lineTo(points[i][cols+1].x, points[i][cols+1].y);
               c.lineTo(points[i+1][cols].x, points[i+1][cols].y);
               c.closePath();
               c.setSourceRgb(colors[ci].r, colors[ci].g, colors[ci].b);
               ci++;
               apply();
            }
            else
            {
               c.moveTo(points[i][0].x, points[i][0].y);
               c.lineTo(points[i+1][1].x, points[i+1][1].y);
               c.lineTo(points[i+1][0].x, points[i+1][0].y);
               c.closePath();
               c.setSourceRgb(colors[ci].r, colors[ci].g, colors[ci].b);
               ci++;
               apply();
               for (int j = 0; j < cols; j++)
               {
                  c.moveTo(points[i][j].x, points[i][j].y);
                  c.lineTo(points[i+1][j+1].x, points[i+1][j+1].y);
                  c.lineTo(points[i][j+1].x, points[i][j+1].y);
                  c.closePath();
                  c.setSourceRgb(colors[ci].r, colors[ci].g, colors[ci].b);
                  ci++;
                  apply();
               }

               for (int j = 1; j < cols; j++)
               {
                  c.moveTo(points[i][j].x, points[i][j].y);
                  c.lineTo(points[i+1][j].x, points[i+1][j].y);
                  c.lineTo(points[i+1][j+1].x, points[i+1][j+1].y);
                  c.closePath();
                  c.setSourceRgb(colors[ci].r, colors[ci].g, colors[ci].b);
                  ci++;
                  apply();
               }

               c.moveTo(points[i][cols].x, points[i][cols].y);
               c.lineTo(points[i+1][cols].x, points[i+1][cols].y);
               c.lineTo(points[i+1][cols+1].x, points[i+1][cols+1].y);
               c.closePath();
               c.setSourceRgb(colors[ci].r, colors[ci].g, colors[ci].b);
               ci++;
               apply();
            }
         }
      }
      else if (pattern == 2)
      {
         Coord ic;
         double ir, twoPi = PI*2;
         Coord A, B, C;
         for (int i = 0; i < rows; i++)
         {
            if (i & 1)
            {
               A = points[i][0]; B = points[i][1]; C = points[i+1][0];
               ic = inCircle(A, B, C, ir);
               c.arc(ic.x, ic.y, ir, 0, twoPi);
               c.setSourceRgb(colors[ci].r, colors[ci].g, colors[ci].b);
               ci++;
               for (int j = 1; j <= cols; j++)
               {
                  A = points[i][j]; B = points[i+1][j]; C = points[i+1][j-1];
                  ic = inCircle(A, B, C, ir);
                  c.arc(ic.x, ic.y, ir, 0, twoPi);
                  c.setSourceRgb(colors[ci].r, colors[ci].g, colors[ci].b);
                  ci++;
                  c.fill();
               }
               for (int j = 1; j < cols; j++)
               {
                  A = points[i][j]; B = points[i+1][j]; C = points[i][j+1];
                  ic = inCircle(A, B, C, ir);
                  c.arc(ic.x, ic.y, ir, 0, twoPi);
                  c.setSourceRgb(colors[ci].r, colors[ci].g, colors[ci].b);
                  ci++;
                  c.fill();
               }
               A = points[i][cols]; B = points[i][cols+1]; C = points[i+1][cols];
               ic = inCircle(A, B, C, ir);
               c.arc(ic.x, ic.y, ir, 0, twoPi);
               c.setSourceRgb(colors[ci].r, colors[ci].g, colors[ci].b);
               ci++;
            }
            else
            {
               A = points[i][0]; B = points[i+1][1]; C = points[i+1][0];
               ic = inCircle(A, B, C, ir);
               c.arc(ic.x, ic.y, ir, 0, twoPi);
               c.setSourceRgb(colors[ci].r, colors[ci].g, colors[ci].b);
               ci++;
               apply();
               for (int j = 0; j < cols; j++)
               {
                  A = points[i][j]; B = points[i+1][j+1]; C = points[i][j+1];
                  ic = inCircle(A, B, C, ir);
                  c.arc(ic.x, ic.y, ir, 0, twoPi);
                  c.setSourceRgb(colors[ci].r, colors[ci].g, colors[ci].b);
                  ci++;
                  apply();
               }
               for (int j = 1; j < cols; j++)
               {
                  A = points[i][j]; B = points[i+1][j]; C = points[i+1][j+1];
                  ic = inCircle(A, B, C, ir);
                  c.arc(ic.x, ic.y, ir, 0, twoPi);
                  c.setSourceRgb(colors[ci].r, colors[ci].g, colors[ci].b);
                  ci++;
                  apply();
               }
               A = points[i][cols]; B = points[i+1][cols]; C = points[i+1][cols+1];
               ic = inCircle(A, B, C, ir);
               c.arc(ic.x, ic.y, ir, 0, twoPi);
               c.setSourceRgb(colors[ci].r, colors[ci].g, colors[ci].b);
               ci++;
               apply();
            }
         }
      }
      else
      {
         for (int i = 0; i < rows; i++)
         {
            for (int j = 0; j < cols; j++)
            {
               c.moveTo(points[i][j].x, points[i][j].y);
               c.lineTo(points[i+1][j].x, points[i+1][j].y);
               c.lineTo(points[i+1][j+1].x, points[i+1][j+1].y);
               c.lineTo(points[i][j+1].x, points[i][j+1].y);
               c.closePath();
               c.setSourceRgb(colors[ci].r, colors[ci].g, colors[ci].b);
               ci++;
               apply();
            }
         }
      }
   }
}
