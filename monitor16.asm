;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;MONITOR16 -- Dajen SCI ROM Monitor v1.6
;
;This is a cleaned up version of the Dajen SCI ROM monitor,
;version 1.6. The original source was typed in from the SCI
;manual, and is available essentially unedited in
;MONITOR16.ORIG
;
;Glitch Works, LLC modifications are released under the
;GNU GPL v3, see LICENSE and GPL-3.0 in project root.
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
	ORG	0D000H		;Staring address

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;SCI -- Standard jump table
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SCI:	JMP	INIT		;INIT PORTS
	JMP	INPUT		;INPUT
	JMP	WRITE		;WRITE
	JMP	CASR0		;CASS INPUT
	JMP	END		;TURN OFF RELAY
	JMP	CASW0		;CASS WRITE
	JMP	CASW2		;END OF WRITE
	JMP	PIN		;PAR INPUT
	JMP	POUT		;PAR OUTPUT
	JMP	ISTAT		;INP STATUS
	JMP	INPM		;INP MASKED
	JMP	WRITB		;B OUT
	JMP	ICHAR		;ESCAPE

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;INIT -- Cold start initialization routine
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
INIT:	LXI	SP, STACK	;SET STACK
	MVI	A, 0CH		;ERASE VIDEO
	CALL	VDM+1
	MVI	A, 30H		;INIT PARALLEL PORTS
	OUT	PORT1
	OUT	PORT3
	OUT	PORT5
	OUT	PORT7
	OUT	PORTB		;CLOCK REG
	SUB	A		;SET INPUT PORTS
	OUT	PORT4
	OUT	PORT0		;PAR IN
	MVI	A, 00		;RESET VDM
	OUT	0C8H
	DW	0		;CUSTOM
	DW	0
	DW	0
	MVI	A, 0FFH		;OUT PORT
	OUT	PORT6
	MVI	A, 0FH		;CASS CONTROL
	OUT	PORT2
	MVI	A, 2CH		;ENABLE PORTS
	OUT	PORT1		;2C=NEG STROBE
	OUT	PORT3		;2E=POS STROBE
	OUT	PORT7
INIT1:	LXI	D, STK0		;SW ON= K AND V
	MVI	B, 07H		;KEYBD-VID
	IN	PORT2		;SW OFF=SERIAL
	RLC			;IN AND OUT
	RLC
	RLC
	MOV	H, A		;SAVE A
	ANI	02		;MASK SWITCH
	STAX	D		;INP DEVICE
	INX	D
	STAX	D		;OUT DEVICE
	MOV	A, H		;GET A
	RLC			;GET OTHER SW
	ANI	02H		;MASK SW
	ADI	2CH		;ADD FOR STR
	OUT	PORT5		;SET STROBE POL
				;STROBE SW ON=NEG, SW OFF=POS
	LXI	H, TABL2	;SET OTHER OPTIONS
INIT2:	INX	D
	MOV	A, M		;GET DATA
	STAX	D
	INX	H
	DCR	B
	JNZ	INIT2
	SUB	A		;TURN OFF RELAYS
	OUT	PORT2
	MVI	A, 03H		;SET UP SERIAL PORT
	OUT	PORTC
	MVI	A, 11H
	OUT	PORTC
	MVI	A, 0B6H		;SET UP CLOCKS
	OUT	PORTB
	MVI	A, 70H
	OUT	PORTB
	DCX	D
	LDAX	D
	OUT	PORTA
	INX	D
	LDAX	D
	OUT	PORTA

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;STRT -- Start of command processor
;
;Fall through to COMMD.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
STRT:	LXI	H, STK17	;INITIALIZE INPUT BUFFER
	MVI	M, 0DH
	INX	H
	SUB	A
	CMP	L
	JNZ	STRT+3
	LXI	SP, STACK
	LXI	H, CMNT0
	CALL	COMNT		;INITIAL COMMENT

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;COMMD -- Actual command processor
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
COMMD:	MVI	C, 28H		;BUFF LENG
	LXI	H, STK17
	CALL	INPM		;GET COMMAND
	CPI	08H		;A BACKSPACE?
	JZ	DELET
	CPI	7FH		;A RUBOUT?
	JZ	DELET		;IF SO, ERASE IT
	CPI	1BH		;ESCAPE CHAR?
	JZ	DELET		;GET RID OF IT
	CPI	0DH		;A CARRIAGE RETURN?
	JZ	CMD1		;IF SO, EXECUTE COMMAND
	MOV	M, A		;PUT INTO BUFFER
	CALL	WRITE		;ECHO CHARACTER
	INX	H
	DCR	C		;END OF INPUT BUFFER?
	JNZ	COMMD+5		;NO, LOOP
	JMP	ERROR		;YES, TOO MUCH

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;DELET -- Delete a character from the buffer
;
;This routine handles BS, RUBOUT, and ESC.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DELET:	MOV	A, C
	CPI	28H		;END OF BUFFER?
	JZ	COMMD		;YES, RETURN
	INR	C		;NO, INCREMENT C
	DCX	H		;DECREMENT POINTER
	MVI	M, 0DH		;ERASE CHARACTER
	MVI	A, 08H		;A BACKSPACE
	CALL	WRITE
	JMP	COMMD+5

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;CHCK -- Character check
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CHCK:	MOV	A, M		;GET CHARACTER
	INX	H		;POINT NEXT
	SUI	20H		;A SPACE?
	RZ
	ADI	20H		;RESTORE
	CALL	CONV4		;CONVERT
	JC	ERROR		;CARRY SET
	SUI	0AH		;LETTER ?
	JC	ERROR		;NO
	INR	A
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;CMD1 -- Execute command
;
;This routine looks up a command in the command table TABL1.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CMD1:	LXI	H, STK17	;START OF INPUT BUFFER
	CALL	CRLF		;RET AND LINE FEED
	CALL	CHCK		;CHECK FIRST LETTER
	RAL			;MULTIPLY BY 8
	RAL
	RAL
	MOV	B, A		;SAVE IT IN B
	CALL	CHCK		;CHECK 2ND LETTER
	JZ	$+4		;IT WAS A SPACE
	INX	H
	ADD	B		;ADD FIRST LETTER VALUE
	SHLD	STK13		;SAVE POINTER
	MVI	C, 0E4H		;COMD COUNT
	LXI	H, TABL1	;COMMAND LOOK-UP TABLE
