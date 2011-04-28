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

#define MIN(X,Y) ((X) < (Y) ? (X) : (Y))

#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#include <sys/ioctl.h>
#include <unistd.h>
#include <fcntl.h>
#include <poll.h>
#include <errno.h>

#include <linux/dvb/version.h>
#include <linux/dvb/frontend.h>
#include <linux/dvb/dmx.h>

#include "dvb_resource.h"

/*
int _dvbres_close_and_error(struct dvb_resource* res, char* msg, int code, int handle);
int _dvbres_error(struct dvb_resource* res, char* msg, int code);
int _dvbres_ok(struct dvb_resource* res);
int _dvbres_ok_retval(struct dvb_resource* res, int retval);
int _dvbres_fillbuffer(struct dvb_resource* res);
*/

// Saves error parameters and returns -1
int _dvbres_error(struct dvb_resource* res, char* msg, int code) {
	strncpy(&res->error_msg[0], msg, sizeof(res->error_msg));
	res->error_msg[sizeof(res->error_msg) - 1] = 0;
	res->error_code = code;
	return -1;
}

// All OK with return value - zeroes error_msg and error_code and returns retval 
int _dvbres_ok_retval(struct dvb_resource* res, int retval) {
	res->error_msg[0] = 0;
	res->error_code = 0;	
	return retval;
}

// All OK - zeroes error_msg and error_code and return zero 
int _dvbres_ok(struct dvb_resource* res) {
	return _dvbres_ok_retval(res, 0);
}

// Fill the circular buffer. Only used when dvres_available() is called.
int _dvbres_fillbuffer(struct dvb_resource* res) {
	if (!res->dvr)
		return _dvbres_error(res, "Resource not open", -1);
	
	// if no buffer allocated yet then we do it now
	if (res->buffer == NULL) {
		char* buffer = malloc(DVBRES_BUFFER_LENGTH);
		if (buffer == NULL)
			return _dvbres_error(res, "Allocationg pre-read buffer", -1);
		res->buffer = buffer;
		res->data_start = 0;
		res->data_length = 0;
	}
	
	// buffer full. This is NOT a buffer overflow situtation! We do not know
	// if there is any more datra to read, and the we kno wnothing about the
	// driver's buffer either.
	if (res->data_length >= DVBRES_BUFFER_LENGTH)
		return _dvbres_ok(res);
		
	int pos = (res->data_start + res->data_length) % DVBRES_BUFFER_LENGTH;
	
	// forward region
	if (pos >= res->data_start) {
		int bytes_red = read(res->dvr, &res->buffer[pos], DVBRES_BUFFER_LENGTH - pos);
		if (bytes_red == -1) {
			if (errno == EWOULDBLOCK) {
				return 0;
			} else {
				return _dvbres_error(res, "Reading from device", errno);
			}
		}
		if (bytes_red == 0)
			return 0;
		res->data_length += bytes_red;
	}
	
	pos = (res->data_start + res->data_length) % DVBRES_BUFFER_LENGTH;
	if (pos < res->data_start) {
		int bytes_red = read(res->dvr, &res->buffer[pos], res->data_start - pos);
		if (bytes_red <= 0)
			return 0;
		res->data_length += bytes_red;
	}
	
	return 0;
}

int dvbres_init(struct dvb_resource* res) {
	memset(res, 0, sizeof(struct dvb_resource));
	return _dvbres_ok(res);
}

int dvbres_listdevices(struct dvb_resource* res, char* buffer, int max_length) {
	
	// spaces
	memset(buffer, 0, max_length);
	// BUG: memset(buffer, max_length, ' ');
	
	// terminating zeros
	buffer[--max_length] = 0;
	buffer[0] = 0;
	
	char frontname[32];
	char adaptername[32];
	int rc;
	int pos = 0;
	
	int ifnum = 0;
	while (pos < max_length) {
		sprintf(adaptername, "/dev/dvb/adapter%d", ifnum);
		sprintf(frontname, "/dev/dvb/adapter%d/frontend0", ifnum);
		
		// opening device
		int front = open(frontname, O_RDWR);
		if (front == -1)
			return _dvbres_ok_retval(res, pos);
		
		// reading status with the purpose of identifying DVB-S
		struct dvb_frontend_info finfo;
		rc = ioctl(front, FE_GET_INFO, &finfo);
		if (rc) {
			close(front);
			return _dvbres_error(res, "Rading frontend info", errno);
		}
		
		// closing device
		rc = close(front);
		if (rc)
			return _dvbres_error(res, "Closing frontend", errno);
		
		// replace tabs with spaces (tab is used as separator)
		unsigned int i;
		for (i=0; i<sizeof(finfo.name); i++)
			if (finfo.name[i] == '\t')
				finfo.name[i] = ' ';
		
		
		int slen;
		
		// tab (if not the first device)
		if (ifnum > 0) {
			if (pos >= max_length)
				return _dvbres_error(res, "Device enum buffer too small", -1);
			buffer[pos++] = '\t';
		}
		
		// space check
		slen = strlen(finfo.name);
		if (pos + slen >= max_length)	
			return _dvbres_error(res, "Device enum buffer too small", -1);
		// copy device name
		strncpy(&buffer[pos], finfo.name, max_length - pos);
		pos += slen;
		
		// tab
		if (pos >= max_length)
			return _dvbres_error(res, "Device enum buffer too small", -1);
		buffer[pos++] = '\t';
		
		// space check
		slen = strlen(adaptername);
		if (pos + slen >= max_length)	
			return _dvbres_error(res, "Device enum buffer too small", -1);
		// copy device name
		strncpy(&buffer[pos], adaptername, max_length - pos);
		pos += slen;
		
		// device type
		if (pos + 1 >= max_length)
			return _dvbres_error(res, "Device enum buffer too small", -1);
		buffer[pos++] = '\t';
		buffer[pos++] = '0' + finfo.type;
		
		
		// next device
		ifnum++;
	}
	
	return _dvbres_error(res, "Device enum buffer to small", -1);
}

