
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module morphs;

import types;
import constants;
import common;
import morphtext;
import std.stdio;
import std.math;

import gtkc.cairotypes;

interface Morpher
{
   Coord getTGPoint(double xf);
   Coord getBGPoint(double xf);
   void transform(CairoPathData* data, int dt, Rect tx);
   void updateParams();
   void refreshParams();

   final Coord transformPoint(Coord p, double w, double h)
   {
      Coord rp = Coord(0,0);
      double xf = p.x/w;
      Coord axt = getTGPoint(xf);
      Coord axb = getBGPoint(xf);
      double yf = p.y/h;
      rp.x = axt.x+(axb.x-axt.x)*yf;
      rp.y = axt.y+(axb.y-axt.y)*yf;
      return rp;
   }

   final void stdTransform(CairoPathData* data, int dt, Rect extent)
   {
      int n = (dt == 2)? 4: 2;
      double w = extent.bottomX-extent.topX;
      double h = extent.bottomY-extent.topY;
      for (int i = 1; i < n; i++)
      {
         double x = data[i].point.x - extent.topX;
         double y = data[i].point.y - extent.topY;
         Coord p = transformPoint(Coord(x, y), w, h);
         data[i].point.x = p.x;
         data[i].point.y = p.y;
      }
   }
}

class FitBox : Morpher
{
   double w, h, nl;
   ParamBlock* mp;

   this(double width, double height, ParamBlock* p)
   {
      w = width;
      h = height;
      mp = p;
      nl = mp.valid? mp.dpa[0]: 1.0;
   }

   Coord getTGPoint(double xf)
   {
      //double x = w*xf;
      double x = w*pow(xf, nl);
      double y = 0.0;
      return Coord(x, y);
   }

   Coord getBGPoint(double xf)
   {
      //double x = w*xf;
      double x = w*pow(xf, nl);
      double y = h;
      return Coord(x, y);
   }

   void transform(CairoPathData* data, int dt, Rect extent)
   {
      stdTransform(data, dt, extent);
   }

   void updateParams()
   {
      mp.dpa[0] = nl;
      mp.valid = true;
   }

   void refreshParams() {}
}

class Taper : Morpher
{
   ParamBlock* mp;
   Coord tgs, tge, bgs, bge;

   this(double w, double h, ParamBlock* p)
   {
      mp = p;
      if (mp.valid)
      {
         tgs = mp.cpa[0];
         tge = mp.cpa[1];
         bgs = mp.cpa[2];
         bge = mp.cpa[3];
      }
      else
      {
         tgs = Coord(0.05*w, 0.01*h);
         tge = Coord(0.95*w, 0.4*h);
         bgs = Coord(0.05*w, 0.99*h);
         bge = Coord(0.95*w, 0.6*h);
      }
   }

   Coord getTGPoint(double xf)
   {
      double x = tgs.x + (tge.x - tgs.x)*pow(xf, 0.7);
      double y = tgs.y + (tge.y - tgs.y)*xf;
      return Coord(x, y);
   }

   Coord getBGPoint(double xf)
   {
      double x = bgs.x + (bge.x - bgs.x)*pow(xf, 0.7);
      double y = bgs.y + (bge.y - bgs.y)*xf;
      return Coord(x, y);
   }

   void transform(CairoPathData* data, int dt, Rect extent)
   {
      stdTransform(data, dt, extent);
   }

   void updateParams()
   {
      mp.cpa[0] = tgs;
      mp.cpa[1] = tge;
      mp.cpa[2] = bgs;
      mp.cpa[3] = bge;
      mp.valid = true;
   }

   void refreshParams() {}
}

class ArchUp: Morpher
{
   ParamBlock* mp;
   double radiust, radiusb;
   double astart, aend, tot;
   double odepth, depth;
   double width, height;

   this(double w, double h, ParamBlock* p)
   {
      width = w;
      height = h;
      mp = p;
      if (mp.valid)
      {
         radiust = mp.dpa[0];
         radiusb = mp.dpa[1];
         depth = mp.dpa[2];
         astart = mp.dpa[3];
         aend = mp.dpa[4];
         tot = mp.dpa[5];
         odepth = mp.dpa[6];
      }
      else
      {
         if (w > h/2)
         {
            radiust = h;
            depth = h/4.0;
         }
         else
         {
            radiust = w/2.0;
            depth = w/4.0;
         }
         h = 0.6666*w;
         radiusb = radiust-depth;
         astart = PI;
         aend = 2*PI;
         tot = PI;
         odepth = depth;
      }
   }

