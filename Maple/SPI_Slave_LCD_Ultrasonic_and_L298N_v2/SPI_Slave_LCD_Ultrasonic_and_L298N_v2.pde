#include <LiquidCrystal.h>
#include <string.h>
#include "spi.h"

// initialize the library with the numbers of the interface pins
LiquidCrystal lcd(20, 21, 28, 29, 30, 31);

// LCD Backlight
#define BKL_PIN 16

// Motor Stuff (L298N)
#define EN1 11
#define EN2 10
#define IN1 12
#define IN2 13
#define IN3 14
#define IN4 2

unsigned long motortime = 0;
#define MOTOR_TIMEOUT 500

#define STOP         0x00
#define MOT_FORWARD  0x01
#define MOT_BACKWARD 0x02
#define MOT_LEFT     0x03
#define MOT_RIGHT    0x04

void MotorDirection(int dirl, int dirr) {
  if (dirl == MOT_FORWARD) {
    digitalWrite(IN1, HIGH);
    digitalWrite(IN2, LOW);
  } 
  else if (dirl == MOT_BACKWARD) {
    digitalWrite(IN1, LOW);
    digitalWrite(IN2, HIGH);
  } 
  else {
    digitalWrite(IN1, LOW);
    digitalWrite(IN2, LOW);
  }
  if (dirr == MOT_FORWARD) {
    digitalWrite(IN3, HIGH);
    digitalWrite(IN4, LOW);
  } 
  else if (dirr == MOT_BACKWARD) {
    digitalWrite(IN3, LOW);
    digitalWrite(IN4, HIGH);
  } 
  else {
    digitalWrite(IN3, LOW);
    digitalWrite(IN4, LOW);
  }
}

void setMotors(int dir) {
  if (dir == MOT_FORWARD) {
    MotorDirection(MOT_FORWARD, MOT_FORWARD);
  } 
  else if (dir == MOT_BACKWARD) {
    MotorDirection(MOT_BACKWARD, MOT_BACKWARD);
  } 
  else if (dir == MOT_LEFT) {
    MotorDirection(MOT_BACKWARD, MOT_FORWARD);
  } 
  else if (dir == MOT_RIGHT) {
    MotorDirection(MOT_FORWARD, MOT_BACKWARD);
  } 
  else {
    MotorDirection(STOP, STOP);
  }
}

void enableMotors(bool state) {
  if (state == true) {
    digitalWrite(EN1, HIGH);
    digitalWrite(EN2, HIGH);
  } 
  else {
    digitalWrite(EN1, LOW);
    digitalWrite(EN2, LOW);
  }
}

// Ultrasonics
#define TRIG 22
#define ECHO 27
#define UA0  17
#define UA1  18
#define UA2  19

volatile bool newval=false;
volatile bool timeout=false;
volatile uint16 value=0;
bool measure = false;
bool measuring = false;

HardwareTimer timer1(1);

void initRXTX() {
  setInputCapture(TIMER1);
}

void setInputCapture(timer_dev *dev) {
  timer_attach_interrupt(dev, TIMER_UPDATE_INTERRUPT,handler_timeout);
  timer_attach_interrupt(dev, TIMER_CC2_INTERRUPT,handler_pulsewidth);
  dev->regs.gen->CR1=0x00000000;
  dev->regs.gen->PSC=72;  //(PSC needs to be set as well)
  dev->regs.gen->CCMR1=0x00000201;
  dev->regs.gen->SMCR=0x00000054;  
  dev->regs.gen->CCER=0x00000031;
  //dev->regs.gen->DIER=0x00000003;
  dev->regs.gen->CR1=0x00000005;
}

void handler_timeout() {
  // Timeout.
  value = (uint16)0xFFFF;
  newval = true;
  timeout = true;
}
 
void handler_pulsewidth() {
  // Pulsewidth.
  value = (uint16)TIMER1->regs.adv->CCR2;
  newval = true;
}

// Slave Device
// Commands
#define LCD_BYTE 0x3F // Write message to LCD
#define BKL_BYTE 0x40 // Backlight setting
#define TMP_BYTE 0x41 // Write a temporary message to the LCD
#define IP_BYTE	 0x51 // Receive IP string!
#define MOT_BYTE 0x15 // Motor Controller
#define SEN_BYTE 0x26 // Ultrasonic Sensor Interaction
#define RET_BYTE 0x6A

HardwareSPI spi(1);

//SPI States
#define IDLE    0
#define LCDDATA 1
#define BKLDATA 2
#define MOTDATA 3
#define IPDATA  4
#define TEMPMSG 5
#define SENDATA 6

#define SEN_GETMASK  0x80

char state = IDLE;
char spitriggers = 0;
char extitriggers = 0;
bool printed = true;
bool tmpprinted = true;
bool motorcmd = true;
bool ipupdate = false;

