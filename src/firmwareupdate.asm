; MIDI CPU
; copyright John Staskevich, 2017
; john@codeandcopper.com
;
; This work is licensed under a Creative Commons Attribution 4.0 International License.
; http://creativecommons.org/licenses/by/4.0/
;
; firmwareupdate.asm
;
; Bootloader-over-MIDI-SysEx code.
;
   		list		p=16f887
		#include	<p16f887.inc>
		#include	<mc.inc>

		global	fupdate_isr

fupdate	code	0x0020

; ==================================================================
;
; firmware update--all functionality in isr.
;
; ==================================================================

; STATE_FLAGS alternative bits
; 0 - Sysex has begun and we're listening
; 1 - Sysex Header is Valid
; 2 - 
; 3 - Firmware Update Mode (isr selector)
; 4 - Current chunk is checksum
; 5 - Current chunk is code
; 6 - 
; 7 - 


fupdate_isr

; context storage already complete
		clrf	STATUS

fupdate_handle_rx
; Clear the Rx interrupt flag
		bcf		PIR1,5
; Grab the RX byte
		movfw	RCREG
		movwf	TEMP

; is SysEx begin?
		movlw	0xF0
		subwf	TEMP,w
		bz		fupdate_sysex_begin

; is SysEx end?
		movlw	0xF7
		subwf	TEMP,w
		bz		fupdate_sysex_end

; real time status (ignored)?
		movfw	TEMP
		andlw	B'11111000'
		sublw	B'11111000'
		bz		fupdate_isr_finish

; some other status?
		btfsc	TEMP,7
		goto	fupdate_sysex_error

; are we still checking?
		btfss	STATE_FLAGS,0
		goto	fupdate_isr_finish

; is the header complete?
		btfsc	STATE_FLAGS,1
		goto	fupdate_get_data

; check header for validity
fupdate_check
		incf	INBOUND_BYTECOUNT,f
		movfw	INBOUND_BYTECOUNT
		movwf	TEMP2

fupdate_check_1
		decfsz	TEMP2,f
		goto	fupdate_check_2
		movlw	0x00
		subwf	TEMP,w
		bnz		fupdate_sysex_error
		goto	fupdate_isr_finish
		
fupdate_check_2
		decfsz	TEMP2,f
		goto	fupdate_check_3
		movlw	0x01
		subwf	TEMP,w
		bnz		fupdate_sysex_error
		goto	fupdate_isr_finish
		
fupdate_check_3
		decfsz	TEMP2,f
		goto	fupdate_check_4
		movlw	0x5D
		subwf	TEMP,w
		bnz		fupdate_sysex_error
		goto	fupdate_isr_finish
		
fupdate_check_4
		decfsz	TEMP2,f
		goto	fupdate_sysex_error
		movlw	0x04
		subwf	TEMP,w
		bnz		fupdate_sysex_error
; header now relevant
		bsf		STATE_FLAGS,1
; reset bytecount
		clrf	INBOUND_BYTECOUNT
		goto	fupdate_isr_finish

fupdate_sysex_begin
; new message
		clrf	INBOUND_BYTECOUNT
; incomplete
		bsf		STATE_FLAGS,0
; not yet relevant
		bcf		STATE_FLAGS,1
		goto	fupdate_isr_finish

fupdate_get_data
; check for chunk start
		incf	INBOUND_BYTECOUNT,f
		movfw	INBOUND_BYTECOUNT
		movwf	TEMP2

fupdate_get_1
		decfsz	TEMP2,f
		goto	fupdate_get_chunk_body
		movlw	0x7E
		subwf	TEMP,w
		bz		fupdate_get_code_begin
		movlw	0x7F
		subwf	TEMP,w
		bz		fupdate_get_checksum_begin

		movfw	TEMP
		bnz		fupdate_sysex_error
; for zero byte, treat as filler and wait for a chunk start byte
		decf	INBOUND_BYTECOUNT,f
		goto	fupdate_isr_finish

fupdate_get_chunk_body
		btfsc	STATE_FLAGS,5
		goto	fupdate_get_code_chunk
		btfsc	STATE_FLAGS,4
		goto	fupdate_get_checksum_chunk
		goto	fupdate_sysex_error

fupdate_get_code_begin
; set the code chunk flag
		bsf		STATE_FLAGS,5
; clear the code counter
		clrf	TEMP3
		goto	fupdate_isr_finish

fupdate_get_checksum_begin
; set the checksum chunk flag
		bsf		STATE_FLAGS,4
		goto	fupdate_isr_finish

