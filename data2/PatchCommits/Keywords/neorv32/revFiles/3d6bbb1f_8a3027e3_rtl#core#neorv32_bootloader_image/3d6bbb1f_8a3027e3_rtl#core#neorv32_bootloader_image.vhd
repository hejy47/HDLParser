-- The NEORV32 Processor by Stephan Nolting, https://github.com/stnolting/neorv32
-- Auto-generated memory init file (for BOOTLOADER) from source file <bootloader/main.bin>

library ieee;
use ieee.std_logic_1164.all;

package neorv32_bootloader_image is

  type bootloader_init_image_t is array (0 to 1022) of std_ulogic_vector(31 downto 0);
  constant bootloader_init_image : bootloader_init_image_t := (
    00000000 => x"00000093",
    00000001 => x"00000113",
    00000002 => x"00000193",
    00000003 => x"00000213",
    00000004 => x"00000293",
    00000005 => x"00000313",
    00000006 => x"00000393",
    00000007 => x"00000413",
    00000008 => x"00000493",
    00000009 => x"00000713",
    00000010 => x"00000793",
    00000011 => x"00002537",
    00000012 => x"80050513",
    00000013 => x"30051073",
    00000014 => x"30401073",
    00000015 => x"80012117",
    00000016 => x"fc010113",
    00000017 => x"ffc17113",
    00000018 => x"00010413",
    00000019 => x"80010197",
    00000020 => x"7b418193",
    00000021 => x"00000597",
    00000022 => x"08058593",
    00000023 => x"30559073",
    00000024 => x"f8000593",
    00000025 => x"0005a023",
    00000026 => x"00458593",
    00000027 => x"feb01ce3",
    00000028 => x"80010597",
    00000029 => x"f9058593",
    00000030 => x"80418613",
    00000031 => x"00c5d863",
    00000032 => x"00058023",
    00000033 => x"00158593",
    00000034 => x"ff5ff06f",
    00000035 => x"00001597",
    00000036 => x"f6c58593",
    00000037 => x"80010617",
    00000038 => x"f6c60613",
    00000039 => x"80010697",
    00000040 => x"f6468693",
    00000041 => x"00d65c63",
    00000042 => x"00058703",
    00000043 => x"00e60023",
    00000044 => x"00158593",
    00000045 => x"00160613",
    00000046 => x"fedff06f",
    00000047 => x"00000513",
    00000048 => x"00000593",
    00000049 => x"05c000ef",
    00000050 => x"30047073",
    00000051 => x"10500073",
    00000052 => x"0000006f",
    00000053 => x"ff810113",
    00000054 => x"00812023",
    00000055 => x"00912223",
    00000056 => x"34202473",
    00000057 => x"02044663",
    00000058 => x"34102473",
    00000059 => x"00041483",
    00000060 => x"0034f493",
    00000061 => x"00240413",
    00000062 => x"34141073",
    00000063 => x"00300413",
    00000064 => x"00941863",
    00000065 => x"34102473",
    00000066 => x"00240413",
    00000067 => x"34141073",
    00000068 => x"00012483",
    00000069 => x"00412403",
    00000070 => x"00810113",
    00000071 => x"30200073",
    00000072 => x"fd010113",
    00000073 => x"02812423",
    00000074 => x"fe002403",
    00000075 => x"026267b7",
    00000076 => x"02112623",
    00000077 => x"02912223",
    00000078 => x"03212023",
    00000079 => x"01312e23",
    00000080 => x"01412c23",
    00000081 => x"01512a23",
    00000082 => x"01612823",
    00000083 => x"01712623",
    00000084 => x"01812423",
    00000085 => x"9ff78793",
    00000086 => x"00000713",
    00000087 => x"00000693",
    00000088 => x"00000613",
    00000089 => x"00000593",
    00000090 => x"00200513",
    00000091 => x"0087f463",
    00000092 => x"00400513",
    00000093 => x"3b5000ef",
    00000094 => x"00005537",
    00000095 => x"00000613",
    00000096 => x"00000593",
    00000097 => x"b0050513",
    00000098 => x"291000ef",
    00000099 => x"249000ef",
    00000100 => x"00245793",
    00000101 => x"00a78533",
    00000102 => x"00f537b3",
    00000103 => x"00b785b3",
    00000104 => x"261000ef",
    00000105 => x"ffff07b7",
    00000106 => x"49478793",
    00000107 => x"30579073",
    00000108 => x"08000793",
    00000109 => x"30479073",
    00000110 => x"30046073",
    00000111 => x"00100513",
    00000112 => x"429000ef",
    00000113 => x"ffff1537",
    00000114 => x"800007b7",
    00000115 => x"f1450513",
    00000116 => x"0007a023",
    00000117 => x"2fd000ef",
    00000118 => x"14d000ef",
    00000119 => x"ffff1537",
    00000120 => x"f4c50513",
    00000121 => x"2ed000ef",
    00000122 => x"fe002503",
    00000123 => x"238000ef",
    00000124 => x"ffff1537",
    00000125 => x"f5450513",
    00000126 => x"2d9000ef",
    00000127 => x"fe402503",
    00000128 => x"224000ef",
    00000129 => x"ffff1537",
    00000130 => x"f6050513",
    00000131 => x"2c5000ef",
    00000132 => x"30102573",
    00000133 => x"210000ef",
    00000134 => x"ffff1537",
    00000135 => x"f6850513",
    00000136 => x"2b1000ef",
    00000137 => x"fe802503",
    00000138 => x"ffff14b7",
    00000139 => x"00341413",
    00000140 => x"1f4000ef",
    00000141 => x"ffff1537",
    00000142 => x"f7050513",
    00000143 => x"295000ef",
    00000144 => x"ff802503",
    00000145 => x"1e0000ef",
    00000146 => x"f7848513",
    00000147 => x"285000ef",
    00000148 => x"ff002503",
    00000149 => x"1d0000ef",
    00000150 => x"ffff1537",
    00000151 => x"f8450513",
    00000152 => x"271000ef",
    00000153 => x"ffc02503",
    00000154 => x"1bc000ef",
    00000155 => x"f7848513",
    00000156 => x"261000ef",
    00000157 => x"ff402503",
    00000158 => x"1ac000ef",
    00000159 => x"ffff1537",
    00000160 => x"f8c50513",
    00000161 => x"24d000ef",
    00000162 => x"14d000ef",
    00000163 => x"00a404b3",
    00000164 => x"0084b433",
    00000165 => x"00b40433",
    00000166 => x"fa402783",
    00000167 => x"0207d263",
    00000168 => x"ffff1537",
    00000169 => x"fb450513",
    00000170 => x"229000ef",
    00000171 => x"219000ef",
    00000172 => x"02300793",
    00000173 => x"02f51263",
    00000174 => x"00000513",
    00000175 => x"0180006f",
    00000176 => x"115000ef",
    00000177 => x"fc85eae3",
    00000178 => x"00b41463",
    00000179 => x"fc9566e3",
    00000180 => x"00100513",
    00000181 => x"5a8000ef",
    00000182 => x"0b4000ef",
    00000183 => x"ffff1937",
    00000184 => x"ffff19b7",
    00000185 => x"02300a13",
    00000186 => x"07200a93",
    00000187 => x"06800b13",
    00000188 => x"07500b93",
    00000189 => x"ffff14b7",
    00000190 => x"ffff1c37",
    00000191 => x"fc090513",
    00000192 => x"1d1000ef",
    00000193 => x"1b1000ef",
    00000194 => x"00050413",
    00000195 => x"199000ef",
    00000196 => x"ecc98513",
    00000197 => x"1bd000ef",
    00000198 => x"fb4400e3",
    00000199 => x"01541863",
    00000200 => x"ffff02b7",
    00000201 => x"00028067",
    00000202 => x"fd5ff06f",
    00000203 => x"01641663",
    00000204 => x"05c000ef",
    00000205 => x"fc9ff06f",
    00000206 => x"00000513",
    00000207 => x"03740063",
    00000208 => x"07300793",
    00000209 => x"00f41663",
    00000210 => x"660000ef",
    00000211 => x"fb1ff06f",
    00000212 => x"06c00793",
    00000213 => x"00f41863",
    00000214 => x"00100513",
    00000215 => x"3f0000ef",
    00000216 => x"f9dff06f",
    00000217 => x"06500793",
    00000218 => x"00f41663",
    00000219 => x"02c000ef",
    00000220 => x"f8dff06f",
    00000221 => x"03f00793",
    00000222 => x"fc8c0513",
    00000223 => x"00f40463",
    00000224 => x"fdc48513",
    00000225 => x"14d000ef",
    00000226 => x"f75ff06f",
    00000227 => x"ffff1537",
    00000228 => x"df050513",
    00000229 => x"13d0006f",
    00000230 => x"800007b7",
    00000231 => x"0007a783",
    00000232 => x"00079863",
    00000233 => x"ffff1537",
    00000234 => x"e5450513",
    00000235 => x"1250006f",
    00000236 => x"ff010113",
    00000237 => x"00112623",
    00000238 => x"30047073",
    00000239 => x"ffff1537",
    00000240 => x"e7050513",
    00000241 => x"10d000ef",
    00000242 => x"fa002783",
    00000243 => x"fe07cee3",
    00000244 => x"b0001073",
    00000245 => x"b8001073",
    00000246 => x"b0201073",
    00000247 => x"b8201073",
    00000248 => x"ff002783",
    00000249 => x"00078067",
    00000250 => x"0000006f",
    00000251 => x"ff010113",
    00000252 => x"00812423",
    00000253 => x"00050413",
    00000254 => x"ffff1537",
    00000255 => x"e8050513",
    00000256 => x"00112623",
    00000257 => x"0cd000ef",
    00000258 => x"03040513",
    00000259 => x"0ff57513",
    00000260 => x"095000ef",
    00000261 => x"30047073",
    00000262 => x"00100513",
    00000263 => x"1cd000ef",
    00000264 => x"0000006f",
    00000265 => x"fe010113",
    00000266 => x"01212823",
    00000267 => x"00050913",
    00000268 => x"ffff1537",
    00000269 => x"00912a23",
    00000270 => x"e9850513",
    00000271 => x"ffff14b7",
    00000272 => x"00812c23",
    00000273 => x"01312623",
    00000274 => x"00112e23",
    00000275 => x"01c00413",
    00000276 => x"081000ef",
    00000277 => x"fe848493",
    00000278 => x"ffc00993",
    00000279 => x"008957b3",
    00000280 => x"00f7f793",
    00000281 => x"00f487b3",
    00000282 => x"0007c503",
    00000283 => x"ffc40413",
    00000284 => x"035000ef",
    00000285 => x"ff3414e3",
    00000286 => x"01c12083",
    00000287 => x"01812403",
    00000288 => x"01412483",
    00000289 => x"01012903",
    00000290 => x"00c12983",
    00000291 => x"02010113",
    00000292 => x"00008067",
    00000293 => x"fb010113",
    00000294 => x"04112623",
    00000295 => x"04512423",
    00000296 => x"04612223",
    00000297 => x"04712023",
    00000298 => x"02812e23",
    00000299 => x"02a12c23",
    00000300 => x"02b12a23",
    00000301 => x"02c12823",
    00000302 => x"02d12623",
    00000303 => x"02e12423",
    00000304 => x"02f12223",
    00000305 => x"03012023",
    00000306 => x"01112e23",
    00000307 => x"01c12c23",
    00000308 => x"01d12a23",
    00000309 => x"01e12823",
    00000310 => x"01f12623",
    00000311 => x"34202473",
    00000312 => x"800007b7",
    00000313 => x"00778793",
    00000314 => x"06f41a63",
    00000315 => x"00000513",
    00000316 => x"0dd000ef",
    00000317 => x"6e0000ef",
    00000318 => x"fe002783",
    00000319 => x"0027d793",
    00000320 => x"00a78533",
    00000321 => x"00f537b3",
    00000322 => x"00b785b3",
    00000323 => x"6f4000ef",
    00000324 => x"03c12403",
    00000325 => x"04c12083",
    00000326 => x"04812283",
    00000327 => x"04412303",
    00000328 => x"04012383",
    00000329 => x"03812503",
    00000330 => x"03412583",
    00000331 => x"03012603",
    00000332 => x"02c12683",
    00000333 => x"02812703",
    00000334 => x"02412783",
    00000335 => x"02012803",
    00000336 => x"01c12883",
    00000337 => x"01812e03",
    00000338 => x"01412e83",
    00000339 => x"01012f03",
    00000340 => x"00c12f83",
    00000341 => x"05010113",
    00000342 => x"30200073",
    00000343 => x"00700793",
    00000344 => x"00100513",
    00000345 => x"02f40863",
    00000346 => x"ffff1537",
    00000347 => x"e8c50513",
    00000348 => x"760000ef",
    00000349 => x"00040513",
    00000350 => x"eadff0ef",
    00000351 => x"ffff1537",
    00000352 => x"e9450513",
    00000353 => x"74c000ef",
    00000354 => x"34102573",
    00000355 => x"e99ff0ef",
    00000356 => x"00500513",
    00000357 => x"e59ff0ef",
    00000358 => x"ff010113",
    00000359 => x"00000513",
    00000360 => x"00112623",
    00000361 => x"00812423",
    00000362 => x"7cc000ef",
    00000363 => x"00500513",
    00000364 => x"009000ef",
    00000365 => x"00000513",
    00000366 => x"001000ef",
    00000367 => x"00050413",
    00000368 => x"00000513",
    00000369 => x"7d0000ef",
    00000370 => x"00c12083",
    00000371 => x"0ff47513",
    00000372 => x"00812403",
    00000373 => x"01010113",
    00000374 => x"00008067",
    00000375 => x"ff010113",
    00000376 => x"00000513",
    00000377 => x"00112623",
    00000378 => x"00812423",
    00000379 => x"788000ef",
    00000380 => x"09e00513",
    00000381 => x"7c4000ef",
    00000382 => x"00000513",
    00000383 => x"7bc000ef",
    00000384 => x"00050413",
    00000385 => x"00000513",
    00000386 => x"78c000ef",
    00000387 => x"00c12083",
    00000388 => x"0ff47513",
    00000389 => x"00812403",
    00000390 => x"01010113",
    00000391 => x"00008067",
    00000392 => x"ff010113",
    00000393 => x"00000513",
    00000394 => x"00112623",
    00000395 => x"748000ef",
    00000396 => x"00600513",
    00000397 => x"784000ef",
    00000398 => x"00c12083",
    00000399 => x"00000513",
    00000400 => x"01010113",
    00000401 => x"7500006f",
    00000402 => x"ff010113",
    00000403 => x"00812423",
    00000404 => x"00050413",
    00000405 => x"01055513",
    00000406 => x"0ff57513",
    00000407 => x"00112623",
    00000408 => x"758000ef",
    00000409 => x"00845513",
    00000410 => x"0ff57513",
    00000411 => x"74c000ef",
    00000412 => x"0ff47513",
    00000413 => x"00812403",
    00000414 => x"00c12083",
    00000415 => x"01010113",
    00000416 => x"7380006f",
    00000417 => x"ff010113",
    00000418 => x"00812423",
    00000419 => x"00050413",
    00000420 => x"00000513",
    00000421 => x"00112623",
    00000422 => x"6dc000ef",
    00000423 => x"00300513",
    00000424 => x"718000ef",
    00000425 => x"00040513",
    00000426 => x"fa1ff0ef",
    00000427 => x"00000513",
    00000428 => x"708000ef",
    00000429 => x"00050413",
    00000430 => x"00000513",
    00000431 => x"6d8000ef",
    00000432 => x"00c12083",
    00000433 => x"0ff47513",
    00000434 => x"00812403",
    00000435 => x"01010113",
    00000436 => x"00008067",
    00000437 => x"fd010113",
    00000438 => x"02812423",
    00000439 => x"02912223",
    00000440 => x"03212023",
    00000441 => x"01312e23",
    00000442 => x"01412c23",
    00000443 => x"02112623",
    00000444 => x"00050913",
    00000445 => x"00058993",
    00000446 => x"00c10493",
    00000447 => x"00000413",
    00000448 => x"00400a13",
    00000449 => x"02091e63",
    00000450 => x"5ac000ef",
    00000451 => x"00a481a3",
    00000452 => x"00140413",
    00000453 => x"fff48493",
    00000454 => x"ff4416e3",
    00000455 => x"02c12083",
    00000456 => x"02812403",
    00000457 => x"00c12503",
    00000458 => x"02412483",
    00000459 => x"02012903",
    00000460 => x"01c12983",
    00000461 => x"01812a03",
    00000462 => x"03010113",
    00000463 => x"00008067",
    00000464 => x"00898533",
    00000465 => x"f41ff0ef",
    00000466 => x"fc5ff06f",
    00000467 => x"fd010113",
    00000468 => x"02812423",
    00000469 => x"fe802403",
    00000470 => x"02112623",
    00000471 => x"02912223",
    00000472 => x"03212023",
    00000473 => x"01312e23",
    00000474 => x"01412c23",
    00000475 => x"01512a23",
    00000476 => x"01612823",
    00000477 => x"01712623",
    00000478 => x"00847413",
    00000479 => x"00040663",
    00000480 => x"00400513",
    00000481 => x"c69ff0ef",
    00000482 => x"00050493",
    00000483 => x"02051863",
    00000484 => x"ffff1537",
    00000485 => x"e9c50513",
    00000486 => x"538000ef",
    00000487 => x"008005b7",
    00000488 => x"00048513",
    00000489 => x"f31ff0ef",
    00000490 => x"4788d7b7",
    00000491 => x"afe78793",
    00000492 => x"02f50463",
    00000493 => x"00000513",
    00000494 => x"fcdff06f",
    00000495 => x"ffff1537",
    00000496 => x"ebc50513",
    00000497 => x"50c000ef",
    00000498 => x"e15ff0ef",
    00000499 => x"fc0518e3",
    00000500 => x"00300513",
    00000501 => x"fb1ff06f",
    00000502 => x"008009b7",
    00000503 => x"00498593",
    00000504 => x"00048513",
    00000505 => x"ef1ff0ef",
    00000506 => x"00050a13",
    00000507 => x"00898593",
    00000508 => x"00048513",
    00000509 => x"ee1ff0ef",
    00000510 => x"ff002b83",
    00000511 => x"00050a93",
    00000512 => x"ffca7b13",
    00000513 => x"00000913",
    00000514 => x"00c98993",
    00000515 => x"013905b3",
    00000516 => x"052b1863",
    00000517 => x"01540433",
    00000518 => x"00200513",
    00000519 => x"f60414e3",
    00000520 => x"ffff1537",
    00000521 => x"ec850513",
    00000522 => x"4a8000ef",
    00000523 => x"02c12083",
    00000524 => x"02812403",
    00000525 => x"800007b7",
    00000526 => x"0147a023",
    00000527 => x"02412483",
    00000528 => x"02012903",
    00000529 => x"01c12983",
    00000530 => x"01812a03",
    00000531 => x"01412a83",
    00000532 => x"01012b03",
    00000533 => x"00c12b83",
    00000534 => x"03010113",
    00000535 => x"00008067",
    00000536 => x"00048513",
    00000537 => x"e71ff0ef",
    00000538 => x"012b87b3",
    00000539 => x"00a40433",
    00000540 => x"00a7a023",
    00000541 => x"00490913",
    00000542 => x"f95ff06f",
    00000543 => x"ff010113",
    00000544 => x"00112623",
    00000545 => x"ec9ff0ef",
    00000546 => x"ffff1537",
    00000547 => x"ecc50513",
    00000548 => x"440000ef",
    00000549 => x"b05ff0ef",
    00000550 => x"0000006f",
    00000551 => x"ff010113",
    00000552 => x"00112623",
    00000553 => x"00812423",
    00000554 => x"00912223",
    00000555 => x"00058413",
    00000556 => x"00050493",
    00000557 => x"d6dff0ef",
    00000558 => x"00000513",
    00000559 => x"4b8000ef",
    00000560 => x"00200513",
    00000561 => x"4f4000ef",
    00000562 => x"00048513",
    00000563 => x"d7dff0ef",
    00000564 => x"00040513",
    00000565 => x"4e4000ef",
    00000566 => x"00000513",
    00000567 => x"4b8000ef",
    00000568 => x"cb9ff0ef",
    00000569 => x"00157513",
    00000570 => x"fe051ce3",
    00000571 => x"00c12083",
    00000572 => x"00812403",
    00000573 => x"00412483",
    00000574 => x"01010113",
    00000575 => x"00008067",
    00000576 => x"fe010113",
    00000577 => x"00812c23",
    00000578 => x"00912a23",
    00000579 => x"01212823",
    00000580 => x"00112e23",
    00000581 => x"00b12623",
    00000582 => x"00300413",
    00000583 => x"00350493",
    00000584 => x"fff00913",
    00000585 => x"00c10793",
    00000586 => x"008787b3",
    00000587 => x"0007c583",
    00000588 => x"40848533",
    00000589 => x"fff40413",
    00000590 => x"f65ff0ef",
    00000591 => x"ff2414e3",
    00000592 => x"01c12083",
    00000593 => x"01812403",
    00000594 => x"01412483",
    00000595 => x"01012903",
    00000596 => x"02010113",
    00000597 => x"00008067",
    00000598 => x"ff010113",
    00000599 => x"00112623",
    00000600 => x"00812423",
    00000601 => x"00050413",
    00000602 => x"cb9ff0ef",
    00000603 => x"00000513",
    00000604 => x"404000ef",
    00000605 => x"0d800513",
    00000606 => x"440000ef",
    00000607 => x"00040513",
    00000608 => x"cc9ff0ef",
    00000609 => x"00000513",
    00000610 => x"40c000ef",
    00000611 => x"c0dff0ef",
    00000612 => x"00157513",
    00000613 => x"fe051ce3",
    00000614 => x"00c12083",
    00000615 => x"00812403",
    00000616 => x"01010113",
    00000617 => x"00008067",
    00000618 => x"fe010113",
    00000619 => x"800007b7",
    00000620 => x"00812c23",
    00000621 => x"0007a403",
    00000622 => x"00112e23",
    00000623 => x"00912a23",
    00000624 => x"01212823",
    00000625 => x"01312623",
    00000626 => x"01412423",
    00000627 => x"01512223",
    00000628 => x"02041863",
    00000629 => x"ffff1537",
    00000630 => x"e5450513",
    00000631 => x"01812403",
    00000632 => x"01c12083",
    00000633 => x"01412483",
    00000634 => x"01012903",
    00000635 => x"00c12983",
    00000636 => x"00812a03",
    00000637 => x"00412a83",
    00000638 => x"02010113",
    00000639 => x"2d40006f",
    00000640 => x"ffff1537",
    00000641 => x"ed050513",
    00000642 => x"2c8000ef",
    00000643 => x"00040513",
    00000644 => x"a15ff0ef",
    00000645 => x"ffff1537",
    00000646 => x"edc50513",
    00000647 => x"2b4000ef",
    00000648 => x"00800537",
    00000649 => x"a01ff0ef",
    00000650 => x"ffff1537",
    00000651 => x"ef850513",
    00000652 => x"2a0000ef",
    00000653 => x"280000ef",
    00000654 => x"00050493",
    00000655 => x"268000ef",
    00000656 => x"07900793",
    00000657 => x"0af49e63",
    00000658 => x"b95ff0ef",
    00000659 => x"00051663",
    00000660 => x"00300513",
    00000661 => x"999ff0ef",
    00000662 => x"ffff1537",
    00000663 => x"f0450513",
    00000664 => x"01045493",
    00000665 => x"26c000ef",
    00000666 => x"00148493",
    00000667 => x"00800937",
    00000668 => x"fff00993",
    00000669 => x"00010a37",
    00000670 => x"fff48493",
    00000671 => x"07349063",
    00000672 => x"4788d5b7",
    00000673 => x"afe58593",
    00000674 => x"00800537",
    00000675 => x"e75ff0ef",
    00000676 => x"00800537",
    00000677 => x"00040593",
    00000678 => x"00450513",
    00000679 => x"e65ff0ef",
    00000680 => x"ff002a03",
    00000681 => x"008009b7",
    00000682 => x"ffc47413",
    00000683 => x"00000493",
    00000684 => x"00000913",
    00000685 => x"00c98a93",
    00000686 => x"01548533",
    00000687 => x"009a07b3",
    00000688 => x"02849663",
    00000689 => x"00898513",
    00000690 => x"412005b3",
    00000691 => x"e35ff0ef",
    00000692 => x"ffff1537",
    00000693 => x"ec850513",
    00000694 => x"f05ff06f",
    00000695 => x"00090513",
    00000696 => x"e79ff0ef",
    00000697 => x"01490933",
    00000698 => x"f91ff06f",
    00000699 => x"0007a583",
    00000700 => x"00448493",
    00000701 => x"00b90933",
    00000702 => x"e09ff0ef",
    00000703 => x"fbdff06f",
    00000704 => x"01c12083",
    00000705 => x"01812403",
    00000706 => x"01412483",
    00000707 => x"01012903",
    00000708 => x"00c12983",
    00000709 => x"00812a03",
    00000710 => x"00412a83",
    00000711 => x"02010113",
    00000712 => x"00008067",
    00000713 => x"fe010113",
    00000714 => x"00912a23",
    00000715 => x"01212823",
    00000716 => x"01312623",
    00000717 => x"01412423",
    00000718 => x"00112e23",
    00000719 => x"00812c23",
    00000720 => x"00000493",
    00000721 => x"00900993",
    00000722 => x"00300a13",
    00000723 => x"00400913",
    00000724 => x"f1302473",
    00000725 => x"40900533",
    00000726 => x"00351513",
    00000727 => x"01850513",
    00000728 => x"00a45433",
    00000729 => x"0ff47413",
    00000730 => x"00000513",
    00000731 => x"0489ea63",
    00000732 => x"00050863",
    00000733 => x"03050513",
    00000734 => x"0ff57513",
    00000735 => x"128000ef",
    00000736 => x"03040513",
    00000737 => x"0ff57513",
    00000738 => x"11c000ef",
    00000739 => x"01448663",
    00000740 => x"02e00513",
    00000741 => x"110000ef",
    00000742 => x"00148493",
    00000743 => x"fb249ae3",
    00000744 => x"01c12083",
    00000745 => x"01812403",
    00000746 => x"01412483",
    00000747 => x"01012903",
    00000748 => x"00c12983",
    00000749 => x"00812a03",
    00000750 => x"02010113",
    00000751 => x"00008067",
    00000752 => x"ff640413",
    00000753 => x"00150513",
    00000754 => x"0ff47413",
    00000755 => x"0ff57513",
    00000756 => x"f9dff06f",
    00000757 => x"ff010113",
    00000758 => x"f9402783",
    00000759 => x"f9002703",
    00000760 => x"f9402683",
    00000761 => x"fed79ae3",
    00000762 => x"00e12023",
    00000763 => x"00f12223",
    00000764 => x"00012503",
    00000765 => x"00412583",
    00000766 => x"01010113",
    00000767 => x"00008067",
    00000768 => x"f9800693",
    00000769 => x"fff00613",
    00000770 => x"00c6a023",
    00000771 => x"00a6a023",
    00000772 => x"00b6a223",
    00000773 => x"00008067",
    00000774 => x"fa002023",
    00000775 => x"fe002683",
    00000776 => x"00151513",
    00000777 => x"00000713",
    00000778 => x"04a6f263",
    00000779 => x"000016b7",
    00000780 => x"00000793",
    00000781 => x"ffe68693",
    00000782 => x"04e6e463",
    00000783 => x"00167613",
    00000784 => x"0015f593",
    00000785 => x"01879793",
    00000786 => x"01e61613",
    00000787 => x"00c7e7b3",
    00000788 => x"01d59593",
    00000789 => x"00b7e7b3",
    00000790 => x"00e7e7b3",
    00000791 => x"10000737",
    00000792 => x"00e7e7b3",
    00000793 => x"faf02023",
    00000794 => x"00008067",
    00000795 => x"00170793",
    00000796 => x"01079713",
    00000797 => x"40a686b3",
    00000798 => x"01075713",
    00000799 => x"fadff06f",
    00000800 => x"ffe78513",
    00000801 => x"0fd57513",
    00000802 => x"00051a63",
    00000803 => x"00375713",
    00000804 => x"00178793",
    00000805 => x"0ff7f793",
    00000806 => x"fa1ff06f",
    00000807 => x"00175713",
    00000808 => x"ff1ff06f",
    00000809 => x"fa002783",
    00000810 => x"fe07cee3",
    00000811 => x"faa02223",
    00000812 => x"00008067",
    00000813 => x"fa402503",
    00000814 => x"fe055ee3",
    00000815 => x"0ff57513",
    00000816 => x"00008067",
    00000817 => x"fa402503",
    00000818 => x"0ff57513",
    00000819 => x"00008067",
    00000820 => x"ff010113",
    00000821 => x"00812423",
    00000822 => x"01212023",
    00000823 => x"00112623",
    00000824 => x"00912223",
    00000825 => x"00050413",
    00000826 => x"00a00913",
    00000827 => x"00044483",
    00000828 => x"00140413",
    00000829 => x"00049e63",
    00000830 => x"00c12083",
    00000831 => x"00812403",
    00000832 => x"00412483",
    00000833 => x"00012903",
    00000834 => x"01010113",
    00000835 => x"00008067",
    00000836 => x"01249663",
    00000837 => x"00d00513",
    00000838 => x"f8dff0ef",
    00000839 => x"00048513",
    00000840 => x"f85ff0ef",
    00000841 => x"fc9ff06f",
    00000842 => x"00757513",
    00000843 => x"00177793",
    00000844 => x"01079793",
    00000845 => x"0036f693",
    00000846 => x"00a51513",
    00000847 => x"00f56533",
    00000848 => x"00167613",
    00000849 => x"00e69793",
    00000850 => x"0015f593",
    00000851 => x"00f567b3",
    00000852 => x"00d61613",
    00000853 => x"00c7e7b3",
    00000854 => x"00959593",
    00000855 => x"fa800813",
    00000856 => x"00b7e7b3",
    00000857 => x"00082023",
    00000858 => x"1007e793",
    00000859 => x"00f82023",
    00000860 => x"00008067",
    00000861 => x"fa800713",
    00000862 => x"00072683",
    00000863 => x"00757793",
    00000864 => x"00100513",
    00000865 => x"00f51533",
    00000866 => x"00d56533",
    00000867 => x"00a72023",
    00000868 => x"00008067",
    00000869 => x"fa800713",
    00000870 => x"00072683",
    00000871 => x"00757513",
    00000872 => x"00100793",
    00000873 => x"00a797b3",
    00000874 => x"fff7c793",
    00000875 => x"00d7f7b3",
    00000876 => x"00f72023",
    00000877 => x"00008067",
    00000878 => x"faa02623",
    00000879 => x"fa802783",
    00000880 => x"fe07cee3",
    00000881 => x"fac02503",
    00000882 => x"00008067",
    00000883 => x"f8400713",
    00000884 => x"00072683",
    00000885 => x"00100793",
    00000886 => x"00a797b3",
    00000887 => x"00d7c7b3",
    00000888 => x"00f72023",
    00000889 => x"00008067",
    00000890 => x"f8a02223",
    00000891 => x"00008067",
    00000892 => x"69617641",
    00000893 => x"6c62616c",
    00000894 => x"4d432065",
    00000895 => x"0a3a7344",
    00000896 => x"203a6820",
    00000897 => x"706c6548",
    00000898 => x"3a72200a",
    00000899 => x"73655220",
    00000900 => x"74726174",
    00000901 => x"3a75200a",
    00000902 => x"6c705520",
    00000903 => x"0a64616f",
    00000904 => x"203a7320",
    00000905 => x"726f7453",
    00000906 => x"6f742065",
    00000907 => x"616c6620",
    00000908 => x"200a6873",
    00000909 => x"4c203a6c",
    00000910 => x"2064616f",
    00000911 => x"6d6f7266",
    00000912 => x"616c6620",
    00000913 => x"200a6873",
    00000914 => x"45203a65",
    00000915 => x"75636578",
    00000916 => x"00006574",
    00000917 => x"65206f4e",
    00000918 => x"75636578",
    00000919 => x"6c626174",
    00000920 => x"76612065",
    00000921 => x"616c6961",
    00000922 => x"2e656c62",
    00000923 => x"00000000",
    00000924 => x"746f6f42",
    00000925 => x"2e676e69",
    00000926 => x"0a0a2e2e",
    00000927 => x"00000000",
    00000928 => x"52450a07",
    00000929 => x"5f524f52",
    00000930 => x"00000000",
    00000931 => x"58450a0a",
    00000932 => x"00282043",
    00000933 => x"20402029",
    00000934 => x"00007830",
    00000935 => x"69617741",
    00000936 => x"676e6974",
    00000937 => x"6f656e20",
    00000938 => x"32337672",
    00000939 => x"6578655f",
    00000940 => x"6e69622e",
    00000941 => x"202e2e2e",
    00000942 => x"00000000",
    00000943 => x"64616f4c",
    00000944 => x"2e676e69",
    00000945 => x"00202e2e",
    00000946 => x"00004b4f",
    00000947 => x"0000000a",
    00000948 => x"74697257",
    00000949 => x"78302065",
    00000950 => x"00000000",
    00000951 => x"74796220",
    00000952 => x"74207365",
    00000953 => x"5053206f",
    00000954 => x"6c662049",
    00000955 => x"20687361",
    00000956 => x"78302040",
    00000957 => x"00000000",
    00000958 => x"7928203f",
    00000959 => x"20296e2f",
    00000960 => x"00000000",
    00000961 => x"616c460a",
    00000962 => x"6e696873",
    00000963 => x"2e2e2e67",
    00000964 => x"00000020",
    00000965 => x"0a0a0a0a",
    00000966 => x"4e203c3c",
    00000967 => x"56524f45",
    00000968 => x"42203233",
    00000969 => x"6c746f6f",
    00000970 => x"6564616f",
    00000971 => x"3e3e2072",
    00000972 => x"4c420a0a",
    00000973 => x"203a5644",
    00000974 => x"2074634f",
    00000975 => x"32203731",
    00000976 => x"0a303230",
    00000977 => x"3a565748",
    00000978 => x"00002020",
    00000979 => x"4b4c430a",
    00000980 => x"0020203a",
    00000981 => x"0a7a4820",
    00000982 => x"52455355",
    00000983 => x"0000203a",
    00000984 => x"53494d0a",
    00000985 => x"00203a41",
    00000986 => x"4f52500a",
    00000987 => x"00203a43",
    00000988 => x"454d490a",
    00000989 => x"00203a4d",
    00000990 => x"74796220",
    00000991 => x"40207365",
    00000992 => x"00000020",
    00000993 => x"454d440a",
    00000994 => x"00203a4d",
    00000995 => x"75410a0a",
    00000996 => x"6f626f74",
    00000997 => x"6920746f",
    00000998 => x"7338206e",
    00000999 => x"7250202e",
    00001000 => x"20737365",
    00001001 => x"2079656b",
    00001002 => x"61206f74",
    00001003 => x"74726f62",
    00001004 => x"00000a2e",
    00001005 => x"726f6241",
    00001006 => x"2e646574",
    00001007 => x"00000a0a",
    00001008 => x"444d430a",
    00001009 => x"00203e3a",
    00001010 => x"53207962",
    00001011 => x"68706574",
    00001012 => x"4e206e61",
    00001013 => x"69746c6f",
    00001014 => x"0000676e",
    00001015 => x"61766e49",
    00001016 => x"2064696c",
    00001017 => x"00444d43",
    00001018 => x"33323130",
    00001019 => x"37363534",
    00001020 => x"42413938",
    00001021 => x"46454443",
    others   => x"00000000"
  );

end neorv32_bootloader_image;