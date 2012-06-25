/*
	Aquarium sunrise/sunset/moonlight sketch for an arduino-controlled
	RGB led strip.

	Interpolates between predefined colors from an array/moves a 1-2 LED wide
	moon along the strip.

	Based on code by Nathan Seidle, SparkFun Electronics 2011
	http://www.sparkfun.com/datasheets/Components/LED/LED_Strip_Example.pde
	http://www.sparkfun.com/products/10312

	4-pin connection:
	Blue = 5V
	Red = SDI
	Green = CKI
	Black = GND

	Split 5-pin connection:
	2-pin Red+Black = 5V/GND
	Green = CKI
	Red = SDI
*/

#define STRIP_LENGTH (32)

// IO Pins
int SDI = 2; // Red wire (not the red 5V wire!)
int CKI = 3; // Green wire
int ledPin = 13; // On board LED
int lightSensorPin = 0; // see get_neon()
int randomPin = 1;

int STOP = 0;
int currcolor = 0; // current index in colors[]
int currstep = 0;
int steps = 300;
int step_delay = 400;
int moon_delay = 150;
int moonPos;
long moonColor;

long strip_colors[STRIP_LENGTH]; // colors for post_frame()

// pre-defined colors for sunrise/sunset
// get copied to colors[] on startup depending on
// current light in tank
long colors_rise[8] = {
  0x000000,
  0x220000,
  0x990000,
  0xFF0000,
  0x999900,
  0xFFFF00,
  0xAAAAAA,
  0xFFFFFF
};
long colors_dawn[8] = {
  0xFFFFFF,
  0xFFFF00,
  0xFF0000,
  0xAA0000,
  0x660000,
  0x060000,
  0x030000,
  0x000000,
};
long colors[8];

enum state {
	rise,
	dawn,
	moon
};
state currentstate = rise;

void setup() {
	randomSeed(analogRead(randomPin));
	pinMode(SDI, OUTPUT);
	pinMode(CKI, OUTPUT);
	pinMode(ledPin, OUTPUT);
	Serial.begin(9600);
	clearAll();
}

void loop() {
	int i = 0;

	// get current tank light status
	int neon = get_neon();

	if (neon == 0) {
		// night in the tank, so do sunrise
		currentstate = rise;
	}
	else {
		// day in tank, so turn LEDs to full white
		// and wait until tank light goes off / night starts
		for(int x = 0 ; x < STRIP_LENGTH ; x++){
			strip_colors[x] = 0xFFFFFF;
		}
		post_frame();
		currentstate = dawn;
		while(get_neon() == neon) {
			// wait until tank light turns off
			delay(100);
			Serial.println("waiting...");
		}
		Serial.println("exit waiting loop");
	}

	// copy color array depending on current light in tank
	for (i = 0; i < 8; i++) {
		if (currentstate == rise) {
			colors[i] = colors_rise[i];
		}
		else {
			colors[i] = colors_dawn[i];
		}
	}

	while(1) {
		
		// after one full sunrise or sunset,
		// just wait until power goes off
		if (STOP == 1) {
			while(1) {
				delay(100000);
			}
		}
			
		currstep++;
		interpolate();

		if (steps == currstep) {
			// transition between two colors finished, move
			// on to the next colir
			currstep = 0;
			currcolor = (currcolor + 1) % 8;
			
			if (currentstate == dawn) {

				// moon phase starts if state is dawn and
				// we are at the last color of our colors[] array
				if (currcolor == 7) {
					initiateMoon();
					currentstate = moon;
					while (currentstate == moon) {
						moveMoon();
					}
				}

			}
			else {

				// if currentcolor is the last color in colors[]
				// and state is not dawn, we are finished with sunrise
				if (currcolor == 7) {
					post_frame();	
					STOP = 1;
				}
			}
		}

		post_frame();
		delay(step_delay);
	}
}

// photoresistor attached to indicator LED of timer
// returns 1 if light is on
// returns 0 if light is off
// 
//             PhotoR     10K
//   +5    o---/\/\/--.--/\/\/---o GND
//                    |
//   Pin 0 o-----------
//
// (taken from http://www.arduino.cc/playground/Learning/PhotoResistor)
int get_neon() {
	int input = -1;
	input = analogRead(lightSensorPin);
	Serial.println(input);
	
	// values may vary, for me
	// timer LED on is about 130, off  is ~25
	if (input < 50) {
		return 0;
	}
	else {
		return 1;
	}
}

