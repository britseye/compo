
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module textsrc;

import std.stream;
import std.conv;
import std.path;
import std.stdio;
import std.array;
import main;
import merger;

class COMPOSrc: MergeSource
{
   AppWindow aw;
   string fileName;
   string[][] result;
   InputStream si;
   string line;
   int lineNum;
   string errMsg;
   string delim;
   int cols, perPage;

   this (AppWindow w, string fName, string delimiter = "|^~|")
   {
      aw = w;
      fileName = fName;
      delim = delimiter;
      lineNum = 0;
      si = new std.stream.File(fileName, FileMode.In);
      line = getLine();
      if (line is null)
      {
         errMsg = "The file is empty or has a blank line";
         return;
      }
      try
      {
         parseFirstLine();
      }
      catch (Exception x)
      {
         errMsg = x.msg;
         return;
      }
   }

   string getLine()
   {
      string s = cast(string) si.readLine();
      if (s is null || s.length == 0)
         return null;
      lineNum++;
      return s;
   }

   void parseFirstLine()
   {
      string[] atemp = cast(string[]) split(line, delim);
      cols = atemp.length;
      result ~= atemp;
   }

   string[][] parseSubsequentLines(int n)
   {
      for (int i = 0; i < n; i++)
      {
         line = getLine();
         if (line is null || line.length == 0)
            return result;
         string[] atemp = cast(string[]) split(line, delim);
         int k = atemp.length;
         if (k > cols)
         {
            errMsg = "Too many items in row";
            return null;
         }
         if (k < cols)
         {
            for (; k < cols; k++)
               atemp ~= "".idup;
         }
         result ~= atemp;
      }
      return result;
   }

   void setPerPage(int n)
   {
      perPage = n;
   }
   void setCols(int n)
   {
      cols = n;
   }

   string[] getFirstLine()
   {
      return result[0];
   }

   int getColumns()
   {
      return cols;
   }

   string[][] getNextPage(bool skipFirst)
   {
      result.length = 0;
      if (lineNum == 0 && skipFirst)
         getLine();
      parseSubsequentLines(perPage);
      return result;
   }

   bool valid()
   {
      return (errMsg is null);
   }
   string getFailReason()
   {
      return "Line "~to!string(lineNum+1)~": "~errMsg;
   }
   void disconnect()
   {
      if (si !is null) (cast(std.stream.File) si).close();
      si = null;
   }
}
