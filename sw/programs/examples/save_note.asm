; save_note, saves NOTE.TXT onto the SD card, then back to the shell
; upload it with send.sh
; then on the computer, cat note.txt
; FILE_WRITE, jump table entry 21, saves bytes from memory as a file
; in R1 = pointer to the file name, R2 = pointer to the bytes, R3 = how many, out R1 = 0 ok
.include "sw/os/devices.asm"
.org PROGRAM_START

        LOADLO R1, name             ; R1 = pointer to "note.txt"
        LOADLO R2, note             ; R2 = pointer to the text
        LOADLO R3, 0x0217           ; R3 = bytes of text, without the 0 at the end
        CALL   FILE_WRITE           ; the kernel saves it
        CMPI   R1, 0x0000
        JNZ    failed
        LOADLO R1, saved
        CALL   SCREEN_LINE          ; "saved NOTE.TXT ..."
        RET                         ; back to the shell
failed: MOV    R8, R1               ; R8 = the error number
        LOADLO R1, not_saved
        CALL   SCREEN_TEXT
        MOV    R1, R8
        CALL   SCREEN_HEX_WORD      ; the error number
        LOADLO R1, 0x000A
        CALL   SCREEN_CHAR
        RET

name:      .string "note.txt"
saved:     .string "saved NOTE.TXT on the SD card: try  cat note.txt"
not_saved: .string "could not save NOTE.TXT, error "
note:      .string "Hello from Claude!\nThis file was saved onto the SD card by your own computer:\na program you uploaded called FILE_WRITE (jump table entry 21 at 0x0054).\n\nThings to try:\n  ls                        see NOTE.TXT in the list\n  sdinfo.file note.txt      which clusters and blocks it is in\n  mkdir notes               make a folder\n  mv note.txt notes/a.txt   move it there (only its line moves)\n  cp notes/a.txt b.txt      copy it back out\n  cat notes/a.txt           read it again\n\nTake the card to your PC: NOTE.TXT opens in Notepad too.\n"