int dvbres_open(struct dvb_resource* res, uint64_t freq, char* device) {

	// return value (code) of calls
	int rc;
	
	// the index of adaper actually used	
	int adapternum = 0;
		
	// temporaray field to hold the root path (/dev/dvb/adapterN)
	char devprefix[32];

	// temporaray field to hold device names (/dev/dvb/adapterN/{something}M)
	char devname[32];
	
	// information about the actual frontend	
	struct dvb_frontend_info finfo;
	
	// if no device is given
	if (device == NULL) {

		// opening device
		do {
			
			// generate the root device name	to devprefix		
			sprintf(devprefix, "/dev/dvb/adapter%d", adapternum);
			
			// generate the next device name and open it
			sprintf(devname, "%s/frontend0", devprefix);
			res->frontend = open(devname, O_RDWR);
			if (!res->frontend)
				return _dvbres_error(res, "Opening front", errno);
			
			// reading status with the purpose of identifying tuner type
			rc = ioctl(res->frontend, FE_GET_INFO, &finfo);
			if (rc) {
				close(res->frontend);
				return _dvbres_error(res, "Reading frontend info", errno);
			}
			
			// if not DVB-T then we skip to the next adapter
			if (finfo.type != 2) {
				close(res->frontend);
				res->frontend = 0;
				adapternum++;
			}
		} while (!res->frontend);
	
	} else { // if device
		
		// copy the device parameter to the devprefix
		strncpy(devprefix, device, sizeof(devprefix));
		
		// opening device
		sprintf(devname, "%s/frontend0", devprefix);
		res->frontend = open(devname, O_RDWR);
		if (!res->frontend)
			return _dvbres_error(res, "Opening front", errno);

		// reading status with the purpose of identifying tuner type
		rc = ioctl(res->frontend, FE_GET_INFO, &finfo);
		if (rc) {
			close(res->frontend);
			return _dvbres_error(res, "Reading frontend info", errno);
		}
		
		// if not DVB-T then we close and return an error
		if (finfo.type != 2) {
			close(res->frontend);
			res->frontend = 0;
			return _dvbres_error(res, "Device is not a DVB-T frontend", -1);
		}
		
	} // if device
	
	struct dvb_frontend_parameters fe_params;
	// common parameters (DVB-S may need frequency in KHZ - not tested)
	fe_params.frequency = finfo.type == FE_QPSK ? freq / 1000 : freq;
	fe_params.inversion = INVERSION_AUTO;
	
	// DVB-S parameters	
	fe_params.u.qpsk.fec_inner = FEC_AUTO;
	
	// DVB-C	
	fe_params.u.qam.fec_inner = FEC_AUTO;
	fe_params.u.qam.modulation = QAM_AUTO;
	
	// DVB-T parameters
	fe_params.u.ofdm.bandwidth = BANDWIDTH_AUTO;
	fe_params.u.ofdm.constellation = QAM_AUTO;
	fe_params.u.ofdm.code_rate_HP = FEC_AUTO;
	fe_params.u.ofdm.code_rate_LP = FEC_AUTO;
	fe_params.u.ofdm.transmission_mode = TRANSMISSION_MODE_AUTO;
	fe_params.u.ofdm.guard_interval = GUARD_INTERVAL_AUTO;
	fe_params.u.ofdm.hierarchy_information = HIERARCHY_AUTO;
	
	rc = ioctl(res->frontend, FE_SET_FRONTEND, &fe_params);
	if (rc) {
		close(res->frontend);
		return _dvbres_error(res, "Tuning", errno);
	}
	
	// setting up demux to forward ALL pids to the DVR device
	
	sprintf(devname, "%s/demux0", devprefix);
	res->demux = open(devname, O_RDWR);
	if (!res->demux) {
		close(res->frontend);
		return _dvbres_error(res, "Opening demux", errno);
	}
	
	struct dmx_pes_filter_params filter;
	filter.pid = 8192;
	filter.input = DMX_IN_FRONTEND;
	filter.output = DMX_OUT_TS_TAP;
	filter.pes_type = DMX_PES_OTHER;
	filter.flags = DMX_IMMEDIATE_START;
	rc = ioctl(res->demux, DMX_SET_PES_FILTER, &filter);
	if (rc) {
		close(res->frontend);
		close(res->demux);
		return _dvbres_error(res, "Setting up pes filter", errno);
	}

	
	//	opening DVR device (non-blocking mode)
	sprintf(devname, "%s/dvr0", devprefix);
	res->dvr = open(devname, O_RDONLY | O_NONBLOCK);
	if (!res->dvr) {
		close(res->frontend);
		close(res->demux);
		return _dvbres_error(res, "Opening dvr", errno);
	}
	
	// all ok
	return _dvbres_ok(res);
}

