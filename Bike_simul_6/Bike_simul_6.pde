import processing.serial.*;   // library for serial communication
Serial port;
boolean first_stage = true;//viene comunque resetata dopo un timeout di 3 secondi
boolean connected = false;
char c;
int m;
int last_m;
boolean state_w;
boolean last_state_w;
String cmd;
int angp_p_step = 0;
int angp_p_step_prev = 0;

float angolo_ruota;
float last_angolo_ruota = 0;
float angolo_pedale;
float last_angolo_pedale = 0;
float angolo;

// dynamic system parameters, constants
float M = 90.0;        // mass of rider + bike
float r = 0.3556;      // wheel radius in m, for 28" wheel
float Cw = 0.9;        // aerodynamic drag coefficient
float Crr = 0.003;     // rolling resistance coefficient
float As = 0.4;        // reference area of bicycle-rider system
float rhoair = 1.225;  // air density
float g = 9.81;        // gravitational acceleration

// dynamic system variables
float angm_wh = 0;     // dot omega on wheel [rad/sec2]
float angv_wh = 0;     // omega on wheel [rad/sec]
float angp_wh = 0;     // beta, angular position of the wheel [rad]

float angv_p_req = 0;  // requested angular velocity of pedals [rad/sec]
float angv_p_max = 0;  // max angular velocity of pedals [rad/sec] at given angular velocity of wheel and gear ratio
float angv_p = 0;      // omegap, angular velocity of pedals [rad/sec]
float angp_p = 0;      // gamma, angular position of the pedals [rad]

float alpha = 0;       // slope of the road [rad]

float cm;
float cp;
float cv;
float ca;

float Tmot = 0;//30.0;     // torque of the motor on wheel system
float reqTmot = 0;//0.0 - 100.0;     //(requestTmot) torque of the motor on wheel system requested by external device
float Tped = 0;            // torque of the rider on pedal system [2 Nm, 10-15 Nm, 75 Nm]

float n = 1.0;             // gear ratio
float Nped = 32.0;         // teeth in pedal gear
int Nwh[] = {32, 25, 21, 18, 15, 12};           // teeth in wheel gear
int gear_idx = 0;          // index of current wheel gear

float req_cadence = 0;     // RPM [deriving from graphic interface]
float tension_cadence = 0; // RPM [used in graphic interface]

boolean tension = false;


float linear_speed = 0;
float linear_distance = 0;

int now, update_ts;
float delta_t;

int slope_percent = 0;     // alpha, expressed in % (PI/4 = 100%)



//test acc and brake
boolean accel = false;
boolean brake = false;

boolean draw_dbg_data;

PFont font12;
PFont font24;

PImage landscapeImg;
PImage roadImg;
PImage wheelImg;
PImage pedalsImg;
PImage cadenceImg;
PImage cogs[];
PImage arrowsImg;
PImage slopeImg;

color bg_color_ctrls;
color bg_road;

int windowX = 720;
int windowY = 630;

int cadenceX = 360;
int cadenceY = 640;
int cadenceW = 240;
int cadenceH = 30;
int cadence_delta = 0;
color max_cadence_col;

int bmX = 200; //rect(200, 640, 100, 32, 5);
int bY = 640;
int mY = 720;
int bmW = 100;
int bmH = 32;


void update_slope(int percent_variation){
  slope_percent += percent_variation;
  if(slope_percent > 20) slope_percent = 20;
  if(slope_percent < -20) slope_percent = -20;
  alpha = atan(slope_percent/100.0);
  println("slope_percent = "+slope_percent+"%");
  ca = (g/r)*(sin(alpha) + Crr * cos(alpha));
}

void update_gear(int changegear){
  gear_idx += changegear;
  if(gear_idx > 5) gear_idx = 5;
  if(gear_idx < 0) gear_idx = 0;
  n = ((float)Nwh[gear_idx] / Nped);
  cp = n / (M * r * r);
  //TODO send gear code over serial...
  if(connected == true) {
    //println((gear_idx+1)+'0');
    port.write((gear_idx+1)+'0');
  }
}

