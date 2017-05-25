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
		EXTERN	poll

; ==================================================================
;
; Global Functions
;
; ==================================================================

		GLOBAL	update_leds


led_output	code	0x1B00
;read_matrix		code


; =================================
;
; check pins 0-7 for LED mode, update output as necessary
; tri-states are set during init, so just write data to the latches.
;
; =================================

update_leds
; are any terminals being used for LED "select" output?
; if not, exit
		banksel	LED_SELECT_FLAGS
		movfw	LED_SELECT_FLAGS
		bnz		update_leds_next_select
		bcf		STATUS,RP0
		return

; go to next select
update_leds_next_select

; rotate select marker, check for match
update_leds_rotate
		incf	LED_ACTIVE_SELNUM,f
		bcf		STATUS,C
		rlf		LED_ACTIVE_SELBIT,f
		btfss	STATUS,C
		goto	update_leds_rotate_check
		bsf		LED_ACTIVE_SELBIT,0
		movlw	D'8'
		movwf	LED_ACTIVE_SELNUM
; check if select terminal is in LED select mode
update_leds_rotate_check
		movfw	LED_SELECT_FLAGS
		andwf	LED_ACTIVE_SELBIT,w
		bz		update_leds_rotate

; update data
; grab the config for the new current select
		movfw	LED_ACTIVE_SELNUM
		movwf	OUTPUT_COUNTER
		pagesel	read_pin_config
		call	read_pin_config
		pagesel	update_leds

; load the raw data
		movfw	CONFIG_D1
		addlw	0x20
		movwf	FSR
		bcf		STATUS,IRP
		movfw	INDF
		movwf	TEMP
		movwf	TEMP3

; format the data according to D0
		movfw	CONFIG_D0
		andlw	B'00011100'
; bit indication?
		bz		update_leds_write
; bar graph?
		sublw	0x10
		bz		update_leds_bar_graph

; signed 7-segment?
		btfsc	CONFIG_D0,4
		goto	update_leds_7seg_signed

; unsigned 7-segment.
; Store digit in TEMP3
update_leds_7seg_unsigned
; get the hundreds, then tens, then ones
		clrf	TEMP3
		movlw	D'100'
		subwf	TEMP,f
		bnc		update_leds_7seg_un_add100
		incf	TEMP3,f
;		movlw	D'100'
		subwf	TEMP,f
		bnc		update_leds_7seg_un_add100
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
		pageselw	update_leds_7seg_table
		movfw	TEMP3
		call	update_leds_7seg_table
		movwf	TEMP3
		goto	update_leds_write

update_leds_7seg_signed
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
		goto	update_leds_write

update_leds_bar_graph
		movlw	B'00000001'
		movwf	TEMP3
		movlw	D'16'
update_leds_bar_graph_loop
		subwf	TEMP,f
		btfss	STATUS,C
		goto	update_leds_bar_graph_end
		rlf		TEMP3,f
		goto	update_leds_bar_graph_loop
update_leds_bar_graph_end
		movfw	TEMP3
;		movwf	TEMP
		goto	update_leds_write

update_leds_write
; turn off all selects for a moment
		bsf		STATUS,RP0
		movlw	B'11111111'
		movwf	TRISB
; write the data, account for common anode/cathode
		movfw	TEMP3
		btfss	CONFIG_D0,1
		comf	TEMP3,w
		bcf		STATUS,RP0
		movwf	PORTD
; activate appropriate select
		bsf		STATUS,RP0
		comf	LED_ACTIVE_SELBIT,w
		movwf	TRISB
		
		bcf		STATUS,RP0
		pageselw	poll
		return

; ==================================================================
;
; call to get 7seg representation of an integer 0-9
;
; ==================================================================

update_leds_7seg_table
		addwf	PCL,F
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

		end
