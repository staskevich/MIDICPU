; MIDI CPU
; copyright John Staskevich, 2017
; john@codeandcopper.com
;
; This work is licensed under a Creative Commons Attribution 4.0 International License.
; http://creativecommons.org/licenses/by/4.0/
;
; readlogic.asm
;
; Take samples from pins configured for logic input.
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
		EXTERN	main_init
		EXTERN	read_pin_config
		EXTERN	combine_channel_with_status
		EXTERN	load_d0_from_address
		EXTERN	load_d1_from_address
		EXTERN	add_to_d0_from_d1_address
		EXTERN	point_to_d0_address
		EXTERN	send_midi_byte
		EXTERN	send_midi_local

; ==================================================================
;
; Global Functions
;
; ==================================================================

		GLOBAL	read_logic_inputs


read_logic		code	0x0A60
;read_logic		code


read_logic_inputs
; no interference yet
		bcf		STATE_FLAGS,2
; Pins 0-7
		clrf	OUTPUT_COUNTER
; store the input states to TEMP
		movfw	PORTD
		movwf	TEMP
		movwf	TEMP4
; store the change flags to TEMP2
		xorwf	DIGITAL_0,w
		movwf	TEMP2
; update the toggles, copy to TEMP3
		comf	TEMP,w
		andwf	TEMP2,w
		banksel	LOGIC_TOGGLES_0
		xorwf	LOGIC_TOGGLES_0,w
		movwf	LOGIC_TOGGLES_0
;		banksel	PORTA
		movwf	TEMP3
; process the trigger inputs
		call	read_trigger_byte
; bail out if relevant sysex message comes in.
		btfsc	STATE_FLAGS,2
		return
; process the encoder inputs
		clrf	OUTPUT_COUNTER
		movfw	TEMP4
		movwf	TEMP
		xorwf	DIGITAL_0,w
		movwf	TEMP2
		movfw	DIGITAL_0
		movwf	TEMP3
		movlw	ENCODER_0
		movwf	ANALOG_INPUT
; for continuous note stuff
		movlw	ENCODER_CN_GATES_0
		movwf	TEMP_REG
		call	read_encoder_byte
; save the new input states
		movfw	TEMP4
		movwf	DIGITAL_0


;		return


; Pins 8-15
		movlw	D'8'
		movwf	OUTPUT_COUNTER
; store the input states to TEMP
		movfw	PORTB
		movwf	TEMP
		movwf	TEMP4
; store the change flags to TEMP2
		xorwf	DIGITAL_1,w
		movwf	TEMP2
; update the toggles, copy to TEMP3
		comf	TEMP,w
		andwf	TEMP2,w
		banksel	LOGIC_TOGGLES_1
		xorwf	LOGIC_TOGGLES_1,w
		movwf	LOGIC_TOGGLES_1
;		banksel	PORTA
		movwf	TEMP3
; process the trigger inputs
		call	read_trigger_byte
; bail out if relevant sysex message comes in.
		btfsc	STATE_FLAGS,2
		return
; process the encoder inputs
		movlw	D'8'
		movwf	OUTPUT_COUNTER
		movfw	TEMP4
		movwf	TEMP
		xorwf	DIGITAL_1,w
		movwf	TEMP2
		movfw	DIGITAL_1
		movwf	TEMP3
		movlw	ENCODER_4
		movwf	ANALOG_INPUT
; for continuous note stuff
		movlw	ENCODER_CN_GATES_1
		movwf	TEMP_REG
		call	read_encoder_byte
; save the new input states
		movfw	TEMP4
		movwf	DIGITAL_1


; Pins 16-23
		movlw	D'16'
		movwf	OUTPUT_COUNTER
; store the input states to TEMP
		movfw	PORTA
		movwf	TEMP2

		andlw	B'00001111'
		movwf	TEMP

		btfsc	TEMP2,5
		bsf		TEMP,4

		movfw	PORTE
		movwf	TEMP2
		rlf		TEMP2,f
		rlf		TEMP2,f
		rlf		TEMP2,f
		rlf		TEMP2,f
		rlf		TEMP2,f
		movfw	TEMP2
		andlw	B'11100000'
		iorwf	TEMP,f
		movfw	TEMP
		movwf	TEMP4
; store the change flags to TEMP2
		movfw	DIGITAL_2
		xorwf	TEMP,w
		movwf	TEMP2
