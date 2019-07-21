/*
 * IRremoteESP8266: IRrecvDumpV2 - dump details of IR codes with IRrecv
 * An IR detector/demodulator must be connected to the input kRecvPin.
 *
 * Copyright 2009 Ken Shirriff, http://arcfn.com
 * Copyright 2017 David Conran
 *
 * Example circuit diagram:
 *  https://github.com/markszabo/IRremoteESP8266/wiki#ir-receiving
 *
 * Changes:
 *   Version 0.4 July, 2018
 *     - Minor improvements and more A/C unit support.
 *   Version 0.3 November, 2017
 *     - Support for A/C decoding for some protcols.
 *   Version 0.2 April, 2017
 *     - Decode from a copy of the data so we can start capturing faster thus
 *       reduce the likelihood of miscaptures.
 * Based on Ken Shirriff's IrsendDemo Version 0.1 July, 2009,
 */

#ifndef UNIT_TEST
#include <Arduino.h>
#endif
#include <IRrecv.h>
#include <IRremoteESP8266.h>
#include <IRsend.h>
#include <IRutils.h>
// The following are only needed for extended decoding of A/C Messages
#include <ir_Coolix.h>
#include <ir_Daikin.h>
#include <ir_Fujitsu.h>
#include <ir_Gree.h>
#include <ir_Haier.h>
#include <ir_Hitachi.h>
#include <ir_Kelvinator.h>
#include <ir_Midea.h>
#include <ir_Mitsubishi.h>
#include <ir_Panasonic.h>
#include <ir_Samsung.h>
#include <ir_Tcl.h>
#include <ir_Teco.h>
#include <ir_Toshiba.h>
#include <ir_Vestel.h>
#include <ir_Whirlpool.h>
#include <ESP8266WiFi.h>
#include <ESP8266WiFiMulti.h>
#include <ESP8266HTTPClient.h>

//Process Json
#include <ArduinoJson.h>

//WEBSockets
#include <Hash.h>
#include <WebSocketsClient.h>

//MQTT PUBSUBCLIENT LIB 
#include <PubSubClient.h>

//AWS MQTT Websocket
#include "Client.h"
#include "AWSWebSocketClient.h"
#include "CircularByteBuffer.h"

//Wifi
char wifi_ssid[]       = "ssid";
char wifi_password[]   = "password";
char wifi_ssid1[] = "ssid1";
char wifi_password1[] = "password";
char wifi_ssid2[] = "ssid2";
char wifi_password2[] = "password2";
ESP8266WiFiMulti WiFiMulti;


//AWS IOT config, change these:
char aws_endpoint[]    = "xxxx.iot.ap-northeast-1.amazonaws.com";
char aws_key[]         = "your secret key id";
char aws_secret[]      = "your secret key";
char aws_region[]      = "ap-northeast-1";
const char* aws_topic  = "remotecontroltopic"; // set topic, publish message to this topic
int port = 443;

//MQTT config
const int maxMQTTpackageSize = 512;
const int maxMQTTMessageHandlers = 1;


AWSWebSocketClient awsWSclient(1000);

PubSubClient client(awsWSclient);

// Send IR code related settings
const uint16_t kIrLed = 4;  // ESP8266 GPIO pin to use. Recommended: 4 (D2).
IRsend irsend(kIrLed);  // Set the GPIO to be used to sending the message.

//# of connections
long connection = 0;

//generate random mqtt clientID
char* generateClientID () {
  char* cID = new char[23]();
  for (int i=0; i<22; i+=1)
    cID[i]=(char)random(1, 256);
  return cID;
}

//count messages arrived
int arrivedcount = 0;

//flag to indicate if IR code is from ESP12E itself

unsigned long timeIROutFromESP12E;