CMD2:	CMP	M		;FIND IT?
	JZ	CMD3		;YES
	INX	H		;NO
	INX	H
	INX	H
	INR	C		;INCREMENT COMMAND COUNTE
	JZ	ERROR		;COULDN'T FIND IT
	JMP	CMD2		;LOOP
CMD3:	INX	H		;GET ADDRESS OF COMMAND
	MOV	E, M		;SAVE IT IN D AND E
	INX	H
	MOV	D, M
	XCHG			;PLADE DE IN HL
	PCHL			;PLACE HL IN PC AND GO

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;CONV0 -- Convert a character
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CONV0:	PUSH	H		;SAVE HL
	LXI	D, 0000H	;ZERO DE
	LHLD	STK13		;GET POINTER TO BUFFER
	MOV	A, M
	CPI	0DH		;WAS IT A CARRIAGE RET?
	JZ	CONV2+8		;YES
	MOV	A, M
	CPI	20H		;A SPACE?
	JZ 	CONV1		;YES
	CPI	0DH		;A CARRIAGE RET?
	JZ	CONV1		;YES
	INX	H		;INCREMENT POINTER
	JMP	CONV0+13	;LOOP
CONV1:	INX	H		;INCREMENT POINTER
	SHLD	STK13		;SAVE POINTER
	DCX	H		;GET CHARACTER
	CALL	CONV2		;GET LOWER NIBBLE
	MOV	E, A		;SAVE IN E
	CALL	CONV2		;GET NIBBLE
	RLC			;ROTATE
	RLC
	RLC
	RLC
	ADD	E		;GET 1ST HALF
	MOV	E, A		;NOW HAVE 1ST BYTE
	CALL	CONV2		;GET 2ND BYTE
	MOV	D, A
	CALL	CONV2
	RLC
	RLC
	RLC
	RLC
	ADD	D
	MOV	D, A
	POP	H
	RET
CONV2:	DCX	H		;GET DATA
	MOV	A, M
	CPI	20H		;DONE?
	JNZ	CONV3		;NO
	POP	H		;GET RID OF LAST CALL
	POP	H
	RET
CONV3:	CALL	CONV4		;CONVERT
	JC	ERROR		;CARRY SET
	CPI	10H		;A NUMBER?
	JNC	ERROR		;NO
	RET
CONV4:	SUI	30H		;ASC BIAS
	RC			;NOT LET OR NUM
	CPI	0AH
	CMC
	RNC			;A NUMBER
	CPI	2BH		;A LOW CASE ?
	CNC	LCL
	CMC
	RC			;NO GOOD
	CPI	11H
	RC			;NO GOOD
	SUI	07H		;A LETTER
	RET
LCL:	SUI	20H		;CONV LOW TO UP
	CPI	2BH		;NOT LET ?
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;GO -- Go command handler
;
;Get an address from the input buffer and transfer control
;to it.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GO:	CALL	CONV0		;GET ADDRESS
	XCHG			;PUT IN HL
	PCHL			;PUT IN PC AND GO

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;EM0 -- Edit memory command handler
;
;Enter here for the "full version."
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
EM0:	CALL	CONV0		;GET ADDRESS
	XCHG			;SAVE IN HL
	CALL	RTHL		;WRITE ADDRESS
	MOV	A, M
	CALL	RTHEX		;WRITE BYTE
	CALL	SPACE
	CALL	INPM		;GET CHAR
	CALL	WRITE		;ECHO IT
	CPI	20H		;A SPACE ?
	JZ	EM1		;YES
	CPI	08H		;A BACKSPACE?
	JZ	EM2		;YES
	CALL	EM4
EM1:	MOV	A, M		;GET MEM BYTE
	CALL	RTHEX		;WRITE IT
	INX	H
	CALL	CRLF
	JMP	EM0+4
EM2:	DCX	H		;DECREMENT HL
	JMP	EM1+5
EM3:	CALL	CONV0		;GET ADDR
	XCHG			;PUT IN HL
	MVI	C, 10H		;BYTE COUNT
	CALL	RTHL
	CALL	INPM
	CALL	WRITE
	CALL	EM4
	INX	H
	DCR	C		;DEC COUNT
	JNZ	EM3+9
	CALL	CRLF
	JMP	EM3+4
