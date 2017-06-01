; MIDI CPU
; copyright John Staskevich, 2017
; john@codeandcopper.com
;
; This work is licensed under a Creative Commons Attribution 4.0 International License.
; http://creativecommons.org/licenses/by/4.0/
;
; update_leds.asm
;
; Manipulate states of LEDs connected to pins.
;
		list		p=16f887
   		#include	<p16f887.inc>

   		#include	<mc.inc>

; ==================================================================
;
; External Functions
;
; ==================================================================

		EXTERN	read_pin_config
		EXTERN	process_inbound_midi

; ==================================================================
;
; Global Functions
;
; ==================================================================

		GLOBAL	update_leds
;		GLOBAL	refresh_leds


led_output	code	0x1B00

; ==================================================================
;
; call to get 7seg representation of an integer 0-9
;
; ==================================================================

update_leds_7seg_table
		andlw	0x0F
		addwf	PCL,F
; 0
		retlw	0x3F
		retlw	0x06
		retlw	0x5B
		retlw	0x4F
		retlw	0x66
		retlw	0x6D
		retlw	0x7D
		retlw	0x07
		retlw	0x7F
		retlw	0x6F
; A
		retlw	B'01110111'
		retlw	B'01111100'
		retlw	B'00111001'
		retlw	B'01011110'
		retlw	B'01111001'
		retlw	B'01110001'

; =================================
;
; check pins 0-7 for LED mode, update led data regs as necessary
; actual outputs will be refreshed elsewhere.
;
; =================================

update_leds
		banksel	LED_SELECT_FLAGS
		movfw	LED_SELECT_FLAGS
		bcf	STATUS,RP0
		movwf	TEMP2

		movlw	B'00000001'
		movwf	BITMASK
		movlw	0x08
		movwf	OUTPUT_COUNTER
;		clrf	CONFIG_LAYER
		bcf	STATUS,IRP

update_led_common
; check for setup as LED common output
		movfw	BITMASK
		andwf	TEMP2,w
		bz	update_led_next_common	
; grab the config.
		movlw	0x03
		movwf	CONFIG_LAYER
		movlw	B'00001000'
		movwf	LAYER_BITMASK
update_led_common_layer_loop
		pagesel	read_pin_config
		call	read_pin_config
		pagesel	update_leds
; layer zero?  if we are here, always use this config.
		movfw	CONFIG_LAYER
		bz	update_led_get_data
; layer active?  if not, go to next layer
		movfw	LAYER_BITMASK
		andwf	LAYER_FLAGS_SNAPSHOT,w
		bz	update_led_common_next_layer
; mode 2Ah?  if so, proceed.
		movfw	CONFIG_MODE
		sublw	0x2A
		bz	update_led_get_data
update_led_common_next_layer
		bcf	STATUS,C
		rrf	LAYER_BITMASK,f
		decf	CONFIG_LAYER,f
		goto	update_led_common_layer_loop
update_led_get_data
		movfw	CONFIG_D1
		sublw	INDIRECT_ADDRESS
		bnz	update_led_get_data_direct
update_led_get_data_indirect
		movfw	INDIRECT_POINTER
		goto	update_led_get_data_offset
update_led_get_data_direct
		movfw	CONFIG_D1
update_led_get_data_offset
		addlw	0x20
		movwf	FSR
		movfw	INDF
		movwf	TEMP
		movwf	TEMP3

; get the code page right
		pageselw	update_leds
; assume 7-segment and set the decimal point flag if necessary.
		clrf	TEMP5
		btfsc	TEMP,7
		bsf	TEMP5,0
		
; format the data according to D0
		movfw	CONFIG_D0
		andlw	B'01111100'
		movwf	TEMP4
; bit indication?
		bz	update_leds_write
; unsigned 7-segment from 0?
		movlw	0x10
		subwf	TEMP4,w
		bnc	update_leds_7seg_unsigned_from_0
; bar graph?
		movlw	0x14
		subwf	TEMP4,w
		bnc	update_leds_bar_graph
; signed 7-segment?
		movlw	0x20
		subwf	TEMP4,w
		bnc	update_leds_7seg_signed
; 3-bit indication
		movlw	0x24
		subwf	TEMP4,w
		bnc	update_leds_3bit_indication
; unsigned 7-segment from 1?
		movlw	0x30
		subwf	TEMP4,w
		bnc	update_leds_7seg_unsigned_from_1
; unsigned 7-segment hex?
		movlw	0x38
		subwf	TEMP4,w
		bnc	update_leds_7seg_unsigned_hex
; unrecognized format.
		goto	update_leds_write

update_leds_3bit_indication
		movlw	B'00000111'
		andwf	TEMP,f
		incf	TEMP,f
		clrf	TEMP3
		bsf	STATUS,C
