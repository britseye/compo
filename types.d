
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module types;

import gtkc.gdktypes;

struct Coord
{
   double x = 0.0;
   double y = 0.0;
}

struct ICoord
{
   int x;
   int y;
}

struct CRect
{
   double x, y, w, h;
}

struct Rect
{
   double topX = 0.0;
   double topY = 0.0;
   double bottomX = 0.0;
   double bottomY = 0.0;
}

struct CPDHdr
{
   cairo_path_data_type_t type;
   int length;
}
union CairoPathData
{
   CPDHdr header;
   Coord point;
}

struct CairoPath
{
   cairo_status_t status;
   CairoPathData* data;
   int numData;
}

CairoPath copyCairoPath(CairoPath* pp)
{
   CairoPath rv;
   CairoPathData[] pd;
   pd.length = pp.numData;
   pd[] = pp.data[0..pp.numData];
   rv.status = pp.status;
   rv.data = pd.ptr;
   rv.numData = pp.numData;
   return rv;
}

struct ShapeInfo
{
   double c1 = 0.0, c2 = 0.0, c3 = 0.0, c4 = 0.0, c5 = 0.0, c6 = 0.0;
}

struct Transform
{
   double hScale = 1;
   double vScale = 1;
   double hSkew = 0;
   double vSkew = 0;
   bool hFlip;
   bool vFlip;
   double ra = 0;
}

struct PartColor
{
   double r = 1;
   double g = 1;
   double b = 1;
   double a = 1;
}

struct Part
{
   int type;
   bool closed;
   string name;
   Coord center;
   PartColor color;
   double lwf;
   int length;
   PathItemR[] ia;

   void copy(Part other)
   {
      type = other.type;
      closed = other.closed;
      length = other.length;
      center = other.center;
      color = other.color;
      lwf = other.lwf;
      ia.length = other.ia.length;
      ia[] = other.ia[];
   }
}

struct PathItem
{
   int type;
   Coord start, cp1, cp2, end;
   Coord cog;
}

struct PathItemR
{
   int type;
   Coord start, cp1, cp2, end;
   Coord cog;
}

