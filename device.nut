/***************************************\
*       FUTURESTACK 13 BADGE DEMO       *
*          (c) 2013 New Relic           *
*                                       *
* For more information, see:            *
* github.com/newrelic/futurestack_badge *
\***************************************/

const PN532_PREAMBLE            = 0x00;
const PN532_STARTCODE2          = 0xFF;
const PN532_POSTAMBLE           = 0x00;

const PN532_HOSTTOPN532         = 0xD4;

const PN532_FIRMWAREVERSION     = 0x02;
const PN532_SAMCONFIGURATION    = 0x14;
const PN532_RFCONFIGURATION     = 0x32;

const PN532_SPI_STATREAD        = 0x02;
const PN532_SPI_DATAWRITE       = 0x01;
const PN532_SPI_DATAREAD        = 0x03;
const PN532_SPI_READY           = 0x01;

const PN532_MAX_RETRIES         = 0x05;

const RUNLOOP_INTERVAL          = 2;

local pn532_ack = [0x00, 0x00, 0xFF, 0x00, 0xFF, 0x00];
local pn532_firmware_version = [0x00, 0xFF, 0x06, 0xFA, 0xD5, 0x03];

local response_buffer = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19];
local nfc_booted = true;


///////////////////////////////////////
// NFC SPI Functions
function spi_init() {
    // Configure SPI_257 at about 4MHz
    hardware.configure(SPI_257);
    hardware.spi257.configure(LSB_FIRST | CLOCK_IDLE_HIGH, 500);

    hardware.pin1.configure(DIGITAL_OUT); // Configure the chip select pin
    hardware.pin1.write(1);               // pull CS high
    imp.sleep(0.1);                       // wait 100 ms
    hardware.pin1.write(0);               // pull CS low to start the transmission of data
    imp.sleep(0.1);
    log("SPI Init successful");
}

function spi_read_ack() {
    spi_read_data(6);
    for (local i = 0; i < 6; i++) {
        if (response_buffer[i] != pn532_ack[i])
            return false;
    }

    return true;
}

function spi_read_data(length) {
    hardware.pin1.write(0); // pull CS low
    imp.sleep(0.002);
    spi_write(PN532_SPI_DATAREAD); // read leading byte DR and discard

    local response = "";
    for (local i = 0; i < length; i++) {
        imp.sleep(0.001);
        response_buffer[i] = spi_write(PN532_SPI_STATREAD);
        response = response + response_buffer[i] + " ";
    }

    //log("spi_read_data: " + response);
    hardware.pin1.write(1); // pull CS high
}

function spi_read_status() {
    hardware.pin1.write(0); // pull CS low
    imp.sleep(0.002);

    // Send status command to PN532; ignore returned byte
    spi_write(PN532_SPI_STATREAD);

    // Collect status response, send junk 0x00 byte
    local value = spi_write(0x00);
    hardware.pin1.write(1); // pull CS high

    return value;
}

function spi_write_command(cmd, cmdlen) {
    local checksum;
    hardware.pin1.write(0); // pull CS low
    imp.sleep(0.002);
    cmdlen++;

    spi_write(PN532_SPI_DATAWRITE);

    checksum = PN532_PREAMBLE + PN532_PREAMBLE + PN532_STARTCODE2;
    spi_write(PN532_PREAMBLE);
    spi_write(PN532_PREAMBLE);
    spi_write(PN532_STARTCODE2);

    spi_write(cmdlen);
    local cmdlen_1=256-cmdlen;
    spi_write(cmdlen_1);

    spi_write(PN532_HOSTTOPN532);
    checksum += PN532_HOSTTOPN532;

    for (local i = 0; i < cmdlen - 1; i++) {
        spi_write(cmd[i]);
        checksum += cmd[i];
    }

    checksum %= 256;
    local checksum_1 = 255 - checksum;
    spi_write(checksum_1);
    spi_write(PN532_POSTAMBLE);

    hardware.pin1.write(1); // pull CS high
}

function spi_write(byte) {
    // Write the single byte
    hardware.spi257.write(format("%c", byte));

    // Collect the response from the holding register
    local resp = hardware.spi257.read(1);

    // Show what we sent
    //log(format("SPI tx %02x, rx %02x", byte, resp[0]));

    // Return the byte
    return resp[0];
}

////////////////////////////////////
// PN532 functions
function nfc_init() {
    hardware.pin1.write(0); // pull CS low
    imp.sleep(1);

    /* No need for this at the moment but it's useful for debugging.
    if (!nfc_get_firmware_version()) {
        error("Didn't find PN53x board");
        nfc_booted = false;
    }
    */

    if (!nfc_SAM_config()) {
        error("SAM config error");
      nfc_booted = false;
    }
}

function nfc_get_firmware_version() {
    log("Getting firmware version");

    if (!send_command_check_ready([PN532_FIRMWAREVERSION], 1,100))
        return 0;
    spi_read_data(12);

    for (local i = 0; i < 6; i++) {
        if (response_buffer[i] != pn532_firmware_version[i])
            return false;
    }

    log(format("Found chip PN5%02x", response_buffer[6]));
    log("Firmware ver "+ response_buffer[7] + "." + response_buffer[8]);
    log(format("Supports %02x", response_buffer[9]));

    return true;
}

function nfc_SAM_config() {
    log("SAM configuration");
    if (!send_command_check_ready([PN532_SAMCONFIGURATION, 0x01, 0x14, 0x01], 4, 100))
        return false;

    spi_read_data(8);
    if (response_buffer[5] == 0x15) return true;
    else return false;
}

