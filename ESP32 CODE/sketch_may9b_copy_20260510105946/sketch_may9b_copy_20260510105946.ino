#include <WiFi.h>
#include <WebServer.h>
#include <EEPROM.h>
#include <Firebase_ESP_Client.h>

// ================= EEPROM =================
#define EEPROM_SIZE 100

String ssid = "";
String password = "";
String deviceId = "";

// ================= FIREBASE =================
#define API_KEY "AIzaSyDHc6pA6rvA6ZyZTjSvTBDzzCd6oHkSVU0"
#define PROJECT_ID "smart-irrigation-acd3e"
#define DATABASE_URL "https://smart-irrigation-acd3e-default-rtdb.firebaseio.com/"


#define USER_EMAIL "davedccalapis@gmail.com"
#define USER_PASSWORD "Wapuchi21calapis"

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// ================= SERVER =================
WebServer server(80);

// ================= PINS =================
#define RELAY_PIN 26
#define SOIL1 34
#define SOIL2 35
#define SOIL3 32
#define SOIL4 33

int dryValue = 3000;

// ================= VARIABLES =================
int s1, s2, s3, s4;
bool pumpState = false;

// ================= EEPROM READ =================
void readCredentials() {
  char ssidArr[33];
  char passArr[33];
  char deviceArr[33];

  for (int i = 0; i < 32; i++) {
    ssidArr[i] = EEPROM.read(i);
    passArr[i] = EEPROM.read(i + 32);
    deviceArr[i] = EEPROM.read(i + 64);
  }

  ssidArr[32] = '\0';
  passArr[32] = '\0';
  deviceArr[32] = '\0';

  ssid = String(ssidArr);
  password = String(passArr);
  deviceId = String(deviceArr);

  ssid.trim();
  password.trim();
  deviceId.trim();

  Serial.println("Loaded:");
  Serial.println("SSID: " + ssid);
  Serial.println("DeviceID: " + deviceId);
}
// ================= EEPROM SAVE =================
void saveCredentials(String newSSID, String newPASS, String newDevice) {
  for (int i = 0; i < 32; i++) {
    EEPROM.write(i, i < newSSID.length() ? newSSID[i] : 0);
    EEPROM.write(i + 32, i < newPASS.length() ? newPASS[i] : 0);
    EEPROM.write(i + 64, i < newDevice.length() ? newDevice[i] : 0);
  }
  EEPROM.commit();
}

// ================= AP MODE =================
void startAP() {

  // IMPORTANT
  WiFi.disconnect(true);
  delay(1000);

  // Set AP mode
  WiFi.mode(WIFI_AP);

  // Start AP with password
  bool apStarted = WiFi.softAP(
    "Irrigation_Setup",
    "12345678"
  );

  if(apStarted){
    Serial.println("AP Started");
    Serial.print("AP IP: ");
    Serial.println(WiFi.softAPIP());
  } else {
    Serial.println("AP Failed!");
  }

  server.on("/setup", []() {

    if (server.hasArg("ssid") &&
        server.hasArg("pass") &&
        server.hasArg("device")) {

      String newSSID = server.arg("ssid");
      String newPASS = server.arg("pass");
      String newDevice = server.arg("device");

      saveCredentials(newSSID, newPASS, newDevice);

      server.send(200, "text/plain", "Saved! Restarting...");

      delay(2000);
      ESP.restart();

    } else {
      server.send(400, "text/plain", "Missing parameters");
    }
  });

  server.begin();

  Serial.println("Server Started");
}

// ================= WIFI =================
bool connectWiFi() {
  WiFi.begin(ssid.c_str(), password.c_str());

  Serial.print("Connecting to WiFi");

  for (int i = 0; i < 20; i++) {
    if (WiFi.status() == WL_CONNECTED) {
      Serial.println("\nConnected!");
      Serial.println(WiFi.localIP());
      return true;
    }
    delay(500);
    Serial.print(".");
  }
  return false;
}
// TOKENSTATUS
void tokenStatusCallback(TokenInfo info) {

  Serial.print("Token Status: ");

  switch (info.status) {
    case token_status_uninitialized:
      Serial.println("Uninitialized");
      break;

    case token_status_on_signing:
      Serial.println("Signing in...");
      break;

    case token_status_on_request:
      Serial.println("Token request in progress");
      break;

    case token_status_on_refresh:
      Serial.println("Token refreshing");
      break;

    case token_status_ready:
      Serial.println("Ready");
      break;

    case token_status_error:
      Serial.println("Token error");
      Serial.println(info.error.message.c_str());
      break;
  }
}

// ================= FIREBASE =================
void initFirebase() {

  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;

  config.token_status_callback = tokenStatusCallback;

  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  Serial.println("Connecting to Firebase...");

  while (!Firebase.ready()) {
    Serial.print(".");
    delay(500);
  }

  Serial.println("\nFirebase Ready!");
}

// ================= SENSOR =================
void readSoil() {
   s1 = analogRead(SOIL1);
   Serial.print("Soil Value: ");
    Serial.println(s1);
  // s2 = analogRead(SOIL2);
  // s3 = analogRead(SOIL3);
  // s4 = analogRead(SOIL4);
}

// ================= PUMP CONTROL =================
void controlPump() {

  int ON_THRESHOLD = 2800;
  int OFF_THRESHOLD = 2200;

  // Turn ON when dry
  if (s1 > ON_THRESHOLD) {
    digitalWrite(RELAY_PIN, HIGH);

    Serial.println("Pump ON");
  }

  // Turn OFF when wet
  if (s1 < OFF_THRESHOLD) {
    digitalWrite(RELAY_PIN, LOW);

    Serial.println("Pump OFF");
  }
}

// ================= SEND TO FIRESTORE =================
void sendToFirestore() {

  if (!Firebase.ready()) {
    Serial.println("Firebase not ready");
    return;
  }

  if (deviceId == "") return;

  float moisture = (1.0 - (s1 / 4095.0)) * 100.0;
  String status = (digitalRead(RELAY_PIN) == LOW) ? "ON" : "OFF";

  FirebaseJson content;

  content.set("fields/deviceId/stringValue", deviceId);
  content.set("fields/moisture/doubleValue", moisture);
  content.set("fields/status/stringValue", status);

  String documentPath = "zones/" + deviceId;

  Serial.println("Sending to Firestore...");

  bool success = Firebase.Firestore.patchDocument(
    &fbdo,
    PROJECT_ID,
    "",
    documentPath.c_str(),
    content.raw(),
    "deviceId,moisture,status"
  );

  if (success) {
    Serial.println("Firestore Updated Successfully");
    Serial.println(fbdo.payload());   // 🔥 ADD THIS
  }
  else {
    Serial.println("Firestore FAILED:");
    Serial.println(fbdo.errorReason());
  }
}
// ================= SETUP =================
void setup() {
  Serial.begin(115200);

  EEPROM.begin(EEPROM_SIZE);

  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, HIGH);

  readCredentials();

  if (ssid == "" || deviceId == "" || !connectWiFi()) {
    startAP();
  } else {
    initFirebase();
  }
}

// ================= LOOP =================
void loop() {

  if (WiFi.status() != WL_CONNECTED) {
    server.handleClient();
    return;
  }

  readSoil();
  controlPump();
  sendToFirestore();

  delay(5000);
}
