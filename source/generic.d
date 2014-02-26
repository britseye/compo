
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module generic;

import std.stdio;
import sheets;

class GenericISO : Portfolio
{
   Sheet[] sheets;
   this()
   {
      Grid g;
      Sheet s;

      // A4 sheet with 10mm margin
      g  = Grid(1, 1, 190.0, 277, 10.0, 10.0, 0, 0, false);
      s = Sheet(true, "Generic", "Full sheet", "Full sheet", Category.FOLDED, Paper.A4, false);
      s.layout.g = g;
      sheets ~= s;

      // A4 to fold or cut in two, with 10mm margin
      g  = Grid(1, 2, 190.0, 128.5, 10.0, 10.0, 0, 148.5, false);
      s = Sheet(true, "Generic", "Half sheet", "Half sheet", Category.FOLDED, Paper.A4, false);
      s.layout.g = g;
      sheets ~= s;

      // A4 to fold or cut in quarters, with 10mm margin
      g  = Grid(2, 2, 85.0, 128.5, 10.0, 10.0, 105.0, 148.5, false);
      s = Sheet(true, "Generic", "Quarter sheet", "Quarter sheet", Category.FOLDED, Paper.A4, false);
      s.layout.g = g;
      sheets ~= s;

      // A4 tri-fold
      g  = Grid(1, 3, 190.0, 85.6, 10.0, 10.0, 0, 148.5, false);
      s = Sheet(true, "Generic", "Trifold", "Trifold", Category.FOLDED, Paper.A4, false);
      s.layout.g = g;
      sheets ~= s;
   }

   int sheetCount()
   {
      return cast(int) sheets.length;
   }

   Sheet* sheetPtr()
   {
      return &sheets[0];
   }
}

class GenericUS : Portfolio
{
   Sheet[] sheets;
   this()
   {
      Grid g;
      Sheet s;

      // US Letter sheet with 0.375 inchmargin
      g  = Grid(1, 1, 7.75, 10.25, 0.375, 0.375, 0, 0, false);
      s = Sheet(false, "Generic", "Full sheet", "Full sheet", Category.FOLDED, Paper.US, false);
      s.layout.g = g;
      sheets ~= s;

      // US Letter to fold or cut in two, with 0.375 inchmargin
      g  = Grid(1, 2, 7.75, 4.75, 0.375, 0.375, 0, 5.5, false);
      s = Sheet(false, "Generic", "Half sheet", "Half sheet", Category.FOLDED, Paper.US, false);
      s.layout.g = g;
      sheets ~= s;

      // US Letter to fold or cut in quarters, with 0.375 inchmargin
      g  = Grid(2, 2, 3.25, 4.75, 0.25, 0.25, 5.25, 5.5, false);
      s = Sheet(false, "Generic", "Quarter sheet", "Quarter sheet", Category.FOLDED, Paper.US, false);
      s.layout.g = g;
      sheets ~= s;

      // US Letter tri-fold
      g  = Grid(1, 3, 7.75, 3.1666, 0.25, 0.25, 0, 4.1666, false);
      s = Sheet(false, "Generic", "Trifold", "Trifold", Category.FOLDED, Paper.US, false);
      s.layout.g = g;
      sheets ~= s;
   }

   int sheetCount()
   {
      return cast(int) sheets.length;
   }
   Sheet* sheetPtr()
   {
      return &sheets[0];
   }
}
