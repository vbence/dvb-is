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

import org.czentral.dvb.io.*;
import java.io.*;

public class NativeTest {
	
	public static void main(String[] args) {
		
		// check for required parameters (otherwise print out usage information)
		if (args.length < 1) {
			System.out.println("Tries to tune to the given frequency and receiv a TS packet.\n usage: NativeTest <frequency-in-hertz>");
			System.exit(1);
		}
		
		// frequency to tune to
		long frequency = Long.parseLong(args[0]);
			
		// getting the registry
		DeviceRegistry reg = DeviceRegistry.getDefaultRegistry();
		
		// checking native library
		System.out.println("Has native support: " + reg.hasNativeSupport());
		
		// listing devices
		DVBDevice[] devices = reg.getDevices();
		System.out.println("Numer of devices: " + devices.length);
		for (int i=0; i<devices.length; i++) {
			System.out.println(devices[i].getName() + " - " + devices[i].getPath());
		}
		
		// a friendly message
		System.out.println("-- Tuning and reading a single packet two times");
		
		// reading a TS packet
		try {
			
			// TS  packet is alway exactly 188 bytes
			byte[] buffer = new byte[188];
			
			// we test it two times (to test closing and repoening)
			for (int k=0; k<2; k++) {
				
				// tune
				DVBTStreamLocator locator = new DVBTStreamLocator();
				locator.setFrequency(frequency);
				
				// open the stream
				DVBInputStream is = locator.getInputStream();
				
				// not an ideal solution, but so far no timeout implemented and we don't want to wait forever
				System.out.print("\r\nWaiting 2 seconds for data ... ");
				Thread.sleep(2000);
				System.out.println("done");		
				
				// is data available?
				if (is.available() > 0) {
					
					// there is data available
					int bytesRed = is.read(buffer);
					for (int i=0; i<Math.min(16, bytesRed); i++)
						System.out.print(Integer.toHexString(buffer[i] & 0xff) + " ");
				
					System.out.println("...");
					
				} else {
					
					// no data
					System.out.println("no data!");
					
				}
				
				// closing the InputStream
				is.close();
			}
			
		} catch (Exception e) {
			// something went terribly wrong
			e.printStackTrace();
		}
		
		/*
		// this little snippet tests if buffer overruns are handled as expected
		// (188 byte packets are not broken) - you should see only 47's
		try {
			byte[] buffer = new byte[188];
			
			DVBTStreamLocator locator = new DVBTStreamLocator();
			locator.setFrequency(610000000);
			DVBInputStream is = locator.getInputStream();
			
			while (true) {
				for (int i=0; i<buffer.length; i++)
					buffer[i] = (byte)(is.read() & 0xff);
			
				System.out.println(Integer.toHexString(buffer[0] & 0xff));
			}
		} catch (IOException e) {
			e.printStackTrace();
		}
		*/

	}
}
