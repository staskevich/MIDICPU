; MIDI CPU
; copyright John Staskevich, 2017
; john@codeandcopper.com
;
; This work is licensed under a Creative Commons Attribution 4.0 International License.
; http://creativecommons.org/licenses/by/4.0/
;
; readmatrix.asm
;
; Read switch matrices.
;
		list		p=16f887
   		#include	<p16f887.inc>

   		#include	<mc.inc>

; ==================================================================
;
; External Functions
;
; ==================================================================

		EXTERN	process_inbound_midi
		EXTERN	read_pin_config
		EXTERN	combine_channel_with_status
		EXTERN	load_d0_from_address
		EXTERN	load_d1_from_address
		EXTERN	send_midi_local

; ==================================================================
;
; Global Functions
;
; ==================================================================

		GLOBAL	read_matrices


read_matrix		code	0x0D00
;read_matrix		code


; =================================
;
; read input switch matrices
;
; =================================

read_matrices
; no interference yet
		bcf		STATE_FLAGS,2
; use tt=0 configs
		bcf		STATE_FLAGS,6
		clrf	CONFIG_LAYER
; skip terminals 0-7 if there is any LED control going on
		banksel	LED_DATA_FLAGS
		movfw	LED_DATA_FLAGS
		banksel	PORTA
		btfss	STATUS,Z
		goto	read_matrices_skip_a

; Control Terminals 0-7
		clrf	OUTPUT_COUNTER
		movlw	0x08
		movwf	COUNTER_H
		movlw	B'00000001'
		movwf	BITMASK
		movlw	TRISD
		movwf	TEMP_REG
read_matrices_a
		call	send_select_pin
; bail out if relevant sysex message comes in.
		btfsc	STATE_FLAGS,2
		return
		bcf		STATUS,C
		rlf		BITMASK,f
		incf	OUTPUT_COUNTER,f
		decfsz	COUNTER_H,f
		goto	read_matrices_a

read_matrices_skip_a

; Control Terminals 8-15
		movlw	0x08
		movwf	COUNTER_H
		movwf	OUTPUT_COUNTER
		movlw	B'00000001'
		movwf	BITMASK
		movlw	TRISB
		movwf	TEMP_REG
read_matrices_b
		call	send_select_pin
; bail out if relevant sysex message comes in.
		btfsc	STATE_FLAGS,2
		return
		bcf		STATUS,C
		rlf		BITMASK,f
		incf	OUTPUT_COUNTER,f
		decfsz	COUNTER_H,f
		goto	read_matrices_b

; Control Terminals 16-18
		movlw	0x03
		movwf	COUNTER_H
		movlw	B'00000001'
		movwf	BITMASK
		movlw	TRISA
		movwf	TEMP_REG
read_matrices_c
; special check for pin 18
; if external vref is connected, don't send a pulse!
		movlw	0x12
		subwf	OUTPUT_COUNTER,w
		bnz		read_matrices_c_send
		btfsc	STATE_FLAGS,5
		goto	read_matrices_c_skip
read_matrices_c_send
;		movlw	B'11000000'
;		andwf	PORTA,f
		call	send_select_pin
; bail out if relevant sysex message comes in.
		btfsc	STATE_FLAGS,2
		return
read_matrices_c_skip
		bcf		STATUS,C
		rlf		BITMASK,f
		incf	OUTPUT_COUNTER,f
		decfsz	COUNTER_H,f
		goto	read_matrices_c

; * Control Terminal 19 is input only.
		incf	OUTPUT_COUNTER,f

; Control Terminal 20
		movlw	B'00100000'
		movwf	BITMASK
		movlw	TRISA
		movwf	TEMP_REG
		call	send_select_pin
; bail out if relevant sysex message comes in.
		btfsc	STATE_FLAGS,2
		return
		incf	OUTPUT_COUNTER,f

; Control Terminals 21-23
		movlw	0x03
		movwf	COUNTER_H
		movlw	B'00000001'
		movwf	BITMASK
		movlw	TRISE
		movwf	TEMP_REG
read_matrices_d
		call	send_select_pin
; bail out if relevant sysex message comes in.
		btfsc	STATE_FLAGS,2
		return
		bcf		STATUS,C
		rlf		BITMASK,f
		incf	OUTPUT_COUNTER,f
		decfsz	COUNTER_H,f
		goto	read_matrices_d

		return

; =================================
;
; for pin specified by TEMP_REG and BITMASK,
; check the config, then send a select pulse, read data,
; and generate MIDI messages as necessary.
;
; =================================

send_select_pin
; get the config
		call	read_pin_config
; check for a select output mode
		movlw	0x2C
		subwf	CONFIG_MODE,w
		btfss	STATUS,C
		goto	ssp_finish
		movfw	CONFIG_MODE
		sublw	0x3F
		btfss	STATUS,C
		goto	ssp_finish
; activate the select pulse
		bcf		STATUS,IRP
		movfw	TEMP_REG
		movwf	FSR
		comf	BITMASK,w
		andwf	INDF,f
; read the data
		btfsc	CONFIG_MODE,1
		goto	send_select_read_reg2
		btfsc	CONFIG_MODE,0
		goto	send_select_read_reg1
send_select_read_reg0
		movfw	PORTD
		movwf	TEMP
		goto	send_select_end_pulse
