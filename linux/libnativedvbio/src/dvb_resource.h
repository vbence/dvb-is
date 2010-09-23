/*
This file is part of libNativeDVBIO by Varga Bence.

libNativeDVBIO is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

libNativeDVBIO is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with libNativeDVBIO.  If not, see <http://www.gnu.org/licenses/>.
*/

#ifndef _DVB_RESOURCE_H_
#define _DVB_RESOURCE_H_

#include <stdint.h>

// Buffer length to implement dvbres_available() function. This
// equals the maximum number returned by dvbres_available(). This
// buffer is transparent and has no further implications at all
// (not bottleneck-ish).
#define DVBRES_BUFFER_LENGTH (400 * 188)

// structure to hold the currentstate of the resource
struct dvb_resource {
	
	// handle of open frontend device
	int frontend;

	// handle of open demux device
	int demux;

	// handle of open DVR device
	int dvr;
	
	// Last error message if error occured. UNDEFINED if no error
	// occured during last function call. Functions are encouraged
	// to set error_msg[0] and error_code to zero though.
	// (see: _dvbres_ok)
	char error_msg[250];
	
	// Last error message if error occured. UNDEFINED if no error
	// occured during last function call. (see: error_msg)
	int error_code;
	
	// circular buffer with the sole purpose of implementing
	// java.io.InputStream.available()
	char* buffer;
	// start of data in the buffer	
	int data_start;
	// length of data in the buffer
	int data_length;
};


// list available devices: in form of <name> TAB <identifier> TAB <type> [TAB ...]
// types: '0': DVB-S '1': DVB-C '2': DVB-T, and returns the length of this
// enumeration in bytes.
// (returns -1 on error)
int dvbres_listdevices(struct dvb_resource* res, char* buffer, int max_length);

// initiates the structure
int dvbres_init(struct dvb_resource* res);

// open a resource (tuning) (returns -1 on error)
int dvbres_open(struct dvb_resource* res, uint64_t freq, char* device);

// get if signal is present
int dvbres_signalpresent(struct dvb_resource* res);

// get if signal is locked
int dvbres_signallocked(struct dvb_resource* res);

// get signal strength 0: bad, 100: good
int dvbres_getsignalstrength(struct dvb_resource* res);

// get signal quality 0: bad, 100: good
int dvbres_getsignalquality(struct dvb_resource* res);

// query bytes available immediately (pre-buffered) (returns -1 on error)
int dvbres_available(struct dvb_resource* res);

// read bytes (return number of bytes red) (returns -1 on error)
int dvbres_read(struct dvb_resource* res, void* target, int max_length);

// closes the resource (returns -1 on error)
int dvbres_close(struct dvb_resource* res);

// releases all resources previously allocated (returns -1 on error)
int dvbres_release(struct dvb_resource* res);


// Only the public interface is defined here. See dvb_resource.c for protected
// functions.

#endif /* _DVB_RESOURCE_H_ */
