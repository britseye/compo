
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module pglayout;

import main;
import common;
import types;
import sheets;
import acomp;
import menus;
import text;

import std.stdio;
import std.math;
import gdk.Event;
import gtk.Widget;
import gtkc.gdktypes;
import gtk.Layout;
import gtk.DrawingArea;
import gtk.Frame;
import cairo.Surface;
import cairo.Context;

class PageLayout: Layout
{
   AppWindow aw;
   DrawingArea da;
   CRect[] rects;
   ACBase[] marked;
   bool[] round;
   Grid grid;
   double plpW, plpH;
   int rows, cols, slots, marks;
   bool hSpaced, vSpaced, isSeq, isRound;
   int callcount;

   this(AppWindow w)
   {
      super(null, null);
      aw = w;
      int iw = cast(int) (aw.pageW*0.78);
      int ih = cast(int) (aw.pageH*0.78);
      //int iw = cast(int) (aw.pageW);
      //int ih = cast(int) (aw.pageH);

      da = new DrawingArea(iw, ih);
      da.addOnDraw(&drawCallback);
      da.addOnButtonPress(&mouseClick);
      Frame f = new Frame(da, null);
      f.setSizeRequest(iw+4, ih+4);
      f.setShadowType(ShadowType.IN);
      put(f, 5, 5);
      f.show();
      da.show();
   }

   int perPage()
   {
      return rows*cols;
   }

   void setLandscapeSheet(Sheet sheet)
   {
      plpW = aw.pageH;
      plpH = aw.pageW;
      if (sheet.seq)
      {
         isSeq = true;
         Sequence seq = sheet.layout.s;
         rects.length = seq.count;
         marked.length = seq.count;
         round.length = seq.count;
         for (int i = 0; i < seq.count; i++)
         {
            rects[i].y = seq.rects[i].x;
            rects[i].x = seq.rects[i].y;
            rects[i].h = seq.rects[i].w;
            rects[i].w = seq.rects[i].h;
            round[i] = seq.rects[i].round;
         }
      }
      else
      {
         isSeq = false;
         Grid g = sheet.layout.g;
         isRound = g.round;
         grid.cols = g.rows;
         grid.rows = g.cols;
         grid.w = g.h;
         grid.h = g.w;
         grid.topx = g.topy;
         grid.topy = g.topx;
         grid.hstride = g.vstride;
         grid.vstride = g.hstride;

         double w = g.h;
         double h = g.w;
         double xoff = g.topy;
         double yoff = g.topx;
         double vstride = g.hstride;
         double hstride = g.vstride;
         vSpaced = (vstride > h);
         hSpaced = (hstride > w);

         int ic = g.cols*g.rows;
         rows = g.cols;
         cols = g.rows;
         slots = rows*cols;
         rects.length = ic;
         marked.length = ic;
         for (int i = 0; i < cols; i++)
         {
            for (int j = 0; j < rows; j++)
            {
               rects[i*rows+j].x = xoff;
               rects[i*rows+j].y = yoff+j*vstride;
               rects[i*rows+j].w = w;
               rects[i*rows+j].h = h;
            }
            xoff += hstride;
         }
      }
      marks = 0;
   }

   void setSheet(Sheet sheet)
   {
      plpW = aw.pageW;
      plpH = aw.pageH;
      if (sheet.seq)
      {
         isSeq = true;
         Sequence seq = sheet.layout.s;
         rects.length = seq.count;
         marked.length = seq.count;
         round.length = seq.count;
         for (int i = 0; i < seq.count; i++)
         {
            rects[i].x = seq.rects[i].x;
            rects[i].y = seq.rects[i].y;
            rects[i].w = seq.rects[i].w;
            rects[i].h = seq.rects[i].h;
            round[i] = seq.rects[i].round;
         }
      }
      else
      {
         isSeq = false;
         Grid g = sheet.layout.g;
         isRound = g.round;
         grid = g;

         double w = g.w;
         double h = g.h;
         double xoff = g.topx;
         double yoff = g.topy;
         double vstride = g.vstride;
         double hstride = g.hstride;
         vSpaced = (vstride > h);
         hSpaced = (hstride > w);

         int ic = g.cols*g.rows;
         rows = g.rows;
         cols = g.cols;
         slots = rows*cols;
         rects.length = ic;
         marked.length = ic;
         for (int i = 0; i < g.rows; i++)
         {
            xoff = g.topx;
            for (int j = 0; j < g.cols; j++)
            {
               rects[i*g.cols+j].x = xoff;
               rects[i*g.cols+j].y = yoff+i*vstride;
               rects[i*g.cols+j].w = w;
               rects[i*g.cols+j].h = h;
               xoff += hstride;
            }
         }
      }
      marks = 0;
   }

