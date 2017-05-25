; MIDI CPU
; copyright John Staskevich, 2017
; john@codeandcopper.com
;
; This work is licensed under a Creative Commons Attribution 4.0 International License.
; http://creativecommons.org/licenses/by/4.0/
;
; sysexfinish.asm
;
; Parse incoming sysex messages.
;
		list		p=16f887
   		#include	<p16f887.inc>
   		#include	<mc.inc>

		GLOBAL	inbound_sysex_finish
		EXTERN	read_pin_config
		EXTERN	sysex_error
		EXTERN	send_midi_byte

isf		code	0x1000

inbound_sysex_finish
; make sure the sysex close byte (F7) was preceded by sysex open (F0)
		movfw	INBOUND_STATUS
		sublw	0xF0
		bnz		isf_error
; make sure the header was relevant
		btfss	STATE_FLAGS,1
		goto	isf_error
; clear the inbound status to avoid any confusion with future bytes
		clrf	INBOUND_STATUS
; message now complete
		bcf		STATE_FLAGS,0
; turn off all interrupts
		bcf		INTCON,GIE
		btfsc	INTCON,GIE
		goto	$-2
; check for config dump request
		movfw	SYSEX_TYPE
		bz		isf_type_0

; at this point, an eeprom write and subsequent reset are certain to occur...
; ...so all TEMP variables may be used without concern for overwrites.

		decf	SYSEX_TYPE,f
		btfsc	STATUS,Z
		goto	isf_type_1

		decf	SYSEX_TYPE,f
		btfsc	STATUS,Z
		goto	isf_type_2

		decf	SYSEX_TYPE,f
		btfsc	STATUS,Z
		goto	isf_type_3

		decf	SYSEX_TYPE,f
		btfsc	STATUS,Z
		goto	isf_type_4

		decf	SYSEX_TYPE,f
		btfsc	STATUS,Z
		goto	isf_type_5

		decf	SYSEX_TYPE,f
		btfsc	STATUS,Z
		goto	isf_type_6

		decf	SYSEX_TYPE,f
		btfsc	STATUS,Z
		goto	isf_type_7

		decf	SYSEX_TYPE,f
		btfsc	STATUS,Z
		goto	isf_type_8

		decf	SYSEX_TYPE,f
		btfsc	STATUS,Z
		goto	isf_type_9

		decf	SYSEX_TYPE,f
		btfsc	STATUS,Z
		goto	isf_type_A

		decf	SYSEX_TYPE,f
		btfsc	STATUS,Z
		goto	isf_type_B

		goto	isf_error

isf_type_0
; prevent any attempt at running status after the dump
		clrf	OUTBOUND_STATUS
; intialize flags
		clrf	TEMP5
		clrf	TEMP6
; dump config via sysex.
; check first byte of payload to determine what to dump
		banksel	INCOMING_SYSEX_A
; 00 is invalid
		movfw	INCOMING_SYSEX_A
		bz		isf_error
; store "dump type" byte
		movwf	TEMP2

		sublw	0x01
		bz		isf_type_01

		movfw	INCOMING_SYSEX_A
		sublw	0x02
		bz		isf_type_02

		movfw	INCOMING_SYSEX_A
		sublw	0x03
		bz		isf_type_03

		movfw	INCOMING_SYSEX_A
		sublw	0x04
		bz		isf_type_04

		movfw	INCOMING_SYSEX_A
		sublw	0x05
		bz		isf_type_05

		movfw	INCOMING_SYSEX_A
		sublw	0x07
		bz		isf_type_07

		movfw	INCOMING_SYSEX_A
		sublw	0x08
		bz		isf_type_08

		movfw	INCOMING_SYSEX_A
		sublw	0x09
		bz		isf_type_09

		movfw	INCOMING_SYSEX_A
		sublw	0x0A
		bz		isf_type_0A

		movfw	INCOMING_SYSEX_A
		sublw	0x0B
		bz		isf_type_0B

		movfw	INCOMING_SYSEX_A
		sublw	0x7D
		bz		isf_type_07D

		movfw	INCOMING_SYSEX_A
		sublw	0x7F
		bz		isf_type_07F

		goto	isf_error

