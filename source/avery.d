
//          Copyright Steve Teale 2011.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

// Written in the D programming language
module avery;

import std.stdio;
import sheets;

class AveryISO : Portfolio
{
   Sheet[] sheets;
   this()
   {
      Grid g;
      Sheet s;

      /*
      <Template brand="Avery" part="7160" size="A4" _description="Mailing labels">
       <Meta category="label"/>
       <Meta category="mail"/>
       <Label-rectangle id="0" width="181.4" height="108.0" round="5">
         <Markup-margin size="5"/>
         <Layout nx="3" ny="7" x0="21.2" y0="43.9" dx="187.2" dy="108.0"/>
       </Label-rectangle>
      </Template>
      */
      g  = Grid(3, 7, 63.99, 38.1, 7.48, 15.49, 66.04, 38.1, false);
      s = Sheet(true, "Avery", "7160", "Mailing labels", Category.MAILING, Paper.A4, false);
      s.layout.g = g;
      sheets ~= s;
      /*
      <Template brand="Avery" part="7161" size="A4" _description="Mailing labels">
      <Meta category="label"/>
      <Meta category="mail"/>
      <Label-rectangle id="0" width="180.2" height="132.6" round="7">
      <Markup-margin size="5"/>
      <Layout nx="3" ny="6" x0="21" y0="23" dx="186.9" dy="132.5"/>
      </Label-rectangle>
      </Template>
      */
      g  = Grid(3, 6, 63.57, 46.78, 7.41, 8.11, 65.93, 46.78, false);
      s = Sheet(true, "Avery", "7161", "Mailing labels", Category.MAILING, Paper.A4, false);
      s.layout.g = g;
      sheets ~= s;
      /*
      <Template brand="Avery" part="7162" size="A4" _description="Mailing labels">
       <Meta category="label"/>
       <Meta category="mail"/>
       <Label-rectangle id="0" width="280.9" height="96.1" round="5">
         <Markup-margin size="5"/>
         <Layout nx="2" ny="8" x0="11.3" y0="36.8" dx="290.5" dy="96.1"/>
       </Label-rectangle>
      </Template>
      */
      g  = Grid(2, 8, 99.1, 33.9, 3.99, 12.98, 102.62, 33.9, false);
      s = Sheet(true, "Avery", "7162", "Mailing labels", Category.MAILING, Paper.A4, false);
      s.layout.g = g;
      sheets ~= s;
      /*
      <Template brand="Avery" part="7163" size="A4" _description="Mailing labels">
       <Meta category="label"/>
       <Meta category="mail"/>
       <Label-rectangle id="0" width="280.9" height="108" round="5">
         <Markup-margin size="5"/>
         <Layout nx="2" ny="7" x0="9.5" y0="43" dx="292" dy="108"/>
       </Label-rectangle>
      </Template>
      */
      g  = Grid(2, 7, 99.1, 38.1, 3.35, 15.17, 103.01, 38.1, false);
      s = Sheet(true, "Avery", "7163", "Mailing labels", Category.MAILING, Paper.A4, false);
      s.layout.g = g;
      sheets ~= s;
      /*
      <Template brand="Avery" part="7164" size="A4" _description="Address labels">
       <Meta category="label"/>
       <Meta category="mail"/>
       <Label-rectangle id="0" width="180" height="204.038" round="8.5">
         <Markup-margin size="5"/>
         <Layout nx="3" ny="4" x0="20.84" y0="10" dx="187.08" dy="204.038"/>
       </Label-rectangle>
      </Template>
      */
      g  = Grid(3, 4, 63.5, 71.98, 7.35, 3.53, 66.0, 71.78, false);
      s = Sheet(true, "Avery", "7164", "Address labels", Category.MAILING, Paper.A4, false);
      s.layout.g = g;
      sheets ~= s;
      /*
      <Template brand="Avery" part="7165" size="A4" _description="Address Labels">
       <Meta category="label"/>
       <Meta category="mail"/>
       <Label-rectangle id="0" width="280.8pt" height="191.991pt" round="0pt" waste="0pt">
         <Markup-margin size="5.66929pt"/>
         <Layout nx="2" ny="4" x0="13.2378pt" y0="36.9638pt" dx="288.113pt" dy="191.991pt"/>
       </Label-rectangle>
      </Template>
      */
      g  = Grid(2, 4, 99.06, 67.73, 4.67, 13.04, 101.64, 67.73, false);
      s = Sheet(true, "Avery", "7165", "Address labels", Category.MAILING, Paper.A4, false);
      s.layout.g = g;
      sheets ~= s;
      // Separator
      g  = Grid(0,0,0,0,0,0,0,false);
      s = Sheet(true, "Avery", "", "", Category.SEPARATOR, Paper.A4, false);
      s.layout.g = g;
      sheets ~= s;

      /*
      <Template brand="Avery" part="L6015" size="A4" _description="CD/DVD Labels">
       <Meta category="label"/>
       <Meta category="media"/>
       <Label-cd id="0" radius="165.827pt" hole="58.1102pt" waste="9.07087pt">
         <Markup-margin size="9pt"/>
         <Layout nx="1" ny="2" x0="131.811pt" y0="60.6614pt" dx="349.795pt" dy="349.795pt"/>
       </Label-cd>
      </Template*/
      g  = Grid(1, 2, 58.5, 58.5, 46.5, 21.4, 123.4, 123.4, true);
      s = Sheet(true, "Avery", "L6015", "CD/DVD Labels", Category.SPECIAL, Paper.A4, false);
      s.layout.g = g;
      sheets ~= s;
      /*
      <Template brand="Avery" part="7664" size="A4" _description="Diskette Labels">
       <Meta category="label"/>
       <Meta category="media"/>
       <Label-rectangle id="0" width="70mm" height="71.9mm" round="2.5mm">
         <Markup-margin size="5"/>
         <Layout nx="2" ny="4" x0="17mm" y0="5mm" dx="104.5mm" dy="72mm"/>
       </Label-rectangle>
      </Template>
      */
      g  = Grid(2, 4, 70.0, 71.9, 17.0, 5.0, 104.5, 72.0, false);
      s = Sheet(true, "Avery", "7664", "Diskette Labels", Category.SPECIAL, Paper.A4, false);
      s.layout.g = g;
      sheets ~= s;
      // Separator
      g  = Grid(0,0,0,0,0,0,0,false);
      s = Sheet(true, "Avery", "", "", Category.SEPARATOR, Paper.A4, false);
      s.layout.g = g;
      sheets ~= s;
      /*
      <Template brand="Avery" part="L4732" size="A4" _description="Mini Labels">
      <Meta category="label"/>
      <Meta category="rectangle-label"/>
      <Label-rectangle id="0" width="35.6mm" height="16.9mm" round="1.5mm" x_waste="0mm" y_waste="0mm">
      <Markup-margin size="1mm"/>
      <Layout nx="5" ny="16" x0="11mm" y0="13mm" dx="38.1mm" dy="16.9mm"/>
      </Label-rectangle>
      </Template>
      */
      g  = Grid(5, 16, 35.6, 16.9, 11.0, 13.0, 38.1, 16.9, false);
      s = Sheet(true, "Avery", "L4732", "Mini Labels", Category.GP, Paper.A4, false);
      s.layout.g = g;
      sheets ~= s;
      /*
      <Template brand="Avery" part="L4770" size="A4" _description="Mini Labels">
      <Meta category="label"/>
      <Meta category="rectangle-label"/>
      <Label-rectangle id="0" width="45.7mm" height="25.4mm" round="1.5mm" x_waste="0mm" y_waste="0mm">
      <Markup-margin size="1mm"/>
      <Layout nx="4" ny="10" x0="10mm" y0="22mm" dx="48.5mm" dy="25.4mm"/>
      </Label-rectangle>
      </Template>
      */
      g  = Grid(4, 10, 45.7, 25.4, 10.0, 22.0, 48.5, 25.4, false);
      s = Sheet(true, "Avery", "L4770", "Mini Labels", Category.GP, Paper.A4, false);
      s.layout.g = g;
      sheets ~= s;
      /*
      <Template brand="Avery" part="6121" size="A4" _description="Allround labels">
       <Meta category="label"/>
       <Label-rectangle id="0" width="107.928pt" height="60.12pt" round="0pt" x_waste="0pt" y_waste="0pt">
         <Markup-margin size="8.496pt"/>
         <Layout nx="5" ny="13" x0="26.928pt" y0="29.736pt" dx="107.928pt" dy="60.12pt"/>
       </Label-rectangle>
      </Template>
      */
      g  = Grid(5, 13, 38.08, 21.21, 9.5, 10.49, 38.08, 21.21, false);
      s = Sheet(true, "Avery", "6121", "Allround labels", Category.GP, Paper.A4, false);
      s.layout.g = g;
      sheets ~= s;
      /*
      <Template brand="Avery" part="7169" size="A4" _description="Shipping labels">
       <Meta category="label"/>
       <Meta category="mail"/>
       <Label-rectangle id="0" width="280.9" height="394.0" round="6">
         <Markup-margin size="6"/>
         <Layout nx="2" ny="2" x0="14.2" y0="20.0" dx="287.7" dy="394.0"/>
       </Label-rectangle>
      </Template>
      */
      g  = Grid(2, 2, 99.10, 138.99, 5.0, 7.06, 101.49, 138.99, false);
      s = Sheet(true, "Avery", "7169", "Shipping labels", Category.MAILING, Paper.A4, false);
      s.layout.g = g;
      sheets ~= s;
      // Separator
      g  = Grid(0,0,0,0,0,0,0,false);
      s = Sheet(true, "Avery", "", "", Category.SEPARATOR, Paper.A4, false);
      s.layout.g = g;
      sheets ~= s;
      /*
      <Template brand="Avery" part="7414" size="A4" _description="Business Cards">
       <Meta category="card"/>
       <Meta category="business-card"/>
       <Label-rectangle id="0" width="255.1" height="147.4" round="0">
         <Markup-margin size="5"/>
         <Layout nx="2" ny="5" x0="42.51" y0="52.44" dx="255.1" dy="147.4"/>
       </Label-rectangle>
      </Template>
      */
      g  = Grid(2, 5, 89.99, 52.0, 15.0, 18.5, 89.99, 52.0, false);
      s = Sheet(true, "Avery", "7414", "Business Cards", Category.BC, Paper.A4, false);
      s.layout.g = g;
      sheets ~= s;
   }

