-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

context work.vunit_context;
context work.com_context;
use work.axi_stream_pkg.all;

entity axi_stream_monitor is
  generic (
    monitor : axi_stream_monitor_t);
  port (
    aclk : in std_logic;
    tvalid : in std_logic;
    tready : in std_logic := '1';
    tdata : in std_logic_vector(data_length(monitor) - 1 downto 0);
    tlast : in std_logic := '1'
    );
end entity;

architecture a of axi_stream_monitor is
begin
  main : process
    variable msg : msg_t;
    variable axi_stream_transaction : axi_stream_transaction_t(tdata(tdata'range));
  begin
    wait until (tvalid and tready) = '1' and rising_edge(aclk);

    if is_visible(monitor.p_logger, debug) then
      debug(monitor.p_logger, "tdata: " & to_nibble_string(tdata) & " (" & to_integer_string(tdata) & ")" &
        ", tlast: " & to_string(tlast));
    end if;

    axi_stream_transaction := (tdata, tlast = '1');
    msg := new_axi_stream_transaction_msg(axi_stream_transaction);
    publish(net, monitor.p_actor, msg);
  end process;

end architecture;
