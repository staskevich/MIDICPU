; MIDI CPU
; copyright John Staskevich, 2017
; john@codeandcopper.com
;
; This work is licensed under a Creative Commons Attribution 4.0 International License.
; http://creativecommons.org/licenses/by/4.0/
;
; varibles.asm
;
; Global variables.
;
		list		p=16f887
   		#include	<p16f887.inc>

; =================================
;
; Variables
;
; =================================

gpr0	udata	0x20

; Digital input states (3)
	global	DIGITAL_0, DIGITAL_1, DIGITAL_2
DIGITAL_0		res	1
DIGITAL_1		res	1
DIGITAL_2		res	1
; Analog input states (14)
	global	ANALOG_0, ANALOG_1, ANALOG_2, ANALOG_3, ANALOG_4, ANALOG_5, ANALOG_6, ANALOG_7, ANALOG_8, ANALOG_9, ANALOG_10, ANALOG_11, ANALOG_12, ANALOG_13
ANALOG_0		res	1
ANALOG_1		res	1
ANALOG_2		res	1
ANALOG_3		res	1
ANALOG_4		res	1
ANALOG_5		res	1
ANALOG_6		res	1
ANALOG_7		res	1
ANALOG_8		res	1
ANALOG_9		res	1
ANALOG_10		res	1
ANALOG_11		res	1
ANALOG_12		res	1
ANALOG_13		res	1
; Encoder input states (12)
	global	ENCODER_0, ENCODER_1, ENCODER_2, ENCODER_3, ENCODER_4, ENCODER_5, ENCODER_6, ENCODER_7, ENCODER_8, ENCODER_9, ENCODER_10, ENCODER_11
ENCODER_0		res	1
ENCODER_1		res	1
ENCODER_2		res	1
ENCODER_3		res	1
ENCODER_4		res	1
ENCODER_5		res	1
ENCODER_6		res	1
ENCODER_7		res	1
ENCODER_8		res	1
ENCODER_9		res	1
ENCODER_10		res	1
ENCODER_11		res	1
; Switch matrix input states (24)
	global	KEYS_0
KEYS_0			res	D'24'

; Locally generated outbound message
	global	LOCAL_STATUS, LOCAL_D0, LOCAL_D1
LOCAL_STATUS	res	1
LOCAL_D0		res	1
LOCAL_D1		res	1
; Outbound MIDI byte
	global	OUTBOUND_BYTE
OUTBOUND_BYTE	res	1
; SysEx Message Identifier
	global	SYSEX_TYPE, TEMP_REG
SYSEX_TYPE		res	1
TEMP_REG		res	1


; Context storage for paging
	global	PCLATH_STORAGE
PCLATH_STORAGE		res	1

	global	INBOUND_STATUS, OUTBOUND_STATUS, INBOUND_BYTECOUNT, COUNTER_H, COUNTER_L, ANALOG_INPUT, TEMP5, TEMP6
INBOUND_STATUS		res	1
OUTBOUND_STATUS		res	1
INBOUND_BYTECOUNT	res	1
COUNTER_H			res	1
COUNTER_L			res 1
ANALOG_INPUT		res 1
TEMP5				res	1
TEMP6				res	1

; MIDI Receive Buffer
	global	RX_MIDI_BYTE, RX_BUFFER_HEAD, RX_BUFFER_TAIL, RX_BUFFER_GAUGE
	global	STATE_FLAGS_2, TRANSPOSE_REG
RX_MIDI_BYTE	res	1
RX_BUFFER_HEAD	res	1
RX_BUFFER_TAIL	res	1
RX_BUFFER_GAUGE	res	1
STATE_FLAGS_2	res	1
TRANSPOSE_REG	res	1

; More temp regs
	global	TEMP7
TEMP7		res	1

; Reserved for future use
ANOTHER_PLACEHOLDER	res	0x05

; Common-use variables accessible from any bank
	global	W_STORAGE, FSR_STORAGE, STATUS_STORAGE, TEMP, TEMP2, TEMP3, TEMP4, CONFIG_MODE, CONFIG_CHANNEL, CONFIG_D0, CONFIG_D1, OUTPUT_COUNTER, CONFIG_LAYER, STATE_FLAGS, BITMASK, TEMP_IM
