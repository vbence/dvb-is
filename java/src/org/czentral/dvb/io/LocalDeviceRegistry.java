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

import java.io.IOException;
import java.io.File;
import java.util.Vector;
import java.util.StringTokenizer;

/**
 * Maintains the list of local DVB devices (thru the native implementation).
 */
class LocalDeviceRegistry extends DeviceRegistry {
	
	/**
	 * Returns a list of dvb devices known by this device registry.
	 *
	 * @return An array containing all the known devices.
	 */
	public DVBDevice[] getDevices() {
		Vector<DVBDevice>v = new Vector<DVBDevice>(10);
		
		if (hasNativeSupport()) {
			try {
				String devideList = NativeDVBIO.listDevices();
				
				char typeChar;
				String name;
				String path;
				long capabilities;
				
				StringTokenizer st = new StringTokenizer(devideList, "\t");
				while (st.hasMoreTokens()) {
					name = st.nextToken();
					path = st.nextToken();
					typeChar = st.nextToken().charAt(0);
					
					if (typeChar == '0') {
						capabilities = DeviceCapabilities.CAPABLE_DVBS;
					} else if (typeChar == '1') {
						capabilities = DeviceCapabilities.CAPABLE_DVBC;
					} else if (typeChar == '2') {
						capabilities = DeviceCapabilities.CAPABLE_DVBT;
					} else {
						capabilities = DeviceCapabilities.CAPABLE_NONE;
					}
					
					v.add(new LocalDVBDevice(name, path, new GeneralDeviceCapabilities(capabilities)));
					
				}
			} catch (IOException e) {
			}
		}

		return v.toArray(new DVBDevice[0]);
	}
	
	/**
	 * Finds the first applicable device, tunes it to the transponder specified
	 * by the <code>locator</code> parameter and returns a DVBInputStream to
	 * access data.
	 *
	 * @return Input stream containing raw MPEG2 Transport stream.
	 * @throws IOException If no suitable devices found or devices are busy.
	 */
	public DVBInputStream openStreamAt(StreamLocator locator) throws IOException {
		if (hasNativeSupport()) {
			NativeDVBIO io = new NativeDVBIO();
			io.open(locator.getFrequency(), null);
			return io;
		}
		
		throw new IOException("No suitable devices.");
	}
}
