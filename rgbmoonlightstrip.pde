/*
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

int SDI = 2; //Red wire (not the red 5V wire!)
int CKI = 3; //Green wire
int ledPin = 13; //On board LED

#define STRIP_LENGTH 32
long strip_colors[STRIP_LENGTH];
int currcolor = 0;
int currstep = 0;
int steps = 100;
int step_delay = 25;
int moon_delay = 100;
long colors[8] = {
  0x000000,
  0xF00000,
  0xFF0000,
  0xFFF000,
  0xFFFF00,
  0xFFFFF0,
  0xFFFFFF,
  0xFF0000
};

enum state {
	rise,
	dawn,
	moon
};

state currentstate = rise;

int moonPos;
long moonColor;


void setup() {
	randomSeed(analogRead(0));

	pinMode(SDI, OUTPUT);
	pinMode(CKI, OUTPUT);
	pinMode(ledPin, OUTPUT);

	// clear the array
	for(int x = 0 ; x < STRIP_LENGTH ; x++){
		strip_colors[x] = 0x000000;
	}

	Serial.begin(9600);
}

void loop() {
	int i = 0;

	//Pre-fill the color array with known values
	strip_colors[0] = 0xFF0000; //Bright Red
	strip_colors[1] = 0x00FF00; //Bright Green
	strip_colors[2] = 0x0000FF; //Bright Blue

	post_frame(); //Push the current color frame to the strip

	delay(1000);
	for (i = 0; i < STRIP_LENGTH; i++) {
		strip_colors[i] = 0;
	}  
	post_frame();

	while(1) {

		if (currentstate == rise) {
			currstep++;
			interpolate();
			if (steps == currstep) {
				currstep = 0;
				currcolor = (currcolor + 1) % 8;
				if (currcolor == 7) {
					currentstate = moon;
					initiateMoon();
					while (currentstate == moon) {
						moveMoon();
					}
				}
			}
			post_frame();
			delay(step_delay);
		}
		else if (currentstate == moon) {
		}
	}
}

void initiateMoon() {
	clearAll();
	
	// get random position
	moonPos = STRIP_LENGTH/2 + random(5);
	// get random color
	moonColor = random(0xFFFFFF);
	strip_colors[moonPos] = moonColor;

	post_frame();
}

void moveMoon() {
	if (moonPos == 1) {
		currentstate = rise;
		return;
	}

	clearAll();
	double percentFade = 0;
	
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

void clearAll() {
	int i = 0;
	for (i = 0; i < STRIP_LENGTH; i++) {
		strip_colors[i] = 0x000000;
	}
}

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

	Serial.println("--------------");
	Serial.println(currstep, DEC);
	Serial.println(steps, DEC);
	Serial.println(percentFade, DEC);

	newColor = (((diffRed << 8) | diffGreen) << 8) | diffBlue;

	Serial.println(newColor, HEX);


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
