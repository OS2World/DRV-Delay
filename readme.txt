The DELAY driver - version 2.1
------------------------------

This is a simple OS/2 device driver for providing a timed delay during
system startup from CONFIG.SYS.  It is useful in situations where several 
machines are being brought up at the same time, but some must not proceed 
past a certain point until others are fully functional.  It is also very 
useful when a message from some device driver scrolls by on the screen
too fast to be read or analyzed.


Installation
============
Copy DELAY.SYS to a convenient directory; it does not have to be on your
boot disk, and it may be convenient to keep it elsewhere if you are in
the habit of reformatting it to install new versions or betas of OS/2!


Usage
=====
To insert a delay of up to 30 minutes in a CONFIG.SYS file for OS/2,
insert the following statement in CONFIG.SYS and reboot the system
(optional parts are shown here in square brackets):

		DEVICE=d:\path\DELAY.SYS [/K] mm:ss [message]

where

	d:\path\	represents where you have chosen to store DELAY.SYS,
    
	/K		is an optional switch (see below); /k, -K and -k are
			equivalent.
	mm:ss		is the intended delay in minutes and seconds.
	message		is an optional message that will appear during the
			delay period. 
		  
	If /K (or its equivalent) is specified, the user can choose to exit
	the delay period immediately by pressing any key (apart from SHIFT,
	CTRL, ALT etc.) on the keyboard. An advisory message reminds the user
	that this option has been selected.

	The possible forms of mm:ss are quite liberal:
	   2:00 Two minutes, no seconds
	   2:   Two minutes
	   2    Two seconds
	   :02  Two seconds
	   :120 One-hundred-twenty seconds (i.e., two minutes)
	Any variant of zero seconds (e.g., 0, 0:00) will cause no delay
	   to happen at all, but the message will be issued to the screen.
	The maximum delay permitted is 30 minutes (1800 seconds), ir-
	   respective of how that may've been represented on the command
	   line.

     Errors:

	Common errors (e.g., missing or excessive delay time) are
	   reported as General Failures to OS/2, with the message
		 'DELAY driver - invalid argument'
	   on the screen, and the driver will fail to load.
	An invalid switch (e.g. /X) generates a similar, but appropriate,
	   message.

     Examples:
	   
	   DEVICE=c:\os2.ext\DELAY.SYS 2:00 ***Wait for NetWare to come up***
	   (waits for two minutes, showing the message, while waiting for
		the NetWare server to come up, in case both the NetWare server
		and OS/2 computer were subjected to a common power failure)
	   
	   DEVICE=c:\os2.ext\DELAY.SYS :05
	   (inserts a five-second delay to leave time to observe a message
		that may've been displayed by a previously executed DEVICE=
		statement.)

	   DEVICE=c:\os2.ext\DELAY.SYS /K 1:00
	   (inserts a one minute delay, but allows a keypress to skip the
		delay.)

Operation
=========
The DELAY driver performs no useful function except at initialisation
time.  At this time it delays for a time specified by an argument on the
DEVICE= line, while displaying the short (optional) message.  At the 
conclusion of the delay time, CONFIG.SYS processing proceeds normally.

The driver unloads after doing its job, so there is no permanent use of
memory. 

Multiple copies of the driver may be loaded if multiple delays are
required (since the delay happens when the driver is loaded, the
position of the DEVICE= line determines the point during system
initialisation at which the delay takes place).

Limitations
===========
Delays are unconditional.  There is no way in this driver to specify,
for instance, "Delay 2:00 minutes if--and only if--the network is not yet
up and running."


Copyright & License
===================
This Software and its documentation are Copyright, 2003 by the Author:
			R D Eager
			45 Fleetwood Avenue
			Herne Bay
			United Kingdom
			CT6 8QW

Email:			rde@tavi.co.uk
Telephone:		+44 1227 367270

License is granted to User to duplicate and disseminate this software
product, and to use on one computer running OS/2, PROVIDED user agrees to
1) hold Author free of any and all liability for any consequences of use
of the Software, 2) copy this DELAY.DOC file and retain it with any copy
of DELAY.SYS copied to any medium, and 3) not charge any other person or
organization for such copies.

History:
1.0	Initial version using DosSleep
1.1	Revised version using DevHlp timer calls
1.2	Fixed crash if zero delay given
1.3	Removed stray STOSB instruction corrupting other code
	(thanks to Carol Anne Ogdin)
1.4	Fixed problem parsing certain time values
1.5	Fixed data corruption for delays greater than 59 seconds
1.6	Provided facility (/K switch) to skip delay by pressing a key
1.7	Added BLDLEVEL, etc.
2.0	Revised build method; repackaging.
2.1	Use noncritical init error code to unload completely.

Bob Eager
rde@tavi.co.uk
April 2003