   void fill(bool b)
   {
      if (b)
      {
         marks = slots;
         marked[] = aw.getRenderItem();
      }
      else
      {
         marks = 0;
         marked[] = null;
      }
      aw.mm.setState(FILE_PRINT, marks);
      aw.mm.setState(FILE_PRINTIMMEDIATE, marks);
      queueDraw();
   }

   void placeSequence()
   {
      marks = 0;
      marked[] = null;
      ACBase[] t = aw.tm.root.children;
      if (t.length == 0)
         return;
      for (int i = 0; i < t.length; i++)
      {
         marked[i] = t[i];
         marks++;
      }
      aw.mm.enable(FILE_PRINT);
      aw.mm.enable(FILE_PRINTIMMEDIATE);
      queueDraw();
   }

   void placeOne()
   {
      marks = 0;
      marked[] = null;
      ACBase[] t = aw.tm.root.children;
      if (t.length == 0)
         return;
      marked[0] = t[0];
      marks = 1;
      aw.mm.enable(FILE_PRINT);
      aw.mm.enable(FILE_PRINTIMMEDIATE);
      queueDraw();
   }

   void fillSequence()
   {
      marks = 0;
      marked[] = null;
      ACBase[] t = aw.tm.root.children;
      if (t.length == 0)
         return;
      bool complete = false;
      int n = 0;
      for (;;)
      {
         for (int i = 0; i < t.length; i++)
         {
            marked[n++] = t[i];
            marks++;
            if (n >= marked.length)
            {
               complete = true;
               break;
            }
         }
         if (complete)
            break;
      }
      aw.mm.enable(FILE_PRINT);
      aw.mm.enable(FILE_PRINTIMMEDIATE);
      queueDraw();
   }

   void fillFrom(int n, PlainText[] pts)
   {
      marked[] = null;
      for (int i = 0; i < n; i++)
         marked[i] = pts[i];
   }

   int inRect(double x, double y)
   {
      x /= 0.78;
      y /= 0.78;
      for (int i = 0; i < rects.length; i++)
      {
         CRect r = rects[i];
         if (x >= r.x && x < r.x+r.w && y >= r.y && y < r.y+r.h)
            return i;
      }
      return -1;
   }

   bool mouseClick(Event e, Widget w)
   {
      int n = inRect(e.motion.x, e.motion.y);
      if (n < 0)
      {
         return false;
      }
      if (e.type == GdkEventType.BUTTON_PRESS)
      {
         if (e.button.button == 1)
         {
            marked[n] = aw.getRenderItem();
            marks++;
         }
         else if (e.button.button == 3)
         {
            marked[n] = null;
            marks--;
         }
         queueDraw();
         aw.mm.setState(FILE_PRINT, marks);
         aw.mm.setState(FILE_PRINTIMMEDIATE, marks);
         return true;
      }
      return false;
   }

   bool drawCallback(Context plc, Widget widget)
   {
      plc.scale(0.78, 0.78);
      int n = marked.length;

      // Render the marked items
      for (int i = 0; i < n; i++)
      {
         if (marked[i] !is null)
         {
            if (marked[i].type == AC_CONTAINER)
            {
               plc.save();
               Surface s = aw.renderCtrForPL(marked[i], plc);
               plc.setSourceSurface(s, rects[i].x, rects[i].y);
               // Set a clipping rectangle so any badly behaved type don't hang out of the box
               plc.rectangle(rects[i].x, rects[i].y, rects[i].w, rects[i].h);
               plc.clip();  // This removes the rectangle
               plc.paint();
               plc.restore();
            }
            else
            {
               plc.save();
               plc.rectangle(rects[i].x, rects[i].y, rects[i].w, rects[i].h);
               plc.clip();
               marked[i].renderToPL(plc, rects[i].x, rects[i].y);
               plc.restore();
            }
         }
         else
         {
            plc.save();
            plc.rectangle(rects[i].x, rects[i].y, rects[i].w, rects[i].h);
            plc.setSourceRgb(1,1,1);
            plc.fill();
            plc.restore();
         }
      }

      plc.setLineWidth(0.5);
      drawOutlines(plc);
      if (aw.drawCropMarks)
         drawCropMarks(plc);

      return true;
   }

