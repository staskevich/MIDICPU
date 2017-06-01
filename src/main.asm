; MIDI CPU
; copyright John Staskevich, 2017
; john@codeandcopper.com
;
; This work is licensed under a Creative Commons Attribution 4.0 International License.
; http://creativecommons.org/licenses/by/4.0/
;
; main.asm
;
; Boot sequence and main program loop.
;
		list		p=16f887
   		#include	<p16f887.inc>

;Configuration Bits

; no code/data protect, no BOR
;		__CONFIG _CONFIG1, 0x20E4
; no code/data protect, with BOR
;		__CONFIG _CONFIG1, 0x23E4
; with code/data protect, no BOR
;		__CONFIG _CONFIG1, 0x2024
; with code/data protect, with BOR
		__CONFIG _CONFIG1, 0x2324



; other stuff
		__CONFIG _CONFIG2, 0x02FF

   		#include	<mc.inc>

; ==================================================================
;
; External Functions
;
; ==================================================================

		EXTERN	inbound_sysex_finish
		EXTERN	main_init
		EXTERN	read_pin_config
		EXTERN	combine_channel_with_status
		EXTERN	load_d0_from_address
		EXTERN	load_d1_from_address
		EXTERN	send_midi_local
		EXTERN	read_logic_inputs
		EXTERN	read_matrices
		EXTERN	read_analog_inputs
		EXTERN	process_inbound_midi
		EXTERN	update_leds

; ==================================================================
;
; Global Functions
;
; ==================================================================

		GLOBAL	poll

; ==================================================================
; ==================================================================
; ==================================================================
;
; PROGRAM
;
; ==================================================================
; ==================================================================
; ==================================================================

reset	code	0x00
		goto	start


main	code	0x700
start
; ===================================
;
; Configure the clock
;
; ===================================

; Configure the internal clock
		banksel	OSCCON
		movlw	B'01110000'
		movwf	OSCCON
; Enable PORTB pull-ups (so there are no floating inputs)
		bcf		OPTION_REG,7

; configure ACT terminal for digital output
; turn on the ACT LED
		bcf		TRISA,6
		banksel	PORTA
;		bcf		PORTA,6
		clrf	PORTA

; check for firmware update state
		btfsc	PORTC,5
		goto	start_go_normal
;		btfsc	PORTC,4
;		goto	start_go_normal

; /////////////FIRMWARE UPDATE MODE

; init STATE_FLAGS
		movlw	B'00001000'
		movwf	STATE_FLAGS

; ===================================
;
; Configure the USART
;
; ===================================
; Set up the USART
		banksel	PIE1
; Enable receive interrupt
		bsf		PIE1,5
; Set up the baud rate generator
; 31.25kHz = 8MHz / (16 (15 + 1))
		movlw	0x0f
		movwf	SPBRG
; Set the transmit control bits
		movlw	B'00100110'
		movwf	TXSTA
		banksel PORTA
; Set the receive control bits
		movlw	B'10010000'
		movwf	RCSTA
		banksel	PORTA
; ===================================
;
; Enable global interrupts
;
; ===================================

; Enable global & peripheral interrupts
		movlw	B'11000000'
		movwf	INTCON

; do nothing while isr handles firmware update
start_wait_for_update
		goto	start_wait_for_update

start_go_normal
; checksum the firmware
		clrf	TEMP
		clrf	TEMP2
		banksel	EEADR
		clrf	EEADR
		clrf	EEADRH

; add all opcodes from 0x0000 to 0x1BFF
checksum_loop
		banksel	EECON1
		bsf		EECON1,EEPGD
		bsf		EECON1,RD
		nop
		nop
; sum into TEMP2,TEMP
		banksel	EEDAT
		movfw	EEDAT
		addwf	TEMP,f
		btfsc	STATUS,C
		incf	TEMP2,f
		movfw	EEDATH
		addwf	TEMP2,f