function nfc_scan() {
    //log("nfc_p2p_scan");
    send_command_check_ready([PN532_RFCONFIGURATION, PN532_MAX_RETRIES, 0xFF, 0x01, 0x14], 5, 100);
    if (!send_command_check_ready([
        0x4A,                // InListPassivTargets
        0x01,                // Number of cards to init (if in field)
        0x00,                // Baud rate (106kbit/s)
        ], 3, 100)) {
        error("Unknown error detected during nfc_p2p_scan");
        return false;
    }

    spi_read_data(18);

    if (response_buffer[7] > 0) {
        local tag = format("%02x%02x%02x", response_buffer[14], response_buffer[15], response_buffer[16]);
        tag_detected(tag);

        return true;
    }

    return false;
}

function nfc_power_down() {
    log("nfc_power_down");
    if (!send_command_check_ready([
        0x16,                // PowerDown
        0x20,                // Only wake on SPI
        ], 2, 100)) {
        error("Unknown error detected during nfc_power_down");
        return false;
    }

    spi_read_data(9);
}

// This command configures the NFC chip to act as a target, much like a standard
// dumb prox card.  The ID sent depends on the baud rate.  We're using 106kbit/s
// so the NFCID1 will be sent (3 bytes).
function nfc_p2p_target() {
    //log("nfc_p2p_target");
    if (!send_command([
        0x8C,                                   // TgInitAsTarget
        0x00,                                   // Accepted modes, 0 = all
        0x08, 0x00,                             // SENS_RES
        device_id_a, device_id_b, device_id_c,  // NFCID1
        0x40,                                   // SEL_RES
        0x01, 0xFE, 0xA2, 0xA3,                 // Parameters to build POL_RES (16 bytes)
        0xA4, 0xA5, 0xA6, 0xA7,
        0xC0, 0xC1, 0xC2, 0xC3,
        0xC4, 0xC5, 0xC6, 0xC7,
        0xFF, 0xFF,
        0xAA, 0x99, 0x88, 0x77,                 // NFCID3t
        0x66, 0x55, 0x44, 0x33,
        0x22, 0x11,
        0x00,                                   // General bytes
        0x00                                    // historical bytes
        ], 38, 100)) {
        error("Unknown error detected during nfc_p2p_target");
        return false;
    }
}

function send_command_check_ready(cmd, cmdlen, timeout) {
    return send_command(cmd, cmdlen, timeout) && check_ready(timeout);
}

function send_command(cmd, cmdlen, timeout) {
    local timer = 0;

    spi_write_command(cmd, cmdlen);

    // Wait for chip to say its ready!
    while (spi_read_status() != PN532_SPI_READY) {
        if (timeout != 0) {
            timer += 10;
            if (timer > timeout) {
                error("No response READY");
                return false;
            }
        }
        imp.sleep(0.01);
    }

    // read acknowledgement
    if (!spi_read_ack()) {
        error("Wrong ACK");
        return false;
    }

    //log("read ack");

    return true;
}

function check_ready(timeout) {
    local timer = 0;
    // Wait for chip to say its ready!
    while (spi_read_status() != PN532_SPI_READY) {
        if (timeout != 0) {
            timer += 10;
            if (timer > timeout) {
                error("No response READY");
                return false;
            }
        }
        imp.sleep(0.01);
    }

    return true;
}

//////////////////////////////////
// General Functions
function hex_to_i(hex) {
    local result = 0;
    local shift = hex.len() * 4;

    // For each digit..
    for(local d = 0; d < hex.len(); d++) {
        local digit;

        // Convert from ASCII Hex to integer
        if(hex[d] >= 0x61)
            digit = hex[d] - 0x57;
        else if(hex[d] >= 0x41)
             digit = hex[d] - 0x37;
        else
             digit = hex[d] - 0x30;

        // Accumulate digit
        shift -= 4;
        result += digit << shift;
    }

    return result;
}

function tag_detected(tag_id) {
    flash_leds_for_tag();
    log("Found tag ID: " + tag_id);
}

function flash_leds_for_tag() {
    hardware.pin8.write(0.5);
    hardware.pin9.write(0.5);
    imp.sleep(0.7);
    hardware.pin8.write(0);
    hardware.pin9.write(0);
}

function flash_error() {
    hardware.pin8.write(0.01);
}

function log(string) {
    server.log(string);
}

function error(string) {
    flash_error();
    log(string);
}

function run_loop() {
    if (nfc_booted) {
        // Run this loop again, soon
        imp.wakeup(RUNLOOP_INTERVAL, run_loop);

        // Scan for nearby NFC devices
        nfc_scan();

        // Enter target mode.  This allows other readers to read our id.
        nfc_p2p_target();
    } else {
        error("PN532 could not be initialized, halting.");
    }
}

// Configure LEDs
hardware.pin8.configure(PWM_OUT, 0.05, 0);
hardware.pin9.configure(PWM_OUT, 0.05, 0);

// Start up SPI
spi_init();

// Looks like this was a cold boot.
imp.configure("FutureStack 13 Badge Demo", [], []);
imp.setpowersave(true);

// Parse out our hardware id from the impee id chip
device_id <- hardware.getimpeeid().slice(0, 6);
device_id_a <- hex_to_i(device_id.slice(0,2));
device_id_b <- hex_to_i(device_id.slice(2,4));
device_id_c <- hex_to_i(device_id.slice(4,6));

log("Booting, my ID is " + device_id);

// Start up the NXP chip and enter the main runloop
nfc_init();
run_loop();