; update the toggles, copy to TEMP3
		comf	TEMP,w
		andwf	TEMP2,w
		banksel	LOGIC_TOGGLES_2
		xorwf	LOGIC_TOGGLES_2,w
		movwf	LOGIC_TOGGLES_2
;		banksel	PORTA
		movwf	TEMP3
; process the trigger inputs
		call	read_trigger_byte
; bail out if relevant sysex message comes in.
		btfsc	STATE_FLAGS,2
		return
; process the encoder inputs
		movlw	D'16'
		movwf	OUTPUT_COUNTER
		movfw	TEMP4
		movwf	TEMP
		xorwf	DIGITAL_2,w
		movwf	TEMP2
		movfw	DIGITAL_2
		movwf	TEMP3
		movlw	ENCODER_8
		movwf	ANALOG_INPUT
; for continuous note stuff
		movlw	ENCODER_CN_GATES_2
		movwf	TEMP_REG
		call	read_encoder_byte
; save the new input states
		movfw	TEMP4
		movwf	DIGITAL_2

		return

; =================================
;
; handle changes to block of 8 digital inputs
; input variables (munged):
;   TEMP: new input states
;   TEMP2: changed bit flags
;	TEMP3: toggle states
;   OUTPUT_COUNTER: first output number
;
; =================================

read_trigger_byte
		banksel	PORTA
; handle each changed bit
		movlw	0x08
		movwf	COUNTER_H
read_trigger_bit
		rrf		TEMP2,f
		btfss	STATUS,C
		goto	read_trigger_bit_unchanged
read_trigger_bit_changed
; assume this is a falling-edge transition
		bcf		STATE_FLAGS,6
		rrf		TEMP,f
		btfss	STATUS,C
		goto	rtbc_prepare_loop
read_trigger_bit_set
; this is a rising-edge transition
		bsf		STATE_FLAGS,6
rtbc_prepare_loop
		clrf	CONFIG_LAYER
		movlw	0x04
		movwf	COUNTER_L
rtbc_layer_loop
		call	read_pin_config
rtbc_check_mode_type
; skip if not a trigger input
		btfss	CONFIG_MODE,6
		goto	read_trigger_bit_next
; check for note off
rtbc_check_note_off
		movlw	B'00111100'
		andwf	CONFIG_MODE,w
		bnz		rtbc_check_note_on
		movlw	0x80
		movwf	LOCAL_STATUS
		goto	rtbc_get_data
rtbc_check_note_on
		movlw	B'00111000'
		andwf	CONFIG_MODE,w
		bnz		rtbc_check_aftertouch
		movlw	0x90
		movwf	LOCAL_STATUS
		goto	rtbc_get_data
rtbc_check_aftertouch
		movlw	B'00110100'
		andwf	CONFIG_MODE,w
		bnz		rtbc_check_controller
		movlw	0xA0
		movwf	LOCAL_STATUS
		goto	rtbc_get_data
rtbc_check_controller
		movlw	B'00110000'
		andwf	CONFIG_MODE,w
		bnz		rtbc_check_program_change
		movlw	0xB0
		movwf	LOCAL_STATUS
		goto	rtbc_get_data
rtbc_check_program_change
		movlw	B'00101100'
		andwf	CONFIG_MODE,w
		bnz		rtbc_check_channel_pressure
		movlw	0xC0
		movwf	LOCAL_STATUS
; check for d1 addend mode
		btfss	CONFIG_MODE,1
		goto	rtbc_get_data
		movfw	CONFIG_D0
		movwf	LOCAL_D0
		btfsc	CONFIG_MODE,0
		call	load_d0_from_address
		call	add_to_d0_from_d1_address
		goto	rtbc_get_channel
rtbc_check_channel_pressure
		movlw	B'00101010'
		andwf	CONFIG_MODE,w
		bnz		rtbc_check_cc_toggle
		movlw	0xD0
		movwf	LOCAL_STATUS
		goto	rtbc_get_data
rtbc_check_cc_toggle
		movlw	B'00101000'
		andwf	CONFIG_MODE,w
		bnz		rtbc_check_pitch_wheel
		movlw	0xB0
		movwf	LOCAL_STATUS
; set up d1 with CC on/off values
		bsf		STATUS,RP1
		movfw	CC_ON_VALUE
		btfsc	TEMP3,0
		movfw	CC_OFF_VALUE
		bcf		STATUS,RP1
		movwf	LOCAL_D1
		goto	rtbc_get_data_d0_only
