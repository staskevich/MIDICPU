; MIDI CPU
; copyright John Staskevich, 2017
; john@codeandcopper.com
;
; This work is licensed under a Creative Commons Attribution 4.0 International License.
; http://creativecommons.org/licenses/by/4.0/
;
; processmidi.asm
;
; Parse incoming MIDI messages.
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
		EXTERN	send_midi_byte

; ==================================================================
;
; Global Functions
;
; ==================================================================

		GLOBAL	sysex_error
		GLOBAL	process_inbound_midi


process_midi	code	0x1800
;process_midi	code



; =================================
;
; Process any incoming MIDI data, merge if necessary
;
; =================================
process_inbound_midi
; refresh leds first
;		call	refresh_leds

; Check for an emtpy fifo
		movfw	RX_BUFFER_GAUGE
		btfsc	STATUS,Z
		return
process_midi_byte
; Pull a byte from the fifo
		movlw	RX_BUFFER
		addwf	RX_BUFFER_HEAD,w
		movwf	FSR
		bsf		STATUS,IRP
		movfw	INDF
		movwf	RX_MIDI_BYTE
; Delete from fifo
		incf	RX_BUFFER_HEAD,f
		movlw	RX_POINTER_MASK
		andwf	RX_BUFFER_HEAD,f
; ok to receive more bytes
;		bsf		INTCON,GIE
; Check for MIDI Status
		btfss	RX_MIDI_BYTE,7
		goto	process_inbound_data
process_inbound_midi_status
; use running status if possible
		movfw	OUTBOUND_STATUS
		subwf	RX_MIDI_BYTE,w
		bnz		process_inbound_midi_new_status
; use running status
; set incomplete message flag
		bsf		STATE_FLAGS,0
; prepare for data
		clrf	INBOUND_BYTECOUNT
		movfw	RX_MIDI_BYTE
		movwf	INBOUND_STATUS
		goto	process_inbound_midi_next
; new status--do some processing
process_inbound_midi_new_status
; check for status 0xF_
		movfw	RX_MIDI_BYTE
		andlw	B'11110000'
		sublw	0xF0
		bnz		process_inbound_midi_ch_spec
process_inbound_midi_ch_unspec
; first check for real-time messages
; MIDI reset
		movfw	RX_MIDI_BYTE
		sublw	0xFF
		bz		merge_inbound_byte
; MIDI active sense (ignore)
		movfw	RX_MIDI_BYTE
		sublw	0xFE
		bz		process_inbound_midi_next
; MIDI undefined real time
		movfw	RX_MIDI_BYTE
		sublw	0xFD
		bz		merge_inbound_byte
; MIDI stop
		movfw	RX_MIDI_BYTE
		sublw	0xFC
		bz		process_inbound_midi_stop
; MIDI continue
		movfw	RX_MIDI_BYTE
		sublw	0xFB
		bz		process_inbound_midi_continue
; MIDI start
		movfw	RX_MIDI_BYTE
		sublw	0xFA
		bz		process_inbound_midi_start
; MIDI tick
		movfw	RX_MIDI_BYTE
		sublw	0xF9
		bz		merge_inbound_byte
; MIDI clock
		movfw	RX_MIDI_BYTE
		sublw	0xF8
		bz		process_inbound_midi_clock
; MIDI SysEx Begin
		movfw	RX_MIDI_BYTE
		sublw	0xF0
		bz		process_inbound_sysex
; MIDI SysEx End
		movfw	RX_MIDI_BYTE
		sublw	0xF7
		bz		process_inbound_sysex_end
; This is a message that is not merged.
		clrf	INBOUND_STATUS
		goto	process_inbound_midi_next

process_inbound_sysex_end
		pagesel	inbound_sysex_finish
		goto	inbound_sysex_finish


process_inbound_midi_ch_spec
; Merge the status byte & prepare to merge data bytes.
		movfw	RX_MIDI_BYTE
		movwf	INBOUND_STATUS
		movwf	OUTBOUND_STATUS
		bsf		STATE_FLAGS,0
		clrf	INBOUND_BYTECOUNT
		goto	merge_inbound_byte

