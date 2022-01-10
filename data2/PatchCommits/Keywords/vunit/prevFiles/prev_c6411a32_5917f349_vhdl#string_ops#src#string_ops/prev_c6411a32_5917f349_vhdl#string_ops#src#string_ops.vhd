-- This package contains useful string operations
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;
use ieee.numeric_std.all;

package string_ops is
  type line_vector is array (natural range <>) of line;
  type lines_t is access line_vector;
  function count (
    constant s : string;
    constant substring : string;
    constant start : natural := 0;
    constant stop : natural := 0)
    return natural;
  function count (
    constant s : string;
    constant char : character := ' ';
    constant start : natural := 0;
    constant stop : natural := 0)
    return natural;
  function strip (
    str : string;
    chars : string := " ")
    return string;
  function rstrip (
    str : string;
    chars : string := " ")
    return string;
  function lstrip (
    str : string;
    chars : string := " ")
    return string;
  function image (
    constant data : std_logic_vector)
    return string;
  function hex_image (
    constant data : std_logic_vector)
    return string;
  function replace (
    constant s      : string;
    constant old_segment : character;
    constant new_segment : character;
    constant cnt : in natural := natural'high)
    return string;
  function replace (
    constant s      : string;
    constant old_segment : string;
    constant new_segment : character;
    constant cnt : in natural := natural'high)
    return string;
  function replace (
    constant s      : string;
    constant old_segment : character;
    constant new_segment : string;
    constant cnt : in natural := natural'high)
    return string;
  function replace (
    constant s      : string;
    constant old_segment : string;
    constant new_segment : string;
    constant cnt : in natural := natural'high)
    return string;
  function title (
    constant s : string)
    return string;
  function upper (
    constant s : string)
    return string;
  function lower (
    constant s : string)
    return string;
  impure function split (
    constant s         : string;
    constant sep       : string;
    constant max_split : integer := -1)
    return lines_t;
  function to_integer_string (
    constant value : unsigned)
    return string;
  function to_integer_string (
    constant value : signed)
    return string;
  function to_integer_string (
    constant value : std_logic_vector)
    return string;
  function to_nibble_string (
    constant value : unsigned)
    return string;
  function to_nibble_string (
    constant value : std_logic_vector)
    return string;
  function to_nibble_string (
    constant value : signed)
    return string;
end package;

package body string_ops is
  function index (
    constant s      : string;
    constant offset : natural)
    return natural is
  begin
    if s'ascending then
      return s'left + offset;
    else
      return s'left - offset;
    end if;
  end function index;

  function offset (
    constant s     : string;
    constant index : natural)
    return natural is
  begin
    if s'ascending then
      return index - s'left;
    else
      return s'left - index;
    end if;    
  end function offset;

  function in_range (
    constant s     : string;
    constant index : natural)
    return boolean is
  begin
    if s'ascending then
      return (index >= s'left) and (index <= s'right);
    else
      return (index <= s'left) and (index >= s'right);
    end if;
  end function in_range;
  
  function slice (
    constant s      : string;
    constant offset : natural;
    constant length : natural)
    return string is
    variable ret_val : string(1 to length);
  begin
    if s'ascending then
      return s(s'left + offset to s'left + offset + length - 1);
    else
      return s(s'left - offset downto s'left -offset - length + 1);
    end if;
  end function slice;
  
  function image (
    constant data : std_logic_vector)
    return string is
    variable ret_val : string(1 to data'length);
  begin
    for i in ret_val'range loop
      if data'ascending then
        ret_val(i) := std_logic'image(data(data'left + i - 1))(2);
      else
        ret_val(i) := std_logic'image(data(data'left - i + 1))(2);
      end if;
    end loop;
    return ret_val;
  end;

  function hex_image (
    constant data : std_logic_vector)
    return string is
    type character_array is array (natural range <>) of character;
    variable ret_val : string(1 to (data'length + 3)/4 + 3);
    variable data_extended : std_logic_vector((((data'length + 3)/4)*4)-1 downto 0) := (others => '0');
    variable i, j, k: integer;
    variable meta_value_detected : boolean;
    constant hex_characters : character_array(0 to 15) := ('0','1','2','3','4','5','6','7','8','9','a','b','c','d','e','f');
  begin
    data_extended(data'length-1 downto 0) := data;
    j := 0;
    for i in ret_val'right - 1 downto 3 loop
      meta_value_detected := false;      
      for k in j+3 downto j loop
        if (data_extended(k) /= '1') and (data_extended(k) /= '0') then
          meta_value_detected := true;
        end if;
      end loop;
      if meta_value_detected then
        ret_val(i) := 'X';
      else
        ret_val(i) := hex_characters(to_integer(unsigned(data_extended(j+3 downto j))));
      end if;
      j := j + 4;
    end loop;
    ret_val(1 to 2) := "x""";
    ret_val(ret_val'right) := '"';
    return ret_val;
  end;

  function strip (
    str : string;
    chars : string;
    lstrip : boolean;
    rstrip : boolean)
    return string is
    variable start : integer := str'left;
    variable stop : integer := str'right;
  begin
    if str = "" then
      return "";
    end if;

    if lstrip then
      for i in str'range loop
        start := i;
        exit when count(chars, str(i)) = 0;      
      end loop;

      if count(chars, str(start)) > 0 then
        return "";
      end if;
    end if;

    if rstrip then
      for i in str'reverse_range loop
        stop := i;
        exit when count(chars, str(i)) = 0;
      end loop;      

      if count(chars, str(stop)) > 0 then
        return "";
      end if;
    end if;

    if str'ascending then
      return str(start to stop);
    else
      return str(start downto stop); 
    end if;
    
  end strip;
  
  function strip (
    str : string;
    chars : string := " ")
    return string is
  begin
    return strip(str, chars, true, true);
  end strip;

  function rstrip (
    str : string;
    chars : string := " ")
    return string is
  begin
    return strip(str, chars, false, true);
  end rstrip;

  function lstrip (
    str : string;
    chars : string := " ")
    return string is
  begin
    return strip(str, chars, true, false);
  end lstrip;

  function replace (
    constant s      : string;
    constant old_segment : string;
    constant new_segment : string;
    constant cnt : in natural := natural'high)
    return string is
    variable l : line;
    variable replaced_substrings : natural := 0;
    variable i : natural;
    variable s_int : string(1 to s'length) := s;
  begin
    deallocate(l);
    if count(s_int, old_segment) > 0 then
      i := 1;
      while i <= s_int'right - old_segment'length + 1 loop
        if (s_int(i to i + old_segment'length - 1) = old_segment) and
           (replaced_substrings < cnt) then
          write(l, new_segment);
          replaced_substrings := replaced_substrings + 1;
          i := i + old_segment'length;
        else
          write(l, s_int(i));
          i := i + 1;          
        end if;
      end loop;
      write(l, s_int(i to s_int'right));
    else
      write(l, s_int);
    end if;

    return l.all;
  end replace;
  
  function replace (
    constant s      : string;
    constant old_segment : string;
    constant new_segment : character;
    constant cnt : in natural := natural'high)
    return string is
    variable new_segment_str : string(1 to 1);
  begin
    new_segment_str(1) := new_segment;
    return replace(s, old_segment, new_segment_str, cnt);
  end replace;

  function replace (
    constant s      : string;
    constant old_segment : character;
    constant new_segment : string;
    constant cnt : in natural := natural'high)
    return string is
    variable old_segment_str : string(1 to 1);
  begin
    old_segment_str(1) := old_segment;
    return replace(s, old_segment_str, new_segment, cnt);
  end replace;

  function replace (
    constant s      : string;
    constant old_segment : character;
    constant new_segment : character;
    constant cnt : in natural := natural'high)
    return string is
    variable old_segment_str, new_segment_str : string(1 to 1);
  begin
    old_segment_str(1) := old_segment;
    new_segment_str(1) := new_segment;
    return replace(s, old_segment_str, new_segment_str, cnt);
  end replace;

  function title (
    constant s : string)
    return string is
    variable last_char : character := NUL;
    variable result : string(s'range);
  begin
    for i in s'range loop
      if (i = s'left) or (last_char = ' ') or (last_char = ht) or (last_char = cr) then
        if (character'pos(s(i)) >= character'pos('a')) and (character'pos(s(i)) <= character'pos('z')) then
          result(i) := character'val(character'pos(s(i)) + character'pos('A') - character'pos('a'));
        else
          result(i) := s(i);
        end if;
      else
        result(i) := s(i);
      end if;
      last_char := s(i);      
    end loop;
    return result;
  end title;              

  function upper (
    constant s : string)
    return string is
    variable last_char : character := NUL;
    variable result : string(s'range);
  begin
    for i in s'range loop
      if (character'pos(s(i)) >= character'pos('a')) and (character'pos(s(i)) <= character'pos('z')) then
        result(i) := character'val(character'pos(s(i)) + character'pos('A') - character'pos('a'));
      else
        result(i) := s(i);
      end if;
    end loop;
    return result;
  end upper;              

  function lower (
    constant s : string)
    return string is
    variable last_char : character := NUL;
    variable result : string(s'range);
  begin
    for i in s'range loop
      if (character'pos(s(i)) >= character'pos('A')) and (character'pos(s(i)) <= character'pos('Z')) then
        result(i) := character'val(character'pos(s(i)) + character'pos('a') - character'pos('A'));
      else
        result(i) := s(i);
      end if;
    end loop;
    return result;
  end lower;              

  function count (
    constant s : string;
    constant char : character := ' ';
    constant start : natural := 0;
    constant stop : natural := 0)
    return natural is
    variable substring : string(1 to 1);
  begin
    substring(1) := char;
    return count(s, substring, start, stop);
  end;
  
  function count (
    constant s : string;
    constant substring : string;
    constant start : natural := 0;
    constant stop : natural := 0)
    return natural is
    variable start_pos, stop_pos : natural;
    variable n, o, length : natural := 0;
  begin
    if substring = "" then
      n := s'length + 1;
    elsif s = "" then
      n := 0;
    else
      if start = 0 then
        start_pos := s'left;
      elsif not in_range(s, start) then
        return 0;
      else
        start_pos := start;
      end if;

      if stop = 0 then
        stop_pos := s'right;
      elsif not in_range(s, stop) then
        return 0;
      else
        stop_pos := stop;
      end if;

      if offset(s, start_pos) > offset(s, stop_pos) then
        return 0;
      end if;
      
      o := offset(s, start_pos);
      while o <= offset(s, stop_pos) - substring'length + 1 loop
        if slice(s, o, substring'length) = substring then
          n := n + 1;
          o := o + substring'length;
        else
          o := o + 1;
        end if;
      end loop;

    end if;

    return n;
  end count;
  
  impure function split (
    constant s         : string;
    constant sep       : string;
    constant max_split : integer := -1)
    return lines_t is
    variable ret_val : lines_t;
    variable ret_val_index : natural := 0;
    variable previous_sep_index : natural := 0;
    variable i, n_splits : natural := 0;
    variable s_int : string(1 to s'length) := s;
  begin
    if (count(s_int, sep) <= max_split) or (max_split = -1) then
      ret_val := new line_vector(0 to count(s_int, sep));
    else
      ret_val := new line_vector(0 to max_split);
    end if;
    
    i := 1;
    while i <= s_int'length - sep'length + 1 loop
      exit when n_splits = max_split;
      if s_int(i to i + sep'length - 1) = sep then
        n_splits := n_splits + 1;
        write(ret_val(ret_val_index), s_int(previous_sep_index + 1 to i - 1));
        ret_val_index := ret_val_index + 1;
        previous_sep_index := i + sep'length - 1;
        if sep'length = 0 then
          i := i + 1;
        else
          i := i + sep'length;
        end if;
      else
        i := i + 1;
      end if;
    end loop;
    write(ret_val(ret_val_index), s_int(previous_sep_index + 1 to s_int'length));
    return ret_val;
  end split;

  function to_integer_string (
    constant value : unsigned)
    return string is
    variable ret_val, reversed_ret_val : line;
    variable last_digit, quotient : unsigned(value'length - 1 downto 0);
  begin
    if value = (value'range => '0') then
      return "0";
    end if;
    
    if value'length < 32 then
      return integer'image(to_integer(value));
    end if;

    if reversed_ret_val /= null then
      deallocate(reversed_ret_val);
    end if;

    quotient := value;
    while quotient /= (quotient'range => '0') loop
      last_digit := quotient mod 10;
      quotient := quotient / 10;
      write(reversed_ret_val, integer'image(to_integer(last_digit(3 downto 0))));
    end loop;

    if ret_val /= null then
      deallocate(ret_val);
    end if;

    for i in reversed_ret_val.all'reverse_range loop
      write(ret_val, reversed_ret_val.all(i));
    end loop;

    return ret_val.all;
  end function to_integer_string;

  function to_integer_string (
    constant value : std_logic_vector)
    return string is
  begin
    return to_integer_string(unsigned(value));
  end;
  
  function to_integer_string (
    constant value : signed)
    return string is
    variable value_internal: signed(value'length - 1 downto 0) := value;
    variable value_internal_extended: signed(value'length downto 0);
    constant minus_one: signed(value'length downto 0) := (others => '1');
  begin
    if value'length <= 32 then
      return integer'image(to_integer(value));
    end if;

    if value_internal(value_internal'left) = '0' then
      return to_integer_string(unsigned(value_internal(value_internal'left - 1 downto 0)));
    end if;

    -- Negate and use the function for unsigned. Extend one bit to ensure the
    -- negated value fits.
    value_internal_extended(value_internal'range) := value_internal;
    value_internal_extended(value_internal_extended'left) := value_internal(value_internal'left);
    value_internal_extended := not(value_internal_extended) + 1;

    return "-" & to_integer_string(unsigned(value_internal_extended));
  end function to_integer_string;

  function to_nibble_string (
    constant value : unsigned)
    return string is
    variable value_i : unsigned(value'length downto 1) := value;
    variable ret_val : line;
  begin
    if ret_val /= null then
      deallocate(ret_val);
    end if;

    for i in value_i'range loop
      if (i mod 4 = 0) and (i /= value_i'left) then
        write(ret_val, string'("_"));
      end if;
      write(ret_val, std_logic'image(value_i(i))(2));
    end loop;

    if ret_val = null then
      return "";
    end if;
    return ret_val.all;
  end function to_nibble_string;

  function to_nibble_string (
    constant value : std_logic_vector)
    return string is
  begin
    return to_nibble_string(unsigned(value));
  end function to_nibble_string;

  function to_nibble_string (
    constant value : signed)
    return string is
  begin
    return to_nibble_string(unsigned(value));
  end function to_nibble_string;

end package body;