isf_type_07F
		banksel	TEMP5
		movlw	B'11111111'
		movwf	TEMP5
		movlw	B'00111111'
		movwf	TEMP6
		goto	isf_type_01_check_0

isf_type_01
; check for valid layer number
		banksel	INCOMING_SYSEX_A
; only 00, 01, 02, and 03 are valid
		movfw	INCOMING_SYSEX_A+1
		sublw	0x03
		bnc		isf_error
		movfw	INCOMING_SYSEX_A+1
		banksel	PORTA
		movwf	CONFIG_LAYER
		goto	isf_type_01_dump

isf_type_01_check_0
		btfss	TEMP6,0
		goto	isf_type_01_check_1
		bcf		TEMP6,0
		movlw	0x00
		movwf	CONFIG_LAYER
		goto	isf_type_01_dump
isf_type_01_check_1
		btfss	TEMP6,1
		goto	isf_type_01_check_2
		bcf		TEMP6,1
		movlw	0x01
		movwf	CONFIG_LAYER
		goto	isf_type_01_dump
isf_type_01_check_2
		btfss	TEMP6,2
		goto	isf_type_01_check_3
		bcf		TEMP6,2
		movlw	0x02
		movwf	CONFIG_LAYER
		goto	isf_type_01_dump
isf_type_01_check_3
		btfss	TEMP6,3
		goto	isf_type_01_skip
		bcf		TEMP6,3
		movlw	0x03
		movwf	CONFIG_LAYER
		goto	isf_type_01_dump

isf_type_01_dump
; dump the control terminal configs
		call	send_sysex_header
; sysex type
		movlw	0x01
		movwf	OUTBOUND_BYTE
		pagesel	send_midi_byte
		call	send_midi_byte
;		pagesel	inbound_sysex_finish
; layer
		movfw	CONFIG_LAYER
		movwf	OUTBOUND_BYTE
		pagesel	send_midi_byte
		call	send_midi_byte
;		pagesel	inbound_sysex_finish

; dump each configuration chunk.  24 control terminals, 2 chunks for each.
		movlw	D'24'
		movwf	COUNTER_L
		clrf	OUTPUT_COUNTER

isf_type_01_loop
		bcf		STATE_FLAGS,6
		pagesel	read_pin_config
		call	read_pin_config
; first chunk for transition 0
; nn
		movfw	OUTPUT_COUNTER
		movwf	OUTBOUND_BYTE
		pagesel	send_midi_byte
		call	send_midi_byte
; tt
		movlw	0x00
		movwf	OUTBOUND_BYTE
		call	send_midi_byte
; mm
		movfw	CONFIG_MODE
		movwf	OUTBOUND_BYTE
		call	send_midi_byte
; ch
		movfw	CONFIG_CHANNEL
		movwf	OUTBOUND_BYTE
		call	send_midi_byte
; d0
		movfw	CONFIG_D0
		movwf	OUTBOUND_BYTE
		call	send_midi_byte
; d1
		movfw	CONFIG_D1
		movwf	OUTBOUND_BYTE
		call	send_midi_byte

; second chunk for transition 1
		bsf		STATE_FLAGS,6
		pagesel	read_pin_config
		call	read_pin_config
; nn
		movfw	OUTPUT_COUNTER
		movwf	OUTBOUND_BYTE
		pagesel	send_midi_byte
		call	send_midi_byte
; tt
		movlw	0x01
		movwf	OUTBOUND_BYTE
		call	send_midi_byte
; mm
		movfw	CONFIG_MODE
		movwf	OUTBOUND_BYTE
		call	send_midi_byte
