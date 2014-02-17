
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module tree;

import mainwin;
import acomp;

import std.stdio;
import std.random;
import gobject.Value;
import gtk.TreeIter;
import gtk.TreePath;
import gtk.TreeModel;

class ACTreeModel : TreeModel
{
   AppWindow aw;
   ACBase root;
   int stamp;

   public this(AppWindow _aw, int w, int h)
   {
      aw = _aw;
      root = new ACBase(null, null, "<root>", AC_ROOT);
      root.width = w;
      root.height = h;
      stamp = uniform(0, int.max);
   }

   /*
    * tells the rest of the world whether our tree model
    * has any special characteristics. In our case, each
    * tree iter is valid as long as the row in question
    * exists, as it only contains a pointer to our struct.
    */
   override GtkTreeModelFlags getFlags()
   {
      ACBase t = root;
      return (GtkTreeModelFlags.ITERS_PERSIST);
   }


   /*
    * tells the rest of the world how many data
    * columns we export via the tree model interface
    */

   override int getNColumns()
   {
      return 3;
   }

   /*
    * tells the rest of the world which type of
    * data an exported model column contains
    */
   override GType getColumnType(int index)
   {
      ACBase t = root;
      if ( index >= 3 || index < 0 )
         return GType.INVALID;

      if (index == 2)
         return GType.INT;

      return GType.STRING;
   }

   /*
    * converts a tree path (physical position) into a
    * tree iter structure (the content of the iter
    * fields will only be used internally by our model).
    * We simply store a pointer to our ACBase object
    * that represents that row in the tree iter.
    */
   override int getIter(TreeIter iter, TreePath path)
   {
      int[] indices = path.getIndices();
      size_t len = indices.length;

      ACBase target, current = root;
      ACBase[] cl = current.children;
      if (!cl.length)
         return 0;
      int n;

      for (int i = 0; i < len; i++)
      {
         n = indices[i];
         if (n > cl.length-1)
            return 0;
         if (i == len-1)
         {
            target = cl[n];
            break;
         }
         current = cl[n];
         cl = current.children;
      }

      // We simply store a pointer to the relevant ACBase object in the iter
      iter.stamp = stamp;
      iter.userData  = cast(void*) target;

      return 1;
   }


   /*
    * converts a tree iter into a tree path (ie. the
    * physical position of that row in the list).
    */
   override TreePath getPath(TreeIter iter)
   {

      if ( iter is null || iter.userData is null)
         throw new Exception("Bad TreeIterator - null, or null data");
      ACBase item = cast(ACBase) iter.userData;

      if (item.type == AC_ROOT)
         throw new Exception("Path for root object requested");
      int[] seq;
      for (;;)
      {
         ACBase parent = item.parent;
         foreach (int i, ACBase x; parent.children)
         {
            if (x is item)
            {
               seq ~= i;
               item = parent;
               break;
            }
         }
         if (item.type == AC_ROOT)
            break;
      }

      TreePath path = new TreePath();
      for (int i = cast(int) seq.length-1; i >= 0; i--)
      {
         path.appendIndex(seq[i]);
      }

      return path;
   }


   /*
    * Returns a row's exported data columns
    * (_get_value is what gtk_tree_model_get uses)
    */

   override Value getValue(TreeIter iter, int column, Value value)
   {
      if ( iter is null || iter.userData is null || column >= 3 )
         return null;

      ACBase item = cast(ACBase) iter.userData;

      switch(column)
      {
      case 0:
         value.init(GType.BOOLEAN);
         value.setBoolean(item.isActiveChild);
         break;

      case 1:
         value.init(GType.STRING);
         value.setString(item.typeName);
         break;

      case 2:
         value.init(GType.STRING);
         value.setString(item.name);
         break;
      default:
         break;
      }

      return value;
   }


   /*
    * Takes an iter structure and sets it to point
    * to the next row.
    */
   override int iterNext(TreeIter iter)
   {
      if ( iter is null || iter.userData is null )
         return 0;

      ACBase item = cast(ACBase) iter.userData;
      ACBase r = root;

      if (item is r)
         throw new Exception("Tree iterator refers to tree store root");
      ACBase parent = item.parent;
      ACBase[] a = parent.children;
      size_t len = a.length;
      for (size_t i = 0; i < a.length; i++)
      {
         if (a[i] is item)
         {
            if (i < a.length-1)
            {
               iter.userData = cast(void*) a[i+1];
               iter.stamp = stamp;
               return 1;
            }
         }
      }
      return 0;
   }


