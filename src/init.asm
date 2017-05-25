; MIDI CPU
; copyright John Staskevich, 2017
; john@codeandcopper.com
;
; This work is licensed under a Creative Commons Attribution 4.0 International License.
; http://creativecommons.org/licenses/by/4.0/
;
; init.asm
;
; Boot-time initialization.
;
		list		p=16f887
   		#include	<p16f887.inc>
   		#include	<mc.inc>

; ==================================================================
;
; External/Global Functions
;
; ==================================================================

		EXTERN	read_pin_config
		GLOBAL	main_init

go_init		code	0x1600

main_init

; ===================================
;
; State flag init
;
; ===================================

		movlw	B'00000000'
		movwf	STATE_FLAGS
		movwf	STATE_FLAGS_2

; ===================================
;
; Configure the clock
;
; ===================================

; Configure the internal clock
;		banksel	OSCCON
;		movlw	B'01110000'
;		movwf	OSCCON

; ===================================
;
; Configure the timers
;
; ===================================

; Configure Timer0 and turn on PORTB pull-ups
;		banksel	OPTION_REG
		bsf		STATUS,RP0
		movlw	B'00000111'
		movwf	OPTION_REG

; Configure Timer 1
;		banksel	T1CON
		bcf		STATUS,RP0
		movlw	B'00000101'
		movwf	T1CON

; Configure Timer 2
;		banksel	T2CON
		movlw	B'01111011'
		movwf	T2CON

; ===================================
;
; Configure the I/O ports
;
; ===================================

;		banksel	PORTA
; put in initial states for output pins
; tri-states are already set to hi-z upon reset
;		movlw	B'00001000'
;		movwf	PORTA
		clrf	PORTA
		movlw	B'00000000'
		movwf	PORTB
		movlw	B'00000000'
		movwf	PORTC
		movlw	B'00000000'
		movwf	PORTD
		movlw	B'00001000'
		movwf	PORTE

; Configure port A
;		banksel	TRISA
		bsf		STATUS,RP0
		movlw	B'00101111'
		movwf	TRISA

; Configure port B
;		banksel	TRISB
		movlw	B'11111111'
		movwf	TRISB

; Configure port C
		movlw	B'11111111'
		movwf	TRISC

; Configure Port D
;		banksel TRISD
		movlw	B'11111111'
		movwf	TRISD

; Configure port E
		movlw	B'11111111'
		movwf	TRISE

; =================================
;
; Use config to set dual-mode pins for analog or digital input
; output #s 8-13, 16-23
;
; =================================

;		banksel PORTA
		bcf		STATUS,RP0
		clrf	CONFIG_LAYER

; init pins 16-23
		movlw	D'16'
		movwf	OUTPUT_COUNTER
		movlw	D'8'
		movwf	COUNTER_L
		movlw	B'11111110'
		movwf	BITMASK

iip_a_loop
		call	init_input_pin_ansel
iip_a_loop_next
		bsf		STATUS,C
		rlf		BITMASK,f
		incf	OUTPUT_COUNTER,f
		decfsz	COUNTER_L,f
		goto	iip_a_loop

; init pins 8-13
; 8
		movlw	D'8'
		movwf	OUTPUT_COUNTER
		movlw	B'11101111'
		movwf	BITMASK
		call	init_input_pin_anselh
; 9
		incf	OUTPUT_COUNTER,f
		movlw	B'11111011'
		movwf	BITMASK
		call	init_input_pin_anselh
; 10
		incf	OUTPUT_COUNTER,f
		movlw	B'11111110'
		movwf	BITMASK
		call	init_input_pin_anselh
; 11
		incf	OUTPUT_COUNTER,f
		movlw	B'11111101'
		movwf	BITMASK
		call	init_input_pin_anselh
; 12
		incf	OUTPUT_COUNTER,f
		movlw	B'11110111'
		movwf	BITMASK
		call	init_input_pin_anselh
; 13
		incf	OUTPUT_COUNTER,f
		movlw	B'11011111'
		movwf	BITMASK
		call	init_input_pin_anselh

; ===================================
;
; Configure the ADC
;
; ===================================

;		banksel	ADCON1
		bsf		STATUS,RP0
		movlw	B'10000000'
		movwf	ADCON1
; ADCON0 is written just before A-D conversion
;		banksel	ADCON0
;		movlw	B'10000000'
;		movwf	ADCON0

; check reference voltage setting
		movlw	PROM_VREF
		banksel	EEADR
		movwf	EEADR
