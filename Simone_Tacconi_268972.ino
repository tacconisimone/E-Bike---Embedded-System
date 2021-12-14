// SIMONE TACCONI 268972
//definizione dei segnali
#define LED_PIN_Y 9
#define LED_PIN_B 10
#define LED_PIN_R 6
#define BOTTON_PLUS 2
#define BOTTON_MINUS 3
//definizione degli stati
#define NO_ASS 0
#define ASS_20 1
#define ASS_40 2
#define ASS_60 3
#define ASS_80 4
#define ASS_100 5


boolean pausa=false;
int livello_assistenza=0;
int last_livello_assistenza;
boolean cambio_assistenza_botton=false;
int last_button_State_Plus = LOW;
int last_button_State_Minus = LOW;
unsigned long inizioMillis;
unsigned long currentMillis;

float circ_W = 2.234300695;
float vel_W;

float last_vel_W=0;
float accellerazione_W=0;
unsigned long tempo_acc;
unsigned long last_tempo_acc;
int denti_pignone[]{32,25, 21, 18, 15, 12};
int pignone_corrente;
int pignone_corona=32;
bool pedalo;
bool in_tensione;
int last_m;

float gir_min_p;
float gir_min_w;
unsigned long tempo_impulso_ruota;
unsigned long precedente_impulso_ruota;
unsigned long delta_impulso_ruota;
unsigned long tempo_impulso_pedale;
unsigned long precedente_impulso_pedale;
unsigned long delta_impulso_pedale;

unsigned long ritardo_invio_a_no_ass;

bool connected_to_processing = false;
char c;
int m;
void setup() {
  // put your setup code here, to run once:
  Serial.begin(115200);
  while(!Serial);  //serve se si usa un uC con USB integrato

  pinMode(LED_PIN_Y, OUTPUT);
  pinMode(LED_PIN_B, OUTPUT);
  pinMode(LED_PIN_R, OUTPUT);
  pinMode(BOTTON_PLUS, INPUT);
  pinMode(BOTTON_MINUS, INPUT);
  digitalWrite(LED_PIN_Y, LOW);
  digitalWrite(LED_PIN_B, LOW);
  digitalWrite(LED_PIN_R, LOW);
  
  while(!connected_to_processing){
    if(Serial.available()>0){
      c = Serial.read();
      if(c=='H') connected_to_processing = true;
    } else {
      Serial.write('h');
      delay(100);
    }
  }
  precedente_impulso_ruota=millis();
  precedente_impulso_pedale=millis();
  last_tempo_acc=millis();
  
  ritardo_invio_a_no_ass=millis();
  pedalo=false;
  in_tensione=false;
  m = 1;
}