// Try to fill the buffer and return number of bytes buffered.
int dvbres_available(struct dvb_resource* res) {
	int rc;
	rc = _dvbres_fillbuffer(res);
	if (rc)
		return rc;
	return _dvbres_ok_retval(res, res->data_length);
}

// Read bytes with BLOCKING and return number of bytes. If there is data in the
// buffer, we flush it first. In this case no blocking will occur.
int dvbres_read(struct dvb_resource* res, void* target, int max_length) {
	
	// check is device is open
	if (!res->dvr)
		return _dvbres_error(res, "Resource not open", -1);
	
	// in the very special case when we need ZERO bytes...
	if (max_length == 0)
		return _dvbres_ok(res);
	
	// total bytes copied to the client buffer (future return value)
	int bytes_red = 0;
	
	// if buffer is used, flush it first
	while (res->buffer != NULL && res->data_length && max_length) {
		int to_copy = MIN(max_length, MIN(res->data_length, DVBRES_BUFFER_LENGTH - res->data_start));
		memcpy(target, &res->buffer[res->data_start], to_copy);
		
		bytes_red += to_copy;
		res->data_length -= to_copy;
		res->data_start = (res->data_start + to_copy) % DVBRES_BUFFER_LENGTH;
		
		target += to_copy;
		max_length -= to_copy; 
	}
	
	// if no more data needed
	if (max_length == 0)
		return _dvbres_ok_retval(res, bytes_red);
	
	// if no data red so far (no or empty buffer) we block
	if (bytes_red == 0) {
		struct pollfd fds[1];
		fds[0].fd = res->dvr;
		fds[0].events = POLLIN | POLLERR | POLLHUP;
		poll(fds, 1, -1);
	}
	
	// real reading operation
	bytes_red += read(res->dvr, target, max_length);
	
	// success
	return _dvbres_ok_retval(res, bytes_red);
}

int dvbres_close(struct dvb_resource* res) {
	int rc;
	
	// freeing buffer (if any)
	if (res->buffer != NULL) {
		free(res->buffer);
		res->buffer = NULL;
		res->data_length = 0;
		res->data_start = 0;
	}
		
	// if already closed	
	if (!res->dvr && !res->demux && !res->frontend)
		return _dvbres_error(res, "No open device (already closed?)", errno);
	
	// closing
	if (res->dvr) {
		rc = close(res->dvr);
		res->dvr = NULL;
	}
	
	if (res->demux) {
		rc = close(res->demux);
		res->demux = NULL;
	}

	if (res->frontend) {
		rc = close(res->frontend);
		res->frontend = NULL;
	}
		
	// all ok
	return _dvbres_ok(res);
}

int dvbres_release(struct dvb_resource* res) {
	if (res->dvr)
		dvbres_close(res);
	return 0;
}

// get if signal is present
int dvbres_signalpresent(struct dvb_resource* res) {
	int rc;
	int status;
	rc = ioctl(res->frontend, FE_READ_STATUS, &status);
	if (rc)
		return _dvbres_error(res, "Reading status.", errno);
	return (status & FE_HAS_SIGNAL) != 0;
}

// get if signal is locked
int dvbres_signallocked(struct dvb_resource* res) {
	int rc;
	int status;
	rc = ioctl(res->frontend, FE_READ_STATUS, &status);
	if (rc)
		return _dvbres_error(res, "Reading status.", errno);
	return (status & FE_HAS_LOCK) != 0;
}

// get signal level 0: bad, 100: good
int dvbres_getsignalstrength(struct dvb_resource* res) {
	int rc;
	int strength = 0;
	rc = ioctl(res->frontend, FE_READ_SIGNAL_STRENGTH, &strength);
	if (rc)
		return _dvbres_error(res, "Reading signal strength.", errno);
	return strength * 100 / 65535;
}

// get signal quality 0: bad, 100: good
int dvbres_getsignalquality(struct dvb_resource* res) {
	int rc;
	int snr = 0;
	rc = ioctl(res->frontend, FE_READ_SNR, &snr);
	if (rc)
		return _dvbres_error(res, "Reading signal strength.", errno);
	return snr * 100 / 65535;
}
