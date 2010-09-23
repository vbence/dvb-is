/*
This file is part of DVB Input Stream API by Varga Bence.

DVB Input Stream API is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

DVB Input Stream API is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with DVB Input Stream API.  If not, see <http://www.gnu.org/licenses/>.
*/ 

package org.czentral.dvb.io;

import java.io.*;

class NativeDVBIO extends DVBInputStream {
	
	static {
		System.loadLibrary("NativeDVBIO");
	}
	
	private int resourceID = 0;

	public native void open(long freq, String adapter) throws IOException;

	public native int available() throws IOException;

	public native boolean isSignalPresent() throws IOException;

	public native boolean isSignalLocked() throws IOException;

	public native int getSignalStrength() throws IOException;

	public native int getSignalQuality() throws IOException;

	public native void close() throws IOException;
	
	public int read() throws IOException {
		byte[] buffer = new byte[1];
		read(buffer, 0, 1);
		return buffer[0] & 0xff;
	}
	
	public int read(byte[] buffer) throws IOException {
		return read(buffer, 0, buffer.length);
	}
	
	public native int read(byte[] buffer, int offset, int length) throws IOException;
	
	public static native String listDevices() throws IOException;
	
	public String toString() {
		return "NativeDVBIO(resourceID: " + resourceID + ")";
	}
	
	public void finalize() {
		try {
			close();
		} catch (IOException e) {
			e.printStackTrace();
		}
	}
}