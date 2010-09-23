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
 * Maintains the list of available DVB devices.
 */
public class DeviceRegistry {
	
	/**
	 * Presence of native support.
	 */
	private static boolean hasNativeSupport;
	
	/**
	 * Singleton instane.
	 */
	private static DeviceRegistry instance;
	
	/**
	 * Presence of native support.
	 */
	private Vector<DeviceRegistry> registries;

	
	/**
	 * Static initialization.
	 */
	static {
		
		// detecting native libraries
		String libName = System.mapLibraryName("NativeDVBIO");
		String path = System.getProperty("java.library.path");
		String separator = System.getProperty("path.separator");
		String fileSep = System.getProperty("file.separator");
		
		hasNativeSupport = false;
		StringTokenizer st = new StringTokenizer(path, separator);
		while (st.hasMoreTokens()) {
			if (new File(st.nextToken() + fileSep + libName).exists()) {
				hasNativeSupport = true;
				break;
			}
		}
	}
	
	/**
	 * Protected constructor.
	 */
	protected DeviceRegistry() {
		registries = new Vector<DeviceRegistry>();
	}
	
	/**
	 * Gets the default device registry.
	 * 
	 * @return The deafult <code>DeviceRegistry</code> object.
	 */
	public static DeviceRegistry getDefaultRegistry() {
		if (instance == null)
			instance = new LocalDeviceRegistry();
		return instance;
	}
	
	/**
	 * Returns a list of dvb devices known by this device registry.
	 *
	 * @return An array containing all the known devices.
	 */
	public DVBDevice[] getDevices() {
		
		Vector<DVBDevice>v = new Vector<DVBDevice>(10);
		
		// iterate thru the registries and merge the devices they know about
		for (int i=0; i<registries.size(); i++) {
			DVBDevice[] devs = registries.get(i).getDevices();
			for (int j=0; j<devs.length; j++) {
				v.add(devs[j]);
			}
		}
		
		// return results as an array
		return v.toArray(new DVBDevice[0]);
	}
	
	/**
	 * Gets if native libraries are correctly installed on the local machine.
	 *
	 * @return <code>True</code> if the native library is operational.
	 */
	public static boolean hasNativeSupport() {
		return hasNativeSupport;
	}

	/**
	 * Finds the first applicable device, tunes it to the transponder specified
	 * by the <code>locator</code> parameter and returns a DVBInputStream to
	 * access data.
	 *
	 * @return Input stream containing raw MPEG2 Transport stream.
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