process_inbound_midi_stop
process_inbound_midi_continue
process_inbound_midi_start
process_inbound_midi_clock
		goto	merge_inbound_byte


process_inbound_sysex
		movfw	RX_MIDI_BYTE
		movwf	INBOUND_STATUS
		clrf	SYSEX_TYPE
; new sysex message--message incomplete
		bsf		STATE_FLAGS,0
; sysex header not yet determined to be relevant
		bcf		STATE_FLAGS,1
; control terminal config message not yet identified
;		bcf		STATE_FLAGS,2
; no data yet received
		clrf	INBOUND_BYTECOUNT
		goto	process_inbound_midi_next

process_inbound_sysex_data
; assume relevant data at first.  we'll turn off the inbound status if we need to ignore future data bytes.
; check for valid header already received.
		btfss	STATE_FLAGS,1
		goto	process_inbound_sysex_header

process_inbound_sysex_body
; for type 04 messages, map the data into memory using nn and tt.
		movlw	0x04
		subwf	SYSEX_TYPE,w
		bz		pisb_type_4
; for type 01 messages, map the data into memory using nn and tt.
;		btfsc	STATE_FLAGS,2
		decfsz	SYSEX_TYPE,w
		goto	pisb_generic

pisb_type_1
; for type 1 message, store 4-byte chunks according to nn and tt
		movfw	INBOUND_BYTECOUNT
		bz		pisb_type_1_store_yy
		movfw	INBOUND_BYTECOUNT
		sublw	0x01
		bz		pisb_type_1_store_nn
		movfw	INBOUND_BYTECOUNT
		sublw	0x02
		bz		pisb_type_1_store_tt
		movfw	INBOUND_BYTECOUNT
		sublw	0x03
		bz		pisb_type_1_store_mm
		movfw	INBOUND_BYTECOUNT
		sublw	0x04
		bz		pisb_type_1_store_ch
		movfw	INBOUND_BYTECOUNT
		sublw	0x05
		bz		pisb_type_1_store_d0

; at this point, we have d1...
pisb_type_1_store_d1
		movfw	RX_MIDI_BYTE
		banksel	SYSEX_D1
		movwf	SYSEX_D1
		banksel	PORTA
; store the complete chunk
		call	store_sysex_chunk
; chunk is complete, roll the bytecount back to 1 (0 is for yy only)
		movlw	0x01
		movwf	INBOUND_BYTECOUNT
		goto	process_inbound_midi_next

pisb_type_1_store_yy
		movfw	RX_MIDI_BYTE
		sublw	SYSEX_MAX_YY
		bnc		pisb_error
		movfw	RX_MIDI_BYTE
		banksel	SYSEX_YY
		movwf	SYSEX_YY
		banksel	PORTA
		incf	INBOUND_BYTECOUNT,f
		goto	process_inbound_midi_next

pisb_type_1_store_nn
		movfw	RX_MIDI_BYTE
		sublw	SYSEX_MAX_NN
		bnc		pisb_error
		movfw	RX_MIDI_BYTE
		banksel	SYSEX_NN
		movwf	SYSEX_NN
		banksel	PORTA
		incf	INBOUND_BYTECOUNT,f
		goto	process_inbound_midi_next

pisb_type_1_store_tt
		movfw	RX_MIDI_BYTE
		sublw	SYSEX_MAX_TT
		bnc		pisb_error
		movfw	RX_MIDI_BYTE
		banksel	SYSEX_TT
		movwf	SYSEX_TT
		banksel	PORTA
		incf	INBOUND_BYTECOUNT,f
		goto	process_inbound_midi_next

pisb_type_1_store_mm
		movfw	RX_MIDI_BYTE
		banksel	SYSEX_MM
		movwf	SYSEX_MM
		banksel	PORTA
		incf	INBOUND_BYTECOUNT,f
		goto	process_inbound_midi_next

pisb_type_1_store_ch
		movfw	RX_MIDI_BYTE
		banksel	SYSEX_CH
		movwf	SYSEX_CH
		banksel	PORTA
		incf	INBOUND_BYTECOUNT,f
		goto	process_inbound_midi_next

