--
--  Copyright (C) 2014  Reto Buerki <reet@codelabs.ch>
--  Copyright (C) 2014  Adrian-Ken Rueegsegger <ken@codelabs.ch>
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

with Ada.Strings.Unbounded;

with Interfaces;

with DOM.Core.Nodes;
with DOM.Core.Elements;

with McKae.XML.XPath.XIA;

with Mulog;

package body Validators.Device
is

   use Ada.Strings.Unbounded;
   use McKae.XML.XPath.XIA;

   -------------------------------------------------------------------------

   procedure IO_Port_Start_Smaller_End (XML_Data : Muxml.XML_Data_Type)
   is
      use type Interfaces.Unsigned_32;

      Nodes : constant DOM.Core.Node_List := XPath_Query
        (N     => XML_Data.Doc,
         XPath => "//ioPort");
   begin
      Mulog.Log (Msg => "Checking I/O start ports <= end");

      for I in 0 .. DOM.Core.Nodes.Length (List => Nodes) - 1 loop
         declare
            Node     : constant DOM.Core.Node
              := DOM.Core.Nodes.Item (List  => Nodes,
                                      Index => I);
            S_Addr_Str : constant String := DOM.Core.Elements.Get_Attribute
              (Elem => Node,
               Name => "start");
            S_Addr : constant Interfaces.Unsigned_32
              := Interfaces.Unsigned_32'Value (S_Addr_Str);
            E_Addr_Str : constant String := DOM.Core.Elements.Get_Attribute
              (Elem => Node,
               Name => "end");
            E_Addr : constant Interfaces.Unsigned_32
              := Interfaces.Unsigned_32'Value (E_Addr_Str);

            --  Either name or logical attribute exists.

            Name       : constant String := DOM.Core.Elements.Get_Attribute
              (Elem => Node,
               Name => "name");
            Logical_Name : constant String := DOM.Core.Elements.Get_Attribute
              (Elem => Node,
               Name => "logical");
         begin
            if S_Addr > E_Addr then
               raise Validation_Error with "I/O port '" & Name & Logical_Name
                 & "' start " & S_Addr_Str & " larger than end " & E_Addr_Str;
            end if;
         end;
      end loop;
   end IO_Port_Start_Smaller_End;

   -------------------------------------------------------------------------

   procedure Physical_Device_References (XML_Data : Muxml.XML_Data_Type)
   is
      Nodes : constant DOM.Core.Node_List := XPath_Query
        (N     => XML_Data.Doc,
         XPath => "//device[@physical]");
   begin
      Mulog.Log (Msg => "Checking physical device references");

      for I in 0 .. DOM.Core.Nodes.Length (List => Nodes) - 1 loop
         declare
            Node         : constant DOM.Core.Node
              := DOM.Core.Nodes.Item (List  => Nodes,
                                      Index => I);
            Logical_Name : constant String
              := DOM.Core.Elements.Get_Attribute
                (Elem => Node,
                 Name => "logical");
            Phys_Name    : constant String
              := DOM.Core.Elements.Get_Attribute
                (Elem => Node,
                 Name => "physical");
            Physical     : constant DOM.Core.Node_List
              := XPath_Query
                (N     => XML_Data.Doc,
                 XPath => "/system/platform/device[@name='" & Phys_Name
                 & "']");
         begin
            if DOM.Core.Nodes.Length (List => Physical) = 0 then
               raise Validation_Error with "Physical device '" & Phys_Name
                 & "' referenced by logical device '" & Logical_Name
                 & "' not found";
            end if;
         end;
      end loop;
   end Physical_Device_References;

   -------------------------------------------------------------------------

   procedure Physical_IRQ_References (XML_Data : Muxml.XML_Data_Type)
   is
      Nodes : constant DOM.Core.Node_List := XPath_Query
        (N     => XML_Data.Doc,
         XPath => "//irq[@logical]");
   begin
      Mulog.Log (Msg => "Checking physical IRQ references");

      for I in 0 .. DOM.Core.Nodes.Length (List => Nodes) - 1 loop
         declare
            Node          : constant DOM.Core.Node
              := DOM.Core.Nodes.Item (List  => Nodes,
                                      Index => I);
            Log_Dev_Name  : constant String := DOM.Core.Elements.Get_Attribute
              (Elem => DOM.Core.Nodes.Parent_Node (N => Node),
               Name => "logical");
            Phys_Dev_Name : constant String := DOM.Core.Elements.Get_Attribute
              (Elem => DOM.Core.Nodes.Parent_Node (N => Node),
               Name => "physical");
            Logical_Name  : constant String
              := DOM.Core.Elements.Get_Attribute
                (Elem => Node,
                 Name => "logical");
            Phys_Name    : constant String
              := DOM.Core.Elements.Get_Attribute
                (Elem => Node,
                 Name => "physical");
            Physical     : constant DOM.Core.Node_List
              := XPath_Query
                (N     => XML_Data.Doc,
                 XPath => "/system/platform/device[@name='" & Phys_Dev_Name
                 & "']/irq[@name='" & Phys_Name & "']");
         begin
            if DOM.Core.Nodes.Length (List => Physical) = 0 then
               raise Validation_Error with "Physical IRQ '" & Phys_Name
                 & "' referenced by logical IRQ '" & Logical_Name
                 & "' of logical device '" & Log_Dev_Name & "' not found";
            end if;
         end;
      end loop;
   end Physical_IRQ_References;

   -------------------------------------------------------------------------

   procedure Physical_IRQ_Uniqueness (XML_Data : Muxml.XML_Data_Type)
   is
      type IRQ_Range is new Natural range 0 .. 223;

      type IRQ_Array is array (IRQ_Range) of Unbounded_String;

      IRQs  : IRQ_Array := (others => Null_Unbounded_String);

      Nodes : constant DOM.Core.Node_List := XPath_Query
        (N     => XML_Data.Doc,
         XPath => "/system/platform/device/irq");
   begin
      Mulog.Log (Msg => "Checking physical IRQ uniqueness");

      for I in 0 .. DOM.Core.Nodes.Length (List => Nodes) - 1 loop
         declare
            Node         : constant DOM.Core.Node
              := DOM.Core.Nodes.Item (List  => Nodes,
                                      Index => I);
            Irq_Number : constant IRQ_Range := IRQ_Range'Value
              (DOM.Core.Elements.Get_Attribute
                 (Elem => Node,
                  Name => "number"));
            Dev_Name   : constant String
              := DOM.Core.Elements.Get_Attribute
                (Elem => DOM.Core.Nodes.Parent_Node (N => Node),
                 Name => "name");
         begin
            if IRQs (Irq_Number) /= Null_Unbounded_String then
               raise Validation_Error with "Devices '" & Dev_Name & "' and '"
                 & To_String (IRQs (Irq_Number)) & "' share IRQ"
                 & Irq_Number'Img;
            end if;

            IRQs (Irq_Number) := To_Unbounded_String (Dev_Name);
         end;
      end loop;
   end Physical_IRQ_Uniqueness;

end Validators.Device;