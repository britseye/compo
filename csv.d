
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module csv;

import std.stream;
import std.conv;
import std.path;
import std.stdio;
import std.array;
import main;
import merger;

import gtkc.gtktypes;

class CSVArray: MergeSource
{
   AppWindow aw;
   string fileName;
   string[][] result;
   InputStream si;
   char[] line;
   int lineNum;
   string errMsg;
   int cols, perPage;

   this (AppWindow w, string fName)
   {
      aw = w;
      fileName = fName;
      lineNum = 1;
      si = new std.stream.File(fileName, FileMode.In);
      line = si.readLine();
      if (si is null)
      {
         errMsg = "The file is empty";
         notifyException();
      }
      try
      {
         parseFirstLine();
      }
      catch (Exception x)
      {
         errMsg = x.msg;
         notifyException();
         return;
      }
   }

   void notifyException()
   {
      string msg = "CSV file exception, " ~ fileName ~", line " ~ to!string(lineNum) ~":\n" ~ errMsg;
      aw.popupMsg(msg, MessageType.ERROR);
   }

   void parseFirstLine()
   {
      string[] atemp;
      char[] temp;
      bool inQ = false;
      bool commaFound = false;
      char *p = line.ptr;
      char* prev;
      char* end;
      int ll;
      end = p+line.length;
      if (*p != '"')
         throw new Exception("Expected quote at beginning of line");
      temp.length = line.length;
      ll = 0;
      p++;
      prev = p;
      inQ = true;
      for (; p < end; p++)
      {
         if (inQ)
         {
            switch (*p)
            {
            case '\\':
               if (*(p+1) =='\\')
               {
                  temp[ll++] = '\\';
                  p++;
               }
               else if (*(p+1) == '"')
               {
                  temp[ll++] = '"';
                  p++;
               }
               else
                  throw new Exception("Orphaned backslash");
               break;
            case '"':
               atemp ~= cast(string) temp[0..ll].dup;
               ll = 0;
               inQ = false;
               commaFound = false;
               break;
            default:
               temp[ll++] = *p;
               break;
            }
         }
         else
         {
            if (*p == ' ' || *p == '\t')
               continue;
            else if (*p == ',')
            {
               if (commaFound)
                  throw new Exception("Consequtive commas");
               commaFound = true;
               continue;
            }
            else if (*p == '"')
               inQ = true;
            else
            {
               throw new Exception("Extraneous character between items");
            }
         }
      }
      cols = atemp.length;
      result ~= atemp;
   }

   void parseSubsequentLines()
   {
      string[] atemp;
      atemp.length = cols;
      char[] temp;
      bool inQ = false;
      bool commaFound = false;
      char *p = line.ptr;
      char* prev;
      char* end;
      int ll;
      end = p+line.length;
      if (*p != '"')
         throw new Exception("Expected quote at beginning of line");
      temp.length = line.length;
      ll = 0;
      p++;
      prev = p;
      inQ = true;
      int n = 0;
      for (; p < end; p++)
      {
         if (inQ)
         {
            switch (*p)
            {
            case '\\':
               if (*(p+1) =='\\')
               {
                  temp[ll++] = '\\';
                  p++;
               }
               else if (*(p+1) == '"')
               {
                  temp[ll++] = '"';
                  p++;
               }
               else
                  throw new Exception("Orphaned backslash");
               break;
            case '"':
               if (n >= cols)
                  throw new Exception("Number of columns in line "~to!string(lineNum)~" greater than in first row.");
               atemp[n++] = cast(string) temp[0..ll].dup;
               ll = 0;
               inQ = false;
               commaFound = false;
               break;
            default:
               temp[ll++] = *p;
               break;
            }
         }
         else
         {
            if (*p == ' ' || *p == '\t')
               continue;
            else if (*p == ',')
            {
               if (commaFound)
                  throw new Exception("Consequtive commas");
               commaFound = true;
               continue;
            }
            else if (*p == '"')
               inQ = true;
            else
            {
               throw new Exception("Extraneous character between items");
            }
         }
      }
      for (; n < cols; n++)
         atemp[n] = "";
      result ~= atemp;
   }

   /*
   interface MergeSource
   {
      void setPerPage(int n);
      string[] getFirstLine();
      int getColumns();
      string[][] getNextPage();
      bool valid();
      string getFailReason();
   }
   */
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

   string[][] getNextPage(bool skipFirstLine)
   {
      return null;
   }

   bool valid()
   {
      return (errMsg is null);
   }
   string getFailReason()
   {
      return errMsg;
   }

   void disconnect()
   {
      if (si !is null) (cast(std.stream.File) si).close();
   }
}

