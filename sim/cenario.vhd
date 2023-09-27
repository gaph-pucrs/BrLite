------------------------------------------------------------------------
-- TEST CASE 1
------------------------------------------------------------------------
library IEEE;
use IEEE.Std_Logic_1164.all;
use work.pkg_brNoC.all;

package PDN_scenario is

   constant PEsX : integer := 8;
   constant PEsY : integer := 8;
   constant PEs  : integer := PEsY*PEsX;

   ------------------------------------------------------
   --  DEFINE A "ESTRUTURA" PARA INSERCAO DE SERVICOS 
   ------------------------------------------------------
   type test_vector is record
      timestamp : integer;
      source    : integer;
      target    : integer;
      payload   : std_logic_vector( 7 downto 0);
      service   : std_logic_vector(1 downto 0);
   end record;

   type services is array (natural range <>) of test_vector;

   constant seeks_in : services := (
         (4,  4, 0, x"01", brALL_SERVICE),
         (80, 0, 0, x"02", brALL_SERVICE), 
         (80, 3, 0, x"03", brALL_SERVICE),
         (80, 5, 0, x"04", brALL_SERVICE),

         (150, 8, 6, x"BA", brTgt_SERVICE),

         (250, 8, 5, x"A8", brTgt_SERVICE), -- rajada para o 5 
         (300, 0, 5, x"A0", brTgt_SERVICE), 
         (350, 6, 5, x"A6", brTgt_SERVICE), 
         (400, 1, 5, x"A1", brTgt_SERVICE), 
         (410, 3, 5, x"A3", brTgt_SERVICE), 
         (420, 4, 5, x"A4", brTgt_SERVICE), 
         (410, 7, 5, x"A7", brTgt_SERVICE), 

         (500, 2, 0, x"EE", brTgt_SERVICE), -- vários para o 0
         (550, 1, 0, x"FF", brTgt_SERVICE), 
         (650, 5, 0, x"88", brTgt_SERVICE), 

         (650, 6, 4, x"66", brTgt_SERVICE), -- 6 send to 4
         (680, 30, 0, x"9F", brALL_SERVICE), 
         (750, 3, 4, x"77", brALL_SERVICE), -- 3 send to 4
         (770, 0, 4, x"CA", brTgt_SERVICE), -- 0 send to 4
         (790, 2, 4, x"BE", brTgt_SERVICE), -- 2 send to 4

         (850, 6, 0, x"11", brTgt_SERVICE),
         (900, 1, 7, x"22", brALL_SERVICE),
         (950, 8, 7, x"33", brTgt_SERVICE),
         (950, 2, 7, x"44", brTgt_SERVICE),

         (1100,  7, 0, x"AF", brTgt_SERVICE),
         (1150, 4, 0, x"DE", brTgt_SERVICE),
         (1200, 8, 0, x"BC", brALL_SERVICE),
         (1200, 5, 0, x"F1", brALL_SERVICE),
         (1300, 2, 7, x"33", brTgt_SERVICE)

      );

end PDN_scenario;