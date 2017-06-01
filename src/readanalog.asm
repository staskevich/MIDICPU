; MIDI CPU
; copyright John Staskevich, 2017
; john@codeandcopper.com
;
; This work is licensed under a Creative Commons Attribution 4.0 International License.
; http://creativecommons.org/licenses/by/4.0/
;
; readanalog.asm
;
; Take samples from pins configured for analog input.
;
		list		p=16f887
   		#include	<p16f887.inc>

   		#include	<mc.inc>


; ==================================================================
;
; External Functions
;
; ==================================================================

		EXTERN	inbound_sysex_finish
		EXTERN	process_inbound_midi
		EXTERN	read_pin_config
		EXTERN	read_reg_config
		EXTERN	combine_channel_with_status
		EXTERN	load_d0_from_address
		EXTERN	load_d1_from_address
		EXTERN	send_midi_local
		EXTERN	go_reg_increment
		EXTERN	go_reg_decrement
		EXTERN	go_reg_sum
		EXTERN	go_reg_copy
		EXTERN	go_reg_store_value
		EXTERN	go_reg_bit_op

; ==================================================================
;
; Global Functions
;
; ==================================================================

		GLOBAL	read_analog_inputs


; read_analog		code	0x800
read_analog		code


; =================================
;
; read analog inputs
; careful--control terminal # and ADC # don't match
;
; =================================

read_analog_inputs
; no interference yet
		bcf		STATE_FLAGS,2
; grab the smoothing level from EEPROM
		movlw	PROM_ANALOG_SMOOTHING
		banksel	EEADR
		movwf	EEADR
		banksel	EECON1
		bcf		EECON1,EEPGD
		bsf		EECON1,RD
		banksel	EEDAT
		movfw	EEDAT
		banksel	PORTA
; move into COUNTER_H and incrment for easier counting later.
		movwf	COUNTER_H
		incf	COUNTER_H,f
; only configs for tt=0 is relevant
		bcf		STATE_FLAGS,6
; Address of continuous note gate flags
		movlw	ANALOG_CN_GATES_2
		movwf	TEMP_REG
; Control Terminal 16, AN0
		movlw	B'00000001'
		movwf	BITMASK
		clrf	ANALOG_INPUT
		movlw	D'16'
		movwf	OUTPUT_COUNTER
		call	read_analog_pin
; bail out if relevant sysex message comes in.
		btfsc	STATE_FLAGS,2
		return
; Control Terminal 17, AN1
		movlw	B'00000010'
		movwf	BITMASK
		incf	ANALOG_INPUT,f
		incf	OUTPUT_COUNTER,f
		call	read_analog_pin
; bail out if relevant sysex message comes in.
		btfsc	STATE_FLAGS,2
		return
; Control Terminal 18, AN2
		movlw	B'00000100'
		movwf	BITMASK
		incf	ANALOG_INPUT,f
		incf	OUTPUT_COUNTER,f
		call	read_analog_pin
; bail out if relevant sysex message comes in.
		btfsc	STATE_FLAGS,2
		return
; Control Terminal 19, AN3
		movlw	B'00001000'
		movwf	BITMASK
		incf	ANALOG_INPUT,f
		incf	OUTPUT_COUNTER,f
		call	read_analog_pin
; bail out if relevant sysex message comes in.
		btfsc	STATE_FLAGS,2
		return
; Control Terminal 20, AN4
		movlw	B'00010000'
		movwf	BITMASK
		incf	ANALOG_INPUT,f
		incf	OUTPUT_COUNTER,f
		call	read_analog_pin
; bail out if relevant sysex message comes in.
		btfsc	STATE_FLAGS,2
		return
; Control Terminal 21, AN5
		movlw	B'00100000'
		movwf	BITMASK
		incf	ANALOG_INPUT,f
		incf	OUTPUT_COUNTER,f
		call	read_analog_pin
; bail out if relevant sysex message comes in.
		btfsc	STATE_FLAGS,2
		return