; increment program address
		incfsz	EEADR,f
		goto	checksum_loop
		incf	EEADRH,f
		movlw	0x1C
		subwf	EEADRH,w
		bnz		checksum_loop
; add in checksum from EEPROM and check for 0
		banksel	EEADR
		movlw	PROM_CHECKSUM
		movwf	EEADR
		banksel	EECON1
		bcf		EECON1,EEPGD
		bsf		EECON1,RD
		banksel	EEDAT
		movfw	EEDAT
		movwf	TEMP4
		incf	EEADR,f
		banksel	EECON1
		bsf		EECON1,RD
		banksel	EEDAT
		movfw	EEDAT
		movwf	TEMP3
; complement value is now in TEMP4,TEMP3
		movlw	0x01
		addwf	TEMP3,f
		btfsc	STATUS,C
		incf	TEMP4,f
		movfw	TEMP3
		addwf	TEMP,f
		btfsc	STATUS,C
		incf	TEMP4,f
		movfw	TEMP4
		addwf	TEMP2,f
; check for zero
		movfw	TEMP2
		bnz		checksum_error
		movfw	TEMP
		bnz		checksum_error

checksum_ok
; continue with init
		banksel	PORTA
		pagesel	start_normal
		goto	start_normal

checksum_error
; blink the activity LED and do nothing.
		banksel	PORTA
checksum_error_blink
; PORTA read-mod-write ok here
		bsf		PORTA,6
		clrf	COUNTER_L
		clrf	COUNTER_H
		decfsz	COUNTER_L,f
		goto	$-1
		decfsz	COUNTER_H,f
		goto	$-3

; PORTA read-mod-write ok here
		bcf		PORTA,6
		clrf	COUNTER_L
		clrf	COUNTER_H
		decfsz	COUNTER_L,f
		goto	$-1
		decfsz	COUNTER_H,f
		goto	$-3
		goto	checksum_error_blink

; Can't change this address--it's referenced from boot code!
main_normal	code	0x0E00
; main_normal	code
start_normal
; ==================================================================
;
; Device Initialization
;
; ==================================================================

		pagesel	main_init
		call	main_init
		pagesel	poll



; ==================================================================
;
; poll inputs while processing incoming MIDI data
;
; ==================================================================

poll
; always check to see if a MIDI CPU-specific SysEx message is being
; processed.  If so, don't bother to process any inputs.

; take a snapshot of layer flags and work from that.
		movfw	LAYER_FLAGS
		movwf	LAYER_FLAGS_SNAPSHOT

; check for global refresh request.
; if there is a request, set the "go flag"
		btfsc	STATE_FLAGS_2,5
		bsf	STATE_FLAGS_2,6

; catch up on any incoming midi data
		pagesel	process_inbound_midi
		call	process_inbound_midi
		pagesel	poll
; Update LED States
		pagesel	update_leds
		btfss	STATE_FLAGS,1
		call	update_leds
		pagesel	poll

; catch up on any incoming midi data
		pagesel	process_inbound_midi
		call	process_inbound_midi
		pagesel	poll
; process analog inputs
		btfss	STATE_FLAGS,1
		call	read_analog_inputs

; catch up on any incoming midi data
		pagesel	process_inbound_midi
		call	process_inbound_midi
		pagesel	poll
; process digital inputs
		btfss	STATE_FLAGS,1
		call	read_logic_inputs

; catch up on any incoming midi data
		pagesel	process_inbound_midi
		call	process_inbound_midi
		pagesel	poll
; process matrixed inputs
		btfss	STATE_FLAGS,1
		pagesel	read_matrices
		call	read_matrices
		pagesel	poll

; if a global refresh just happened, clear the flags.
		btfss	STATE_FLAGS_2,6
		goto	poll
		bcf	STATE_FLAGS_2,5
		bcf	STATE_FLAGS_2,6

		goto	poll

		end
