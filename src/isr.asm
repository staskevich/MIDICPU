; MIDI CPU
; copyright John Staskevich, 2017
; john@codeandcopper.com
;
; This work is licensed under a Creative Commons Attribution 4.0 International License.
; http://creativecommons.org/licenses/by/4.0/
;
; isr.asm
;
; Interrupt service routines.
;
		list		p=16f887
   		#include	<p16f887.inc>
   		#include	<mc.inc>

		global	isr

		EXTERN	fupdate_isr

xisr	code	0x0004
isr
; Store the context
		movwf 	W_STORAGE
		swapf	STATUS,w
		clrf	STATUS
		movwf	STATUS_STORAGE
		movfw	FSR
		movwf	FSR_STORAGE
		movfw	PCLATH
		movwf	PCLATH_STORAGE

; check for firmware update mode
		btfsc	STATE_FLAGS,3
		goto	fupdate_isr
		pagesel	isr_normal
		goto	isr_normal

xisr_normal	code	0x0E40
;xisr_normal	code
isr_normal

		btfsc	INTCON,2
		goto	handle_timer_0

		btfsc	PIR1,5
		goto	handle_rx

		btfsc	PIR1,0
		goto	handle_timer_1

		btfsc	PIR1,1
		goto	handle_timer_2


; Should not execute.

;		bcf		PORTA,6
;		goto	$-1

		goto	isr_finish


; =================================
;
; Return from the ISR
;
; =================================

isr_finish
		movfw	PCLATH_STORAGE
		movwf	PCLATH
		movfw	FSR_STORAGE
		movwf	FSR
		swapf	STATUS_STORAGE,w
		movwf	STATUS
		swapf	W_STORAGE,f
		swapf	W_STORAGE,w
		retfie

; =================================
;
; Handle timer 0 expiry
;
; =================================

handle_timer_0
		bcf	INTCON,T0IF

t0_refresh_leds
; any led select outputs to refresh?
;		bsf	STATUS,RP0
;		movfw	LED_SELECT_FLAGS
;		bcf	STATUS,RP0
;		btfsc	STATUS,Z
;		goto	isr_finish

		btfss	STATE_FLAGS_2,7
		goto	isr_finish

t0_refresh_leds_loop
		bcf	STATUS,C
		rlf	LED_REFRESH_BIT,f
		incf	LED_REFRESH_NUM,f
		btfss	LED_REFRESH_NUM,3
		goto	t0_refresh_leds_loop_check
		clrf	LED_REFRESH_NUM
		movlw	B'00000001'
		movwf	LED_REFRESH_BIT
t0_refresh_leds_loop_check
		bsf	STATUS,RP0
		movfw	LED_SELECT_FLAGS
		bcf	STATUS,RP0
		andwf	LED_REFRESH_BIT,w
		bz	t0_refresh_leds_loop

t0_refresh_leds_set_up_data
; set up the data
		movfw	LED_REFRESH_NUM
		addlw	LED_DATA_0
		movwf	FSR
		bcf	STATUS,IRP
; turn off all selects for a moment
		bsf	STATUS,RP0
		movlw	B'11111111'
		movwf	TRISB
		bcf	STATUS,RP0
; write the data, account for common anode/cathode
		movfw	INDF
		movwf	PORTD
; activate appropriate select
		comf	LED_REFRESH_BIT,w
		bsf	STATUS,RP0
		movwf	TRISB
		bcf	STATUS,RP0

		goto	isr_finish


; =================================
;
; Handle timer 1 expiry
;
; =================================

handle_timer_1
; disable timer 1 interrupt
		banksel	PIE1
		bcf		PIE1,0
; clear timer 1 interrupt flag
		banksel	PIR1
		bcf		PIR1,0
; clear the activity LED
;		bsf		PORTA,6
		movlw	B'01000000'
		movwf	PORTA
		goto	isr_finish

; =================================
;
; Handle timer 2 expiry
;
; =================================

handle_timer_2
		bcf		PIR1,1
		bsf		STATUS,RP0
		decfsz	T2_COUNTER,f
		goto	handle_t2_finish
send_midi_as
; reset the active sense counter
		movlw	T2_SCALE
		movwf	T2_COUNTER
; reset the running status
		bcf		STATUS,RP0
		clrf	OUTBOUND_STATUS
		btfss	STATE_FLAGS_2,0
		goto	handle_t2_finish
; wait for uart ready
		btfss	PIR1,4
		goto	$-1
; load data
		movlw	0xFE
		movwf	TXREG

		nop
		goto	isr_finish

; ??? should wipe out incomplete incoming message only after two as messages?
; wipe out any incomplete message that may have been received
; actually this doesn't seem necessary.  any incomplete message will be
; wiped out when a new status byte comes in...
;		bcf		STATE_FLAGS,0
;		clrf	INBOUND_BYTECOUNT

handle_t2_finish
		bcf		STATUS,RP0
		goto	isr_finish

; =================================
;
; Handle MIDI RX
;
; =================================

handle_rx
; Clear the Rx interrupt flag
;		bcf	PIR1,5
; Discard if the buffer is full
		movlw	RX_BUFFER_SIZE
		subwf	RX_BUFFER_GAUGE,w
		bnz		handle_rx_store_byte
		goto	handle_rx_overflow

handle_rx_store_byte
; Store the receive byte in the FIFO
; IRP is set to zero in the context switch code
		bsf		STATUS,IRP
		movlw	RX_BUFFER
		addwf	RX_BUFFER_TAIL,w
		movwf	FSR
		incf	RX_BUFFER_TAIL,f
		movlw	RX_POINTER_MASK
		andwf	RX_BUFFER_TAIL,f
		incf	RX_BUFFER_GAUGE,f
		movfw	RCREG
		movwf	INDF
		goto	isr_finish

handle_rx_overflow
; infinite loop
;		bcf		PORTA,6
		clrf	PORTA
		goto	$-1


; Discard the byte.
; Should probably shut down here as well.
		movfw	RCREG
		goto	isr_finish




		end