; Control Terminal 22, AN6
		movlw	B'01000000'
		movwf	BITMASK
		incf	ANALOG_INPUT,f
		incf	OUTPUT_COUNTER,f
		call	read_analog_pin
; bail out if relevant sysex message comes in.
		btfsc	STATE_FLAGS,2
		return
; Control Terminal 23, AN7
		movlw	B'10000000'
		movwf	BITMASK
		incf	ANALOG_INPUT,f
		incf	OUTPUT_COUNTER,f
		call	read_analog_pin
; bail out if relevant sysex message comes in.
		btfsc	STATE_FLAGS,2
		return
; Address of continuous note gate flags
		movlw	ANALOG_CN_GATES_1
		movwf	TEMP_REG
; Control Terminal 8, AN12
		movlw	B'00000001'
		movwf	BITMASK
		movlw	D'12'
		movwf	ANALOG_INPUT
		movlw	D'8'
		movwf	OUTPUT_COUNTER
		call	read_analog_pin
; bail out if relevant sysex message comes in.
		btfsc	STATE_FLAGS,2
		return
; Control Terminal 9, AN10
		movlw	B'00000010'
		movwf	BITMASK
		movlw	D'10'
		movwf	ANALOG_INPUT
		incf	OUTPUT_COUNTER,f
		call	read_analog_pin
; bail out if relevant sysex message comes in.
		btfsc	STATE_FLAGS,2
		return
; Control Terminal 10, AN8
		movlw	B'00000100'
		movwf	BITMASK
		movlw	D'8'
		movwf	ANALOG_INPUT
		incf	OUTPUT_COUNTER,f
		call	read_analog_pin
; bail out if relevant sysex message comes in.
		btfsc	STATE_FLAGS,2
		return
; Control Terminal 11, AN9
		movlw	B'00001000'
		movwf	BITMASK
		movlw	D'9'
		movwf	ANALOG_INPUT
		incf	OUTPUT_COUNTER,f
		call	read_analog_pin
; bail out if relevant sysex message comes in.
		btfsc	STATE_FLAGS,2
		return
; Control Terminal 12, AN11
		movlw	B'00010000'
		movwf	BITMASK
		movlw	D'11'
		movwf	ANALOG_INPUT
		incf	OUTPUT_COUNTER,f
		call	read_analog_pin
; bail out if relevant sysex message comes in.
		btfsc	STATE_FLAGS,2
		return
; Control Terminal 13, AN13
		movlw	B'00100000'
		movwf	BITMASK
		movlw	D'13'
		movwf	ANALOG_INPUT
		incf	OUTPUT_COUNTER,f
		call	read_analog_pin
; bail out if relevant sysex message comes in.
		btfsc	STATE_FLAGS,2
		return

; Analog data is now valid
		bsf		STATE_FLAGS,4

		return

; =================================
;
; read analog pin
;
; =================================


read_analog_pin
; check layer 0 config.  If not analog mode, exit.
		clrf	CONFIG_LAYER
		call	read_pin_config
		movlw	B'11110000'
		andwf	CONFIG_MODE,w
		btfss	STATUS,Z
		return
; convert the analog voltage
; select the current pin & turn on the ADC
		bcf		STATUS,0
		rlf		ANALOG_INPUT,w
		movwf	TEMP
		rlf		TEMP,w
		iorlw	B'10000001'
		movwf	ADCON0
; wait for the ADC cap to charge
		call	adc_delay
; start conversion
		bsf		ADCON0,1
; wait for conversion to complete
		btfsc	ADCON0,1
		goto	$-1
; get the data
		movfw	ADRESH
		movwf	TEMP
		banksel	ADRESL
		movfw	ADRESL
		banksel	PORTA
		movwf	TEMP2
; turn off the ADC
		bcf		ADCON0,0
; TEMP:TEMP2: current sample
		btfsc	STATE_FLAGS,4
		goto	rap_rolling_average
