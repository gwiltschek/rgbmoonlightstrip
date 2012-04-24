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

int STOP = 0;
#define STRIP_LENGTH 32
long strip_colors[STRIP_LENGTH];
int currcolor = 0;
int currstep = 0;
int steps = 500;
int step_delay = 500;
int moon_delay = 100;
long colors[8];

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
  0x0A0000,
  0x060000,
  0x030000,
  0x000000,
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

	get_currentstate();

	for (i = 0; i < 8; i++) {
		if (currentstate == rise) {
			colors[i] = colors_rise[i];
		}
		else {
			colors[i] = colors_dawn[i];
		}
	}

	delay(1000);
	for (i = 0; i < STRIP_LENGTH; i++) {
		strip_colors[i] = 0;
	}  
	post_frame();

	while(1) {
		if (STOP == 1) {
			while(1) {

			}
		}
			
		currstep++;
		interpolate();
		if (steps == currstep) {
			currstep = 0;
			currcolor = (currcolor + 1) % 8;
			if (currentstate == dawn) {
				if (currcolor == 7) {
					Serial.println("MOON INIT");
					initiateMoon();
					currentstate = moon;
					while (currentstate == moon) {
						moveMoon();
					}
				}
			}
			else {
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

void get_currentstate() {
	currentstate = dawn;

	Serial.println(currentstate);
}

void initiateMoon() {
	
	// get random position
	moonPos = STRIP_LENGTH - 3;
	// get random color
	moonColor = random(0xFFFFFF);

	int i = 0;
	int moonSteps = 50;	
	for (i = 0; i < moonSteps; i++) {
		long red = moonColor >> 16;
		long green = (moonColor >> 8) & 0xff;
		long blue = moonColor & 0xff;

		red = red * i  / moonSteps;
		green = green * i / moonSteps;
		blue = blue * i / moonSteps;
		
		long newColor = (((red << 8) | green) << 8) | blue;

		strip_colors[moonPos] = newColor;
		Serial.println(i);
		Serial.println(moonPos);
		Serial.println(strip_colors[moonPos]);
		post_frame();
		delay(200);
	}

}

void moveMoon() {
	if (moonPos == 1) {
		STOP = 1;
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
