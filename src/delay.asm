 	PAGE	64,132
	TITLE	DELAY - device driver for timed delay on startup
	NAME	DELAY
	.286
;
; Description:
;	OS/2 device driver for providing timed delay during startup
;	Takes a single mandatory argument: the required delay in
;	minutes and/or seconds.If only minutes are supplied,
;	they must be followed by a colon. An optional second argument
;	is treated as a message and output to the screen.
;	The /K (or -K) switch allows early exit from the delay loop by
;	pressing any key during the delay period; it must appear before
;	any time value.
;
;	Examples:
;		DEVICE=C:\DELAY.SYS 2:30
;		DEVICE=C:\DELAY.SYS 150
;		DEVICE=C:\DELAY.SYS 3: Please wait...network loading
;		DEVICE=C:\DELAY.SYS /K 150
;		DEVICE=C:\DELAY.SYS /K 120 Delaying for 2 minutes...
;
; OS/2 versions supported:
;	2.x
;	3.x
;	4.x
;
; Version:
;	2.1
;
; Date:
;	April 2003
;
; Author:
;	R D Eager
;
; History:
;	1.0	Initial version using DosSleep
;	1.1	Revised version using DevHlp timer calls
;	1.2	Fixed crash if zero delay given
;	1.3	Removed stray STOSB instruction corrupting other code
;		(thanks to Carol Anne Ogdin)
;	1.4	Fixed problem parsing certain time values
;	1.5	Fixed data corruption for delays greater than 59 seconds
;	1.6	Provided facility (/K switch) to skip delay by pressing a key
;	1.7	Added BLDLEVEL, etc.
;	2.0	Revised build method; repackaging.
;	2.1	Use noncritical init error code to unload completely.
;
	PAGE
;
; Copyright and License:
;
; This Software and its documentation are Copyright, 1993, 2003 by the Author:
;			Robert D Eager
;			45 Fleetwood Avenue
;			Herne Bay
;			United Kingdom
;			CT6 8QW
;
;	Telephone:	+44 1227 367270
;	Email:		rde@tavi.co.uk
;
; License is granted to User to duplicate and disseminate this software
; product, and to use on one computer running OS/2, PROVIDED user agrees to
; 1) hold Author free of any and all liability for any consequences of use
; of the Software, 2) copy the DELAY.DOC file and retain it with any copy
; of DELAY.SYS copied to any medium, and 3) not charge any other person or
; organization for such copies.  Use of this product on more than one
; computer in an organization may be separately negotiated by contacting
; the Author, above.
;
	PAGE+
;
	.XLIST
	INCLUDE	DEVHLP.INC
	INCLUDE	DEVSYM.INC
	.LIST
;
; Constants
;
STDOUT		EQU	1		; Standard output handle
;
MAXMES		EQU	100		; Maximum length of user message
MAXSEC		EQU	1800		; Maximum delay in seconds (30 mins)
;
TAB		EQU	09H		; Tab character
CR		EQU	0DH		; Carriage return
LF		EQU	0AH		; Linefeed
;
; External references
;
	EXTRN	DosClose:FAR
	EXTRN	DosDevIOCtl:FAR
	EXTRN	DosOpen:FAR
	EXTRN	DosRead:FAR
	EXTRN	DosWrite:FAR
;
; Structure definitions
;
KBS	STRUC				; Keyboard input data structure
KASCII	DB	?			; ASCII value received
KSCAN	DB	?			; Scan code received
KSTAT	DB	?			; Keystroke status
KNLS	DB	?			; NLS status
KSS	DW	?			; Shift status
KTIME	DD	?			; Time stamp
KBS	ENDS
;
	SUBTTL	Data areas
	PAGE+
;
DGROUP	GROUP	_DATA
;
_DATA	SEGMENT	WORD PUBLIC 'DATA'
;
; Device driver header
;
HEADER	DD	-1			; Link to next device driver
	DW	1000000010000000B	; Device attributes:
;		|     |||_______________;  function level 001
;		|_______________________;  character device
	DW	OFFSET STRATEGY		; Strategy entry point
	DW	0			; IDC entry point - not used
	DB	'DELAY$$$'		; Device name
	DB	8 DUP (0)		; Reserved