   Coord getTGPoint(double xf)
   {
      xf *= tot;
      double a = astart+xf;
      double x = radiust*cos(a)+width/2;
      double y = radiust*sin(a)+height;
      return Coord(x, y);
   }

   Coord getBGPoint(double xf)
   {
      xf *= tot;
      double a = astart+xf;
      double x = radiusb*cos(a)+width/2;
      double y = radiusb*sin(a)+height;
      return Coord(x, y);
   }

   void transform(CairoPathData* data, int dt, Rect extent)
   {
      stdTransform(data, dt, extent);
   }

   void updateParams()
   {
      mp.dpa[0] = radiust;
      mp.dpa[1] = radiusb;
      mp.dpa[2] = depth;
      mp.dpa[3] = astart;
      mp.dpa[4] = aend;
      mp.dpa[5] = tot;
      mp.dpa[6] = odepth;
      mp.valid = true;
   }

   void refreshParams() {}
}

class Circular: Morpher
{
   ParamBlock* mp;
   double radiuso, radiusi;
   double astart, aend, tot;
   double odepth, depth;
   double width, height;
   bool anti;

   this(double w, double h, ParamBlock* p)
   {
      anti = false;
      width = w;
      height = h;
      mp = p;
      if (mp.valid)
      {
         radiuso = mp.dpa[0];
         radiusi = mp.dpa[1];
         depth = mp.dpa[2];
         astart = mp.dpa[3];
         aend = mp.dpa[4];
         tot = mp.dpa[5];
         odepth = mp.dpa[6];
      }
      else
      {
         if (w > h)
            radiuso = h/2;
         else
            radiuso = w/2;
         odepth = depth = radiuso*0.2;
         radiusi = radiuso-depth;
         astart = 0;
         aend = 0.95*2*PI;
         tot = aend - astart;
      }
   }

   Coord getTGPoint(double xf)
   {
      xf *= tot;
      double a, x, y;
      if (anti)
      {
         a = aend-xf;
         x = radiusi*cos(a)+width/2;
         y = radiusi*sin(a)+height/2;
      }
      else
      {
         a = astart+xf;
         x = radiuso*cos(a)+width/2;
         y = radiuso*sin(a)+height/2;
      }
      return Coord(x, y);
   }

   Coord getBGPoint(double xf)
   {
      xf *= tot;
      double a, x, y;
      if (anti)
      {
         a = aend-xf;
         x = radiuso*cos(a)+width/2;
         y = radiuso*sin(a)+height/2;
      }
      else
      {
         a = astart+xf;
         x = radiusi*cos(a)+width/2;
         y = radiusi*sin(a)+height/2;
      }
      return Coord(x, y);
   }

   void transform(CairoPathData* data, int dt, Rect extent)
   {
      stdTransform(data, dt, extent);
   }

   void updateParams()
   {
      mp.dpa[0] = radiuso;
      mp.dpa[1] = radiusi;
      mp.dpa[2] = depth;
      mp.dpa[3] = astart;
      mp.dpa[4] = aend;
      mp.dpa[5] = tot;
      mp.dpa[6] = odepth;
      mp.valid = true;
   }

   void refreshParams() {}
}

class SineWave: Morpher
{
   ParamBlock* mp;
   int halfCycles;
   double odepth, depth;
   double width, height;
   double sp;

   this(double w, double h, ParamBlock* p)
   {
      mp = p;
      width = w;
      height = h;
      if (mp.valid)
      {
         halfCycles = mp.ipa[0];
         depth = mp.dpa[0];
         odepth = mp.dpa[1];
         sp = mp.dpa[2];
      }
      else
      {
         halfCycles = 3;
         odepth = depth = h/4;
         sp = 0.5*PI;
      }
   }

   Coord getTGPoint(double xf)
   {
      double a = sp+xf*(PI*halfCycles);
      double x = xf*width;
      double y = height/2-depth/2+cos(a)*height/3;
      return Coord(x, y);
   }

   Coord getBGPoint(double xf)
   {
      double a = sp+xf*(PI*halfCycles);
      double x = xf*width;
      double y = height/2+depth/2+cos(a)*height/3;
      return Coord(x, y);
   }

   void transform(CairoPathData* data, int dt, Rect extent)
   {
      stdTransform(data, dt, extent);
   }

   void updateParams()
   {
      mp.ipa[0] = halfCycles;
      mp.dpa[0] = depth;
      mp.dpa[1] = odepth;
      mp.dpa[2] = sp;
      mp.valid = true;
   }

   void refreshParams() {}
}

class Twisted: Morpher
{
   ParamBlock* mp;
   int halfCycles;
   double odepth, depth;
   double width, height;
   double sp;