gprnobnk	udata_shr	0x70
W_STORAGE		res	1
FSR_STORAGE		res	1
STATUS_STORAGE	res	1
TEMP			res	1
TEMP2			res	1
TEMP3			res	1
TEMP4			res	1
CONFIG_MODE		res	1
CONFIG_CHANNEL	res	1
CONFIG_D0		res	1
CONFIG_D1		res	1
OUTPUT_COUNTER	res	1
CONFIG_LAYER	res	1
BITMASK			res	1
; temp IM for use with process_midi code only
TEMP_IM			res	1
; STATE_FLAGS
; Various flags for operation
STATE_FLAGS		res	1

; Bank 1 variables
	global	FIRMWARE_BUFFER, INCOMING_SYSEX_A, LED_ACTIVE_SELNUM, LED_ACTIVE_SELBIT, LED_DATA_FLAGS, LED_SELECT_FLAGS, T2_COUNTER, ANALOG_THRESHOLD, MATRIX_VELOCITY
gpr1	udata	0xA0
FIRMWARE_BUFFER		res	D'1'
PLACEHOLDER_GPR1	res	D'8'
LED_ACTIVE_SELNUM	res	1
LED_ACTIVE_SELBIT	res	1
LED_DATA_FLAGS		res	1
LED_SELECT_FLAGS	res	1
T2_COUNTER			res	1
ANALOG_THRESHOLD	res	1
MATRIX_VELOCITY		res	1
INCOMING_SYSEX_A	res	D'64'

; Bank 2 variables
	global	SYSEX_YY, SYSEX_NN, SYSEX_TT, SYSEX_MM, SYSEX_CH, SYSEX_D0, SYSEX_D1
gpr2	udata	0x110
SYSEX_YY			res	1
SYSEX_NN			res	1
SYSEX_TT			res	1
SYSEX_MM			res	1
SYSEX_CH			res	1
SYSEX_D0			res	1
SYSEX_D1			res	1

	global	ANALOG_CN_GATES_0
	global	ANALOG_CN_GATES_1
	global	ANALOG_CN_GATES_2
ANALOG_CN_GATES_0	res	1
ANALOG_CN_GATES_1	res	1
ANALOG_CN_GATES_2	res	1

	global	ENCODER_CN_GATES_0, ENCODER_CN_GATES_1, ENCODER_CN_GATES_2
ENCODER_CN_GATES_0	res	1
ENCODER_CN_GATES_1	res	1
ENCODER_CN_GATES_2	res	1

	global	ANALOG_CN_NOTES_0
	global	ANALOG_CN_NOTES_1
	global	ANALOG_CN_NOTES_2
ANALOG_CN_NOTES_0	res	1
ANALOG_CN_NOTES_1	res	1
ANALOG_CN_NOTES_2	res	1

	global	ENCODER_CN_NOTES_0, ENCODER_CN_NOTES_1, ENCODER_CN_NOTES_2
ENCODER_CN_NOTES_0	res	1
ENCODER_CN_NOTES_1	res	1
ENCODER_CN_NOTES_2	res	1

	global	CC_ON_VALUE, CC_OFF_VALUE
CC_ON_VALUE			res 1
CC_OFF_VALUE		res 1

PLACEHOLDER_GPR2	res	D'3'
	global	RX_BUFFER
RX_BUFFER			res	D'8'
	global	INCOMING_SYSEX_B
INCOMING_SYSEX_B	res	D'64'

; Bank 3 variables
	global	KEY_TOGGLES, LOGIC_TOGGLES_0, LOGIC_TOGGLES_1, LOGIC_TOGGLES_2
	global	INCOMING_SYSEX_C
gpr3	udata	0x190
KEY_TOGGLES			res	D'24'
LOGIC_TOGGLES_0		res	D'1'
LOGIC_TOGGLES_1		res	D'1'
LOGIC_TOGGLES_2		res	D'1'
PLACEHOLDER_GPR3	res	D'5'
INCOMING_SYSEX_C	res	D'64'

	end