rap_first_sample
; if this is the first sample, go with this value
; current sample becomes TEMP3:TEMP4 and rolling average
		movlw	0xFF
		movwf	TEMP5
		movlw	INCOMING_SYSEX_A
		addwf	ANALOG_INPUT,w
		addwf	ANALOG_INPUT,w
		movwf	FSR
		bcf		STATUS,IRP
		movfw	TEMP
		movwf	TEMP3
		movwf	INDF
		incf	FSR,f
		movfw	TEMP2
		movwf	TEMP4
		movwf	INDF
; Store 7-bit value to TEMP2
		rrf		TEMP,f
		rrf		TEMP2,f
		rrf		TEMP,f
		rrf		TEMP2,f
		bcf		STATUS,C
		rrf		TEMP2,f
		goto	rap_round_down
rap_rolling_average
; grab the previous event trigger value
		movlw	INCOMING_SYSEX_A+D'29'
		addwf	ANALOG_INPUT,w
		addwf	ANALOG_INPUT,w
		movwf	FSR
		bcf		STATUS,IRP
		movfw	INDF
		movwf	TEMP6
		decf	FSR,f
		movfw	INDF
		movwf	TEMP5
; grab the rolling average
		movlw	D'28'
		subwf	FSR,f
		movfw	INDF
		movwf	TEMP3
		incf	FSR,f
		movfw	INDF
		movwf	TEMP4
; old rolling average now in TEMP3:TEMP4
; new sample in TEMP:TEMP2
		movfw	COUNTER_H
		sublw	0x01
		bz		rap_roll_skip_ends
		movfw	COUNTER_H
		sublw	0x02
		bz		rap_roll_skip_ends
; if TEMP3 is 11 and new sample is an increase, replace the rolling av
rap_roll_check_high_end
		movfw	TEMP3
		sublw	B'00000011'
		bnz		rap_roll_check_low_end
		movfw	TEMP
		sublw	B'00000011'
		bnz		rap_roll_check_low_end
		movfw	TEMP2
		subwf	TEMP4,w
		bc		rap_roll_skip_ends
		movlw	0x02
		movwf	COUNTER_H
		goto	rap_roll_skip_ends
;		goto	rap_rolling_store_average

; if TEMP3 is 00 and new sample is a decrease, replace the rolling av
rap_roll_check_low_end
		movfw	TEMP3
		bnz		rap_roll_skip_ends
		movfw	TEMP
		bnz		rap_roll_skip_ends
		movfw	TEMP4
		subwf	TEMP2,w
		bc		rap_roll_skip_ends
		movlw	0x02
		movwf	COUNTER_H
		goto	rap_roll_skip_ends
;		goto	rap_rolling_store_average

rap_roll_skip_ends
		decf	FSR,f

; rolling average counts for 15 parts, new data counts for 1
; sum the parts
; high-order byte (each sample uses only last 2 bits--no carry concern)
; move the smoothing level for decrementing
		movfw	COUNTER_H
		movwf	COUNTER_L
		movfw	TEMP
		decf	COUNTER_L,f
		btfsc	STATUS,Z
		goto	rap_rolling_high_finished
		addwf	INDF,w
		decf	COUNTER_L,f
		btfsc	STATUS,Z
		goto	rap_rolling_high_finished
		addwf	INDF,w
		addwf	INDF,w
		decf	COUNTER_L,f
		btfsc	STATUS,Z
		goto	rap_rolling_high_finished
		addwf	INDF,w
		addwf	INDF,w
		addwf	INDF,w
		addwf	INDF,w
		decf	COUNTER_L,f
		btfsc	STATUS,Z
		goto	rap_rolling_high_finished
		addwf	INDF,w
		addwf	INDF,w
		addwf	INDF,w
		addwf	INDF,w
		addwf	INDF,w
		addwf	INDF,w
		addwf	INDF,w
		addwf	INDF,w
rap_rolling_high_finished
		movwf	TEMP
; low-order byte
		incf	FSR,f
; move the smoothing level for decrementing
		movfw	COUNTER_H
		movwf	COUNTER_L
; current sample
		movfw	TEMP2
		decf	COUNTER_L,f
		btfsc	STATUS,Z
		goto	rap_rolling_low_finished
