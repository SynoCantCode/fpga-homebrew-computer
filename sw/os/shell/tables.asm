; command table and the shell texts
; included by shell.asm

command_table: .word help_name
.word command_help
.word clear_name
.word command_clear
.word type_name
.word command_type
.word run_name
.word command_run
.word peek_name
.word command_peek
.word poke_name
.word command_poke
.word dump_name
.word command_dump
.word ticks_name
.word command_ticks
.word echo_name
.word command_echo
.word mem_name
.word command_mem
.word reboot_name
.word command_reboot
.word sdread_name
.word command_sdread
.word heap_name
.word command_heap
.word sdinfo_name
.word command_sdinfo
.word sdread_file_name
.word command_sdread_file
.word cat_name
.word command_cat
.word sum_name
.word command_sum
.word colour_name
.word command_colour
.word color_name
.word command_colour
.word go_name
.word command_go
.word sdwrite_file_name
.word command_sdwrite_file
.word sdinfo_file_name
.word command_sdinfo_file
.word cd_name
.word command_cd
.word mkdir_name
.word command_mkdir
.word rm_name
.word command_rm
.word touch_name
.word command_touch
.word mv_name
.word command_mv
.word cp_name
.word command_cp
.word rename_name
.word command_rename
.word ls_name
.word command_ls
.word desktop_name
.word command_desktop
.word time_name
.word command_time
.word pins_name
.word command_pins
.word net_name
.word command_net
.word 0x0000_0000                       ; end of the table

mem_table: .word ROM_START
.word ROM_END - 1
.word mem_rom
.word KERNEL_VARIABLES
.word KERNEL_VARIABLES_END - 1
.word mem_kernel
.word PROGRAM_START
.word STACK_LIMIT - 1
.word mem_programs
.word STACK_LIMIT
.word STACK_TOP - 1
.word mem_stack
.word SDRAM_RESERVED
.word SDRAM_RESERVED_END - 1
.word mem_sdram
.word HEAP_START
.word HEAP_END - 1
.word mem_heap
.word TEXT_SCREEN
.word TEXT_SCREEN_END - 1
.word mem_screen
.word IO_START
.word 0xFFFF_FFFF
.word mem_io
.word 0x0000_0000                       ; end of the table
.word 0x0000_0000
.word 0x0000_0000

help_name: .string "help"
clear_name: .string "clear"
type_name: .string "type"
run_name: .string "run"
peek_name: .string "peek"
poke_name: .string "poke"
dump_name: .string "dump"
ticks_name: .string "ticks"
echo_name: .string "echo"
mem_name: .string "mem"
reboot_name: .string "reboot"
sdread_name: .string "sdread.block"
heap_name: .string "heap"
sdinfo_name: .string "sdinfo"
sdread_file_name: .string "sdread.file"
cat_name: .string "cat"
sum_name: .string "sum"
sum_text: .string "sum = 0x"
sum_size_text: .string "  size = d'"
colour_name: .string "colour"
color_name: .string "color"
go_name: .string "go"
sdwrite_file_name: .string "sdwrite.file"
sdinfo_file_name: .string "sdinfo.file"
cd_name: .string "cd"
mkdir_name: .string "mkdir"
rm_name: .string "rm"
touch_name: .string "touch"
mv_name: .string "mv"
cp_name: .string "cp"
rename_name: .string "rename"
ls_name: .string "ls"
desktop_name: .string "desktop"
time_name: .string "time"
pins_name: .string "pins"
net_name: .string "net"
pins_out_name: .string "out"
pins_set_name: .string "set"
pins_a_text: .string "A 0b"
pins_b_text: .string "  B 0b"
no_pins_text: .string "no answer from the pins chip (the MCP23017, I2C 0x20 on pins 41 and 42: wired? powered? RESET high?)"
pins_usage_text: .string "use: pins   or   pins out HHHH   or   pins set HHHH (hex: low byte A0-A7, high byte B0-B7)"
century_text: .string "20"
no_clock_text: .string "no answer from the clock chip (the DS3231, I2C 0x68 on pins 41 and 42: wired? powered?)"
time_usage_text: .string "use: time   or   time YYMMDDHHMMSS (e.g. time 261019140500)"
wm_path: .string "/wm.bin"

