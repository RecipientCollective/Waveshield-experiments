/*
 * use WaveHC.
 *
 * Play files with sample rate controlled by voltage.
 * play loop.wav file until the button is pushed than play sound.wav
 * while playing sound.wav the led will light up and the sample Rate can be controlled by voltage
 *
 *little mod make by mandria - recipient.cc collective
 */
#include <WaveHC.h>
#include <WaveUtil.h>

SdReader card;    // This object holds the information for the card
FatVolume vol;    // This holds the information for the partition on the card
FatReader root;   // This holds the information for the volumes root directory
FatReader file;   // This object represent the WAV file
WaveHC wave;      // This is the only wave (audio) object, since we will only play one at a time

/*
 * Define macro to put error messages in flash memory
 */
#define error(msg) error_P(PSTR(msg))

const int buttonPin = 7;     // the number of the pushbutton pin
const int ledPin =  13;      // the number of the LED pin
const int potPin = 0;
// variables will change:
int buttonState = 0;         // variable for reading the pushbutton status
//
boolean momenton=false;      // variable to know if the player is in loop mode or in single file w effects


//////////////////////////////////// SETUP
void setup() {
  Serial.begin(9600);
  Serial.println("Wave test!");
   // initialize the LED pin as an output:
  pinMode(ledPin, OUTPUT);      
  // initialize the pushbutton pin as an input:
  pinMode(buttonPin, INPUT);     

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
// forward declarition
void playfile(FatReader &file);

//////////////////////////////////// LOOP
void loop() { 
 Serial.println("new ardu Loop");
    playfile("LOOP.WAV");  
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
void playcomplete(char *name) {
  int16_t firstpotval;
  int16_t potval;
  uint32_t newsamplerate;
  digitalWrite(ledPin, HIGH);
  firstpotval=analogRead(0);
  if (wave.isplaying) {// already playing something, so stop it!
    wave.stop(); // stop it
  }
  if (!file.open(root, name)) {
    PgmPrint("Couldn't open file ");
    Serial.print(name); 
    return;
  }
   if (!wave.create(file)) {
     putstring_nl(" Not a valid WAV"); return;
   }
   // ok time to play!
   wave.play();
   
  while (wave.isplaying) {
     potval = analogRead(potPin);
     if (potval==firstpotval){
     } else {
     if ( ((potval - lastpotval) > HYSTERESIS) || ((lastpotval - potval) > HYSTERESIS)) {
         putstring("pot = ");
         Serial.println(potval, DEC); 
         putstring("tickspersam = ");
         Serial.print(wave.dwSamplesPerSec, DEC);
         putstring(" -> ");
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
        lastpotval = potval;  
     }
     }
     if(wave.remainingBytesInChunk == 0){
         file.close();
         playfile("LOOP.WAV");
      }
     delay(100);
   }
   sdErrorCheck();
}

void playfile(char *name) {
  digitalWrite(ledPin, LOW);
  if (!file.open(root, name)) {
    PgmPrint("Couldn't open file ");
    Serial.print(name); 
    return;
  }
  if (!wave.create(file)) {
    PgmPrintln("Not a valid WAV");
    return;
  }
  // ok time to play!
  wave.play();
   while (wave.isplaying) {
   buttonState = digitalRead(buttonPin);

  // check if the pushbutton is pressed.
  // if it is, the buttonState is HIGH:
  if (buttonState == HIGH) {     
    // turn LED on:    
    wave.stop();
    file.close();
    playcomplete("SOUND.WAV");
  } 
    delay(100);
   }
  sdErrorCheck();
}

