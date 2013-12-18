
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module treeops;

import tree;
import main;
import treeops;
import acomp;
import sheets;

import std.stdio;
import gtk.TreeView;
import gtk.TreePath;
import gtk.TreeIter;
import gtk.TreeSelection;
import gtk.TreeViewColumn;
import gtk.CellRendererText;
import gtk.CellRendererToggle;

struct DeletedItem
{
   ACBase item;
   string lastPos;
}

class TreeOps
{
   AppWindow aw;
   ACTreeModel tm;
   TreeView tv;
   TreeSelection ts;
   DeletedItem[20] diStack;
   int diTop;

   this(AppWindow w)
   {
      aw = w;
      diTop = -1;
   }

   ACTreeModel getModel()
   {
      return tm;
   }

   void pushDeleted(ACBase acb, TreePath tp)
   {
      DeletedItem di;
      di.item = acb;
      di.lastPos = tp.toString();

      if (diTop < 19)
      {
         diTop++;
         diStack[diTop] = di;
      }
      else
      {
         for (int i = 0; i < 19; i++)
            diStack[i] = diStack[i+1];
         diStack[diTop] = di;
      }
   }

   DeletedItem popDeleted()
   {
      DeletedItem di;
      di.item = null;
      if (diTop < 0)
      {
         string msg = "Sorry, no objects deleted from the tree view are available.\n\n";
         msg ~= "(If you meant to undo an action on the current object, return the focus to the object ";
         msg ~= "by clicking in the item name box in the right pane.)";
         aw.popupMsg(msg, MessageType.INFO);
         return di;
      }
      di = diStack[diTop--];
      return di;
   }


   TreePath getPath(ACBase acb)
   {
      int ctr, item;
      TreePath tp = new TreePath();
      if (acb.parent is tm.root)
      {
         foreach (int i, ACBase t; tm.root.children)
         {
            if (t is acb)
            {
               tp.appendIndex(i);
               break;
            }
         }
      }
      else
      {
         ACBase p = acb.parent;
         foreach (int i, ACBase t; tm.root.children)
         {
            if (t is p)
            {
               tp.appendIndex(i);
               break;
            }
         }
         foreach (int i, ACBase t; p.children)
         {
            if (t is acb)
            {
               tp.appendIndex(i);
               break;;
            }
         }
      }
      return tp;
   }

   void notifyDeletion(TreePath tp)
   {
      tm.rowDeleted(tp);
   }

   void notifyDeletion(ACBase acb)
   {
      TreePath tp = getPath(acb);
      tm.rowDeleted(tp);
   }

   void notifyInsertion(ACBase acb, string ep = null)
   {
      TreePath tp;
      if (ep is null)
         tp = getPath(acb);
      else
         tp = new TreePath(ep);

      TreeIter iter = new TreeIter();
      iter.userData = cast(void*) acb;
      iter.stamp = tm.stamp;

      tm.rowInserted(tp, iter);
   }

   void notifyChange(ACBase acb)
   {
      TreePath tp = getPath(acb);

      TreeIter iter = new TreeIter();
      iter.userData = cast(void*) acb;
      iter.stamp = tm.stamp;

      tm.rowChanged(tp, iter);
   }

   TreeView createViewAndModel(int initType, double cWidth, double cHeight)
   {
      TreeViewColumn   col;
      CellRendererText renderer;
      CellRendererToggle rtog;
      tm = new ACTreeModel(aw, cast(int) cWidth, cast(int) cHeight);
      aw.tm = tm;

      tv = new TreeView(tm);
      tv.modifyFont("", 9);
      ts = tv.getSelection();
      tv.setEnableTreeLines(1);
      //tv.setActivateOnSingleClick(1);

      col = new TreeViewColumn();
      rtog  = new CellRendererToggle();
rtog.setPadding(2, 0);
      //rtog.setFixedSize(-1, 15);
      col.packStart(rtog, false);
      col.addAttribute(rtog, "active", 0);
      col.setTitle("Active");
      tv.appendColumn(col);

      col = new TreeViewColumn();
      renderer  = new CellRendererText();
      //renderer.setFixedSize(-1, 15);
      col.packStart(renderer, true);
      col.addAttribute(renderer, "text", 1);
      col.setTitle("Type");
      tv.appendColumn(col);

      col = new TreeViewColumn();
      renderer  = new CellRendererText();
renderer.setPadding(2, 0);
      //renderer.setFixedSize(-1, 15);
      col.packStart(renderer, true);
      col.addAttribute(renderer, "text", 2);
      col.setTitle("Name");
      tv.appendColumn(col);

      if (initType >= 0)
      {
         ACBase acb = aw.createItem(initType, aw.RelTo.ROOT);
         tm.root.children ~= acb;
         notifyInsertion(acb, "0");
      }


      tv.addOnCursorChanged(&aw.onCursorChanged);;
      tv.addOnButtonPress(&aw.onTreeClick);


      return tv;
   }

   void expand(ACBase acb)
   {
      TreeIter ti = new TreeIter();
      ti.userData = cast(void*) acb;
      ti.stamp = tm.stamp;

      tv.expandRow(ti, tm, 1);
   }

   void select(ACBase acb)
   {
      TreeIter ti = new TreeIter();
      ti.userData = cast(void*) acb;
      ti.stamp = tm.stamp;

      ts.selectIter(ti);
      tv.expandRow(ti, tm, 1);
   }
}
