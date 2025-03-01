#include <SPI.h>

const int CS_PIN = 10; // Chip Select pin for SPI
const int MPU = 0x68;  // MPU6050 Address (only relevant for I2C, not SPI)
float GyroZ, gyroAngleZ, yaw;
float elapsedTime, currentTime, previousTime;
float gyroZ_bias = 0.0;  // Bias correction value

// Complementary filter constants
float alpha = 0.98; // Higher means more gyro trust, lower means more accelerometer trust

void SPI_Write(uint8_t reg, uint8_t data) {
    digitalWrite(CS_PIN, LOW);
    SPI.transfer(reg);
    SPI.transfer(data);
    digitalWrite(CS_PIN, HIGH);
}

uint8_t SPI_Read(uint8_t reg) {
    digitalWrite(CS_PIN, LOW);
    SPI.transfer(reg | 0x80);  // Set MSB to 1 for reading
    uint8_t data = SPI.transfer(0x00);
    digitalWrite(CS_PIN, HIGH);
    return data;
}

void calibrateGyro() {
    Serial.println("Calibrating Gyro...");
    int num_samples = 500;
    float sum = 0;

    for (int i = 0; i < num_samples; i++) {
        uint8_t high = SPI_Read(0x47);
        uint8_t low = SPI_Read(0x48);
        int16_t rawGyroZ = (high << 8) | low;
        sum += rawGyroZ;
        delay(3);
    }

    gyroZ_bias = sum / num_samples / 131.0; // Convert to deg/s
    Serial.print("Gyro Bias (Z): ");
    Serial.println(gyroZ_bias);
}

void setup() {
    Serial.begin(9600);
    SPI.begin();
    SPI.setClockDivider(SPI_CLOCK_DIV16); // SPI @ 1 MHz (for 16MHz CPU)
    SPI.setDataMode(SPI_MODE3);
    SPI.setBitOrder(MSBFIRST);

    pinMode(CS_PIN, OUTPUT);
    digitalWrite(CS_PIN, HIGH);

    delay(100);

    // Wake up MPU6050 (MPU6000 in SPI mode)
    SPI_Write(0x6B, 0x00);
    delay(100);

    calibrateGyro(); // Perform bias calibration
}

void loop() {
    previousTime = currentTime;
    currentTime = millis();
    elapsedTime = (currentTime - previousTime) / 1000.0;

    // Read Gyro Z-axis data
    uint8_t high = SPI_Read(0x47);
    uint8_t low = SPI_Read(0x48);
    int16_t rawGyroZ = (high << 8) | low;

    // Convert raw value to deg/s
    GyroZ = (rawGyroZ / 131.0) - gyroZ_bias; // Apply bias correction

    // Integrate gyroscope data to get yaw angle
    yaw = yaw + GyroZ * elapsedTime;

    Serial.print("Yaw (Gyro Only): ");
    Serial.println(yaw);

    delay(100); // Small delay for stability
}