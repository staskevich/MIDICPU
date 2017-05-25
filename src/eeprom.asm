; MIDI CPU
; copyright John Staskevich, 2017
; john@codeandcopper.com
;
; This work is licensed under a Creative Commons Attribution 4.0 International License.
; http://creativecommons.org/licenses/by/4.0/
;
; eeprom.asm
;
; Default values stored in EEPROM.
;
		list		p=16f887
		#include	<p16f887.inc>

; ==================================================================
; ==================================================================
; ==================================================================
;
; DATA EEPROM FILL
;
; ==================================================================
; ==================================================================
; ==================================================================

eedata	code	0x2100

; firmware version
		data	0x04
; checksum
		data	0xB6
		data	0x07
; analog threshold
		data	0x06
; analog smoothing
		data	0x04
; VREF
		data	0x00
; Default Note Velocity
		data	0x7F
; Default CC "On" Value
		data	0x7F
; Default CC "Off" Value
		data	0x00
; Active Sense
		data	0x00
; Encoder Initial Values (12)
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
; Select Datamasks (15)
		data	B'00000000'
		data	B'00000001'
		data	B'00000011'
		data	B'00000111'
		data	B'00001111'
		data	B'00011111'
		data	B'00111111'
		data	B'01111111'
		data	B'10000000'
		data	B'11000000'
		data	B'11100000'
		data	B'11110000'
		data	B'11111000'
		data	B'11111100'
		data	B'11111110'
; Analog Data Map (16)
		data	D'14'
		data	D'12'
		data	D'10'
		data	D'11'
		data	D'13'
		data	D'15'
		data	D'0'
		data	D'0'
		data	D'0'
		data	D'1'
		data	D'2'
		data	D'3'
		data	D'4'
		data	D'5'
		data	D'6'
		data	D'7'
; Reserved (73)
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00
		data	0x00

; Note Transpose Register
		data	0x7F

; Remap Flags
		data	0x00

; Note Remap Table (128)
		data	0x00
		data	0x01
		data	0x02
		data	0x03
		data	0x04
		data	0x05
		data	0x06
		data	0x07
		data	0x08
		data	0x09
		data	0x0A
		data	0x0B
		data	0x0C
		data	0x0D
		data	0x0E
		data	0x0F
		data	0x10
		data	0x11
		data	0x12
		data	0x13
		data	0x14
		data	0x15
		data	0x16
		data	0x17
		data	0x18
		data	0x19
		data	0x1A
		data	0x1B
		data	0x1C
		data	0x1D
		data	0x1E
		data	0x1F
		data	0x20
		data	0x21
		data	0x22
		data	0x23
		data	0x24
		data	0x25
		data	0x26
		data	0x27
		data	0x28
		data	0x29
		data	0x2A
		data	0x2B
		data	0x2C
		data	0x2D
		data	0x2E
		data	0x2F
		data	0x30
		data	0x31
		data	0x32
		data	0x33
		data	0x34
		data	0x35
		data	0x36
		data	0x37
		data	0x38
		data	0x39
		data	0x3A
		data	0x3B
		data	0x3C
		data	0x3D
		data	0x3E
		data	0x3F
		data	0x40
		data	0x41
		data	0x42
		data	0x43
		data	0x44
		data	0x45
		data	0x46
		data	0x47
		data	0x48
		data	0x49
		data	0x4A
		data	0x4B
		data	0x4C
		data	0x4D
		data	0x4E
		data	0x4F
		data	0x50
		data	0x51
		data	0x52
		data	0x53
		data	0x54
		data	0x55
		data	0x56
		data	0x57
		data	0x58
		data	0x59
		data	0x5A
		data	0x5B
		data	0x5C
		data	0x5D
		data	0x5E
		data	0x5F
		data	0x60
		data	0x61
		data	0x62
		data	0x63
		data	0x64
		data	0x65
		data	0x66
		data	0x67
		data	0x68
		data	0x69
		data	0x6A
		data	0x6B
		data	0x6C
		data	0x6D
		data	0x6E
		data	0x6F
		data	0x70
		data	0x71
		data	0x72
		data	0x73
		data	0x74
		data	0x75
		data	0x76
		data	0x77
		data	0x78
		data	0x79
		data	0x7A
		data	0x7B
		data	0x7C
		data	0x7D
		data	0x7E
		data	0x7F

		end

