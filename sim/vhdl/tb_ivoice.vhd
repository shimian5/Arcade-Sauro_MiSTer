-- Evaluation testbench for the vendored Intv_MiSTer ivoice.vhd (SP0256 that executes the ROM) with the AL2 ROM.
-- Drives allophone sequences the way Sauro's firmware does (next byte when the chip signals ready), logs the
-- time of every write and every output sample change. Clocks: phi enable once per 12 clksys cycles at
-- 4.5897 MHz, divi = 358, giving the SP0256's 12.82 kHz sample rate for a 4 MHz chip clock (see docs/AUDIO.md).
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE std.textio.ALL;
USE ieee.std_logic_textio.ALL;
LIBRARY work;
USE work.base_pack.ALL;

ENTITY tb_ivoice IS
  GENERIC (SEQSEL : natural := 1; RUN_MS : natural := 600);
END ENTITY;

ARCHITECTURE sim OF tb_ivoice IS
  CONSTANT CLKSYS_PERIOD : time := 18157 ps;     -- 12 x 4.5897 MHz
  SIGNAL clksys : std_logic := '0';
  SIGNAL reset_na : std_logic := '0';
  SIGNAL ad, dw, dr : uv16 := (OTHERS => '0');
  SIGNAL wr, phi_cpu, phi : std_logic := '0';
  SIGNAL sound : sv16;
  SIGNAL rom_wr : std_logic := '0';
  SIGNAL rom_aw : uv16 := (OTHERS => '0');
  SIGNAL rom_dw : uv8 := (OTHERS => '0');
  SIGNAL phicnt : natural := 0;
  TYPE bytes IS ARRAY (natural RANGE <>) OF std_logic_vector(7 DOWNTO 0);
  FUNCTION seq(sel : natural) RETURN bytes IS
  BEGIN
    CASE sel IS
      WHEN 0 => RETURN (x"28", x"28", x"14", x"00", x"29", x"04", x"38", x"20", x"00");
      WHEN 1 => RETURN (x"1B", x"07", x"2D", x"20", x"00");
      WHEN OTHERS => RETURN (x"28", x"3B", x"2C", x"0D", x"3B", x"37", x"0D", x"0C", x"29", x"00");
    END CASE;
  END FUNCTION;
  CONSTANT s : bytes := seq(SEQSEL);
BEGIN
  clksys <= NOT clksys AFTER CLKSYS_PERIOD / 2;

  -- phi: one clksys-wide pulse every 12 clocks
  PROCESS (clksys) IS
  BEGIN
    IF rising_edge(clksys) THEN
      IF phicnt = 11 THEN phicnt <= 0; phi <= '1'; ELSE phicnt <= phicnt + 1; phi <= '0'; END IF;
    END IF;
  END PROCESS;

  dut : ENTITY work.ivoice
    PORT MAP (ad => ad, dw => dw, dr => dr, wr => wr, phi_cpu => phi_cpu, phi => phi, divi => 358,
              sound => sound, gain => "00", rom_voice_wr => rom_wr, rom_aw => rom_aw, rom_dw => rom_dw,
              clksys => clksys, reset_na => reset_na);

  -- load the ROM, release reset, then play the sequence
  stim : PROCESS IS
    FILE romf : text OPEN read_mode IS "al2rom.hex";
    FILE logf : text OPEN write_mode IS "ivoice_writes.txt";
    VARIABLE l, o : line;
    VARIABLE v : std_logic_vector(7 DOWNTO 0);
    VARIABLE addr : natural := 0;
    VARIABLE idx : natural := 0;
  BEGIN
    WAIT FOR 100 ns;
    WHILE NOT endfile(romf) LOOP
      readline(romf, l); hread(l, v);
      WAIT UNTIL rising_edge(clksys);
      rom_aw <= to_unsigned(addr, 16); rom_dw <= unsigned(v); rom_wr <= '1';
      WAIT UNTIL rising_edge(clksys);
      rom_wr <= '0';
      addr := addr + 1;
    END LOOP;
    WAIT FOR 1 us;
    reset_na <= '1';
    ad <= to_unsigned(16#80#, 16);
    WAIT FOR 100 us;
    WHILE idx < s'length LOOP
      -- wait until the chip reports it can take an allophone (read of 0080 bit 15)
      WAIT UNTIL rising_edge(clksys) AND dr(15) = '1';
      WAIT FOR 20 us;                                  -- NMI latency + handler
      WAIT UNTIL rising_edge(clksys);
      IF dr(15) = '1' THEN
        dw <= to_unsigned(0, 8) & unsigned(s(idx)); wr <= '1'; phi_cpu <= '1';
        WAIT UNTIL rising_edge(clksys);
        wr <= '0'; phi_cpu <= '0';
        write(o, now / 1 us); write(o, string'(" us write ")); hwrite(o, s(idx)); writeline(logf, o);
        idx := idx + 1;
        WAIT FOR 5 us;
      END IF;
    END LOOP;
    WAIT FOR RUN_MS * 1 ms;
    ASSERT false REPORT "end of simulation" SEVERITY failure;
  END PROCESS;

  -- log output samples whenever the output changes
  logs : PROCESS (sound) IS
    FILE sf : text OPEN write_mode IS "ivoice_samples.txt";
    VARIABLE o : line;
  BEGIN
    write(o, now / 1 ns); write(o, string'(" ")); write(o, to_integer(sound)); writeline(sf, o);
  END PROCESS;
END ARCHITECTURE;
