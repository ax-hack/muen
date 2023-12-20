--
--  Copyright (C) 2013-2022  Reto Buerki <reet@codelabs.ch>
--  Copyright (C) 2013-2022  Adrian-Ken Rueegsegger <ken@codelabs.ch>
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
with SK.Constants;
with SK.Strings;

with Exceptions;
with Example_Component.Channels;

with Log;

package body Interrupt_Handler
with
   Refined_State => (State => (FPU_State, Active_FPU_Features))
is

   --  Storage area for saving/restoring the FPU state.
   FPU_State           : SK.XSAVE_Area_Type;
   Active_FPU_Features : SK.Word64
   with
      Constant_After_Elaboration;

   -------------------------------------------------------------------------

   procedure Dispatch_Exception (Context : SK.Exceptions.Isr_Context_Type)
   is
      use type SK.Byte;

      Vector : constant SK.Byte := SK.Byte'Mod (Context.Vector);
   begin
      SK.CPU.XSAVE (Target => FPU_State,
                    State  => Active_FPU_Features);
      if Vector > 31 then
         Handle_Interrupt (Vector => Vector);
      elsif Vector = 3 then
         Log.Put_Line (Item => "#BP exception @ RIP "
                       & SK.Strings.Img (Item => Context.RIP));
         Log.Put_Line (Item => "                RSP "
                       & SK.Strings.Img (Item => Context.RSP));
         Log.Put_Line (Item => "                RBP "
                       & SK.Strings.Img (Item => Context.Regs.RBP));
         Log.Put_Line (Item => "         Error Code "
                       & SK.Strings.Img (Item => Context.Error_Code));
         Exceptions.Print_Backtrace (RIP => Context.RIP,
                                     RBP => Context.Regs.RBP);
         Exceptions.BP_Triggered := True;

         --  Hardware stores the RIP pointing to the instruction after int3 on
         --  the interrupt stack so we can simply return to resume execution.

      else
         Log.Put_Line (Item => "Halting due to unexpected exception "
                       & SK.Strings.Img (Item => Vector));
         Log.Put_Line (Item => " Error Code: "
                       & SK.Strings.Img (Item => Context.Error_Code));
         Log.Put_Line (Item => " RIP       : "
                       & SK.Strings.Img (Item => Context.RIP));
         Log.Put_Line (Item => " RSP       : "
                       & SK.Strings.Img (Item => Context.RSP));
         Log.Put_Line (Item => " CS        : "
                       & SK.Strings.Img (Item => SK.Byte'Mod (Context.CS)));
         Log.Put_Line (Item => " SS        : "
                       & SK.Strings.Img (Item => SK.Byte'Mod (Context.SS)));
         Log.Put_Line (Item => " RFLAGS    : "
                       & SK.Strings.Img (Item => Context.RFLAGS));

         SK.CPU.Stop;
      end if;

      SK.CPU.XRSTOR (Source => FPU_State,
                     State  => Active_FPU_Features);
   end Dispatch_Exception;

   -------------------------------------------------------------------------

   procedure Handle_Interrupt (Vector : SK.Byte)
   is
      use type SK.Byte;
   begin
      Log.Put_Line (Item => "Received vector " & SK.Strings.Img
                    (Item => Vector));
      if Vector = Example_Component.Channels.Example_Request_Vector then
         Foo_Request_Pending := True;
      end if;
   end Handle_Interrupt;

begin
   FPU_State                          := SK.Null_XSAVE_Area;
   FPU_State.Legacy_Header.FCW        := SK.Constants.FCW_Default_Value;
   FPU_State.Legacy_Header.MXCSR      := SK.Constants.MXCSR_Default_Value;
   FPU_State.Legacy_Header.MXCSR_Mask := SK.Constants.MXCSR_Mask_Default_Value;
   SK.CPU.XGETBV
     (Register => 0,
      Value    => Active_FPU_Features);
end Interrupt_Handler;