rtbc_check_pitch_wheel
		movlw	B'00100100'
		andwf	CONFIG_MODE,w
		bnz		rtbc_check_sysex
		movlw	0xE0
		movwf	LOCAL_STATUS
		goto	rtbc_get_data
rtbc_check_sysex
		movlw	0x5C
		subwf	CONFIG_MODE,w
		bnz		rtbc_check_midi_start
		movlw	0xF0
		movwf	LOCAL_STATUS
		movfw	CONFIG_D0
		movwf	LOCAL_D0
		movfw	CONFIG_D1
		movwf	LOCAL_D1
		call	send_midi_local
		goto	rtbc_next_layer
rtbc_check_midi_start
		movlw	0x64
		subwf	CONFIG_MODE,w
		bnz		rtbc_check_midi_stop
rtbc_go_midi_start
; set the "run" state bit
		bsf		STATE_FLAGS,7
; send the message
		movlw	0xFA
		movwf	OUTBOUND_BYTE
		call	send_midi_byte
		goto	rtbc_next_layer
rtbc_check_midi_stop
		movlw	0x65
		subwf	CONFIG_MODE,w
		bnz		rtbc_check_midi_run_toggle
rtbc_go_midi_stop
; clear the "run" state bit
		bcf		STATE_FLAGS,7
; send the message
		movlw	0xFC
		movwf	OUTBOUND_BYTE
		call	send_midi_byte
		goto	rtbc_next_layer
rtbc_check_midi_run_toggle
		movlw	0x66
		subwf	CONFIG_MODE,w
		bnz		rtbc_check_midi_clock
; toggle the "run" state bit
		btfsc	STATE_FLAGS,7
		goto	rtbc_go_midi_stop
		goto	rtbc_go_midi_start
rtbc_check_midi_clock
		movlw	0x67
		subwf	CONFIG_MODE,w
		bnz		rtbc_check_an_cn
		movlw	0xF8
		movwf	OUTBOUND_BYTE
		call	send_midi_byte
		goto	rtbc_next_layer
rtbc_check_an_cn
; set up an offset & bitmask for use by all continuous note modes
; TEMP5 stores the offset for the pointer to the flags/notes registers
; BITMASK stores the bit of the target continuous note input
; set up the offset
		clrf	TEMP5
		movlw	D'8'
		subwf	CONFIG_D0,w
		btfsc	STATUS,C
		incf	TEMP5,f
		movlw	D'16'
		subwf	CONFIG_D0,w
		btfsc	STATUS,C
		incf	TEMP5,f
; set up the bitmask
		movlw	B'00000001'
		movwf	BITMASK
		movfw	CONFIG_D0
		andlw	B'00000111'
		bz		rtbc_check_an_cn_gate_on
		movwf	TEMP6
rtbc_bitmask_shift
		bcf		STATUS,C
		rlf		BITMASK,f
		decfsz	TEMP6,f
		goto	rtbc_bitmask_shift

rtbc_check_an_cn_gate_on
		movlw	0x68
		subwf	CONFIG_MODE,w
		bnz		rtbc_check_an_cn_gate_off
; set the gate bit for the analog input specified by d0
		movlw	ANALOG_CN_GATES_0
		addwf	TEMP5,w
		movwf	FSR
		bsf		STATUS,IRP
		movfw	BITMASK
		iorwf	INDF,f
; note_on will be generated elsewhere
		goto	rtbc_next_layer

rtbc_check_an_cn_gate_off
		movlw	0x69
		subwf	CONFIG_MODE,w
		bnz		rtbc_check_en_cn_gate_on
; clear the gate bit for the analog input specified by d0
		movlw	ANALOG_CN_GATES_0
		addwf	TEMP5,w
		movwf	FSR
		bsf		STATUS,IRP
		comf	BITMASK,w
		andwf	INDF,f
; note_off will be generated elsewhere
		goto	rtbc_next_layer

rtbc_check_en_cn_gate_on
		movlw	0x6A
		subwf	CONFIG_MODE,w
		bnz		rtbc_check_en_cn_gate_off
; set the gate bit for the encoder input specified by d0
		movlw	ENCODER_CN_GATES_0
		addwf	TEMP5,w
		movwf	FSR
		bsf		STATUS,IRP
		movfw	BITMASK
		iorwf	INDF,f
; note_on will be generated elsewhere
		goto	rtbc_next_layer

rtbc_check_en_cn_gate_off
		movlw	0x6B
		subwf	CONFIG_MODE,w
		bnz		rtbc_check_midi_reset