; ch
		movfw	CONFIG_CHANNEL
		movwf	OUTBOUND_BYTE
		call	send_midi_byte
; d0
		movfw	CONFIG_D0
		movwf	OUTBOUND_BYTE
		call	send_midi_byte
; d1
		movfw	CONFIG_D1
		movwf	OUTBOUND_BYTE
		call	send_midi_byte
		pagesel	inbound_sysex_finish

		incf	OUTPUT_COUNTER,f
		decfsz	COUNTER_L,f
		goto	isf_type_01_loop

; footer
		movlw	0xF7
		movwf	OUTBOUND_BYTE
		pagesel	send_midi_byte
		call	send_midi_byte
		pagesel	inbound_sysex_finish
;		goto	isf_flush
		goto	isf_type_01_check_1
isf_type_01_skip

isf_type_02_check
		btfss	TEMP5,0
		goto	isf_type_02_skip
		bcf		TEMP5,0
isf_type_02
; dump matrix note velocity
		movlw	0x02
		movwf	TEMP
		movlw	PROM_MATRIX_VELOCITY
		banksel	EEADR
		movwf	EEADR
		banksel	PORTA
		movlw	D'1'
		movwf	COUNTER_L
		goto	isf_dump_generic
isf_type_02_skip


isf_type_03_check
		btfss	TEMP5,1
		goto	isf_type_03_skip
		bcf		TEMP5,1
isf_type_03
; dump CC on/off values
		movlw	0x03
		movwf	TEMP
		movlw	PROM_CC_ON
		banksel	EEADR
		movwf	EEADR
		banksel	PORTA
		movlw	D'2'
		movwf	COUNTER_L
		goto	isf_dump_generic
isf_type_03_skip

isf_type_04_check
		btfss	TEMP5,2
		goto	isf_type_04_skip
		bcf		TEMP5,2
isf_type_04
; dump rotary encoder initial values
		movlw	0x04
		movwf	TEMP
		movlw	PROM_ENCODER_INIT
		banksel	EEADR
		movwf	EEADR
		banksel	PORTA
		movlw	D'12'
		movwf	COUNTER_L
		goto	isf_dump_generic
isf_type_04_skip

isf_type_05_check
		btfss	TEMP5,3
		goto	isf_type_05_skip
		bcf		TEMP5,3
isf_type_05
; dump note remap table
		movlw	0x05
		movwf	TEMP
		movlw	PROM_NOTE_MAP
		banksel	EEADR
		movwf	EEADR
		banksel	PORTA
		movlw	D'128'
		movwf	COUNTER_L
		goto	isf_dump_generic
isf_type_05_skip

isf_type_07_check
		btfss	TEMP5,4
		goto	isf_type_07_skip
		bcf		TEMP5,4
isf_type_07
		banksel	OUTBOUND_BYTE
; dump the outbound sysex buffer
		call	send_sysex_header
		movlw	0x07
		movwf	OUTBOUND_BYTE
		pagesel	send_midi_byte
		call	send_midi_byte
;		pagesel	inbound_sysex_finish
		movlw	D'128'
		movwf	COUNTER_L
		banksel	EEADR
		clrf	EEADR
		movlw	0x1F
		movwf	EEADRH
isf_type_07_loop
		banksel	EECON1
		bsf		EECON1,EEPGD
		bsf		EECON1,RD
		nop
		nop
		banksel	EEDAT
		movfw	EEDAT
		incf	EEADR,f
		banksel	PORTA
		movwf	OUTBOUND_BYTE
		pagesel	send_midi_byte
		call	send_midi_byte
		pagesel	inbound_sysex_finish

		decfsz	COUNTER_L,f
		goto	isf_type_07_loop

		movlw	0xF7
		movwf	OUTBOUND_BYTE
		pagesel	send_midi_byte
		call	send_midi_byte
		pagesel	inbound_sysex_finish
isf_type_07_skip