//callback to handle mqtt messages
void callback(char* topic, byte* payload, unsigned int length) {

  Serial.print("Message arrived [");
  Serial.print(topic);
  Serial.print("] ");

    
  for (int i = 0; i < length; i++) {
    Serial.print((char)payload[i]);
  }
  
  Serial.println();

  payload[length] = '\0';
  String s = String((char *)payload);

  Serial.println(s);

  Serial.println();

  // Get IR code based on the IR code ID

  if(WiFiMulti.run() == WL_CONNECTED){
    
    HTTPClient http;
    http.begin("http://101.132.104.40/data?id="+s);
    int httpCode = http.GET();
    String result = http.getString();
    Serial.println(result);

    // Use ArduinoJson library to deserialize Json
    DynamicJsonDocument doc(4000);
    DeserializationError error = deserializeJson(doc, result);
    if(error){
      Serial.print(F("deserializeJson() failed: "));
      Serial.println(error.c_str());
      return;      
    }
    const char* code = doc["code"];
    int codeLength = doc["codeLength"];
    Serial.println(code);
    Serial.println(codeLength);
    uint16_t rawData[codeLength];
    for(int i = 0; i<codeLength; i++){
      rawData[i] = getValue(code,' ',i).toInt();
    }
    timeIROutFromESP12E = millis();
    irsend.sendRaw(rawData, sizeof(rawData) / sizeof(rawData[0]), 38);
  }
  // Test code
  /*
  int intCodeLength = codeLength.toInt();
  uint16_t rawData[intCodeLength];
  for(int i = 0; i<intCodeLength; i++){
    rawData[i] = getValue(code,' ',i).toInt();
  }
  irsend.sendRaw(rawData, sizeof(rawData) / sizeof(rawData[0]), 38); 
  delay(2000);  
  */

}

//connects to websocket layer and mqtt layer
bool connect () {

    if (client.connected()) {    
        client.disconnect ();
    }  
    //delay is not necessary... it just help us to get a "trustful" heap space value
    delay (1000);
    Serial.print (millis ());
    Serial.print (" - conn: ");
    Serial.print (++connection);
    Serial.print (" - (");
    Serial.print (ESP.getFreeHeap ());
    Serial.println (")");


    //creating random client id
    char* clientID = generateClientID ();
    
    client.setServer(aws_endpoint, port);
    if (client.connect(clientID)) {
      Serial.println("PubSubClient connected");     
      return true;
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      return false;
    }
    
}

//subscribe to a mqtt topic
void subscribe () {
    client.setCallback(callback);
    client.subscribe(aws_topic);
   //subscript to a topic
    Serial.println("MQTT subscribed");
}


// ==================== start of TUNEABLE PARAMETERS ====================
// An IR detector/demodulator is connected to GPIO pin 14
// e.g. D5 on a NodeMCU board.
const uint16_t kRecvPin = 14;

// The Serial connection baud rate.
// i.e. Status message will be sent to the PC at this baud rate.
// Try to avoid slow speeds like 9600, as you will miss messages and
// cause other problems. 115200 (or faster) is recommended.
// NOTE: Make sure you set your Serial Monitor to the same speed.
const uint32_t kBaudRate = 115200;

// As this program is a special purpose capture/decoder, let us use a larger
// than normal buffer so we can handle Air Conditioner remote codes.
const uint16_t kCaptureBufferSize = 1024;

