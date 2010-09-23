/*
This file is part of libNativeDVBIO by Varga Bence.

libNativeDVBIO is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

libNativeDVBIO is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with libNativeDVBIO.  If not, see <http://www.gnu.org/licenses/>.
*/

#ifndef _DVB_RESOURCE_COLLECTION_H_
#define _DVB_RESOURCE_COLLECTION_H_


#define RESCOLL_MAX 100

int rescoll_create();

struct dvb_resource* rescoll_get(int index);

int rescoll_delete(int index);

#endif /* _DVB_RESOURCE_COLLECTION_H_ */