; x 1
		addwf	INDF,w
		btfsc	STATUS,C
		incf	TEMP,f
		decf	COUNTER_L,f
		btfsc	STATUS,Z
		goto	rap_rolling_low_finished
; x 2
		addwf	INDF,w
		btfsc	STATUS,C
		incf	TEMP,f
; x 3
		addwf	INDF,w
		btfsc	STATUS,C
		incf	TEMP,f
		decf	COUNTER_L,f
		btfsc	STATUS,Z
		goto	rap_rolling_low_finished
; x 4
		addwf	INDF,w
		btfsc	STATUS,C
		incf	TEMP,f
; x 5
		addwf	INDF,w
		btfsc	STATUS,C
		incf	TEMP,f
; x 6
		addwf	INDF,w
		btfsc	STATUS,C
		incf	TEMP,f
; x 7
		addwf	INDF,w
		btfsc	STATUS,C
		incf	TEMP,f
		decf	COUNTER_L,f
		btfsc	STATUS,Z
		goto	rap_rolling_low_finished
; x 8
		addwf	INDF,w
		btfsc	STATUS,C
		incf	TEMP,f
; x 9
		addwf	INDF,w
		btfsc	STATUS,C
		incf	TEMP,f
; x 10
		addwf	INDF,w
		btfsc	STATUS,C
		incf	TEMP,f
; x 11
		addwf	INDF,w
		btfsc	STATUS,C
		incf	TEMP,f
; x 12
		addwf	INDF,w
		btfsc	STATUS,C
		incf	TEMP,f
; x 13
		addwf	INDF,w
		btfsc	STATUS,C
		incf	TEMP,f
; x 14
		addwf	INDF,w
		btfsc	STATUS,C
		incf	TEMP,f
; x 15
		addwf	INDF,w
		btfsc	STATUS,C
		incf	TEMP,f
rap_rolling_low_finished
		movwf	TEMP2
; divide by 16
; move the smoothing level for decrementing
		movfw	COUNTER_H
		movwf	COUNTER_L
		decf	COUNTER_L,f
		btfsc	STATUS,Z
		goto	rap_rolling_divide_finished
; 2
rap_divide_2
		bcf		STATUS,C
		rrf		TEMP,f
		rrf		TEMP2,f
		decf	COUNTER_L,f
		btfsc	STATUS,Z
		goto	rap_rolling_divide_finished
; 4
rap_divide_4
		bcf		STATUS,C
		rrf		TEMP,f
		rrf		TEMP2,f
		decf	COUNTER_L,f
		btfsc	STATUS,Z
		goto	rap_rolling_divide_finished
; 8
rap_divide_8
		bcf		STATUS,C
		rrf		TEMP,f
		rrf		TEMP2,f
		decf	COUNTER_L,f
		btfsc	STATUS,Z
		goto	rap_rolling_divide_finished
; 16
rap_divide_16
		bcf		STATUS,C
		rrf		TEMP,f
		rrf		TEMP2,f
rap_rolling_divide_finished
rap_rolling_store_average
; store new moving average (low)
		movfw	TEMP2
		movwf	INDF
		movwf	TEMP4
; store new moving average (high)
		decf	FSR,f
		movfw	TEMP
		movwf	INDF
		movwf	TEMP3
; TEMP : TEMP2: new average
; TEMP3 : TEMP4: new average
; TEMP5 : TEMP6: previous trigger value
; reduce 10 bits to 7
		rrf		TEMP,f
		rrf		TEMP2,f
		rrf		TEMP,f
		rrf		TEMP2,f
		bcf		STATUS,C
		rrf		TEMP2,f
; round up / round down.
; round up only when 7-bit value is 64+
		btfss	TEMP2,6
		goto	rap_round_down
; round up if the bit just shifted out was a 1
		btfsc	STATUS,C
		incf	TEMP2,f
; make sure we didn't roll the 7-bit value
		btfsc	TEMP2,7
		decf	TEMP2,f
