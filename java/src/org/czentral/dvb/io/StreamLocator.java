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
 * A locator holds the parameters the tuner needs to tune to a certain
 * transponder.
 */
public abstract class StreamLocator {
	
	/**
	 * Transponder frequency in Hertz.
	 */
	protected long frequency;
	
	/**
	 * Sets the frequency of the transponder containing the digital stream.
	 *
	 * @param frequencyHz Transponder frequency in Hertz.
	 */
	public void setFrequency(long frequencyHz) {
		this.frequency = frequencyHz;
	}

	/**
	 * Sets the frequency of the transponder containing the digital stream.
	 *
	 * @return Transponder frequency in Hertz.
	 */
	public long getFrequency() {
		return frequency;
	}
	
	/**
	 * Tunes the first available device to the trasnsponder and starts
	 * receiveing the stream.
	 * 
	 * Calling this metod is identical to <code>DeviceRegistry.
	 * openStreamAt(StreamLocator)</code>
	 *
	 * @return The input stream.
	 */
	public DVBInputStream getInputStream() throws IOException {
		return DeviceRegistry.getDefaultRegistry().openStreamAt(this);
	}
}