   /*
    * Returns TRUE or FALSE depending on whether
    * the row specified by 'parent' has any children.
    * If it has children, then 'iter' is set to
    * point to the first child. Special case: if
    * 'parent' is NULL, then the first top-level
    * row should be returned if it exists.
    */

   override int iterChildren(TreeIter iter, TreeIter parent)
   {
      if (parent is null)
      {
         if (root.children.length)
         {
            ACBase item = root.children[0];
            iter.stamp = stamp;
            iter.userData = cast(void*) item;
            return 1;
         }
         return 0;
      }
      ACBase item = cast(ACBase) parent.userData;
      if (item.children.length)
      {
         item = item.children[0];
         iter.stamp = stamp;
         iter.userData = cast(void*) item;
         return 1;
      }
      return 0;
   }


   /*
    * Returns TRUE or FALSE depending on whether
    * the row specified by 'iter' has any children.
    */
   override int iterHasChild(TreeIter iter)
   {
      if (iter is null || iter.userData is null)
         return 0;
      ACBase item = cast(ACBase) iter.userData;
      return item.children.length? 1: 0;
   }


   /*
    * Returns the number of children the row
    * specified by 'iter' has. This is usually 0,
    * as we only have a list and thus do not have
    * any children to any rows. A special case is
    * when 'iter' is NULL, in which case we need
    * to return the number of top-level nodes,
    * ie. the number of rows in our list.
    */
   override int iterNChildren(TreeIter iter)
   {
      /* special case: if iter == NULL, return number of top-level rows */
      if ( iter is null )
         return cast(int) root.children.length;

      ACBase item = cast(ACBase) iter.userData;
      return cast(int) item.children.length;
   }


   /*
    * If the row specified by 'parent' has any
    * children, set 'iter' to the n-th child and
    * return TRUE if it exists, otherwise FALSE.
    * A special case is when 'parent' is NULL, in
    * which case we need to set 'iter' to the n-th
    * top level row if it exists.
    */
   override int iterNthChild(TreeIter iter, TreeIter parent, int n)
   {
      if( parent is null ) // return nth top level item
      {
         if (n < root.children.length)
         {
            iter.userData = cast(void*) root.children[n];
            iter.stamp = stamp;
            return 1;
         }
         return 0;
      }

      ACBase item = cast(ACBase) parent.userData;
      if (n < item.children.length  && n >= 0)
      {
         iter.userData = cast(void*) item.children[n];
         iter.stamp = stamp;
         return 1;
      }
      return 0;
   }


   /*
    * Point 'iter' to the parent node of 'child'.
    */
   override int iterParent(TreeIter iter, TreeIter child)
   {
      ACBase item = cast(ACBase) child.userData;
      if (item.parent.type == AC_ROOT)
         return false;
      iter.userData = cast(void*) item.parent;
      iter.stamp = stamp;
      return true;
   }

   void addInitial(ACBase ii)
   {
      root.children ~= ii;
      TreePath tp = new TreePath();
      tp.appendIndex(0);

      TreeIter iter = new TreeIter();
      iter.userData = cast(void*) ii;
      iter.stamp = stamp;

      rowInserted(tp, iter);
   }

   void appendRoot(ACBase nc)
   {
      root.children ~= nc;
      nc.parent = root;
      TreePath tp = new TreePath();
      tp.appendIndex(cast(int) root.children.length-1);

      TreeIter iter = new TreeIter();
      iter.userData = cast(void*) nc;
      iter.stamp = stamp;

      rowInserted(tp, iter);
      if (nc.type == AC_CONTAINER)
      {
         foreach (ref ACBase child; nc.children)
            aw.treeOps.notifyInsertion(child);
      }
   }

   void insertRoot(ACBase nc, ACBase relto, bool rel)
   {
      int index = ACBase.insertChild(relto, nc, rel);
      nc.parent = root;
      TreePath tp = new TreePath();
      tp.appendIndex(index+1);

      TreeIter iter = new TreeIter();
      iter.userData = cast(void*) nc;
      iter.stamp = stamp;

      rowInserted(tp, iter);
      if (nc.type == AC_CONTAINER)
      {
         foreach (ref ACBase child; nc.children)
            aw.treeOps.notifyInsertion(child);
      }
   }

   TreeIter tiFromACBase(ACBase x)
   {
      TreeIter iter = new TreeIter();
      iter.userData = cast(void*) x;
      iter.stamp = stamp;
      return iter;
   }
}
