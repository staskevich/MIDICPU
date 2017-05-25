; MIDI CPU
; copyright John Staskevich, 2017
; john@codeandcopper.com
;
; This work is licensed under a Creative Commons Attribution 4.0 International License.
; http://creativecommons.org/licenses/by/4.0/
;
; txutils.asm
;
; Send MIDI messages.
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

; ==================================================================
;
; Global Functions
;
; ==================================================================

		GLOBAL	send_midi_byte
		GLOBAL	send_midi_local


txutils		code	0x0F58
;txutils		code


; =================================
;
; send locally generated MIDI message
;
; =================================

send_midi_local
; wrap LOCAL_D0 and LOCAL_D1 above 127
		movfw	LOCAL_D0
		andlw	B'01111111'
		movwf	LOCAL_D0
		movfw	LOCAL_D1
		andlw	B'01111111'
		movwf	LOCAL_D1

; suspend T2 interrupts
;		banksel	PIE1
;		bcf		PIE1,1
;		banksel	PORTA
; reset midi active sense timer
;		movlw	T2_SCALE
;		movwf	T2_COUNTER
; send status byte if necessary
; treat SysEx separately
		movlw	0xF0
		subwf	LOCAL_STATUS,w
		bz		send_midi_local_sysex
		movfw	OUTBOUND_STATUS
		subwf	LOCAL_STATUS,w
		bz		send_midi_local_data
send_midi_local_status
		movfw	LOCAL_STATUS
		movwf	OUTBOUND_STATUS
		movwf	OUTBOUND_BYTE
		call	send_midi_byte

send_midi_local_data
; remap d0 if necessary
		movfw	LOCAL_STATUS
		andlw	B'11110000'
		sublw	0x90
		bz		send_midi_local_transpose_note

		movfw	LOCAL_STATUS
		andlw	B'11110000'
		sublw	0x80
		bz		send_midi_local_transpose_note

		movfw	LOCAL_STATUS
		andlw	B'11110000'
		sublw	0xA0
		bz		send_midi_local_transpose_note

		movfw	LOCAL_STATUS
		andlw	B'11110000'
		sublw	0xB0
		bz		send_midi_local_remap_cc

		movfw	LOCAL_STATUS
		andlw	B'11110000'
		sublw	0xC0
		bnz		send_midi_local_skip_remap

send_midi_local_remap_program
		btfss	STATE_FLAGS_2,3
		goto	send_midi_local_skip_remap
		goto	send_midi_local_d0_remap
send_midi_local_remap_cc
		btfss	STATE_FLAGS_2,2
		goto	send_midi_local_skip_remap
		goto	send_midi_local_d0_remap
send_midi_local_transpose_note
; perform transposition before remap
		btfss	STATE_FLAGS_2,4
		goto	send_midi_local_remap_note
		movfw	TRANSPOSE_REG
		movwf	FSR
		bcf		STATUS,IRP
		movfw	INDF
		addwf	LOCAL_D0,f
		movlw	D'64'
		subwf	LOCAL_D0,f
		bcf		LOCAL_D0,7

send_midi_local_remap_note
		btfss	STATE_FLAGS_2,1
		goto	send_midi_local_skip_remap

send_midi_local_d0_remap
		movfw	LOCAL_D0
		addlw	PROM_NOTE_MAP
;		banksel	EEADR
		bsf		STATUS,RP1
		movwf	EEADR
;		banksel	EECON1
		bsf		STATUS,RP0
		bcf		EECON1,EEPGD
		bsf		EECON1,RD
;		banksel	EEDAT
		bcf		STATUS,RP0
		movfw	EEDAT
;		banksel	PORTA
		bcf		STATUS,RP1
		movwf	LOCAL_D0
send_midi_local_skip_remap
; send first data byte
		movfw	LOCAL_D0
;		andlw	B'01111111'
		movwf	OUTBOUND_BYTE
		call	send_midi_byte
; send second data byte if necessary
; program change
		movfw	LOCAL_STATUS
		andlw	B'11110000'
		sublw	0xC0
		bz		send_midi_local_done
; pitch wheel
		movfw	LOCAL_STATUS
		andlw	B'11110000'
		sublw	0xD0
		bz		send_midi_local_done
; everything else has two data bytes
		movfw	LOCAL_D1
;		andlw	B'01111111'
		movwf	OUTBOUND_BYTE
		call	send_midi_byte
		goto	send_midi_local_done

send_midi_local_sysex
; don't save the outbound status so that inbound sysex don't accidentally get merged.
		clrf	OUTBOUND_STATUS
; header status
		movfw	LOCAL_STATUS
		movwf	OUTBOUND_BYTE
		call	send_midi_byte

		movfw	LOCAL_D0
;		andlw	B'01111111'
;		banksel	EEADR
		bsf		STATUS,RP1
		movwf	EEADR
		movlw	0x1F
		movwf	EEADRH
;		banksel	PORTA
		bcf		STATUS,RP1

		movfw	LOCAL_D1
;		andlw	B'01111111'
		movwf	COUNTER_L
; body data
send_midi_local_sysex_loop
;		banksel	EECON1
		bsf		STATUS,RP1
		bsf		STATUS,RP0
		bsf		EECON1,EEPGD
		bsf		EECON1,RD
		nop
		nop
;		banksel	EEDAT
		bcf		STATUS,RP0
		movfw	EEDAT
;		banksel	PORTA
		bcf		STATUS,RP1
		movwf	OUTBOUND_BYTE
		call	send_midi_byte
;		banksel	EEADR
		bsf		STATUS,RP1
		incf	EEADR,f
;		banksel	PORTA
		bcf		STATUS,RP1
		decfsz	COUNTER_L,f
		goto	send_midi_local_sysex_loop
; footer status
		movlw	0xF7
;		movwf	OUTBOUND_STATUS
		movwf	OUTBOUND_BYTE
		call	send_midi_byte

send_midi_local_done
; merge if necessary.
		pagesel	process_inbound_midi
		call	process_inbound_midi
		pagesel	send_midi_local_done
; resume T2 interrupts
;		banksel	PIE1
;		bsf		PIE1,1
;		banksel	PORTA

		return

; =================================
;
; send a MIDI byte
;
; =================================

send_midi_byte
; reset the active sense counter
		movlw	T2_SCALE
		bsf		STATUS,RP0
		movwf	T2_COUNTER
		bcf		STATUS,RP0
		nop
; wait for uart ready
		btfss	PIR1,4
		goto	$-1
; load data
		movfw	OUTBOUND_BYTE
		movwf	TXREG

		nop
; blink the activity LED

activity_blink
; set activity led & kick off timer 1
; temporarily disable timer 1
;		banksel	PIE1
		bsf		STATUS,RP0
		bcf		PIE1,TMR1IE
;		banksel	PORTA
		bcf		STATUS,RP0
; reset counters & flag
		clrf	TMR1H
		clrf	TMR1L
		bcf		PIR1,0
; light activity LED
;		bcf		PORTA,6
		clrf	PORTA
; arm timer 1
;		banksel	PIE1
		bsf		STATUS,RP0
		bsf		PIE1,TMR1IE
;		banksel	PORTA
		bcf		STATUS,RP0

		return


		end
