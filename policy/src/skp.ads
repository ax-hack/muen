with Ada.Strings.Unbounded;
with Ada.Containers.Ordered_Sets;
with Ada.Containers.Doubly_Linked_Lists;

with SK;

package Skp
is

   --  Subject name.
   subtype Subject_Name_Type is Ada.Strings.Unbounded.Unbounded_String;

   --  Memory region specification.
   type Memory_Region_Type is private;

   --  Return physical start address of memory region.
   function Get_Physical_Address
     (Region : Memory_Region_Type)
      return SK.Word64;

   --  Return virtual start address of memory region.
   function Get_Virtual_Address
     (Region : Memory_Region_Type)
      return SK.Word64;

   --  Return size of memory region in bytes.
   function Get_Size (Region : Memory_Region_Type) return SK.Word64;

   --  Return alignment of memory region in bytes.
   function Get_Alignment (Region : Memory_Region_Type) return SK.Word64;

   --  Returns True if the memory region allows write access.
   function Is_Writable (Region : Memory_Region_Type) return Boolean;

   --  Returns True if the memory region is marked as executable.
   function Is_Executable (Region : Memory_Region_Type) return Boolean;

   --  Memory layout specification.
   type Memory_Layout_Type is private;

   --  Return PML4 address of memory layout.
   function Get_Pml4_Address (Layout : Memory_Layout_Type) return SK.Word64;

   --  Return memory layout region count.
   function Get_Region_Count (Layout : Memory_Layout_Type) return Positive;

   --  Iterate over regions in memory layout.
   procedure Iterate
     (Layout  : Memory_Layout_Type;
      Process : not null access procedure (R : Memory_Region_Type));

   --  I/O port range.
   type IO_Port_Range is private;

   --  Return start address of I/O port range.
   function Get_Start (Port_Range : IO_Port_Range) return SK.Word16;

   --  Return end address of I/O port range.
   function Get_End (Port_Range : IO_Port_Range) return SK.Word16;

   --  IO ports specification.
   type IO_Ports_Type is private;

   --  Return IO bitmap memory address.
   function Get_Bitmap_Address (Ports : IO_Ports_Type) return SK.Word64;

   --  Iterate over ranges of I/O ports.
   procedure Iterate
     (Ports   : IO_Ports_Type;
      Process : not null access procedure (R : IO_Port_Range));

   --  Subject specification.
   type Subject_Type is private;

   --  Return subject Id.
   function Get_Id (Subject : Subject_Type) return Natural;

   --  Return subject name.
   function Get_Name (Subject : Subject_Type) return Subject_Name_Type;

   --  Return subject memory layout.
   function Get_Memory_Layout
     (Subject : Subject_Type)
      return Memory_Layout_Type;

   --  Return allowed I/O ports.
   function Get_IO_Ports (Subject : Subject_Type) return IO_Ports_Type;

   --  SK system policy.
   type Policy_Type is private;

   --  Return subjects count.
   function Get_Subject_Count (Policy : Policy_Type) return Positive;

   --  Iterate over subjects.
   procedure Iterate
     (Policy  : Policy_Type;
      Process : not null access procedure (S : Subject_Type));

   Subject_Not_Found : exception;

private

   function "<" (Left, Right : Subject_Type) return Boolean;

   type Memory_Region_Type is record
      Physical_Address : SK.Word64;
      Virtual_Address  : SK.Word64;
      Size             : SK.Word64;
      Alignment        : SK.Word64;
      Writable         : Boolean;
      Executable       : Boolean;
   end record;

   package Memregion_Package is new Ada.Containers.Doubly_Linked_Lists
     (Element_Type => Memory_Region_Type);

   type Memory_Layout_Type is record
      Pml4_Address : SK.Word64;
      Regions      : Memregion_Package.List;
   end record;

   type IO_Port_Range is record
      Start_Port : SK.Word16;
      End_Port   : SK.Word16;
   end record;

   package Ports_Package is new Ada.Containers.Doubly_Linked_Lists
     (Element_Type => IO_Port_Range);

   type IO_Ports_Type is record
      IO_Bitmap_Address : SK.Word64;
      Ranges            : Ports_Package.List;
   end record;

   type Subject_Type is record
      Id            : Natural;
      Name          : Subject_Name_Type;
      Memory_Layout : Memory_Layout_Type;
      IO_Ports      : IO_Ports_Type;
   end record;

   package Subjects_Package is new Ada.Containers.Ordered_Sets
     (Element_Type => Subject_Type);

   type Policy_Type is record
      Subjects : Subjects_Package.Set;
   end record;

end Skp;