;
DevHlp	DD	?			; Entry point to DevHlp
COUNT	DW	?			; Holds timer count (seconds)
WLEN	DW	?			; Receives DosWrite length
KHAND	DW	?			; Receives keyboard handle
KACT	DW	?			; Receives keyboard open action
KCOUNT	DW	?			; Keyboard transfer count
KDATA	KBS	<>			; Keyboard input data
MAREA	DB	(MAXMES+1) DUP (0)	; Optional message area
;
KBD	DB	'KBD$',0		; name of keyboard device
;
MES1	DB	'DELAY driver - invalid argument',CR,LF,0
MES2	DB	'DELAY driver - invalid switch'
MES3	DB	CR,LF,0
MES4	DB	'(Press any key to skip the delay)',CR,LF,0
MES5	DB	'DELAY driver - cannot open keyboard',CR,LF,0
;
	DB	'*** Copyright (C) R D Eager  2003 ***'
;
_DATA	ENDS
;
	SUBTTL	Main code
	PAGE+
;
_TEXT	SEGMENT	WORD PUBLIC 'CODE'
;
	ASSUME	CS:_TEXT,DS:DGROUP,ES:NOTHING
;
; Strategy entry point; ES:BX points to the request packet
;
; We support only initialise (of course) and deinstall. Deinstall allows multiple
; calls to load this driver, thus providing multiple delays within CONFIG.SYS.
; If deinstall were not provided, only the first load would succeed.
;
STRATEGY	PROC	FAR
;
	MOV	AL,ES:[BX].ReqFunc	; get function code
	CMP	AL,CMDInit		; initialise function?
	JE	STRA10			; j if so
	CMP	AL,CMDDeInstall		; deinstall function?
	JE	STRA20			; j if so
	MOV	AX,(STERR OR STDON OR 3); error and done status, unknown command
	JMP	SHORT STRA30		; use common exit code
;
STRA10:	CALL	INIT			; do the initialisation
	JMP	SHORT STRA30		; common exit
;
STRA20:	MOV	AX,STDON		; done status - deinstall OK
;
STRA30:	MOV	ES:[BX].ReqStat,AX	; store status in request packet
	RET				; return to system
;
STRATEGY	ENDP
;
	SUBTTL	Initialisation code
	PAGE+
;
; Initialisation code. All of this code is present only during initialisation;
; none of the driver data is used after that time either.
;
; ES:BX points to the request packet.
; Status is returned in AX.
;
INIT	PROC	NEAR
;
; Process the INIT arguments
;
	PUSH	BX			; save request packet offset for later
	PUSH	ES			; save request packet segment for later
	PUSH	DS			; save data segment for later
;
	MOV	AX,WORD PTR ES:[BX].InitDevHlp
					; offset of DevHlp entry point
	MOV	WORD PTR DevHlp,AX	; save it
	MOV	AX,WORD PTR ES:[BX].InitDevHlp+2
					; segment of DevHlp entry point
	MOV	WORD PTR DevHlp+2,AX	; save it
	MOV	SI,WORD PTR ES:[BX].InitParms
					; offset of INIT arguments
	MOV	DS,WORD PTR ES:[BX].InitParms+2
					; segment of INIT arguments
;
	ASSUME	CS:_TEXT,DS:NOTHING,ES:NOTHING
;
	XOR	CX,CX			; clear 16 bit delay value (seconds)
	XOR	BX,BX			; use as minutes counter
	XOR	BP,BP			; use as /K indicator
	CLD				; autoincrement
;
INIT01:	LODSB				; skip leading whitespace
	CMP	AL,' '
	JE	INIT01
	CMP	AL,TAB
	JE	INIT01
	DEC	SI			; back to first non-space
;
INIT02:	LODSB				; skip filename
	CMP	AL,' '
	JE	SHORT INIT03		; found next separator
	CMP	AL,TAB
	JE	SHORT INIT03		; found next separator
	CMP	AL,0			; found terminator?
	JE	SHORT INIT04		; j if so
	JMP	INIT02			; else keep looking
;
INIT03:	LODSB				; strip separating whitespace
	CMP	AL,' '
	JE	INIT03
	CMP	AL,TAB
	JE	INIT03
;
INIT04:	DEC	SI			; back to first non-space, if any
;
; We are now at the start of the argument proper
; (or at the end of the whole line)
;
	LODSB				; check for switch character
	CMP	AL,'/'			; switch?
	JE	INIT05			; j if so
	CMP	AL,'-'			; alternate switch?
	JE	INIT05
	DEC	SI			; back again
	JMP	SHORT INIT09		; check for time value
;
INIT05:	LODSB				; get switch letter
	OR	AL,AL			; end of argument?
	JNZ	INIT06			; j if not
	JMP	INIT30			; else error
;
INIT06:	CMP	AL,'K'			; /K?
	JE	INIT07			; j if so
	CMP	AL,'k'			; /k?
	JE	INIT07			; j if so
	JMP	INIT30			; else error
