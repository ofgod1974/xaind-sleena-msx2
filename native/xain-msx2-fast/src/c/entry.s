.module xain_c_entry
.globl _game_input
.globl _game_update
.globl _level_init
.area _CODE
jp _game_input
jp _game_update
jp _level_init
