module rsvgwrap;

import std.string;
import std.stdio;

import cairo.Context;
import cairo.Matrix;

// RsvgHandle with rsvg_handle_new_from_file()
struct RsvgHandle;
extern(C) RsvgHandle* rsvg_handle_new_from_file(immutable(char)* fn);
extern(C) RsvgHandle* rsvg_handle_new_from_data(const ubyte* data, size_t data_len, void**error);
extern(C) int rsvg_handle_render_cairo(RsvgHandle *handle, cairo_t* cr);
extern(C) void rsvg_handle_get_dimensions(RsvgHandle* handle, RsvgDimensionData* dp);

struct RsvgDimensionData
{
    int width;
    int height;
    gdouble em;
    gdouble ex;
}

class SVGRenderer
{
   Context ctx;
   cairo_t* ctp;
   RsvgHandle* handle;

/*************************************************************************************
   Make an SVGRenderer from an SVG file to render in a Cairo Context
*/
   this(string filename)
   {
      handle = rsvg_handle_new_from_file(toStringz(filename));
   }

   this(ubyte* data, size_t len)
   {
      void* vp;
      handle = rsvg_handle_new_from_data(data, len, &vp);
   }

   void setContext(Context c)
   {
      ctp = cast(cairo_t*) c.getContextStruct();
      ctx = c;
   }

/*************************************************************************************
   Render it in the Cairo Context - a transparent Surface context seems to work best
   x - x position
   y - y position
   w - width of the target drawing area
   h - height of the target drawing area
   scalex - Additional scaling

   The image will first be scaled so it fits in the most restrictive dimension.
   Then any additional scaling is applied.
*/
   bool render(double w, double h, int scaleType, double scalex = 1.0)
   {
      cairo_matrix_t mts;
      Matrix tms = new Matrix(&mts);
      tms.initIdentity();

      RsvgDimensionData dd;
      rsvg_handle_get_dimensions(handle, &dd);
      double nw, nh;
      double sw = cast(double) dd.width;
      double sh = cast(double) dd.height;
      double tar = w/h;
      double ar = sw/sh;
      if (scaleType == 0)
      {
         if (tar > ar)
         {
            nh = h;
            nw = sw*h/sh;
            tms.initScale(scalex*h/sh, scalex*h/sh);
         }
         else
         {
            nw = w;
            nh = sh*w/sw;
            tms.initScale(scalex*w/sw, scalex*w/sw);
         }
      }
      else if (scaleType == 1)
      {
         tms.initScale(scalex*w/sw, scalex*h/sh);
      }
      ctx.setMatrix(tms);
      int rv = rsvg_handle_render_cairo(handle, ctp);
      return (rv != 0);
   }
}
