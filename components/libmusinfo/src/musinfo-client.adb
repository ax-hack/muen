--
--  Copyright (C) 2016  Reto Buerki <reet@codelabs.ch>
--  Copyright (C) 2016  Adrian-Ken Rueegsegger <ken@codelabs.ch>
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

with Interfaces;

with Musinfo.Client.Sinfo;

package body Musinfo.Client
with
   Refined_State => (State => (Sinfo.Object, Sinfo_Valid))
is

   use type Interfaces.Unsigned_64;

   -------------------------------------------------------------------------

   procedure Check_Validity
   is
      Magic : constant Interfaces.Unsigned_64 := Sinfo.Object.Magic;
   begin
      Sinfo_Valid := Magic = Muen_Subject_Info_Magic;
   end Check_Validity;

   -------------------------------------------------------------------------

   function Is_Valid return Boolean
   with
      Refined_Post => Is_Valid'Result = Sinfo_Valid
   is
   begin
      return Sinfo_Valid;
   end Is_Valid;

   -------------------------------------------------------------------------

   function TSC_Khz return TSC_Tick_Rate_Khz_Type
   with
      Refined_Global => (Input    => Sinfo.Object,
                         Proof_In => Sinfo_Valid)
   is
   begin
      return Sinfo.Object.TSC_Khz;
   end TSC_Khz;

end Musinfo.Client;