; clear the gate bit for the analog input specified by d0
		movlw	ENCODER_CN_GATES_0
		addwf	TEMP5,w
		movwf	FSR
		bsf		STATUS,IRP
		comf	BITMASK,w
		andwf	INDF,f
; note_off will be generated elsewhere
		goto	rtbc_next_layer

rtbc_check_midi_reset
		movlw	0x7E
		subwf	CONFIG_MODE,w
		bnz		rtbc_check_increment
		movlw	0xFF
		movwf	OUTBOUND_BYTE
		call	send_midi_byte
		goto	rtbc_next_layer

rtbc_check_increment
		movlw	0x70
		subwf	CONFIG_MODE,w
		bnz		rtbc_check_decrement
; check for invalid register address
		movfw	CONFIG_D0
		sublw	MAX_REGISTER
		bnc		rtbc_next_layer
; set up register address
		call	point_to_d0_address
; check for overflow -- use ANALOG_INPUT temproarily
		movfw	INDF
		movwf	ANALOG_INPUT
		movfw	CONFIG_D1
		addwf	ANALOG_INPUT,f
		btfsc	ANALOG_INPUT,7
		goto	rtbc_next_layer
; commit increment
		movfw	ANALOG_INPUT
		movwf	INDF
		goto	rtbc_next_layer

rtbc_check_decrement
		movlw	0x71
		subwf	CONFIG_MODE,w
		bnz		rtbc_check_store_value
; check for invalid register address
		movfw	CONFIG_D0
		sublw	MAX_REGISTER
		bnc		rtbc_next_layer
; set up register address
		call	point_to_d0_address
; check for overflow -- use ANALOG_INPUT temproarily
		movfw	INDF
		movwf	ANALOG_INPUT
		movfw	CONFIG_D1
		subwf	ANALOG_INPUT,f
		btfsc	ANALOG_INPUT,7
		goto	rtbc_next_layer
; commit decrement
		movfw	ANALOG_INPUT
		movwf	INDF
		goto	rtbc_next_layer

rtbc_check_store_value
		movlw	0x74
		subwf	CONFIG_MODE,w
		bnz		rtbc_check_bit_op
; check for invalid register address
		movfw	CONFIG_D0
		sublw	MAX_REGISTER
		bnc		rtbc_next_layer
; set up register address
		call	point_to_d0_address
		movfw	CONFIG_D1
		movwf	INDF
		goto	rtbc_next_layer

rtbc_check_bit_op
		movlw	0x76
		subwf	CONFIG_MODE,w
		bnz		rtbc_mode_not_matched
; check for invalid register address
		movfw	CONFIG_D0
		sublw	MAX_REGISTER
		bnc		rtbc_next_layer
; set up register address
		call	point_to_d0_address
; set up bitmask
		movlw	B'00000001'
		movwf	BITMASK
; mask to counter
		movlw	B'00000111'
		andwf	CONFIG_D1,w
		bz		rtbc_check_bit_op_loop_skip
		movwf	TEMP5
; shift to correct bit
rtbc_check_bit_op_loop
		bcf		STATUS,C
		rlf		BITMASK,f
		decfsz	TEMP5,f
		goto	rtbc_check_bit_op_loop
rtbc_check_bit_op_loop_skip
		btfsc	CONFIG_D1,3
		goto	rtbc_check_bit_op_set
		btfss	CONFIG_D1,4
		goto	rtbc_check_bit_op_clear
rtbc_check_bit_op_toggle
		movfw	BITMASK
		andwf	INDF,w
		bz		rtbc_check_bit_op_set
rtbc_check_bit_op_clear
		comf	BITMASK,w
		andwf	INDF,f
		goto	rtbc_next_layer
rtbc_check_bit_op_set
		movfw	BITMASK
		iorwf	INDF,f
		goto	rtbc_next_layer

rtbc_mode_not_matched
		goto	read_trigger_bit_next
rtbc_get_data
; use literal value for D1
		movfw	CONFIG_D1
		movwf	LOCAL_D1
; if necessary overwrite with value from address
		btfsc	CONFIG_MODE,1
		call	load_d1_from_address
rtbc_get_data_d0_only
; use literal value for D0
		movfw	CONFIG_D0
		movwf	LOCAL_D0
; if necessary overwrite with value from address
		btfsc	CONFIG_MODE,0
		call	load_d0_from_address
rtbc_get_channel
		call	combine_channel_with_status
; send message
		call	send_midi_local

rtbc_next_layer
		pagesel	process_inbound_midi
		call	process_inbound_midi
		pagesel	read_logic_inputs
