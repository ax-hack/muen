--
--  Copyright (C) 2016  Reto Buerki <reet@codelabs.ch>
--  Copyright (C) 2016  Adrian-Ken Rueegsegger <ken@codelabs.ch>
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

with SK.CPU;

with Interrupt_Handler;
pragma Unreferenced (Interrupt_Handler);

with Interrupts;
with Log;

with PS2.Output;

procedure PS2_Drv
is
begin
   Interrupts.Initialize;
   PS2.Output.Init;

   Log.Text_IO.Put_Line (Item => "PS/2 driver initialized");

   SK.CPU.Sti;
   loop
      SK.CPU.Hlt;
   end loop;
end PS2_Drv;