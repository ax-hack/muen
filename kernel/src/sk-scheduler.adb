with System;

with SK.VMX;
with SK.Constants;
with SK.KC;
with SK.CPU;
with SK.Subjects;

package body SK.Scheduler
--# own
--#    State is in New_Major, Current_Major, Current_Minor, Scheduling_Plan;
is

   --  Dumper subject id.
   Dumper_Id : constant := 1;

   --  Configured scheduling plan.
   Scheduling_Plan : Skp.Scheduling.Scheduling_Plan_Type;

   Tau0_Kernel_Iface_Address : SK.Word64;
   pragma Import (C, Tau0_Kernel_Iface_Address, "tau0kernel_iface_ptr");

   New_Major : Skp.Scheduling.Major_Frame_Range;
   for New_Major'Address use System'To_Address (Tau0_Kernel_Iface_Address);
   --# assert New_Major'Always_Valid;

   --  Current major, minor frame.
   Current_Major : Skp.Scheduling.Major_Frame_Range :=
     Skp.Scheduling.Major_Frame_Range'First;
   Current_Minor : Skp.Scheduling.Minor_Frame_Range :=
     Skp.Scheduling.Minor_Frame_Range'First;

   -------------------------------------------------------------------------

   --  Remove subject specified by Old_Id from the scheduling plan and replace
   --  it with the subject given by New_Id.
   procedure Swap_Subject (Old_Id, New_Id : Skp.Subject_Id_Type)
   --# global
   --#    in out X86_64.State;
   --#    in out Scheduling_Plan;
   --# derives
   --#    X86_64.State, Scheduling_Plan from *, Old_Id, New_Id;
   is
   begin
      if Old_Id = New_Id then
         pragma Debug (KC.Put_String (Item => "Scheduling error: subject "));
         pragma Debug (KC.Put_Byte   (Item => Byte (Old_Id)));
         pragma Debug (KC.Put_Line   (Item => " swap to self"));
         CPU.Panic;
      end if;

      for I in Skp.Scheduling.Major_Frame_Range loop
         for J in Skp.Scheduling.Minor_Frame_Range loop
            if Scheduling_Plan (I).CPUs (0).Minor_Frames
              (J).Subject_Id = Old_Id
            then
               Scheduling_Plan (I).CPUs (0).Minor_Frames
                 (J).Subject_Id := New_Id;
            end if;
         end loop;
      end loop;
   end Swap_Subject;

   -------------------------------------------------------------------------

   --  Read VMCS fields and store them in the given subject state.
   procedure Store_Subject_Info (State : in out SK.Subject_State_Type)
   --# global
   --#    in out X86_64.State;
   --# derives
   --#    X86_64.State from * &
   --#    State        from *, X86_64.State;
   is
   begin
      VMX.VMCS_Read (Field => Constants.VMX_EXIT_QUALIFICATION,
                     Value => State.Exit_Qualification);
      VMX.VMCS_Read (Field => Constants.VMX_EXIT_INTR_INFO,
                     Value => State.Interrupt_Info);

      VMX.VMCS_Read (Field => Constants.GUEST_RIP,
                     Value => State.RIP);
      VMX.VMCS_Read (Field => Constants.GUEST_SEL_CS,
                     Value => State.CS);
      VMX.VMCS_Read (Field => Constants.GUEST_RSP,
                     Value => State.RSP);
      VMX.VMCS_Read (Field => Constants.GUEST_SEL_SS,
                     Value => State.SS);
      VMX.VMCS_Read (Field => Constants.GUEST_CR0,
                     Value => State.CR0);
      VMX.VMCS_Read (Field => Constants.GUEST_CR3,
                     Value => State.CR3);
      VMX.VMCS_Read (Field => Constants.GUEST_CR4,
                     Value => State.CR4);
      VMX.VMCS_Read (Field => Constants.GUEST_RFLAGS,
                     Value => State.RFLAGS);
   end Store_Subject_Info;

   -------------------------------------------------------------------------

   --  Update scheduling information. If the end of the current major frame is
   --  reached, the minor frame index is reset and the major frame is switched
   --  to the one set by Tau0. Otherwise the minor frame index is incremented
   --  by 1.
   procedure Update_Scheduling_Info
   --# global
   --#    in     New_Major;
   --#    in     Scheduling_Plan;
   --#    in out Current_Major;
   --#    in out Current_Minor;
   --# derives
   --#    Current_Minor from *, Current_Major, Scheduling_Plan &
   --#    Current_Major from *, Current_Minor, New_Major, Scheduling_Plan;
   is
   begin
      if Current_Minor < Scheduling_Plan (Current_Major).CPUs (0).Length then

         --# assert
         --#    Current_Minor < Scheduling_Plan
         --#       (Current_Major).CPUs (0).Length and
         --#    Scheduling_Plan (Current_Major).CPUs (0).Length
         --#       <= Skp.Scheduling.Minor_Frame_Range'Last;

         Current_Minor := Current_Minor + 1;
      else
         Current_Minor := Skp.Scheduling.Minor_Frame_Range'First;
         Current_Major := New_Major;
      end if;
   end Update_Scheduling_Info;

   -------------------------------------------------------------------------

   procedure Handle_Hypercall
     (Current_Subject :        Skp.Subject_Id_Type;
      Subject_State   : in out SK.Subject_State_Type)
   --# global
   --#    in out X86_64.State;
   --#    in out Subjects.Descriptors;
   --#    in out Scheduling_Plan;
   --# derives
   --#    X86_64.State, Scheduling_Plan from
   --#       *,
   --#       Current_Subject,
   --#       Subject_State &
   --#    Subject_State        from * &
   --#    Subjects.Descriptors from *, Subject_State;
   is
      New_Subject : Skp.Subject_Id_Type;
   begin
      if Subject_State.Regs.RAX <= SK.Word64 (Skp.Subject_Id_Type'Last) then
         New_Subject := Skp.Subject_Id_Type (Subject_State.Regs.RAX);
         Subjects.Set_State (Id    => New_Subject,
                             State => SK.Null_Subject_State);

         Swap_Subject
           (Old_Id => Current_Subject,
            New_Id => New_Subject);
         Subject_State := SK.Null_Subject_State;
      else
         pragma Debug (KC.Put_String ("Invalid hypercall parameter"));
         CPU.Panic;
      end if;
   end Handle_Hypercall;

   -------------------------------------------------------------------------

   procedure Schedule
   --# global
   --#    in     VMX.State;
   --#    in     GDT.GDT_Pointer;
   --#    in     Interrupts.IDT_Pointer;
   --#    in     Current_Major;
   --#    in     Current_Minor;
   --#    in     Scheduling_Plan;
   --#    in out X86_64.State;
   --#    in out Subjects.Descriptors;
   --# derives
   --#    Subjects.Descriptors from
   --#       *,
   --#       Current_Major,
   --#       Current_Minor,
   --#       Scheduling_Plan &
   --#    X86_64.State from
   --#       *,
   --#       VMX.State,
   --#       GDT.GDT_Pointer,
   --#       Interrupts.IDT_Pointer,
   --#       Subjects.Descriptors,
   --#       Current_Major,
   --#       Current_Minor,
   --#       Scheduling_Plan;
   is
      Current_Frame : Skp.Scheduling.Minor_Frame_Type;
   begin
      Current_Frame := Scheduling_Plan (Current_Major).CPUs (0).Minor_Frames
        (Current_Minor);

      if Subjects.Get_State (Id => Current_Frame.Subject_Id).Launched then
         VMX.Resume (Subject_Id => Current_Frame.Subject_Id,
                     Time_Slice => Current_Frame.Ticks);
      else
         VMX.Launch (Subject_Id => Current_Frame.Subject_Id,
                     Time_Slice => Current_Frame.Ticks);
      end if;
   end Schedule;

   -------------------------------------------------------------------------

   procedure Handle_Vmx_Exit (Subject_Registers : SK.CPU_Registers_Type)
   --# global
   --#    in     GDT.GDT_Pointer;
   --#    in     Interrupts.IDT_Pointer;
   --#    in     VMX.State;
   --#    in     New_Major;
   --#    in out Scheduling_Plan;
   --#    in out Current_Major;
   --#    in out Current_Minor;
   --#    in out Subjects.Descriptors;
   --#    in out X86_64.State;
   --# derives
   --#    Current_Major from
   --#       *,
   --#       Current_Minor,
   --#       New_Major,
   --#       Scheduling_Plan,
   --#       Subject_Registers,
   --#       Subjects.Descriptors,
   --#       X86_64.State  &
   --#    Current_Minor from
   --#       *,
   --#       Current_Major,
   --#       Scheduling_Plan,
   --#       Subject_Registers,
   --#       Subjects.Descriptors,
   --#       X86_64.State &
   --#    Scheduling_Plan from
   --#       *,
   --#       Current_Major,
   --#       Current_Minor,
   --#       Subject_Registers,
   --#       Subjects.Descriptors,
   --#       X86_64.State &
   --#    X86_64.State from
   --#       *,
   --#       Subject_Registers,
   --#       New_Major,
   --#       Current_Major,
   --#       Current_Minor,
   --#       Scheduling_Plan,
   --#       VMX.State,
   --#       Interrupts.IDT_Pointer,
   --#       GDT.GDT_Pointer,
   --#       Subjects.Descriptors &
   --#    Subjects.Descriptors from
   --#       *,
   --#       X86_64.State,
   --#       Subject_Registers,
   --#       New_Major,
   --#       Current_Major,
   --#       Current_Minor,
   --#       Scheduling_Plan;
   is
      State           : SK.Subject_State_Type;
      Current_Subject : Skp.Subject_Id_Type;
   begin
      Current_Subject := Scheduling_Plan (Current_Major).CPUs (0).Minor_Frames
        (Current_Minor).Subject_Id;
      State           := Subjects.Get_State (Id => Current_Subject);
      State.Regs      := Subject_Registers;

      VMX.VMCS_Read (Field => Constants.VMX_EXIT_REASON,
                     Value => State.Exit_Reason);

      if State.Exit_Reason = Constants.VM_EXIT_HYPERCALL then
         Handle_Hypercall (Current_Subject => Current_Subject,
                           Subject_State   => State);
      elsif State.Exit_Reason /= Constants.VM_EXIT_TIMER_EXPIRY then

         --  Abnormal subject exit, schedule dumper.

         Store_Subject_Info (State => State);
         Swap_Subject (Old_Id => Current_Subject,
                       New_Id => Dumper_Id);
      end if;

      Subjects.Set_State (Id    => Current_Subject,
                          State => State);

      Update_Scheduling_Info;
      Schedule;
   end Handle_Vmx_Exit;

begin
   Scheduling_Plan := Skp.Scheduling.Scheduling_Plans;
end SK.Scheduler;