// kTimeout is the Nr. of milli-Seconds of no-more-data before we consider a
// message ended.
// This parameter is an interesting trade-off. The longer the timeout, the more
// complex a message it can capture. e.g. Some device protocols will send
// multiple message packets in quick succession, like Air Conditioner remotes.
// Air Coniditioner protocols often have a considerable gap (20-40+ms) between
// packets.
// The downside of a large timeout value is a lot of less complex protocols
// send multiple messages when the remote's button is held down. The gap between
// them is often also around 20+ms. This can result in the raw data be 2-3+
// times larger than needed as it has captured 2-3+ messages in a single
// capture. Setting a low timeout value can resolve this.
// So, choosing the best kTimeout value for your use particular case is
// quite nuanced. Good luck and happy hunting.
// NOTE: Don't exceed kMaxTimeoutMs. Typically 130ms.
#if DECODE_AC
// Some A/C units have gaps in their protocols of ~40ms. e.g. Kelvinator
// A value this large may swallow repeats of some protocols
const uint8_t kTimeout = 50;
#else   // DECODE_AC
// Suits most messages, while not swallowing many repeats.
const uint8_t kTimeout = 15;
#endif  // DECODE_AC
// Alternatives:
// const uint8_t kTimeout = 90;
// Suits messages with big gaps like XMP-1 & some aircon units, but can
// accidentally swallow repeated messages in the rawData[] output.
//
// const uint8_t kTimeout = kMaxTimeoutMs;
// This will set it to our currently allowed maximum.
// Values this high are problematic because it is roughly the typical boundary
// where most messages repeat.
// e.g. It will stop decoding a message and start sending it to serial at
//      precisely the time when the next message is likely to be transmitted,
//      and may miss it.

// Set the smallest sized "UNKNOWN" message packets we actually care about.
// This value helps reduce the false-positive detection rate of IR background
// noise as real messages. The chances of background IR noise getting detected
// as a message increases with the length of the kTimeout value. (See above)
// The downside of setting this message too large is you can miss some valid
// short messages for protocols that this library doesn't yet decode.
//
// Set higher if you get lots of random short UNKNOWN messages when nothing
// should be sending a message.
// Set lower if you are sure your setup is working, but it doesn't see messages
// from your device. (e.g. Other IR remotes work.)
// NOTE: Set this value very high to effectively turn off UNKNOWN detection.
const uint16_t kMinUnknownSize = 12;
// ==================== end of TUNEABLE PARAMETERS ====================

// Use turn on the save buffer feature for more complete capture coverage.
IRrecv irrecv(kRecvPin, kCaptureBufferSize, kTimeout, true);

decode_results results;  // Somewhere to store the results

