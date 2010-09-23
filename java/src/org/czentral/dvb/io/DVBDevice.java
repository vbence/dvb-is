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

/**
 * Holds the description of a DVB capable device.
 */
public interface DVBDevice {
	
	/**
	 * Gets the user-friendly name of the device.
	 *
	 * @return The name of the device that can be presented to the user.
	 */
	public String getName();
	
	/**
	 * Gets the native <code>Device Path</code>.
	 *
	 * @return The name of the device that can be presented to the user.
	 */
	public String getPath();

	/**
	 * Gets the capabilities of this device. The detected values are
	 * unrealiable, they are presented with an informative fashion.
	 *
	 * @return Object containing the capabilities of this device.
	 */
	public DeviceCapabilities getCapabilities();
	
	/**
	 * Gets the context of this DVB device.
	 *
	 * @return The context of this device.
	 */
	public DeviceContext getContext();
	
	/**
	 * Tunes this device to the stream represented by locator and opens input
	 * stream.
	 *
	 * @return The input stream.
	 */
	public DVBInputStream openStreamAt(StreamLocator locator) throws IOException;

}
