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
		GLOBAL	combine_channel_with_status
		GLOBAL	load_d0_from_address
		GLOBAL	load_d1_from_address
		GLOBAL	add_to_d0_from_d1_address
		GLOBAL	point_to_d0_address

config_utils	code	0x0EB0
;config_utils	code

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
; Use relative address in CONFIG_D0
; Load value into LOCAL_D0
;
; =================================

load_d0_from_address
		movfw	CONFIG_D0
		addlw	0x20
		movwf	FSR
		bcf		STATUS,IRP
		movfw	INDF
		movwf	LOCAL_D0
; make sure we don't accidentally create a status byte
		bcf		LOCAL_D0,7
		return

; =================================
;
; Use relative address in CONFIG_D1
; Load value into LOCAL_D1
;
; =================================

load_d1_from_address
		movfw	CONFIG_D1
		addlw	0x20
		movwf	FSR
		bcf		STATUS,IRP
		movfw	INDF
		movwf	LOCAL_D1
; make sure we don't accidentally create a status byte
		bcf		LOCAL_D1,7
		return

; =================================
;
; Use "OUTPUT_COUNTER" and return the address of the
; corresponding analog data register in W
;
; =================================

get_analog_data_address
		movlw	D'8'
		subwf	OUTPUT_COUNTER,w
		btfsc	STATUS,C
		goto	gada_go
; invalid output (<8) so exit
		movlw	ANALOG_0
		return

gada_go
; Use the map in data EEPROM to calculate the address.
		addlw	PROM_ANALOG_DATA_MAP
		banksel	EEADR
		movwf	EEADR
		banksel	EECON1
		bcf		EECON1,EEPGD
		bsf		EECON1,RD
		banksel	EEDAT
		movfw	EEDAT
		banksel	PORTA
		addlw	ANALOG_0
		return

; =================================
;
; Setup up FSR/INDF as D0 register address
;
; =================================
point_to_d0_address
; set up FSR
		movfw	CONFIG_D0
		addlw	0x20
		movwf	FSR
		bcf		STATUS,IRP
		return

; =================================
;
; Use relative address in CONFIG_D1
; Add value into LOCAL_D0
;
; =================================
add_to_d0_from_d1_address
		movfw	CONFIG_D1
		addlw	0x20
		movwf	FSR
		bcf		STATUS,IRP
		movfw	INDF
		addwf	LOCAL_D0,f
; make sure we don't accidentally create a status byte
		bcf		LOCAL_D0,7
		return


		

		end