EM4:	CALL	CONV3		;CONVERT BYTE
	RLC			;ROTATE NIBBLE
	RLC
	RLC
	RLC
	MOV	B, A		;SAVE IN B
	CALL	INPM
	CALL	WRITE
	CALL	CONV3
	ADD	B		;GET NIBBLE
	MOV	M, A		;STORE
	JMP	SPACE

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;PROG0 -- Program 2708 command handler
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PROG0:	CALL	CONV0		;PROGRAM 2708
	XCHG			;SAVE IN HL
	CALL	CONV0
	MVI	A, 0A0H		;DO 160X
PROG1:	STA	STK9		;SAVE A
	PUSH	D
	PUSH	H
	LXI	B, 0400H
	CALL	ESCAP		;WANT TO QUIT?
PROG2:	MOV	A, M		;GET BYTE
	STAX	D		;PLACE IN 2708
	INX	D
	CALL	DONE
	JNZ	PROG2		;LOOP
	POP	H		;GET HL
	POP	D		;GET DE
	LDA	STK9		;GET COUNT BYTE
	DCR	A		;DECREMENT IT
	JNZ	PROG1		;LOOP
VER0:	LXI	B, 0400H
	JMP	VERFY+6		;VERIFY DATA

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;DONE -- Handle end condition for some commands
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DONE:	INX	H
	DCX	B
	SUB	A
	ORA	B
	ORA	C
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;COMNT -- Print a high bit terminated string
;
;pre: HL points to high bit terminated string
;post: string is printed to console device
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
COMNT:	MOV	A, M		;GET BYTE
	CALL	WRITE		;WRITE IT
	INX	H
	ORA	A		;BIT 7 HIGH ?
	JP	COMNT		;NO, LOOP
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;DELA2 -- Double software delay
;
;Calls DELAY then falls through to it on return for 2X.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DELA2:	CALL	DELAY		;TWO TIMES

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;DELAY -- Software delay loop
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DELAY:	PUSH	B		;SAVE B
	LXI	B, 7000H
	INX	B
	SUB	A
	ORA	B
	ORA	C		;DONE ?
	JNZ	DELAY+4
	POP	B		;RESTORE BC
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;DELAS -- Half software delay
;
;This routine performs approximately 1/2 of the delay as
;DELAY. Returns through DELAY.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DELAS:	PUSH	B
	LXI	B, 0B800H	;HALF AS MUCH DELAY
	JMP	DELAY+4

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;ISTAT -- Get input device status
;
;Compatible with Processor Technology software.
;
;Falls through to ISTAT if a character is available.
;
;post: Z flag clear if data available
;post: A register contains character if available
;post: Z flag set if data not available
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ISTAT:	CALL	CHKST		;GET STATUS
	ANI	80H		;BIT 7
	RZ			;Z= NO DATA

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;ICHAR -- Get a character from the console
;
;Returns current character from the console device without
;waiting for a new character. Clears high bit.
;
;post: A register contains character from console
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ICHAR:	CALL	INPUT+6		;GET CHAR
	ANI	7FH		;MASK BIT 7
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;INPM -- Input masked
;
;Waits for a character from the console input device. Clears
;high bit.
;
;post: A register contains character from console
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
INPM:	CALL	INPUT
	ANI	7FH		;MASK BITS 0-6
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;INPUT -- Read from the console input device
;
;This routine handles actual selection of the input device
;based on the value stored at STK0.
;
;A CMA can be added after PIN0 and/or PIN1 for inverted
;data polarity on primary or secondary parallel port.
;
;post: A register contains unmasked byte from console input
;      device
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
INPUT:	CALL	ISTAT		;CHECK STATUS
	JZ	INPUT		;LOOP TIL READY
	LDA	STK0		;INPUT DEVICE
	ORA	A
	JZ	PIN0		;PRIMARY PARALLEL INPUT
	DCR	A
	JZ	PIN1		;OTHER PARALLEL INPUT
	IN	PORTD		;INPUT FROM SERIAL
	RET
PIN0:	IN	PORT4
	NOP			;CMA IF INV DATA
	RET
PIN:	IN	PORT1		;CHECK STATUS
	ORA	A		;CHECK BIT 7
	JP	PIN		;LOOP
PIN1:	IN	PORT0
	NOP			;CMA IF INV DAT
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;CHKST -- Check console device status
;
;This routine handles actual selection of the input device
;based on the value stored at STK0.
;
;When getting status from the serial port, bit 0 is shifted
;into the CY flag.
;
;Check for new character availability from the selected
;console device.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CHKST:	LDA	STK0		;CHECK STATUS
	ORA	A
	JZ	PINS0		;PAR STAT
	DCR	A
	IN	PORT1		;STATUS PORT
	RZ
	IN	PORTC		;SERIAL STATUS
	RRC			;GET BIT 0
	RET
PINS0:	IN	PORT5		;STATUS PORT
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;WRITB -- Write value in B register to selected console dev
;
;This routine provides Processor Technology software
;compatibility. Falls through to WRITE. Does not strip high
;bit.
;
;pre: B register contains char to print to console
;post: contents of B register printed to console
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
WRITB:	MOV	A, B		;GET DATA

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;WRITE -- Write a character to the console
;
;This routine handles actual selection of the input device
;based on the value stored at STK0.
;
;Does not strip high bit.
;
;pre: A register contains char to print to console
;post: contents of A register printed to console
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
WRITE:	PUSH	PSW		;SAVE A
	LDA	STK1		;OUT DEVICE
	ORA	A
	JZ	VDM		;VIDEO ROUTINE
	DCR	A
	JZ	POUT+1
