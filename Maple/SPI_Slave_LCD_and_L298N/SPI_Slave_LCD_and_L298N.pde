#include <LiquidCrystal.h>
#include "spi.h"
 
// initialize the library with the numbers of the interface pins
 LiquidCrystal lcd(17, 18, 19, 20, 21, 22);

// LCD Backlight
#define BKL_PIN 15

// Motor Stuff (L298N)
#define EN1 9
#define EN2 8
#define IN1 2
#define IN2 3
#define IN3 12
#define IN4 13

static unsigned long motortime = 0;
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
  } else if (dirl == MOT_BACKWARD) {
    digitalWrite(IN1, LOW);
    digitalWrite(IN2, HIGH);
  } else {
    digitalWrite(IN1, LOW);
    digitalWrite(IN2, LOW);
  }
  if (dirr == MOT_FORWARD) {
    digitalWrite(IN3, HIGH);
    digitalWrite(IN4, LOW);
  } else if (dirr == MOT_BACKWARD) {
    digitalWrite(IN3, LOW);
    digitalWrite(IN4, HIGH);
  } else {
    digitalWrite(IN3, LOW);
    digitalWrite(IN4, LOW);
  }
}

void setMotors(int dir) {
  if (dir == MOT_FORWARD) {
    MotorDirection(MOT_FORWARD, MOT_FORWARD);
  } else if (dir == MOT_BACKWARD) {
    MotorDirection(MOT_BACKWARD, MOT_BACKWARD);
  } else if (dir == MOT_LEFT) {
    MotorDirection(MOT_BACKWARD, MOT_FORWARD);
  } else if (dir == MOT_RIGHT) {
    MotorDirection(MOT_FORWARD, MOT_BACKWARD);
  } else {
    MotorDirection(STOP, STOP);
  }
}

void enableMotors(bool state) {
  if (state == true) {
    digitalWrite(EN1, HIGH);
    digitalWrite(EN2, HIGH);
  } else {
    digitalWrite(EN1, LOW);
    digitalWrite(EN2, LOW);
  }
}

// Slave Device
// Commands
#define LCD_BYTE 0x3F // Write message to LCD
#define BKL_BYTE 0x40 // Backlight setting
#define MOT_BYTE 0x15 // Motor Controller
#define RET_BYTE 0x6A

HardwareSPI spi(1);

//SPI States
#define IDLE    0
#define LCDDATA 1
#define BKLDATA 2
#define MOTDATA 3

char state = IDLE;
char spitriggers = 0;
char extitriggers = 0;
bool printed = true;
bool motorcmd = true;

char msg[40];
char mot[4];
unsigned int pointer = 0;

extern "C" {
  void __irq_spi1(void) {
    uint32 status = SPI1_BASE->SR;
    spitriggers++;
    if ((status & SPI_SR_RXNE) != 0) {
      if (state == IDLE) {
        byte command = spi.read();
        if (command == LCD_BYTE) {
          state = LCDDATA;
          digitalWrite(BOARD_LED_PIN, HIGH);
        } else if (command == BKL_BYTE) {
          state = BKLDATA;
          digitalWrite(BOARD_LED_PIN, HIGH);
        } else if (command == MOT_BYTE) {
          state = MOTDATA;
          digitalWrite(BOARD_LED_PIN, HIGH);
        } else {
          digitalWrite(BOARD_LED_PIN, LOW);
        }
      } else if (state == LCDDATA) {
        msg[pointer++] = spi.read();
      } else if (state == BKLDATA) {
        pwmWrite(BKL_PIN,spi.read());
      } else if (state == MOTDATA) {
        mot[pointer++] = spi.read();
      }
    }
    SPI1_BASE->SR = 0;
  }
}

void finish(void) {
  if (state == LCDDATA) {
    printed = false;
    msg[pointer++] = 0x00;
  } else if (state == MOTDATA) {
    motorcmd = false;
  }
  state = IDLE;
  pointer = 0;
  extitriggers++;
}

void setup(void) {
  pinMode(BOARD_LED_PIN, OUTPUT);
  digitalWrite(BOARD_LED_PIN, HIGH);
  pinMode(EN1, OUTPUT);
  pinMode(EN2, OUTPUT);
  enableMotors(false);
  pinMode(IN1, OUTPUT);
  pinMode(IN2, OUTPUT);
  pinMode(IN3, OUTPUT);
  pinMode(IN4, OUTPUT);
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
  lcd.print("Waiting...");
}

// LCD Scrolling
unsigned int scroll = 0;
unsigned long scrolltime = 0;
bool scrolllog = false;
#define SCROLL_TIME 750

void loop(void) {
  if ((printed == false) && (state == IDLE)) {
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print(msg);
    scroll = 1;
    scrolltime = millis();
    scrolllog = true;
    printed = true;
  }
  if (((millis()-scrolltime) > SCROLL_TIME) && scrolllog) {
    scrolltime = millis();
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print(&msg[scroll++]);
    if (msg[scroll] == 0x00)
      scroll = 0;
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
      default:
        SerialUSB.println("STOP!");
        mot[0] = STOP;
        break;
    }
    motorcmd = false;
  }
  lcd.setCursor(0, 1);
  lcd.print(spitriggers, DEC);
  lcd.print(",");
  lcd.print(extitriggers, DEC);
}
