module interfaces;

import std.math;

import types;

import controlset;
import gtk.Widget;
import gtk.Entry;
import cairo.Context;

// Modifications to COMPO layer objects are made using a ControlSet.
// ControlSets send messages to their host as follows:
interface CSTarget
{
   void setNameEntry(Entry e);
   // Plain GTK Widgets in the ControlSet will notify the taget
   // using this.
   void onCSNotify(Widget w, Purpose p);

   // There may be many instances of the MoreLess tool. The latter merely
   // reports which instance was used, and whether is asked for more
   // or less. Coarse if true means move more vigorously.
   void onCSMoreLess(int instance, bool more, bool coarse);

   // There may be several instances of the InchTool in a
   // ControlSet. The directions have no logic west, north,
   // east, south.
   string onCSInch(int instance, int direction, bool coarse);

   // There may be several instances of the Compass in a
   // ControlSet. The Compass reports an angle, starting from
   // three o'clock.
   void onCSCompass(int instance, double angle, bool coarse);

   // This one is rather COMPO specific. It reports a changed line thickness
   void onCSLineWidth(double lw);

   // Tells the target is should make a note of any selection that may be
   // relevant, since this may be changed by a pending operation.
   void onCSSaveSelection();

   // Tells the target that some text parameter has been changed.
   void onCSTextParam(Purpose p, string sval, int ival);

   // Tells the target to change some string
   void onCSNameChange(string s);
}