isf_type_08_check
		btfss	TEMP5,5
		goto	isf_type_08_skip
		bcf		TEMP5,5
isf_type_08
; dump adc config
		movlw	0x08
		movwf	TEMP
		movlw	PROM_ANALOG_THRESHOLD
		banksel	EEADR
		movwf	EEADR
		banksel	PORTA
		movlw	D'3'
		movwf	COUNTER_L
		goto	isf_dump_generic
isf_type_08_skip

isf_type_09_check
		btfss	TEMP5,6
		goto	isf_type_09_skip
		bcf		TEMP5,6
isf_type_09
; dump active sense setting
		movlw	0x09
		movwf	TEMP
		movlw	PROM_ACTIVE_SENSE
		banksel	EEADR
		movwf	EEADR
		banksel	PORTA
		movlw	D'1'
		movwf	COUNTER_L
		goto	isf_dump_generic
isf_type_09_skip

isf_type_0A_check
		btfss	TEMP6,4
		goto	isf_type_0A_skip
		bcf		TEMP6,4
isf_type_0A
; dump remap flags setting
		movlw	0x0A
		movwf	TEMP
		movlw	PROM_REMAP_FLAGS
		banksel	EEADR
		movwf	EEADR
		banksel	PORTA
		movlw	D'1'
		movwf	COUNTER_L
		goto	isf_dump_generic
isf_type_0A_skip

isf_type_0B_check
		btfss	TEMP6,5
		goto	isf_type_0B_skip
		bcf		TEMP6,5
isf_type_0B
; dump remap flags setting
		movlw	0x0B
		movwf	TEMP
		movlw	PROM_TRANSPOSE_REG
		banksel	EEADR
		movwf	EEADR
		banksel	PORTA
		movlw	D'1'
		movwf	COUNTER_L
		goto	isf_dump_generic
isf_type_0B_skip

isf_type_07D_check
		btfss	TEMP5,7
		goto	isf_type_07D_skip
		bcf		TEMP5,7
isf_type_07D
; dump active sense setting
		movlw	0x7D
		movwf	TEMP
		movlw	PROM_VERSION
		banksel	EEADR
		movwf	EEADR
		banksel	PORTA
		movlw	D'1'
		movwf	COUNTER_L
		goto	isf_dump_generic
isf_type_07D_skip

		goto	isf_flush

isf_dump_generic
		call	send_sysex_header
		movfw	TEMP
		movwf	OUTBOUND_BYTE
		pagesel	send_midi_byte
		call	send_midi_byte
;		pagesel	inbound_sysex_finish
isf_dump_generic_loop
; dump COUNTER_L bytes from data EEPROM at EEADR
		banksel	EECON1
		bcf		EECON1,EEPGD
		bsf		EECON1,RD
		banksel	EEDAT
		movfw	EEDAT
		incf	EEADR,f
		banksel	PORTA
		movwf	OUTBOUND_BYTE
		pagesel	send_midi_byte
		call	send_midi_byte
		pagesel	inbound_sysex_finish

		decfsz	COUNTER_L,f
		goto	isf_dump_generic_loop

		movlw	0xF7
		movwf	OUTBOUND_BYTE
		pagesel	send_midi_byte
		call	send_midi_byte
		pagesel	inbound_sysex_finish
;		goto	isf_flush
		goto	isf_type_03_check

isf_type_2
		banksel	EEADR
		movlw	PROM_MATRIX_VELOCITY
		movwf	EEADR
		banksel	PORTA
		movlw	0x01
		movwf	COUNTER_L
		goto	isf_generic

isf_type_3
		banksel	EEADR
		movlw	PROM_CC_ON
		movwf	EEADR
		banksel	PORTA
		movlw	0x02
		movwf	COUNTER_L
		goto	isf_generic

isf_type_4
		banksel	EEADR
		movlw	PROM_ENCODER_INIT
		movwf	EEADR
		banksel	PORTA
		movlw	D'12'
		movwf	COUNTER_L
		goto	isf_generic

