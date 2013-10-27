
//orginal from http://forums.electricimp.com/discussion/comment/1603

//I2C Addresses
const i2c_ioexp = 0x7C;

//----------------------------------------
//-- Configure I2C
//----------------------------------------
hardware.configure(I2C_89);
local i2c = hardware.i2c89;

//----------------------------------------
//-- IO Expander Functions
//----------------------------------------
local function ioexp_read(addr) {
    local result = i2c.read(i2c_ioexp, format("%c", addr), 1);
    if (result == null) {
        server.log("i2c read fail");
        return -1;
    } else return result[0];
}

local function ioexp_write(addr, data) {
    i2c.write(i2c_ioexp, format("%c%c",addr, data));
}

local function ioexp_writebit(addr, bitn, level) {
    // read modify write
    local reg = ioexp_read(addr);
    reg = (level==0)?(reg&~(1<<bitn)) : (reg | (1<<bitn));
    ioexp_write(addr, reg)
}

local function ioexp_setpin(gpio, level) {
    ioexp_writebit(gpio>=8?0x10:0x11, gpio&7, level?1:0);
}

local function ioexp_setdir(gpio, output) {
    ioexp_writebit(gpio>=8?0x0e:0x0f, gpio&7, output?0:1);
}


// Enable Potentiometer
ioexp_setpin(8, 0);
ioexp_setdir(8, 1);
hardware.pin2.configure(ANALOG_IN);

function doIt()
{
    imp.wakeup(1.0,doIt);
    server.log(hardware.pin2.read());
}

imp.configure("Rotary Tester", [], []);

doIt();