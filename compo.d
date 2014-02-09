
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module compo;

import mainwin;
import gtk.Main;
import gtk.MainWindow;

void main(string[] arg)
{
   Main.init(arg);

   new AppWindow();
   Main.run();
}