rap_round_down
; TEMP2: new 7bit value.  TEMP: nothing
; TEMP3 & TEMP4: new average
; TEMP5 : TEMP6: previous trigger value
; apply configurable min/max.
		movfw	ANALOG_INPUT
		addlw	0x03
		movwf	REG_ADDRESS
		call	read_reg_config
		movfw	REG_MIN
		subwf	TEMP2,w
		btfss	STATUS,C
		goto	rap_enforce_minimum
		movfw	TEMP2
		subwf	REG_MAX,w
		btfsc	STATUS,C
		goto	rap_compare_previous
rap_enforce_maximum
		movfw	REG_MAX
		movwf	TEMP2
		goto	rap_compare_previous
rap_enforce_minimum
		movfw	REG_MIN
		movwf	TEMP2
rap_compare_previous
; compare to previous 7-bit value.  If unchanged, nothing further required.
		movlw	ANALOG_0
		addwf	ANALOG_INPUT,w
		movwf	FSR
		movfw	INDF
; save old value in LOCAL_D0 for use by continuous note modes
		movwf	LOCAL_D0
; global refresh happening?  trigger an event.
		btfsc	STATE_FLAGS_2,6
		goto	analog_pin_trigger_event
; check for change to 7-bit value.
		subwf	TEMP2,w
		bz		read_analog_pin_unchanged
; check if an event should be triggered based on the change between the
; new rolling average and the average that triggered the previous event.
analog_pin_changed
; check for min/max values
		movfw	TEMP2
		bz		analog_pin_trigger_event
		sublw	0x7F
		bz		analog_pin_trigger_event
; determine how much the 10-bit value has changed
		movfw	INDF
		subwf	TEMP2,w
		bc		rap_increase
rap_decrease
; check configurable threshold
; subtract new rolling average from trigger value
		movfw	TEMP3
		subwf	TEMP5,f
		movfw	TEMP4
		subwf	TEMP6,f
		btfss	STATUS,C
		decf	TEMP5,f
; TEMP2: new 7bit value.  TEMP: nothing
; TEMP3 : TEMP4: new average
; TEMP5 : TEMP6: change from trigger value
		goto	rap_check_threshold
rap_increase
; check configurable threshold
; subtract trigger value from new rolling average
		movfw	TEMP5
		subwf	TEMP3,w
		movwf	TEMP5
		movfw	TEMP6
		subwf	TEMP4,w
		btfss	STATUS,C
		decf	TEMP5,f
		movwf	TEMP6
; TEMP2: new 7bit value.  TEMP: nothing
; TEMP3 : TEMP4: new average
; TEMP5 : TEMP6: change from trigger value
rap_check_threshold
; check for huge decrease
		movf	TEMP5,f
		bnz		analog_pin_trigger_event
; check threshold
		banksel	ANALOG_THRESHOLD
		movfw	ANALOG_THRESHOLD
		banksel	PORTA
		subwf	TEMP6,w
		bnc		read_analog_pin_unchanged
		goto	analog_pin_trigger_event

analog_pin_trigger_event
; value has changed--send a midi message
; store new 10-bit trigger value
		movlw	INCOMING_SYSEX_A+D'28'
		addwf	ANALOG_INPUT,w
		addwf	ANALOG_INPUT,w
		movwf	FSR
		movfw	TEMP3
		movwf	INDF
		incf	FSR,f
		movfw	TEMP4
		movwf	INDF
; store new 7-bit value
		movlw	ANALOG_0
		addwf	ANALOG_INPUT,w
		movwf	FSR
; put previous 7-bit value in TEMP5
		movfw	INDF
		movwf	TEMP5
; store new value
		movfw	TEMP2
		movwf	INDF
; check each of 4 config layers.
; set up the layer flag bitmask
		movlw	B'00000001'
		movwf	TEMP7
rap_layer_loop
; current layer active?
		movfw	LAYER_FLAGS_SNAPSHOT
		andwf	TEMP7,0
		bz	rap_next_layer
; get the pin config for this layer.
		call	read_pin_config