; bail out if relevant sysex message comes in.
		btfsc	STATE_FLAGS,2
		return
		incf	CONFIG_LAYER,f
		decfsz	COUNTER_L,f
		goto	rtbc_layer_loop

read_trigger_bit_unchanged
		rrf		TEMP,f
read_trigger_bit_next
; if we were working with a rising edge, subtract 24 back out of OUTPUT_COUNTER
		movlw	D'24'
		subwf	OUTPUT_COUNTER,w
		bnc		read_trigger_bit_next_a
		movlw	D'24'
		subwf	OUTPUT_COUNTER,f
; next bit
read_trigger_bit_next_a
; advance bitmask
;		bcf		STATUS,C
;		rlf		BITMASK,f
		rrf		TEMP3,f
; next pin
		incf	OUTPUT_COUNTER,f
		decfsz	COUNTER_H,f
		goto	read_trigger_bit

		return




; =================================
;
; handle changes to block of 4 encoder input pairs
; input variables (munged):
;   TEMP: new input states
;   TEMP2: changed bit flags
;   TEMP3: old input states
;   OUTPUT_COUNTER: first output number
;	ANALOG_INPUT: points to first encoder stored value
;
; =================================

read_encoder_byte
		movlw	B'00000001'
		movwf	BITMASK
		bcf		STATE_FLAGS,6
		bcf		STATUS,IRP
		clrf	CONFIG_LAYER
		movlw	D'4'
		movwf	COUNTER_H
reb_loop
; check the pin config
; encoder modes are B'0001xxxx'
		call	read_pin_config
		movlw	B'11110000'
		andwf	CONFIG_MODE,w
		sublw	B'00010000'
		bnz		reb_next
; load previous value into LOCAL_D0 for continuous note mode
		movfw	ANALOG_INPUT
		movwf	FSR
		bcf		STATUS,IRP
		movfw	INDF
		movwf	LOCAL_D0
; check pair for changes
		movlw	B'00000011'
		andwf	TEMP2,w
		bz		reb_no_change
; check pair 0,1 for zero state
		comf	TEMP,w
		andlw	B'00000011'
		bnz		reb_no_change

reb_check_continuous_note_off
		movlw	B'00001110'
		andwf	CONFIG_MODE,w
		bnz		reb_check_other

reb_check_cn_off_note_flag
; is there a note flag?  then send note-off
		movfw	TEMP_REG
		addlw	D'6'
		movwf	FSR
		bsf		STATUS,IRP
		movfw	BITMASK
		andwf	INDF,f
		bz		reb_check_other
; clear the note flag
		comf	BITMASK,w
		andwf	INDF,f
; (note number loaded to LOCAL_D0 above)
		movlw	0x90
		movwf	LOCAL_STATUS
		clrf	LOCAL_D1
		call	combine_channel_with_status
		call	send_midi_local

; increment/decrement the value
reb_check_other
; point to the encoder stored value
		movfw	ANALOG_INPUT
		movwf	FSR
		bcf		STATUS,IRP
; if already at maximum, skip any increment
		movlw	0x7F
		subwf	INDF,w
		bz		reb_co_ccw
; check for clockwise rotation
		btfss	TEMP3,0
		incf	INDF,f
reb_co_ccw
; if already at zero, skip any decrement
		movf	INDF,f
		bz		reb_check_other_mode
; check for counter-clockwise rotation
		btfss	TEMP3,1
		decf	INDF,f

reb_check_other_mode
reb_check_continuous_note_on
		movlw	B'00001110'
		andwf	CONFIG_MODE,w
		bnz		reb_check_controller
reb_check_cn_gate_flag
; is there a gate flag? then send note on
		movfw	TEMP_REG
		movwf	FSR
		bsf		STATUS,IRP
		movfw	BITMASK
		andwf	INDF,w
		bz		reb_next
; set the note flag
		movlw	D'6'
		addwf	FSR,f
		movfw	BITMASK
		iorwf	INDF,f
; prepare for note-on
		movfw	ANALOG_INPUT
		movwf	FSR
		bcf		STATUS,IRP
; note number D0 from encoder data
		movfw	INDF
		movwf	LOCAL_D0
; assume literal velocity D1 from config
		movfw	CONFIG_D1
		movwf	LOCAL_D1
; overwrite with register value if necessary
		btfsc	CONFIG_MODE,0
		call	load_d1_from_address
		movlw	0x90
		movwf	LOCAL_STATUS
		call	combine_channel_with_status
		call	send_midi_local
		goto	reb_next