send_select_read_reg1
		movfw	PORTB
		movwf	TEMP
		goto	send_select_end_pulse
send_select_read_reg2
		movfw	PORTA
		movwf	TEMP2
		andlw	B'00001111'
		movwf	TEMP
		btfsc	TEMP2,5
		bsf		TEMP,4
		swapf	PORTE,w
		movwf	TEMP2
		rlf		TEMP2,w
		andlw	B'11100000'
		iorwf	TEMP,f
; clear the select pulse
send_select_end_pulse
		movfw	BITMASK
		iorwf	INDF,f
; apply a bitmask according to config
send_select_apply_datamask
		movlw	PROM_DATAMASKS
		addwf	CONFIG_D1,w
; read bitmask from eeprom and apply to data
		banksel	EEADR
		movwf	EEADR
		banksel	EECON1
		bcf		EECON1,EEPGD
		bsf		EECON1,RD
		banksel	EEDAT
		movfw	EEDAT
		banksel	PORTA
		iorwf	TEMP,f
; compare data to previously recorded state, send messages if necessary
; TEMP = new key states
; TEMP2 = new key states
; TEMP3 = change flags
; TEMP4 = new toggle states
		movfw	TEMP
		movwf	TEMP2
		bcf		STATUS,IRP
		movlw	KEYS_0
		addwf	OUTPUT_COUNTER,w
		movwf	FSR
		movfw	INDF
		xorwf	TEMP,w
		movwf	TEMP3
; store data for activity check next cycle
		movfw	TEMP
		movwf	INDF
; update the toggles...watch closely!
		bsf		STATUS,IRP
		movlw	KEY_TOGGLES
		addwf	OUTPUT_COUNTER,w
		movwf	FSR
		comf	TEMP,w
		andwf	TEMP3,w
; w now contains bits which should be toggled
		xorwf	INDF,f
		movfw	INDF
		movwf	TEMP4
; check mode & trigger events
ssp_check_note
		movfw	CONFIG_MODE
		sublw	0x33
		btfss	STATUS,C
		goto	ssp_check_cc
; D0: note # is determined by matrix setup.
; STATUS
		movlw	0x90
		movwf	LOCAL_STATUS
; D1: grab Velocity "on" value
		banksel	MATRIX_VELOCITY
		movfw	MATRIX_VELOCITY
		banksel	PORTA
		movwf	TEMP5
; D1: Velocity "off" value is 0
		clrf	TEMP6
		goto	ssp_process_bits
ssp_check_cc
		movfw	CONFIG_MODE
		sublw	0x3B
		btfss	STATUS,C
		goto	ssp_check_program_change
; D0: CC # is determined by matrix setup.
; STATUS
		movlw	0xB0
		movwf	LOCAL_STATUS
; D1: grab CC "on" value
		banksel	CC_ON_VALUE
		movfw	CC_ON_VALUE
		banksel	PORTA
		movwf	TEMP5
; D1: grab CC "off" value
		banksel	CC_OFF_VALUE
		movfw	CC_OFF_VALUE
		banksel	PORTA
		movwf	TEMP6
		goto	ssp_process_bits
ssp_check_program_change
; assume program change
; D0: program number is determined by matrix.
; D1: isn't used for program change.
; STATUS
		movlw	0xC0
		movwf	LOCAL_STATUS

ssp_process_bits
		call	combine_channel_with_status
		movfw	CONFIG_D0
;		movwf	LOCAL_D0
		movwf	TEMP7
		movlw	D'8'
		movwf	COUNTER_L

ssp_loop

; check for changed keystate
		btfss	TEMP3,0
		goto	ssp_loop_next
; check for toggle mode
		btfss	CONFIG_MODE,2
		goto	ssp_loop_toggle
ssp_loop_regular
; regular mode...set up the note velocity / CC value
		btfss	TEMP2,0
		goto	ssp_loop_on
ssp_loop_off
; program change?  ignore the "off" state change.
		comf	CONFIG_MODE,w
		andlw	B'00111100'
		bz		ssp_loop_next
		movfw	TEMP6
		movwf	LOCAL_D1
		goto	ssp_loop_send_message
ssp_loop_on
		movfw	TEMP5
		movwf	LOCAL_D1
		goto	ssp_loop_send_message

ssp_loop_toggle
; toggle mode...first check if keystate is "on" (0)
; do nothing on release
		btfsc	TEMP2,0
		goto	ssp_loop_next
; key is has just been depressed.  Use toggle state to choose on or off
		btfss	TEMP4,0
		goto	ssp_loop_on
		goto	ssp_loop_off

ssp_loop_send_message
		movfw	TEMP7
		movwf	LOCAL_D0
		call	send_midi_local

ssp_loop_next
		pagesel	process_inbound_midi
		call	process_inbound_midi
		pagesel	read_matrices
; bail out if relevant sysex message comes in.
		btfsc	STATE_FLAGS,2
		return
		rrf		TEMP2,f
		rrf		TEMP3,f
		rrf		TEMP4,f
		incf	TEMP7,f
		decfsz	COUNTER_L,f
		goto	ssp_loop

ssp_finish
		pagesel	process_inbound_midi
		call	process_inbound_midi
		pagesel	read_matrices
		return

		end