   void drawSequence(Context plc)
   {
      foreach (int i, CRect r; rects)
      {
         if (round[i])
            plc.arc(r.x+r.w/2, r.y+r.h/2, r.w/2, 0, 2*PI);
         else
         {
            plc.moveTo(r.x, r.y);
            plc.lineTo(r.x, r.y+r.h);
            plc.lineTo(r.x+r.w, r.y+r.h);
            plc.lineTo(r.x+r.w, r.y);
            plc.closePath();
         }
         plc.stroke();
      }
   }

   void drawCircles(Context plc)
   {
      foreach (int i, CRect r; rects)
      {
         plc.arc(r.x+r.w/2, r.y+r.h/2, r.w/2, 0, 2*PI);
         plc.stroke();
      }
   }

   void drawOutlines(Context plc)
   {
      plc.setSourceRgb(0,0,0);
      plc.setLineWidth(0.5);
      if (isSeq)
         drawSequence(plc);
      else if (isRound)
         drawCircles(plc);
      else
      {
         if (hSpaced && vSpaced)
            drawBoxes(plc);
         else if (hSpaced)
            drawLadders(plc, true);
         else if (vSpaced)
            drawLadders(plc, false);
         else
            drawGrid(plc);
      }
   }

   void drawBoxes(Context plc)
   {
      foreach (int i, CRect r; rects)
      {
         plc.moveTo(r.x, r.y);
         plc.lineTo(r.x, r.y+r.h);
         plc.lineTo(r.x+r.w, r.y+r.h);
         plc.lineTo(r.x+r.w, r.y);
         plc.closePath();
         plc.stroke();
      }
   }

   void drawGrid(Context plc)
   {
      double off = grid.topx;
      double start = grid.topy;
      double end = start+grid.rows*grid.h;
      for (int i = 0; i <= grid.cols; i++)
      {
         plc.moveTo(off, start);
         plc.lineTo(off, end);
         plc.stroke();
         off += grid.w;
      }
      off = grid.topy;
      start = grid.topx;
      end = start+grid.cols*grid.w;
      for (int i = 0; i <= grid.rows; i++)
      {
         plc.moveTo(start, off);
         plc.lineTo(end, off);
         plc.stroke();
         off += grid.h;
      }
   }

   void drawLadders(Context plc, bool colwise)
   {
      double off;
      double start;
      double end;
      double rstart, rend;
      if (colwise)
      {
         off = grid.topx;
         start = grid.topy;
         end = start+grid.rows*grid.h;
         rstart = off;
         rend = off+grid.w;
         for (int i = 0; i < grid.cols; i++)
         {
            plc.moveTo(off, start);
            plc.lineTo(off, end);
            plc.stroke();
            plc.moveTo(off+grid.w, start);
            plc.lineTo(off+grid.w, end);
            plc.stroke();
            double vpos = start;
            for (int j = 0; j <= grid.rows; j++)
            {
               plc.moveTo(rstart, vpos);
               plc.lineTo(rend, vpos);
               plc.stroke();
               vpos += grid.h;
            }
            off += grid.hstride;
            rstart = off;
            rend = rstart+grid.w;
         }
      }
      else
      {
         off = grid.topy;
         start = grid.topx;
         end = start+grid.cols*grid.w;
         rstart = off;
         rend = off+grid.h;
         for (int i = 0; i < grid.rows; i++)
         {
            plc.moveTo(start, off);
            plc.lineTo(end, off);
            plc.stroke();
            plc.moveTo(start, off+grid.h);
            plc.lineTo(end, off+grid.h);
            plc.stroke();
            double hpos = start;
            for (int j = 0; j <= grid.cols; j++)
            {
               plc.moveTo(hpos, rstart);
               plc.lineTo(hpos, rend);
               plc.stroke();
               hpos += grid.w;
            }
            off += grid.vstride;
            rstart = off;
            rend = rstart+grid.h;
         }
      }
   }

