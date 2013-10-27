
// working sample from http://forums.electricimp.com/discussion/329/setting-up-a-button-on-hannah/p1

// IO Expander Class for SX1509
class IOExpander
{
    
    I2CPort = null;
    I2CAddress = null;
    IRQ_Callbacks = array(16);
    
    constructor (port, address) {
        
        // Configure port and save address
        if (port == I2C_12) {
            
            // Configure I2C bus on pins 1,2
            hardware.configure(I2C_12);
            I2CPort = hardware.i2c12;            
        }
        else if (port == I2C_89) {
            
            // Configure I2C bus on pins 8,9
            hardware.configure (I2C_89)
            I2CPort = hardware.i2c89;
        }
        else {
            
            // Problem somewhere
            server.log(format("Invalid I2C port specified: %c", port));
        }
        I2CAddress = address << 1;
        hardware.pin1.configure(DIGITAL_IN, getIRQSources.bindenv(this));
    }
    
    // Read a byte
    function read(register) {

        // Read and return data if successful
        local data = I2CPort.read(I2CAddress, format("%c", register), 1);
        if (data != null) return data[0];
        
        // Error, return -1
        server.log("I2C Read Failed");
        return -1;
    }
    
    // Write a byte
    function write (register, data) {
        I2CPort.write(I2CAddress, format("%c%c", register, data));
    }
    
    // Write a bit to a register
    function writeBit (register, bitn, level) {
        local value = read(register);
        value = (level == 0)?(value & ~(1<<bitn)):(value | (1<<bitn));
        write(register, value);
    }
    
    // Write a masked bit pattern
    function writeMasked (register, data, mask) {
       local value = read (register);
       value = (value & ~mask) | (data & mask);
       write (register, value);
    }
    
    // Set a GPIO direction
    function setDir (gpio, output){
        writeBit (gpio>=8?0x0e:0x0f, gpio&7, output?0:1);
    }
    
    // Set a GPIO level
    function setPin (gpio, level){
        writeBit (gpio>=8?0x10:0x11, gpio&7, level?1:0);
    }
    
    // Enable/disable a GPIO internal pull-up resistor
    function setPullUp (gpio, enable) {
        writeBit (gpio>=8?0x06:0x07, gpio&7, enable);
    }
    
    // Set GPIO interrupt mask
    function setIRQMask (gpio, enable) {
        writeBit (gpio>=8?0x12:0x13, gpio&7, enable);
    }
    
    // Set GPIO interrupt edges
    function setIRQEdges (gpio, rising, falling) {
        local addr = 0x17 - (gpio>>2);
        local mask = 0x03 << ((gpio&3)<<1);
        local data = (2*falling + rising) << ((gpio&3)<<1);    
        writeMasked (addr, data, mask);
    }
    
    // Clear an interrupt
    function clearIRQ (gpio) {
        writeBit (gpio>=8?0x18:0x19, gpio&7, 1);
    }
    
    function setIRQCallBack(pin, func){
        IRQ_Callbacks[pin] = func;
    }
    
    function clearIRQCallBack(pin){
           IRQ_Callbacks[pin] = null;
    }
    
    function getIRQSources(){
        //0x18=RegInterruptSourceB (Pins 15->8), 1 is an interrupt and we write a 1 to clear the interrupt
        //0x19=RegInterruptSourceA (Pins 7->0), 1 is an interrupt and we write a 1 to clear the interrupt
       local sourceB = read(0x18);
       local sourceA = read(0x19);

        local irqSources = array(16);
        
        local j = 0;
        for(local z=1; z < 256; z = z<<1){
            irqSources[j] = ((sourceA & z) == z);
            irqSources[j+8] = ((sourceB & z) == z);
            j++;
        }
        //server.log(format("irqSource=%s", byteArrayString(irqSource)));
        
        //TODO: This could be in the loop above if performance becomes an issue
        for(local pin=0; pin < 16; pin++){
            if(irqSources[pin]){
                IRQ_Callbacks[pin]();
                clearIRQ(pin);
            }
        }
        
       //Clear the interrupts   //Currently callback functions handle this
       //write(0x18, 0xFF);
       //write(0x19, 0xFF);
       return irqSources;    //Array of the IO pins and who has active interrupts
    }
    
    // Get a GPIO input pin level
    function getPin (gpio) {
        //If gpio pin is greater than or equal to 8 then its staus is in the 0x10 register, else its in the 0x11 register.  Then left shift to create a mask for the particular pin and return true or false based on its value
        return (read(gpio>=8?0x10:0x11)&(1<<(gpio&7))) ? 1 : 0;
    }
    
}


// PushButton Class for Hannah
class PushButton extends IOExpander
{
    // IO Pin assignment
    pin = null;
    irq = null;
 
    // Output port
    outPort = null;
    //Callback function for interrupt
    callBack = null;
 
    constructor(port, address, btnPin, irqPin, out, call)
    {
        //server.log("Contructing PushButton")
        base.constructor(port, address);
 
        // Save assignments
        pin = btnPin;
        irq = irqPin;
        outPort = out;
        callBack = call;
 
        // Set event handler for irq
        if (irqPin != null) //This is handled by our IOExpander class
            irqPin.configure(DIGITAL_IN, irqHandler.bindenv(this));
        else
            setIRQCallBack(btnPin, irqHandler.bindenv(this))
 
        // Configure pin as input, irq on both edges
        setDir(pin, 0);
        setPullUp(pin,1)
        setIRQMask(pin, 0);
        setIRQEdges(pin, 1, 1);
        
       //server.log("PushButton Constructed")
    }
 
    function irqHandler()
    {
        local state = null;

            // Get the pin state
            state = getPin(pin)?0:1;
 
            // Output to port and display on node
            if (outPort != null) outPort.set(state);
            //server.show(format("Push Button %d = %d", pin, state));
            //server.log(format("Push Button %d = %d", pin, state));
            if (callBack != null && state == 1) callBack()  //Only call the callback on the push down event, not the release

 
        // Clear the interrupt
        clearIRQ(pin);
    }
    
    function readState()
    {
        local state = getPin(pin);
 
        server.log(format("debug %d", state));
        return state;
    }
}


function callbackFunction1(){
     server.log("Button 1 Pressed!")
}

function callbackFunction2(){
     server.log("Button 2 Pressed!")
}

//Instantiate the buttons
pushButton1 <- PushButton(I2C_89, 0x3e, 0, null, null, callbackFunction1);
pushButton2 <- PushButton(I2C_89, 0x3e, 1, null, null, callbackFunction2);

//imp.configure and the rest of your code goes here