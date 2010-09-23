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

#include <stdlib.h>

#include <jni.h>
#include "dvb_resource.h"
#include "dvb_resource_collection.h"

#include "org_czentral_dvb_io_NativeDVBIO.h"

void throw_exception(JNIEnv* env, char* errormsg) {
	jstring msg = (*env)->NewStringUTF(env, errormsg);
	
	jclass cls = (*env)->FindClass(env, "java/io/IOException");
	if (cls != NULL) {
		jmethodID method = (*env)->GetMethodID(env, cls, "<init>", "(Ljava/lang/String;)V");
		if (method != NULL) {
			jobject exception = (*env)->NewObject(env, cls, method, msg);
			(*env)->Throw(env, exception);
		}
	}
}

void throw_dvbres_exception(JNIEnv* env, struct dvb_resource* res) {
	
	// let's hope this is enough (dvb_resource.error_msg is 250)
	char errormsg[300];
	sprintf(errormsg, "Error: %s (error code: %d)", res->error_msg, res->error_code);
	
	throw_exception(env, errormsg);
}

/*
 * Class:     NativeDVBIO
 * Method:    open
 * Signature: (JLjava/lang/String;)V
 */
JNIEXPORT void JNICALL Java_org_czentral_dvb_io_NativeDVBIO_open(JNIEnv* env, jobject obj, jlong freq, jstring jdevice) {
	int index = rescoll_create();
	struct dvb_resource* res = rescoll_get(index);
	
	int resourceid = index + 1;
	jclass cls = (*env)->GetObjectClass(env, obj);
	jfieldID fid = (*env)->GetFieldID(env, cls, "resourceID", "I");
	(*env)->SetIntField(env, obj, fid, resourceid);
	
	char* device = NULL;
	if (jdevice != NULL)
		device = (char*)((*env)->GetStringUTFChars(env, jdevice, NULL));
	
	int rc;
	rc = dvbres_open(res, freq, device);
	if (rc)
		throw_dvbres_exception(env, res);
	
	if (device != NULL)
		(*env)->ReleaseStringUTFChars(env, jdevice, device);
}

/*
 * Class:     NativeDVBIO
 * Method:    available
 * Signature: ()I
 */
JNIEXPORT jint JNICALL Java_org_czentral_dvb_io_NativeDVBIO_available(JNIEnv* env, jobject obj) {
	jclass cls = (*env)->GetObjectClass(env, obj);
	jfieldID fid = (*env)->GetFieldID(env, cls, "resourceID", "I");
	int resourceid = (*env)->GetIntField(env, obj, fid);

	int index = resourceid - 1;
	struct dvb_resource* res = rescoll_get(index);
	if (res == NULL)
		throw_exception(env, "Invalid resource ID");
		
	int rc = dvbres_available(res);
	if (rc == -1 && res->error_code)
		throw_dvbres_exception(env, res);
	
	return rc;
}

/*
 * Class:     NativeDVBIO
 * Method:    isSignalPresent
 * Signature: ()Z
 */
JNIEXPORT jboolean JNICALL Java_org_czentral_dvb_io_NativeDVBIO_isSignalPresent(JNIEnv* env, jobject obj) {
	jclass cls = (*env)->GetObjectClass(env, obj);
	jfieldID fid = (*env)->GetFieldID(env, cls, "resourceID", "I");
	int resourceid = (*env)->GetIntField(env, obj, fid);

	int index = resourceid - 1;
	struct dvb_resource* res = rescoll_get(index);
	if (res == NULL)
		throw_exception(env, "Invalid resource ID");

	int rc = dvbres_signalpresent(res);
	if (rc && res->error_code)
		throw_dvbres_exception(env, res);
	
	return rc != 0;
}

/*
 * Class:     NativeDVBIO
 * Method:    isSignalLocked
 * Signature: ()Z
 */
JNIEXPORT jboolean JNICALL Java_org_czentral_dvb_io_NativeDVBIO_isSignalLocked(JNIEnv* env, jobject obj) {
	jclass cls = (*env)->GetObjectClass(env, obj);
	jfieldID fid = (*env)->GetFieldID(env, cls, "resourceID", "I");
	int resourceid = (*env)->GetIntField(env, obj, fid);

	int index = resourceid - 1;
	struct dvb_resource* res = rescoll_get(index);
	if (res == NULL)
		throw_exception(env, "Invalid resource ID");

	int rc = dvbres_signallocked(res);
	if (rc && res->error_code)
		throw_dvbres_exception(env, res);
	
	return rc != 0;
}

