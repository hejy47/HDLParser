----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 18.05.2016 22:29:27
-- Design Name: 
-- Module Name: icmp_handler - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity icmp_handler is 
    generic (
        our_mac     : std_logic_vector(47 downto 0) := (others => '0');
        our_ip      : std_logic_vector(31 downto 0) := (others => '0'));
    port (  clk                : in  STD_LOGIC;
            packet_in_valid    : in  STD_LOGIC;
            packet_in_data     : in  STD_LOGIC_VECTOR (7 downto 0);
            -- For receiving data from the PHY        
            packet_out_request : out std_logic := '0';
            packet_out_granted : in  std_logic := '0';
            packet_out_valid   : out std_logic := '0';         
            packet_out_data    : out std_logic_vector(7 downto 0) := (others => '0'));
end icmp_handler;

architecture Behavioral of icmp_handler is

    component icmp_extract_ethernet_header
    generic (
        our_mac     : std_logic_vector(47 downto 0) := (others => '0'));
    Port ( clk            : in  STD_LOGIC;
           data_valid_in  : in  STD_LOGIC;
           data_in        : in  STD_LOGIC_VECTOR (7 downto 0);
           data_valid_out : out STD_LOGIC;
           data_out       : out STD_LOGIC_VECTOR (7 downto 0);
           
           ether_type     : out STD_LOGIC_VECTOR (15 downto 0); 
           ether_dst_mac  : out STD_LOGIC_VECTOR (47 downto 0);
           ether_src_mac  : out STD_LOGIC_VECTOR (47 downto 0));
    end component;
    signal ether_extracted_data_valid : STD_LOGIC := '0';
    signal ether_extracted_data       : STD_LOGIC_VECTOR (7 downto 0) := (others => '0');
    signal ether_is_ipv4             : STD_LOGIC := '0'; 
    signal ether_src_mac             : STD_LOGIC_VECTOR (47 downto 0) := (others => '0');

    component icmp_extract_ip_header 
    generic (
        our_ip      : std_logic_vector(31 downto 0) := (others => '0'));
    Port ( clk                : in  STD_LOGIC;
           data_valid_in      : in  STD_LOGIC;
           data_in            : in  STD_LOGIC_VECTOR (7 downto 0);
           data_valid_out     : out STD_LOGIC;
           data_out           : out STD_LOGIC_VECTOR (7 downto 0);
           
           ip_version         : out STD_LOGIC_VECTOR (3 downto 0);
           ip_type_of_service : out STD_LOGIC_VECTOR (7 downto 0);
           ip_length          : out STD_LOGIC_VECTOR (15 downto 0);
           ip_identification  : out STD_LOGIC_VECTOR (15 downto 0);
           ip_flags           : out STD_LOGIC_VECTOR (2 downto 0);
           ip_fragment_offset : out STD_LOGIC_VECTOR (12 downto 0);
           ip_ttl             : out STD_LOGIC_VECTOR (7 downto 0);
           ip_protocol        : out STD_LOGIC_VECTOR (7 downto 0);
           ip_checksum        : out STD_LOGIC_VECTOR (15 downto 0);
           ip_src_ip          : out STD_LOGIC_VECTOR (31 downto 0);
           ip_dest_ip         : out STD_LOGIC_VECTOR (31 downto 0));           
    end component;
    signal ip_extracted_data_valid : STD_LOGIC := '0';
    signal ip_extracted_data       : STD_LOGIC_VECTOR (7 downto 0) := (others => '0');

    signal ip_version         : STD_LOGIC_VECTOR (3 downto 0)  := (others => '0');
    signal ip_type_of_service : STD_LOGIC_VECTOR (7 downto 0)  := (others => '0');
    signal ip_length          : STD_LOGIC_VECTOR (15 downto 0) := (others => '0');
    signal ip_identification  : STD_LOGIC_VECTOR (15 downto 0) := (others => '0');
    signal ip_flags           : STD_LOGIC_VECTOR (2 downto 0)  := (others => '0');
    signal ip_fragment_offset : STD_LOGIC_VECTOR (12 downto 0) := (others => '0');
    signal ip_ttl             : STD_LOGIC_VECTOR (7 downto 0)  := (others => '0');
    signal ip_protocol        : STD_LOGIC_VECTOR (7 downto 0)  := (others => '0');
    signal ip_checksum        : STD_LOGIC_VECTOR (15 downto 0) := (others => '0');
    signal ip_src_ip          : STD_LOGIC_VECTOR (31 downto 0) := (others => '0');
    signal ip_dest_ip         : STD_LOGIC_VECTOR (31 downto 0) := (others => '0');           

    component icmp_extract_icmp_header 
    Port ( clk            : in  STD_LOGIC;
           data_valid_in  : in  STD_LOGIC;
           data_in        : in  STD_LOGIC_VECTOR (7 downto 0);
           data_valid_out : out STD_LOGIC;
           data_out       : out STD_LOGIC_VECTOR (7 downto 0);
           
           icmp_type       : out STD_LOGIC_VECTOR (7 downto 0);
           icmp_code       : out STD_LOGIC_VECTOR (7 downto 0);
           icmp_checksum   : out STD_LOGIC_VECTOR (15 downto 0);
           icmp_identifier : out STD_LOGIC_VECTOR (15 downto 0);
           icmp_sequence   : out STD_LOGIC_VECTOR (15 downto 0));           
    end component;
    signal icmp_extracted_data_valid : STD_LOGIC := '0';
    signal icmp_extracted_data       : STD_LOGIC_VECTOR (7 downto 0) := (others => '0');

    signal icmp_type       : STD_LOGIC_VECTOR (7 downto 0);
    signal icmp_code       : STD_LOGIC_VECTOR (7 downto 0);
    signal icmp_checksum   : STD_LOGIC_VECTOR (15 downto 0);
    signal icmp_identifier : STD_LOGIC_VECTOR (15 downto 0);           
    signal icmp_sequence   : STD_LOGIC_VECTOR (15 downto 0);           

    component icmp_build_reply 
    generic (
        our_mac     : std_logic_vector(47 downto 0) := (others => '0');
        our_ip      : std_logic_vector(31 downto 0) := (others => '0'));
    Port ( clk                : in  STD_LOGIC;
           data_valid_in      : in  STD_LOGIC;
           data_in            : in  STD_LOGIC_VECTOR (7 downto 0);
           data_valid_out     : out STD_LOGIC;
           data_out           : out STD_LOGIC_VECTOR (7 downto 0);

           ether_is_ipv4      : in  STD_LOGIC; 
           ether_src_mac      : in  STD_LOGIC_VECTOR (47 downto 0);

           ip_version         : in  STD_LOGIC_VECTOR (3 downto 0);
           ip_type_of_service : in  STD_LOGIC_VECTOR (7 downto 0);
           ip_length          : in  STD_LOGIC_VECTOR (15 downto 0);
           ip_identification  : in  STD_LOGIC_VECTOR (15 downto 0);
           ip_flags           : in  STD_LOGIC_VECTOR (2 downto 0);
           ip_fragment_offset : in  STD_LOGIC_VECTOR (12 downto 0);
           ip_ttl             : in  STD_LOGIC_VECTOR (7 downto 0);
           ip_protocol        : in  STD_LOGIC_VECTOR (7 downto 0);
           ip_checksum        : in  STD_LOGIC_VECTOR (15 downto 0);
           ip_src_ip          : in  STD_LOGIC_VECTOR (31 downto 0);
           ip_dest_ip         : in  STD_LOGIC_VECTOR (31 downto 0);           
           
           icmp_type          : in  STD_LOGIC_VECTOR (7 downto 0);
           icmp_code          : in  STD_LOGIC_VECTOR (7 downto 0);
           icmp_checksum      : in  STD_LOGIC_VECTOR (15 downto 0);
           icmp_identifier    : in  STD_LOGIC_VECTOR (15 downto 0);
           icmp_sequence      : in  STD_LOGIC_VECTOR (15 downto 0));           
    end component;

    signal reply_data_valid   : std_logic := '0';
    signal reply_data         : std_logic_vector(7 DOWNTO 0) := (others => '0');

    component icmp_commit_buffer
    Port ( clk                : in  STD_LOGIC;
           data_valid_in      : in  STD_LOGIC;
           data_in            : in  STD_LOGIC_VECTOR (7 downto 0);
           packet_out_request : out std_logic := '0';
           packet_out_granted : in  std_logic := '0';
           packet_out_valid   : out std_logic := '0';         
           packet_out_data    : out std_logic_vector(7 downto 0) := (others => '0'));
    end component;

    signal i_packet_out_valid   : std_logic := '0';
    signal i_packet_out_request : std_logic := '0';
    signal i_packet_out_granted : std_logic := '0';
    signal i_packet_out_data    : std_logic_vector(7 DOWNTO 0) := (others => '0');
    -------------------------------------------
    -- Debugging
    -------------------------------------------    
    COMPONENT ila_0
    PORT (
        clk    : IN STD_LOGIC;
        probe0 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe1 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        probe2 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe3 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        probe4 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        probe5 : IN STD_LOGIC_VECTOR(0 DOWNTO 0)
    );
    END COMPONENT ;
