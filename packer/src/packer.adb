with Ada.Text_IO;
with Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Command_Line;

with SK.Utils;

with Skp.Kernel;
with Skp.Binaries;
with Skp.Subjects;

with Pack.Image;

procedure Packer
is
   use Ada.Strings.Unbounded;
   use Pack;
   use Skp;
   use Skp.Subjects;
   use Skp.Binaries;

   --  Print packer usage.
   procedure Print_Usage;
   procedure Print_Usage
   is
   begin
      Ada.Text_IO.Put_Line
        (Ada.Command_Line.Command_Name & " <kernel_elf> <image>");
   end Print_Usage;

   Top_Dir    : constant String := "..";
   Policy_Dir : constant String := Top_Dir & "/policy/include";
begin
   if Ada.Command_Line.Argument_Count /= 2 then
      Print_Usage;
      Ada.Command_Line.Set_Exit_Status (Code => Ada.Command_Line.Failure);
      return;
   end if;

   Ada.Text_IO.Put_Line ("Packaging kernel image ...");

   --  Kernel

   Ada.Directories.Copy_File
     (Source_Name => Ada.Command_Line.Argument (1),
      Target_Name => Ada.Command_Line.Argument (2));
   Image.Add_Section
     (Image    => Ada.Command_Line.Argument (2),
      Filename => Policy_Dir & "/kernel_pt",
      Address  => Kernel.PML4_Address);
   Ada.Text_IO.Put_Line (SK.Utils.To_Hex (Item => Kernel.PML4_Address)
                         & " [PML4] kernel");

   --  Subjects

   for S in Subject_Specs'Range loop
      declare
         Img  : constant String := Ada.Command_Line.Argument (2);
         Fn   : constant String := Top_Dir & "/" & To_String
           (Binary_Specs (S).Path);
         Name : constant String := Ada.Directories.Base_Name (Name => Fn);
      begin
         Ada.Text_IO.Put_Line
           (SK.Utils.To_Hex (Item => Binary_Specs (S).Physical_Address)
            & " [BIN ] " & Name);
         Ada.Text_IO.Put_Line
           (SK.Utils.To_Hex (Item => Subject_Specs (S).PML4_Address)
            & " [PML4] " & Name);
         Ada.Text_IO.Put_Line
           (SK.Utils.To_Hex (Item => Subject_Specs (S).IO_Bitmap_Address)
            & " [IOBM] " & Name);

         Image.Add_Section
           (Image    => Img,
            Filename => "obj/" & Name,
            Address  => Binary_Specs (S).Physical_Address);
         Image.Add_Section
           (Image    => Img,
            Filename => Policy_Dir & "/" & Name & "_pt",
            Address  => Subject_Specs (S).PML4_Address);
         Image.Add_Section
           (Image    => Img,
            Filename => Policy_Dir & "/" & Name & "_iobm",
            Address  => Subject_Specs (S).IO_Bitmap_Address);
      end;
   end loop;
end Packer;
