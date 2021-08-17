--
--  Copyright (C) 2013, 2017  Reto Buerki <reet@codelabs.ch>
--  Copyright (C) 2013, 2017  Adrian-Ken Rueegsegger <ken@codelabs.ch>
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

with X86_64;

--D @Interface
--D Package providing subprograms to setup interrupt handling by means of Global
--D Descriptor and Interrupt Descriptor Tables as well as Task-State Segment.
package SK.Interrupt_Tables
with
   Abstract_State => State,
   Initializes    => State
is

   --  Initialize interrupt handling using the given interrupt stack address.
   procedure Initialize (Stack_Addr : Word64)
   with
      Global  => (In_Out => (State, X86_64.State)),
      Depends => ((State, X86_64.State) =>+ (State, Stack_Addr, X86_64.State));

   --  Return base addresses of GDT/IDT/TSS tables.
   procedure Get_Base_Addresses
     (GDT : out Word64;
      IDT : out Word64;
      TSS : out Word64)
   with
      Global  => (Input => State),
      Depends => ((GDT, IDT, TSS) => State);

end SK.Interrupt_Tables;
