
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module common;

import main;
import acomp;
import constants;
import types;

import std.stdio;
import std.array;
import std.format;
import std.path;

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

