--
--  Copyright (C) 2015  Reto Buerki <reet@codelabs.ch>
--  Copyright (C) 2015  Adrian-Ken Rueegsegger <ken@codelabs.ch>
--  All rights reserved.
--
--  Redistribution and use in source and binary forms, with or without
--  modification, are permitted provided that the following conditions are met:
--
--    * Redistributions of source code must retain the above copyright notice,
--      this list of conditions and the following disclaimer.
--
--    * Redistributions in binary form must reproduce the above copyright
--      notice, this list of conditions and the following disclaimer in the
--      documentation and/or other materials provided with the distribution.
--
--  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
--  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
--  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
--  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
--  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
--  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
--  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
--  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
--  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
--  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
--  POSSIBILITY OF SUCH DAMAGE.
--

package Mutime.Info
with
   Abstract_State => (State with External => Async_Writers)
is

   use type Interfaces.Integer_64;

   subtype Timezone_Type is Interfaces.Integer_64 range
     -12 * 60 * 60 * 10 ** 6 .. 14 * 60 * 60 * 10 ** 6;

   --  TSC tick rate in Hz from 1 Mhz to 100 Ghz.
   subtype TSC_Tick_Rate_Hz_Type is
     Interfaces.Unsigned_64 range 1000000 .. 100000000000;

   Time_Info_Size : constant := 24;

   --D @Interface
   --D This record is used to exchange time information from the time subject to
   --D clients.
   type Time_Info_Type is record
      --D @Interface
      --D Mutime timestamp when TSC was zero. A TSC_Time_Base value of zero
      --D indicates that the time info is not (yet) valid.
      TSC_Time_Base      : Timestamp_Type'Base with Atomic;
      --D @Interface
      --D TSC Ticks in Hz
      TSC_Tick_Rate_Hz   : TSC_Tick_Rate_Hz_Type'Base;
      --D @Interface
      --D Timezone offset in microseconds
      Timezone_Microsecs : Timezone_Type'Base;
   end record
   with Size => Time_Info_Size * 8;

   --  Return validity status of time info page.
   function Is_Valid return Boolean
   with
      Global => (Input => State),
      Volatile_Function;

   --  Calculate current timestamp using the information stored in the time
   --  info record and the specified CPU ticks. The procedure returns the
   --  timestamp and the applied correction to the time base in microseconds
   --  if Success is True. No timezone offset is applied.
   procedure Get_Current_Time_UTC
     (Schedule_Ticks :     Interfaces.Unsigned_64;
      Correction     : out Interfaces.Integer_64;
      Timestamp      : out Timestamp_Type;
      Success        : out Boolean)
   with
      Global  => (Input => State),
      Depends => ((Correction, Timestamp) => (Schedule_Ticks, State),
                  Success                 => State);

   --  Calculate current timestamp using the information stored in the time
   --  info record and the specified CPU ticks. The procedure returns the
   --  timestamp and the applied correction to the time base in microseconds
   --  if Success is True. The correction also takes the timezone offset into
   --  account.
   procedure Get_Current_Time
     (Schedule_Ticks :     Interfaces.Unsigned_64;
      Correction     : out Interfaces.Integer_64;
      Timestamp      : out Timestamp_Type;
      Success        : out Boolean)
   with
      Global  => (Input => State),
      Depends => ((Correction, Timestamp) => (Schedule_Ticks, State),
                   Success                => State);

   --  Return time at system boot.
   procedure Get_Boot_Time (Timestamp : out Timestamp_Type)
   with
      Global  => (Input => State),
      Depends => (Timestamp => State);

private

   for Time_Info_Type use record
      TSC_Time_Base      at  0 range 0 .. 63;
      TSC_Tick_Rate_Hz   at  8 range 0 .. 63;
      Timezone_Microsecs at 16 range 0 .. 63;
   end record;
   for Time_Info_Type'Object_Size use Time_Info_Size * 8;

   function Valid (TI : Time_Info_Type) return Boolean
   is (TI.TSC_Time_Base in Timestamp_Type
       and TI.TSC_Time_Base /= 0
       and TI.TSC_Tick_Rate_Hz in TSC_Tick_Rate_Hz_Type
       and TI.Timezone_Microsecs in Timezone_Type)
   with
      Post => (if Valid'Result then TI.TSC_Time_Base /= 0);

   procedure Get_Current_Time
     (TI              :     Time_Info_Type;
      Schedule_Ticks  :     Interfaces.Unsigned_64;
      Timezone_Offset :     Timezone_Type;
      Correction      : out Interfaces.Integer_64;
      Timestamp       : out Timestamp_Type)
   with
      Depends => ((Correction, Timestamp) => (Schedule_Ticks, Timezone_Offset,
                                              TI)),
      Pre     => Valid (TI => TI);

   procedure Get_Boot_Time
     (TI        :     Time_Info_Type;
      Timestamp : out Timestamp_Type)
   with
      Depends => (Timestamp => TI),
      Pre     => Valid (TI => TI);

end Mutime.Info;
