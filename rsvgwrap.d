module rsvgwrap;

import std.string;
import cairo.Context;
import cairo.Matrix;

// RsvgHandle with rsvg_handle_new_from_file()
struct RsvgHandle;
extern(C) RsvgHandle* rsvg_handle_new_from_file(immutable(char)* fn);
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
      void* vp;
      handle = rsvg_handle_new_from_file(toStringz(filename));
   }

   void setContext(Context c)
   {
      ctp = cast(cairo_t*) c.getContextStruct();
      ctx = c;
   }

/*************************************************************************************
   Render it in the Cairo Context
   x - x position
   y - y position
   w - width of the target drawing area
   h - height of the target drawing area
   scalex - Additional scaling

   The image will first be scaled so it fits in the most restrictive dimension.
   Then any additional scaling is applied.
*/
   bool render(double x, double y, double w, double h, int scaleType, double scalex = 1.0)
   {
      //ctx.save();
      cairo_matrix_t mts, mtt;
      Matrix tms = new Matrix(&mts);
      Matrix tmt = new Matrix(&mtt);
      tmt.initTranslate(x, y);
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
            nw = nh*ar;
            tms.initScale(scalex*((tar*nw)/sh), scalex*(nh/sh));
         }
         else
         {
            nw = w;
            nh = nw/ar;
            tms.initScale(scalex*(nw/sw), scalex*((tar*nh)/sw));
         }
      }
      else if (scaleType == 1)
      {
         tms.initScale(scalex*w/sw, scalex*h/sh);
      }
      tms.multiply(tms, tmt);
      ctx.setMatrix(tms);
      int rv = rsvg_handle_render_cairo(handle, ctp);
      //ctx.restore();
      return (rv != 0);
   }
}
