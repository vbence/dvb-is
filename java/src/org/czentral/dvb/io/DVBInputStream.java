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

import java.io.InputStream;
import java.io.IOException;

/**
 * Provides the means to access an MPEG 2
 * Transport Stream broadcasted on a RF (DVB-X, ATSC etc.) network.
 *
 * There are extra functions present to determine certain reception attributes.
 * These are optional opertations which CAN BE supported by the implementation.
 * You are encouraged to present this information to the user but STRONGLY
 * DISCOURAGED to make any decicisions based on these values.
 */
public abstract class DVBInputStream extends InputStream {
	
	/**
	 * Optional returns if there is a signal present above noise level.
	 * 
	 * @return <code>True</code> if signal is present.
	 * @throws IOException If the operation can not be executed. (Any error in the native code.)
	 */
	public abstract boolean isSignalPresent() throws IOException;
	
	/**
	 * Optional, returns if the signal is locked.
	 * <b>Request for comment: </b> when exactly is a signal <i>locked</i>?
	 *
	 * @return <code>True</code> if signal is locked.
	 * @throws IOException If the operation can not be executed. (Any error in the native code.)
	 */
	public abstract boolean isSignalLocked() throws IOException;
	
	/**
	 * Optional, gets the signal strength.
	 *
	 * @return Signal strength. 0: bad, 100: good. Or -1 if not supported.
	 * @throws IOException If the operation can not be executed. (Any error in the native code.)
	 */
	public abstract int getSignalStrength() throws IOException;
	
	/**
	 * Optional, gets signal quality.
	 *
	 * @return Signal quality. 0: bad, 100: good.  Or -1 if not supported.
	 * @throws IOException If the operation can not be executed. (Any error in the native code.)
	 */
	public abstract int getSignalQuality() throws IOException;
	
}