   void drawCropMarks(Context plc)
   {
      plc.setLineWidth(0.5);
      double off, start, end;
      if (hSpaced && vSpaced)
      {
         // horizontal marks down the left side
         off = grid.topy;
         start = 0;
         end = start+grid.topx;
         for (int i = 0; i <= grid.rows; i++)
         {
            plc.moveTo(start, off);
            plc.lineTo(end, off);
            if (i > 0 && i < grid.rows)
            {
               double t = off+grid.vstride-grid.h;
               plc.lineTo(end, t);
               plc.lineTo(start, t);
            }
            plc.stroke();
            off += i? grid.vstride: grid.h;
         }
         // horizontal marks down the right side
         off = grid.topy;
         start = grid.topx+(grid.cols-1)*grid.hstride+grid.w;
         end = plpW;
         for (int i = 0; i <= grid.rows; i++)
         {
            plc.moveTo(end, off);
            plc.lineTo(start, off);
            if (i > 0 && i < grid.rows)
            {
               double t = off+grid.vstride-grid.h;
               plc.lineTo(start, t);
               plc.lineTo(end, t);
            }
            plc.stroke();
            off += i? grid.vstride: grid.h;
         }
         // vertical marks across top
         off = grid.topx;
         start = 0;
         end = start+grid.topy;
         for (int i = 0; i <= grid.cols; i++)
         {
            plc.moveTo(off, start);
            plc.lineTo(off, end);
            plc.stroke();
            if (i > 0 && i < grid.cols)
            {
               double t = off+grid.hstride-grid.w;
               plc.moveTo(t, start);
               plc.lineTo(t, end);
               plc.stroke();
            }
            off += i? grid.hstride: grid.w;
         }
         // vertical marks across bottom
         off = grid.topx;
         start = grid.topy+(grid.rows-1)*grid.vstride+ grid.h;
         end = plpH;
         for (int i = 0; i <= grid.cols; i++)
         {
            plc.moveTo(off, start);
            plc.lineTo(off, end);
            plc.stroke();
            if (i > 0 && i < grid.cols)
            {
               double t = off+grid.hstride-grid.w;
               plc.moveTo(t, start);
               plc.lineTo(t, end);
               plc.stroke();
            }
            off += i? grid.hstride: grid.w;
         }
         // boxes at the intersections
         off = grid.topy;
         start = grid.topx+grid.w;
         end = grid.topx+grid.hstride;
         double dv = grid.vstride-grid.h;
         for (int i = 0; i <= grid.rows; i++)
         {
            double ts = start, te = end;
            for (int j = 0; j < grid.cols-1; j++)
            {
               if (i == 0)
               {
                  plc.moveTo(ts, off);
                  plc.lineTo(te, off);
                  plc.stroke();
               }
               else if (i == grid.rows)
               {
                  plc.moveTo(ts, off-dv);
                  plc.lineTo(te, off-dv);
                  plc.stroke();
               }
               else
               {
                  plc.moveTo(ts, off);
                  plc.lineTo(te, off);
                  plc.lineTo(te, off-dv);
                  plc.lineTo(ts, off-dv);
                  plc.closePath();
                  plc.stroke();
               }
               ts += grid.hstride;
               te += grid.hstride ;
            }
            off += grid.vstride;
         }
      }
      else if (hSpaced)
      {
         // horizontal marks down left side
         off = grid.topy;
         start = 0;
         end = start+grid.topx;
         for (int i = 0; i <= grid.rows; i++)
         {
            plc.moveTo(start, off);
            plc.lineTo(end, off);
            plc.stroke();
            off += grid.h;
         }
         // horizontal marks down right side
         off = grid.topy;
         start = grid.topx+(grid.cols-1)*grid.hstride+grid.w;
         end = plpW;
         for (int i = 0; i <= grid.rows; i++)
         {
            plc.moveTo(start, off);
            plc.lineTo(end, off);
            plc.stroke();
            off += grid.h;
         }
         // vertical marks across top
         off = grid.topx;
         start = 0;
         end = start+grid.topy;
         for (int i = 0; i <= grid.cols; i++)
         {
            plc.moveTo(off, start);
            plc.lineTo(off, end);
            plc.stroke();
            if (i > 0 && i < grid.cols)
            {
               double t = off+grid.hstride-grid.w;
               plc.moveTo(t, start);
               plc.lineTo(t, end);
               plc.stroke();
            }
            off += i? grid.hstride: grid.w;
         }
         // vertical marks across bottom
         off = grid.topx;
         start = grid.topy+grid.rows*grid.h;
         end = plpH;
         for (int i = 0; i <= grid.cols; i++)
         {
            plc.moveTo(off, start);
            plc.lineTo(off, end);
            plc.stroke();
            if (i > 0 && i < grid.cols)
            {
               double t = off+grid.hstride-grid.w;
               plc.moveTo(t, start);
               plc.lineTo(t, end);
               plc.stroke();
            }
            off += i? grid.hstride: grid.w;
         }
         // horizontal lines in the spaces between the columns
         off = grid.topy;
         start = grid.topx+grid.w;
         end = grid.topx+grid.hstride;
         for (int i = 0; i <= grid.rows; i++)
         {
            double ts = start, te = end;
            for (int j = 0; j < grid.cols-1; j++)
            {
               plc.moveTo(ts, off);
               plc.lineTo(te, off);
               plc.stroke();
               ts += grid.hstride;
               te += grid.hstride ;
            }
            off += grid.h;
         }
      }
      else if (vSpaced)
      {
         // vertical marks across the top
         off = grid.topx;
         start = 0;
         end = start+grid.topy;
         for (int i = 0; i <= grid.cols; i++)
         {
            plc.moveTo(off, start);
            plc.lineTo(off, end);
            plc.stroke();
            off += grid.w;
         }
         // vertical marks across the bottom
         off = grid.topx;
         start = grid.topy+(grid.rows-1)*grid.vstride+grid.h;
         end = plpH;
         for (int i = 0; i <= grid.cols; i++)
         {
            plc.moveTo(off, start);
            plc.lineTo(off, end);
            plc.stroke();
            off += grid.w;
         }
         // horizontal marks down the left side
         off = grid.topy;
         start = 0;
         end = start+grid.topx;
         for (int i = 0; i <= grid.rows; i++)
         {
            plc.moveTo(start, off);
            plc.lineTo(end, off);
            plc.stroke();
            if (i > 0 && i < grid.rows)
            {
               double t = off+grid.vstride-grid.h;
               plc.moveTo(start, t);
               plc.lineTo(end, t);
               plc.stroke();
            }
            off += i? grid.vstride: grid.h;
         }
         // horizontal marks down the right side
         off = grid.topy;
         start = grid.topx+grid.cols*grid.w;
         end = plpW;
         for (int i = 0; i <= grid.rows; i++)
         {
            plc.moveTo(start, off);
            plc.lineTo(end, off);
            plc.stroke();
            if (i > 0 && i < grid.rows)
            {
               double t = off+grid.vstride-grid.h;
               plc.moveTo(start, t);
               plc.lineTo(end, t);
               plc.stroke();
            }
            off += i? grid.vstride: grid.h;
         }
         // vertical lines in the spaces between the rows
         off = grid.topx;
         start = grid.topy+grid.h;
         end = grid.topy+grid.vstride;
         for (int i = 0; i <= grid.cols; i++)
         {
            double ts = start, te = end;
            for (int j = 0; j < grid.rows-1; j++)
            {
               plc.moveTo(off, ts);
               plc.lineTo(off, te);
               plc.stroke();
               ts += grid.vstride;
               te += grid.vstride ;
            }
            off += grid.w;
         }
      }
      else
      {
         // horizontal marks down left side
         off = grid.topy;
         start = 0;
         end = start+grid.topx;
         for (int i = 0; i <= grid.rows; i++)
         {
            plc.moveTo(start, off);
            plc.lineTo(end, off);
            plc.stroke();
            off += grid.h;
         }
         // horizontal marks down right side
         off = grid.topy;
         start = grid.topx+grid.cols*grid.w;
         end = plpW;
         for (int i = 0; i <= grid.rows; i++)
         {
            plc.moveTo(start, off);
            plc.lineTo(end, off);
            plc.stroke();
            off += grid.h;
         }
         // vertical marks across top
         off = grid.topx;
         start = 0;
         end = grid.topy;
         for (int i = 0; i <= grid.cols; i++)
         {
            plc.moveTo(off, start);
            plc.lineTo(off, end);
            plc.stroke();
            off += grid.w;
         }
         // vertical marks across bottom
         off = grid.topx;
         start = grid.topy+grid.rows*grid.h;
         end = plpH;
         for (int i = 0; i <= grid.cols; i++)
         {
            plc.moveTo(off, start);
            plc.lineTo(off, end);
            plc.stroke();
            off += grid.w;
         }
      }
   }


   void renderToPrinter(Context c)
   {
      for (int i = 0; i < marked.length; i++)
      {
         if (marked[i] !is null)
         {
            c.save();
            marked[i].printFlag = true;
            if (marked[i].type == AC_CONTAINER)
            {
               aw.renderCtrToPL(marked[i], c, rects[i].x, rects[i].y);
            }
            else
               marked[i].renderToPL(c, rects[i].x, rects[i].y);
            marked[i].printFlag = false;
            c.restore();
         }
      }
      c.setLineWidth(0.5);
      if (aw.drawOutlines)
         drawOutlines(c);
      if (aw.drawCropMarks)
         drawCropMarks(c);
   }
}
