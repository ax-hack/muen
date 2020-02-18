--
--  Copyright (C) 2018  secunet Security Networks AG
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

with Interfaces;

with Dbg.Byte_Arrays;

package Dbg.PC_Speaker
is

   --  Play sound of specified frequency for duration given in milliseconds.
   procedure Play_Sound
     (Frequency   : Interfaces.Unsigned_32;
      Duration_MS : Natural);

   --  Output sound for given byte and specified duration in milliseconds.
   procedure Put_Byte
     (Item        : Interfaces.Unsigned_8;
      Duration_MS : Natural);

   --  Output sound for given byte array using the specified duration in
   --  milliseconds for each byte.
   procedure Put
     (Item        : Byte_Arrays.Byte_Array;
      Duration_MS : Natural);

private

   subtype Pos   is Interfaces.Unsigned_8 range 0 .. 7;
   subtype Phase is Interfaces.Unsigned_8 range 0 .. 1;
   subtype Bit   is Interfaces.Unsigned_8 range 0 .. 1;

   --  Start beeping with specified frequency.
   procedure Start_Beep (Frequency : Interfaces.Unsigned_32);

   --  Stop beeping.
   procedure Stop_Beep;

   function Nth_Bit
     (B : Interfaces.Unsigned_8;
      N : Pos)
      return Bit;

end Dbg.PC_Speaker;