SOUT:	IN	PORTC
	ANI	02H		;READY ?
	JZ	SOUT		;LOOP
	POP	PSW		;GET A
	OUT	PORTD
	RET
POUT:	PUSH	PSW		;SAVE A
	IN	PORT7		;CHECK STATUS
	ORA	A		;BIT 7 HIGH ?
	JP	POUT+1
	POP	PSW		;GET A
	OUT	PORT6
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;VDM -- Video display routine
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
VDM:	POP	PSW		;GET A
	PUSH	B		;SAVE REG'S
	PUSH	D
	PUSH	H
	PUSH	PSW
	LHLD	STK11		;GET VDM POINTER
	CPI	0CH		;ERASE SCREEN?
	JZ	FF		;YES
	CPI	0DH		;CARRIAGE RETURN ?
	JZ	CR
	CPI	0AH		;LINE FEED?
	JZ	LF
	CPI	08H		;A BACKSPACE ?
	JZ	BS
	CPI	7FH		;A RUB OUT ?
	JZ	BS
	CPI	0BH		;CTRL K, HOME ?
	JZ	HOME
	ANI	7FH		;POLY-F6 80
	MOV	M, A		;PUT ON SCREEN
	INX	H
VD1:	CALL	VD3		;END OF SCREEN?
	JC	VD2

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;SC1 -- Control video scroll speed
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SC1:	LDA	STK2		;GET SCROLL SPEED
	MOV	D, A
	MVI	E, 0FFH
	INX	D
	SUB	A
	ORA	D
	ORA	E		;DONE ?
	JNZ	SC1+6		;LOOP
SC2:	CALL	ISTAT		;CHANGE SPEED?
	JZ	SC3		;NO
	CPI	20H		;A SPACE?
	JNZ	$+6
	CALL	INPM		;WAIT FOR CHAR
	CPI	3AH		;GREATER THAN 9 ?
	JNC	SC3		;YES
	SUI	30H		;SUB ASCII BIAS
	JC	SC3		;NOT 0-9
	RAL			;MULTIPLY BY 16
	RAL
	RAL
	RAL
	ADI	6CH
	STA	STK2		;STORE SPEED
SC3:	LXI	H, 0CC40H	;START SCROLL
	LXI	D, 0CC00H	;START OF SCREEN
	MOV	A, M		;GET BYTE
	STAX	D		;MOVE IT
	INX	D
	INX	H
	CALL	VD3		;DONE?
	JC	SC3+6
	DCX	H
	MVI	M, 20H		;POLY-20
	MOV	A, L
	CPI	0C0H		;DONE ?
	JNZ	SC3+16
VD2:	MVI	M, 0A0H		;POLY-0FFH
	SHLD	STK11		;SAVE POINTER
	POP	PSW		;RESTORE REG'S
	POP	H
	POP	D
	POP	B
	RET			;DONE
