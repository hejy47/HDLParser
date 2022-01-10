----------------------------------------------------------------------------------
-- GCVideo DVI HDL
-- Copyright (C) 2014-2020, Ingo Korb <ingo@akana.de>
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- 1. Redistributions of source code must retain the above copyright notice,
--    this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright notice,
--    this list of conditions and the following disclaimer in the documentation
--    and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
-- THE POSSIBILITY OF SUCH DAMAGE.
--
-- ZPUVideoInterface.vhd: Video size measurement and a few config outputs
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.video_defs.all;
use work.ZPUDevices.all;

entity ZPUVideoInterface is
  port (
    Clock           : in  std_logic;
    PixelClockEnable: in  boolean;
    Video           : in  VideoY422;
    ConsoleMode     : in  console_mode_t;
    ForceYPbPr      : in  boolean;
    ZSelect         : in  std_logic;
    ZPUBusIn        : in  ZPUDeviceIn;
    ZPUBusOut       : out ZPUDeviceOut;
    IRQ             : out std_logic;
    VSettings       : out VideoSettings_t;
    OSDSettings     : out OSDSettings_t;
    ImageControls   : out ImageControls_t
  );
end ZPUVideoInterface;

architecture Behavioral of ZPUVideoInterface is
  -- everything disabled by default
  --                                                109876543210
  constant VidSettingsDefault: std_logic_vector := "000000000000";

  -- output disabled, colors don't matter
  constant OSDBGSettingsDefault: std_logic_vector := "1------------------------";

  signal current_pixelcount: natural range 0 to 880;
  signal current_linecount : natural range 0 to 650;
  signal pixel_counter     : natural range 0 to 880;
  signal line_counter      : natural range 0 to 650;

  signal prev_hsync        : boolean;
  signal prev_vsync        : boolean;
  signal active_line       : boolean;
  signal active_line_count : natural range 0 to 7;
  signal volume_setting    : std_logic_vector( 7 downto 0) := x"ff";
  signal vid_settings      : std_logic_vector(11 downto 0) := VidSettingsDefault;
  signal osd_bgsettings    : std_logic_vector(24 downto 0) := OSDBGSettingsDefault;
  signal image_controls    : std_logic_vector(24 downto 0);

  signal stored_flags      : std_logic_vector(2 downto 0);
  signal console_mode      : std_logic;
  signal force_ypbpr       : std_logic;
begin

  ZPUBusOut.mem_busy <= '0';
  console_mode       <= '1' when ConsoleMode = MODE_WII else '0';
  force_ypbpr        <= '1' when ForceYPbPr             else '0';

  -- forward stored videosettings to output
  VSettings.ScanlineProfile    <= vid_settings(1 downto 0);
  VSettings.ScanlinesEven      <= (vid_settings(2)  = '1');
  VSettings.ScanlinesAlternate <= (vid_settings(3)  = '1');
  VSettings.LinedoublerEnabled <= (vid_settings(4)  = '1');
  VSettings.CableDetect        <= (vid_settings(5)  = '1');
  VSettings.LimitedRange       <= (vid_settings(6)  = '1');
  VSettings.EnhancedMode       <= (vid_settings(7)  = '1');
  VSettings.Widescreen         <= (vid_settings(8)  = '1');
  VSettings.AnalogRGBOutput    <= (vid_settings(9)  = '1');
  VSettings.SyncOnGreen        <= (vid_settings(10) = '1');
  VSettings.SampleRateHack     <= (vid_settings(11) = '1');
  VSettings.Volume             <= unsigned(volume_setting);

  -- putting this bit in an unrelated register simplifies the software side
  VSettings.DisableOutput      <= (osd_bgsettings(24) = '1');

  -- forward OSD settings to output
  OSDSettings.BGAlpha    <= unsigned(osd_bgsettings(23 downto 16));
  OSDSettings.BGTintCb   <=   signed(osd_bgsettings(15 downto  8));
  OSDSettings.BGTintCr   <=   signed(osd_bgsettings( 7 downto  0));

  -- forward picture settings
  ImageControls.Saturation <= unsigned(image_controls(24 downto 16));
  ImageControls.Brightness <=   signed(image_controls(15 downto  8));
  ImageControls.Contrast   <= unsigned(image_controls( 7 downto  0));

  process(Clock)
  begin
    if rising_edge(Clock) then
      ---- ZPU bus interface
      -- system reset
      if ZPUBusIn.Reset = '1' then
        IRQ             <= '0';
        vid_settings    <= VidSettingsDefault;
        osd_bgsettings  <= OSDBGSettingsDefault;
        volume_setting  <= x"ff";
      end if;

      -- reset interrupt flag on any write
      if ZSelect = '1' and ZPUBusIn.mem_writeEnable = '1' then
        IRQ <= '0';
      end if;

      -- read path
      case ZPUBusIn.mem_addr(4 downto 2) is
        when "000"  => ZPUBusOut.mem_read <= std_logic_vector(to_unsigned(pixel_counter, 32));
        when "001"  => ZPUBusOut.mem_read <= std_logic_vector(to_unsigned(line_counter,  32));

        when "010"  => ZPUBusOut.mem_read             <= (others => '0');
                       ZPUBusOut.mem_read(4)          <= force_ypbpr;
                       ZPUBusOut.mem_read(3)          <= console_mode;
                       ZPUBusOut.mem_read(2 downto 0) <= stored_flags;

        when others => ZPUBusOut.mem_read <= (others => '-');  -- undefined
      end case;

      -- write path
      if ZSelect = '1' and ZPUBusIn.mem_writeEnable = '1' then
        case ZPUBusIn.mem_addr(4 downto 2) is
          when "000"  => vid_settings   <= ZPUBusIn.mem_write(11 downto 0);
          when "001"  => osd_bgsettings <= ZPUBusIn.mem_write(24 downto 0);
          when "010"  => volume_setting <= ZPUBusIn.mem_write( 7 downto 0);
          when "011"  => image_controls <= ZPUBusIn.mem_write(24 downto 0);
          when others => null;
        end case;
      end if;

      ---- update signal measurements
      if PixelClockEnable then
        prev_vsync <= Video.VSync;
        prev_hsync <= Video.HSync;

        if not Video.Blanking then
          -- non-blank pixel on line
          current_pixelcount <= current_pixelcount + 1;
          active_line        <= true;
        end if;

        if Video.HSync and not prev_hsync and
           not Video.VSync then
          -- start of HSync, outside VSync
          if active_line then
            -- measure just one line per frame, but not the first
            if active_line_count < 7 then
              active_line_count <= active_line_count + 1;
            end if;

            if active_line_count = 6 then
              pixel_counter <= current_pixelcount;
            end if;

            current_linecount <= current_linecount + 1;
          end if;

          current_pixelcount <= 0;
          active_line        <= false;
        end if;

        if Video.VSync and not prev_vsync then
          -- start of VSync, copy remaining measurements
          IRQ <= '1';

          line_counter      <= current_linecount;
          current_linecount <= 0;
          active_line_count <= 0;

          stored_flags <= (others => '0');
          if Video.IsProgressive then
            stored_flags(0) <= '1';
          end if;
          if Video.IsPAL then
            stored_flags(1) <= '1';
          end if;
          if Video.Is30kHz then
            stored_flags(2) <= '1';
          end if;
        end if;

      end if;
    end if;
  end process;

end Behavioral;

