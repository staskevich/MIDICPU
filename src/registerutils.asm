; MIDI CPU
; copyright John Staskevich, 2017
; john@codeandcopper.com
;
; This work is licensed under a Creative Commons Attribution 4.0 International License.
; http://creativecommons.org/licenses/by/4.0/
;
; registerutils.asm
;
; Functions for working with memory registers.
;
		list		p=16f887
   		#include	<p16f887.inc>

   		#include	<mc.inc>



; ==================================================================
;
; External Functions
;
; ==================================================================

	EXTERN	read_reg_config
	EXTERN	point_to_d0_address
	EXTERN	load_d1_from_address

; ==================================================================
;
; Global Functions
;
; ==================================================================

	GLOBAL	go_reg_increment
	GLOBAL	go_reg_decrement
	GLOBAL	go_reg_sum
	GLOBAL	go_reg_copy
	GLOBAL	go_reg_store_value
	GLOBAL	go_reg_bit_op

register_utils	code

go_reg_return
		return

go_reg_increment
; set up REG_ADDRESS
		movfw	CONFIG_D0
		movwf	REG_ADDRESS
		call	read_reg_config
; set up register address
		call	point_to_d0_address
; check for rr / overflow -- use TEMP6 temporarily
		movfw	INDF
		movwf	TEMP6
		movfw	CONFIG_D1
		addwf	TEMP6,f
		movfw	TEMP6
		subwf	REG_MAX,w
		bnc	go_reg_increment_rr
go_reg_increment_commit
		movfw	TEMP6
		movwf	INDF
		goto	go_reg_return
go_reg_increment_rr
		btfss	REG_RR,0
		goto	go_reg_return
		incf	REG_MAX,w
		subwf	TEMP6,w
		addwf	REG_MIN,w
		movwf	TEMP6
		goto	go_reg_increment_commit

go_reg_decrement
; set up REG_ADDRESS
		movfw	CONFIG_D0
		movwf	REG_ADDRESS
		call	read_reg_config
; set up register address
		call	point_to_d0_address
; check for rr / underflow -- use TEMP6 temporarily
		movfw	REG_MIN
		subwf	INDF,w
		movwf	TEMP6
		movfw	CONFIG_D1
		subwf	TEMP6,w
		bnc	go_reg_decrement_rr	
		movfw	CONFIG_D1
		subwf	INDF,f
		goto	go_reg_return
go_reg_decrement_rr
		btfss	REG_RR,0
		goto	go_reg_return
		incf	REG_MAX,w
		addwf	TEMP6,f
		movfw	CONFIG_D1
		subwf	TEMP6,w
		movwf	INDF
		goto	go_reg_return

go_reg_sum
; set up REG_ADDRESS
		movfw	CONFIG_D0
		movwf	REG_ADDRESS
		call	read_reg_config
; grab d1 value
		call	load_d1_from_address
; set up register address
		call	point_to_d0_address
; check for overflow
		movfw	LOCAL_D1
		addwf	INDF,w
		movwf	TEMP6
		subwf	REG_MAX,w
		bc	go_reg_sum_commit
		btfss	REG_RR,0
		goto	go_reg_return
		incf	REG_MAX,w
		subwf	TEMP6,w
		addwf	REG_MIN,w
		movwf	INDF
		goto	go_reg_return
; commit sum
go_reg_sum_commit
		movfw	TEMP6
		movwf	INDF
		goto	go_reg_return

go_reg_copy
; check for invalid d1 register address
		movfw	CONFIG_D1
		sublw	MAX_REGISTER
		bnc	go_reg_return
; grab d1 value
		call	load_d1_from_address
; set up register address
		call	point_to_d0_address
; commit copy
		movfw	LOCAL_D1
		movwf	INDF
		goto	go_reg_return

go_reg_store_value
; set up register address
		call	point_to_d0_address
		movfw	CONFIG_D1
		movwf	INDF
		goto	go_reg_return

go_reg_bit_op
; set up register address
		call	point_to_d0_address
; set up bitmask
		movlw	B'00000001'
		movwf	BITMASK
; mask to counter
		movlw	B'00000111'
		andwf	CONFIG_D1,w
		bz	go_reg_bit_op_loop_skip
		movwf	TEMP5
; shift to correct bit
go_reg_bit_op_loop
		bcf		STATUS,C
		rlf		BITMASK,f
		decfsz	TEMP5,f
		goto	go_reg_bit_op_loop
go_reg_bit_op_loop_skip
		btfsc	CONFIG_D1,3
		goto	go_reg_bit_op_set
		btfss	CONFIG_D1,4
		goto	go_reg_bit_op_clear
go_reg_bit_op_toggle
		movfw	BITMASK
		andwf	INDF,w
		bz	go_reg_bit_op_set
go_reg_bit_op_clear
		comf	BITMASK,w
		andwf	INDF,f
		goto	go_reg_return
go_reg_bit_op_set
		movfw	BITMASK
		iorwf	INDF,f
		goto	go_reg_return


		end