pisb_type_1_store_d0
		movfw	RX_MIDI_BYTE
		banksel	SYSEX_D0
		movwf	SYSEX_D0
		banksel	PORTA
		incf	INBOUND_BYTECOUNT,f
		goto	process_inbound_midi_next

pisb_type_4
; reuse some type_1 code
		movfw	INBOUND_BYTECOUNT
		bz		pisb_type_4_store_nn
		movfw	INBOUND_BYTECOUNT
		sublw	0x01
		bz		pisb_type_1_store_mm
		movfw	INBOUND_BYTECOUNT
		sublw	0x02
		bz		pisb_type_1_store_ch
		movfw	INBOUND_BYTECOUNT
		sublw	0x03
		bz		pisb_type_1_store_d0
pisb_type_4_store_d1
		movfw	RX_MIDI_BYTE
		banksel	SYSEX_YY
		movwf	SYSEX_D1
		clrf	SYSEX_YY
		banksel	PORTA
; store the complete chunk
		call	store_sysex_chunk
; chunk is complete, roll the bytecount back to 0
		clrf	INBOUND_BYTECOUNT
		goto	process_inbound_midi_next

; nn is a special case, since nn goes from 03h-1Dh.
pisb_type_4_store_nn

;		movlw	0x1A
;		banksel	SYSEX_NN
;		movwf	SYSEX_NN
;		banksel	PORTA
;		incf	INBOUND_BYTECOUNT,f
;		goto	process_inbound_midi_next

		movlw	0x03
		subwf	RX_MIDI_BYTE,w
		bnc		pisb_error
		movfw	RX_MIDI_BYTE
		sublw	MAX_REGISTER
		bnc		pisb_error
		movfw	RX_MIDI_BYTE
		banksel	SYSEX_NN
		movwf	SYSEX_NN
		clrf	SYSEX_TT
		banksel	PORTA
		incf	INBOUND_BYTECOUNT,f
		goto	process_inbound_midi_next

pisb_generic
; for other messages, just use a raw dump into the memory space.
; if this is the 129th byte, it's an error.
		btfsc	INBOUND_BYTECOUNT,7
		goto	pisb_error
		movfw	INBOUND_BYTECOUNT
		movwf	TEMP_IM
		call	store_sysex_byte
		incf	INBOUND_BYTECOUNT,f
		goto	process_inbound_midi_next

pisb_error
sysex_error
; make sure interrupts are back on
		bsf		INTCON,7
		clrf	INBOUND_STATUS
		clrf	SYSEX_TYPE
		bcf		STATE_FLAGS,0
		bcf		STATE_FLAGS,1
;		bcf		STATE_FLAGS,2
		goto	process_inbound_midi_next

process_inbound_sysex_header
		movfw	INBOUND_BYTECOUNT
		bnz		pish_1
pish_0
; Header byte 0 = 00h
		movf	RX_MIDI_BYTE,f
		bz		pish_next
		clrf	INBOUND_STATUS
		bcf		STATE_FLAGS,0
		goto	process_inbound_midi_next
pish_1
		movwf	TEMP_IM
		decfsz	TEMP_IM,f
		goto	pish_2
; Header byte 1 = 01h
		movlw	0x01
		subwf	RX_MIDI_BYTE,w
		bz		pish_next
		clrf	INBOUND_STATUS
		bcf		STATE_FLAGS,0
		goto	process_inbound_midi_next
pish_2
		decfsz	TEMP_IM,f
		goto	pish_3
; Header byte 2 = 5Dh
		movlw	0x5D
		subwf	RX_MIDI_BYTE,w
		bz		pish_next
		clrf	INBOUND_STATUS
		bcf		STATE_FLAGS,0
		goto	process_inbound_midi_next
pish_3
		decfsz	TEMP_IM,f
		goto	pish_4
; Header byte 3 = 04h
		movlw	0x04
		subwf	RX_MIDI_BYTE,w
		bz		pish_next
		clrf	INBOUND_STATUS
		bcf		STATE_FLAGS,0
		goto	process_inbound_midi_next
pish_4
		decfsz	TEMP_IM,f
		goto	pish_overflow
; Header now considered valid.
		bsf		STATE_FLAGS,1
; We might soon be interfering with some input processing
; STATE_FLAGS,2 will be cleared when a new input processing routine begins
		bsf		STATE_FLAGS,2
		clrf	INBOUND_BYTECOUNT
