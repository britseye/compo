import std.stdio;

// Arithmetic more/less
bool molA(T)(bool more, bool quickly, ref T target, T inc, T minval, T maxval)
{
   if (more)
   {
      target += quickly? inc*5: inc;
      return (target <= maxval);
   }
   else
   {
      target -= quickly? inc*5: inc;
      return (target >= minval);
   }
}

// Geometric more/less
bool molG(T)(bool more, bool quickly, ref T target, T factor, T minval, T maxval)
{
   T f;
   bool iflag = false;
   static if (is( T == double))
   {
      f = quickly? 5*factor+1: factor+1;
   }
   else static if (is(T == int))
   {
      f = 2;  // Only sensible value?
   }

   if (more)
   {
      target *= f;
      return (target <= maxval);
   }
   else
   {
      if (target == cast(T) 0)
         return false;
      target /= f;
      return (target >= minval);
   }
}
