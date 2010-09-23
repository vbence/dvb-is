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

/**
 * Identifies the capabilities of a digital tuner device.
 */
public abstract class DeviceCapabilities {
	
	/**
	 * No capabilities detected.
	 */
	public static int CAPABLE_NONE = 0;
	
	/**
	 * DVB-S system used by satellite recievers.
	 */
	public static int CAPABLE_DVBS = 2 ^ 0;
	
	/**
	 * DVB-C system used by cable receivers.
	 */
	public static int CAPABLE_DVBC = 2 ^ 1;
	
	/**
	 * DVB-T system used by terrestrial recievers.
	 */
	public static int CAPABLE_DVBT = 2 ^ 2;
	
	
	/**
	 * Capability contants packed with binary OR operation.
	 */
	protected long capabilities;
	
	
	/**
	 * Checks if the device is capable of receiving DVB-S trasponders.
	 *
	 * @return <code>True</code> if the device has the capabilility.
	 */
	public boolean isDVBSCapable() {
		return (capabilities & CAPABLE_DVBS) != 0;
	}

	/**
	 * Checks if the device is capable of receiving DVB-C trasponders.
	 *
	 * @return <code>True</code> if the device has the capabilility.
	 */
	public boolean isDVBCCapable() {
		return (capabilities & CAPABLE_DVBC) != 0;
	}

	/**
	 * Checks if the device is capable of receiving DVB-T trasponders.
	 *
	 * @return <code>True</code> if the device has the capabilility.
	 */
	public boolean isDVBTCapable() {
		return (capabilities & CAPABLE_DVBT) != 0;
	}

}