; prep the buffer so we can tell what parts were specified in this message
		call	wipe_sysex_buffer
; we just destroyed the analog rolling average stuff
		bcf		STATE_FLAGS,4
; This byte determines sysex message type.
		movfw	RX_MIDI_BYTE
		movwf	SYSEX_TYPE
; Make sure type is valid
		movfw	SYSEX_TYPE
		sublw	SYSEX_MAX_TYPE
		bnc		sysex_error

; Special case: 01h
;		movfw	SYSEX_TYPE
;		sublw	0x01
;		bnz		process_inbound_midi_next
;		bsf		STATE_FLAGS,2
		goto	process_inbound_midi_next

pish_overflow
; should never execute here.
		clrf	INBOUND_STATUS
		bcf		STATE_FLAGS,0
		goto	process_inbound_midi_next


pish_next
		incf	INBOUND_BYTECOUNT,f
		goto	process_inbound_midi_next


process_inbound_data
; don't merge data if status was not recorded
		movf	INBOUND_STATUS,f
		bz		process_inbound_midi_next
; check for sysex status
		movlw	0xF0
		subwf	INBOUND_STATUS,w
		bz		process_inbound_sysex_data
; determine how many data bytes have come through
; not the first (zero'th) data byte?  merge.
		movf	INBOUND_BYTECOUNT,f
		bnz		process_inbound_data_merge
; first data byte, running status candidate?  merge.
		movfw	INBOUND_STATUS
		subwf	OUTBOUND_STATUS,w
		bz		process_inbound_data_merge
process_inbound_data_restatus
; A locally generated message must have interrupted the inbound running status.
; ...so resend the inbound status before sending data.
		movfw	INBOUND_STATUS
		movwf	OUTBOUND_STATUS
		movwf	OUTBOUND_BYTE
		pagesel	send_midi_byte
		call	send_midi_byte
process_inbound_data_merge
; send the byte thru
		movfw	RX_MIDI_BYTE
		movwf	OUTBOUND_BYTE
		pagesel	send_midi_byte
		call	send_midi_byte
		pagesel	process_inbound_midi
; use bytecount & status to decide whether or not this message is complete.
		incf	INBOUND_BYTECOUNT,f
; if second data byte was just sent, then message is complete for sure.
		btfsc	INBOUND_BYTECOUNT,1
		goto	process_inbound_data_complete
; only one data byte has been sent.  use status to check for completion.
; mask out the channel info
		movfw	INBOUND_STATUS
		andlw	B'11110000'
		movwf	TEMP_IM
; program change & channel pressure are the only one-data-byte messages.
		sublw	0xC0
		bz		process_inbound_data_complete
		movfw	TEMP_IM
		sublw	0xD0
		bz		process_inbound_data_complete
; message not complete.
		bsf		STATE_FLAGS,0
		goto	process_inbound_midi_next

process_inbound_data_complete
		bcf		STATE_FLAGS,0
		clrf	INBOUND_BYTECOUNT
		goto	process_inbound_midi_next
		
merge_inbound_byte
; send the real-time message on thru
		movfw	RX_MIDI_BYTE
		movwf	OUTBOUND_BYTE
		pagesel	send_midi_byte
		call	send_midi_byte
		pagesel	process_inbound_midi
		goto	process_inbound_midi_next

process_inbound_midi_next
		decfsz	RX_BUFFER_GAUGE,f
		goto	process_midi_byte
; buffer is empty.
; if inbound message not complete, wait for more data or a timeout.
process_inbound_midi_wait
		btfss	STATE_FLAGS,0
		return
;		btfsc	RX_BUFFER_GAUGE,0
		movfw	RX_BUFFER_GAUGE
		btfss	STATUS,Z
		goto	process_midi_byte
		goto	process_inbound_midi_wait

; =================================
;
; Store bytes to incoming sysex buffer.
;
; TEMP_IM: byte address to store (0 to 191)
; RX_MIDI_BYTE: stored value direct from RX port.
;
; =================================
store_sysex_byte

; determine in which bank the byte will be stored.
		movfw	TEMP_IM
		sublw	D'63'
		bc		ssb_bank_a

		movfw	TEMP_IM
		sublw	D'127'
		bc		ssb_bank_b

		movfw	TEMP_IM
		sublw	D'191'
; if the address is too large, exit
		btfss	STATUS,C
		return

ssb_bank_c
		movlw	D'128'
		subwf	TEMP_IM,w
		addlw	INCOMING_SYSEX_C
		movwf	FSR
		bsf		STATUS,IRP
		movfw	RX_MIDI_BYTE
		movwf	INDF
		return

ssb_bank_b
		movlw	D'64'
		subwf	TEMP_IM,w
		addlw	INCOMING_SYSEX_B
		movwf	FSR
		bsf		STATUS,IRP
		movfw	RX_MIDI_BYTE
		movwf	INDF
		return

ssb_bank_a
		movfw	TEMP_IM
		addlw	INCOMING_SYSEX_A
		movwf	FSR
		bcf		STATUS,IRP
		movfw	RX_MIDI_BYTE
		movwf	INDF
		return


; =================================
;
; Store chunk to incoming sysex buffer.
; inputs:
; SYSEX_NN
; SYSEX_TT
; SYSEX_MM
; SYSEX_CH
; SYSEX_D0
; SYSEX_D1
;
; =================================
store_sysex_chunk
; determine the bank in which the chunk will be stored.
; if TT=1, add 24 to the "effective" output number

		banksel	SYSEX_NN

;		clrf	SYSEX_NN
;		goto	ssc_bank_a

		movlw	D'24'
		btfsc	SYSEX_TT,0
		addwf	SYSEX_NN,f
		movfw	SYSEX_NN
		sublw	D'15'
		bc		ssc_bank_a

		movfw	SYSEX_NN
		sublw	D'31'
		bc		ssc_bank_b

ssc_bank_c
		movlw	D'32'
		subwf	SYSEX_NN,w
		movwf	TEMP_IM
		bsf		STATUS,IRP
		movlw	INCOMING_SYSEX_C
		goto	ssc_transfer

ssc_bank_b
		movlw	D'16'
		subwf	SYSEX_NN,w
		movwf	TEMP_IM
		bsf		STATUS,IRP
		movlw	INCOMING_SYSEX_B
		goto	ssc_transfer

ssc_bank_a
		movfw	SYSEX_NN
		movwf	TEMP_IM
		bcf		STATUS,IRP
		movlw	INCOMING_SYSEX_A

ssc_transfer
		addwf	TEMP_IM,w
		addwf	TEMP_IM,w
		addwf	TEMP_IM,w
		addwf	TEMP_IM,w
		movwf	FSR
; mm
		movfw	SYSEX_MM
		movwf	INDF
		incf	FSR,f
; ch
		movfw	SYSEX_CH
		movwf	INDF
		incf	FSR,f
; d0
		movfw	SYSEX_D0
		movwf	INDF
		incf	FSR,f
; d1
		movfw	SYSEX_D1
		movwf	INDF

		banksel	PORTA

		return


; =================================
;
; Fill the sysex buffer with null data
;
; =================================
; bank A
wipe_sysex_buffer
		movlw	INCOMING_SYSEX_A
		movwf	FSR
		bcf		STATUS,IRP
		movlw	D'64'
		movwf	TEMP_IM
		movlw	0xFF
wipe_sysex_a
		movwf	INDF
		incf	FSR,f
		decfsz	TEMP_IM,f
		goto	wipe_sysex_a
; bank B
		movlw	INCOMING_SYSEX_B
		movwf	FSR
		bsf		STATUS,IRP
		movlw	D'64'
		movwf	TEMP_IM
		movlw	0xFF
wipe_sysex_b
		movwf	INDF
		incf	FSR,f
		decfsz	TEMP_IM,f
		goto	wipe_sysex_b
; bank C
		movlw	INCOMING_SYSEX_C
		movwf	FSR
;		bsf		STATUS,IRP
		movlw	D'64'
		movwf	TEMP_IM
		movlw	0xFF
wipe_sysex_c
		movwf	INDF
		incf	FSR,f
		decfsz	TEMP_IM,f
		goto	wipe_sysex_c

		return


		end
