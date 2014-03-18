module cairox;

import types;
import cairo.Context;

void moveToP(Context c, Coord p) { c.moveTo(p.x, p.y); }
void lineToP(Context c, Coord p) { c.lineTo(p.x, p.y); }

void curveToPI(Context c, PathItem pi) { c.curveTo(pi.cp1.x, pi.cp1.y, pi.cp2.x, pi.cp2.y, pi.end.x, pi.end.y); }
void curveToPI(Context c, PathItemR pi) { c.curveTo(pi.cp1.x, pi.cp1.y, pi.cp2.x, pi.cp2.y, pi.end.x, pi.end.y); }

void curve(Context c, PathItem pi)
{
   c.moveTo(pi.start.x, pi.start.y);
   curveToPI(c, pi);
}

void curve(Context c, PathItemR pi)
{
   c.moveTo(pi.start.x, pi.start.y);
   curveToPI(c, pi);
}

void arcP(Context c, Coord p, double radius, double sa, double ea)
{
   c.arc(p.x, p.y, radius, sa, ea);
}

void arcNegativeP(Context c, Coord p, double radius, double sa, double ea)
{
   c.arcNegative(p.x, p.y, radius, sa, ea);
}