// Display the human readable state of an A/C message if we can.
void dumpACInfo(decode_results *results) {
  String description = "";
#if DECODE_DAIKIN
  if (results->decode_type == DAIKIN) {
    IRDaikinESP ac(0);
    ac.setRaw(results->state);
    description = ac.toString();
  }
#endif  // DECODE_DAIKIN
#if DECODE_DAIKIN2
  if (results->decode_type == DAIKIN2) {
    IRDaikin2 ac(0);
    ac.setRaw(results->state);
    description = ac.toString();
  }
#endif  // DECODE_DAIKIN2
#if DECODE_FUJITSU_AC
  if (results->decode_type == FUJITSU_AC) {
    IRFujitsuAC ac(0);
    ac.setRaw(results->state, results->bits / 8);
    description = ac.toString();
  }
#endif  // DECODE_FUJITSU_AC
#if DECODE_KELVINATOR
  if (results->decode_type == KELVINATOR) {
    IRKelvinatorAC ac(0);
    ac.setRaw(results->state);
    description = ac.toString();
  }
#endif  // DECODE_KELVINATOR
#if DECODE_MITSUBISHI_AC
  if (results->decode_type == MITSUBISHI_AC) {
    IRMitsubishiAC ac(0);
    ac.setRaw(results->state);
    description = ac.toString();
  }
#endif  // DECODE_MITSUBISHI_AC
#if DECODE_TOSHIBA_AC
  if (results->decode_type == TOSHIBA_AC) {
    IRToshibaAC ac(0);
    ac.setRaw(results->state);
    description = ac.toString();
  }
#endif  // DECODE_TOSHIBA_AC
#if DECODE_GREE
  if (results->decode_type == GREE) {
    IRGreeAC ac(0);
    ac.setRaw(results->state);
    description = ac.toString();
  }
#endif  // DECODE_GREE
#if DECODE_MIDEA
  if (results->decode_type == MIDEA) {
    IRMideaAC ac(0);
    ac.setRaw(results->value);  // Midea uses value instead of state.
    description = ac.toString();
  }
#endif  // DECODE_MIDEA
#if DECODE_HAIER_AC
  if (results->decode_type == HAIER_AC) {
    IRHaierAC ac(0);
    ac.setRaw(results->state);
    description = ac.toString();
  }
#endif  // DECODE_HAIER_AC
#if DECODE_HAIER_AC_YRW02
  if (results->decode_type == HAIER_AC_YRW02) {
    IRHaierACYRW02 ac(0);
    ac.setRaw(results->state);
    description = ac.toString();
  }
#endif  // DECODE_HAIER_AC_YRW02
#if DECODE_SAMSUNG_AC
  if (results->decode_type == SAMSUNG_AC) {
    IRSamsungAc ac(0);
    ac.setRaw(results->state, results->bits / 8);
    description = ac.toString();
  }
#endif  // DECODE_SAMSUNG_AC
#if DECODE_COOLIX
  if (results->decode_type == COOLIX) {
    IRCoolixAC ac(0);
    ac.setRaw(results->value);  // Coolix uses value instead of state.
    description = ac.toString();
  }
#endif  // DECODE_COOLIX
#if DECODE_PANASONIC_AC
  if (results->decode_type == PANASONIC_AC &&
      results->bits > kPanasonicAcShortBits) {
    IRPanasonicAc ac(0);
    ac.setRaw(results->state);
    description = ac.toString();
  }
#endif  // DECODE_PANASONIC_AC
#if DECODE_HITACHI_AC
  if (results->decode_type == HITACHI_AC) {
    IRHitachiAc ac(0);
    ac.setRaw(results->state);
    description = ac.toString();
  }
#endif  // DECODE_HITACHI_AC
#if DECODE_WHIRLPOOL_AC
  if (results->decode_type == WHIRLPOOL_AC) {
    IRWhirlpoolAc ac(0);
    ac.setRaw(results->state);
    description = ac.toString();
  }
#endif  // DECODE_WHIRLPOOL_AC
#if DECODE_VESTEL_AC
  if (results->decode_type == VESTEL_AC) {
    IRVestelAc ac(0);
    ac.setRaw(results->value);  // Like Coolix, use value instead of state.
    description = ac.toString();
  }
#endif  // DECODE_VESTEL_AC
#if DECODE_TECO
  if (results->decode_type == TECO) {
    IRTecoAc ac(0);
    ac.setRaw(results->value);  // Like Coolix, use value instead of state.
    description = ac.toString();
  }
#endif  // DECODE_TECO
#if DECODE_TCL112AC
  if (results->decode_type == TCL112AC) {
    IRTcl112Ac ac(0);
    ac.setRaw(results->state);
    description = ac.toString();
  }
#endif  // DECODE_TCL112AC
  // If we got a human-readable description of the message, display it.
  if (description != "") Serial.println("Mesg Desc.: " + description);
}

// The section of code run only once at start-up.
void setup() {
  Serial.begin(kBaudRate, SERIAL_8N1, SERIAL_TX_ONLY);
  while (!Serial)  // Wait for the serial connection to be establised.
    delay(50);
  Serial.println();
  Serial.print("IRrecvDumpV2 is now running and waiting for IR input on Pin ");
  Serial.println(kRecvPin);

#if DECODE_HASH
  // Ignore messages with less than minimum on or off pulses.
  irrecv.setUnknownThreshold(kMinUnknownSize);
#endif                  // DECODE_HASH
  irrecv.enableIRIn();  // Start the receiverwifiMulti.addAP

  // Connect Wifi
  wifi_set_sleep_type(NONE_SLEEP_T);
  Serial.begin (115200);
  delay (2000);
  Serial.setDebugOutput(1);

  WiFi.mode(WIFI_STA);
  //fill with ssid and wifi password
  WiFiMulti.addAP(wifi_ssid, wifi_password);
  WiFiMulti.addAP(wifi_ssid1, wifi_password1);
  WiFiMulti.addAP(wifi_ssid2, wifi_password2);
  //WiFiMulti.addAP(wifi_ssid3, wifi_password3);
  Serial.println ("connecting to wifi");
  while(WiFiMulti.run() != WL_CONNECTED) {
      delay(100);
      Serial.print (".");
  }
  Serial.println ("\nWiFi connected");

  //fill AWS parameters    
  awsWSclient.setAWSRegion(aws_region);
  awsWSclient.setAWSDomain(aws_endpoint);
  awsWSclient.setAWSKeyID(aws_key);
  awsWSclient.setAWSSecretKey(aws_secret);
  awsWSclient.setUseSSL(true);

  if (connect ()){
    subscribe ();
  }  

  // Ready to send IR code
  irsend.begin();
  Serial.begin (kBaudRate, SERIAL_8N1, SERIAL_TX_ONLY);
}