reb_check_controller
; point FSR to encoder data value
		movfw	ANALOG_INPUT
		movwf	FSR
		bcf		STATUS,IRP
; check mode
		movlw	B'00001010'
		andwf	CONFIG_MODE,w
		bnz		reb_check_program_change
		movlw	0xB0
		movwf	LOCAL_STATUS
		call	combine_channel_with_status
; use literal value for D0
		movfw	CONFIG_D0
		movwf	LOCAL_D0
; if necessary overwrite with value from address
		btfsc	CONFIG_MODE,0
		call	load_d0_from_address
;		movfw	INDF
;		movwf	LOCAL_D1
		call	load_d1_from_address
		call	send_midi_local
		goto	reb_next

reb_check_program_change
		movlw	B'00001001'
		andwf	CONFIG_MODE,w
		bnz		reb_check_channel_pressure
		movlw	0xC0
		movwf	LOCAL_STATUS
		goto	reb_send_generic
reb_check_channel_pressure
		movlw	B'00001000'
		andwf	CONFIG_MODE,w
		bnz		reb_check_matrix_velocity
		movlw	0xD0
		movwf	LOCAL_STATUS
		goto	reb_send_generic

reb_check_matrix_velocity
		movlw	0x1A
		subwf	CONFIG_MODE,w
		bnz		reb_check_cc_on_value
		movfw	INDF
		banksel	MATRIX_VELOCITY
		movwf	MATRIX_VELOCITY
		banksel	PORTA
		goto	reb_next

reb_check_cc_on_value
		movlw	0x1B
		subwf	CONFIG_MODE,w
		bnz		reb_check_cc_off_value
		movfw	INDF
		banksel	CC_ON_VALUE
		movwf	CC_ON_VALUE
		banksel	PORTA
		goto	reb_next

reb_check_cc_off_value
		movlw	0x1C
		subwf	CONFIG_MODE,w
		bnz		reb_next
		movfw	INDF
		banksel	CC_OFF_VALUE
		movwf	CC_OFF_VALUE
		banksel	PORTA
		goto	reb_next

reb_send_generic
		call	combine_channel_with_status
;		movfw	INDF
;		movwf	LOCAL_D0
		call	load_d0_from_address
		call	send_midi_local
		goto	reb_next

reb_no_change
; continuous note mode?
		movlw	B'11101110'
		andwf	CONFIG_MODE,w
		bnz		reb_next
; status 0x90 for sure
		movlw	0x90
		movwf	LOCAL_STATUS
; check for continuous note gate/note mismatch
reb_no_change_cn_gate
; check gate flag
		movfw	TEMP_REG
		movwf	FSR
		bsf		STATUS,IRP
		movfw	BITMASK
		andwf	INDF,w
		bz		reb_no_change_cn_note
; gate is on.  if note is off, send a note-on message.
		movlw	D'6'
		addwf	FSR,f
		movfw	BITMASK
		andwf	INDF,w
		bnz		reb_next
; send note-on
; set the note_flag
		movfw	BITMASK
		iorwf	INDF,f
; LOCAL_D0 should already be loaded and ready to go.
; use literal for D1
		movfw	CONFIG_D1
		movwf	LOCAL_D1
; overwrite with register value if necessary
		btfsc	CONFIG_MODE,0
		call	load_d1_from_address
		call	combine_channel_with_status
		call	send_midi_local
		goto	reb_next

reb_no_change_cn_note
; gate is off.  if note is on, send a note-off message.
		movlw	D'6'
		addwf	FSR,f
		movfw	BITMASK
		andwf	INDF,w
		bz		reb_next
; clear the note flag
		comf	BITMASK,w
		andwf	INDF,f
; LOCAL_D0 should already be loaded and ready to go.
		clrf	LOCAL_D1
		call	combine_channel_with_status
		call	send_midi_local

reb_next
		bcf		STATUS,C
		rlf		BITMASK,f
		bcf		STATUS,C
		rlf		BITMASK,f
		rrf		TEMP,f
		rrf		TEMP,f
		rrf		TEMP2,f
		rrf		TEMP2,f
		rrf		TEMP3,f
		rrf		TEMP3,f
		incf	OUTPUT_COUNTER,f
		incf	OUTPUT_COUNTER,f
		incf	ANALOG_INPUT,f
		decfsz	COUNTER_H,f
		goto	reb_loop

		return

		end