;		banksel	EECON1
		bsf		STATUS,RP0
		bcf		EECON1,EEPGD
		bsf		EECON1,RD
;		banksel	EEDAT
		bcf		STATUS,RP0
		movfw	EEDAT
		bz		vref_internal
vref_external
; set up the ADC to use pins 18 & 19 as VREF
		banksel	ADCON1
		bsf		ADCON1,5
		bsf		ADCON1,4
; state bit
		bsf		STATE_FLAGS,5
vref_internal
; do nothing
;		banksel	PORTA

; ===================================
;
; Init Remap Flags
;
; ===================================

		movlw	PROM_REMAP_FLAGS
		banksel	EEADR
		movwf	EEADR
;		banksel	EECON1
		bsf		STATUS,RP0
;		bcf		EECON1,EEPGD
		bsf		EECON1,RD
;		banksel	EEDAT
		bcf		STATUS,RP0
		movfw	EEDAT
;		banksel	PORTA
		bcf		STATUS,RP1
		andlw	B'00000111'
		movwf	TEMP
		bcf		STATUS,C
		rlf		TEMP,w
		iorwf	STATE_FLAGS_2,f

; ===================================
;
; Init Note Transpose
;
; ===================================

		movlw	PROM_TRANSPOSE_REG
;		banksel	EEADR
		bsf		STATUS,RP1
		movwf	EEADR
;		banksel	EECON1
		bsf		STATUS,RP0
;		bcf		EECON1,EEPGD
		bsf		EECON1,RD
;		banksel	EEDAT
		bcf		STATUS,RP0
		movfw	EEDAT
;		banksel	PORTA
		bcf		STATUS,RP1
		movwf	TEMP
		btfsc	TEMP,6
		goto	init_transpose_skip
		movfw	TEMP
		addlw	0x20
		movwf	TRANSPOSE_REG
		bsf		STATE_FLAGS_2,4
init_transpose_skip

; ===================================
;
; Init some variables
;
; ===================================

; init the logic input,	analog input values
		movlw	D'17'
		movwf	COUNTER_L
		bcf		STATUS,IRP
		movlw	DIGITAL_0
		movwf	FSR
		movlw	0xFF
init_loop_a
		movwf	INDF
		incf	FSR,f
		decfsz	COUNTER_L,f
		goto	init_loop_a
; init the matrix key values
		movlw	D'24'
		movwf	COUNTER_L
		bcf		STATUS,IRP
		movlw	KEYS_0
		movwf	FSR
		movlw	0xFF
init_loop_a2
		movwf	INDF
		incf	FSR,f
		decfsz	COUNTER_L,f
		goto	init_loop_a2


; matrix note velocity
		movlw	PROM_MATRIX_VELOCITY
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
		banksel	MATRIX_VELOCITY
		movwf	MATRIX_VELOCITY
;		banksel	PORTA
; cc on/off values
		movlw	PROM_CC_ON
		banksel	EEADR
		movwf	EEADR
;		banksel	EECON1
		bsf		STATUS,RP0
		bsf		EECON1,RD
;		banksel	EEDAT
		bcf		STATUS,RP0
		movfw	EEDAT
;		banksel	CC_ON_VALUE
		movwf	CC_ON_VALUE
;		banksel	EEADR
		incf	EEADR,f
;		banksel	EECON1
		bsf		STATUS,RP0
		bsf		EECON1,RD
;		banksel	EEDAT
		bcf		STATUS,RP0
		movfw	EEDAT
;		banksel	CC_OFF_VALUE
		movwf	CC_OFF_VALUE
;		banksel	PORTA
		bcf		STATUS,RP1

; encoder value init
		clrf	OUTPUT_COUNTER
;		clrf	CONFIG_LAYER
		bcf		STATE_FLAGS,6

		movlw	D'12'
		movwf	COUNTER_L
		movlw	ENCODER_0
		movwf	FSR
		movlw	PROM_ENCODER_INIT
		movwf	TEMP
init_loop_b
;		banksel	EEADR
		bsf		STATUS,RP1
		movfw	TEMP
		movwf	EEADR
;		banksel	EECON1
		bsf		STATUS,RP0
		bcf		EECON1,EEPGD
		bsf		EECON1,RD
;		banksel	EEDAT
		bcf		STATUS,RP0
		movfw	EEDAT
		movwf	INDF
;		banksel	PORTA
		bcf		STATUS,RP1

; if necessary, also move init value to MATRIX_VELOCITY, CC_ON_VALUE, or CC_OFF_VALUE
		pagesel	read_pin_config
		call	read_pin_config
		pagesel	main_init