char buf[66];
char ip[4][4] = {{ 0x00 }};
char msg[40];
char mot[4];
unsigned int pointer = 0;

void clearips (void) {
  for (int j=0;j<4;j++) {
    for (int i=0;i<4;i++) {
      ip[j][i] = 0x00;
    }
  }
}

void readips (void) {
  int i=0;
  int j=0;
  int k=0;
  while(buf[k] != 0x00) {
    if(buf[k] == ' ') {
      j++;
      i=0;
    } 
    else if (buf[k] == '.') {
      i++;
    } 
    else {
      ip[j][i] = (ip[j][i]*10) + (buf[k] - '0');
    }
    k++;
    if (k > 66)
      break;
  }
}

extern "C" {
  void __irq_spi1(void) {
    uint32 status = SPI1_BASE->SR;
    spitriggers++;
    if ((status & SPI_SR_RXNE) != 0) {
      if (state == IDLE) {
        byte command = spi.read();
        digitalWrite(BOARD_LED_PIN, HIGH);
        if (command == LCD_BYTE) {
          state = LCDDATA;
        } else if (command == BKL_BYTE) {
          state = BKLDATA;
        } else if (command == MOT_BYTE) {
          state = MOTDATA;
        } else if (command == IP_BYTE) {
          state = IPDATA;
        } else if (command == SEN_BYTE) {
          state = SENDATA;
        } else if (command == TMP_BYTE) {
          state = TEMPMSG;
        } else {
          digitalWrite(BOARD_LED_PIN, LOW);
        }
      } else if (state == LCDDATA) {
        msg[pointer++] = spi.read();
      } else if (state == BKLDATA) {
        pwmWrite(BKL_PIN,spi.read());
      } else if (state == MOTDATA) {
        mot[pointer++] = spi.read();
      } else if (state == IPDATA) {
        buf[pointer++] = spi.read();
      } else if (state == TEMPMSG) {
        buf[pointer++] = spi.read();
      } else if (state == SENDATA) {
        buf[pointer] = spi.read();
        if (buf[pointer]&0x80 != 0) {
          spi.write(0x55);//Grrr
          measure = true;
        }
      }
    }
    SPI1_BASE->SR = 0;
  }
}

void finish(void) {
  if (state == LCDDATA) {
    printed = false;
    msg[pointer++] = 0x00;
  } else if (state == TEMPMSG) {
    tmpprinted = false;
    buf[pointer++] = 0x00;
  } else if (state == MOTDATA) {
    motorcmd = false;
  } else if (state == IPDATA) {
    ipupdate = true;
  }
  state = IDLE;
  pointer = 0;
  extitriggers++;
}

void setup(void) {
  pinMode(BOARD_LED_PIN, OUTPUT);
  digitalWrite(BOARD_LED_PIN, HIGH);
  pinMode(BOARD_BUTTON_PIN, INPUT);
  pinMode(EN1, OUTPUT);
  pinMode(EN2, OUTPUT);
  enableMotors(false);
  pinMode(IN1, OUTPUT);
  pinMode(IN2, OUTPUT);
  pinMode(IN3, OUTPUT);
  pinMode(IN4, OUTPUT);
  pinMode(TRIG, OUTPUT);
  pinMode(ECHO, INPUT_PULLDOWN);
  digitalWrite(TRIG, LOW);
  setInputCapture(TIMER1);
  setMotors(STOP);
  spi.beginSlave(MSBFIRST, 0);
  pinMode(BOARD_SPI1_NSS_PIN, INPUT_PULLUP);
  pinMode(BOARD_SPI1_SCK_PIN, INPUT_PULLDOWN);
  //pinMode(BOARD_SPI1_MOSI_PIN, INPUT_PULLDOWN);
  spi_irq_enable(SPI1 ,SPI_RXNE_INTERRUPT);
  attachInterrupt(BOARD_SPI1_NSS_PIN, finish ,RISING);
  pinMode(BKL_PIN, PWM);
  pwmWrite(BKL_PIN,0);
  lcd.begin(16, 2);
  lcd.clear();
  lcd.print("Waiting...");
  strcpy(msg,"Waiting...");
}

// LCD Scrolling
unsigned int scroll = 0;
unsigned long scrolltime = 0;
bool scrolllog = false;
#define SCROLL_TIME 750
// LCD states
#define LCD_NORMAL	0
#define LCD_DEBUG	1
#define LCD_IP		2
#define LCD_TMP         3
#define LCD_REFRESH 1000
unsigned long lcdtime = 0;
int curip=0;
char LCDstate = LCD_NORMAL;
// Button Pressing
#define BUTTON_COUNTDOWN 5000
#define BUTTON_PRESS 100
unsigned long buttontime = 0;
unsigned long lastbuttime = 0;
bool buttonactive=false;
unsigned long lastmeasure = 0;
unsigned short ultratime = 0;
// Temp Display Messages
#define TMPMSG_DISTIME 5000
unsigned long tmpmsgtime = 0;
bool tmpactive = false;


