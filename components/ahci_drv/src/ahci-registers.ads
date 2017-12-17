--
--  Copyright (C) 2017  Reto Buerki <reet@codelabs.ch>
--  Copyright (C) 2017  Adrian-Ken Rueegsegger <ken@codelabs.ch>
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

with System;

with Interfaces;

with Ahci_Drv_Component.Devices;

package Ahci.Registers
is

   use Ahci_Drv_Component.Devices;

   --  Serial ATA AHCI 1.3.1 Specification, section 3.1.

   type Unsigned_4 is mod 2 ** 4;
   for Unsigned_4'Size use 4;

   type Unsigned_5 is mod 2 ** 5;
   for Unsigned_5'Size use 5;

   type Bit_Array is array (Natural range <>) of Boolean
   with
      Pack;

   type Byte_Array is array (Natural range <>) of Interfaces.Unsigned_8
   with
      Pack;

   type HBA_Caps_Type is record
      NP       : Unsigned_5;
      SXS      : Boolean;
      EMS      : Boolean;
      CCCS     : Boolean;
      NCS      : Unsigned_5;
      PSC      : Boolean;
      SSC      : Boolean;
      PMD      : Boolean;
      FBSS     : Boolean;
      SPM      : Boolean;
      SAM      : Boolean;
      Reserved : Boolean;
      ISS      : Unsigned_4;
      SCLO     : Boolean;
      SAL      : Boolean;
      SALP     : Boolean;
      SSS      : Boolean;
      SMPS     : Boolean;
      SSNTF    : Boolean;
      SNCQ     : Boolean;
      S64A     : Boolean;
   end record
   with
      Size => 4 * 8;

   for HBA_Caps_Type use record
      NP       at 0 range  0 ..  4;
      SXS      at 0 range  5 ..  5;
      EMS      at 0 range  6 ..  6;
      CCCS     at 0 range  7 ..  7;
      NCS      at 0 range  8 .. 12;
      PSC      at 0 range 13 .. 13;
      SSC      at 0 range 14 .. 14;
      PMD      at 0 range 15 .. 15;
      FBSS     at 0 range 16 .. 16;
      SPM      at 0 range 17 .. 17;
      SAM      at 0 range 18 .. 18;
      Reserved at 0 range 19 .. 19;
      ISS      at 0 range 20 .. 23;
      SCLO     at 0 range 24 .. 24;
      SAL      at 0 range 25 .. 25;
      SALP     at 0 range 26 .. 26;
      SSS      at 0 range 27 .. 27;
      SMPS     at 0 range 28 .. 28;
      SSNTF    at 0 range 29 .. 29;
      SNCQ     at 0 range 30 .. 30;
      S64A     at 0 range 31 .. 31;
   end record;

   type Global_HBA_Control_Type is record
      HR       : Boolean;
      IE       : Boolean;
      MRSM     : Boolean;
      Reserved : Bit_Array (3 .. 30);
      AE       : Boolean;
   end record
   with
      Size => 4 * 8;

   for Global_HBA_Control_Type use record
      HR       at 0 range  0 ..  0;
      IE       at 0 range  1 ..  1;
      MRSM     at 0 range  2 ..  2;
      Reserved at 0 range  3 .. 30;
      AE       at 0 range 31 .. 31;
   end record;

   type Version_Type is record
      MIN : Interfaces.Unsigned_16;
      MJR : Interfaces.Unsigned_16;
   end record
   with
      Size => 4 * 8;

   for Version_Type use record
      MIN at 0 range  0 .. 15;
      MJR at 0 range 16 .. 31;
   end record;

   type Generic_Host_Control_Type is record
      Host_Capabilities     : HBA_Caps_Type;
      Global_Host_Control   : Global_HBA_Control_Type;
      Interrupt_Status      : Bit_Array (0 .. 31);
      Ports_Implemented     : Bit_Array (0 .. 31);
      Version               : Version_Type;
      CCC_Control           : Interfaces.Unsigned_32;
      CCC_Ports             : Interfaces.Unsigned_32;
      Enclosure_Mgmt_Loc    : Interfaces.Unsigned_32;
      Enclosure_Mgmt_Ctrl   : Interfaces.Unsigned_32;
      Host_Capabilities_Ext : Interfaces.Unsigned_32;
      BIOS_HO_Status_Ctrl   : Interfaces.Unsigned_32;
   end record
   with
      Size => 16#2c# * 8;

   for Generic_Host_Control_Type use record
      Host_Capabilities     at 16#00# range 0 .. 31;
      Global_Host_Control   at 16#04# range 0 .. 31;
      Interrupt_Status      at 16#08# range 0 .. 31;
      Ports_Implemented     at 16#0c# range 0 .. 31;
      Version               at 16#10# range 0 .. 31;
      CCC_Control           at 16#14# range 0 .. 31;
      CCC_Ports             at 16#18# range 0 .. 31;
      Enclosure_Mgmt_Loc    at 16#1c# range 0 .. 31;
      Enclosure_Mgmt_Ctrl   at 16#20# range 0 .. 31;
      Host_Capabilities_Ext at 16#24# range 0 .. 31;
      BIOS_HO_Status_Ctrl   at 16#28# range 0 .. 31;
   end record;

   --  Serial ATA AHCI 1.3.1 Specification, section 3.3.
   type Port_Registers_Type is record
      Cmd_List_Base_Addr       : Interfaces.Unsigned_32;
      Cmd_List_Base_Upper_Addr : Interfaces.Unsigned_32;
      FIS_Base_Addr            : Interfaces.Unsigned_32;
      FIS_Base_Upper_Addr      : Interfaces.Unsigned_32;
      Interrupt_Status         : Interfaces.Unsigned_32;
      Interrupt_Enable         : Interfaces.Unsigned_32;
      Command_And_Status       : Interfaces.Unsigned_32;
      Reserved_1               : Interfaces.Unsigned_32;
      Task_File_Data           : Interfaces.Unsigned_32;
      Signature                : Interfaces.Unsigned_32;
      SATA_Status              : Interfaces.Unsigned_32;
      SATA_Control             : Interfaces.Unsigned_32;
      SATA_Error               : Interfaces.Unsigned_32;
      SATA_Active              : Interfaces.Unsigned_32;
      Command_Issue            : Interfaces.Unsigned_32;
      SATA_Notification        : Interfaces.Unsigned_32;
      FIS_Based_Switching_Ctrl : Interfaces.Unsigned_32;
      Device_Sleep             : Interfaces.Unsigned_32;
      Reserved_2               : Byte_Array (16#48# .. 16#6f#);
      Vendor_Specific          : Byte_Array (16#70# .. 16#7f#);
   end record
   with
      Size => 16#80# * 8;

   for Port_Registers_Type use record
      Cmd_List_Base_Addr       at 16#00# range 0 ..  31;
      Cmd_List_Base_Upper_Addr at 16#04# range 0 ..  31;
      FIS_Base_Addr            at 16#08# range 0 ..  31;
      FIS_Base_Upper_Addr      at 16#0c# range 0 ..  31;
      Interrupt_Status         at 16#10# range 0 ..  31;
      Interrupt_Enable         at 16#14# range 0 ..  31;
      Command_And_Status       at 16#18# range 0 ..  31;
      Reserved_1               at 16#1c# range 0 ..  31;
      Task_File_Data           at 16#20# range 0 ..  31;
      Signature                at 16#24# range 0 ..  31;
      SATA_Status              at 16#28# range 0 ..  31;
      SATA_Control             at 16#2c# range 0 ..  31;
      SATA_Error               at 16#30# range 0 ..  31;
      SATA_Active              at 16#34# range 0 ..  31;
      Command_Issue            at 16#38# range 0 ..  31;
      SATA_Notification        at 16#3c# range 0 ..  31;
      FIS_Based_Switching_Ctrl at 16#40# range 0 ..  31;
      Device_Sleep             at 16#44# range 0 ..  31;
      Reserved_2               at 16#48# range 0 .. 319;
      Vendor_Specific          at 16#70# range 0 .. 127;
   end record;

   type Ports_Array is array (0 .. 31) of Port_Registers_Type
   with
      Pack;

   Instance : Generic_Host_Control_Type
   with
      Volatile,
      Async_Readers,
      Async_Writers,
      Address => System'To_Address (Ahci_Controller_Ahci_Registers_Address);

   Ports : Ports_Array
   with
      Volatile,
      Async_Readers,
      Async_Writers,
      Address => System'To_Address
        (Ahci_Controller_Ahci_Registers_Address + 16#100#);

end Ahci.Registers;