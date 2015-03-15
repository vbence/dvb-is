# DVB Input Stream for Java

Enables Java applications to access local digital tuners. With a straightforward interface for tuning, getting signal level, and accessing transport stream data in the well known *InputStream* fashion.

The project conatins native implementations for BDA (Windows) and V4L2 (Linux) systems. Only DVB-T chains are built at the moment.

The following snippet will help you decide if *DVB Input Stream* is what you're looking for:

```
    DVBTStreamLocator locator = new DVBTStreamLocator();
    locator.setFrequency(610000000);
    InputStream is = locator.getInputStream();
```

## Known issues
 * BDA drivers are not consistent when returning signal strength levels. (This is due to an ambiguity in the specification.) The native implementation on Windows currently just passes the values returned by the driver. Consult BDA documentation for possible values. - Future plans include a heuristic algorithm for the interpretation of these values.

## Further plans
 * A transparent layer to access shared remote tuners. This is only way to support Mac OS X at the moment. (As it lacks an abstraction layer for digital tuners, like BDA or V4L).
 * BDA: support for MS's very new, under-documented universal Network Provider.