void loop() {
  // put your main code here, to run repeatedly:
  int button_State_Plus = digitalRead(BOTTON_PLUS);
  int button_State_Minus = digitalRead(BOTTON_MINUS);
  
  if(button_State_Minus != last_button_State_Minus && button_State_Minus == HIGH){
    last_button_State_Minus=button_State_Minus;
    if(livello_assistenza>=1) {   
      cambio_assistenza_botton=true;
      --livello_assistenza;
    }
  }
  if(button_State_Plus != last_button_State_Plus && button_State_Plus == HIGH){
    last_button_State_Plus=button_State_Plus;
    if(livello_assistenza<=4) {
      cambio_assistenza_botton=true;
      ++livello_assistenza;
    }
  }

  if((gir_min_p*pignone_corona)>(99*(gir_min_w*pignone_corrente)/100)) pedalo=true;
    else pedalo=false;

  if((accellerazione_W>0) && (pedalo==true)) in_tensione=true;
    else in_tensione=false;

  
  if((vel_W>=livello_assistenza*5)||(in_tensione==false)){
      pausa=true;
    }
  else if((vel_W<livello_assistenza*5) && (in_tensione==true)) pausa=false;
///* ci deve stare per forza altrimenti rimane bloccato sull'ultimo stato
  if(pausa==true){
    if(millis()>=ritardo_invio_a_no_ass + 500){
      Serial.write('a');
      digitalWrite(LED_PIN_Y, LOW);
      ritardo_invio_a_no_ass=millis();
    }
  }
//   */
  
  if((cambio_assistenza_botton==true) || (pausa==false)){
    switch(livello_assistenza){
      case NO_ASS:
        pausa=false;
        cambio_assistenza_botton=false;
        if(millis()>=ritardo_invio_a_no_ass + 500){
          Serial.write('a');
          //Serial.write('vel_W');
          //Serial.write('livello_assistenza');
          digitalWrite(LED_PIN_Y, LOW);
          ritardo_invio_a_no_ass=millis();
        }
        break;

      case ASS_20:
        if((vel_W<5) && (in_tensione==true)){
          pausa=false;
          cambio_assistenza_botton=false;
          Serial.write('b');
          //Serial.write('vel_W');
          //Serial.write('livello_assistenza');
          digitalWrite(LED_PIN_Y, HIGH);
        }
        else{
          pausa=true;
          if(millis()>=ritardo_invio_a_no_ass + 500){
            Serial.write('a');
            digitalWrite(LED_PIN_Y, LOW);
            ritardo_invio_a_no_ass=millis();
             }
          }
        break;

      case ASS_40:
        if((vel_W<10) && (in_tensione==true)){
          pausa=false;
          cambio_assistenza_botton=false;
          Serial.write('c');
          //Serial.write('vel_W');
          //Serial.write('livello_assistenza');
          digitalWrite(LED_PIN_Y, HIGH);
        }
        else{
          pausa=true;
          if(millis()>=ritardo_invio_a_no_ass + 500){
            Serial.write('a');
            digitalWrite(LED_PIN_Y, LOW);
            ritardo_invio_a_no_ass=millis();
             }
          }
        break;

      case ASS_60:
        if((vel_W<15) && (in_tensione==true)){
          pausa=false;
          cambio_assistenza_botton=false;
          Serial.write('d');
          //Serial.write('vel_W');
          //Serial.write('livello_assistenza');
          digitalWrite(LED_PIN_Y, HIGH);
        }
        else{
          pausa=true;
          if(millis()>=ritardo_invio_a_no_ass + 500){
            Serial.write('a');
            digitalWrite(LED_PIN_Y, LOW);
            ritardo_invio_a_no_ass=millis();
             }
          }
        break;

      case ASS_80:
        if((vel_W<20) && (in_tensione==true)){
          pausa=false;
          cambio_assistenza_botton=false;
          Serial.write('e');
          //Serial.write('vel_W');
          //Serial.write('livello_assistenza');
          digitalWrite(LED_PIN_Y, HIGH);
        }
        else{
          pausa=true;
          if(millis()>=ritardo_invio_a_no_ass + 500){
            Serial.write('a');
            digitalWrite(LED_PIN_Y, LOW);
            ritardo_invio_a_no_ass=millis();
             }
          }
        break;

      case ASS_100:
        if((vel_W<25) && (in_tensione==true)){
          pausa=false;
          cambio_assistenza_botton=false;
          Serial.write('f');
          //Serial.write('vel_W');
          //Serial.write('livello_assistenza');
          digitalWrite(LED_PIN_Y, HIGH);
        }
        else{
          pausa=true;
          if(millis()>=ritardo_invio_a_no_ass + 500){
            Serial.write('a');
            digitalWrite(LED_PIN_Y, LOW);
            ritardo_invio_a_no_ass=millis();
             }
          }
        break;
        
    }
  }


  if(Serial.available()>0){
    c = Serial.read();
    switch(c){
      case 'w':
        precedente_impulso_ruota = tempo_impulso_ruota;
        tempo_impulso_ruota=millis();
        delta_impulso_ruota=tempo_impulso_ruota - precedente_impulso_ruota;
        digitalWrite(LED_PIN_B, HIGH);
        break;
      case 'p':
        precedente_impulso_pedale = tempo_impulso_pedale;
        tempo_impulso_pedale=millis();
        delta_impulso_pedale=tempo_impulso_pedale - precedente_impulso_pedale;
        digitalWrite(LED_PIN_R, HIGH);
        break;
      case '1':
        m = 1;
        break;
      case '2':
        m = 2;
        break;
      case '3':
        m = 3;
        break;
      case '4':
        m = 4;
        break;
      case '5':
        m = 5;
        break;
      case '6':
        m = 6;
        break;
    }
  }
  
  pignone_corrente=denti_pignone[m-1];
  
  if((millis()-tempo_impulso_ruota)>(2*delta_impulso_ruota)) {
    vel_W=0;
    gir_min_w=0;
    //accellerazione_W=0;
  }
  else {
    tempo_acc=millis();
    vel_W = (circ_W/((delta_impulso_ruota)*1000))*3.6;
    accellerazione_W=(vel_W - last_vel_W)/(tempo_acc - last_tempo_acc);
    gir_min_w = 60000/delta_impulso_ruota;
    last_vel_W=vel_W;
    last_tempo_acc=tempo_acc;
  }
  
  if((millis()-tempo_impulso_pedale)>(2*delta_impulso_pedale)) gir_min_p=0;
  else gir_min_p = 60000/((delta_impulso_pedale) * 12);
  

  if((gir_min_p>88) && (m<6) && (in_tensione==true) ){
    if(last_m != m){
      Serial.write((m+1)+'0');
      last_m=m;
    }
  }
  if((gir_min_p<30) && (m>1) && (gir_min_p>2) ){              
    if(last_m != m){
      Serial.write((m-1)+'0');
      last_m=m;
    } 
  } 
  
  
  if(millis() >= tempo_impulso_ruota + 50 ){
    digitalWrite(LED_PIN_B, LOW);
  }
  if(millis() >= tempo_impulso_pedale + 20 ){
    digitalWrite(LED_PIN_R, LOW);
  }

}
