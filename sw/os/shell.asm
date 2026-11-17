; shell, the computers home base
; shows a "> " prompt, collects a typed line, runs its command on Enter
; also watches the UART queue for a program upload from the PC
; receive_program takes it and run_program runs it
; commands, numbers in hex without 0x, dump COUNT in decimal
; help, clear, type, run, peek ADDR, poke ADDR VALUE, dump ADDR [COUNT],
; ticks, echo TEXT, mem, reboot, heap, go ADDR, sdread.block, sdread.file, sdwrite.file, sdinfo,
; sdinfo.file, ls [PATH], cd [PATH], mkdir NAME, touch NAME, rm NAME, mv OLD NEW, cp OLD NEW,
; rename OLD NAME, cat NAME, desktop, time [YYMMDDHHMMSS], pins [out HHHH | set HHHH], net
; a new command = a routine (in R1 = text after its name), a .string, 2 lines in command_table

.include "sw/os/shell/main.asm"         ; start, prompt, reading a line, finding its command
.include "sw/os/shell/words.asm"        ; words, hex and decimal numbers
.include "sw/os/shell/basics.asm"       ; help, clear, type, run, reboot
.include "sw/os/shell/system.asm"       ; ticks, peek, poke, dump, echo, heap
.include "sw/os/shell/card.asm"         ; sdinfo, ls, cat, sdread / sdwrite, file system errors
.include "sw/os/shell/folders.asm"      ; cd, mkdir, touch, rm, the current path
.include "sw/os/shell/moving.asm"       ; mv, cp, rename
.include "sw/os/shell/uploads.asm"      ; numbers on the screen, uploads from the PC
.include "sw/os/shell/more.asm"         ; mem, the shells note, time, pins, desktop
.include "sw/os/shell/tables.asm"       ; command table and texts
