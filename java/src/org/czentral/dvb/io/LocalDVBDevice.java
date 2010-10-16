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


class LocalDVBDevice implements DVBDevice {
	
	/**
	 * User-friendly name of the device.
	 */
	protected String name;
	
	/**
	 * Native path of the device.
	 */
	protected String path;
	
	/**
	 * Device capabilities.
	 */
	protected DeviceCapabilities capabilities;
	
	public LocalDVBDevice(String name, String path, DeviceCapabilities capabilities) {
		this.name = name;
		this.path = path;
		this.capabilities = capabilities;
	}
	
	public String getName() {
		return name;
	}
	
	public String getPath() {
		return path;
	}

	public DeviceCapabilities getCapabilities() {
		return capabilities;
	}
	
	public DeviceContext getContext() {
		return LocalContext.getInstance();
	}
	
	public DVBInputStream openStreamAt(StreamLocator locator) throws IOException {
		NativeDVBIO io = new NativeDVBIO();
		io.open(locator.getFrequency(), path);
		return io;
	}

}
