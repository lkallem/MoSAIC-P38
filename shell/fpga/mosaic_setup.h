
#ifdef DDR4
	#undef DDR4
#endif

int nRows = 2;
int nCols = 2;

uint32_t packetRxCountRegister = 0x14;
uint32_t coordinatesRegister   = 0x10;

uint32_t tileAddresses [2][2] = {{0x0000, 0x0100},
											{0x0200, 0x0300}};

char file_name [2][2][30] = {
										{"pico_scratchpad.hex", ""},
										{"", "test_tile_nop.hex"}};

uint32_t coordinates [2][2] = {{0x0000, 0x0008},
										 {0x0001, 0x0009}};

