[![Archived header](https://github.com/newrelic/open-source-office/raw/master/examples/categories/images/Archived.png)](https://github.com/newrelic/open-source-office/blob/master/examples/categories/index.md#archived)

## FutureStack 13 Badge Firmware

This firmware will turn your FutureStack badge into a simple NFC tag reader.  To get started, register an account with http://electricimp.com, BlinkUp your badge using the Electric Imp [Android](https://play.google.com/store/apps/details?id=com.electricimp.electricimp) or [iOS](https://itunes.apple.com/lb/app/electric-imp/id547133856?mt=8) mobile app, and create a new model using the IDE containing the code in device.nut (no need for agent code).  Hit "Build and Run" and your badge should be ready to go.

## Other resources
### Electric Imp
To explore more about Electric Imp, check out their dev center [here](https://electricimp.com/docs).  If you want to use your Imp in your own hardware project, check out [this page](https://electricimp.com/docs/gettingstarted/devkits) to find a breakout board.

### NXP NFC controller
The NFC chip on the badges is an NXP PN532.  You can find the datasheet [here]( http://www.adafruit.com/datasheets/pn532longds.pdf).  The user manual (a bit higher level) is [here]( http://www.adafruit.com/datasheets/pn532um.pdf) and an application note is [here]( http://www.adafruit.com/datasheets/PN532C106_Application%20Note_v1.2.pdf).  With these datasheets, you'll be able to tailor the NFC chip's behavior to your heart's content.

### Power
Any CR123 3v battery should be suffient as a replacement for the one provided.


## License
Portions of this code used with permission from [Javier Montaner](https://github.com/jmgjmg/eImpNFC).

Copyright (c) 2013 New Relic, Inc. See the LICENSE file for license rights and limitations (MIT).