isf_type_5
		banksel	EEADR
		movlw	PROM_NOTE_MAP
		movwf	EEADR
		banksel	PORTA
		movlw	D'128'
		movwf	COUNTER_L
		goto	isf_generic

isf_type_6
; fill area of data eeprom with sequential note numbers.
		banksel	EEADR
		movlw	PROM_NOTE_MAP
		movwf	EEADR
		clrf	EEDAT
		banksel	PORTA


		movlw	D'128'
		movwf	COUNTER_L
isf6_loop
; write a single byte to data eeprom
		banksel	EECON1
		bcf		EECON1,EEPGD
		bsf		EECON1,WREN
		movlw	0x55
		movwf	EECON2
		movlw	0xAA
		movwf	EECON2
		bsf		EECON1,WR
; wait for write to  complete
;		btfsc	EECON1,WR
;		goto	$-1
		banksel	PIR2
		btfss	PIR2,EEIF
		goto	$-1
		bcf		PIR2,EEIF
; next byte
		banksel	EEDAT
		incf	EEADR,f
		incf	EEDAT,f

		banksel	PORTA
		decfsz	COUNTER_L,f
		goto	isf6_loop
; reboot!
		goto	isf_reboot

isf_type_7
; special case--write buffer to program eeprom
; nothing follows the sysex buffer in program eeprom, so just write 192 bytes anyway
		banksel	EEADRH
		movlw	0x1F
		movwf	EEADRH
		clrf	EEADR
		goto	isf_type_1_write

isf_type_8
		banksel	EEADR
		movlw	PROM_ANALOG_THRESHOLD
		movwf	EEADR
		banksel	PORTA
		movlw	0x03
		movwf	COUNTER_L
		goto	isf_generic

isf_type_9
		banksel	EEADR
		movlw	PROM_ACTIVE_SENSE
		movwf	EEADR
		banksel	PORTA
		movlw	0x01
		movwf	COUNTER_L
		goto	isf_generic

isf_type_A
		banksel	EEADR
		movlw	PROM_REMAP_FLAGS
		movwf	EEADR
		banksel	PORTA
		movlw	0x01
		movwf	COUNTER_L
		goto	isf_generic

isf_type_B
		banksel	EEADR
		movlw	PROM_TRANSPOSE_REG
		movwf	EEADR
		banksel	PORTA
		movlw	0x01
		movwf	COUNTER_L
		goto	isf_generic

isf_generic
; take the incoming sysex buffer and write to data eeprom
		clrf	TEMP
		movlw	INCOMING_SYSEX_A
		movwf	FSR
		bcf		STATUS,IRP
isfg_loop
; write a single byte to data eeprom
		banksel	EEDAT
		movfw	INDF
		movwf	EEDAT
; make sure not to accidentally fill in any status bytes (might happen if message truncated)
		bcf		EEDAT,7
		banksel	EECON1
		bcf		EECON1,EEPGD
		bsf		EECON1,WREN
		movlw	0x55
		movwf	EECON2
		movlw	0xAA
		movwf	EECON2
		bsf		EECON1,WR
; wait for write to  complete
;		btfsc	EECON1,WR
;		goto	$-1
		banksel	PIR2
		btfss	PIR2,EEIF
		goto	$-1
		bcf		PIR2,EEIF
; next byte
		banksel	EEDAT
		incf	EEADR,f
		incf	FSR,f
		banksel	PORTA

		incf	TEMP,f
		btfss	TEMP,6
		goto	isfg_next
isfg_next_bank
; prepare to use second block of 64 incoming bytes
		clrf	TEMP
		movlw	INCOMING_SYSEX_B
		movwf	FSR
		bsf		STATUS,IRP
isfg_next
		decfsz	COUNTER_L,f
		goto	isfg_loop
