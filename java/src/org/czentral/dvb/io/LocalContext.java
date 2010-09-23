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
 * Context of the local devices
 */
public final class LocalContext implements DeviceContext {
	
	/**
	 * Friendly name returned by <code>getName</code>.
	 */
	private final String NAME = "local";
	
	/**
	 * SingletonInstance.
	 */
	private static LocalContext instance;

	/**
	 * Creates a new instance of this objects.
	 */
	private LocalContext() {
	}
	
	/**
	 * Gets the single <code>LocalContext</code> instance.
	 * 
	 * @return Object representing the local context.
	 */
	public static LocalContext getInstance() {
		if (instance == null)
			instance = new LocalContext();
		return instance;
	}
	
	public String getName() {
		return NAME;
	}

}