VD3:	MOV	A, H
	CPI	0D0H		;C7-80X24
	RET			;RC-80X24
	MOV	A, L		;GET L
	CPI	80H		;END OF LINE
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;FF -- Handle video rubout
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
FF:	LXI	H, 0CFFFH	;END OF SCREEN
	MVI	M, 20H		;POLY-A0
	DCX	H
	MOV	A, H
	CPI	0CBH		;DONE?
	JNZ	FF+3
	INX	H
	JMP	VD2

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;CR -- Handle video carraige return
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CR:	MVI	M, 20H		;POLY-A0
	MOV	A, L
	ANI	0C0H
	MOV	L, A
	MOV	A, M		;SAVE BYTE
	STA	STK10
	JMP	VD2
				
	MOV	A, D		;***THE FOLLOWING FOR 80X24***
	SBB	H
	POP	D
	JC	CR+9
	MOV	A, M
	STA	STK10		;SAVE CHAR
	JMP	VD2

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;LF -- Handle video linefeed
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LF:	LDA	STK10		;GET BYTE
	MOV	M, A		;PUT ON SCREEN
	LXI	D, 0040H
	DAD	D		;LINE-FEEDS HL
	MOV	A, M		;GET BYTE
	STA	STK10
	JMP	VD1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;BS -- Handle video backspace
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
BS:	MVI	M, 20H		;POLY-A0
	DCX	H
	JMP	VD1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;HOME -- Return to video home location
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
HOME:	MVI	M, 20H		;POLY-A0
	LXI	H, 0CC00H	;START OF SCREEN
	JMP	VD2

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;CRLF -- Print CR, LF to the selected console device
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CRLF:	MVI	A, 0DH		;CARRIAGE RETURN
	CALL	WRITE
	MVI	A, 0AH		;LINE FEED
	CALL	WRITE
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;SPACE -- Print a space to the selected console device
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SPACE:	MVI	A, 20H		;SPACE
	CALL	WRITE
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;RTHEX -- Write a hex character to the console
;
;pre: A register contains byte to print
;post: contents of A register printed to console as hex byte
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
RTHEX:	PUSH	PSW
	RAR			;GET UPPER NIBBLE
	RAR
	RAR
	RAR
	CALL	BINAS
	CALL	WRITE
	POP	PSW		;GET BYTE AGAIN
	CALL	BINAS
	CALL	WRITE
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;BINAS -- Convert binary to ASCII
;
;pre: A register contains nibble to convert
;post: A register contains ASCII representation of nibble
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
BINAS:	ANI	0FH		;BIN TO ASCII
	ADI	30H
	CPI	3AH		;OK?
	RC			;YES
	ADI	07H
	RET			;NOW ITS DONE

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;RTHL -- Write HL to console as hex
;
;pre: HL register contains word to be printed
;post: HL printed to console as hex
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
RTHL:	MOV	A, H		;WRITE HL
	CALL	RTHEX
	MOV	A, L
	CALL	RTHEX
	CALL	SPACE
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;ESCAP -- Check for and handle ESC character
;
;post: Z flag clear if no ESC char
;post: COMPLETE printed to console and control returned to
;      command processor if ESC pressed
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ESCAP:	CALL	ICHAR		;GET CHAR
	CPI	1BH		;ESCAPE ?
	RNZ
	LXI	H, CMNT6
	JMP	CMPLT+3

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;CASR0 -- Cassette read routine
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CASR0:	IN	PORT2		;IS RELAY ON ?
	ANI	01H
	JNZ	CASR1
	IN	PORT2		;GET DATA AT PORT2
	ORI	01H		;TURN ON READ RELAY
	OUT	PORT2
	MVI	A, 32H		;SET UP READ CLOCK
	OUT	PORTB
	LDA	STK3		;GET READ SPEED
	OUT	PORT8
	LDA	STK3+1
	OUT	PORT8
	CALL	ESCAP		;WANT TO QUIT ?
	IN	PORT2		;LEVEL DETECTION
	ORA	A		;BIT 7 HIGH ?
	JP	CASR0+27	;LOOP TIL TONE
	CALL	DELAY
	IN	PORT2		;CHECK LEVEL AGAIN
	ORA	A		;BIT 7 HIGH?
	JP	CASR0+27	;LOOP TIL TONE
	MVI	A, 80H		;SET UP SSDA
	OUT	PORTE		;RESET RECEIVER
	MVI	A, 0B8H		;8-BIT WORD, SM, 1 BYTE
	OUT	PORTF
	MVI	A, 82H		;WRITE TO CON REG 3
	OUT	PORTE
	MVI	A, 70H		;INT, ONE SYNC CLR STAT
	OUT	PORTF
	MVI	A, 81H		;WRITE TO SYNC REG
	OUT	PORTE
	MVI	A, 0E6H		;SYNC CODE
	OUT	PORTF
	MVI	A, 03H		;ENABLE X-MIT
	OUT	PORTE
CASR1:	CALL	ESCAP		;WANT TO QUIT ?
	IN	PORTE		;CHECK STATUS
	ORA	A		;BIT 7 HIGH ?
	JP	CASR1		;NOT READY
	IN	PORTF		;GET DATA
	RET
CASR2:	CALL	CASR0		;GET SA AND LEN
	MVI	B, 00H		;ZERO CHECKSUM REG
	MOV	L, A		;PUT ADDRESS IN HL
	MOV	B, A
	CALL	CASR1
	MOV	H, A
	ADD	B
	MOV	B, A
	CALL	CASR1
	MOV	D, A		;PUT BLOCK LEN IN DE
	ADD	B
	MOV	B, A
	CALL	CASR1
	MOV	E, A
	ADD	B
	MOV	B, A
	RET
CASR3:	CALL	CASR1		;GET DATA NOW
	MOV	M, A		;PUT IN MEMORY
	ADD	B
	MOV	B, A
	INX	H
	DCX	D
	SUB	A		;ZERO A
	ORA	D		;IS D ZERO ?
	ORA	E		;IS E ZERO ?
	JNZ	CASR3		;NO, LOOP
	CALL	CASR1		;GET CHECKSUM
	SUB	B		;COMPARE WITH B
	MOV	D, A		;SAVE RESULT IN D
	CALL	END
	SUB	A
	CMP	D		;CHECKSUM OK ?
	LXI	H, CMNT2	;TAPE ERROR
	CZ	CASR4		;TAPE OK
	CALL	COMNT
	JMP	STRT
CASR4:	LXI	H, CMNT4	;COMPLETE
	RET
CASR5:	CALL	CONV0		;READ AND SPECIFY
	XCHG			;SAVE IN H
	PUSH	H
	LHLD	STK13
	MOV	A, M
	CPI	0DH		;A CARRIAGE RET ?
	POP	H
	JNZ	CASR6		;GET ANOTHER ADDRESS
	CALL	CASR0
	MVI	B, 00H		;ZERO CHECKSUM REG
	MOV	M, A		;PLACE BYTE IN MEMORY
	ADD	B		;KEEP CHECKSUM
	MOV	B, A
	INX	H
	CALL	CASR1
	MOV	M, A
	ADD	B
	MOV	B, A
	INX	H
	CALL	CASR1
	MOV	M, A
	MOV	D, A
	ADD	B
	MOV	B, A
	INX	H
	CALL	CASR1
	MOV	M, A
	MOV	E, A
	ADD	B
	MOV	B, A
	INX	H
	JMP	CASR3
CASR6:	CALL	BKLEN+4		;GET 2ND ADDR
	MOV	D, B
	MOV	E, C
	CALL	CASR0
	MVI	B, 00H		;ZERO CHECKSUM REG
	JMP	CASR3+3
