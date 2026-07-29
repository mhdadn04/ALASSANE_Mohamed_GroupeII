import os
import sys

# Ensure the directory of this script is in sys.path so local imports resolve correctly
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from vehicle_simulator import VehicleSimulator

def main():
    # Create the Qt application
    app = QGuiApplication(sys.argv)
    
    # Create the vehicle simulator object
    simulator = VehicleSimulator()

    # Create the QML engine
    engine = QQmlApplicationEngine()
    
    # Inject the simulator instance into the QML root context
    # This allows direct access to the 'vehicle' object in dashboard.qml
    engine.rootContext().setContextProperty("vehicle", simulator)
    
    # Dynamically resolve the absolute path to dashboard.qml
    current_dir = os.path.dirname(os.path.abspath(__file__))
    qml_file = os.path.join(current_dir, "dashboard.qml")
    
    # Load the QML UI
    engine.load(qml_file)

    # Exit if loading failed
    if not engine.rootObjects():
        print("Error: Could not load the QML interface.")
        sys.exit(-1)
        
    # Start the Qt event loop
    print("Dashboard application launched successfully.")
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