fupdate_get_checksum_chunk
fg_sum_1
		decfsz	TEMP2,f
		goto	fg_sum_2
; checksum low data
		movfw	TEMP
		movwf	TEMP4
		goto	fupdate_isr_finish
fg_sum_2
		decfsz	TEMP2,f
		goto	fg_sum_3
; checksum low check
		movfw	TEMP4
		addlw	B'10000000'
		addwf	TEMP,f
		incfsz	TEMP,f
		goto	fupdate_sysex_error
		goto	fupdate_isr_finish
fg_sum_3
		decfsz	TEMP2,f
		goto	fg_sum_4
; checksum mid data
		movfw	TEMP
		movwf	TEMP5
		goto	fupdate_isr_finish
fg_sum_4
		decfsz	TEMP2,f
		goto	fg_sum_5
; checksum mid check
		movfw	TEMP5
		addlw	B'10000000'
		addwf	TEMP,f
		incfsz	TEMP,f
		goto	fupdate_sysex_error
		goto	fupdate_isr_finish
fg_sum_5
		decfsz	TEMP2,f
		goto	fg_sum_6
; checksum high data
		movfw	TEMP
		movwf	TEMP6
		goto	fupdate_isr_finish
fg_sum_6
		decfsz	TEMP2,f
		goto	fg_sum_7
; checksum high check
		movfw	TEMP6
		addlw	B'10000000'
		addwf	TEMP,f
		incfsz	TEMP,f
		goto	fupdate_sysex_error
; move all 16 bits to TEMP5,TEMP4
		btfsc	TEMP5,0
		bsf		TEMP4,7
		btfsc	TEMP6,0
		bsf		TEMP5,7
		bcf		STATUS,C
		rrf		TEMP5,f
		btfsc	TEMP6,1
		bsf		TEMP5,7
		goto	fupdate_isr_finish
fg_sum_7
		decfsz	TEMP2,f
		goto	fg_sum_8
; version data
		movfw	TEMP
		movwf	TEMP6
		goto	fupdate_isr_finish
fg_sum_8
		decfsz	TEMP2,f
		goto	fupdate_sysex_error
; version check
		movfw	TEMP6
		addlw	B'10000000'
		addwf	TEMP,f
		incfsz	TEMP,f
		goto	fupdate_sysex_error
; store the checksum & version to data EEPROM
; store to EEPROM
; turn off all interrupts
		bcf		INTCON,GIE
		btfsc	INTCON,GIE
		goto	$-2
; make sure any writes are complete
		banksel	EECON1
		btfsc	EECON1,WR
		goto	$-1
; write version
		banksel	PORTA
		movfw	TEMP6
		banksel	EEDAT
		movwf	EEDAT
		movlw	PROM_VERSION
		movwf	EEADR
		banksel	EECON1
		bcf		EECON1,EEPGD
		bsf		EECON1,WREN
		movlw	0x55
		movwf	EECON2
		movlw	0xAA
		movwf	EECON2
		bsf		EECON1,WR
; wait for write to complete
;		banksel	PIR2
;		btfss	PIR2,EEIF
;		goto	$-1
;		bcf		PIR2,EEIF

; make sure any writes are complete
;		banksel	EECON1
		btfsc	EECON1,WR
		goto	$-1
; write high byte
		banksel	PORTA
		movfw	TEMP5
		banksel	EEDAT
		movwf	EEDAT
		incf	EEADR,f
		banksel	EECON1
		bcf		EECON1,EEPGD
		bsf		EECON1,WREN
		movlw	0x55
		movwf	EECON2
		movlw	0xAA
		movwf	EECON2
		bsf		EECON1,WR
; wait for write to complete
;		banksel	PIR2
;		btfss	PIR2,EEIF
;		goto	$-1
;		bcf		PIR2,EEIF

; make sure any writes are complete
		banksel	EECON1
		btfsc	EECON1,WR
		goto	$-1
; write low byte
		banksel	PORTA
		movfw	TEMP4
		banksel	EEDAT
		movwf	EEDAT
		incf	EEADR,f
		banksel	EECON1
		bcf		EECON1,EEPGD
		bsf		EECON1,WREN
		movlw	0x55
		movwf	EECON2
		movlw	0xAA
		movwf	EECON2
		bsf		EECON1,WR
; wait for write to complete
;		banksel	PIR2
;		btfss	PIR2,EEIF
;		goto	$-1
;		bcf		PIR2,EEIF
; make sure any writes are complete
		banksel	EECON1
		btfsc	EECON1,WR
		goto	$-1
; shut off activity LED and wait for user to power cycle
		banksel	PORTA
		movlw	B'01000000'
		movwf	PORTA