CASR7:	CALL	CASR2		;RC PROGRAM
	JMP	CASR3
CASR8:	CALL	CASR2		;RV PROGRAM
	CALL	CASR1
	CMP	M		;MEMORY SAME AS TAPE?
	JNZ	VTERR		;ERROR
	ADD	B
	MOV	B, A		;KEEP CHECKSUM
	INX	H
	DCX	D
	SUB	A
	ORA	D
	ORA	E
	JNZ	CASR8+3
	JMP	CASR3+14

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;VTERR -- Handle verify tape error
;
;Falls through to ERROR.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
VTERR:	CALL	END		;SHUT OFF RELAY
	LXI	H, CMNT3
	CALL	COMNT

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;ERROR -- Handle error condition
;
;This routine prints the high bit terminated error string
;pointed to by HL and returns control to the command
;processor.
;
;Returns through call into CMPLT.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ERROR:	CALL	CRLF
	LXI	H, CMNT1	;ERROR
	JMP	CMPLT+3

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;END -- End cassette read
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
END:	CALL	ESCAP		;QUIT ?
	IN	PORT2		;CHECK LEVEL
	ORA	A		;BIT 7 HIGH ?
	JM	END		;LOOP TIL NO LEVEL
	IN	PORT2		;A GAP
	ANI	0FEH		;MASK RELAY
	OUT	PORT2		;RESTORE
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;BKLEN -- Get block length parameters
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
BKLEN:	CALL	CONV0
	XCHG			;SAVE IN HL
	CALL	CONV0
	INX	D
	MOV	A, E
	SUB	L		;CALCULATE LENGTH
	MOV	C, A
	MOV	A, D
	SBB	H
	MOV	B, A
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;ZERO -- Zero memory command handler
;
;Optionally fills memory with a specified value.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ZERO:	CALL	BKLEN		;ZERO A MEMORY
	CALL	CONV0		;NO ZERO ?
	MOV	M, E
	CALL	DONE
	JNZ	ZERO+6		;LOOP TIL DONE

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;CMPLT -- Print complete message and restart monitor
;
;This routine prints "COMPLETE" to the console and jmps to
;STRT to re-initialize the command processor.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CMPLT:	LXI	H, CMNT4	;COMPLETE
	CALL	COMNT
	JMP	STRT

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;MOVE -- Move memory command handler
;
;Falls through to VERFY.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
MOVE:	CALL	BKLEN		;MOVE A BLOCK OF MEM
	CALL	CONV0		;GET START ADDR
	MOV	A, M		;GET BYTE
	STAX	D		;MOVE A BYTE
	INX	D
	CALL	DONE
	JNZ	MOVE+6		;LOOP TIL DONE
	LXI	H, STK17+2
	SHLD	STK13

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;VERFY -- Verify memory command handler
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
VERFY:	CALL	BKLEN		;VERIFY MEMORY
	CALL	CONV0		;GET ADDRESS
	CALL	ESCAP		;WANT TO QUIT?
	LDAX	D
	CMP	M		;COMPARE
	JNZ	VMERR		;ERROR
	INX	D
	CALL	DONE
	JNZ	VERFY+6		;LOOP
	JMP	CMPLT

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;VMERR -- Handle verify memory error
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
VMERR:	PUSH	H		;SAVE H
	LXI	H, CMNT3
	CALL	COMNT
	LXI	H, CMNT1
	CALL	COMNT
	POP	H
	CALL	RTHL		;WRITE ADDRESS
	MOV	A, M		;WRITE BYTE
	CALL	RTHEX
	CALL	SPACE
	CALL	RTDE
	LDAX	D
	CALL	RTHEX
	CALL	CRLF
	JMP	VERFY+14

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;RTDE -- Write contents of DE to console as hex
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
RTDE:	MOV	A, D		;WRITE DE
	CALL	RTHEX
	MOV	A, E
	JMP	RTHL+5

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;WC0 -- Write cassette command handler
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
WC0:	CALL	BKLEN		;WC WRITE CASS
	MOV	A, L		;WRITE ADDRESS
	MVI	D, 00H		;ZERO CHECKSUM REG
	CALL	CASW0
	MOV	D, A		;CHECKSUM IN D
	MOV	A, H
	CALL	CASW0
	ADD	D
	MOV	D, A
	MOV	A, B		;WRITE BLOCK LEN
	CALL	CASW0
	ADD	D
	MOV	D, A
	MOV	A, C
	CALL	CASW0
	ADD	D
	MOV	D, A
WC1:	MOV	A, M		;GET MEMORY BYTE
	CALL	CASW0		;OUTPUT
	ADD	D		;ADD CHECKSUM
	MOV	D, A		;SAVE IN D
	CALL	DONE
	JNZ	WC1		;LOOP TIL DONE
	MOV	A, D
	CALL	CASW0
	CALL	CASW2
	LXI	H, CMNT5	;WRITTEN
	CALL	COMNT
	JMP	STRT

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;CASW0 -- Cassette write routine
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CASW0:	PUSH	PSW		;SAVE A
	IN	PORT2		;IS WRITE RELAY ON
	ANI	02H
	JNZ	CASW1
	IN	PORT2		;TURN RELAY ON
	ORI	02H
	OUT	PORT2
	MVI	A, 40H		;SET UP TRANSMIT
	OUT	PORTE
	MVI	A, 0B8H
	OUT	PORTF
	MVI	A, 02H		;CONT REG 3
	OUT	PORTE
	MVI	A, 70H		;CLEAR CTS TU
	OUT	PORTF
	MVI	A, 03H		;ENABLE X-MIT
	OUT	PORTE
	CALL	DELAY
	MVI	A, 76H
	OUT	PORTB		;SET UP CLOCK
	LDA	STK5		;GET SPEED
	OUT	PORT9
	LDA	STK5+1
	OUT	PORT9
	CALL	DELA2
	CALL	DELAY
	MVI	A, 3CH		;OUTPUT CLOCK BYTE
	CALL	CASW0
	MVI	A, 0E6H		;OUTPUT SYNC BYTE
	CALL	CASW0