void loop(void) {
  if (LCDstate == LCD_NORMAL) {
    if ((printed == false) && (state == IDLE)) {
      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.print(msg);
      scroll = 1;
      scrolltime = millis();
      if (strlen(msg) > 14) {
        scrolllog = true;
      } else {
        scrolllog = false;
      }
      printed = true;
    }
    if (((millis()-scrolltime) > SCROLL_TIME) && scrolllog) {
      scrolltime = millis();
      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.print(&msg[scroll++]);
      if (msg[scroll+1] == 0x00)
        scroll = 0;
    }
  } else if (LCDstate == LCD_DEBUG) {
    if ((millis()-lcdtime) > LCD_REFRESH) {
      lcdtime = millis();
      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.print(spitriggers, DEC);
      lcd.print(",");
      lcd.print(extitriggers, DEC);
    }
  } else if (LCDstate == LCD_IP) {
    if ((millis()-lcdtime) > LCD_REFRESH) {
      lcdtime = millis();
      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.print("IP ");
      lcd.print(curip+1, DEC);
      lcd.print(':');
      lcd.setCursor(0, 1);
      for(int i=0;i<4;i++) {
        lcd.print(ip[curip][i], DEC);
        if (i < 3)
          lcd.print('.');
      }
    }
  } else if (LCDstate == LCD_TMP) {
    if ((millis()-lcdtime) > LCD_REFRESH) {
      lcdtime = millis();
      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.print(buf);
    }
  }
  if (buttonactive && ((millis()-buttontime) > BUTTON_COUNTDOWN)) {
    LCDstate = LCD_NORMAL;
    printed = false;
    buttonactive = false;
  }
  if (!tmpprinted) {
    LCDstate = LCD_TMP;
    tmpprinted = true;
    tmpactive = true;
    tmpmsgtime = millis();
    lcdtime = millis() - LCD_REFRESH;
  }
  if (tmpactive && ((millis()-tmpmsgtime) > TMPMSG_DISTIME)) {
    LCDstate = LCD_NORMAL;
    printed = false;
    tmpactive = false;
  }
  if (((millis()-lastbuttime) > BUTTON_PRESS)) {
    if (isButtonPressed()) {
      buttontime = millis();
      if (buttonactive) {
        if (LCDstate == LCD_DEBUG) {
          LCDstate = LCD_IP;
        } else if (LCDstate == LCD_IP) {
          curip++;
          if (curip >= 4) {
            curip = 0;
            LCDstate = LCD_NORMAL;
            buttonactive = false;
            printed = false;
          }
        }
      } else {
        LCDstate = LCD_DEBUG;
        buttonactive = true;
      }
    }
    lastbuttime = millis();
  }
  if (ipupdate) {
    clearips();
    readips();
    ipupdate = false;
  }
  if (!motorcmd) {
    motortime = millis();
    setMotors(mot[0]);
    enableMotors(true);
    motorcmd = true;
  }
  if ((millis()-motortime) > MOTOR_TIMEOUT) {
    motortime = millis();
    setMotors(STOP);
    enableMotors(false);
  }
  if (SerialUSB.available() > 0) {
    char c = SerialUSB.read();
    switch (c) {
    case 'f':
      SerialUSB.println("Moving Forward");
      mot[0] = MOT_FORWARD;
      break;
    case 'b':
      SerialUSB.println("Moving Backward");
      mot[0] = MOT_BACKWARD;
      break;
    case 'l':
      SerialUSB.println("Moving Left");
      mot[0] = MOT_LEFT;
      break;
    case 'r':
      SerialUSB.println("Moving Right");
      mot[0] = MOT_RIGHT;
      break;
    case 's':
      measure = true;
      break;
    default:
      SerialUSB.println("STOP!");
      mot[0] = STOP;
      break;
    }
    motorcmd = false;
  }
  if (measure) {
    if (!measuring) {
      newval = false;
      timeout = false;
      digitalWrite(TRIG, HIGH);
      delayMicroseconds(10);
      digitalWrite(TRIG, LOW);
      timer1.setCount(0);
      timer1.refresh();
      timer1.resume();
      measuring = true;
    } else {
      if(newval) {
        timer1.pause();
        if (timeout == false) {
          ultratime = value;
          float distance = (((float)ultratime)*0.00017);
          SerialUSB.print("Pulse length: ");
          SerialUSB.print(ultratime);
          SerialUSB.print("uS, Distance: ");
          SerialUSB.println(distance,4);
        } else {
          SerialUSB.println("Object too far!");
        }
        measuring = false;
        measure = false;
        // Start measuring next sensor
        
      }
    }
  }
}

