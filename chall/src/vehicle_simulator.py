import time
from PySide6.QtCore import QObject, Signal, Property, QTimer

class VehicleSimulator(QObject):
    # Signals to notify the UI of data changes
    speedChanged = Signal(float)
    odometerChanged = Signal(float)
    pedalChanged = Signal(float)
    brakeChanged = Signal(float)
    powerChanged = Signal(float)
    driveModeChanged = Signal(int)

    def __init__(self, parent=None):
        super().__init__(parent)
        
        # State variables
        self._speed = 0.0       # Current speed in km/h
        self._odometer = 124.0  # Initial odometer reading in km (starting from 124 km for realism)
        self._pedal = 0.0       # Accelerator pedal percentage (0 to 100)
        self._brake = 0.0       # Brake pedal percentage (0 to 100)
        self._power = 0.0       # Instantaneous power in kW
        self._drive_mode = 1    # 0: ECO, 1: COMFORT, 2: SPORT

        # Setup loop running at ~60 FPS (16ms)
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.update_physics)
        self.last_time = time.time()
        self.timer.start(16)

    # Speed Property (Read-Only from QML)
    @Property(float, notify=speedChanged)
    def speed(self):
        return self._speed

    # Odometer Property (Read-Only from QML)
    @Property(float, notify=odometerChanged)
    def odometer(self):
        return self._odometer

    # Accelerator Pedal Property (Read-Write from QML)
    @Property(float, notify=pedalChanged)
    def pedal(self):
        return self._pedal

    @pedal.setter
    def pedal(self, val):
        val = max(0.0, min(100.0, float(val)))
        if self._pedal != val:
            self._pedal = val
            self.pedalChanged.emit(val)

    # Brake Pedal Property (Read-Write from QML)
    @Property(float, notify=brakeChanged)
    def brake(self):
        return self._brake

    @brake.setter
    def brake(self, val):
        val = max(0.0, min(100.0, float(val)))
        if self._brake != val:
            self._brake = val
            self.brakeChanged.emit(val)

    # Power Property (Read-Only from QML)
    @Property(float, notify=powerChanged)
    def power(self):
        return self._power

    # Drive Mode Property (Read-Write from QML)
    # 0 = ECO, 1 = COMFORT, 2 = SPORT
    @Property(int, notify=driveModeChanged)
    def driveMode(self):
        return self._drive_mode

    @driveMode.setter
    def driveMode(self, val):
        val = int(val)
        if self._drive_mode != val:
            self._drive_mode = val
            self.driveModeChanged.emit(val)

    def update_physics(self):
        current_time = time.time()
        dt = current_time - self.last_time
        self.last_time = current_time

        # Prevent large steps if system lags
        if dt > 0.1:
            dt = 0.1

        # 1. Physics limits based on Drive Mode
        if self._drive_mode == 0:      # ECO
            max_speed = 30.0           # Capped speed limit
            accel_tau = 15.0           # Smooth, slow acceleration (high inertia)
            regen_power = -7.0         # Mild regen braking
            max_power = 20.0           # Limited power draw
        elif self._drive_mode == 2:    # SPORT
            max_speed = 50.0           # Full speed limit
            accel_tau = 5.5            # Sharp, responsive acceleration (less inertia)
            regen_power = -22.0        # Aggressive regen braking (one-pedal feel)
            max_power = 35.0           # Maximum motor power
        else:                          # COMFORT (default)
            max_speed = 50.0
            accel_tau = 9.0
            regen_power = -15.0
            max_power = 30.0

        # 2. Target speed based on accelerator pedal
        target_speed = (self._pedal / 100.0) * max_speed

        # 3. Physics Model: Define inertia using time constants (tau)
        if self._brake > 0:
            # Active braking: slows down very fast, proportional to brake pressure
            tau = 2.0 / (self._brake / 100.0)
            target_speed = 0.0
        elif target_speed > self._speed:
            # Acceleration
            tau = accel_tau
        else:
            # Deceleration (coasting)
            tau = 25.0

        # Euler integration for speed
        dv = ((target_speed - self._speed) / tau) * dt
        new_speed = self._speed + dv

        # Clamp speed
        if new_speed < 0.05:
            new_speed = 0.0
        elif new_speed > max_speed:
            new_speed = max_speed

        # 4. Electrical Power estimation (kW)
        if self._brake > 0:
            # Regenerative braking: returns negative power (charging the battery)
            new_power = (self._brake / 100.0) * regen_power * (self._speed / max_speed if max_speed > 0 else 0)
        elif self._pedal > 0:
            # Acceleration power consumption
            new_power = (self._pedal / 100.0) * max_power * (0.3 + 0.7 * (self._speed / max_speed if max_speed > 0 else 0))
        else:
            # Standby / idling consumption (e.g. lights, screen, computing = 0.5 kW)
            new_power = 0.5 if self._speed > 0 else 0.2

        # 5. Damping (exponential filter) for fluid power needle movements
        # Prevents the needle from dropping instantly, mimicking real mechanical dashboard dampening
        smoothed_power = self._power + (new_power - self._power) * 0.12

        # 6. Odometer calculation (speed in km/h, dt in seconds -> distance in km)
        self._odometer += self._speed * (dt / 3600.0)

        # 7. Emit changes if values modified
        if abs(new_speed - self._speed) > 0.001:
            self._speed = new_speed
            self.speedChanged.emit(self._speed)

        if abs(smoothed_power - self._power) > 0.01:
            self._power = smoothed_power
            self.powerChanged.emit(self._power)

        self.odometerChanged.emit(self._odometer)
