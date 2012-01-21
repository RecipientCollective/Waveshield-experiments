/// controllo voltaggio playhead - lunghezza loop - loop o no- velocita di lettura


/*
 * Adafruit SampleRateMod.pde example modified to use WaveHC.
 *
 * Play files with sample rate controlled by voltage on analog pin zero.
 */
#include <WaveHC.h>
#include <WaveUtil.h>

SdReader card;    // This object holds the information for the card
FatVolume vol;    // This holds the information for the partition on the card
FatReader root;   // This holds the information for the volumes root directory
FatReader file;   // This object represent the WAV file
WaveHC wave;      // This is the only wave (audio) object, since we will only play one at a time

const int pingPin = 7;
int IRpin = 1;
int cm = 0;
//variable ping or ir
boolean ping = false;
int rangeUnit=0;
float scalePot = 0 ;

const int knockSensor = A0; // the piezo is connected to analog pin 0
const int threshold = 15;  // threshold value to decide when the detected sound is a knock or not
int sensorReading = 0;      // variable to store the value read from the sensor pin


/*
 * Define macro to put error messages in flash memory
 */
#define error(msg) error_P(PSTR(msg))

//////////////////////////////////// SETUP
void setup() {
  Serial.begin(9600);
  Serial.println("Wave test!");

  // try card.init(true) if errors occur on V1.0 Wave Shield
  if (!card.init()) {
    error("Card init. failed!");
  }
  // enable optimize read - some cards may timeout
  card.partialBlockRead(true);
  
  if (!vol.init(card)) {
    error("No partition!");
  }
  if (!root.openRoot(vol)) {
    error("Couldn't open root");
  }
  putstring_nl("Files found:");
  root.ls();
}

// forward declarition
void playcomplete(FatReader &file);

//////////////////////////////////// LOOP
void loop() { 
  uint8_t i, r;
  char c, name[15];
  dir_t dir;

  root.rewind();
  // scroll through the files in the directory
  while (root.readDir(dir) > 0) { 
    // only play .WAV files
    if (!strncmp_P((char *)&dir.name[8]. PSTR("WAV"))) continue;
    
    if (!file.open(vol, dir)){
      putstring("Can't open ");
      printEntryName(dir);
      Serial.println();
      continue;
    }
    putstring("\n\rPlaying "); 
    printEntryName(dir);
    Serial.println();
    playcomplete(file);
    file.close();    
  }
}
/////////////////////////////////// HELPERS
/*
 * print error message and halt
 */
void error_P(const char *str) {
  PgmPrint("Error: ");
  SerialPrint_P(str);
  sdErrorCheck();
  while(1);
}
/*
 * print error message and halt if SD I/O error, great for debugging!
 */
void sdErrorCheck(void) {
  if (!card.errorCode()) return;
  PgmPrint("\r\nSD I/O error: ");
  Serial.print(card.errorCode(), HEX);
  PgmPrint(", ");
  Serial.println(card.errorData(), HEX);
  while(1);
}
int16_t lastpotval = 0;
#define HYSTERESIS 3
/*
 * play file with sample rate changes
 */
void playcomplete(FatReader &file) {
  int16_t potval;
  float potvalF;
  uint32_t newsamplerate;
  
   if (!wave.create(file)) {
     putstring_nl(" Not a valid WAV"); return;
   }
   // ok time to play!
   wave.play();
   
  while (wave.isplaying) {
 
    
 sensorReading = analogRead(knockSensor);  
  Serial.print("sensor knok = "); 
  Serial.println(sensorReading);
  // if the sensor reading is greater than the threshold:
  if (sensorReading >= threshold) {
    // toggle the status of the ledPin:
    //ledState = !ledState;   
    // update the LED pin itself:        
    //digitalWrite(ledPin, ledState);
    // send the string "Knock!" back to the computer, followed by newline
    Serial.println("change sensor");    
    ping = !ping;  
  }
    
    
    
 if (ping){   
  // establish variables for duration of the ping, 
  // and the distance result in inches and centimeters:
  long duration, inches, cm;

  // The PING))) is triggered by a HIGH pulse of 2 or more microseconds.
  // Give a short LOW pulse beforehand to ensure a clean HIGH pulse:
  pinMode(pingPin, OUTPUT);
  digitalWrite(pingPin, LOW);
  delayMicroseconds(2);
  digitalWrite(pingPin, HIGH);
  delayMicroseconds(5);
  digitalWrite(pingPin, LOW);

  // The same pin is used to read the signal from the PING))): a HIGH
  // pulse whose duration is the time (in microseconds) from the sending
  // of the ping to the reception of its echo off of an object.
  pinMode(pingPin, INPUT);
  duration = pulseIn(pingPin, HIGH);

  // convert the time into a distance
  inches = microsecondsToInches(duration);
  cm = microsecondsToCentimeters(duration);
  
  Serial.print(inches);
  Serial.print("in, ");
  Serial.print(cm);
  Serial.print("cm");
  Serial.println();
  potval = duration;
  if (potval>rangeUnit){
  rangeUnit=potval;
  }  
 
  delay(100);
 }else{
  //SHARP IR
  //float volts = analogRead(IRpin)*0.0048828125;   // value from sensor * (5/1024) - if running 3.3.volts then change 5 to 3.3
  //float distance = 23*pow(volts, -1.10);  
  // worked out from graph 65 = theretical distance / (1/Volts)S - luckylarry.co.uk
  float irSens = analogRead(IRpin);
  Serial.println(irSens);                       // print the distance
  delay(100); 
  potval = irSens;
 if (potval>rangeUnit){
  rangeUnit=potval;
  }  
}
  
    
    
     
     if ( ((potval - lastpotval) > HYSTERESIS) || ((lastpotval - potval) > HYSTERESIS)) {
         putstring("pot = ");
         Serial.println(potval, DEC); 
         putstring("tickspersam = ");
         Serial.print(wave.dwSamplesPerSec, DEC);
         putstring(" -> ");
        // potval 0-1024 sample 0-24000  x/1024*24000
        potvalF = potval;
        scalePot = (potvalF/1024)*24000;
         newsamplerate = wave.dwSamplesPerSec;
         newsamplerate *= potval;
         newsamplerate /= 512;   // we want to 'split' between sped up and slowed down.
        if (newsamplerate > 24000) {
          newsamplerate = 24000;  
        }
        if (newsamplerate < 1000) {
          newsamplerate = 1000;  
        }        
        wave.setSampleRate(newsamplerate);
        
        Serial.println(newsamplerate, DEC);
        putstring("scalePot = ");
        Serial.println(scalePot);
        lastpotval = potval;
     }
     delay(100);
   }
   sdErrorCheck();
}


long microsecondsToInches(long microseconds)
{
  // According to Parallax's datasheet for the PING))), there are
  // 73.746 microseconds per inch (i.e. sound travels at 1130 feet per
  // second).  This gives the distance travelled by the ping, outbound
  // and return, so we divide by 2 to get the distance of the obstacle.
  // See: http://www.parallax.com/dl/docs/prod/acc/28015-PING-v1.3.pdf
  return microseconds / 74 / 2;
}

long microsecondsToCentimeters(long microseconds)
{
  // The speed of sound is 340 m/s or 29 microseconds per centimeter.
  // The ping travels out and back, so to find the distance of the
  // object we take half of the distance travelled.
  return microseconds / 29 / 2;
}

