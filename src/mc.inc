; MIDI CPU
; copyright John Staskevich, 2017
; john@codeandcopper.com
;
; This work is licensed under a Creative Commons Attribution 4.0 International License.
; http://creativecommons.org/licenses/by/4.0/
;
; mc.inc
;
; Main include file.
;

; =================================
;
; Functions
;
; =================================

;	EXTERN	isr


; =================================
;
; Variables
;
; =================================

	EXTERN	DIGITAL_0
	EXTERN	DIGITAL_1
	EXTERN	DIGITAL_2
; Analog input states (14)
	EXTERN	ANALOG_0
	EXTERN	ANALOG_1
	EXTERN	ANALOG_2
	EXTERN	ANALOG_3
	EXTERN	ANALOG_4
	EXTERN	ANALOG_5
	EXTERN	ANALOG_6
	EXTERN	ANALOG_7
	EXTERN	ANALOG_8
	EXTERN	ANALOG_9
	EXTERN	ANALOG_10
	EXTERN	ANALOG_11
	EXTERN	ANALOG_12
	EXTERN	ANALOG_13
; Switch matrix input states (24)
	EXTERN	KEYS_0
; Encoder input states (12)
	EXTERN	ENCODER_0
	EXTERN	ENCODER_1
	EXTERN	ENCODER_2
	EXTERN	ENCODER_3
	EXTERN	ENCODER_4
	EXTERN	ENCODER_5
	EXTERN	ENCODER_6
	EXTERN	ENCODER_7
	EXTERN	ENCODER_8
	EXTERN	ENCODER_9
	EXTERN	ENCODER_10
	EXTERN	ENCODER_11
; Locally generated outbound message
	EXTERN	LOCAL_STATUS
	EXTERN	LOCAL_D0
	EXTERN	LOCAL_D1	
; Outbound MIDI byte
	EXTERN	OUTBOUND_BYTE
; SysEx Message Identifier
	EXTERN	SYSEX_TYPE

; STATE_FLAGS
; Various flags for operation
; Bit - Meaning
; 0 - Inbound Message Incomplete
; 1 - Sysex Header Relevant
; 2 - Input processing registers munged
; 3 - Firmware Update Mode (isr selector)
; 4 - Analog Data Valid
; 5 - External Reference Voltage
; 6 - CONFIG Transition (TT = 0 or 1)
; 7 - Sync Run State (0 = stopped, 1 = running)
	EXTERN	STATE_FLAGS

; STATE_FLAGS_2
; Various flags for operation
; Bit - Meaning
; 0 - Active Sense On/Off
	EXTERN	STATE_FLAGS_2

; Pointer to transpose value
	EXTERN	TRANSPOSE_REG

; More temp regs
	EXTERN	TEMP7

; LED Stuff
	EXTERN	LED_ACTIVE_SELNUM
	EXTERN	LED_ACTIVE_SELBIT
	EXTERN	LED_DATA_FLAGS
	EXTERN	LED_SELECT_FLAGS

; Counter to scale Timer 2
	EXTERN	T2_COUNTER

	EXTERN	PCLATH_STORAGE

	EXTERN	INBOUND_STATUS
	EXTERN	OUTBOUND_STATUS
	EXTERN	INBOUND_BYTECOUNT
	EXTERN	COUNTER_H
	EXTERN	COUNTER_L
	EXTERN	ANALOG_INPUT
	EXTERN	TEMP5
	EXTERN	TEMP6

; MIDI Receive Buffer
	EXTERN	RX_MIDI_BYTE
	EXTERN	RX_BUFFER_HEAD
	EXTERN	RX_BUFFER_TAIL
	EXTERN	RX_BUFFER_GAUGE
	EXTERN	RX_BUFFER