/*
 * Class:     NativeDVBIO
 * Method:    getSignalStrength
 * Signature: ()I
 */
JNIEXPORT jint JNICALL Java_org_czentral_dvb_io_NativeDVBIO_getSignalStrength(JNIEnv* env, jobject obj) {
	jclass cls = (*env)->GetObjectClass(env, obj);
	jfieldID fid = (*env)->GetFieldID(env, cls, "resourceID", "I");
	int resourceid = (*env)->GetIntField(env, obj, fid);

	int index = resourceid - 1;
	struct dvb_resource* res = rescoll_get(index);
	if (res == NULL)
		throw_exception(env, "Invalid resource ID");
		
	int rc = dvbres_getsignalstrength(res);
	if (rc == -1 && res->error_code)
		throw_dvbres_exception(env, res);
	
	return rc;
}

/*
 * Class:     NativeDVBIO
 * Method:    getSignalQuality
 * Signature: ()I
 */
JNIEXPORT jint JNICALL Java_org_czentral_dvb_io_NativeDVBIO_getSignalQuality(JNIEnv* env, jobject obj) {
	jclass cls = (*env)->GetObjectClass(env, obj);
	jfieldID fid = (*env)->GetFieldID(env, cls, "resourceID", "I");
	int resourceid = (*env)->GetIntField(env, obj, fid);

	int index = resourceid - 1;
	struct dvb_resource* res = rescoll_get(index);
	if (res == NULL)
		throw_exception(env, "Invalid resource ID");
		
	int rc = dvbres_getsignalquality(res);
	if (rc == -1 && res->error_code)
		throw_dvbres_exception(env, res);
		
	printf("qual: %d\n", rc);
	
	return rc;
}

/*
 * Class:     NativeDVBIO
 * Method:    close
 * Signature: ()V
 */
JNIEXPORT void JNICALL Java_org_czentral_dvb_io_NativeDVBIO_close(JNIEnv* env, jobject obj) {
	jclass cls = (*env)->GetObjectClass(env, obj);
	jfieldID fid = (*env)->GetFieldID(env, cls, "resourceID", "I");
	int resourceid = (*env)->GetIntField(env, obj, fid);

	int index = resourceid - 1;
	struct dvb_resource* res = rescoll_get(index);
	if (res == NULL)
		throw_exception(env, "Invalid resource ID");
	
	if (res->dvr != 0)
		dvbres_close(res);
		
	res = NULL;
	int rc = rescoll_delete(index);
	if (rc)
		throw_exception(env, "Closing removing resource from global collection.");
}

/*
 * Class:     NativeDVBIO
 * Method:    read
 * Signature: ([BII)I
 */
JNIEXPORT jint JNICALL Java_org_czentral_dvb_io_NativeDVBIO_read(JNIEnv* env, jobject obj, jbyteArray jBuffer, jint offset, jint length) {
	jclass cls = (*env)->GetObjectClass(env, obj);
	jfieldID fid = (*env)->GetFieldID(env, cls, "resourceID", "I");
	int resourceid = (*env)->GetIntField(env, obj, fid);
	
	int index = resourceid - 1;
	struct dvb_resource* res = rescoll_get(index);
	if (res == NULL)
		throw_exception(env, "Invalid resource ID");
	
	char* buffer = (char*)(*env)->GetByteArrayElements(env, jBuffer, NULL);	

	int bytesred = dvbres_read(res, &buffer[offset], length);
	
	(*env)->ReleaseByteArrayElements(env, jBuffer, (jbyte*)buffer, 0);
	
	return bytesred;
}

/*
 * Class:     NativeDVBIO
 * Method:    listDevices
 * Signature: ([B)I
 */
JNIEXPORT jstring JNICALL Java_org_czentral_dvb_io_NativeDVBIO_listDevices(JNIEnv* env, jclass cls) {
	int rc;
	
	// ToDo: a non-capping buffer solution	
	int bufflen = 32000;
	void* buffer = malloc(bufflen);
	
	struct dvb_resource res;
	rc = dvbres_listdevices(&res, buffer, bufflen);
	if (rc == -1)
		throw_dvbres_exception(env, &res);
	
	return (*env)->NewStringUTF(env, buffer);
}
