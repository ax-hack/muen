--
--  Copyright (C) 2013, 2014  Reto Buerki <reet@codelabs.ch>
--  Copyright (C) 2013, 2014  Adrian-Ken Rueegsegger <ken@codelabs.ch>
--  Copyright (C) 2014        Alexander Senier <mail@senier.net>
--
--  This program is free software: you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation, either version 3 of the License, or
--  (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program.  If not, see <http://www.gnu.org/licenses/>.
--

with Ada.Exceptions;
with Ada.Directories;
with Ada.Characters.Handling;

with Muxml;
with Test_Utils;

package body Muxml_Tests
is

   use Ahven;
   use Muxml;

   -------------------------------------------------------------------------

   procedure Initialize (T : in out Testcase)
   is
   begin
      T.Set_Name (Name => "Load/Store XML files");
      T.Add_Test_Routine
        (Routine => Load_Nonexistent_Xml'Access,
         Name    => "Load nonexistent XML");
      T.Add_Test_Routine
        (Routine => Load_Non_Xml_File'Access,
         Name    => "Load non-XML file");
      T.Add_Test_Routine
        (Routine => Load_Invalid_Xml'Access,
         Name    => "Load invalid XML file");
      T.Add_Test_Routine
        (Routine => Load_Invalid_Format'Access,
         Name    => "Load XML with invalid format");
      T.Add_Test_Routine
        (Routine => Store_Invalid_Format'Access,
         Name    => "Store XML with invalid format");
      T.Add_Test_Routine
        (Routine => Load_And_Store_Xml'Access,
         Name    => "Load and store supported documents");
   end Initialize;

   -------------------------------------------------------------------------

   procedure Load_And_Store_Xml
   is
   begin
      for K in Schema_Kind loop
         declare
            Data     : XML_Data_Type;
            K_Str    : constant String := Ada.Characters.Handling.To_Lower
              (Item => K'Img);
            Src_File : constant String := "data/" & K_Str & ".xml";
            Dst_File : constant String := "obj/" & K_Str & ".xml";
         begin
            Parse (Data => Data,
                   Kind => K,
                   File => Src_File);
            Write (Data => Data,
                   Kind => K,
                   File => Dst_File);
            Assert
              (Condition => Test_Utils.Equal_Files
                 (Filename1 => Src_File,
                  Filename2 => Dst_File),
               Message => "Stored " & K_Str & " XML differs from loaded one");
            Ada.Directories.Delete_File (Name => Dst_File);
         end;
      end loop;
   end Load_And_Store_Xml;

   -------------------------------------------------------------------------

   procedure Load_Invalid_Format
   is
      Data : XML_Data_Type;
      pragma Unreferenced (Data);
   begin
      Parse (Data => Data,
             Kind => Muxml.Format_B,
             File => "data/format_a.xml");
      Fail (Message => "Exception expected");

   exception
      when Processing_Error => null;
   end Load_Invalid_Format;

   -------------------------------------------------------------------------

   procedure Load_Invalid_Xml
   is
      Data : XML_Data_Type;
      pragma Unreferenced (Data);
   begin
      Parse (Data => Data,
             Kind => Muxml.Format_B,
             File => "data/invalid.xml");
      Fail (Message => "Exception expected");

   exception
      when Processing_Error => null;
   end Load_Invalid_Xml;

   -------------------------------------------------------------------------

   procedure Load_Non_Xml_File
   is
      Ref_Msg : constant String := "Error reading XML file 'data/invalid' - "
        & "data/invalid:1:1: Non-white space found at top level";
      Data    : XML_Data_Type;
      pragma Unreferenced (Data);
   begin
      Parse (Data => Data,
             Kind => Muxml.Format_B,
             File => "data/invalid");
      Fail (Message => "Exception expected");

   exception
      when E : Processing_Error =>
         Assert (Condition => Ada.Exceptions.Exception_Message
                 (X => E) = Ref_Msg,
                 Message   => "Exception message mismatch");
   end Load_Non_Xml_File;

   -------------------------------------------------------------------------

   procedure Load_Nonexistent_Xml
   is
      Ref_Msg : constant String
        := "Error reading XML file 'nonexistent' - Could not open nonexistent";
      Data    : XML_Data_Type;
      pragma Unreferenced (Data);
   begin
      Parse (Data => Data,
             Kind => Muxml.Format_B,
             File => "nonexistent");
      Fail (Message => "Exception expected");

   exception
      when E : Processing_Error =>
         Assert (Condition => Ada.Exceptions.Exception_Message
                 (X => E) = Ref_Msg,
                 Message   => "Exception message mismatch");
   end Load_Nonexistent_Xml;

   -------------------------------------------------------------------------

   procedure Store_Invalid_Format
   is
      Data : XML_Data_Type;
   begin
      Parse (Data => Data,
             Kind => Muxml.Format_A,
             File => "data/test_policy_a.xml");

      Write (Data => Data,
             Kind => Muxml.Format_B,
             File => "obj/test_policy_b.xml");
      Fail (Message => "Exception expected");
   exception
      when Processing_Error => null;
   end Store_Invalid_Format;

end Muxml_Tests;