;
INIT07:	INC	BP			; set keypress flag
;
INIT08:	LODSB				; skip separating whitespace
	CMP	AL,' '
	JE	INIT08
	CMP	AL,TAB
	JE	INIT08
	DEC	SI			; back to first non-separator
;
; We have now processed any switches, and are at the start of any
; specified time value
;
INIT09:	LODSB				; get next character
	OR	AL,AL			; end of argument?
	JZ	INIT20			; j if so
	CMP	AL,':'			; minutes separator?
	JNE	INIT11			; j if not
	IMUL	CX,60			; convert to seconds	
	JNO	INIT10			; j if not too big
	JMP	INIT31			; else error
;
INIT10:	MOV	BX,CX			; save for later
	XOR	CX,CX			; reinitialise for seconds
	JMP	INIT09			; continue scan
;
INIT11:	CMP	AL,' '			; separator?
	JE	INIT16			; go to accumulate message
	CMP	AL,TAB			; separator?
	JE	INIT16			; go to accumulate message
	CMP	AL,'0'			; check for valid digit
	JNB	INIT12			; j if valid
	JMP	INIT31			; else error
;
INIT12:	CMP	AL,'9'
	JNA	INIT13			; j if in range
	JMP	INIT31			; else error
;
INIT13:	SUB	AL,'0'			; get value
	CBW				; make word
	IMUL	CX,10			; multiply up...
	JNO	INIT14			; j if not too big...
	JMP	INIT31			; ...else error
;
INIT14:	ADD	CX,AX			; ...and add in
	JNO	INIT09			; if not too big,
					; see if more to do...
INIT15:	JMP	INIT31			; ...else error
;
; Combine minutes and seconds for complete time value
;
INIT16:	ADD	CX,BX			; retrieve minutes part
	JO	INIT15			; j if too big
;
; A further separator was found. Use rest of line as a message.
;
INIT17:	LODSB				; skip whitespace
	CMP	AL,' '
	JE	INIT17
	CMP	AL,TAB
	JE	INIT17
	DEC	SI			; back to first non-space
	POP	ES			; get data segment
;
	ASSUME	CS:_TEXT,DS:NOTHING,ES:DGROUP
;
	PUSH	ES			; save it again
	PUSH	CX			; save delay value
	MOV	CX,MAXMES		; maximum length
	MOV	DI,OFFSET MAREA		; where to put it
;
INIT18:	LODSB				; get next message byte
	STOSB				; save it
	OR	AL,AL			; end?
	JZ	INIT19			; j if so
	LOOP	INIT18			; else keep copying unless full
;
INIT19:	POP	CX			; recover delay value
;
; End of argument. CX contains the required delay in seconds.
;
INIT20:	CMP	CX,MAXSEC		; in range?
	JNA	INIT21			; j if so...
	JMP	INIT31			; ...else error
;
INIT21:	POP	DS			; recover data segment
	POP	ES			; recover request packet segment
;
	ASSUME	CS:_TEXT,DS:DGROUP,ES:NOTHING
;
	CMP	MAREA,0			; any additional message?
	JE	INIT22			; j if not
	MOV	AX,OFFSET MAREA
	CALL	DOSOUT			; else display it
	MOV	AX,OFFSET MES3		; message tail
	CALL	DOSOUT			; display it
;
INIT22:	OR	CX,CX			; zero delay?
	JNZ	INIT2X			; j if not
	JMP	INIT28			; else skip timer
;
INIT2X:	OR	BP,BP			; looking for keypresses?
	JZ	INIT23			; j if not
	MOV	AX,OFFSET MES4		; advisory message
	CALL	DOSOUT			; display it
;
; Open the keyboard so that we can look for keypresses
;
	PUSH	DS			; name of keyboard device
	PUSH	OFFSET DGROUP:KBD
	PUSH	DS			; where to put handle
	PUSH	OFFSET DGROUP:KHAND
	PUSH	DS			; where to put open action
	PUSH	OFFSET DGROUP:KACT
	PUSH	0			; file size (not applicable)
	PUSH	0
	PUSH	0			; file attribute (not applicable)
	PUSH	1			; open flag (open, no create)
	PUSH	42H			; open mode (read/write, deny none)
	PUSH	0			; reserved DWORD
	PUSH	0
	CALL	DosOpen			; do it
	OR	AX,AX			; OK?
	JNZ	INIT29			; j if not