// The repeating section of the code
//
void loop() {

  //keep the mqtt up and running
  if (awsWSclient.connected ()) {    
      client.loop ();
  } else {
    //handle reconnection
    if (connect ()){
      subscribe ();      
    }
  }
  
  // Check if the IR code has been received.
  if (irrecv.decode(&results)) {
    if (millis()-timeIROutFromESP12E<5000){
      return;
    }
    // Display a crude timestamp.
    uint32_t now = millis();
    Serial.printf("Timestamp : %06u.%03u\n", now / 1000, now % 1000);
    if (results.overflow)
      Serial.printf(
          "WARNING: IR code is too big for buffer (>= %d). "
          "This result shouldn't be trusted until this is resolved. "
          "Edit & increase kCaptureBufferSize.\n",
          kCaptureBufferSize);
    // Display the basic output of what we found.
    Serial.print(resultToHumanReadableBasic(&results));
    dumpACInfo(&results);  // Display any extra A/C info if we have it.
    yield();  // Feed the WDT as the text output can take a while to print.

    // Display the library version the message was captured with.
    Serial.print("Library   : v");
    Serial.println(_IRREMOTEESP8266_VERSION_);
    Serial.println();

    // Output RAW timing info of the result.
    Serial.println(resultToTimingInfo(&results));
    yield();  // Feed the WDT (again)

    // Output the results as source code
    //Serial.println(resultToSourceCode(&results));

    
    String rawString = resultToSourceCode(&results);
    Serial.println(rawString);
    // Get IR code array length
    int squareBracketStart = rawString.indexOf('[');
    int squareBracketEnd = rawString.indexOf(']');
    String codeLength = rawString.substring(squareBracketStart+1,squareBracketEnd);
    Serial.println(codeLength);
    
    // Get IR code as string
    int bracketStart = rawString.indexOf('{');
    int bracketEnd = rawString.indexOf('}');
    String code = rawString.substring(bracketStart+1, bracketEnd);
    code.replace(" ","");
    Serial.println(code);
    code.replace(","," ");
    Serial.println(code);

    // Send IR code string to restful (save IR code to server)
    if(WiFiMulti.run() == WL_CONNECTED){
      
      HTTPClient http;
      http.begin("http://101.132.104.40/data");
      http.addHeader("Content-Type","application/json");
      String payload = "{\"code\":\""+code+"\",\"codeLength\":\""+codeLength+"\"}";
      Serial.println(payload);
      int httpCode = http.POST(payload);
      String result = http.getString();
      Serial.println(result);
    }
    Serial.println("");  // Blank line between entries
    yield();             // Feed the WDT (again)
  }
}

String getValue(String data, char separator, int index)
{
  int found = 0;
  int strIndex[] = {0, -1};
  int maxIndex = data.length()-1;

  for(int i=0; i<=maxIndex && found<=index; i++){
    if(data.charAt(i)==separator || i==maxIndex){
        found++;
        strIndex[0] = strIndex[1]+1;
        strIndex[1] = (i == maxIndex) ? i+1 : i;
    }
  }

  return found>index ? data.substring(strIndex[0], strIndex[1]) : "";
}