update_leds_3bit_loop
		rlf	TEMP3,f
		decfsz	TEMP,f
		goto	update_leds_3bit_loop
		goto	update_leds_write

update_leds_7seg_unsigned_hex
; clear decimal point flag bit since it has nothing to do with the number value
		bcf	TEMP,7
; assume ones column
		movfw	TEMP
; check for 16s column
		btfss	CONFIG_D0,2
		swapf	TEMP,w
; mask out the 4 highest bits
		andlw	B'00001111'
		call	update_leds_7seg_table
		movwf	TEMP3
; set decimal point if flagged
		btfsc	TEMP5,0
		bsf	TEMP3,7
		goto	update_leds_write

update_leds_7seg_unsigned_from_1
; clear decimal point flag bit since it has nothing to do with the number value
		bcf	TEMP,7
; unsigned 7-segment from 1.  Add 1 to register value and hand off to "from 0"
		incf	TEMP,f
		goto	update_leds_7seg_un_f0_noflag

; unsigned 7-segment from 0.
; Store digit in TEMP3
update_leds_7seg_unsigned_from_0
; clear decimal point flag bit since it has nothing to do with the number value
		bcf	TEMP,7
update_leds_7seg_un_f0_noflag
; get the hundreds, then tens, then ones
		clrf	TEMP3
		movlw	D'100'
		subwf	TEMP,f
		bnc	update_leds_7seg_un_add100
		incf	TEMP3,f
;		movlw	D'100'
		subwf	TEMP,f
		bnc	update_leds_7seg_un_add100
		incf	TEMP3,f
		goto	update_leds_7seg_un_noadd100

update_leds_7seg_un_add100
; add the 100 back in
		movlw	D'100'
		addwf	TEMP,f
update_leds_7seg_un_noadd100
; first, is this the digit we need?
		btfss	CONFIG_D0,3
		goto	update_leds_7seg_un_map

update_leds_7seg_un_tens
		clrf	TEMP3
		movlw	D'10'
update_leds_7seg_un_tens_loop
		subwf	TEMP,f
		bnc		update_leds_7seg_un_add10
		incf	TEMP3,f
		goto	update_leds_7seg_un_tens_loop

update_leds_7seg_un_add10
; first, is this the digit we need?
		btfss	CONFIG_D0,2
		goto	update_leds_7seg_un_map
; add the 10 back in
		movfw	TEMP
		addlw	D'10'
		movwf	TEMP3

update_leds_7seg_un_map
; use the decimal digit to get output state
		movfw	TEMP3
		call	update_leds_7seg_table
		movwf	TEMP3
; set decimal point if flagged
		btfsc	TEMP5,0
		bsf	TEMP3,7
		goto	update_leds_write

update_leds_7seg_signed
; clear decimal point flag bit since it has nothing to do with the number value
		bcf	TEMP,7
; are we looking for the sign column?
		btfss	CONFIG_D0,3
		goto	update_leds_7seg_sign
; check for negative value
		btfss	TEMP,6
		goto	update_leds_7seg_signed_neg
; subtract 0x40
		movlw	0x40
		subwf	TEMP,f
		goto	update_leds_7seg_un_tens

update_leds_7seg_signed_neg
;		goto	update_leds_write
; perform 2s complement, merge into unsigned code
		comf	TEMP,f
		incf	TEMP,w
		andlw	B'00111111'
		movwf	TEMP
		btfsc	STATUS,Z
		bsf		TEMP,6
		goto	update_leds_7seg_un_tens

update_leds_7seg_sign
; add minus sign for negative numbers, blank otherwise
		movlw	0x40
		btfsc	TEMP,6
		movlw	0x00
		movwf	TEMP3
; set decimal point if flagged
		btfsc	TEMP5,0
		bsf	TEMP3,7
		goto	update_leds_write

update_leds_bar_graph
		movlw	B'00000001'
		movwf	TEMP3
		movlw	D'16'
update_leds_bar_graph_loop
		subwf	TEMP,f
		btfss	STATUS,C
		goto	update_leds_write
		rlf		TEMP3,f
		goto	update_leds_bar_graph_loop

update_leds_write
; write the data to the LED data regsiter.  actual refresh elsewhere.
		movlw	LED_DATA_0 - 0x08
		addwf	OUTPUT_COUNTER,w
		movwf	FSR
; account for common anode/cathode
		movfw	TEMP3
		btfss	CONFIG_D0,1
		comf	TEMP3,w
		movwf	INDF

update_led_next_common
; catch up on incoming MIDI
		pagesel	process_inbound_midi
		call	process_inbound_midi
		pagesel	update_leds

		bcf	STATUS,C
		rlf	BITMASK,f
		incf	OUTPUT_COUNTER,f
		btfss	OUTPUT_COUNTER,4
		goto	update_led_common


		return


		end