;
; Register timer routine to be called once per second
;
INIT23:	MOV	COUNT,CX		; save delay in memory for timer
	MOV	AX,OFFSET TIMER		; set up for DevHlp call
	MOV	BX,32			; ticks per second
	MOV	DL,DevHlp_TickCount	; required function
	CALL	DevHlp			; register once-per-second timer
;
; Wait for timer to count down to zero, or perhaps for a keypress
;
INIT24:	OR	BP,BP			; should we look for a keypress?
	JZ	INIT25			; j if not
;
; Look for a keypress, and bail out if we see one
;
	MOV	KCOUNT,08001H		; try to read one keystroke,
					; return if none available

	MOV	KDATA.KSTAT,0		; clear out status before call
	MOV	KDATA.KNLS,0		; set reserved field to zero
	PUSH	DS			; address of data packet
	PUSH	OFFSET DGROUP:KDATA.KASCII
	PUSH	DS			; address of parameter packet
	PUSH	OFFSET DGROUP:KCOUNT
	PUSH	74H			; function code (read character data)
	PUSH	4			; keyboard category
	PUSH	KHAND			; keyboard handle
	CALL	DosDevIOCtl		; try to read
	TEST	KDATA.KSTAT,40H		; character read?
	JNZ	INIT26			; j if so...exit wait loop
;
INIT25:	MOV	AX,COUNT		; get current value
	CMP	AX,0			; test it
	JG	INIT24			; test > 0 in case goes negative
;
; End of wait (for whatever reason); deregister timer routine
;
INIT26:	MOV	AX,OFFSET TIMER		; set up for DevHlp call
	MOV	DL,DevHlp_ResetTimer	; required function
	CALL	DevHlp
;
; Close keyboard, if open
;
	OR	BP,BP			; keyboard open?
	JZ	INIT28			; j if not
	PUSH	KHAND			; keyboard handle
	CALL	DosClose		; ignore any error
;
INIT28:	POP	BX			; recover request header offset
	XOR	AX,AX
	MOV	WORD PTR ES:[BX].InitEcode,AX
					; lose code segment
	MOV	WORD PTR ES:[BX].InitEdata,AX
					; lose data segment
	MOV	AX,(STERR OR STDON OR 15H)
					; error and done status, noncritical
	RET
;
; Failure to open keyboard
;
INIT29:	MOV	AX,OFFSET MES5		; error message
	JMP	SHORT INIT32		; use common code
;
; Invalid switch detected
;
INIT30:	MOV	AX,OFFSET MES2		; error message
	JMP	SHORT INIT32		; use common code
;
; Invalid argument detected
;
INIT31:	MOV	AX,OFFSET MES1		; error message; drop through
;
INIT32:	POP	DS			; recover data segment
	POP	ES			; recover request packet segment
	POP	BX			; recover request packet offset
	CALL	DOSOUT			; display message
	MOV	WORD PTR ES:[BX].InitEcode,0
					; lose code segment
	MOV	WORD PTR ES:[BX].InitEdata,0
					; lose data segment
	MOV	AX,810CH		; error/done/general failure
	RET
;
INIT	ENDP
;
	SUBTTL	Timer handler
	PAGE+
;
; Timer routine; called once per second while awaiting time expiry
;
TIMER	PROC	FAR
	DEC	COUNT			; count down by one second
	RET
TIMER	ENDP
;
	SUBTTL	Output message
	PAGE+
;
; Routine to output a string to the screen.
;
; Inputs:
;	AX	- offset of zero terminated message
;
; Outputs:
;	AX	- not preserved
;
DOSOUT	PROC	NEAR
;
	PUSH	DI			; save DI
	PUSH	CX			; save CX
	PUSH	ES			; save ES
	PUSH	AX			; save message offset
	PUSH	DS			; copy DS...
	POP	ES			; ...to ES
	MOV	DI,AX			; ES:DI point to message
	XOR	AL,AL			; set AL=0 for scan value
	MOV	CX,100			; just a large value
	REPNZ	SCASB			; scan for zero byte
	POP	AX			; recover message offset
	POP	ES			; recover ES
	POP	CX			; recover CX
	SUB	DI,AX			; get size to DI
	DEC	DI			; adjust
	PUSH	STDOUT			; standard output handle
	PUSH	DS			; segment of message
	PUSH	AX			; offset of message
	PUSH	DI			; length of message
	PUSH	DS			; segment for length written
	PUSH	OFFSET DGROUP:WLEN	; offset for length written
	CALL	DosWrite		; write message
	POP	DI			; recover DI
;
	RET
;
DOSOUT	ENDP
;
_TEXT	ENDS
;
	END
