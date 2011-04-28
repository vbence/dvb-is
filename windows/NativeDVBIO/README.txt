NativeDVBIO
===========

Windows implementation of the natve libraries needed by the JAVA DVB
Input Stream Project.


Compiling
=========

The code is written for Delphi 7. It depends on DSPack (with the DirectX
headers) and JNI.pas. You have to obtain and extract them to a
directory, and add that directory to Delphi's search path by appending
it (seaprators are semicolos):
Project > Options > Directories/Conditionals > Search path


JNI

JNI.pas can be obtained thru Project JEDI:
http://delphi-jedi.org/


DSPack

DSPack can be obtained thru the author's blog:
http://www.progdigy.com/

There are tons of incompatible versions out there (also version with
bugs?), check out the forums too:
http://www.progdigy.com/forums/

I found a 'working' version bundeled with M.Majoor's MajorUdpSend:
http://www.majority.nl/


Installing
==========

You have to copy the compiled .DLL to the system directory. An other
option is to put the file into the directory your JAVA project is run
from. (Possibly the second idea is the best to avoid version conflicts
when two different user programs install two different versions of
NativeDVBIO.)
