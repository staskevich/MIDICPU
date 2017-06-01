; MIDI CPU
; copyright John Staskevich, 2017
; john@codeandcopper.com
;
; This work is licensed under a Creative Commons Attribution 4.0 International License.
; http://creativecommons.org/licenses/by/4.0/
;
; configutils.asm
;
; Functions for working with MIDI CPU config stored in EEPROM.
;
		list		p=16f887
   		#include	<p16f887.inc>

   		#include	<mc.inc>


; ==================================================================
;
; Global Functions
;
; ==================================================================

		GLOBAL	read_pin_config
		GLOBAL	read_reg_config
		GLOBAL	combine_channel_with_status
		GLOBAL	load_d0_from_address
		GLOBAL	load_d1_from_address
		GLOBAL	add_to_d0_from_d1_address
		GLOBAL	point_to_d0_address

; config_utils	code	0x0EB0
config_utils	code

; =================================
;
; formulate midi status based on channel setting
;
; =================================

combine_channel_with_status
		movf	CONFIG_CHANNEL,f
		bz		combine_jumpers_with_status
; use literal channel from config
		decf	CONFIG_CHANNEL,w
; mask off any bogus channel numbers
		andlw	B'00001111'
		iorwf	LOCAL_STATUS,f
		return
combine_jumpers_with_status
; use jumper channel setting
		comf	PORTC,w
		andlw	B'00001111'
		iorwf	LOCAL_STATUS,f
		return

; =================================
;
; read pin config specified by OUTPUT_COUNTER, (STATE_FLAGS,6) and CONFIG_LAYER
; return config in CONFIG_MODE, CONFIG_CHANNEL, CONFIG_D0 and CONFIG_D1
;
; munged: EEADR, EEADRH
; =================================

read_pin_config

		banksel	EEADR

		movfw	CONFIG_LAYER
		sublw	0x03
		bz		read_pin_config_l3
		movfw	CONFIG_LAYER
		sublw	0x02
		bz		read_pin_config_l2
		movfw	CONFIG_LAYER
		sublw	0x01
		bz		read_pin_config_l1

read_pin_config_l0
		movlw	0x1C
		movwf	EEADRH
		clrf	EEADR
		goto	read_pin_config_get
read_pin_config_l1
		movlw	0x1C
		movwf	EEADRH
		movlw	0xC0
		movwf	EEADR
		goto	read_pin_config_get
read_pin_config_l2
		movlw	0x1D
		movwf	EEADRH
		movlw	0x80
		movwf	EEADR
		goto	read_pin_config_get
read_pin_config_l3
		movlw	0x1E
		movwf	EEADRH
		movlw	0x40
		movwf	EEADR

read_pin_config_get
; add in the offset for control terminal number
; each config occupies 4 words
		movfw	OUTPUT_COUNTER
		addwf	EEADR,f
		btfsc	STATUS,C
		incf	EEADRH,f

		movfw	OUTPUT_COUNTER
		addwf	EEADR,f
		btfsc	STATUS,C
		incf	EEADRH,f

		movfw	OUTPUT_COUNTER
		addwf	EEADR,f
		btfsc	STATUS,C
		incf	EEADRH,f

		movfw	OUTPUT_COUNTER
		addwf	EEADR,f
		btfsc	STATUS,C
		incf	EEADRH,f

; add in an offset of 96 for tt=1
		btfss	STATE_FLAGS,6
		goto	read_pin_config_get_mode

		movlw	D'96'
		addwf	EEADR,f
		btfsc	STATUS,C
		incf	EEADRH,f

read_pin_config_get_mode
; mode
		banksel	EECON1
		bsf		EECON1,EEPGD
		bsf		EECON1,RD
		nop
		nop
		banksel	EEDAT
		movfw	EEDAT
		movwf	CONFIG_MODE
		bcf		CONFIG_MODE,7
; channel
		banksel	EEADR
		incf	EEADR,f
		banksel	EECON1
		bsf		EECON1,RD
		nop
		nop
		banksel	EEDAT
		movfw	EEDAT
		movwf	CONFIG_CHANNEL
		bcf		CONFIG_CHANNEL,7
; d0
		banksel	EEADR
		incf	EEADR,f
		banksel	EECON1
		bsf		EECON1,RD
		nop
		nop
		banksel	EEDAT
		movfw	EEDAT
		movwf	CONFIG_D0
		bcf		CONFIG_D0,7
; d1
		banksel	EEADR
		incf	EEADR,f
		banksel	EECON1
		bsf		EECON1,RD
		nop
		nop
		banksel	EEDAT
		movfw	EEDAT
		movwf	CONFIG_D1
		bcf		CONFIG_D1,7

		banksel	PORTA

		return

; =================================
;
; Use register address in REG_ADDRESS
;
; Where applicable, load info into REG_RR, REG_MIN and REG_MAX
;
; WARNING: REG_ADDRESS and FSR will be modified if REG_ADDRESS
;    points to indirect register
;
; =================================
read_reg_config
; check for indirect address
		movfw	REG_ADDRESS
		sublw	INDIRECT_ADDRESS
		bnz	read_reg_config_direct
; indirect.  get config for pointed register
		movfw	INDIRECT_POINTER
		movwf	REG_ADDRESS
read_reg_config_direct
; check for invalid address
; if invalid, don't worry about what's in the reg config variables
		movfw	REG_ADDRESS
		sublw	MAX_REGISTER
		btfss	STATUS,C
		return
