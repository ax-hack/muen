--
--  Copyright (C) 2014, 2015  Reto Buerki <reet@codelabs.ch>
--  Copyright (C) 2014, 2015  Adrian-Ken Rueegsegger <ken@codelabs.ch>
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

with SK.KC;
with SK.VTd.Debug;
with SK.VTd.Dump;
with SK.Strings;

package body SK.VTd
is

   use Skp.IOMMU;

   --  Maximum number of busy-loops to perform when waiting for the hardware to
   --  set a status flag.
   Loop_Count_Max : constant := 10000;

   -------------------------------------------------------------------------

   --  Check capabilities of IOMMU given by index. Return False if capability
   --  requirements are not met.
   procedure Check_Capabilities
     (Idx    :     IOMMU_Device_Range;
      Ctx    : out Crash_Audit_Types.VTd_IOMMU_Status_Type;
      Result : out Boolean)
   with
      Global  => (Input  => Skp.IOMMU.State),
      Depends => ((Ctx, Result) => (Skp.IOMMU.State, Idx))
   is
      Version : Reg_Version_Type;
      Caps    : Reg_Capability_Type;
      Extcaps : Reg_Extcapability_Type;
   begin
      Version := Read_Version (Index => Idx);
      Ctx.Version_Support := Version.MAX = 1 and then Version.MIN = 0;
      pragma Debug (not Ctx.Version_Support,
                    KC.Put_Line
                      (Item => "Init: Unsupported IOMMU version "
                       & Strings.Img (Word16 (Version.MAX) * 2 ** 8
                         + Word16 (Version.MIN))));

      Caps := Read_Capability (Index => Idx);

      Ctx.Nr_Domains_OK := Caps.ND >= 2;
      pragma Debug
        (not Ctx.Nr_Domains_OK,
         KC.Put_Line (Item => "Init: IOMMU supports less than 256 domains"));

      Ctx.AGAW_Support := Caps.SAGAW (Cap_AGAW_Bit) = 1;
      pragma Debug (not Ctx.AGAW_Support,
                    KC.Put_Line
                      (Item => "Init: IOMMU SAGAW bit clear at position "
                       & Strings.Img (Byte (Cap_AGAW_Bit))));

      Ctx.FR_Offset_Match := SK.Word16 (Caps.FRO) * 16
        = Skp.IOMMU.Config_Get_FR_Offset (Index => Idx);
      pragma Debug (not Ctx.FR_Offset_Match,
                    KC.Put_Line
                      (Item => "Init: IOMMU FR offset mismatch "
                       & Strings.Img (Word16 (Caps.FRO) * 16)));

      Ctx.NFR_Match := Caps.NFR = 0;
      pragma Debug (not Ctx.NFR_Match,
                    KC.Put_Line
                      (Item => "Init: Unsupported IOMMU NFR "
                       & Strings.Img (Caps.NFR)));

      Extcaps := Read_Extended_Capability (Index => Idx);

      Ctx.IOTLB_Inv_Offset_Match := SK.Word16 (Extcaps.IRO) * 16 + 8
        = Skp.IOMMU.Config_Get_IOTLB_Inv_Offset (Index => Idx);
      pragma Debug (not Ctx.IOTLB_Inv_Offset_Match,
                    KC.Put_Line
                      (Item => "Init: IOMMU IOTLB invalidate offset mismatch "
                       & Strings.Img (Word16 (Extcaps.IRO) * 16 + 8)));

      Ctx.IR_Support := Extcaps.IR = 1;
      pragma Debug
        (not Ctx.IR_Support,
         KC.Put_Line
           (Item => "Init: No support for IOMMU Interrupt Remapping"));

      Ctx.EIM_Support := Extcaps.EIM = 1;
      pragma Debug
        (not Ctx.EIM_Support,
         KC.Put_Line
           (Item => "Init: No support for IOMMU Extended Interrupt Mode"));

      Result := Ctx.Version_Support and
        Ctx.Nr_Domains_OK           and
        Ctx.AGAW_Support            and
        Ctx.FR_Offset_Match         and
        Ctx.NFR_Match               and
        Ctx.IOTLB_Inv_Offset_Match  and
        Ctx.IR_Support              and
        Ctx.EIM_Support;
   end Check_Capabilities;

   -------------------------------------------------------------------------

   procedure Check_State
     (Is_Valid : out Boolean;
      Ctx      : out Crash_Audit_Types.VTd_Init_Context_Type)
   is
      Needed_Caps_Present : Boolean;
   begin
      Is_Valid        := True;
      Ctx             := Crash_Audit_Types.Null_VTd_Init_Context;
      Ctx.IOMMU_Count := Byte'Mod (IOMMU_Device_Range'Last);

      for I in IOMMU_Device_Range loop
         Check_Capabilities (Idx    => I,
                             Ctx    => Ctx.Status (Positive (I)),
                             Result => Needed_Caps_Present);
         pragma Debug (not Needed_Caps_Present, VTd.Dump.Print_Message
                       (IOMMU   => I,
                        Message => "Capability check failed"));
         Is_Valid := Is_Valid and Needed_Caps_Present;
      end loop;
   end Check_State;

   -------------------------------------------------------------------------

   --  Set command register fields based on given status register values.
   --  The current state of the global command register must be reconstructed
   --  from the global status register since command register values are
   --  *undefined* when read, see Intel VT-d Specification, "10.4.4 Global
   --  Command Register".
   procedure Set_Command_From_Status
     (Command : out Reg_Global_Command_Type;
      Status  :     Reg_Global_Status_Type)
   with
      Depends => (Command => Status)
   is
   begin
      Command := (CFI      => Status.CFIS,
                  SIRTP    => 0,
                  IRE      => Status.IRES,
                  QIE      => Status.QIES,
                  WBF      => 0,
                  EAFL     => Status.AFLS,
                  SFL      => 0,
                  SRTP     => 0,
                  TE       => Status.TES,
                  Reserved => (others => 0));
   end Set_Command_From_Status;

   -------------------------------------------------------------------------

   procedure Clear_Fault_Record (IOMMU : IOMMU_Device_Range)
   is
      Fault_Recording : Reg_Fault_Recording_Type;
      Fault_Status    : Reg_Fault_Status_Type;
   begin
      Fault_Recording   := Read_Fault_Recording (Index => IOMMU);
      Fault_Recording.F := 1;
      Write_Fault_Recording
        (Index => IOMMU,
         Value => Fault_Recording);

      Fault_Status     := Read_Fault_Status (Index => IOMMU);
      Fault_Status.PFO := 1;
      Write_Fault_Status
        (Index => IOMMU,
         Value => Fault_Status);
   end Clear_Fault_Record;

   -------------------------------------------------------------------------

   --  Sets the fault event interrupt mask of the specified IOMMU to the given
   --  state. Setting the mask to true prohibits hardware from generating an
   --  interrupt when a fault event occurs.
   procedure Set_Fault_Event_Mask
     (IOMMU  : IOMMU_Device_Range;
      Enable : Boolean)
   with
      Global  => (In_Out => Skp.IOMMU.State),
      Depends => (Skp.IOMMU.State =>+ (IOMMU, Enable))
   is
      Fault_Event_Control : Reg_Fault_Event_Control_Type;
   begin
      Fault_Event_Control := Read_Fault_Event_Control
        (Index => IOMMU);
      Fault_Event_Control.IM := (if Enable then 1 else 0);
      Write_Fault_Event_Control
        (Index => IOMMU,
         Value => Fault_Event_Control);
   end Set_Fault_Event_Mask;

   -------------------------------------------------------------------------

   --  Set address of root table for IOMMU with given index.
   procedure Set_Root_Table_Address
     (IOMMU   :     IOMMU_Device_Range;
      Address :     SK.Word64;
      Success : out Boolean)
   with
      Global  => (In_Out => Skp.IOMMU.State),
      Depends => ((Skp.IOMMU.State, Success) => (Skp.IOMMU.State, IOMMU,
                                                 Address))
   is
      Global_Status  : Reg_Global_Status_Type;
      Global_Command : Reg_Global_Command_Type;
   begin
      Write_Root_Table_Address
        (Index => IOMMU,
         Value => Address);

      Global_Status := Read_Global_Status (Index => IOMMU);
      Set_Command_From_Status (Command => Global_Command,
                               Status  => Global_Status);
      Global_Command.SRTP := 1;
      Write_Global_Command
        (Index => IOMMU,
         Value => Global_Command);

      for I in 1 .. Loop_Count_Max loop
         Global_Status := Read_Global_Status (Index => IOMMU);
         exit when Global_Status.RTPS = 1;
      end loop;
      Success := Global_Status.RTPS = 1;
   end Set_Root_Table_Address;

   -------------------------------------------------------------------------

   --  Invalidate context cache of IOMMU with given index.
   procedure Invalidate_Context_Cache
     (IOMMU   :     IOMMU_Device_Range;
      Success : out Boolean)
   with
      Global  => (In_Out => Skp.IOMMU.State),
      Depends => ((Skp.IOMMU.State, Success) => (Skp.IOMMU.State, IOMMU))
   is
      Context_Command : Reg_Context_Command_Type;
   begin

      --  Explicitly set Unused values to 0.

      Context_Command.Unused := (others => 0);
      Context_Command.ICC    := 1;
      Context_Command.CIRG   := 1;
      Context_Command.CAIG   := 0;

      Write_Context_Command
        (Index => IOMMU,
         Value => Context_Command);

      for J in 1 .. Loop_Count_Max loop
         Context_Command := Read_Context_Command (Index => IOMMU);
         exit when Context_Command.ICC = 0;
      end loop;
      Success := Context_Command.ICC = 0 and then Context_Command.CAIG = 1;
   end Invalidate_Context_Cache;

   -------------------------------------------------------------------------

   --  Flush IOTLB of IOMMU with given index.
   procedure Flush_IOTLB
     (IOMMU   :     IOMMU_Device_Range;
      Success : out Boolean)
   with
      Global  => (In_Out => Skp.IOMMU.State),
      Depends => ((Skp.IOMMU.State, Success) => (Skp.IOMMU.State, IOMMU))
   is
      IOTLB_Invalidate : Reg_IOTLB_Invalidate;
   begin
      IOTLB_Invalidate := Read_IOTLB_Invalidate (Index => IOMMU);

      IOTLB_Invalidate.IIRG := 1;
      IOTLB_Invalidate.IVT  := 1;
      IOTLB_Invalidate.IAIG := 0;

      Write_IOTLB_Invalidate
        (Index => IOMMU,
         Value => IOTLB_Invalidate);

      for J in 1 .. Loop_Count_Max loop
         IOTLB_Invalidate := Read_IOTLB_Invalidate (Index => IOMMU);
         exit when IOTLB_Invalidate.IVT = 0;
      end loop;
      Success := IOTLB_Invalidate.IVT = 0 and IOTLB_Invalidate.IAIG = 1;
   end Flush_IOTLB;

   -------------------------------------------------------------------------

   --  Enable address translation for IOMMU with given index.
   procedure Enable_Translation
     (IOMMU   :     IOMMU_Device_Range;
      Success : out Boolean)
   with
      Global  => (In_Out => Skp.IOMMU.State),
      Depends => ((Skp.IOMMU.State, Success) => (Skp.IOMMU.State, IOMMU))
   is
      Global_Command : Reg_Global_Command_Type;
      Global_Status  : Reg_Global_Status_Type;
   begin
      Global_Status := Read_Global_Status (Index => IOMMU);
      Set_Command_From_Status (Command => Global_Command,
                               Status  => Global_Status);
      Global_Command.TE := 1;
      Write_Global_Command
        (Index => IOMMU,
         Value => Global_Command);

      for J in 1 .. Loop_Count_Max loop
         Global_Status := Read_Global_Status (Index => IOMMU);
         exit when Global_Status.TES = 1;
      end loop;
      Success := Global_Status.TES = 1;
   end Enable_Translation;

   -------------------------------------------------------------------------

   --  Set Interrupt Remap Table address and size for IOMMU with given index.
   procedure Set_IR_Table_Address
     (IOMMU   :     IOMMU_Device_Range;
      Address :     Bit_52_Type;
      Size    :     Bit_4_Type;
      Success : out Boolean)
     with
       Global  => (In_Out => Skp.IOMMU.State),
       Depends => ((Skp.IOMMU.State, Success) => (Skp.IOMMU.State, IOMMU,
                                                  Address, Size))
   is
      Global_Status  : Reg_Global_Status_Type;
      Global_Command : Reg_Global_Command_Type;
      IRT_Address    : constant Reg_IRT_Address
        := (IRTA     => Address,
            S        => Size,
            EIME     => 1,
            Reserved => (others => 0));
   begin
      Write_IRT_Address (Index => IOMMU,
                         Value => IRT_Address);

      Global_Status := Read_Global_Status (Index => IOMMU);
      Set_Command_From_Status (Command => Global_Command,
                               Status  => Global_Status);
      Global_Command.SIRTP := 1;
      Write_Global_Command
        (Index => IOMMU,
         Value => Global_Command);

      for J in 1 .. Loop_Count_Max loop
         Global_Status := Read_Global_Status (Index => IOMMU);
         exit when Global_Status.IRTPS = 1;
      end loop;
      Success := Global_Status.IRTPS = 1;
   end Set_IR_Table_Address;

   -------------------------------------------------------------------------

   --  Block Compatibility Format Interrupts (CFI).
   procedure Block_CF_Interrupts
     (IOMMU   :     IOMMU_Device_Range;
      Success : out Boolean)
     with
       Global  => (In_Out => Skp.IOMMU.State),
       Depends => ((Skp.IOMMU.State, Success) => (Skp.IOMMU.State, IOMMU))
   is
      Global_Command : Reg_Global_Command_Type;
      Global_Status  : Reg_Global_Status_Type;
   begin
      Global_Status := Read_Global_Status (Index => IOMMU);
      Set_Command_From_Status (Command => Global_Command,
                               Status  => Global_Status);
      Global_Command.CFI := 0;
      Write_Global_Command
        (Index => IOMMU,
         Value => Global_Command);

      for J in 1 .. Loop_Count_Max loop
         Global_Status := Read_Global_Status (Index => IOMMU);
         exit when Global_Status.CFIS = 0;
      end loop;
      Success := Global_Status.CFIS = 0;
   end Block_CF_Interrupts;

   -------------------------------------------------------------------------

   --  Enable Interrupt Remapping (IR) for IOMMU with given index.
   procedure Enable_Interrupt_Remapping
     (IOMMU   :     IOMMU_Device_Range;
      Success : out Boolean)
     with
       Global  => (In_Out => Skp.IOMMU.State),
       Depends => ((Skp.IOMMU.State, Success) => (Skp.IOMMU.State, IOMMU))
   is
      Global_Command : Reg_Global_Command_Type;
      Global_Status  : Reg_Global_Status_Type;
   begin
      Global_Status := Read_Global_Status (Index => IOMMU);
      Set_Command_From_Status (Command => Global_Command,
                               Status  => Global_Status);
      Global_Command.IRE := 1;
      Write_Global_Command
        (Index => IOMMU,
         Value => Global_Command);

      for J in 1 .. Loop_Count_Max loop
         Global_Status := Read_Global_Status (Index => IOMMU);
         exit when Global_Status.IRES = 1;
      end loop;
      Success := Global_Status.IRES = 1;
   end Enable_Interrupt_Remapping;

   -------------------------------------------------------------------------

   --  Disable Queued Invalidation (QI) for IOMMU with given index.
   procedure Disable_Queued_Invalidation
     (IOMMU   :     IOMMU_Device_Range;
      Success : out Boolean)
   with
      Global  => (In_Out => Skp.IOMMU.State),
      Depends => ((Skp.IOMMU.State, Success) => (Skp.IOMMU.State, IOMMU))
   is
      Global_Command : Reg_Global_Command_Type;
      Global_Status  : Reg_Global_Status_Type;
   begin
      Global_Status := Read_Global_Status (Index => IOMMU);
      Set_Command_From_Status (Command => Global_Command,
                               Status  => Global_Status);
      Global_Command.QIE := 0;
      Write_Global_Command
        (Index => IOMMU,
         Value => Global_Command);

      for J in 1 .. Loop_Count_Max loop
         Global_Status := Read_Global_Status (Index => IOMMU);
         exit when Global_Status.QIES = 0;
      end loop;
      Success := Global_Status.QIES = 0;
   end Disable_Queued_Invalidation;

   -------------------------------------------------------------------------

   procedure VTd_Error
     (IOMMU   : IOMMU_Device_Range;
      Message : String;
      Reason  : Crash_Audit_Types.VTd_Reason_Range)
   with
      Global  => (Input  => CPU_Info.APIC_ID,
                  In_Out => (Crash_Audit.State, X86_64.State)),
      Depends => ((Crash_Audit.State,
                   X86_64.State) => (Reason, CPU_Info.APIC_ID,
                                     Crash_Audit.State, X86_64.State),
                  null => (IOMMU, Message)),
      No_Return
   is
      Audit_Entry : Crash_Audit.Entry_Type;
   begin
      pragma Debug (VTd.Dump.Print_Message
                    (IOMMU   => IOMMU,
                     Message => Message));
      Crash_Audit.Allocate (Audit => Audit_Entry);
      Crash_Audit.Set_Reason (Audit  => Audit_Entry,
                              Reason => Reason);
      Crash_Audit.Finalize (Audit => Audit_Entry);
   end VTd_Error;

   -------------------------------------------------------------------------

   procedure Initialize
   is
      use Crash_Audit_Types;

      Status : Boolean;
   begin
      for I in IOMMU_Device_Range loop
         Set_Fault_Event_Mask (IOMMU  => I,
                               Enable => True);
         Clear_Fault_Record (IOMMU => I);
         pragma Debug (Debug.Setup_Fault_Interrupt (IOMMU => I));
         pragma Debug (Set_Fault_Event_Mask (IOMMU  => I,
                                             Enable => False));

         --  Explicitly disable QI (required on DELL R*40 servers).

         Disable_Queued_Invalidation
           (IOMMU   => I,
            Success => Status);
         if not Status then
            VTd_Error
              (IOMMU   => I,
               Message => "Unable to disable queued invalidation",
               Reason  => VTd_Unable_To_Disable_QI);
         end if;

         --  DMAR

         Set_Root_Table_Address
           (IOMMU   => I,
            Address => Root_Table_Address,
            Success => Status);
         if not Status then
            VTd_Error
              (IOMMU   => I,
               Message => "Unable to set root table address",
               Reason  => VTd_Unable_To_Set_DMAR_Root_Table);
         end if;

         Invalidate_Context_Cache
           (IOMMU   => I,
            Success => Status);
         if not Status then
            VTd_Error
              (IOMMU   => I,
               Message => "Unable to invalidate context cache",
               Reason  => VTd_Unable_To_Invalidate_Ctx_Cache);
         end if;

         Flush_IOTLB (IOMMU   => I,
                      Success => Status);
         if not Status then
            VTd_Error
              (IOMMU   => I,
               Message => "Unable to flush IOTLB",
               Reason  => VTd_Unable_To_Flush_IOTLB);
         end if;

         Enable_Translation (IOMMU   => I,
                             Success => Status);
         if not Status then
            VTd_Error
              (IOMMU   => I,
               Message => "Error enabling translation",
               Reason  => VTd_Unable_To_Enable_Translation);
         end if;

         --  IR

         Set_IR_Table_Address (IOMMU   => I,
                               Address => IR_Table_Phys_Address,
                               Size    => IR_Table_Size,
                               Success => Status);
         if not Status then
            VTd_Error
              (IOMMU   => I,
               Message => "Unable to set IR table address",
               Reason  => VTd_Unable_To_Set_IR_Table);
         end if;

         Block_CF_Interrupts (IOMMU   => I,
                              Success => Status);
         if not Status then
            VTd_Error
              (IOMMU   => I,
               Message => "Unable to block CF interrupts",
               Reason  => VTd_Unable_To_Block_CF);
         end if;

         Enable_Interrupt_Remapping (IOMMU   => I,
                                     Success => Status);
         if not Status then
            VTd_Error
              (IOMMU   => I,
               Message => "Error enabling interrupt remapping",
               Reason  => VTd_Unable_To_Enable_IR);
         end if;

         declare
            Dummy : Reg_Global_Status_Type;
         begin
            Dummy := Read_Global_Status (Index => I);
            pragma Debug (VTd.Dump.Print_Global_Status
                          (IOMMU  => I,
                           Status => Dummy));
         end;
      end loop;
   end Initialize;

end SK.VTd;