CASW1:	CALL	ESCAP
	IN	PORTE		;STATUS
	ANI	40H		;READY ?
	JZ	CASW1
	POP	PSW		;GET A
	OUT	PORTF		;OUTPTU
	RET
CASW2:	CALL	DELAS		;WRITE A TRAILER
	MVI	A, 70H		;TURN OFF CLOCK
	OUT	PORTB
	CALL	DELAY		;WRITE A GAP
	IN	PORT2		;GET PORT DATA
	ANI	0FDH		;TURN OFF RELAY
	OUT	PORT2
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;AI0 -- Assign input device command handler
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
AI0:	LHLD	STK13		;SET INPUT DEVICE
	CALL	CHCK
	MVI	B, 00H
	CPI	0BH		;K FOR KEYBD
	JZ	AI1
	INR	B
	CPI	10H		;P FOR PAR PORT
	JZ	AI1
	INR	B
	CPI	13H		;S FOR SERIAL
	JNZ	ERROR		;NO GOOD
AI1:	MOV	A, B
	STA	STK0		;INPUT DEVICE CODE
	JMP	STRT

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;AO0 -- Assign output device command handler
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
AO0:	LHLD	STK13		;ASSIGN OUTPUT DEVICE
	CALL	CHCK
	MVI	B, 00H		;ZERO B
	CPI	16H		;V for VDM
	JZ	AO1
	INR	B
	CPI	10H		;P FOR PAR PORT
	JZ	AO1
	INR	B
	CPI	13H		;S FOR SERIAL
	JNZ	ERROR		;NO GOOD
AO1:	MOV	A, B
	STA	STK1		;OUTPUT DEVICE CODE
	JMP	STRT

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;SR -- Set cassette read speed command handler
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SR:	CALL	CONV0		;CASS READ SPEED
	XCHG			;PUT IN HL
	SHLD	STK3
	JMP	STRT

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;SW -- Set cassette write speed handler
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SW:	CALL	CONV0		;CASS WRITE SPEED
	XCHG			;PUT IN HL
	SHLD	STK5
	JMP	STRT

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;SS -- Set serial port speed command handler
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SS:	CALL	CONV0		;SERIAL SPEED
	MOV	A, E
	OUT	PORTA
	MOV	A, D
	OUT	PORTA
	XCHG
	SHLD	STK7
	JMP	STRT

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;DA0 -- Dump ASCII command handler
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DA0:	CALL	BKLEN		;GET LENGTH
	CALL	CRLF
	MVI	D, 08H		;SET BYTE COUNTER
	CALL	RTHL		;WRITE ADDRESS
	CALL	SPACE
DA1:	CALL	SPACE
	MOV	A, M		;GET MEMORY
	CALL	RTHEX		;WRITE IT
	INX	H
	DCR	D
	JNZ	DA1		;LOOP
	LXI	D, 0FFF8H	;2'S COMP 9
	DAD	D		;SUB H BY 9
	MVI	D, 08H		;SET BYTE COUNTER
	CALL	SPACE
DA2:	CALL	SPACE
	MOV	A, M		;GET BYTE
	ANI	7FH		;MASK BIT 7
	CPI	20H
	JC	SKIP		;NOT CHAR
	CPI	5EH
	JC	PRINT
	CPI	61H
	JC	SKIP		;NOT CHAR
	CPI	7BH
	JC	PRINT		;STILL ASCII
SKIP:	MVI 	A, '.'		;OUTPUT A '.'
PRINT:	CALL	WRITE		;OUTPUT
	CALL	DONE
	JZ	CMPLT		;DONE
	DCR	D		;DECREMENT BYTE COUNT
	JNZ	DA2		;LOOP
	CALL	ESCAP		;WANT TO QUIT ?
	JMP	DA0+3		;CONTINUE

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;HEX -- Hex math command handler
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
HEX:	CALL	BKLEN		;GET ADDR
	DCX	D
	DAD	D
	CALL	RTHL
	DCX	B
	MOV	H, B
	MOV	L, C
	CALL	RTHL
	JMP	STRT

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;SERCH -- Search memory command handler
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SERCH:	CALL	BKLEN
	XCHG			;PUT H IN D
	LHLD	STK13		;GET BUFF
	PUSH	H		;PUT ON STACK
	XCHG			;RESTORE H
CMPR0:	DCX	H
	INX	B
	XCHG			;PUT H IN D
	POP	H		;GET BUFF
	SHLD	STK13		;STORE
	PUSH	H		;SAVE
	XCHG			;RESTORE H
	PUSH	H
	POP	D		;PUT H IN D
	INX	D