   int sheetCount()
   {
      return cast(int) sheets.length;
   }
   Sheet* sheetPtr()
   {
      return &sheets[0];
   }
}

class AveryUS : Portfolio
{
   Sheet[] sheets;
   this()
   {
      Sequence seq;
      Grid g;
      Sheet s;

      /*
      <Template brand="Avery" part="5159" size="US-Letter" _description="Address Labels">
       <Meta category="label"/>
       <Meta category="mail"/>
       <Label-rectangle id="0" width="4in" height="1.5in" round="0.0625in" waste="0in">
         <Markup-margin size="0.0625in"/>
         <Layout nx="2" ny="7" x0="0.15625in" y0="0.25in" dx="4.1875in" dy="1.5in"/>
       </Label-rectangle>
      </Template>
      */
      g  = Grid(2, 7, 4, 1.5, 0.15625, 0.25, 4.1875, 1.5, false);
      s = Sheet(false, "Avery", "5159", "Address Labels", Category.MAILING, Paper.US, false);
      s.layout.g = g;
      sheets ~= s;
      /*
      <Template brand="Avery" part="5160" size="US-Letter" _description="Address Labels">
       <Meta category="label"/>
       <Meta category="mail"/>
       <Label-rectangle id="0" width="2.625in" height="1in" round="0.0625in">
         <Markup-margin size="0.0625in"/>
         <Layout nx="3" ny="10" x0="0.1875in" y0="0.5in" dx="2.75in" dy="1in"/>
       </Label-rectangle>
      </Template>
      */
      g  = Grid(3, 10, 2.625, 1, 0.1875, 0.5, 2.75, 1, false);
      s = Sheet(false, "Avery", "5160", "Address Labels", Category.MAILING, Paper.US, false);
      s.layout.g = g;
      sheets ~= s;
      /*
      <Template brand="Avery" part="5161" size="US-Letter" _description="Address Labels">
       <Meta category="label"/>
       <Meta category="mail"/>
       <Label-rectangle id="0" width="4in" height="1in" round="0.0625in">
         <Markup-margin size="0.0625in"/>
         <Layout nx="2" ny="10" x0="0.15625in" y0="0.5in" dx="4.1875in" dy="1in"/>
       </Label-rectangle>
      </Template>
      */
      g  = Grid(2, 10, 4, 1, 0.15625, 0.5, 4.1875, 1, false);
      s = Sheet(false, "Avery", "5161", "Address Labels", Category.MAILING, Paper.US, false);
      s.layout.g = g;
      sheets ~= s;
      /*
      <Template brand="Avery" part="5162" size="US-Letter" _description="Address Labels">
       <Meta category="label"/>
       <Meta category="mail"/>
       <Label-rectangle id="0" width="4in" height="1.333333333in" round="0.0625in">
         <Markup-margin size="0.0625in"/>
         <Layout nx="2" ny="7"
                 x0="0.15625in" y0="0.833333333in" dx="4.1875in" dy="1.333333333in"/>
       </Label-rectangle>
      </Template>
      */
      g  = Grid(2, 7, 4, 1.333333, 0.15625, 0.833333, 4.1875, 1.333333, false);
      s = Sheet(false, "Avery", "5162", "Address Labels", Category.MAILING, Paper.US, false);
      s.layout.g = g;
      sheets ~= s;
      /*
      <Template brand="Avery" part="5197" size="US-Letter" _description="Address Labels">
       <Meta category="label"/>
       <Meta category="mail"/>
       <Label-rectangle id="0" width="4in" height="1.5in" round="0.0625in">
         <Markup-margin size="0.0625in"/>
         <Layout nx="2" ny="6" x0="0.1875in" y0="1in" dx="4.125in" dy="1.5in"/>
       </Label-rectangle>
      </Template>
      */
      g  = Grid(2, 6, 4, 1.5, 0.1875, 1, 4.125, 1.5, false);
      s = Sheet(false, "Avery", "5197", "Address Labels", Category.MAILING, Paper.US, false);
      s.layout.g = g;
      sheets ~= s;
      /*
      <Template brand="Avery" part="5663" size="US-Letter" _description="Address Labels">
       <Meta category="label"/>
       <Meta category="mail"/>
       <Label-rectangle id="0" width="4.25in" height="2in" round="0in">
         <Markup-margin size="0.0625in"/>
         <Layout nx="2" ny="5" x0="0in" y0="0.5in" dx="4.25in" dy="2in"/>
       </Label-rectangle>
      </Template>
      */
      g  = Grid(2, 5, 4.25, 2, 0, 0.5, 4.25, 2, false);
      s = Sheet(false, "Avery", "5663", "Address Labels", Category.MAILING, Paper.US, false);
      s.layout.g = g;
      sheets ~= s;
      /*
      <Template brand="Avery" part="5167" size="US-Letter" _description="Return Address Labels">
       <Meta category="label"/>
       <Meta category="mail"/>
       <Label-rectangle id="0" width="1.75in" height="0.5in" round="0.0625in">
         <Markup-margin size="0.0625in"/>
         <Layout nx="4" ny="20" x0="0.28125in" y0="0.5in" dx="2.0625in" dy="0.5in"/>
       </Label-rectangle>
      </Template>
      */
      g  = Grid(4, 20, 1.75, 0.5, 0.28125, 0.5, 2.0625, 0.5, false);
      s = Sheet(false, "Avery", "5167", "Return Address Labels", Category.MAILING, Paper.US, false);
      s.layout.g = g;
      sheets ~= s;

      // Separator
      g  = Grid(0,0,0,0,0,0,0,false);
      s = Sheet(false, "Avery", "", "", Category.SEPARATOR, Paper.A4, false);
      s.layout.g = g;
      sheets ~= s;

      /*
      <Template brand="Avery" part="5395" size="US-Letter" _description="Name Badge Labels">
       <Meta category="label"/>
       <Label-rectangle id="0" width="3.375in" height="2.333333333in" round="0.1875in" waste="0.0625in">
         <Markup-margin size="0.0625in"/>
         <Layout nx="2" ny="4" x0="0.6875in" y0="0.583333333in" dx="3.75in" dy="2.5in"/>
       </Label-rectangle>
      </Template>
      */
      g  = Grid(2, 4, 3.375, 2.333333, 0.6875, 0.583333, 3.75, 2.5, false);
      s = Sheet(false, "Avery", "5395", "NameBadge Labels", Category.SPECIAL, Paper.US, false);
      s.layout.g = g;
      sheets ~= s;
      /*
      <Template brand="Avery" part="5931-Disc" size="US-Letter"
            _description="CD/DVD Labels (Disc Labels)">
       <Meta category="label"/>
       <Meta category="media"/>
       <Label-cd id="0" radius="2.3125in" hole="0.8125in" waste="0.0625in">
         <Layout nx="1" ny="2" x0="1.9375in" y0="0.6875in" dx="0" dy="5in"/>
       </Label-cd>
      </Template>
      <Label-rectangle id="0" width="0.21875in" height="4.6875in" round="0.0625in" waste="0.0625in">
      <Layout nx="2" ny="2" x0="0.5in" y0="0.734375in" dx="0.46875in" dy="4.84375in"/>
      </Label-rectangle>
      */
      // This is actually a sequence sheet
      seq  = Sequence(6);
      LSRect tr = LSRect(true, 1.9375, 0.6875, 4.625, 4.625);
      seq.rects ~= tr;
      tr = LSRect(true, 1.9375, 5.6875, 4.625, 4.625);
      seq.rects ~= tr;
      tr = LSRect(false, 0.5, 0.7344, 0.21875, 4.6875);
      seq.rects ~= tr;
      tr = LSRect(false, 0.96875, 0.7344, 0.21875, 4.6875);
      seq.rects ~= tr;
      tr = LSRect(false, 0.5, 5.5782, 0.21875, 4.6875);
      seq.rects ~= tr;
      tr = LSRect(false, 0.96875, 5.5782, 0.21875, 4.6875);
      seq.rects ~= tr;
      s = Sheet(false, "Avery", "5931", "CD/DVD Labels", Category.SPECIAL, Paper.US, true);
      s.layout.s = seq;
      sheets ~= s;
      /*
      <Template brand="Avery" part="5997-Face" size="US-Letter"
            _description="Video Tape Face Labels">
       <Meta category="label"/>
       <Meta category="media"/>
       <Label-rectangle id="0" width="220" height="133" round="5">
         <Markup-margin size="5"/>
         <Layout nx="2" ny="5" x0="80" y0="60.5" dx="236" dy="133"/>
       </Label-rectangle>
      </Template>
      */
      g  = Grid(2, 5, 3.055, 1.847, 1.111, 0.840, 3.277, 1.847, false);
      s = Sheet(false, "Avery", "5997-Face", "Video Tape Face Labels", Category.SPECIAL, Paper.US, false);
      s.layout.g = g;
      sheets ~= s;
      /*
      <Template brand="Avery" part="5997-Spine" size="US-Letter"
           _description="Video Tape Spine Labels">
       <Meta category="label"/>
       <Meta category="media"/>
       <Label-rectangle id="0" width="414" height="48" round="5">
         <Markup-margin size="5"/>
         <Layout nx="1" ny="15" x0="99" y0="36" dx="0" dy="48"/>
       </Label-rectangle>
      </Template>
      */
      g  = Grid(2, 5, 3.055, 1.847, 1.111, 0.840, 3.277, 1.847, false);
      s = Sheet(false, "Avery", "5997-Spine", "Video Tape Spine Labels", Category.SPECIAL, Paper.US, false);
      s.layout.g = g;
      sheets ~= s;
      /*
      <Template brand="Avery" part="5196" size="US-Letter" _description="Diskette Labels">
       <Meta category="label"/>
       <Meta category="media"/>
       <Label-rectangle id="0" width="2.75in" height="2.75in" round="0.0625in">
         <Markup-margin size="0.0625in"/>
         <Layout nx="3" ny="3" x0="0.125in" y0="0.5in" dx="2.75in" dy="3in"/>
       </Label-rectangle>
      </Template>
      */
      g  = Grid(3, 3, 2.75, 2.75, 0.125, 0.5, 2.75, 3, false);
      s = Sheet(false, "Avery", "5196", "Diskette Labels", Category.SPECIAL, Paper.US, false);
      s.layout.g = g;
      sheets ~= s;
      /*
      <Template brand="Avery" part="5366" size="US-Letter" _description="Filing Labels">
       <Meta category="label"/>
       <Label-rectangle id="0" width="3.4375in" height="0.666666667in" round="0.0625in">
         <Markup-margin size="0.0625in"/>
         <Layout nx="2" ny="15" x0="0.53125in" y0="0.5in" dx="4in" dy="0.666666667in"/>
       </Label-rectangle>
      </Template>
      */
      g  = Grid(2, 15, 3.4375, 0.666666, 0.53125, 0.5, 4, 0.666666, false);
      s = Sheet(false, "Avery", "5366", "Filing Labels", Category.SPECIAL, Paper.US, false);
      s.layout.g = g;
      sheets ~= s;
      /*
      <Template brand="Avery" part="5026" size="US-Letter" _description="File Folder Labels">
       <Meta category="label"/>
       <Label-rectangle id="0" width="3.4375in" height="0.9375in" round="0.0625in" waste="5pt">
         <Markup-margin size="0.0625in"/>
         <Layout nx="2" ny="9" x0="0.49755in" y0="0.51125in" dx="4.0674in" dy="1.13in"/>
       </Label-rectangle>
      </Template>
      */
      g  = Grid(2, 9, 3.4375, 0.9375, 0.4975, 0.51125, 4.0674, 1.13, false);
      s = Sheet(false, "Avery", "5026", "File Folder Labels", Category.SPECIAL, Paper.US, false);
      s.layout.g = g;
      sheets ~= s;

      // Separator
      g  = Grid(0,0,0,0,0,0,0,false);
      s = Sheet(false, "Avery", "", "", Category.SEPARATOR, Paper.A4, false);
      s.layout.g = g;
      sheets ~= s;

      /*
      <Template brand="Avery" part="3274.1" size="US-Letter" _description="Square Labels">
       <Meta category="label"/>
       <Meta category="square-label"/>
       <Meta category="rectangle-label"/>
       <Label-rectangle id="0" width="2.5in" height="2.5in" round="0">
         <Markup-margin size="0.0625in"/>
         <Layout nx="3" ny="3" x0="0.3125in" y0="1.25in" dx="2.6875in" dy="3in"/>
       </Label-rectangle>
      </Template>
      */
      g  = Grid(3, 3, 2.5, 2.5, 0.3125, 1.25, 2.6875, 3, false);
      s = Sheet(false, "Avery", "3274.1", "Square Labels", Category.GP, Paper.US, false);
      s.layout.g = g;
      sheets ~= s;
      /*
      <Template brand="Avery" part="3274.2" size="US-Letter" _description="Small Round Labels">
       <Meta category="label"/>
       <Meta category="round-label"/>
       <Label-round id="0" radius="0.75in">
         <Markup-margin size="0.0625in"/>
         <Layout nx="4" ny="5" x0="0.5in" y0="0.75in" dx="2in" dy="2in"/>
       </Label-round>
      </Template>
      */
      g  = Grid(4, 5, 1.5, 1.5, 0.5, 0.75, 2, 2, true);
      s = Sheet(false, "Avery", "3274.2", "Small Round Labels", Category.GP, Paper.US, false);
      s.layout.g = g;
      sheets ~= s;
      /*
      <Template brand="Avery" part="3274.3" size="US-Letter" _description="Large Round Labels">
       <Meta category="label"/>
       <Meta category="round-label"/>
       <Label-round id="0" radius="1.25in">
         <Markup-margin size="5"/>
         <Layout nx="3" ny="3" x0="0.3125in" y0="1.25in" dx="2.6875in" dy="3in"/>
       </Label-round>
      </Template>
      */
      g  = Grid(3, 3, 2.5, 2.5, 0.3125, 1.25, 2.6875, 3, true);
      s = Sheet(false, "Avery", "3274.3", "Large Round Labels", Category.GP, Paper.US, false);
      s.layout.g = g;
      sheets ~= s;
      /*
      <Template brand="Avery" part="5126" size="US-Letter" _description="Shipping Labels">
       <Meta category="label"/>
       <Meta category="rectangle-label"/>
       <Meta category="mail"/>
       <Label-rectangle id="0" width="8.5in" height="5.5in" round="0in" x_waste="0in" y_waste="0in">
         <Markup-margin size="9pt"/>
         <Layout nx="1" ny="2" x0="0in" y0="0in" dx="0in" dy="5.5in"/>
       </Label-rectangle>
      </Template>
      */
      // Crap design - no margins
      g  = Grid(1, 2, 8.5, 5.5, 0, 0, 0, 5.5, false);
      s = Sheet(false, "Avery", "5126", "Shipping Labels", Category.GP, Paper.US, false);
      s.layout.g = g;
      sheets ~= s;
      /*
      <Template brand="Avery" part="5163" size="US-Letter" _description="Shipping Labels">
       <Meta category="label"/>
       <Meta category="mail"/>
       <Label-rectangle id="0" width="4in" height="2in" round="0.125in">
         <Markup-margin size="0.125in"/>
         <Layout nx="2" ny="5" x0="0.1625in" y0="0.5in" dx="4.1875in" dy="2in"/>
       </Label-rectangle>
      </Template>
      */
      g  = Grid(2, 5, 4, 2, 0.1625, 0.5, 4.1875, 2, false);
      s = Sheet(false, "Avery", "5163", "Shipping Labels", Category.GP, Paper.US, false);
      s.layout.g = g;
      sheets ~= s;
      /*
      <Template brand="Avery" part="5164" size="US-Letter" _description="Shipping Labels">
       <Meta category="label"/>
       <Meta category="mail"/>
       <Label-rectangle id="0" width="4in" height="3.333333333in" round="0.125in">
         <Markup-margin size="0.125in"/>
         <Layout nx="2" ny="3" x0="0.15625in" y0="0.5in" dx="4.1875in" dy="3.333333333in"/>
       </Label-rectangle>
      </Template>
      */
      g  = Grid(2, 3, 4, 3.333333, 0.15625, 0.5, 4.1875, 3.333333, false);
      s = Sheet(false, "Avery", "5164", "Shipping Labels", Category.GP, Paper.US, false);
      s.layout.g = g;
      sheets ~= s;
      /*
      <Template brand="Avery" part="5168" size="US-Letter" _description="Shipping Labels">
       <Meta category="label"/>
       <Meta category="mail"/>
       <Label-rectangle id="0" width="3.5in" height="5in" round="0.0625in" waste="0in">
         <Markup-margin size="0.0625in"/>
         <Layout nx="2" ny="2" x0="0.5in" y0="0.5in" dx="4in" dy="5in"/>
       </Label-rectangle>
      </Template>
      */
      g  = Grid(2, 2, 3.5, 5, 0.5, 0.5, 4, 5, false);
      s = Sheet(false, "Avery", "5168", "Shipping Labels", Category.GP, Paper.US, false);
      s.layout.g = g;
      sheets ~= s;
      /*
      <Template brand="Avery" part="5193" size="US-Letter" _description="Round Labels">
       <Meta category="label"/>
       <Meta category="round-label"/>
       <Label-round id="0" radius="0.8125in" waste="0pt">
         <Markup-margin size="0.0625in"/>
         <Layout nx="4" ny="6" x0="0.4157in" y0="0.549in" dx="2.0145in" dy="1.6554in"/>
       </Label-round>
      </Template>
      */
      g  = Grid(4, 6, 1.625, 1.625, 0.4157, 0.549, 2.0145, 1.6554, true);
      s = Sheet(false, "Avery", "5193", "Round Labels", Category.GP, Paper.US, false);
      s.layout.g = g;
      sheets ~= s;
      /*
      <Template brand="Avery" part="5194" size="US-Letter" _description="Round Labels">
       <Meta category="label"/>
       <Meta category="round-label"/>
       <Label-round id="0" radius="1.25in" waste="0pt">
         <Markup-margin size="0.0625in"/>
         <Layout nx="3" ny="4" x0="0.21in" y0="0.425in" dx="2.75in" dy="2.515in"/>
       </Label-round>
      </Template>
      */
      g  = Grid(3, 4, 2.5, 2.5, 0.21, 0.425, 2.75, 2.515, true);
      s = Sheet(false, "Avery", "5194", "Round Labels", Category.GP, Paper.US, false);
      s.layout.g = g;
      sheets ~= s;
      /*
      <Template brand="Avery" part="5195" size="US-Letter" _description="Round Labels">
       <Meta category="label"/>
       <Meta category="round-label"/>
       <Label-round id="0" radius="1.65625in" waste="0pt">
         <Markup-margin size="0.0625in"/>
         <Layout nx="2" ny="3" x0="0.6406in" y0="0.4844in" dx="3.9063in" dy="3.3594in"/>
       </Label-round>
      </Template>
      */
      g  = Grid(2, 3, 3.3125, 3.3125, 0.6406, 0.4844, 3.9063, 3.3594, true);
      s = Sheet(false, "Avery", "5195", "Round Labels", Category.GP, Paper.US, false);
      s.layout.g = g;
      sheets ~= s;

      // Separator
      g  = Grid(0,0,0,0,0,0,0,false);
      s = Sheet(false, "Avery", "", "", Category.SEPARATOR, Paper.A4, false);
      s.layout.g = g;
      sheets ~= s;

      /*
      <Template brand="Avery" part="5371" size="US-Letter" _description="Business Cards">
       <Meta category="card"/>
       <Meta category="business-card"/>
       <Label-rectangle id="0" width="3.5in" height="2in" round="0">
         <Markup-margin size="0.0625in"/>
         <Layout nx="2" ny="5" x0="0.75in" y0="0.5in" dx="3.5in" dy="2in"/>
       </Label-rectangle>
      </Template>
      */
      g  = Grid(2, 5, 3.5, 2, 0.75, 0.5, 3.5, 2, false);
      s = Sheet(false, "Avery", "5371", "Business Cards", Category.BC, Paper.US, false);
      s.layout.g = g;
      sheets ~= s;
      /*
      <Template brand="Avery" part="5388" size="US-Letter" _description="Index Cards">
       <Meta category="card"/>
       <Label-rectangle id="0" width="5in" height="3in" round="0pt" waste="0pt">
         <Markup-margin size="0.125in"/>
         <Layout nx="1" ny="3" x0="1.75in" y0="1in" dx="5in" dy="3in"/>
       </Label-rectangle>
      </Template>
      */
      g  = Grid(1, 3, 5, 3, 1.75, 1, 5, 3, false);
      s = Sheet(false, "Avery", "5388", "Index Cards", Category.GP, Paper.US, false);
      s.layout.g = g;
      sheets ~= s;
      /*
      <Template brand="Avery" part="5305" size="US-Letter" _description="Tent Cards">
       <Meta category="card"/>
       <Label-rectangle id="0" width="612pt" height="180pt" round="0pt" x_waste="0pt" y_waste="0pt">
         <Markup-margin size="27pt"/>
         <Layout nx="1" ny="2" x0="0pt" y0="216pt" dx="0pt" dy="360pt"/>
       </Label-rectangle>
      </Template>
      */
      g  = Grid(1, 2, 8.5, 2.5, 0, 3, 0, 5, false);
      s = Sheet(false, "Avery", "5305", "Tent Cards", Category.SPECIAL, Paper.US, false);
      s.layout.g = g;
      sheets ~= s;
      /*
      <Template brand="Avery" part="5389" size="US-Letter" _description="Post cards">
       <Meta category="card"/>
       <Meta category="mail"/>
       <Label-rectangle id="0" width="6in" height="4in" round="0pt" waste="0pt">
         <Markup-margin size="0.125in"/>
         <Layout nx="1" ny="2" x0="1.25in" y0="1.25in" dx="6in" dy="4.5in"/>
       </Label-rectangle>
      </Template>
      */
      g  = Grid(1, 2, 6, 4, 1.25, 1.25, 6, 4.5, false);
      s = Sheet(false, "Avery", "5389", "Post Cards", Category.GP, Paper.US, false);
      s.layout.g = g;
      sheets ~= s;
   }

   int sheetCount()
   {
      return cast(int) sheets.length;
   }
   Sheet* sheetPtr()
   {
      return &sheets[0];
   }
}