   this(double w, double h, ParamBlock* p)
   {
      mp = p;
      width = w;
      height = h;
      if (mp.valid)
      {
         halfCycles = mp.ipa[0];
         depth = mp.dpa[0];
         odepth = mp.dpa[1];
         sp = mp.dpa[2];
      }
      else
      {
         halfCycles = 1;
         odepth = depth = h/4;
         sp = 0;
      }
   }

   Coord getTGPoint(double xf)
   {
      double a = sp+xf*(PI*halfCycles);
      double x = xf*width;
      double y = height/2-cos(a)*height*0.8;
      return Coord(x, y);
   }

   Coord getBGPoint(double xf)
   {
      double a = sp+xf*(PI*halfCycles);
      double x = xf*width;
      double y = height/2+cos(a)*height*0.8;
      return Coord(x, y);
   }

   void transform(CairoPathData* data, int dt, Rect extent)
   {
      stdTransform(data, dt, extent);
   }

   void updateParams()
   {
      mp.ipa[0] = halfCycles;
      mp.dpa[0] = depth;
      mp.dpa[1] = odepth;
      mp.dpa[2] = sp;
      mp.valid = true;
   }

   void refreshParams() {}
}

class Flare: Morpher
{
   ParamBlock* mp;
   double severity;
   double tsp, bsp, xfact;
   double odepth, depth;
   double width, height;

   this(double w, double h, ParamBlock* p)
   {
      mp = p;
      width = w;
      height = h;
      if (mp.valid)
      {
         tsp = mp.dpa[0];
         bsp = mp.dpa[1];
         severity = mp.dpa[2];
         xfact = mp.dpa[3];
         depth = mp.dpa[4];
         odepth = mp.dpa[5];
      }
      else
      {
         severity = 1.0;
         xfact = 5;
         odepth = depth = h/8;
         tsp = 0.4;
         bsp = 0.5;  //1.8;
      }
   }

   Coord getTGPoint(double xf)
   {
      double x = xf*width;
      double t = xf*xfact+tsp;
      double y = -height*pow(E, -t)+height/2-depth;
      return Coord(x, y);
   }

   Coord getBGPoint(double xf)
   {
      double x = xf*width;
      double t = xf*xfact+bsp;
      double y = height*pow(E, -t)+height/2+depth;
      return Coord(x, y);
   }

   void transform(CairoPathData* data, int dt, Rect extent)
   {
      stdTransform(data, dt, extent);
   }

   void updateParams()
   {
      mp.dpa[0] = tsp;
      mp.dpa[1] = bsp;
      mp.dpa[2] = severity;
      mp.dpa[3] = xfact;
      mp.dpa[4] = depth;
      mp.dpa[5] = odepth;
      mp.valid = true;
   }

   void refreshParams() {}
}

class RFlare: Morpher
{
   ParamBlock* mp;
   double severity;
   double tsp, bsp, xfact;
   double odepth, depth;
   double width, height;

   this(double w, double h, ParamBlock* p)
   {
      mp = p;
      width = w;
      height = h;
      if (mp.valid)
      {
         severity = mp.dpa[0];
         tsp = mp.dpa[1];
         bsp = mp.dpa[2];
         xfact = mp.dpa[3];
         depth = mp.dpa[4];
         odepth = mp.dpa[5];
      }
      else
      {
         severity = 1.0;
         tsp = bsp = -0.5;
         xfact = 4;
         odepth = depth = h/8;
      }
   }

   Coord getTGPoint(double xf)
   {
      double x = xf*width;
      double t = xf*xfact-tsp;
      double y = -1*pow(E, t)+height/2-depth;
      return Coord(x, y);
   }

   Coord getBGPoint(double xf)
   {
      double x = xf*width;
      double t = xf*xfact-bsp;
      double y = pow(E, t)+height/2+depth;
      return Coord(x, y);
   }

   void transform(CairoPathData* data, int dt, Rect extent)
   {
      stdTransform(data, dt, extent);
   }

   void updateParams()
   {
      mp.dpa[0] = severity;
      mp.dpa[1] = tsp;
      mp.dpa[2] = tsp;
      mp.dpa[3] = xfact;
      mp.dpa[4] = depth;
      mp.dpa[5] = odepth;
   }

   void refreshParams() {}
}

class Catenary: Morpher
{
   ParamBlock* mp;
   double a, b;
   double odepth, depth;
   double width, height;
   Coord delegate(double) tg;
   Coord delegate(double) bg;
   bool inverted;