CMPR1:	CALL	DONE
	JZ	CMPLT
	PUSH	H
	LHLD	STK13
	MOV	A, M
	POP	H		;RESTORE H
	CPI	0DH		;END OF STRING
	JZ	CMPR2		;YES
	PUSH	D		;SAVE D
	CALL	CONV0		;GET CHAR
	MOV	A, E
	POP	D		;RESTORE D
	CMP	M		;COMPARE
	JZ	CMPR1		;GOOD
	JMP	CMPR0+2
CMPR2:	CALL	ESCAP		;QUIT ?
	XCHG			;GET H
	CALL	RTHL		;WRITE ADDR
	CALL	CRLF
	XCHG			;RESTORE H
	JMP	CMPR0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;INP0 -- Input from port command handler
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
INP0:	CALL	CONV0
	LXI	H, STK17+20	;BUFFER AREA
	MVI	M, 0DBH
	INX	H
	MOV	M, E
	INX	H
	MVI	M, 0C9H
INP1:	CALL	STK17+20	;EXECUTE IT
	CALL	RTHEX
	CALL	DOAGN
	JMP	INP1		;DO AGAIN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;OUT0 -- Output to port command handler
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
OUT0:	CALL	BKLEN
	DCR	E
	MOV	C, L
	LXI	H, STK17+20	;BUFFER AREA
	MVI	M, 07BH		;MOV A, E
	INX	H
	MVI	M, 0D3H
	INX	H
	MOV	M, C
	INX	H
	MVI	M, 0C9H
OUT1:	CALL	STK17+20	;EXECUTE IT
	CALL	DOAGN		;DO AGAIN?
	JMP	OUT1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;DOAGN -- Check for repeat of previous operation
;
;Check to see if the previous operation should be repeated.
;This routine is used by the D, I, and O commands.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DOAGN:	CALL	INPM
	CPI	20H		;A SPACE?
	JNZ	CMPLT		;DONE
	CALL	CRLF
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;DM0 -- Hex dump memory command handler
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DM0:	CALL	CONV0
	XCHG
	CALL	RTHL
	MVI	C, 10H
	MOV	A, M
	CALL	RTHEX
	INX	H
	CALL	SPACE
	DCR	C
	JNZ	DM0+9
	CALL	DOAGN		;REPEAT?
	JMP	DM0+4

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;TABL1 -- Command look-up table
;
;This table contains the packed ASCII command definitions
;and pointers to the command handlers.
:
;PACKED ASCII FORMAT:
;
;For single character commands:
;        - Multiply by 8 and discard overflow
;
;        D = 0x44 * 8
;          = 0x220
;          = 0x20
;
;For two character commands:
;        - Multiply the first character by 8, subtract 0x20
;        - Subtract 0x20 from the first character
;        - Add the two values and discard overflow
;
;       DA = 0x44 0x41
;          = ((0x44 * 8) - 0x20) + (0x41 - 0x20)
;          = 0x221
;          = 0x21
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
TABL1:	DB	11H		;AI
	DW	AI0
	DB	17H		;AO
	DW	AO0
	DB	20H		;D
	DW	DM0
	DB	21H		;DA
	DW	DA0
	DB	28H		;E
	DW	EM0
	DB	35H		;EM
	DW	EM3
	DB	30H		;F
	DB	03		;FLOPPY BOOT
	DB	PORT+08H
	DB	38H		;G
	DW	GO
	DB	40H		;H
	DW	HEX
	DB	48H		;I
	DW	INP0
	DB	68H		;M
	DW	MOVE
	DB	6BH		;MC
	DW	ERROR		;NOT IMPLEMENTED
	DB	78H		;O
	DW	OUT0
	DB	80H		;P
	DW	PROG0
	DB	93H		;RC
	DW	CASR7
	DB	94H		;RD
	DW	ERROR		;NOT IMPLEMENTED
	DB	96H		;RF
	DW	ERROR		;NOT IMPLEMENTED
	DB	0A3H		;RS
	DW	CASR5
	DB	0A6H		;RV
	DW	CASR8
	DB	98H		;S
	DW	SERCH
	DB	0AAH		;SR
	DW	SR
	DB	0ABH		;SS
	DW	SS
	DB	0AFH		;SW
	DW	SW
	DB	0B0H		;V
	DW	VERFY
	DB	0BBH		;WC
	DW	WC0
	DB	0BCH		;WD
	DW	ERROR		;NOT IMPLEMENTED
	DB	0BEH		;WF
	DW	ERROR		;NOT IMPLEMENTED
	DB	0D0H		;Z
	DW	ZERO

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;TABL2 -- Initial mode table
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
TABL2:	DB	0F0H		;SCROLL SPEED
	DB	59H		;CASS READ SPEED
	DB	02H		;2500 BAUD
	DB	20H		;CASS WRITE SPEED
	DB	03H		;2500 BAUD
	DB	70H		;SERIAL SPEED
	DB	04H		;110 BAUD

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Monitor Strings
;
;All strings are terminated by setting the high bit of the
;last character.
;
;CMNT0 is the prompt string.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CMNT6:	DB	'ESCAP', 0C5H
CMNT5:	DB	'WRITTE', 0CEH
CMNT4:	DB	'  COMPLET', 0C5H
CMNT3:	DB	'VERIFY', 0A0H
CMNT2:	DB	'TAPE '
CMNT1:	DB	' ERROR', 0A0H
CMNT0:	DB	0DH, 0AH, '>', 0A0H

	END