fupdate_wait_for_reset
		goto	fupdate_wait_for_reset

fupdate_get_code_chunk
fg_code_1
		decfsz	TEMP2,f
		goto	fg_code_2
; address low data
		movfw	TEMP
		movwf	TEMP5
		goto	fupdate_isr_finish

fg_code_2
		decfsz	TEMP2,f
		goto	fg_code_3
; address low check
		movfw	TEMP5
		addlw	B'10000000'
		addwf	TEMP,f
		incfsz	TEMP,f
		goto	fupdate_sysex_error
		goto	fupdate_isr_finish

fg_code_3
		decfsz	TEMP2,f
		goto	fg_code_4
; address high data
		movfw	TEMP
		movwf	TEMP6
		goto	fupdate_isr_finish

fg_code_4
		decfsz	TEMP2,f
		goto	fg_code_5
; address high check
		movfw	TEMP6
		addlw	B'10000000'
		addwf	TEMP,f
		incfsz	TEMP,f
		goto	fupdate_sysex_error
; change address from 7:7 to 6:8
		btfsc	TEMP6,0
		bsf		TEMP5,7
		bcf		STATUS,C
		rrf		TEMP6,f
		goto	fupdate_isr_finish

fg_code_5
		decfsz	TEMP2,f
		goto	fg_code_6
; opcode low data
		movfw	TEMP
;		movwf	TEMP4
		movwf	TEMP_IM
		goto	fupdate_isr_finish

fg_code_6
		decfsz	TEMP2,f
		goto	fg_code_7
; opcode low check
;		movfw	TEMP4
		movfw	TEMP_IM
		addlw	B'10000000'
		addwf	TEMP,f
		incfsz	TEMP,f
		goto	fupdate_sysex_error
		goto	fupdate_isr_finish

fg_code_7
		decfsz	TEMP2,f
		goto	fg_code_8
; opcode high data
		movfw	TEMP
		movwf	TEMP4
		goto	fupdate_isr_finish

fg_code_8
		decfsz	TEMP2,f
		goto	fupdate_sysex_error
; opcdode high check
		movfw	TEMP4
		addlw	B'10000000'
		addwf	TEMP,f
		incfsz	TEMP,f
		goto	fupdate_sysex_error
; ok--munged opcode is now TEMP4(7) : TEMP_IM (7)
; change from 7:7 to 6:8
		btfsc	TEMP4,0
		bsf		TEMP_IM,7
		bcf		STATUS,C
		rrf		TEMP4,f
; ok--munged opcode is now in TEMP4:TEMP_IM
; de-munge the opcode
		movfw	TEMP4
		bnz		demunge_check_clrw
; high byte is zero--check for unaltered literals
; nop    (0 0000 0000)
		movfw	TEMP_IM
		bz		fg_code_store
; return (0 0000 1000)
		movfw	TEMP_IM
		sublw	0x08
		bz		fg_code_store
; retfie (0 0000 1001)
		movfw	TEMP_IM
		sublw	0x09
		bz		fg_code_store
; sleep  (0 0110 0011)
		movfw	TEMP_IM
		sublw	B'01100011'
		bz		fg_code_store
; clrwdt (0 0110 0100)
		movfw	TEMP_IM
		sublw	B'01100100'
		bz		fg_code_store
		goto	demunge_bit_oriented

; clrw   (1 0000 0000)
demunge_check_clrw
		movfw	TEMP4
		sublw	0x01
		bnz		demunge_bit_oriented
		movfw	TEMP_IM
		bz		fg_code_store

; de-munge the bit-oriented opcodes
; use the opcode counter to cycle modifications
demunge_bit_oriented
; bit oriented instructions are 01 iibb bfff ffff
; check for the 01
		movfw	TEMP4
		andlw	B'00110000'
		sublw	B'00010000'
		bnz		demunge_reg_lit

		btfsc	TEMP3,1
		goto	demunge_bit_oriented_1x
demunge_bit_oriented_0x
		btfsc	TEMP3,0
		goto	demunge_bit_oriented_01
demunge_bit_oriented_00
		movlw	B'00001001'
		xorwf	TEMP4,f
		goto	demunge_reg_lit
demunge_bit_oriented_01
		movlw	B'00000010'
		xorwf	TEMP4,f
		goto	demunge_reg_lit
demunge_bit_oriented_1x
		btfsc	TEMP3,0
		goto	demunge_bit_oriented_11
demunge_bit_oriented_10
		movlw	B'00001110'
		xorwf	TEMP4,f
		goto	demunge_reg_lit
