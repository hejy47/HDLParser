-- Common com types.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015-2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

use std.textio.all;

use work.queue_pkg.all;

package com_types_pkg is
  type com_status_t is (ok,
                        timeout,
                        null_message_error,
                        unknown_actor_error,
                        unknown_receiver_error,
                        unknown_subscriber_error,
                        unknown_publisher_error,
                        deferred_receiver_error,
                        already_a_subscriber_error,
                        not_a_subscriber_error,
                        full_inbox_error,
                        reply_missing_request_id_error,
                        unknown_request_id_error,
                        deprecated_interface_error,
                        insufficient_size_error,
                        duplicate_actor_name_error);

  subtype com_error_t is com_status_t range timeout to duplicate_actor_name_error;

  type actor_t is record
    id : natural;
  end record actor_t;
  constant null_actor_c : actor_t := (id => 0);

  subtype message_id_t is natural;
  constant no_message_id_c : message_id_t := 0;

  type message_t is record
    id         : message_id_t;
    status     : com_status_t;
    sender     : actor_t;
    receiver   : actor_t;
    request_id : message_id_t;
    payload    : line;
  end record message_t;
  type message_ptr_t is access message_t;

  subtype msg_data_t is queue_t;
  type msg_t is record
    id         : message_id_t;
    status     : com_status_t;
    sender     : actor_t;
    receiver   : actor_t;
    request_id : message_id_t;
    data       : msg_data_t;
  end record msg_t;

  type subscription_traffic_type_t is (published, outbound, inbound);

  type receipt_t is record
    status : com_status_t;
    id     : message_id_t;
  end record receipt_t;

  subtype network_t is std_logic;
  constant network_event : std_logic := '1';
  constant idle_network  : std_logic := 'Z';

  alias event_t is network_t;
  alias no_event is idle_network;

  constant max_timeout_c : time := 1 hr;  -- ModelSim can't handle time'high
end package;