; skip if not an analog mode.
		movlw	B'11110000'
		andwf	CONFIG_MODE,w
		bnz	rap_next_layer
; check mode, send message if necessary
rap_check_continuous_note
		movlw	B'11111110'
		andwf	CONFIG_MODE,w
		bnz	rap_skip_continuous_note

; truth table for continuous note ons / offs.
; considers change to analog value, gate flags, and note flags.
; exceptional case is no-change/gate-on/note-on
; chang 0000 1111
; gates 0011 0011
; notes	0101 0101
; ===============
; n-ons 0010 0011
; n-off 0100 0101

rap_check_cn_note_flag
; is there a note flag?  then send note off
		movfw	TEMP_REG
		addlw	D'6'
		movwf	FSR
		bsf		STATUS,IRP
		movfw	BITMASK
		andwf	INDF,w
		bz		rap_check_cn_gate_flag
; clear the note flag
		comf	BITMASK,w
		andwf	INDF,f
; send the note off message
		movlw	0x90
		movwf	LOCAL_STATUS
		movfw	TEMP5
		movwf	LOCAL_D0
		clrf	LOCAL_D1
		call	combine_channel_with_status
		call	send_midi_local
rap_check_cn_gate_flag
; is there a gate flag?  then send note on
		movfw	TEMP_REG
		movwf	FSR
		movfw	BITMASK
		andwf	INDF,w
		bz	rap_next_layer
; set the note flag
		movlw	D'6'
		addwf	FSR,f
		movfw	BITMASK
		iorwf	INDF,f
; prepare for note on
		movfw	TEMP2
		movwf	LOCAL_D0
; use literal for D1
		movfw	CONFIG_D1
		movwf	LOCAL_D1
; overwrite with register value if necessary
		btfsc	CONFIG_MODE,0
		call	load_d1_from_address
		goto	rap_send_message
rap_skip_continuous_note
rap_check_aftertouch
		movlw	B'11111100'
		andwf	CONFIG_MODE,w
		bnz	rap_skip_aftertouch

		movlw	0xA0
		movwf	LOCAL_STATUS
; use register for D1
		call	load_d1_from_address
; use literal for D0
		movfw	CONFIG_D0
		movwf	LOCAL_D0
; overwrite with register value if necessary
		btfss	CONFIG_MODE,0
		goto	rap_send_message
		call	load_d0_from_address
		goto	rap_send_message
rap_skip_aftertouch
rap_check_controller
		movlw	B'11111010'
		andwf	CONFIG_MODE,w
		bnz	rap_skip_controller

		movlw	0xB0
		movwf	LOCAL_STATUS
; use register for D1
		call	load_d1_from_address
; use literal for D0
		movfw	CONFIG_D0
		movwf	LOCAL_D0
; overwrite with register value if necessary
		btfss	CONFIG_MODE,0
		goto	rap_send_message
		call	load_d0_from_address
		goto	rap_send_message
rap_skip_controller
rap_check_program_change
		movlw	B'11111001'
		andwf	CONFIG_MODE,w
		bnz	rap_skip_program_change

		movlw	0xC0
		movwf	LOCAL_STATUS
		call	load_d0_from_address
		goto	rap_send_message
rap_skip_program_change
rap_check_channel_pressure
		movlw	B'11111000'
		andwf	CONFIG_MODE,w
		bnz	rap_skip_channel_pressure

		movlw	0xD0
		movwf	LOCAL_STATUS
		call	load_d0_from_address
		goto	rap_send_message
rap_skip_channel_pressure
rap_check_pitch_wheel
		movlw	B'11110111'
		andwf	CONFIG_MODE,w
		bnz	rap_skip_pitch_wheel

		movlw	0xE0
		movwf	LOCAL_STATUS
		call	load_d1_from_address
		clrf	LOCAL_D0
		goto	rap_send_message