; replace with null register if necessary
; RR
; Ignore address less than 0x11
		movlw	0x11
		subwf	REG_ADDRESS,w
		bnc		read_reg_config_minmax
		addlw	PROM_REGISTER_INIT
		bsf		STATUS,RP1
		movwf	EEADR
		bsf		STATUS,RP0
		bcf		EECON1,EEPGD
		bsf		EECON1,RD
		bcf		STATUS,RP0
		movlw	0x01
		btfss	EEDAT,7
		clrw
		bcf		STATUS,RP1
		movwf	REG_RR
read_reg_config_minmax
; Min
; Ignore address less than 0x03
		movlw	0x03
		subwf	REG_ADDRESS,w
		btfss	STATUS,C
		return
		addlw	PROM_REGISTER_MIN
		bsf		STATUS,RP1
		movwf	EEADR
		bsf		STATUS,RP0
		bcf		EECON1,EEPGD
		bsf		EECON1,RD
		bcf		STATUS,RP0
		movfw	EEDAT
		bcf		STATUS,RP1
		movwf	REG_MIN
; Max
		bsf		STATUS,RP1
		movlw	NUM_MINMAX_REGS
		addwf	EEADR,f
		bsf		STATUS,RP0
;		bcf		EECON1,EEPGD
		bsf		EECON1,RD
		bcf		STATUS,RP0
		movfw	EEDAT
		bcf		STATUS,RP1
		movwf	REG_MAX

		return

; =================================
;
; Use relative address in CONFIG_D0
; Load value into LOCAL_D0
;
; =================================

load_d0_from_address
		movfw	CONFIG_D0
		sublw	INDIRECT_ADDRESS
		bnz	load_d0_from_address_direct
load_d0_from_address_indirect
		movfw	INDIRECT_POINTER
		goto	load_d0_from_address_go
load_d0_from_address_direct
		movfw	CONFIG_D0
load_d0_from_address_go
		addlw	0x20
		movwf	FSR
		bcf	STATUS,IRP
		movfw	INDF
		movwf	LOCAL_D0
; make sure we don't accidentally create a status byte
		bcf	LOCAL_D0,7
		return

; =================================
;
; Use relative address in CONFIG_D1
; Load value into LOCAL_D1
;
; =================================

load_d1_from_address
		movfw	CONFIG_D1
		sublw	INDIRECT_ADDRESS
		bnz	load_d1_from_address_direct
load_d1_from_address_indirect
		movfw	INDIRECT_POINTER
		goto	load_d1_from_address_go
load_d1_from_address_direct
		movfw	CONFIG_D1
load_d1_from_address_go
		addlw	0x20
		movwf	FSR
		bcf	STATUS,IRP
		movfw	INDF
		movwf	LOCAL_D1
; make sure we don't accidentally create a status byte
		bcf	LOCAL_D1,7
		return

; =================================
;
; Setup up FSR/INDF as D0 register address
;
; =================================

point_to_d0_address
		movfw	CONFIG_D0
		sublw	INDIRECT_ADDRESS
		bnz	point_to_d0_address_direct
point_to_d0_address_indirect
		movfw	INDIRECT_POINTER
		goto	point_to_d0_address_check
point_to_d0_address_direct
		movfw	CONFIG_D0
point_to_d0_address_check
		movwf	FSR
; check for invalid address
		sublw	MAX_REGISTER
		bc	point_to_d0_address_finish
; insert null address so nothing bad happens
		movlw	NULL_ADDRESS
		movwf	FSR
point_to_d0_address_finish
		movlw	0x20
		addwf	FSR,f
		bcf	STATUS,IRP
		return

; =================================
;
; Use relative address in CONFIG_D1
; Add value into LOCAL_D0
;
; =================================
add_to_d0_from_d1_address
		movfw	CONFIG_D1
		sublw	INDIRECT_ADDRESS
		bnz	atd0fd1a_direct
atd0fd1a_indirect
		movfw	INDIRECT_POINTER
		goto	atd0fd1a_go
atd0fd1a_direct
		movfw	CONFIG_D1
atd0fd1a_go
		addlw	0x20
		movwf	FSR
		bcf	STATUS,IRP
		movfw	INDF
		addwf	LOCAL_D0,f
; make sure we don't accidentally create a status byte
		bcf	LOCAL_D0,7
		return

; =================================
;
; Use "OUTPUT_COUNTER" and return the address of the
; corresponding analog data register in W
;
; =================================

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; code should be manually placed to avoid wrap condition with PCL
get_analog_data_add_code	code	0x0FE8
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
get_analog_data_address
		movlw	HIGH	get_analog_data_address
		movwf	PCLATH
		movlw	D'8'
		subwf	OUTPUT_COUNTER,w
		btfsc	STATUS,C
		goto	gada_go
; invalid output (<8) so exit
		movlw	ANALOG_0
		return
gada_go
		retlw	ANALOG_12
		retlw	ANALOG_10
		retlw	ANALOG_8
		retlw	ANALOG_9
		retlw	ANALOG_11
		retlw	ANALOG_13
		retlw	ANALOG_0
		retlw	ANALOG_0
		retlw	ANALOG_0
		retlw	ANALOG_1
		retlw	ANALOG_2
		retlw	ANALOG_3
		retlw	ANALOG_4
		retlw	ANALOG_5
		retlw	ANALOG_6
		retlw	ANALOG_7



		end