// let the moonlight fade in with a random color
void initiateMoon() {
	int i = 0;
	int moonInitSteps = 50;	
	
	// set position
	moonPos = STRIP_LENGTH - 3;
	
	// get random color
	moonColor = (((random(0xFF) << 8) | random(0xFF)) << 8) | random(0xFF);

	// do moonInitSteps steps from 0% to 100% moonColor
	for (i = 0; i < moonInitSteps; i++) {
		long red = moonColor >> 16;
		long green = (moonColor >> 8) & 0xff;
		long blue = moonColor & 0xff;

		red = red * i  / moonInitSteps;
		green = green * i / moonInitSteps;
		blue = blue * i / moonInitSteps;
		
		long newColor = (((red << 8) | green) << 8) | blue;

		strip_colors[moonPos] = newColor;

		post_frame();
		delay(200);
	}
}

// move the moon along the LED strip
void moveMoon() {
	double percentFade = 0;	
	
	if (moonPos == 1) {
		// end moon movement
		STOP = 1;
		return;
	}

	// clear old moon
	clearAll();

	// move moonlight between two leds
	while (percentFade <= 1) {
		long endColor = moonColor;
		long startColor = 0x000000;
		
		long startRed = startColor >> 16;
		long startGreen = (startColor >> 8) & 0xff;
		long startBlue = startColor & 0xff;
		
		long endRed = endColor >> 16;
		long endGreen = (endColor >> 8) & 0xff;
		long endBlue = endColor & 0xff;

		long diffRed = endRed - startRed;
		long diffGreen = endGreen - startGreen;
		long diffBlue = endBlue - startBlue;

		diffRed = (diffRed * percentFade) + startRed;
		diffGreen = (diffGreen * percentFade) + startGreen;
		diffBlue = (diffBlue * percentFade) + startBlue;

		long newColor = (((diffRed << 8) | diffGreen) << 8) | diffBlue;

		strip_colors[moonPos] = moonColor - newColor;
		strip_colors[moonPos - 1] = newColor;
		delay(moon_delay);
		post_frame();
		percentFade += 0.01;
	}
	moonPos--;
}

// turn off all LEDs
void clearAll() {
	int i = 0;
	for (i = 0; i < STRIP_LENGTH; i++) {
		strip_colors[i] = 0x000000;
	}
}

// fill strip_colors with interpolated values from colors[x] and colors[x+1]
void interpolate() {
	int i = 0;

	long newColor = 0;
	long startColor = colors[currcolor];
	long endColor = colors[(currcolor + 1) % 8];
	
	long startRed = startColor >> 16;
	long startGreen = (startColor >> 8) & 0xff;
	long startBlue = startColor & 0xff;
	
	long endRed = endColor >> 16;
	long endGreen = (endColor >> 8) & 0xff;
	long endBlue = endColor & 0xff;

	long diffRed = endRed - startRed;
	long diffGreen = endGreen - startGreen;
	long diffBlue = endBlue - startBlue;

	double percentFade = (double)currstep/(double)steps;

	diffRed = (diffRed * percentFade) + startRed;
	diffGreen = (diffGreen * percentFade) + startGreen;
	diffBlue = (diffBlue * percentFade) + startBlue;

	newColor = (((diffRed << 8) | diffGreen) << 8) | diffBlue;

	for (i = 0; i < STRIP_LENGTH; i++) {
		strip_colors[i] = newColor;
	}
}

//Takes the current strip color array and pushes it out
void post_frame (void) {
  //Each LED requires 24 bits of data
  //MSB: R7, R6, R5..., G7, G6..., B7, B6... B0 
  //Once the 24 bits have been delivered, the IC immediately relays these bits to its neighbor
  //Pulling the clock low for 500us or more causes the IC to post the data.

  for(int LED_number = 0 ; LED_number < STRIP_LENGTH ; LED_number++) {
    long this_led_color = strip_colors[LED_number]; //24 bits of color data

    for(byte color_bit = 23 ; color_bit != 255 ; color_bit--) {
      //Feed color bit 23 first (red data MSB)
      
      digitalWrite(CKI, LOW); //Only change data when clock is low
      
      long mask = 1L << color_bit;
      //The 1'L' forces the 1 to start as a 32 bit number, otherwise it defaults to 16-bit.
      
      if(this_led_color & mask) 
        digitalWrite(SDI, HIGH);
      else
        digitalWrite(SDI, LOW);
  
      digitalWrite(CKI, HIGH); //Data is latched when clock goes high
    }
  }

  //Pull clock low to put strip into reset/post mode
  digitalWrite(CKI, LOW);
  delayMicroseconds(500); //Wait for 500us to go into reset
}