begin
i_icmp_extracted_ethernet_header: icmp_extract_ethernet_header generic map (
    our_mac => our_mac)
  port map (
    clk            => clk,
    data_valid_in  => packet_in_valid,
    data_in        => packet_in_data,
    data_valid_out => ether_extracted_data_valid,
    data_out       => ether_extracted_data,
       
    ether_type     => open,
    ether_dst_mac  => open, 
    ether_src_mac  => ether_src_mac);

    
i_icmp_extract_ip_header: icmp_extract_ip_header generic map (
        our_ip  => our_ip)
    port map ( 
        clk            => clk,
        data_valid_in  => ether_extracted_data_valid,
        data_in        => ether_extracted_data,
        data_valid_out => ip_extracted_data_valid,
        data_out       => ip_extracted_data,
        
        ip_version         => ip_version,
        ip_type_of_service => ip_type_of_service,
        ip_length          => ip_length,
        ip_identification  => ip_identification,
        ip_flags           => ip_flags,
        ip_fragment_offset => ip_fragment_offset,
        ip_ttl             => ip_ttl,
        ip_protocol        => ip_protocol,
        ip_checksum        => ip_checksum,
        ip_src_ip          => ip_src_ip,
        ip_dest_ip         => ip_dest_ip);           

i_icmp_extract_icmp_header : icmp_extract_icmp_header port map ( 
    clk            => clk,
 
    data_valid_in  => ip_extracted_data_valid,
    data_in        => ip_extracted_data,
    data_valid_out => icmp_extracted_data_valid,
    data_out       => icmp_extracted_data,
           
    icmp_type       => icmp_type,
    icmp_code       => icmp_code,
    icmp_checksum   => icmp_checksum,
    icmp_identifier => icmp_identifier,
    icmp_sequence   => icmp_sequence);           