   this(double w, double h, ParamBlock* p)
   {
      mp = p;
      width = w;
      height = h;
      if (mp.valid)
      {
         a = mp.dpa[0];
         b = mp.dpa[1];
         depth = mp.dpa[2];
         odepth = mp.dpa[3];
         inverted = (mp.ipa[0] != 0);
      }
      else
      {
         odepth = depth = h/5;
         a = 1.0;
         b = 4.5;
      }
      tg = &f1;
      bg = &f2;
   }

   void invert()
   {
      if (inverted)
      {
         tg = &f1;
         bg = &f2;
      }
      else
      {
         tg = &f3;
         bg = &f4;
      }
      inverted = !inverted;
   }

   Coord f1(double xf)
   {
      double x = 0.025*width+xf*0.95*width;
      double t = (xf-0.5)*b;
      //double y = a*cosh(t/a)*height/5;//-height;
      double y = -a*cosh(t/a)*height/5+height;
      return Coord(x, y);
   }

   Coord f2(double xf)
   {
      //Coord t = getTGPoint(xf);
      //return Coord(t.x, t.y+depth);
      double x = xf*width;
      double t = (xf-0.5)*b;
      //double y = a*cosh(t/a)*height/5+depth;//-height;
      double y = -a*cosh(t/a)*height/5+height+depth;
      return Coord(x, y);
   }

   Coord f3(double xf)
   {
      double x = xf*width;
      double t = (xf-0.5)*b;
      double y = a*cosh(t/a)*height/5-depth;//-height;
      //double y = -a*cosh(t/a)*height/5+height;
      return Coord(x, y);
   }

   Coord f4(double xf)
   {
      //Coord t = getTGPoint(xf);
      //return Coord(t.x, t.y+depth);
      double x = 0.025*width+xf*0.95*width;
      double t = (xf-0.5)*b;
      double y = a*cosh(t/a)*height/5;//-height;
      //double y = -a*cosh(t/a)*height/5+height+depth;
      return Coord(x, y);
   }

   Coord getTGPoint(double xf)
   {
      return tg(xf);
   }
   Coord getBGPoint(double xf)
   {
      return bg(xf);
   }

   void transform(CairoPathData* data, int dt, Rect extent)
   {
      stdTransform(data, dt, extent);
   }

   void updateParams()
   {
      mp.dpa[0] = a;
      mp.dpa[1] = b;
      mp.dpa[2] = depth;
      mp.dpa[3] = odepth;
      mp.ipa[0] = inverted? 1: 0;
      mp.valid = true;
   }

   void refreshParams() {}
}

class Convex: Morpher
{
   ParamBlock* mp;
   double a, b, oa, ob;
   double atstart, atend, tott;
   double abstart, abend, totb;
   double width, height;

   this(double w, double h, ParamBlock* p)
   {
      mp = p;
      width = w;
      height = h;
      if (mp.valid)
      {
         a = mp.dpa[0];
         oa = mp.dpa[1];
         b = mp.dpa[2];
         ob = mp.dpa[3];
         atstart = mp.dpa[4];
         atend = mp.dpa[5];
         abstart = mp.dpa[6];
         abend = mp.dpa[7];
      }
      else
      {
         oa = a = w/2;
         ob = b = h/2;
         atstart = rads*210;
         atend = rads*330;
         abstart = rads*30;
         abend = rads*150;
      }
      tott = atend - atstart;
      totb = abend - abstart;
   }

   Coord getTGPoint(double xf)
   {
      xf *= tott;
      double theta = atstart+xf;
      double x = a*cos(theta)+width/2;
      double y = b*sin(theta)+height/2;
      return Coord(x, y);
   }

   Coord getBGPoint(double xf)
   {
      xf *= totb;
      double theta = abend-xf;
      double x = a*cos(theta)+width/2;
      double y = b*sin(theta)+height/2;
      return Coord(x, y);
   }


   void transform(CairoPathData* data, int dt, Rect extent)
   {
      stdTransform(data, dt, extent);
   }

   void updateParams()
   {
      mp.dpa[0] = a;
      mp.dpa[1] = oa;
      mp.dpa[2] = b;
      mp.dpa[3] = ob;
      mp.dpa[4] = atstart;
      mp.dpa[5] = atend;
      mp.dpa[6] = abstart;
      mp.dpa[7] = abend;
      mp.valid = true;
   }

   void refreshParams() {}
}

class Concave: Morpher
{
   ParamBlock* mp;
   double a, b, oa, ob;
   double atstart, atend, tott;
   double abstart, abend, totb;
   double width, height;

