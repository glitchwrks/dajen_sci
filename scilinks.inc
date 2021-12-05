;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;SCILINKS -- Dajen SCI ROM Monitor v1.6 Linkage
;
;This file contains linkage to the standard Dajen SCI ROM
;Monitor, version 1.6.
;
;(c) 2021 Glitch Works, LLC
;http://www.glitchwrks.com/
;
;Released under the GNU GPL v3, see LICENSE and GPL-3.0 in
;project root.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Monitor Equates
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PORT	EQU	0D0H		;PORT LOCATION
STACK	EQU	0DFC0H		;STACK LOCATION
STK0	EQU	STACK+4		;INP DEV CODE
STK1	EQU	STACK+5		;OUT DEV CODE
STK2	EQU	STACK+6		;SCROLL SPEED
STK3	EQU	STACK+7		;CASS READ SPD
STK5	EQU	STACK+9		;CASS WRITE SPD
STK7	EQU	STACK+11	;SERIAL SPEED
STK9	EQU	STACK+13	;TEMP STORE
STK10	EQU	STACK+14	;VDM CHARACTER
STK11	EQU	STACK+15	;VDM POINTER
STK13	EQU	STACK+17	;TEMP STORE
STK15	EQU	STACK+19	;TEMP STORE
STK16	EQU	STACK+20	;TEMP STORE
STK17	EQU	STACK+21	;INPUT BUFFER
PORT0	EQU	PORT+0		;PAR INP
PORT1	EQU	PORT+1		;CONTROL REG
PORT2	EQU	PORT+2		;CASSETTE CONTROL
PORT3	EQU	PORT+3		;CONTROL
PORT4	EQU	PORT+4		;KEYBD IN
PORT5	EQU	PORT+5		;CONTROL
PORT6	EQU	PORT+6		;PAR OUT
PORT7	EQU	PORT+7		;CONTROL
PORT8	EQU	PORT+8		;CASS READ CLOCK
PORT9	EQU	PORT+9		;CASS WRITE CLOCK
PORTA	EQU	PORT+10		;SERIAL CLOCK
PORTB	EQU	PORT+11		;CONTROL REG
PORTC	EQU	PORT+12		;UART CONTROL
PORTD	EQU	PORT+13		;UART DATA
PORTE	EQU	PORT+14		;CASS SSDA CONT
PORTF	EQU	PORT+15		;CASS SSDA DATA
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Default ROM start address is 0xD000.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ROMBASE	equ	0D000H		;ROM starting address

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Standard SCI Monitor Jump Table Equates
;
;See the Dajen SCI manual and/or monitor listing for more
;information.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
INIT	equ	ROMBASE		;Initialize ports
INPUT	equ	ROMBASE+3	;Read byte from console
WRITE	equ	ROMBASE+6	;Write byte to console
CASR0	equ	ROMBASE+9	;Cassette read
END	equ	ROMBASE+12	;Cassette read end routine
CASW0	equ	ROMBASE+15	;Cassette write
CASW2	equ	ROMBASE+18	;Cassette write end routine
PIN	equ	ROMBASE+21	;Parallel input from second port
POUT	equ	ROMBASE+24	;Parallel output to PORT6
ISTAT	equ	ROMBASE+27	;Console input status check
INPM	equ	ROMBASE+30	;Read char from console, 0x7F masked
WRITB	equ	ROMBASE+33	;Print character in B
ICHAR	equ	ROMBASE+36	;Read char from console, no wait,
				;mask high bit with 0x7F