init_loop_b_check_mv
		movlw	0x1A
		subwf	CONFIG_MODE,w
		bnz		init_loop_b_check_cc_on
		movfw	INDF
;		banksel	MATRIX_VELOCITY
		bsf		STATUS,RP0
		movwf	MATRIX_VELOCITY
;		banksel	PORTA
		bcf		STATUS,RP0
		goto	init_loop_b_next

init_loop_b_check_cc_on
		movlw	0x1B
		subwf	CONFIG_MODE,w
		bnz		init_loop_b_check_cc_off
		movfw	INDF
;		banksel	CC_ON_VALUE
		bsf		STATUS,RP1
		movwf	CC_ON_VALUE
;		banksel	PORTA
		bcf		STATUS,RP1
		goto	init_loop_b_next

init_loop_b_check_cc_off
		movlw	0x1C
		subwf	CONFIG_MODE,w
		bnz		init_loop_b_next
		movfw	INDF
;		banksel	CC_OFF_VALUE
		bsf		STATUS,RP1
		movwf	CC_OFF_VALUE
;		banksel	PORTA
		bcf		STATUS,RP1

init_loop_b_next
;		banksel	OUTPUT_COUNTER
		incf	OUTPUT_COUNTER,f
		incf	OUTPUT_COUNTER,f
		incf	FSR,f
		incf	TEMP,f
		decfsz	COUNTER_L,f
		goto	init_loop_b

; analog threshold init
		movlw	PROM_ANALOG_THRESHOLD
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
		banksel	ANALOG_THRESHOLD
		movwf	ANALOG_THRESHOLD

; matrix toggle values
;		banksel	PORTA
		bcf		STATUS,RP0
		movlw	D'24'
		movwf	COUNTER_L
		bsf		STATUS,IRP
		movlw	KEY_TOGGLES
		movwf	FSR
		movlw	0xFF
init_loop_c
		movwf	INDF
		incf	FSR,f
		decfsz	COUNTER_L,f
		goto	init_loop_c

; logic toggle values
		banksel	LOGIC_TOGGLES_0
		movlw	0xFF
		movwf	LOGIC_TOGGLES_0
		movwf	LOGIC_TOGGLES_1
		movwf	LOGIC_TOGGLES_2

; continuous note flags
;		banksel	ANALOG_CN_GATES_0
		bcf		STATUS,RP0
		clrf	ANALOG_CN_GATES_0
		clrf	ANALOG_CN_NOTES_0
		clrf	ANALOG_CN_GATES_1
		clrf	ANALOG_CN_NOTES_1
		clrf	ANALOG_CN_GATES_2
		clrf	ANALOG_CN_NOTES_2
		clrf	ENCODER_CN_GATES_0
		clrf	ENCODER_CN_NOTES_0
		clrf	ENCODER_CN_GATES_1
		clrf	ENCODER_CN_NOTES_1
		clrf	ENCODER_CN_GATES_2
		clrf	ENCODER_CN_NOTES_2
;		banksel	PORTA
		bcf		STATUS,RP1


; RX_BUFFER init
		clrf	RX_BUFFER_HEAD
		clrf	RX_BUFFER_TAIL
		clrf	RX_BUFFER_GAUGE
; Debounce init
;		movlw	0x10
;		movwf	DEBOUNCE_COUNTER
; Merge-related
		clrf	INBOUND_STATUS
		clrf	INBOUND_BYTECOUNT

		clrf	SYSEX_TYPE
		clrf	OUTBOUND_STATUS

; =================================
;
; LED Output Init
;
; =================================
;		banksel	LED_DATA_FLAGS
		bsf		STATUS,RP0
		clrf	LED_SELECT_FLAGS
; init the active select for ct 15 (first next is then 8)
		movlw	D'15'
		movwf	LED_ACTIVE_SELNUM
		movlw	B'10000000'
		movwf	LED_ACTIVE_SELBIT
; Use config to set LED flags & TRISD
; output #s 0-7
		clrf	LED_DATA_FLAGS
;		banksel	PORTA
		bcf		STATUS,RP0
		clrf	OUTPUT_COUNTER
		movlw	D'8'
		movwf	COUNTER_L
		movlw	B'00000001'
		movwf	BITMASK
init_led_loop_a
		pagesel	read_pin_config
		call	read_pin_config
		pagesel	init_led_loop_a
		movfw	CONFIG_MODE
		sublw	0x2B
		bnz		init_led_loop_a_next