   this(double w, double h, ParamBlock* p)
   {
      mp = p;
      width = w;
      height = h;
      if (mp.valid)
      {
         a = mp.dpa[0];
         oa = mp.dpa[1];
         b = mp.dpa[2];
         ob = mp.dpa[3];
         atstart = mp.dpa[4];
         atend = mp.dpa[5];
         abstart = mp.dpa[6];
         abend = mp.dpa[7];
      }
      else
      {
         oa = a = w/2;
         ob = b = a/2;
         atstart = rads*210;
         atend = rads*330;
         abstart = rads*30;
         abend = rads*150;
      }
      tott = atend - atstart;
      totb = abend - abstart;
   }

   Coord getTGPoint(double xf)
   {
      xf *= totb;
      double theta = abend-xf;
      double x = a*cos(theta)+width/2;
      double y = b*sin(theta)+height*0.25-b;
      return Coord(x, y);
   }

   Coord getBGPoint(double xf)
   {
      xf *= tott;
      double theta = atstart+xf;
      double x = a*cos(theta)+width/2;
      double y = b*sin(theta)+height*0.75+b;
      return Coord(x, y);
   }

   void transform(CairoPathData* data, int dt, Rect extent)
   {
      stdTransform(data, dt, extent);
   }

   void updateParams()
   {
      mp.dpa[0] = a;
      mp.dpa[1] = oa;
      mp.dpa[2] = b;
      mp.dpa[3] = ob;
      mp.dpa[4] = atstart;
      mp.dpa[5] = atend;
      mp.dpa[6] = abstart;
      mp.dpa[7] = abend;
      mp.valid = true;
   }

   void refreshParams() {}
}

class BezierMorph: Morpher
{
   ParamBlock* mp;
   Coord sp1, ep1, c11, c12;
   Coord sp2, ep2, c21, c22;
   double width, height;

   this(double w, double h, ParamBlock* p)
   {
      mp = p;
      width = w;
      height = h;
      if (mp.valid)
      {
         sp1 = mp.cpa[0];
         c11 = mp.cpa[1];
         c12 = mp.cpa[2];
         ep1 = mp.cpa[3];
         sp2 = mp.cpa[4];
         c21 = mp.cpa[5];
         c22 = mp.cpa[6];
         ep2 = mp.cpa[7];
      }
      else
      {
         sp1.x = 0;
         sp1.y = height/3;
         c11.x = width/3;
         c11.y = 0.1*height;
         c12.x = 2*width/3;
         c12.y = 0;
         ep1.x = width;
         ep1.y = 0.1*height;

         sp2.x = 0;
         sp2.y = height;
         c21.x = width/3;
         c21.y = 0.5*height;
         c22.x = 2*width/3;
         c22.y = 0.2*height;
         ep2.x = width;
         ep2.y = 0.3*height;

         updateParams();
      }
   }

// http://pomax.github.io/bezierinfo/
   Coord getTGPoint(double t)
   {
      double x = sp1.x*pow(1-t, 3) + c11.x*3*pow((1-t), 2)*t + c12.x*3*(1-t)*pow(t, 2) + ep1.x*pow(t, 3);
      double y = sp1.y*pow(1-t, 3) + c11.y*3*pow((1-t), 2)*t + c12.y*3*(1-t)*pow(t, 2) + ep1.y*pow(t, 3);
      return Coord(x, y);
   }

   Coord getBGPoint(double t)
   {
      double x = sp2.x*pow(1-t, 3) + c21.x*3*pow((1-t), 2)*t + c22.x*3*(1-t)*pow(t, 2) + ep2.x*pow(t, 3);
      double y = sp2.y*pow(1-t, 3) + c21.y*3*pow((1-t), 2)*t + c22.y*3*(1-t)*pow(t, 2) + ep2.y*pow(t, 3);
      return Coord(x, y);
   }

   void transform(CairoPathData* data, int dt, Rect extent)
   {
      stdTransform(data, dt, extent);
   }

   void updateParams()
   {
      mp.cpa[0] = sp1;
      mp.cpa[1] = c11;
      mp.cpa[2] = c12;
      mp.cpa[3] = ep1;
      mp.cpa[4] = sp2;
      mp.cpa[5] = c21;
      mp.cpa[6] = c22;
      mp.cpa[7] = ep2;
      mp.valid = true;
   }

   void refreshParams()
   {
      sp1 = mp.cpa[0];
      c11 = mp.cpa[1];
      c12 = mp.cpa[2];
      ep1 = mp.cpa[3];
      sp2 = mp.cpa[4];
      c21 = mp.cpa[5];
      c22 = mp.cpa[6];
      ep2 = mp.cpa[7];
   }
}