; reboot!
		goto	isf_reboot


isf_type_1

;		bcf		PORTA,6
;		goto	$-1

; control terminal configuration.
; first, read from EEPROM and fill in any chunks not specified in the sysex.
		banksel	SYSEX_YY
		movfw	SYSEX_YY
		banksel	PORTA
		movwf	CONFIG_LAYER

		movlw	D'24'
		movwf	COUNTER_H
		clrf	OUTPUT_COUNTER
		bcf		STATE_FLAGS,6
isf_type_1_chunk_check_tt0
		call	fill_sysex_chunk
		incf	OUTPUT_COUNTER,f
		decfsz	COUNTER_H,f
		goto	isf_type_1_chunk_check_tt0

		movlw	D'24'
		movwf	COUNTER_H
		clrf	OUTPUT_COUNTER
		bsf		STATE_FLAGS,6
isf_type_1_chunk_check_tt1
		call	fill_sysex_chunk
		incf	OUTPUT_COUNTER,f
		decfsz	COUNTER_H,f
		goto	isf_type_1_chunk_check_tt1
; write new config to EEPROM
; point to the proper config layer in EEPROM

		banksel	SYSEX_YY
		decf	SYSEX_YY,f
		bz		isf_type_1_layer_1
		decf	SYSEX_YY,f
		bz		isf_type_1_layer_2
		decf	SYSEX_YY,f
		bz		isf_type_1_layer_3

isf_type_1_layer_0
;		goto	isf_type_1_layer_0_go
; special case: check for analog or encoder modes and copy config
; from tt=0 to tt=1 where necessary
; first 8 pins: copy from buffer a to buffer b
		banksel	PORTA
		movlw	D'8'
		movwf	COUNTER_H
		clrf	OUTPUT_COUNTER
isf_t1_copy_loop_ab
		movlw	INCOMING_SYSEX_A
		addwf	OUTPUT_COUNTER,w
		addwf	OUTPUT_COUNTER,w
		addwf	OUTPUT_COUNTER,w
		addwf	OUTPUT_COUNTER,w
		movwf	FSR
		bcf		STATUS,IRP
		btfsc	INDF,6
		goto	isf_t1_copy_loop_ab_next
		call	chunk_copy
		movlw	INCOMING_SYSEX_B+D'32'
		addwf	OUTPUT_COUNTER,w
		addwf	OUTPUT_COUNTER,w
		addwf	OUTPUT_COUNTER,w
		addwf	OUTPUT_COUNTER,w
		movwf	FSR
		bsf		STATUS,IRP
		call	chunk_paste
isf_t1_copy_loop_ab_next
		incf	OUTPUT_COUNTER,f
		decfsz	COUNTER_H,f
		goto	isf_t1_copy_loop_ab
; middle 8 pins: copy from buffer a to buffer c
		movlw	D'8'
		movwf	COUNTER_H
		clrf	OUTPUT_COUNTER
isf_t1_copy_loop_ac
		movlw	INCOMING_SYSEX_A+D'32'
		addwf	OUTPUT_COUNTER,w
		addwf	OUTPUT_COUNTER,w
		addwf	OUTPUT_COUNTER,w
		addwf	OUTPUT_COUNTER,w
		movwf	FSR
		bcf		STATUS,IRP
		btfsc	INDF,6
		goto	isf_t1_copy_loop_ac_next
		call	chunk_copy
		movlw	INCOMING_SYSEX_C
		addwf	OUTPUT_COUNTER,w
		addwf	OUTPUT_COUNTER,w
		addwf	OUTPUT_COUNTER,w
		addwf	OUTPUT_COUNTER,w
		movwf	FSR
		bsf		STATUS,IRP
		call	chunk_paste
isf_t1_copy_loop_ac_next
		incf	OUTPUT_COUNTER,f
		decfsz	COUNTER_H,f
		goto	isf_t1_copy_loop_ac