prompt: .string "> "
colon: .string ": "
two_spaces: .string "  "
unknown: .string "unknown command (help lists them)"
help_text: .string "help, clear, type, run [NAME], go ADDR, peek ADDR, poke ADDR VALUE, ticks,\ndump ADDR [COUNT], echo TEXT, mem, reboot, heap, sdinfo, sdinfo.file NAME,\nls [PATH], cd [PATH], mkdir NAME, touch NAME, rm NAME, cat NAME, sum NAME,\nmv OLD NEW, cp OLD NEW, rename OLD NAME, sdread.block BLOCK ADDR,\nsdread.file NAME ADDR, sdwrite.file NAME ADDR SIZE, desktop, time [YYMMDDHHMMSS],\ncolour, pins [out HHHH | set HHHH], net [up | listen]   (NAMEs can be paths; hex)\n"
type_text: .string "typing: Esc goes back to the shell"
run_text: .string "no program yet: upload one with send.sh"
ticks_text: .string "ticks: "
ticks_unit: .string " (hundredths of a second since reset, hex)"
peek_text: .string "use: peek ADDR (hex)"
poke_text: .string "use: poke ADDR VALUE (hex)"
dump_text: .string "use: dump ADDR [COUNT] (ADDR in hex, COUNT in decimal)"
aligned_text: .string "address must be a multiple of 4"
sdread_text: .string "read SD block "
saved_text: .string "saved "
saved_from_text: .string " bytes from "
sdwrite_file_usage_text: .string "use: sdwrite.file NAME ADDR SIZE (hex), e.g. sdwrite.file notes.txt 6000 258"
card_full_text: .string "the card is full"
not_folder_text: .string "that's a file, not a folder"
no_folder_text: .string "folder not found"
taken_text: .string "that name is already taken"
cant_move_text: .string "it can't be moved there"
no_memory_text: .string "not enough memory to copy that"
not_empty_text: .string "that folder isn't empty"
cant_delete_text: .string "that can't be deleted (the root, . or .., or the folder you're in)"
rename_usage_text: .string "use: rename OLD NAME (a new name, not a path: use mv to move it somewhere else)"
two_names_text: .string "use: mv OLD NEW / cp OLD NEW (names or paths), e.g. mv a.txt docs/a.txt"
slash_text: .string "/"
folder_full_text: .string "the folder is full (no free line in its list)"
go_usage_text: .string "use: go ADDR (hex), e.g. go 5000"
where_size_text: .string "size "
where_clusters_text: .string " bytes. Its clusters (and blocks):"
where_blocks_text: .string " = blocks "
where_dash_text: .string "-"
where_more_text: .string "... (and more)"
sdread_into: .string " into "
sd_error_text: .string "SD card error "
sdread_usage_text: .string "use: sdread.block BLOCK ADDR (hex)"
heap_size_text: .string "  size "
info_partition: .string "FAT32 part of the card starts at block "
info_cluster: .string "blocks per cluster "
info_fat: .string "the FAT starts at block "
info_data: .string "the data area starts at block "
info_root: .string "the root folder starts at cluster "
dir_text: .string "<DIR>"
kind_folder_text: .string "folder"
file_size_text: .string "file  size = d'"
loaded_text: .string "loaded at "
file_saved_text: .string "saved "
file_saved_size_text: .string " (d'"
file_saved_end_text: .string " bytes)"
file_saved_pc_text: .string "saved on the card"
file_failed_pc_text: .string "NOT saved"
incomplete_text: .string "upload incomplete: the PC stopped sending"
loaded_pc_text: .string "loaded, not run (type run to start it)"
not_run_text: .string ", not run (run starts it)"
file_read_text: .string "read "
file_bytes_text: .string " bytes into "
file_usage_text: .string "use: sdread.file NAME ADDR (ADDR in hex), e.g. sdread.file notes.txt 6000"
bad_name_text: .string "bad file name: up to 8 letters, a dot, up to 3 letters (like notes.txt)"
missing_text: .string "file not found"
folder_text: .string "that's a folder, not a file"
not_program_text: .string "not a program: only .bin files run"
no_room_text: .string "that program doesn't fit between 0x5000 and the stack (0xF000)"
refused_write_text: .string "refused: that block belongs to the card's file system"
damaged_text: .string "the file is damaged: its chain in the FAT ends too soon"
heap_taken_text: .string "  taken"
heap_free_text: .string "  free"
heap_damaged_text: .string "the heap's labels are damaged"
mem_rom: .string "ROM: the kernel's code"
mem_kernel: .string "kernel variables"
mem_programs: .string "a program's variables (or a small uploaded program)"
mem_screen: .string "text screen"
mem_stack: .string "stack"
mem_sdram: .string "SDRAM: kept back (KERNEL.BIN, programs, pages)"
mem_heap: .string "SDRAM: the heap, 5 MB (ALLOCATE / FREE)"
mem_io: .string "I/O devices"
