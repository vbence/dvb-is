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

#include "dvb_resource.h"
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define RESCOLL_MAX 100

int rescoll_num = 0;
void* rescoll_data[RESCOLL_MAX];

int rescoll_create() {
	if (rescoll_num >= RESCOLL_MAX)
		return -1;
	
	rescoll_data[rescoll_num] = malloc(sizeof(struct dvb_resource));
	dvbres_init(rescoll_data[rescoll_num]);
	
	return rescoll_num++;
}

struct dvb_resource* rescoll_get(int index) {
	if (index < 0 || index >= rescoll_num)
		return NULL;
	
	return rescoll_data[index];
}

int rescoll_delete(int index) {
	if (index < 0 || index >= rescoll_num)
		return -1;

	struct dvb_resource* res = rescoll_data[index];
	
	memmove(&rescoll_data[index], &rescoll_data[index + 1], (rescoll_num - index - 1) * sizeof(void*));
	rescoll_num--;
	
	dvbres_release(res);
	free(res);
	
	return 0;
}