; last 8 pins: copy from buffer b to buffer c
		movlw	D'8'
		movwf	COUNTER_H
		clrf	OUTPUT_COUNTER
		bsf		STATUS,IRP
isf_t1_copy_loop_bc
		movlw	INCOMING_SYSEX_B
		addwf	OUTPUT_COUNTER,w
		addwf	OUTPUT_COUNTER,w
		addwf	OUTPUT_COUNTER,w
		addwf	OUTPUT_COUNTER,w
		movwf	FSR
		btfsc	INDF,6
		goto	isf_t1_copy_loop_bc_next
		call	chunk_copy
		movlw	INCOMING_SYSEX_C+D'32'
		addwf	OUTPUT_COUNTER,w
		addwf	OUTPUT_COUNTER,w
		addwf	OUTPUT_COUNTER,w
		addwf	OUTPUT_COUNTER,w
		movwf	FSR
		call	chunk_paste
isf_t1_copy_loop_bc_next
		incf	OUTPUT_COUNTER,f
		decfsz	COUNTER_H,f
		goto	isf_t1_copy_loop_bc

isf_type_1_layer_0_go
; set up addresses for write
		banksel	EEADRH
		movlw	0x1C
		movwf	EEADRH
		clrf	EEADR
		goto	isf_type_1_write
isf_type_1_layer_1
; set up addresses for write
		banksel	EEADRH
		movlw	0x1C
		movwf	EEADRH
		movlw	0xC0
		movwf	EEADR
		goto	isf_type_1_write
isf_type_1_layer_2
; set up addresses for write
		banksel	EEADRH
		movlw	0x1D
		movwf	EEADRH
		movlw	0x80
		movwf	EEADR
		goto	isf_type_1_write
isf_type_1_layer_3
; set up addresses for write
		banksel	EEADRH
		movlw	0x1E
		movwf	EEADRH
		movlw	0x40
		movwf	EEADR

isf_type_1_write
; write from incoming sysex buffer - block A
		movlw	INCOMING_SYSEX_A
		movwf	FSR
		bcf		STATUS,IRP
		call	write_program_eeprom
; write from incoming sysex buffer - block B
		movlw	INCOMING_SYSEX_B
		movwf	FSR
		bsf		STATUS,IRP
		call	write_program_eeprom
; write from incoming sysex buffer - block C
		movlw	INCOMING_SYSEX_C
		movwf	FSR
;		bsf		STATUS,IRP
		call	write_program_eeprom

; reboot!
		goto	isf_reboot


isf_reboot
; set the watchdog timer and wait for reset to happen.

		banksel	WDTCON
		movlw	B'00000001'
		movwf	WDTCON

isf_reboot_wait
		goto	isf_reboot_wait


; =================================
;
; Take a configuration chunk and move between the variables TEMP thru TEMP3
;
; =================================
chunk_copy
		movfw	INDF
		movwf	TEMP
		incf	FSR,f
		movfw	INDF
		movwf	TEMP2
		incf	FSR,f
		movfw	INDF
		movwf	TEMP3
		incf	FSR,f
		movfw	INDF
		movwf	TEMP4
		return
chunk_paste
		movfw	TEMP
		movwf	INDF
		incf	FSR,f
		movfw	TEMP2
		movwf	INDF
		incf	FSR,f
		movfw	TEMP3
		movwf	INDF
		incf	FSR,f
		movfw	TEMP4
		movwf	INDF
		return

; =================================
;
; Check stored sysex chunk for null data
; fill from eeprom if necessary
;
; OUTPUT_COUNTER: chunk number 0-47
; CONFIG_LAYER: layer number
; TEMP4: munged
;
; =================================
fill_sysex_chunk
; determine in which bank the chunk resides
		btfsc	STATE_FLAGS,6
		goto	fsc_bank_b_or_c