; Common-use variables accessible from any bank
	EXTERN	W_STORAGE
	EXTERN	FSR_STORAGE
	EXTERN	STATUS_STORAGE
	EXTERN	TEMP		
	EXTERN	TEMP2		
	EXTERN	TEMP3		
	EXTERN	TEMP4		
	EXTERN	CONFIG_MODE	
	EXTERN	CONFIG_CHANNEL
	EXTERN	CONFIG_D0	
	EXTERN	CONFIG_D1	
	EXTERN	OUTPUT_COUNTER
	EXTERN	CONFIG_LAYER
	EXTERN	TEMP_REG
	EXTERN	BITMASK		
; temp IM for use with non-interrupt code only
	EXTERN	TEMP_IM		

; Bank 1 variables
	EXTERN	FIRMWARE_BUFFER
	EXTERN	ANALOG_THRESHOLD
	EXTERN	MATRIX_VELOCITY
	EXTERN	INCOMING_SYSEX_A

; Bank 2 variables
	EXTERN	SYSEX_YY	
	EXTERN	SYSEX_NN	
	EXTERN	SYSEX_TT	
	EXTERN	SYSEX_MM	
	EXTERN	SYSEX_CH	
	EXTERN	SYSEX_D0	
	EXTERN	SYSEX_D1	

	EXTERN	ANALOG_CN_GATES_0
	EXTERN	ANALOG_CN_GATES_1
	EXTERN	ANALOG_CN_GATES_2
	EXTERN	ENCODER_CN_GATES_0
	EXTERN	ENCODER_CN_GATES_1
	EXTERN	ENCODER_CN_GATES_2
	EXTERN	ANALOG_CN_NOTES_0
	EXTERN	ANALOG_CN_NOTES_1
	EXTERN	ANALOG_CN_NOTES_2
	EXTERN	ENCODER_CN_NOTES_0
	EXTERN	ENCODER_CN_NOTES_1
	EXTERN	ENCODER_CN_NOTES_2

	EXTERN	CC_ON_VALUE
	EXTERN	CC_OFF_VALUE

	EXTERN	INCOMING_SYSEX_B

; Bank 3 variables
	EXTERN	KEY_TOGGLES	
	EXTERN	LOGIC_TOGGLES_0
	EXTERN	LOGIC_TOGGLES_1
	EXTERN	LOGIC_TOGGLES_2
	EXTERN	INCOMING_SYSEX_C


; =================================
;
; Constants
;
; =================================

T2_SCALE		equ	0x08
RX_BUFFER_SIZE	equ	D'8'
RX_POINTER_MASK	equ	B'00000111'
MAX_REGISTER	equ	0x1C

SYSEX_MAX_YY	equ	0x03
SYSEX_MAX_NN	equ	0x17
SYSEX_MAX_TT	equ	0x01
SYSEX_MAX_TYPE	equ	0x7F

; types of sysex config messages.  type byte follows device id.
SYSEX_DUMP				equ	0x00
SYSEX_CT_CONFIG			equ	0x01
SYSEX_MATRIX_VELOCITY	equ	0x02
SYSEX_CC_ON				equ	0x03
SYSEX_ENCODER_INIT		equ	0x04
SYSEX_NOTE_MAP			equ	0x05
SYSEX_NOTE_MAP_RESET	equ	0x06
SYSEX_DATA_BUFFER		equ	0x07
SYSEX_ANALOG_THRESHOLD	equ	0x08

; =================================
;
; EEPROM address constants
;
; =================================

PROM_VERSION			equ	0x00
PROM_CHECKSUM			equ	0x01
PROM_ANALOG_THRESHOLD	equ	0x03
PROM_ANALOG_SMOOTHING	equ	0x04
PROM_VREF				equ	0x05
PROM_MATRIX_VELOCITY	equ	0x06
PROM_CC_ON				equ	0x07
PROM_CC_OFF				equ	0x08
PROM_ACTIVE_SENSE		equ	0x09
PROM_ENCODER_INIT		equ	0x0A
PROM_DATAMASKS			equ	0x16
PROM_ANALOG_DATA_MAP	equ	0x25
PROM_TRANSPOSE_REG		equ	0x7E
PROM_REMAP_FLAGS		equ	0x7F
PROM_NOTE_MAP			equ	0x80