; set the LED flag & tri-state
;		banksel	LED_DATA_FLAGS
		bsf		STATUS,RP0
		movfw	BITMASK
		iorwf	LED_DATA_FLAGS,f
		xorwf	TRISD,f
;		banksel	PORTA
		bcf		STATUS,RP0
init_led_loop_a_next
		bcf		STATUS,C
		rlf		BITMASK,f
		incf	OUTPUT_COUNTER,f
		decfsz	COUNTER_L,f
		goto	init_led_loop_a

; Use config to set output value & pull up
; output #s 8-15
		clrf	TEMP
		movlw	D'8'
		movwf	COUNTER_L
		movlw	B'00000001'
		movwf	BITMASK
init_led_loop_b
		pagesel	read_pin_config
		call	read_pin_config
		pagesel	init_led_loop_b
		movfw	CONFIG_MODE
		sublw	0x2A
		bnz		init_led_loop_b_next
; deactivate the weak pull-up
		bsf		STATUS,RP0
		movfw	BITMASK
		xorwf	WPUB,f
		iorwf	LED_SELECT_FLAGS,f
; set output state for common anode non-inverting, or for common cathode inverting.
		bcf		STATUS,RP0
		btfss	CONFIG_D0,1
		goto	init_led_common_anode
init_led_common_cathode
		movfw	BITMASK
		btfsc	CONFIG_D0,0
		iorwf	TEMP,f
		goto	init_led_loop_b_next
init_led_common_anode
		movfw	BITMASK
		btfss	CONFIG_D0,0
		iorwf	TEMP,f
init_led_loop_b_next
		bcf		STATUS,C
		rlf		BITMASK,f
		incf	OUTPUT_COUNTER,f
		decfsz	COUNTER_L,f
		goto	init_led_loop_b

; write the common/select states now
; tristate will activate output during runtime.
		movfw	TEMP
		movwf	PORTB

; =========================
; 
; Activity LED Test
; 
; =========================
led_test
		movlw	0xff
		movwf	COUNTER_H
led_test_a
		movlw	0xff
		movwf	COUNTER_L
led_test_b
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop

		decfsz	COUNTER_L,f
		goto	led_test_b
		decfsz	COUNTER_H,f
		goto	led_test_a

;		bsf	PORTA,6
		movlw	B'01000000'
		movwf	PORTA

; ===================================
;
; Enable global interrupts
;
; ===================================

; Enable global & peripheral interrupts
		movlw	B'11000000'
		movwf	INTCON

; ===================================
;
; Configure the USART
;
; ===================================

; Set up the USART
;		banksel	PIE1
		bsf		STATUS,RP0
; Enable receive interrupt
		bsf		PIE1,5
; Set up the baud rate generator
; 31.25kHz = 8MHz / (16 (15 + 1))
		movlw	0x0f
		movwf	SPBRG
; Set the transmit control bits
		movlw	B'00100110'
		movwf	TXSTA
;		banksel PORTA
		bcf		STATUS,RP0
; Set the receive control bits
		movlw	B'10010000'
		movwf	RCSTA


; STATE

; =========================
; 
; Timer Init
; 
; =========================
; kick off the midi active sense timer (Timer 2)
;		banksel	T2_COUNTER
		bsf		STATUS,RP0
		movlw	T2_SCALE
		movwf	T2_COUNTER
;		banksel	PIE1
		bsf		PIE1,1
;		banksel	PORTA
		bcf		STATUS,RP0
		bsf		T2CON,2
; check active sense setting
		movlw	PROM_ACTIVE_SENSE
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
; set state flag if necessary
		btfss	STATUS,Z
		bsf		STATE_FLAGS_2,0

		return

; =========================
; 
; Check config of dual-mode pins and init as necessary
; 
; =========================

init_input_pin_ansel
		pagesel	read_pin_config
		call	read_pin_config
		pagesel	main_init
; if analog input mode, do nothing
		movlw	B'11110000'
		andwf	CONFIG_MODE,w
		btfsc	STATUS,Z
		return
; otherwise, set pin for digital input.
		movfw	BITMASK
		banksel	ANSEL
		andwf	ANSEL,f
		banksel	PORTA

		return

init_input_pin_anselh
		pagesel	read_pin_config
		call	read_pin_config
		pagesel	main_init
; if analog input mode, do nothing
		movlw	B'11110000'
		andwf	CONFIG_MODE,w
		btfsc	STATUS,Z
		return
; otherwise, set pin for digital input.
		movfw	BITMASK
		banksel	ANSELH
		andwf	ANSELH,f
		banksel	PORTA

		return

		end