rap_skip_pitch_wheel
;rap_check_increment
;		movlw	0x0A
;		subwf	CONFIG_MODE,w
;		bnz	rap_skip_increment
;		call	go_reg_increment
;		goto	rap_next_layer
;rap_skip_increment
;rap_check_sum
;		movlw	0x0B
;		subwf	CONFIG_MODE,w
;		bnz	rap_skip_sum
;		call	go_reg_sum
;		goto	rap_next_layer
;rap_skip_sum
rap_check_copy
		movlw	0x0C
		subwf	CONFIG_MODE,w
		bnz	rap_skip_copy
		call	go_reg_copy
		goto	rap_next_layer
rap_skip_copy
rap_check_store
		movlw	0x0D
		subwf	CONFIG_MODE,w
		bnz	rap_skip_store
		call	go_reg_store_value
		goto	rap_next_layer
rap_skip_store
rap_check_bitop
		movlw	0x0E
		subwf	CONFIG_MODE,w
		bnz	rap_next_layer
		call	go_reg_bit_op
		goto	rap_next_layer

; send message
rap_send_message
		call	combine_channel_with_status
		call	send_midi_local
rap_next_layer
		pagesel	process_inbound_midi
		call	process_inbound_midi
		pagesel	read_analog_inputs
; next layer
		bcf	STATUS,C
		rlf	TEMP7,f
		incf	CONFIG_LAYER,f
		btfss	CONFIG_LAYER,2
		goto	rap_layer_loop
		return

read_analog_pin_unchanged
; check each of 4 config layers.
; set up the layer flag bitmask
		movlw	B'00000001'
		movwf	TEMP7
rapu_layer_loop
; current layer active?
		movfw	LAYER_FLAGS_SNAPSHOT
		andwf	TEMP7,0
		bz	rapu_next_layer
; get the pin config for this layer.
		call	read_pin_config
; skip if not an analog mode.
		movlw	B'11110000'
		andwf	CONFIG_MODE,w
		bnz	rapu_next_layer
; if current mode is continous note, there may still be stuff to do.
; send either a note-on or note off, neither, but not both.
		movlw	B'11111110'
		andwf	CONFIG_MODE,w
		bnz	rapu_next_layer
; status is 0x90 for sure
		movlw	0x90
		movwf	LOCAL_STATUS
rap_unchanged_cn_gate
; check gate flag
		movfw	TEMP_REG
		movwf	FSR
		bsf		STATUS,IRP
		movfw	BITMASK
		andwf	INDF,w
		bz		rap_unchanged_cn_note
; gate is on.  if note is off, send a note-on message.
		movlw	D'6'
		addwf	FSR,f
		movfw	BITMASK
		andwf	INDF,w
		bnz	rapu_next_layer
; send note-on
; set the note flag
		movfw	BITMASK
		iorwf	INDF,f
; LOCAL_D0 should already be loaded and ready to go.
; use literal for D1
		movfw	CONFIG_D1
		movwf	LOCAL_D1
; overwrite with register value if necessary
		btfsc	CONFIG_MODE,0
		call	load_d1_from_address
		goto	rapu_send_message

rap_unchanged_cn_note
; gate is off. if note is on, send a note-off message.
		movlw	D'6'
		addwf	FSR,f
		movfw	BITMASK
		andwf	INDF,w
		bz	rapu_next_layer
; send note_off
; clear the note flag
		comf	BITMASK,w
		andwf	INDF,f
; LOCAL_D0 should already be loaded and ready to go.
		clrf	LOCAL_D1
		goto	rapu_send_message
; send message
rapu_send_message
		call	combine_channel_with_status
		call	send_midi_local
rapu_next_layer
		pagesel	process_inbound_midi
		call	process_inbound_midi
		pagesel	read_analog_inputs
; next layer
		bcf	STATUS,C
		rlf	TEMP7,f
		incf	CONFIG_LAYER,f
		btfss	CONFIG_LAYER,2
		goto	rapu_layer_loop
		return


; =================================
;
; allow ADC cap to charge
; about 5us delay
;
; =================================

adc_delay
; 1/2 us per instruction.
; 8 x nop + call & return ~= 5us
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop

		return

		end
