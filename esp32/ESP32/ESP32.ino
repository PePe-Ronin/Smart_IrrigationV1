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

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// ================= SERVER =================
WebServer server(80);

// ================= PINS =================
#define RELAY_PIN 13
#define SOIL1 34
#define SOIL2 35
#define SOIL3 32
#define SOIL4 33

int threshold = 2500;

// ================= VARIABLES =================
int s1, s2, s3, s4;
bool pumpState = false;

// ================= EEPROM READ =================
void readCredentials() {
  char ssidArr[32];
  char passArr[32];
  char deviceArr[32];

  for (int i = 0; i < 32; i++) {
    ssidArr[i] = EEPROM.read(i);
    passArr[i] = EEPROM.read(i + 32);
    deviceArr[i] = EEPROM.read(i + 64);
  }

  ssid = String(ssidArr);
  password = String(passArr);
  deviceId = String(deviceArr);

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
  WiFi.softAP("Irrigation_Setup");
  Serial.println("AP Mode Started");

  server.on("/setup", []() {
    if (server.hasArg("ssid") && server.hasArg("pass") && server.hasArg("device")) {

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

// ================= FIREBASE =================
void initFirebase() {
  config.api_key = API_KEY;
  config.project_id = PROJECT_ID;

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
}

// ================= SENSOR =================
void readSoil() {
  s1 = analogRead(SOIL1);
  s2 = analogRead(SOIL2);
  s3 = analogRead(SOIL3);
  s4 = analogRead(SOIL4);
}

// ================= PUMP CONTROL =================
void controlPump() {
  if (s1 > threshold || s2 > threshold || s3 > threshold || s4 > threshold) {
    digitalWrite(RELAY_PIN, LOW); // ON
    pumpState = true;
  } else {
    digitalWrite(RELAY_PIN, HIGH); // OFF
    pumpState = false;
  }
}

// ================= SEND TO FIRESTORE =================
void sendToFirestore() {

  if (deviceId == "") {
    Serial.println("No deviceId set!");
    return;
  }

  float avg = (s1 + s2 + s3 + s4) / 4.0;
  float moisture = 1.0 - (avg / 4095.0);

  String json = "{ \"fields\": {";
  json += "\"moisture\": {\"doubleValue\": " + String(moisture) + "},";
  json += "\"status\": {\"stringValue\": \"Connected\"}";
  json += "}}";

  String path = "zones/" + deviceId;

  if (Firebase.Firestore.patchDocument(
        &fbdo,
        PROJECT_ID,
        "",
        path.c_str(),
        json.c_str(),
        "moisture,status")) {

    Serial.println("Updated Firestore: " + path);
  } else {
    Serial.println("Error:");
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