fsc_bank_a_or_b
		movfw	OUTPUT_COUNTER
		sublw	D'15'
		bc		fsc_bank_a
		goto	fsc_bank_b_tt0

fsc_bank_b_or_c
		movfw	OUTPUT_COUNTER
		sublw	D'7'
		bc		fsc_bank_b_tt1

fsc_bank_c
		bsf		STATUS,IRP
		movlw	D'8'
		subwf	OUTPUT_COUNTER,w
		movwf	TEMP4
		movlw	INCOMING_SYSEX_C
		goto	fsc_check
fsc_bank_b_tt0
		bsf		STATUS,IRP
		movlw	D'16'
		subwf	OUTPUT_COUNTER,w
		movwf	TEMP4
		movlw	INCOMING_SYSEX_B
		goto	fsc_check
fsc_bank_b_tt1
		bsf		STATUS,IRP
		movlw	D'8'
		addwf	OUTPUT_COUNTER,w
		movwf	TEMP4
		movlw	INCOMING_SYSEX_B
		goto	fsc_check
fsc_bank_a
		bcf		STATUS,IRP
		movfw	OUTPUT_COUNTER
		movwf	TEMP4
		movlw	INCOMING_SYSEX_A

fsc_check
		addwf	TEMP4,w
		addwf	TEMP4,w
		addwf	TEMP4,w
		addwf	TEMP4,w
		movwf	FSR
; if this chunk has incoming data already, skip it!
		btfss	INDF,7
		return

fsc_overwrite
; get old config and plug it in amongst the new chunks
		pagesel	read_pin_config
		call	read_pin_config
		pagesel	fsc_overwrite
; mm
		movfw	CONFIG_MODE
		movwf	INDF
; ch
		incf	FSR,f
		movfw	CONFIG_CHANNEL
		movwf	INDF
; d0
		incf	FSR,f
		movfw	CONFIG_D0
		movwf	INDF
; d1
		incf	FSR,f
		movfw	CONFIG_D1
		movwf	INDF

		return

; =================================
;
; write 64 words to program EEPROM
;
; input variables:
; EEADRH / EEADR : beginning program eeprom address
; FSR / STATUS,IRP : beginning source data RAM address
;
; Current memory bank is assumed to include EEDAT/EEADR
;
; =================================
write_program_eeprom
		movlw	D'64'
		movwf	TEMP4
		clrf	EEDATH
wpe_loop
; grab one byte of source data
		movfw	INDF
		movwf	EEDAT
; this should only matter for sysex type 07
		bcf		EEDAT,7
; write to EEPROM buffer
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
; next word
		banksel	EEADR
		incf	EEADR,f
		btfsc	STATUS,Z
		incf	EEADRH,f

		incf	FSR,f
		decfsz	TEMP4,f
		goto	wpe_loop

;		banksel	PORTA

		return

isf_flush
; flush the RX FIFO before exiting
		banksel	RCREG
		movfw	RCREG
		movfw	RCREG
		bcf		PIR1,5
		bcf		RCSTA,4
		bsf		RCSTA,4

isf_error
; exit cleanly
		banksel	PORTA
		pagesel	sysex_error
		goto	sysex_error


; =================================
;
; send sysex header
;
; =================================

send_sysex_header
		movlw	0xF0
		movwf	OUTBOUND_BYTE
		pagesel	send_midi_byte
		call	send_midi_byte
		movlw	0x00
		movwf	OUTBOUND_BYTE
;		pagesel	send_midi_byte
		call	send_midi_byte
		movlw	0x01
		movwf	OUTBOUND_BYTE
;		pagesel	send_midi_byte
		call	send_midi_byte
		movlw	0x5D
		movwf	OUTBOUND_BYTE
;		pagesel	send_midi_byte
		call	send_midi_byte
		movlw	0x04
		movwf	OUTBOUND_BYTE
;		pagesel	send_midi_byte
		call	send_midi_byte

		pagesel	send_sysex_header

		return


		end
