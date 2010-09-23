#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ(2.61)
AC_INIT([libNativeDVBIO], [0.0.0], [], [], [http://czentral.org/dvb/io])
AM_INIT_AUTOMAKE
AC_CONFIG_SRCDIR([src/dvb_resource.h])
AC_CONFIG_HEADER([config.h])
AC_PROG_LIBTOOL
#LT_PREREQ(2.2)
LT_INIT

# Checks for programs.
AC_PROG_CC

# Checks for libraries.

# Checks for header files.
AC_HEADER_STDC
AC_CHECK_HEADERS([fcntl.h stdint.h stdlib.h string.h sys/ioctl.h unistd.h])
AC_CHECK_HEADERS([jni.h], [true], [have_jni=no])

# Checks for typedefs, structures, and compiler characteristics.
AC_TYPE_UINT64_T

# Checks for library functions.
AC_PROG_GCC_TRADITIONAL
AC_FUNC_MALLOC
AC_CHECK_FUNCS([memmove memset])

AC_CONFIG_FILES([Makefile
                 src/Makefile])
AC_OUTPUT

if test "x${have_jni}" = xno; then
    echo "-------------------------------------------"
    echo " Unable to find jni.h on standard paths.   "
    echo " If you have it on a nonstandard path      "
    echo " please include that directory in CFLAGS.  "
    echo " example:                                  "
    echo " $ export CFLAGS=\"-I/path/to/jni/ \$CFLAGS\""
    echo "-------------------------------------------"
    AC_MSG_FAILURE([Required header file is missing.])
fi