void setup() {
  
  // coefficients computation
  cm = 1.0 / (M * r * r);
  update_gear(0); // updates cp
  cv = (As * Cw * rhoair * r) / (2 * M);
  update_slope(0); // updates ca
  
  size(1024, 768, P3D);
  background(255);
  frameRate(100);
  
  font12 = createFont("Arial Bold", 12);
  font24 = createFont("Arial Bold", 24);
  textFont(font12);
  text("word", 10, 50);
 
  wheelImg = loadImage("Ruota_e_pignoni_355.png");
  landscapeImg = loadImage("Landscape.png");
  roadImg = loadImage("Strada.png");
  pedalsImg = loadImage("Corona_pedale.png");
  cadenceImg = loadImage("Cadence_2.png");
  cogs = new PImage[6];
  for(int j=0;j<6;j++)
    cogs[j]= loadImage("Cog_grey_G"+(j+1)+".png");
  arrowsImg = loadImage("arrow-keys.png");
  slopeImg = loadImage("slope_bike2.png");
  
  draw_dbg_data = true;
  bg_color_ctrls = color(200,200,220);
  bg_road = color(178);
  
  // here we want to connect to board, max 3 seconds
  
  now = millis();
  background(bg_road);
  fill(0);
  textFont(font24);
  text("Connecting...", 100, 400);
  
  //port = new Serial(this, Serial.list()[0],115200);  // use the first port in the list
  port = new Serial(this, "COM3",115200);  // use a fixed port
  //delay(1000);    //on connection a reset is done, so wait a little for the board to start
  //MOD: the delay for connection will be managed in draw with first_stage variable

  //start with an initial speed for test...
  angv_wh = 6.0;
  now = millis();
  update_ts = now;
  last_state_w = false;
  
}


 
void draw() {
 
  background(bg_road);
  
  // check if it is time to wait for connection or not...
  if(first_stage==true){
    if((connected == false) && (millis() < now + 3000)){
      if(port.available() > 0){
        c = (char) port.read();
        if(c=='h'){
          connected = true;
          port.write('H');
        }
      }
      text("Connecting...", 100, 400);
    } 
    else first_stage = false;
    update_ts = millis();  // needed for next delta_t
    return; //quit from "this" draw cycle
  }
  
  //controllo per i rapporti e assistenza motore
  if((connected == true) && (port.available() > 0)){
    m = (char) port.read();
    println(m);
    //println((m-'0')-gear_idx-1);
    if(m!=last_m){
      //println(m);
      if((m>='1') && (m<='6')){
        //println((m-'0')-gear_idx-1);
        update_gear((m-'0')-gear_idx-1);
        last_m = m;
      }
    
      else if((m>='a') && (m<='f')){
        //println("motore"+m);
        reqTmot=(m-97)*20;  //nM
        //println(Tmot);
      }
    }
  }  
  
  // **********************************
  // checking inputs and interactions
  // other will be managed directly in keyboard or mouse callbacks
  // **********************************
  
  accel = false;
  brake = false;
  req_cadence = 0;
  
  if (mousePressed == true){
    if((mouseX > bmX) && (mouseX < bmX+bmW)){
      if((mouseY > mY) && (mouseY < mY+bmH)){//pressed on accel
        accel = true;        
      } else if((mouseY > bY) && (mouseY < bY+bmH)){//pressed on brake
        brake = true;        
      }
    } else {
      accel = false;
      brake = false;
    }
    
    if((mouseX >= cadenceX) && (mouseX < cadenceX+cadenceW) && (mouseY >= cadenceY) && (mouseY < cadenceY+cadenceH)){
      req_cadence = (mouseX - cadenceX)/2.0;
    } else {
      req_cadence = 0;
    }
    
  }
  
  
  
  // **********************************
  // applying inputs to sys vars
  // **********************************
  
  if(accel == true){
    Tmot = 50;
  } else if(brake == true){
    Tmot = -400;
  } else {
     Tmot = reqTmot; //Tmot = 0;
  }
  
  angv_p_req = req_cadence*PI/30;
  angv_p_max = angv_wh * n;
  tension_cadence = angv_p_max*30/PI;
  
  // set a Tped proportional to (angv_p_req - angv_p)
  if(angv_p_req < angv_p_max){
    tension = false;
    angv_p = angv_p_req;
    Tped = 0;
  } else {
    tension = true;
    angv_p = angv_p_max;
    // simple function, proportional to difference
    Tped = (angv_p_req - angv_p)*30*100/(120*PI);
  }
  
  
  // **********************************
  // cinematic updates
  // **********************************
  
  now = millis();
  delta_t = (now - update_ts) / 1000.0;
  update_ts = now;
  
  //main dynamic equation
  angm_wh = cm*Tmot + cp*Tped - cv*(angv_wh*angv_wh) - ca;
  
  angv_wh += angm_wh * delta_t;
  if(angv_wh < 0) angv_wh = 0;
  angp_wh += angv_wh * delta_t;  
  
  //example, converting sys params
  //velocità bici [km/h] = (rad_per_sec / 2PI) * r * 2PI  * 3600 / 1000
  linear_speed = angv_wh * r * 3.6;
  
  linear_distance += angv_wh * r * delta_t;
  
  // angv_p is angv_p_req or angv_p_max
  angp_p += angv_p * delta_t;
  


  //if connection is present send pulses
  if(connected == true){
    // check angolo ruota
    angolo_ruota = angp_wh%(2 * PI);
    if ((angolo_ruota >= 0) && (angolo_ruota < PI)) state_w = true;
    else state_w = false;
    
    if((last_state_w == true) && (state_w == false)) port.write("w");
    last_state_w = state_w;
    
    angp_p_step = (int)(12*((angp_p/(2*PI)) - (int)(angp_p/(2*PI))));
    if(angp_p_step != angp_p_step_prev){
      //println(angp_p_step);
      port.write("p");
      angp_p_step_prev = angp_p_step;
    }
  }
  
  
  
  // **********************************
  // moving and rotating graphics
  // **********************************
  
  imageMode(CORNER);
  //moving landscape
  image(landscapeImg, -((linear_distance*4)%2000), 0);
  
  pushMatrix();
    translate(width/2, height/2, 0);
    imageMode(CENTER);
    //apply alpha to following items
    rotateZ(-alpha);
    //moving road
    image(roadImg, 768-((linear_distance*50)%1050), 80);
    
    translate(-width/4, 0, 0);
    
    pushMatrix();
      // rotating wheel 
      rotateZ(angp_wh);
      imageMode(CENTER);
      image(wheelImg, 0, 0);
    popMatrix();      
    
    translate(230, 20, 0);
    
    pushMatrix();
      // rotating pedals 
      rotateZ(angp_p);
      imageMode(CENTER);
      image(pedalsImg, 6, 6);
    popMatrix();  
  
  popMatrix();
    
  
  
  
  // **********************************
  // filling background for controls and messages
  // **********************************
  
  stroke(bg_color_ctrls);
  strokeWeight(10);
  noFill();
  rect(0, 0, windowX, windowY);
  strokeWeight(1);
  fill(bg_color_ctrls);
  rect(windowX, 0, width-windowX, windowY);
  rect(0, windowY, width, height-windowY);
  stroke(0);
  noFill();
  rect(5, 5, windowX-10, windowY-10);
  
  
  
  // **********************************
  // controls and messages
  // **********************************
  
  if(draw_dbg_data == true){
    //stroke(0);
    //strokeWeight(20);
    fill(0);
    rect(windowX-120, 20, 100, 100, 20);
    textSize(12);
    fill(color(255,255,255, 220));
    text(String.format("fr = %.2f",frameRate), windowX-110, 40);
    //mouse pos, useful at graphics design time
    text(String.format("X = %d",mouseX), windowX-110, 60);
    text(String.format("Y = %d",mouseY), windowX-110, 80);
    //requested cadence
    text(String.format("rc = %.1f",req_cadence), windowX-110, 100);
  }
  
  //drawing gears
  imageMode(CORNER);
  image(cogs[gear_idx], 10, 530);
  
  //drawing slope icon
  image(slopeImg, 600, 510);
  textFont(font24);
  fill(bg_road); 
  text(""+slope_percent+"%", 635, 600);
  
  //drawing arrow-keys
  imageMode(CORNER);
  image(arrowsImg, 30, 640);
  
  //drawing cadence ctrl
  imageMode(CORNER);
  image(cadenceImg, cadenceX, cadenceY);
  cadence_delta = (int)tension_cadence*2;
  if(cadence_delta > cadenceW){
    cadence_delta = cadenceW;
    max_cadence_col = color(255,0,0);
  } else {
    max_cadence_col = color(0,0,255);
  }
    
  stroke(max_cadence_col); 
  strokeWeight(3);
  line(cadenceX+cadence_delta, cadenceY-5, cadenceX+cadence_delta, cadenceY+cadenceH+5);
  stroke(0); //black
  strokeWeight(1);
  //textSize(12);
  textFont(font12);
  fill(color(0,0,0, 220));
  for(int i=10; i<120; i+=20){
    text(""+i, cadenceX+2*i-7, cadenceY+20);
  }
  
  
  
  textFont(font24);
  //textAlign(LEFT, CENTER);
  //drawing fixed test graphics for accel and brake
  strokeWeight(1);
  fill(color(0,0,0, 220));
  text("Motor ", bmX+8, mY+bmH-8);
  fill(color(100,100,255, 180));
  rect(bmX, mY, bmW, bmH, 5);
  
  fill(color(0,0,0, 220));
  text("Brake ", bmX+8, bY+bmH-8);
  fill(color(255,180,180, 180));
  rect(bmX, bY, bmW, bmH, 5);
  
  fill(color(255,0,0, 220));
  if(accel == true){
    circle(bmX+85, mY+bmH/2, 10);
  } else if(brake == true){
    circle(bmX+85, bY+bmH/2, 10);
  }



  
  

  
  //drawing fixed graphics for system variables
  
  textSize(24);
  fill(color(0,0,0, 220));
  
  
  
  text(String.format("speed: wheel = %.2f rad/s   lin = %.2f km/h", angv_wh, linear_speed), 10, 30);
  text("torque = " + Tmot , 10, 50);
  
  
  ////tip text on the bottom
  //text("click col mouse su accel o brake ", 10, 700);
  //text("premi barra_spazio per cambiare vista ", 10, 740);
  

  

  
}


void keyPressed() {
  if (key == CODED) {
    if (keyCode == UP) {
      println("UP");
      update_slope(1);
    } else if (keyCode == DOWN) {
      println("DOWN");
      update_slope(-1);
    } else if (keyCode == LEFT) {
      update_gear(-1);
    } else if (keyCode == RIGHT) {
      update_gear(1);
    } 
    
  } else {
    println("keyCode="+keyCode);
    if (keyCode == 77){
      println("millis="+millis());
    } else if (keyCode == 32){
      draw_dbg_data = !draw_dbg_data;        
    }
  }
  
}
