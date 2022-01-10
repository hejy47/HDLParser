-- Com package provides a generic communication mechanism for testbenches
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015-2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.math_complex.all;
use ieee.numeric_bit.all;
use ieee.numeric_std.all;
use ieee.fixed_pkg.all;
use ieee.float_pkg.all;

context work.vunit_context;

use work.queue_pkg.all;
use work.queue_2008_pkg.all;
use work.integer_vector_ptr_pkg.all;
use work.string_ptr_pkg.all;
use work.codec_pkg.all;
use work.com_support_pkg.all;
use work.com_messenger_pkg.all;
use work.com_common_pkg.all;
use work.queue_pool_pkg.all;

use std.textio.all;

package body com_pkg is
  -----------------------------------------------------------------------------
  -- Handling of actors
  -----------------------------------------------------------------------------
  impure function new_actor (name : string := ""; inbox_size : positive := positive'high) return actor_t is
  begin
    return messenger.create(name, inbox_size);
  end;

  impure function find (name : string; enable_deferred_creation : boolean := true) return actor_t is
  begin
    return messenger.find(name, enable_deferred_creation);
  end;

  impure function name (actor : actor_t) return string is
  begin
    return messenger.name(actor);
  end;

  procedure destroy (actor : inout actor_t) is
  begin
    messenger.destroy(actor);
  end;

  procedure reset_messenger is
  begin
    messenger.reset_messenger;
  end;

  impure function num_of_actors
    return natural is
  begin
    return messenger.num_of_actors;
  end;

  impure function num_of_deferred_creations
    return natural is
  begin
    return messenger.num_of_deferred_creations;
  end;

  impure function inbox_size (actor : actor_t) return natural is
  begin
    return messenger.inbox_size(actor);
  end;

  procedure resize_inbox (actor : actor_t; new_size : natural) is
  begin
    messenger.resize_inbox(actor, new_size);
  end;

  -----------------------------------------------------------------------------
  -- Message related subprograms
  -----------------------------------------------------------------------------
  impure function new_msg (sender : actor_t := null_actor_c) return msg_t is
    variable msg : msg_t;
  begin
    msg.sender := sender;
    msg.data   := new_queue(queue_pool);
    return msg;
  end;

  procedure delete (msg : inout msg_t) is
  begin
    msg.id         := no_message_id_c;
    msg.status     := ok;
    msg.sender     := null_actor_c;
    msg.receiver   := null_actor_c;
    msg.request_id := no_message_id_c;
    recycle(queue_pool, msg.data);
  end procedure delete;

  impure function copy(msg : msg_t) return msg_t is
    variable result : msg_t := msg;
  begin
    result.data := copy(msg.data);
    return result;
  end;

  function sender(msg : msg_t) return actor_t is
  begin
    return msg.sender;
  end;

  function receiver(msg : msg_t) return actor_t is
  begin
    return msg.receiver;
  end;

  impure function to_string(msg : msg_t) return string is
    function to_id_string(id : message_id_t) return string is
    begin
      if id = no_message_id_c then
        return "-";
      else
        return to_string(id);
      end if;
    end function;
    impure function to_actor_string(actor : actor_t) return string is
    begin
      if actor = null_actor_c then
        return "-";
      else
        return name(actor);
      end if;
    end function;
  begin
    return to_id_string(msg.id) & ":" & to_id_string(msg.request_id) & " " &
      to_actor_string(msg.sender) & " -> " & to_actor_string(msg.receiver);
  end;

  impure function to_string (msg_vec : msg_vec_t) return string is
    variable l : line;
  begin
    for i in msg_vec'range loop
      write(l, to_string(i) & ". " & to_string(msg_vec(i)));
      if i /= msg_vec'right then
        write(l, LF);
      end if;
    end loop;

    return l.all;
  end;


  -----------------------------------------------------------------------------
  -- Subprograms for pushing/popping data to/from a message. Data is popped
  -- from a message in the same order they were pushed (FIFO)
  -----------------------------------------------------------------------------
  procedure push(msg : msg_t; value : integer) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return integer is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : character) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return character is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : boolean) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return boolean is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : real) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return real is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : bit) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return bit is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : std_ulogic) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return std_ulogic is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : severity_level) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return severity_level is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : file_open_status) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return file_open_status is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : file_open_kind) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return file_open_kind is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : bit_vector) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return bit_vector is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : std_ulogic_vector) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return std_ulogic_vector is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : complex) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return complex is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : complex_polar) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return complex_polar is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : ieee.numeric_bit.unsigned) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return ieee.numeric_bit.unsigned is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : ieee.numeric_bit.signed) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return ieee.numeric_bit.signed is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : ieee.numeric_std.unsigned) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return ieee.numeric_std.unsigned is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : ieee.numeric_std.signed) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return ieee.numeric_std.signed is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : string) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return string is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : time) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return time is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : integer_vector_ptr_t) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return integer_vector_ptr_t is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : string_ptr_t) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return string_ptr_t is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : queue_t) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return queue_t is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : boolean_vector) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return boolean_vector is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : integer_vector) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return integer_vector is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : real_vector) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return real_vector is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : time_vector) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return time_vector is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : ufixed) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return ufixed is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : sfixed) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return sfixed is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : float) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return float is
  begin
    return pop(msg.data);
  end;

  -----------------------------------------------------------------------------
  -- Primary send and receive related subprograms
  -----------------------------------------------------------------------------
  procedure wait_on_subscribers (
    publisher                  : actor_t;
    subscription_traffic_types : subscription_traffic_types_t;
    timeout                    : time) is
  begin
    if messenger.subscriber_inbox_is_full(publisher, subscription_traffic_types) then
      wait on net until not messenger.subscriber_inbox_is_full(publisher, subscription_traffic_types) for timeout;
      check(not messenger.subscriber_inbox_is_full(publisher, subscription_traffic_types), full_inbox_error);
    end if;
  end procedure wait_on_subscribers;

  procedure send (
    signal net          : inout network_t;
    constant receiver   : in    actor_t;
    constant mailbox_id : in    mailbox_id_t;
    variable msg        : inout msg_t;
    constant timeout    : in    time := max_timeout_c) is
    variable t_start : time;
  begin
    if not check(msg.data /= null_queue, null_message_error) then
      return;
    end if;

    if not check(not messenger.unknown_actor(receiver), unknown_receiver_error) then
      return;
    end if;

    t_start := now;
    if messenger.is_full(receiver, mailbox_id) then
      wait on net until not messenger.is_full(receiver, mailbox_id) for timeout;
      check(not messenger.is_full(receiver, mailbox_id), full_inbox_error);
    end if;

    messenger.send(receiver, mailbox_id, msg);

    if msg.sender /= null_actor_c then
      if messenger.has_subscribers(msg.sender, outbound) then
        wait_on_subscribers(msg.sender, (0             => outbound), timeout - (now - t_start));
        messenger.internal_publish(msg.sender, msg, (0 => outbound));
      end if;
    end if;

    if (mailbox_id = inbox) and messenger.has_subscribers(receiver, inbound) then
      wait_on_subscribers(receiver, (0             => inbound), timeout - (now - t_start));
      messenger.internal_publish(receiver, msg, (0 => inbound));
    end if;

    notify(net);
    recycle(queue_pool, msg.data);
  end;

  procedure send (
    signal net        : inout network_t;
    constant receiver : in    actor_t;
    variable msg      : inout msg_t;
    constant timeout  : in    time := max_timeout_c) is
  begin
    send(net, receiver, inbox, msg, timeout);
  end;

  procedure send (
    signal net         : inout network_t;
    constant receivers : in    actor_vec_t;
    variable msg       : inout msg_t;
    constant timeout   : in    time := max_timeout_c) is
    variable msg_to_send : msg_t;
    variable t_start : time;
  begin
    if receivers'length = 0 then
      delete(msg);
      return;
    end if;

    t_start := now;
    for i in receivers'range loop
      if i = receivers'right then
        send(net, receivers(i), msg, timeout - (now - t_start));
      else
        msg_to_send := copy(msg);
        send(net, receivers(i), msg_to_send, timeout - (now - t_start));
      end if;
    end loop;
  end;

  procedure receive (
    signal net        : inout network_t;
    constant receiver : in    actor_t;
    variable msg      : inout msg_t;
    constant timeout  : in    time := max_timeout_c) is
  begin
    receive(net, actor_vec_t'(0 => receiver), msg, timeout);
  end;

  procedure receive (
    signal net         : inout network_t;
    constant receivers : in    actor_vec_t;
    variable msg       : inout msg_t;
    constant timeout   : in    time := max_timeout_c) is
    variable status                  : com_status_t;
    variable started_with_full_inbox : boolean;
    variable receiver                : actor_t;
  begin
    delete(msg);
    wait_for_message(net, receivers, status, timeout);
    if not check(no_error_status(status), status) then
      return;
    end if;

    for i in receivers'range loop
      receiver := receivers(i);
      if has_message(receiver) then
        started_with_full_inbox := messenger.is_full(receiver, inbox);
        msg                     := get_message(receiver);
        exit;
      end if;
    end loop;

    if started_with_full_inbox or messenger.has_subscribers(receiver, inbound) then
      notify(net);
    end if;
  end;

  procedure reply (
    signal net           : inout network_t;
    variable request_msg : inout msg_t;
    variable reply_msg   : inout msg_t;
    constant timeout     : in    time := max_timeout_c) is
  begin
    check(request_msg.id /= no_message_id_c, reply_missing_request_id_error);
    reply_msg.request_id := request_msg.id;
    reply_msg.sender     := request_msg.receiver;

    if request_msg.sender /= null_actor_c then
      send(net, request_msg.sender, inbox, reply_msg, timeout);
    else
      send(net, request_msg.receiver, outbox, reply_msg, timeout);
    end if;
  end;

  procedure receive_reply (
    signal net           : inout network_t;
    variable request_msg : inout msg_t;
    variable reply_msg   : inout msg_t;
    constant timeout     : in    time := max_timeout_c) is
    variable status       : com_status_t;
    variable source_actor : actor_t;
    variable mailbox      : mailbox_id_t;
    variable message      : message_ptr_t;
  begin
    delete(reply_msg);

    source_actor := request_msg.sender when request_msg.sender /= null_actor_c else request_msg.receiver;
    mailbox      := inbox              when request_msg.sender /= null_actor_c else outbox;

    wait_for_reply_stash_message(net, source_actor, mailbox, request_msg.id, status, timeout);
    check(no_error_status(status), status);
    message              := get_reply_stash_message(source_actor);
    reply_msg.id         := message.id;
    reply_msg.status     := message.status;
    reply_msg.sender     := message.sender;
    reply_msg.receiver   := message.receiver;
    reply_msg.request_id := message.request_id;
    reply_msg.data       := decode(message.payload.all);
    delete(message);
  end;

  procedure publish (
    signal net       : inout network_t;
    constant sender  : in    actor_t;
    variable msg     : inout msg_t;
    constant timeout : in    time := max_timeout_c) is
  begin
    wait_on_subscribers(sender, (published, outbound), timeout);
    messenger.publish(sender, msg, (published, outbound));
    notify(net);
    recycle(queue_pool, msg.data);
  end;

  -----------------------------------------------------------------------------
  -- Secondary send and receive related subprograms
  -----------------------------------------------------------------------------
  procedure request (
    signal net           : inout network_t;
    constant receiver    : in    actor_t;
    variable request_msg : inout msg_t;
    variable reply_msg   : inout msg_t;
    constant timeout     : in    time := max_timeout_c) is
    variable start : time;
  begin
    start := now;
    send(net, receiver, request_msg, timeout);
    receive_reply(net, request_msg, reply_msg, timeout - (now - start));
  end;

  procedure request (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    variable request_msg  : inout msg_t;
    variable positive_ack : out   boolean;
    constant timeout      : in    time := max_timeout_c) is
    variable start : time;
  begin
    start := now;
    send(net, receiver, request_msg, timeout);
    receive_reply(net, request_msg, positive_ack, timeout - (now - start));
  end;

  procedure acknowledge (
    signal net            : inout network_t;
    variable request_msg  : inout msg_t;
    constant positive_ack : in    boolean := true;
    constant timeout      : in    time    := max_timeout_c) is
    variable reply_msg : msg_t;
  begin
    reply_msg := new_msg;
    push_boolean(reply_msg.data, positive_ack);
    reply(net, request_msg, reply_msg, timeout);
  end;

  procedure receive_reply (
    signal net            : inout network_t;
    variable request_msg  : inout msg_t;
    variable positive_ack : out   boolean;
    constant timeout      : in    time := max_timeout_c) is
    variable reply_msg : msg_t;
  begin
    receive_reply(net, request_msg, reply_msg, timeout);
    positive_ack := pop_boolean(reply_msg.data);
    delete(reply_msg);
  end;

  -----------------------------------------------------------------------------
  -- Low-level subprograms primarily used for handling timeout wihout error
  -----------------------------------------------------------------------------
  procedure wait_for_message (
    signal net        : in  network_t;
    constant receiver : in  actor_t;
    variable status   : out com_status_t;
    constant timeout  : in  time := max_timeout_c) is
  begin
    wait_for_message(net, actor_vec_t'(0 => receiver), status, timeout);
  end procedure wait_for_message;

  procedure wait_for_message (
    signal net         : in  network_t;
    constant receivers : in  actor_vec_t;
    variable status    : out com_status_t;
    constant timeout   : in  time := max_timeout_c) is
  begin
    for i in receivers'range loop
      if not check(not messenger.deferred(receivers(i)), deferred_receiver_error) then
        status := deferred_receiver_error;
        return;
      end if;
    end loop;

    status := ok;
    if not messenger.has_messages(receivers) then
      wait on net until messenger.has_messages(receivers) for timeout;
      if not messenger.has_messages(receivers) then
        status := work.com_types_pkg.timeout;
      end if;
    end if;
  end procedure wait_for_message;

  impure function has_message (actor : actor_t) return boolean is
  begin
    return messenger.has_messages(actor);
  end function has_message;

  procedure wait_for_reply (
    signal net           : inout network_t;
    variable request_msg : inout msg_t;
    variable status      : out   com_status_t;
    constant timeout     : in    time := max_timeout_c) is
    variable source_actor : actor_t;
    variable mailbox      : mailbox_id_t;
  begin
    source_actor := request_msg.sender when request_msg.sender /= null_actor_c else request_msg.receiver;
    mailbox      := inbox              when request_msg.sender /= null_actor_c else outbox;

    wait_for_reply_stash_message(net, source_actor, mailbox, request_msg.id, status, timeout);
  end;

  impure function get_message (receiver : actor_t) return msg_t is
    variable msg : msg_t;
  begin
    check(messenger.has_messages(receiver), null_message_error);

    msg.status     := ok;
    msg.id         := messenger.get_id(receiver);
    msg.request_id := messenger.get_request_id(receiver);
    msg.sender     := messenger.get_sender(receiver);
    msg.receiver   := messenger.get_receiver(receiver);
    msg.data       := decode(messenger.get_payload(receiver));
    messenger.delete_first_envelope(receiver);

    return msg;
  end function get_message;

  procedure get_reply (variable request_msg : inout msg_t; variable reply_msg : inout msg_t) is
    variable source_actor : actor_t;
    variable message      : message_ptr_t;
  begin
    source_actor := request_msg.sender when request_msg.sender /= null_actor_c else request_msg.receiver;

    check(messenger.has_reply_stash_message(source_actor), null_message_error);
    message              := get_reply_stash_message(source_actor);
    check(message.request_id = request_msg.id, unknown_request_id_error);
    reply_msg.id         := message.id;
    reply_msg.status     := message.status;
    reply_msg.sender     := message.sender;
    reply_msg.receiver   := message.receiver;
    reply_msg.request_id := message.request_id;
    reply_msg.data       := decode(message.payload.all);
    delete(message);
  end;

  -----------------------------------------------------------------------------
  -- Subscriptions
  -----------------------------------------------------------------------------
  procedure subscribe (
    subscriber   : actor_t;
    publisher    : actor_t;
    traffic_type : subscription_traffic_type_t := published) is
  begin
    messenger.subscribe(subscriber, publisher, traffic_type);
  end procedure subscribe;

  procedure unsubscribe (
    subscriber   : actor_t;
    publisher    : actor_t;
    traffic_type : subscription_traffic_type_t := published) is
  begin
    messenger.unsubscribe(subscriber, publisher, traffic_type);
  end procedure unsubscribe;

  -----------------------------------------------------------------------------
  -- Debugging
  -----------------------------------------------------------------------------

  impure function num_of_messages (actor : actor_t; mailbox_id : mailbox_id_t := inbox) return natural is
  begin
    return messenger.num_of_messages(actor, mailbox_id);
  end;

  impure function peek_message(
    actor      : actor_t;
    position   : natural      := 0;
    mailbox_id : mailbox_id_t := inbox) return msg_t is
    variable msg : msg_t;
  begin
    if position > messenger.num_of_messages(actor, mailbox_id) - 1 then
      failure(com_logger, "Peeking non-existing position.");
      return msg;
    end if;

    msg.status     := ok;
    msg.id         := messenger.get_id(actor, position, mailbox_id);
    msg.request_id := messenger.get_request_id(actor, position, mailbox_id);
    msg.sender     := messenger.get_sender(actor, position, mailbox_id);
    msg.receiver   := messenger.get_receiver(actor, position, mailbox_id);
    msg.data       := decode(messenger.get_payload(actor, position, mailbox_id));

    return msg;
  end;

  impure function peek_all_messages(actor : actor_t; mailbox_id : mailbox_id_t := inbox) return msg_vec_ptr_t is
    variable msg_vec_ptr : msg_vec_ptr_t;
    constant n_messages  : natural := messenger.num_of_messages(actor, mailbox_id);
  begin
    if n_messages = 0 then
      return null;
    end if;

    msg_vec_ptr := new msg_vec_t(0 to n_messages - 1);
    for i in msg_vec_ptr'range loop
      msg_vec_ptr(i) := peek_message(actor, i, mailbox_id);
    end loop;

    return msg_vec_ptr;
  end;

  -----------------------------------------------------------------------------
  -- Misc
  -----------------------------------------------------------------------------
  procedure allow_timeout is
  begin
    messenger.allow_timeout;
  end;

  procedure allow_deprecated is
  begin
    messenger.allow_deprecated;
  end;

  procedure push(queue : queue_t; variable value : inout msg_t) is
  begin
    push(queue, value.id);
    push(queue, com_status_t'pos(value.status));
    push(queue, value.sender.id);
    push(queue, value.receiver.id);
    push(queue, value.request_id);
    push_queue_ref(queue, value.data);
  end;

  impure function pop(queue : queue_t) return msg_t is
    variable ret_val : msg_t := new_msg;
  begin
    ret_val.id          := pop(queue);
    ret_val.status      := com_status_t'val(integer'(pop(queue)));
    ret_val.sender.id   := pop(queue);
    ret_val.receiver.id := pop(queue);
    ret_val.request_id  := pop(queue);
    ret_val.data        := pop_queue_ref(queue);

    return ret_val;
  end;
end package body com_pkg;