demunge_bit_oriented_11
		movlw	B'00000101'
		xorwf	TEMP4,f

; de-munge the registers & literals
; use the opcode counter to cycle modifications
demunge_reg_lit
		btfsc	TEMP3,1
		goto	demunge_reg_lit_1x
demunge_reg_lit_0x
		btfsc	TEMP3,0
		goto	demunge_reg_lit_01
demunge_reg_lit_00
		movlw	B'00011011'
		xorwf	TEMP_IM,f
		goto	fg_code_store
demunge_reg_lit_01
		movlw	B'00100001'
		xorwf	TEMP_IM,f
		goto	fg_code_store
demunge_reg_lit_1x
		btfsc	TEMP3,0
		goto	demunge_reg_lit_11
demunge_reg_lit_10
		movlw	B'00000111'
		xorwf	TEMP_IM,f
		goto	fg_code_store
demunge_reg_lit_11
		movlw	B'00110010'
		xorwf	TEMP_IM,f


fg_code_store
; store opcode low byte in buffer
		movlw	FIRMWARE_BUFFER
		movwf	FSR
		movfw	TEMP3
		addwf	FSR,f
		addwf	FSR,f
		movfw	TEMP_IM
		movwf	INDF
; store opcode high byte in buffer
		incf	FSR,f
		movfw	TEMP4
		movwf	INDF
; increment the opcode counter
		incf	TEMP3,f
; check for chunk completion
		movlw	D'32'
		subwf	TEMP3,w
		bz		fg_code_chunk_complete
; prepare bytecount for next 4-byte opcode
		movlw	0x04
		subwf	INBOUND_BYTECOUNT,f
		goto	fupdate_isr_finish

fg_code_chunk_complete
; write the code chunk to program EEPROM
; disable interrupts
		bcf		INTCON,GIE
		btfsc	INTCON,GIE
		goto	$-2
; write code to EEPROM
; FSR points to code buffer
		movlw	FIRMWARE_BUFFER
		movwf	FSR
; EEADRH:EEADR point to program chunk to write
		movfw	TEMP6
		banksel	EEADR
		movwf	EEADRH
		banksel	PORTA
		movfw	TEMP5
		banksel	EEADR
		movwf	EEADR
; 32 words to write
		movlw	D'32'
		movwf	TEMP
fg_code_write_loop
; set up the opcode
		movfw	INDF
		movwf	EEDAT
		incf	FSR,f
		movfw	INDF
		movwf	EEDATH
		incf	FSR,f
; trigger the write
		banksel	EECON1
		bsf		EECON1,EEPGD
		bsf		EECON1,WREN
		movlw	0x55
		movwf	EECON2
		movlw	0xAA
		movwf	EECON2
		bsf		EECON1,WR
		nop
		nop
		bcf		EECON1,WREN
; next opcode
		banksel	EEADR
		incf	EEADR,f
; in aligned 32-word chunk, EEADRH is never incremented
		decfsz	TEMP,f
		goto	fg_code_write_loop

; flush RX
		banksel	PORTA
		movfw	RCREG
		movfw	RCREG
		bcf		PIR1,5
		bcf		RCSTA,4
		bsf		RCSTA,4
; re-enable interrupts
		bsf		INTCON,GIE
; clear the code chunk flag
		bcf		STATE_FLAGS,5
; reset the bytecount
		clrf	INBOUND_BYTECOUNT
; wait for more chunks
		goto	fupdate_isr_finish


fupdate_sysex_end
; execution here is an error condition
; ignore other data
		bcf		STATE_FLAGS,1
		bcf		STATE_FLAGS,0
; clear LED
		banksel	PORTA
; porta read-mod-write ok here
		bsf		PORTA,6
		goto	$-1


fupdate_sysex_error
; ignore rest of message.
		bcf		STATE_FLAGS,1
		bcf		STATE_FLAGS,0
; blink LED
		banksel	PORTA
fupdate_error_blink
; porta read-mod-write ok here
		bsf		PORTA,6
		clrf	COUNTER_L
		clrf	COUNTER_H
		decfsz	COUNTER_L,f
		goto	$-1
		decfsz	COUNTER_H,f
		goto	$-3

; porta read-mod-write ok here
		bcf		PORTA,6
		clrf	COUNTER_L
		clrf	COUNTER_H
		decfsz	COUNTER_L,f
		goto	$-1
		decfsz	COUNTER_H,f
		goto	$-3
		goto	fupdate_error_blink



fupdate_isr_finish
		retfie

; make checksum the same as old update code!!!
		data	0x3BB5

		end
