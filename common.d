
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module common;

import mainwin;
import acomp;
import constants;
import types;

import std.stdio;
import std.array;
import std.format;
import std.path;
import std.random;
import std.math;

import gdk.RGBA;

// This block of data is intended for use by multiple object types to hold rendering data.
// In cases where it is used serialize() will write it to file, and deserialize will
// recover it. Objects can use it as they please,bu must make sure it is up to date
// before a save
struct ParamBlock
{
   bool valid;
   Coord[8] cpa;
   double[8] dpa;
   int[8] ipa;
   string name;

   void clear()
   {
      cpa[] = Coord(double.nan, double.nan);
      dpa[] = double.nan;
      ipa[] = 0;
   }
}

string formatCoord(Coord c)
{
   scope auto writer = appender!string();
   formattedWrite(writer, "%3.2f, %3.2f", c.x, c.y);
   return writer.data;
}

string getConfigPath(string fn)
{
   string t = "~/.COMPO/";
   t = expandTilde(t);
   t ~= fn;
   return t;
}

Coord inCircle(Coord A, Coord B, Coord C, out double r)
{
   double a = sqrt((B.x-C.x)*(B.x-C.x)+(B.y-C.y)*(B.y-C.y));
   double b = sqrt((A.x-C.x)*(A.x-C.x)+(A.y-C.y)*(A.y-C.y));
   double c = sqrt((A.x-B.x)*(A.x-B.x)+(A.y-B.y)*(A.y-B.y));
   double P = a+b+c;
   double s = 0.5*P;
   r = sqrt(((s-a)*(s-b)*(s-c))/s);
   Coord ic;
   ic.x = (a*A.x+b*B.x+c*C.x)/P;
   ic.y = (a*A.y+b*B.y+c*C.y)/P;
   return ic;
}

struct ColorSource
{
   double propMax;
   int maxColor, shadeBand;
   Mt19937 gen;
   uint seed;
   PartColor base, props;

   void init(RGBA rgba, uint rseed)
   {
      base.r = rgba.red;
      base.g = rgba.green;
      base.b = rgba.blue;
      getColorProps();
   }

   void setBase(RGBA rgba)
   {
      base.r = rgba.red;
      base.g = rgba.green;
      base.b = rgba.blue;
      getColorProps();
   }

   void setBase(PartColor pc)
   {
      base = pc;
      getColorProps();
   }

   void setShadeBand(int n) { shadeBand = n; }

   void setSeed(uint seed) { gen.seed(seed); }

   private void getColorProps()
   {
      double[3] a;
      a[0] = base.r;
      a[1] = base.g;
      a[2] = base.b;
      propMax = 0;
      maxColor = 0;
      foreach (int i, double d; a)
      {
         if (d > propMax)
         {
            propMax = d;
            maxColor = i;
         }
      }
      switch (maxColor)
      {
         case 0:
            props = PartColor(1, base.g/base.r, base.b/base.r, 0);
            break;
         case 1:
            props = PartColor(base.r/base.g, 1, base.b/base.g, 0);
            break;
         case 2:
            props = PartColor(base.r/base.b, base.g/base.b, 1, 0);
            break;
         default:
            break;
      }
   }

   PartColor randomShade()
   {
      PartColor pc;
      if (shadeBand == 0)
      {
         pc = base;
         return pc;
      }
      double upper = 1, lower = 0;
      switch (shadeBand)
      {
         case 1:
            lower = uniform(0, 0.9);
            break;
         case 2:
            lower = 0.8;
            break;
         case 3:
            upper = 0.8;
            lower = 0.4;
            break;
         case 4:
            upper = 0.6;
            break;
         default:
            break;
      }

      pc.a = 1;
      double t = upper-lower;
      double f = uniform(0, t, gen);
      pc.r = lower+props.r*f;
      pc.g = lower+props.g*f;
      pc.b = lower+props.b*f;
      return pc;
   }

   PartColor randomColor()
   {
      double upper = 1, lower = 0;
      switch (shadeBand)
      {
         case 5:
            lower = 0.7;
            break;
         case 6:
            upper = 0.8;
            lower = 0.4;
            break;
         case 7:
            upper = 0.5;
            break;
         default:
            break;
      }

      PartColor pc;
      pc.r = uniform(lower, upper, gen);
      pc.g = uniform(lower, upper, gen);
      pc.b = uniform(lower, upper, gen);
      pc.a = 1;
      return pc;
   }

   PartColor getColor()
   {
      if (shadeBand < 5)
         return randomShade();
      else
         return randomColor();
   }
}

struct FillOptions
{
   FillOption[] foa;
   ACBase that;
   ACBase root;

   private void getCandidates()
   {
      if (that.parent.type != AC_CONTAINER)
         return;
      foreach (ACBase child; root.children)
      {
         if (child is that || child is that.parent)
            continue;
         foa ~= FillOption(child.name, child.uuid);
      }
   }

   void init(ACBase acb)
   {
      that= acb;
      root = that.aw.tm.root;
      getCandidates();
   }

   FillOption[] get()
   {
      return foa;
   }
}