--i_ila_0: ila_0 port map (
--    clk       => clk,
--    probe0(0) => packet_in_valid, 
--    probe1    => packet_in_data,
--    probe2(0) => ether_extracted_data_valid, 
--    probe3(0) => ip_extracted_data_valid,
--    probe4(0) => icmp_extracted_data_valid,
--    probe5(0) => i_packet_out_valid);

i_icmp_build_reply: icmp_build_reply generic map (
        our_mac => our_mac,
        our_ip  => our_ip)
    port map ( 
        clk                => clk,
    
        data_valid_in      => icmp_extracted_data_valid,
        data_in            => icmp_extracted_data,
        data_valid_out     => reply_data_valid,
        data_out           => reply_data,
    
        ether_is_ipv4      => ether_is_ipv4, 
        ether_src_mac      => ether_src_mac,
    
        ip_version         => ip_version,
        ip_type_of_service => ip_type_of_service,
        ip_length          => ip_length,
        ip_identification  => ip_identification,
        ip_flags           => ip_flags,
        ip_fragment_offset => ip_fragment_offset,
        ip_ttl             => ip_ttl,
        ip_protocol        => ip_protocol,
        ip_checksum        => ip_checksum,
        ip_src_ip          => ip_src_ip,
        ip_dest_ip         => ip_dest_ip,           
           
        icmp_type          => icmp_type,
        icmp_code          => icmp_code,
        icmp_checksum      => icmp_checksum,
        icmp_identifier    => icmp_identifier,
        icmp_sequence      => icmp_sequence);

i_icmp_commit_buffer: icmp_commit_buffer port map (
        clk                => clk,
        data_valid_in      => reply_data_valid,
        data_in            => reply_data,
        packet_out_request => i_packet_out_request,
        packet_out_granted => i_packet_out_granted,
        packet_out_valid   => i_packet_out_valid,         
        packet_out_data    => i_packet_out_data);

    packet_out_request   <= i_packet_out_request;
    i_packet_out_granted <= packet_out_granted;
    packet_out_valid     <= i_packet_out_valid;
    packet_out_data      <= i_packet_out_data;
           
end Behavioral;
