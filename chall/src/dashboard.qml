import QtQuick
import QtQuick.Window

Window {
    id: root
    width: 1280
    height: 800
    visible: true
    title: "Tableau de Bord Premium - Navette Électrique 8 Places"
    color: "#08090d" // Deep charcoal/black base

    // Drive Mode Themes
    // 0 = ECO (Green), 1 = COMFORT (Cyan), 2 = SPORT (Magenta)
    readonly property int driveMode: vehicle.driveMode
    property color themeColor: driveMode === 0 ? "#39ff14" : (driveMode === 1 ? "#00f0ff" : "#ff007f")
    property color themeGlowColor: driveMode === 0 ? "rgba(57, 255, 20, 0.4)" : (driveMode === 1 ? "rgba(0, 240, 255, 0.4)" : "rgba(255, 0, 127, 0.4)")

    // Keyboard states
    property bool isAccelerating: false
    property bool isBraking: false
    
    // Mouse states (to avoid conflict with timer key-release resets)
    property bool isMouseAccelerating: false
    property bool isMouseBraking: false

    // General states
    property bool lightsActive: true
    property bool leftTurnActive: false
    property bool rightTurnActive: false
    property bool hazardActive: false
    property int fanSpeed: 4

    // Prevent focus loss to keep keyboard inputs active
    onActiveFocusItemChanged: {
        if (activeFocusItem !== mainContainer) {
            mainContainer.focus = true
        }
    }

    // Keyboard & Mouse Pedal Physics Timer
    Timer {
        id: pedalPhysicsTimer
        interval: 16
        running: true
        repeat: true
        onTriggered: {
            var dt = 0.016
            
            // Accelerator pedal physics
            if (isAccelerating) {
                vehicle.pedal = Math.min(100.0, vehicle.pedal + 120.0 * dt) // 0 to 100 in ~0.8s
            } else if (!isMouseAccelerating) {
                vehicle.pedal = Math.max(0.0, vehicle.pedal - 160.0 * dt)   // Returns to 0 on release
            }

            // Brake pedal physics
            if (isBraking) {
                vehicle.brake = Math.min(100.0, vehicle.brake + 180.0 * dt) // 0 to 100 in ~0.5s
            } else if (!isMouseBraking) {
                vehicle.brake = Math.max(0.0, vehicle.brake - 200.0 * dt)   // Returns to 0 on release
            }
        }
    }

    // Timer for local time
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            var date = new Date()
            timeLabel.text = date.toLocaleTimeString(Qt.locale("fr_FR"), "hh:mm:ss")
        }
    }

    // Timer for blinking turn signals
    Timer {
        id: blinkTimer
        interval: 375 // Slightly faster for high-tech feel
        running: leftTurnActive || rightTurnActive || hazardActive
        repeat: true
        property bool blinkState: false
        onTriggered: {
            blinkState = !blinkState
        }
        onRunningChanged: {
            if (!running) blinkState = false
        }
    }

    // Main layout container (captures focus)
    Item {
        id: mainContainer
        anchors.fill: parent
        anchors.margins: 25
        focus: true

        // Keyboard Event Handlers (Fixed with isAutoRepeat checks)
        Keys.onPressed: {
            if (event.isAutoRepeat) return
            if (event.key === Qt.Key_Up) {
                isAccelerating = true
                event.accepted = true
            } else if (event.key === Qt.Key_Down) {
                isBraking = true
                event.accepted = true
            } else if (event.key === Qt.Key_Left) {
                leftTurnActive = !leftTurnActive
                if (leftTurnActive) rightTurnActive = false
                event.accepted = true
            } else if (event.key === Qt.Key_Right) {
                rightTurnActive = !rightTurnActive
                if (rightTurnActive) leftTurnActive = false
                event.accepted = true
            }
        }
        Keys.onReleased: {
            if (event.isAutoRepeat) return
            if (event.key === Qt.Key_Up) {
                isAccelerating = false
                event.accepted = true
            } else if (event.key === Qt.Key_Down) {
                isBraking = false
                event.accepted = true
            }
        }

        // ================= HEADER / STATUS BAR =================
        Row {
            id: headerBar
            width: parent.width
            height: 50

            // Left: Shuttle brand info
            Column {
                width: 300
                spacing: 2
                Text {
                    text: "E-SHUTTLE 8P"
                    color: "#ffffff"
                    font.pixelSize: 18
                    font.bold: true
                    font.letterSpacing: 3
                }
                Row {
                    spacing: 8
                    Rectangle {
                        width: 45; height: 14
                        color: themeColor
                        radius: 3
                        Text {
                            anchors.centerIn: parent
                            text: driveMode === 0 ? "ECO" : (driveMode === 1 ? "COMFORT" : "SPORT")
                            color: "#000000"
                            font.pixelSize: 9
                            font.bold: true
                        }
                    }
                    Text {
                        text: "CONNECTED TO CAN BUS (SIMULATED)"
                        color: "#4e5366"
                        font.pixelSize: 9
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Center: Bins/Indicators (Turn signals, Hazard, Headlights)
            Item {
                width: parent.width - 600
                height: parent.height

                Row {
                    anchors.centerIn: parent
                    spacing: 25

                    // Left Turn
                    Text {
                        text: "◀"
                        font.pixelSize: 26
                        color: (leftTurnActive || hazardActive) && blinkTimer.blinkState ? "#39ff14" : "#1a1c24"
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                leftTurnActive = !leftTurnActive
                                if (leftTurnActive) rightTurnActive = false
                            }
                        }
                    }

                    // Headlights (interactive)
                    Text {
                        text: "⛯"
                        font.pixelSize: 22
                        color: lightsActive ? "#00f0ff" : "#1a1c24"
                        anchors.verticalCenter: parent.verticalCenter
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                lightsActive = !lightsActive
                                shuttleCanvas.requestPaint()
                            }
                        }
                    }

                    // Hazard (interactive)
                    Text {
                        text: "⚠️"
                        font.pixelSize: 22
                        color: hazardActive ? "#ff007f" : "#4e5366"
                        anchors.verticalCenter: parent.verticalCenter
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                hazardActive = !hazardActive
                                if (hazardActive) {
                                    leftTurnActive = false
                                    rightTurnActive = false
                                }
                            }
                        }
                    }

                    // Right Turn
                    Text {
                        text: "▶"
                        font.pixelSize: 26
                        color: (rightTurnActive || hazardActive) && blinkTimer.blinkState ? "#39ff14" : "#1a1c24"
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                rightTurnActive = !rightTurnActive
                                if (rightTurnActive) leftTurnActive = false
                            }
                        }
                    }
                }
            }

            // Right: Time & System Status
            Column {
                width: 300
                anchors.right: parent.right
                spacing: 2
                Text {
                    id: timeLabel
                    text: "--:--:--"
                    color: "#ffffff"
                    font.pixelSize: 18
                    font.family: "Monospace"
                    font.bold: true
                    horizontalAlignment: Text.AlignRight
                    width: parent.width
                }
                Text {
                    text: "SYS STATE: READY | GPS: OK"
                    color: "#39ff14"
                    font.pixelSize: 9
                    font.bold: true
                    horizontalAlignment: Text.AlignRight
                    width: parent.width
                }
            }
        }

        // Divider
        Rectangle {
            id: headerDivider
            width: parent.width
            height: 1
            color: "#121522"
            anchors.top: headerBar.bottom
            anchors.topMargin: 10
        }

        // ================= MAIN INSTRUMENT PANEL =================
        Row {
            anchors.top: headerDivider.bottom
            anchors.bottom: parent.bottom
            width: parent.width
            spacing: 20
            anchors.topMargin: 15

            // --- LEFT PANEL: DRIVING SYSTEMS ---
            Rectangle {
                width: 250
                height: parent.height
                color: "#0a0c12"
                border.color: "#121522"
                border.width: 1
                radius: 12

                // Glow effect border for current theme
                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: "transparent"
                    border.color: themeColor
                    border.width: 1
                    opacity: 0.15
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 15

                    Text {
                        text: "CONDUITE & ORGANES"
                        color: "#4e5366"
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.5
                    }

                    // DRIVE MODE SELECTOR (Eco / Comfort / Sport)
                    Column {
                        width: parent.width
                        spacing: 8
                        Text { text: "MODE DE MARCHE"; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
                        
                        Row {
                            width: parent.width
                            height: 32
                            spacing: 2

                            // ECO Button
                            Rectangle {
                                width: (parent.width - 4) / 3
                                height: parent.height
                                color: driveMode === 0 ? "#122a16" : "#10121a"
                                border.color: driveMode === 0 ? "#39ff14" : "#1a1c24"
                                border.width: 1
                                radius: 4
                                Text { anchors.centerIn: parent; text: "ECO"; color: driveMode === 0 ? "#39ff14" : "#4e5366"; font.pixelSize: 10; font.bold: true }
                                MouseArea { anchors.fill: parent; onClicked: vehicle.driveMode = 0 }
                            }

                            // COMFORT Button
                            Rectangle {
                                width: (parent.width - 4) / 3
                                height: parent.height
                                color: driveMode === 1 ? "#0e232e" : "#10121a"
                                border.color: driveMode === 1 ? "#00f0ff" : "#1a1c24"
                                border.width: 1
                                radius: 4
                                Text { anchors.centerIn: parent; text: "COMFORT"; color: driveMode === 1 ? "#00f0ff" : "#4e5366"; font.pixelSize: 10; font.bold: true }
                                MouseArea { anchors.fill: parent; onClicked: vehicle.driveMode = 1 }
                            }

                            // SPORT Button
                            Rectangle {
                                width: (parent.width - 4) / 3
                                height: parent.height
                                color: driveMode === 2 ? "#2e0f21" : "#10121a"
                                border.color: driveMode === 2 ? "#ff007f" : "#1a1c24"
                                border.width: 1
                                radius: 4
                                Text { anchors.centerIn: parent; text: "SPORT"; color: driveMode === 2 ? "#ff007f" : "#4e5366"; font.pixelSize: 10; font.bold: true }
                                MouseArea { anchors.fill: parent; onClicked: vehicle.driveMode = 2 }
                            }
                        }
                    }

                    // METALLIC PEDALS SIMULATOR
                    Row {
                        width: parent.width
                        height: 200
                        spacing: 25
                        anchors.horizontalCenter: parent.horizontalCenter

                        // Brake Pedal
                        Column {
                            height: parent.height
                            spacing: 8
                            anchors.bottom: parent.bottom

                            // The pedal casing
                            Rectangle {
                                width: 85
                                height: 160
                                color: "#111420"
                                radius: 6
                                border.color: vehicle.brake > 0 ? "#ff007f" : "#1b1e2c"
                                border.width: 1.5
                                anchors.horizontalCenter: parent.horizontalCenter

                                // Anti-slip lines (Metallic look)
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 12
                                    Repeater {
                                        model: 6
                                        Rectangle {
                                            width: 60; height: 3
                                            color: "#1d2238"
                                        }
                                    }
                                }

                                // Interactive indicator
                                Rectangle {
                                    width: parent.width - 4
                                    height: (vehicle.brake / 100.0) * (parent.height - 4)
                                    color: "#ff007f"
                                    opacity: 0.25
                                    radius: 4
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    Behavior on height { NumberAnimation { duration: 30 } }
                                }

                                // Interactive slide handler
                                MouseArea {
                                    anchors.fill: parent
                                    preventStealing: true
                                    onPressed: {
                                        isMouseBraking = true
                                        var val = ((height - mouse.y) / height) * 100
                                        vehicle.brake = Math.max(0.0, Math.min(100.0, val))
                                    }
                                    onPositionChanged: {
                                        var val = ((height - mouse.y) / height) * 100
                                        vehicle.brake = Math.max(0.0, Math.min(100.0, val))
                                    }
                                    onReleased: {
                                        isMouseBraking = false
                                        vehicle.brake = 0
                                    }
                                }
                            }

                            Text {
                                text: "FREIN : " + Math.round(vehicle.brake) + "%"
                                color: vehicle.brake > 0 ? "#ff007f" : "#4e5366"
                                font.pixelSize: 10
                                font.bold: true
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        // Accelerator Pedal
                        Column {
                            height: parent.height
                            spacing: 8
                            anchors.bottom: parent.bottom

                            Rectangle {
                                width: 55
                                height: 180
                                color: "#111420"
                                radius: 6
                                border.color: vehicle.pedal > 0 ? themeColor : "#1b1e2c"
                                border.width: 1.5
                                anchors.horizontalCenter: parent.horizontalCenter

                                // Anti-slip lines
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 12
                                    Repeater {
                                        model: 7
                                        Rectangle {
                                            width: 35; height: 3
                                            color: "#1d2238"
                                        }
                                    }
                                }

                                // Interactive indicator
                                Rectangle {
                                    width: parent.width - 4
                                    height: (vehicle.pedal / 100.0) * (parent.height - 4)
                                    color: themeColor
                                    opacity: 0.25
                                    radius: 4
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    Behavior on height { NumberAnimation { duration: 30 } }
                                }

                                // Interactive slide handler
                                MouseArea {
                                    anchors.fill: parent
                                    preventStealing: true
                                    onPressed: {
                                        isMouseAccelerating = true
                                        var val = ((height - mouse.y) / height) * 100
                                        vehicle.pedal = Math.max(0.0, Math.min(100.0, val))
                                    }
                                    onPositionChanged: {
                                        var val = ((height - mouse.y) / height) * 100
                                        vehicle.pedal = Math.max(0.0, Math.min(100.0, val))
                                    }
                                    onReleased: {
                                        isMouseAccelerating = false
                                        vehicle.pedal = 0
                                    }
                                }
                            }

                            Text {
                                text: "ACCEL : " + Math.round(vehicle.pedal) + "%"
                                color: vehicle.pedal > 0 ? themeColor : "#4e5366"
                                font.pixelSize: 10
                                font.bold: true
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }

                    // System Health Card
                    Rectangle {
                        width: parent.width
                        height: 100
                        color: "#0d0f17"
                        border.color: "#161925"
                        border.width: 1
                        radius: 8

                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 6

                            Row {
                                width: parent.width
                                Text { text: "TEMPÉRATEUR MOTEUR"; color: "#4e5366"; font.pixelSize: 9; font.bold: true }
                                Text { 
                                    text: Math.round(35 + vehicle.speed * 0.14) + " °C"
                                    color: "#ffffff"
                                    font.pixelSize: 10; font.bold: true
                                    anchors.right: parent.right 
                                }
                            }
                            Row {
                                width: parent.width
                                Text { text: "TEMPÉRATEUR ONDULEUR"; color: "#4e5366"; font.pixelSize: 9; font.bold: true }
                                Text { 
                                    text: Math.round(33 + vehicle.speed * 0.08) + " °C"
                                    color: "#ffffff"
                                    font.pixelSize: 10; font.bold: true
                                    anchors.right: parent.right 
                                }
                            }
                            Row {
                                width: parent.width
                                Text { text: "PRES. PNEUS (AV / AR)"; color: "#4e5366"; font.pixelSize: 9; font.bold: true }
                                Text { 
                                    text: "2.8 bar / 3.0 bar"
                                    color: "#39ff14"
                                    font.pixelSize: 10; font.bold: true
                                    anchors.right: parent.right 
                                }
                            }
                            Row {
                                width: parent.width
                                Text { text: "VITESSE MAX LIMITÉE"; color: "#4e5366"; font.pixelSize: 9; font.bold: true }
                                Text { 
                                    text: "50 km/h"
                                    color: "#ff9900"
                                    font.pixelSize: 10; font.bold: true
                                    anchors.right: parent.right 
                                }
                            }
                        }
                    }
                }
            }

            // --- CENTER WIDESCREEN: INSTRUMENT CLUSTER ---
            Item {
                width: parent.width - 500
                height: parent.height

                // Widescreen panel layout
                // Columns: Left Dial (Speed), Center Vehicle Wireframe, Right Dial (Power)
                Row {
                    id: instrumentClusterRow
                    width: parent.width
                    height: parent.height - 110
                    spacing: 0

                    // 1. LEFT DIAL: SPEEDOMETER
                    Item {
                        width: parent.width * 0.38
                        height: parent.height

                        Canvas {
                            id: speedDialCanvas
                            anchors.fill: parent
                            
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.reset();
                                ctx.clearRect(0, 0, width, height);
                                
                                var cx = width / 2;
                                var cy = height / 2 + 10;
                                var radius = Math.min(width, height) / 2 - 20;
                                
                                // Draw Background Arc (135 to 45 deg)
                                ctx.beginPath();
                                ctx.arc(cx, cy, radius, 0.75 * Math.PI, 2.25 * Math.PI, false);
                                ctx.lineWidth = 8;
                                ctx.strokeStyle = "#121420";
                                ctx.lineCap = "round";
                                ctx.stroke();
                                
                                // Draw Active speed segment
                                var ratio = vehicle.speed / vehicle.MAX_SPEED;
                                if (ratio > 0) {
                                    var end = 0.75 * Math.PI + (ratio * 1.5 * Math.PI);
                                    ctx.beginPath();
                                    ctx.arc(cx, cy, radius, 0.75 * Math.PI, end, false);
                                    ctx.lineWidth = 10;
                                    ctx.strokeStyle = themeColor;
                                    ctx.lineCap = "round";
                                    ctx.stroke();
                                    
                                    // Glow
                                    ctx.shadowBlur = 12;
                                    ctx.shadowColor = themeColor;
                                    ctx.stroke();
                                    ctx.shadowBlur = 0; // reset
                                }
                                
                                // Draw Ticks & Labels
                                ctx.lineWidth = 1.5;
                                for (var i = 0; i <= 10; i++) {
                                    var val = i * 5;
                                    var angle = 0.75 * Math.PI + ((val / 50.0) * 1.5 * Math.PI);
                                    var innerR = radius - (i % 2 === 0 ? 12 : 6);
                                    var outerR = radius - 1;
                                    
                                    ctx.beginPath();
                                    ctx.moveTo(cx + innerR * Math.cos(angle), cy + innerR * Math.sin(angle));
                                    ctx.lineTo(cx + outerR * Math.cos(angle), cy + outerR * Math.sin(angle));
                                    ctx.strokeStyle = i % 2 === 0 ? "#3d425c" : "#222536";
                                    ctx.stroke();
                                    
                                    if (i % 2 === 0) {
                                        var labelR = radius - 24;
                                        var lx = cx + labelR * Math.cos(angle);
                                        var ly = cy + labelR * Math.sin(angle);
                                        ctx.fillStyle = "#696e8c";
                                        ctx.font = "bold 11px sans-serif";
                                        ctx.textAlign = "center";
                                        ctx.textBaseline = "middle";
                                        ctx.fillText(val.toString(), lx, ly);
                                    }
                                }
                                
                                // Needle
                                var needleAngle = 0.75 * Math.PI + (ratio * 1.5 * Math.PI);
                                ctx.beginPath();
                                ctx.moveTo(cx, cy);
                                ctx.lineTo(cx + (radius - 5) * Math.cos(needleAngle), cy + (radius - 5) * Math.sin(needleAngle));
                                ctx.lineWidth = 2.5;
                                ctx.strokeStyle = "#ffffff";
                                ctx.stroke();
                                
                                // Center Hub
                                ctx.beginPath();
                                ctx.arc(cx, cy, 6, 0, 2 * Math.PI);
                                ctx.fillStyle = "#ffffff";
                                ctx.fill();
                            }
                        }

                        Connections {
                            target: vehicle
                            function onSpeedChanged() { speedDialCanvas.requestPaint() }
                        }

                        // Digital Speed readout
                        Column {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: 15
                            Text {
                                text: Math.round(vehicle.speed).toString()
                                color: "#ffffff"
                                font.pixelSize: 58
                                font.bold: true
                                font.family: "Monospace"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            Text {
                                text: "VITESSE"
                                color: themeColor
                                font.pixelSize: 9
                                font.bold: true
                                font.letterSpacing: 2
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            Text {
                                text: "km/h"
                                color: "#4e5366"
                                font.pixelSize: 10
                                font.bold: true
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }

                    // 2. CENTER CAR VISUALIZATION
                    Item {
                        width: parent.width * 0.24
                        height: parent.height

                        Canvas {
                            id: shuttleCanvas
                            anchors.fill: parent
                            
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.reset();
                                ctx.clearRect(0, 0, width, height);
                                
                                var cx = width / 2;
                                var cy = height / 2 + 10;
                                
                                // Top-view body
                                ctx.beginPath();
                                ctx.roundRect(cx - 36, cy - 80, 72, 160, 16);
                                ctx.lineWidth = 1.5;
                                ctx.strokeStyle = "#1b2138";
                                ctx.fillStyle = "#090a10";
                                ctx.fill();
                                ctx.stroke();

                                // Outer accent glow line
                                ctx.beginPath();
                                ctx.roundRect(cx - 38, cy - 82, 76, 164, 18);
                                ctx.strokeStyle = themeColor;
                                ctx.lineWidth = 0.5;
                                ctx.globalAlpha = 0.3;
                                ctx.stroke();
                                ctx.globalAlpha = 1.0;

                                // Headlights beam
                                if (lightsActive) {
                                    // Left beam
                                    ctx.beginPath();
                                    ctx.moveTo(cx - 28, cy - 80);
                                    ctx.lineTo(cx - 45, cy - 110);
                                    ctx.lineTo(cx - 15, cy - 110);
                                    ctx.closePath();
                                    var grL = ctx.createLinearGradient(cx - 28, cy - 80, cx - 28, cy - 110);
                                    grL.addColorStop(0, "rgba(0, 240, 255, 0.25)");
                                    grL.addColorStop(1, "rgba(0, 240, 255, 0.0)");
                                    ctx.fillStyle = grL;
                                    ctx.fill();

                                    // Right beam
                                    ctx.beginPath();
                                    ctx.moveTo(cx + 28, cy - 80);
                                    ctx.lineTo(cx + 15, cy - 110);
                                    ctx.lineTo(cx + 45, cy - 110);
                                    ctx.closePath();
                                    var grR = ctx.createLinearGradient(cx + 28, cy - 80, cx + 28, cy - 110);
                                    grR.addColorStop(0, "rgba(0, 240, 255, 0.25)");
                                    grR.addColorStop(1, "rgba(0, 240, 255, 0.0)");
                                    ctx.fillStyle = grR;
                                    ctx.fill();
                                }

                                // 2+2+2+2 seat configuration wireframe
                                ctx.strokeStyle = "#272e42";
                                ctx.lineWidth = 1;
                                var rowsY = [cy - 50, cy - 20, cy + 10, cy + 40];
                                for (var r = 0; r < 4; r++) {
                                    var y = rowsY[r];
                                    // Left Seat
                                    ctx.beginPath();
                                    ctx.roundRect(cx - 25, y - 8, 18, 16, 3);
                                    ctx.stroke();

                                    // Right Seat
                                    ctx.beginPath();
                                    ctx.roundRect(cx + 7, y - 8, 18, 16, 3);
                                    ctx.stroke();
                                }

                                // Battery pack overlay under chassis (glowing battery compartment)
                                ctx.beginPath();
                                ctx.roundRect(cx - 18, cy - 35, 36, 90, 6);
                                ctx.lineWidth = 1.5;
                                if (vehicle.power < 0) {
                                    ctx.strokeStyle = "#39ff14"; // Charging Green
                                    ctx.shadowColor = "#39ff14";
                                } else if (vehicle.power > 25) {
                                    ctx.strokeStyle = "#ff007f"; // High Discharge Pink
                                    ctx.shadowColor = "#ff007f";
                                } else {
                                    ctx.strokeStyle = "#00f0ff"; // Normal Discharge Blue
                                    ctx.shadowColor = "#00f0ff";
                                }
                                ctx.shadowBlur = 6;
                                ctx.stroke();
                                ctx.shadowBlur = 0; // reset

                                // Draw Door outline warning if speed is low and we're static
                                if (vehicle.speed < 0.5) {
                                    ctx.strokeStyle = "#ff9900";
                                    ctx.lineWidth = 2;
                                    // Left open door
                                    ctx.beginPath();
                                    ctx.moveTo(cx - 36, cy - 10);
                                    ctx.lineTo(cx - 50, cy - 25);
                                    ctx.stroke();

                                    // Right open door
                                    ctx.beginPath();
                                    ctx.moveTo(cx + 36, cy - 10);
                                    ctx.lineTo(cx + 50, cy - 25);
                                    ctx.stroke();
                                }
                            }
                        }

                        // Door Open warning text overlay
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 10
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: vehicle.speed < 0.5 ? "rgba(255, 153, 0, 0.15)" : "transparent"
                            border.color: vehicle.speed < 0.5 ? "#ff9900" : "transparent"
                            border.width: 1
                            radius: 4
                            width: 110; height: 22

                            Text {
                                anchors.centerIn: parent
                                text: vehicle.speed < 0.5 ? "PORTES OUVERTES" : "PORTES VERROU."
                                color: vehicle.speed < 0.5 ? "#ff9900" : "#4e5366"
                                font.pixelSize: 9
                                font.bold: true
                            }
                        }

                        Connections {
                            target: vehicle
                            function onPowerChanged() { shuttleCanvas.requestPaint() }
                            function onSpeedChanged() { shuttleCanvas.requestPaint() }
                        }
                    }

                    // 3. RIGHT DIAL: POWER & REGEN FLOW
                    Item {
                        width: parent.width * 0.38
                        height: parent.height

                        Canvas {
                            id: powerDialCanvas
                            anchors.fill: parent
                            
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.reset();
                                ctx.clearRect(0, 0, width, height);
                                
                                var cx = width / 2;
                                var cy = height / 2 + 10;
                                var radius = Math.min(width, height) / 2 - 20;
                                
                                // Draw Background Arc (135 to 45 deg)
                                ctx.beginPath();
                                ctx.arc(cx, cy, radius, 0.75 * Math.PI, 2.25 * Math.PI, false);
                                ctx.lineWidth = 8;
                                ctx.strokeStyle = "#121420";
                                ctx.lineCap = "round";
                                ctx.stroke();
                                
                                // Draw charging sector (135 deg to 270 deg / -15kW to 0kW)
                                ctx.beginPath();
                                ctx.arc(cx, cy, radius, 0.75 * Math.PI, 1.5 * Math.PI, false);
                                ctx.lineWidth = 3;
                                ctx.strokeStyle = "rgba(57, 255, 20, 0.2)";
                                ctx.stroke();

                                // Draw discharge sector (270 deg to 45 deg / 0kW to 35kW)
                                ctx.beginPath();
                                ctx.arc(cx, cy, radius, 1.5 * Math.PI, 2.25 * Math.PI, false);
                                ctx.lineWidth = 3;
                                ctx.strokeStyle = "rgba(0, 240, 255, 0.2)";
                                ctx.stroke();
                                
                                // Draw active power segment
                                // -15 kW -> 0.75 * Math.PI
                                // 0 kW   -> 1.50 * Math.PI (top center)
                                // +35 kW -> 2.25 * Math.PI
                                var powerAngle = 1.50 * Math.PI; // default 0 kW
                                if (vehicle.power < 0) {
                                    // Regen braking: -15 to 0
                                    var regenRatio = Math.abs(vehicle.power) / 15.0; // 0 to 1
                                    powerAngle = 1.50 * Math.PI - (regenRatio * 0.75 * Math.PI);
                                    ctx.beginPath();
                                    ctx.arc(cx, cy, radius, powerAngle, 1.5 * Math.PI, false);
                                    ctx.lineWidth = 10;
                                    ctx.strokeStyle = "#39ff14"; // Green for regen
                                    ctx.lineCap = "round";
                                    ctx.stroke();

                                    ctx.shadowBlur = 10;
                                    ctx.shadowColor = "#39ff14";
                                    ctx.stroke();
                                    ctx.shadowBlur = 0;
                                } else if (vehicle.power > 0) {
                                    // Acceleration: 0 to +35 kW
                                    var powerRatio = vehicle.power / 35.0;
                                    powerAngle = 1.50 * Math.PI + (powerRatio * 0.75 * Math.PI);
                                    ctx.beginPath();
                                    ctx.arc(cx, cy, radius, 1.5 * Math.PI, powerAngle, false);
                                    ctx.lineWidth = 10;
                                    ctx.strokeStyle = vehicle.power > 25.0 ? "#ff007f" : "#00f0ff";
                                    ctx.lineCap = "round";
                                    ctx.stroke();

                                    ctx.shadowBlur = 10;
                                    ctx.shadowColor = vehicle.power > 25.0 ? "#ff007f" : "#00f0ff";
                                    ctx.stroke();
                                    ctx.shadowBlur = 0;
                                }
                                
                                // Draw Ticks & Labels
                                ctx.lineWidth = 1.5;
                                var pValues = [-15, -10, -5, 0, 5, 10, 15, 20, 25, 30, 35];
                                for (var i = 0; i < pValues.length; i++) {
                                    var pVal = pValues[i];
                                    var angle = 0;
                                    if (pVal < 0) {
                                        angle = 1.5 * Math.PI - (Math.abs(pVal)/15.0 * 0.75 * Math.PI);
                                    } else {
                                        angle = 1.5 * Math.PI + (pVal/35.0 * 0.75 * Math.PI);
                                    }
                                    
                                    var isMajor = pVal % 10 === 0 || pVal === 0 || pVal === -15 || pVal === 35;
                                    var innerR = radius - (isMajor ? 12 : 6);
                                    var outerR = radius - 1;
                                    
                                    ctx.beginPath();
                                    ctx.moveTo(cx + innerR * Math.cos(angle), cy + innerR * Math.sin(angle));
                                    ctx.lineTo(cx + outerR * Math.cos(angle), cy + outerR * Math.sin(angle));
                                    ctx.strokeStyle = isMajor ? "#3d425c" : "#222536";
                                    ctx.stroke();
                                    
                                    if (isMajor) {
                                        var labelR = radius - 24;
                                        var lx = cx + labelR * Math.cos(angle);
                                        var ly = cy + labelR * Math.sin(angle);
                                        ctx.fillStyle = pVal < 0 ? "#39ff14" : (pVal === 0 ? "#ffffff" : "#696e8c");
                                        ctx.font = "bold 10px sans-serif";
                                        ctx.textAlign = "center";
                                        ctx.textBaseline = "middle";
                                        ctx.fillText(pVal.toString(), lx, ly);
                                    }
                                }
                                
                                // Needle
                                ctx.beginPath();
                                ctx.moveTo(cx, cy);
                                ctx.lineTo(cx + (radius - 5) * Math.cos(powerAngle), cy + (radius - 5) * Math.sin(powerAngle));
                                ctx.lineWidth = 2.5;
                                ctx.strokeStyle = "#ffffff";
                                ctx.stroke();
                                
                                // Center Hub
                                ctx.beginPath();
                                ctx.arc(cx, cy, 6, 0, 2 * Math.PI);
                                ctx.fillStyle = "#ffffff";
                                ctx.fill();
                            }
                        }

                        Connections {
                            target: vehicle
                            function onPowerChanged() { powerDialCanvas.requestPaint() }
                        }

                        // Digital Power readout
                        Column {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: 15
                            Text {
                                text: (vehicle.power >= 0 ? "+" : "") + vehicle.power.toFixed(1)
                                color: vehicle.power < 0 ? "#39ff14" : "#ffffff"
                                font.pixelSize: 42
                                font.bold: true
                                font.family: "Monospace"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            Text {
                                text: vehicle.power < 0 ? "RECUPÉRATION" : "PUISSANCE"
                                color: vehicle.power < 0 ? "#39ff14" : themeColor
                                font.pixelSize: 9
                                font.bold: true
                                font.letterSpacing: 2
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            Text {
                                text: "kW"
                                color: "#4e5366"
                                font.pixelSize: 10
                                font.bold: true
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }
                }

                // Gear indicators in the center (P R N D)
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: odoContainer.top
                    anchors.bottomMargin: 18
                    spacing: 20

                    Text { text: "P"; font.pixelSize: 20; font.bold: true; color: "#161824" }
                    Text { text: "R"; font.pixelSize: 20; font.bold: true; color: "#161824" }
                    Text { text: "N"; font.pixelSize: 20; font.bold: true; color: "#161824" }
                    Text { 
                        text: "D"
                        font.pixelSize: 22
                        font.bold: true
                        color: vehicle.speed > 0.1 || vehicle.pedal > 0 ? "#39ff14" : "#ffffff"
                        
                        Rectangle {
                            anchors.centerIn: parent
                            width: 32; height: 32
                            radius: 16
                            color: "transparent"
                            border.color: "#39ff14"
                            border.width: 1.5
                            z: -1
                            visible: vehicle.speed > 0.1 || vehicle.pedal > 0
                        }
                    }
                }

                // --- ODOMETER BAR ---
                Rectangle {
                    id: odoContainer
                    width: 280
                    height: 52
                    color: "#08090d"
                    border.color: "#181c2e"
                    border.width: 1.5
                    radius: 8
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 10
                    anchors.horizontalCenter: parent.horizontalCenter

                    // Sub-glow
                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: "transparent"
                        border.color: themeColor
                        border.width: 1
                        opacity: 0.1
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 3

                        // Prefix zeros
                        Text {
                            text: {
                                var odoStr = Math.floor(vehicle.odometer).toString()
                                var zeros = ""
                                for (var i = odoStr.length; i < 6; i++) {
                                    zeros += "0"
                                }
                                return zeros
                            }
                            color: "#1d2138"
                            font.pixelSize: 26
                            font.family: "Monospace"
                            font.bold: true
                        }

                        // Main integer part
                        Text {
                            text: Math.floor(vehicle.odometer).toString()
                            color: "#ffffff"
                            font.pixelSize: 26
                            font.family: "Monospace"
                            font.bold: true
                        }

                        // Decimal dot
                        Text {
                            text: "."
                            color: themeColor
                            font.pixelSize: 26
                            font.family: "Monospace"
                            font.bold: true
                        }

                        // Decimal digit
                        Text {
                            text: Math.floor((vehicle.odometer % 1) * 10).toString()
                            color: themeColor
                            font.pixelSize: 26
                            font.family: "Monospace"
                            font.bold: true
                        }

                        // Unit
                        Text {
                            text: " km"
                            color: "#4e5366"
                            font.pixelSize: 13
                            font.bold: true
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 5
                        }
                    }
                }
            }

            // --- RIGHT PANEL: ENERGY & TEMPERATURE ---
            Rectangle {
                width: 250
                height: parent.height
                color: "#0a0c12"
                border.color: "#121522"
                border.width: 1
                radius: 12

                // Glow effect border for current theme
                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: "transparent"
                    border.color: themeColor
                    border.width: 1
                    opacity: 0.15
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 15

                    Text {
                        text: "BATTERIE & CLIM"
                        color: "#4e5366"
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.5
                    }

                    // Battery pack status card
                    Rectangle {
                        width: parent.width
                        height: 110
                        color: "#0d0f17"
                        border.color: "#161925"
                        border.width: 1
                        radius: 8

                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            Row {
                                width: parent.width
                                spacing: 10

                                // Battery pack graphic
                                Rectangle {
                                    width: 44; height: 22
                                    color: "transparent"
                                    border.color: "#39ff14"
                                    border.width: 2
                                    radius: 3
                                    anchors.verticalCenter: parent.verticalCenter

                                    // Battery level fill
                                    Rectangle {
                                        width: 36 * 0.87 // 87% capacity
                                        height: 14
                                        color: "#39ff14"
                                        radius: 1.5
                                        anchors.left: parent.left; anchors.leftMargin: 3
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    // Tip
                                    Rectangle {
                                        width: 3; height: 8
                                        color: "#39ff14"
                                        radius: 1
                                        anchors.left: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                Column {
                                    Text { text: "87 %"; color: "#ffffff"; font.pixelSize: 18; font.bold: true }
                                    Text { text: "AUTONOMIE: 185 km"; color: "#39ff14"; font.pixelSize: 8; font.bold: true }
                                }
                            }

                            Rectangle { width: parent.width; height: 1; color: "#161925" }

                            // Battery physical variables (V, A, Temp)
                            Row {
                                width: parent.width
                                Text { text: "TENSION DE PACK"; color: "#4e5366"; font.pixelSize: 9; font.bold: true }
                                Text { text: "395.2 V"; color: "#ffffff"; font.pixelSize: 10; font.bold: true; anchors.right: parent.right }
                            }

                            Row {
                                width: parent.width
                                Text { text: "COURANT DE DÉCH."; color: "#4e5366"; font.pixelSize: 9; font.bold: true }
                                Text { 
                                    // Amps = Power (kW) * 1000 / Voltage
                                    text: ((vehicle.power * 1000) / 395.2).toFixed(1) + " A"
                                    color: vehicle.power < 0 ? "#39ff14" : "#ffffff"
                                    font.pixelSize: 10; font.bold: true
                                    anchors.right: parent.right 
                                }
                            }

                            Row {
                                width: parent.width
                                Text { text: "TEMPÉRATURE PACK"; color: "#4e5366"; font.pixelSize: 9; font.bold: true }
                                Text { text: "31.4 °C"; color: "#ffffff"; font.pixelSize: 10; font.bold: true; anchors.right: parent.right }
                            }
                        }
                    }

                    // Dynamic Power bar graph
                    Column {
                        width: parent.width
                        spacing: 6
                        Text { text: "CONSOMMATION INSTANTANÉE"; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
                        
                        Rectangle {
                            width: parent.width; height: 14
                            color: "#111420"
                            radius: 4
                            border.color: "#1d2238"
                            border.width: 1

                            Rectangle {
                                width: (Math.abs(vehicle.power) / 35.0) * parent.width
                                height: parent.height
                                color: vehicle.power < 0 ? "#39ff14" : (vehicle.power > 25.0 ? "#ff007f" : "#00f0ff")
                                radius: 4
                                Behavior on width { NumberAnimation { duration: 50 } }
                            }
                        }
                    }

                    // INTERACTIVE VENTILATION CARD (For Open-Body Shuttle)
                    Rectangle {
                        width: parent.width
                        height: 120
                        color: "#0d0f17"
                        border.color: "#161925"
                        border.width: 1
                        radius: 8

                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            Text {
                                text: "VENTILATION PASSAGERS (NAVETTE OUVERTE)"
                                color: "#4e5366"
                                font.pixelSize: 9
                                font.bold: true
                            }

                            Row {
                                width: parent.width
                                height: 32
                                spacing: 2

                                // OFF Button
                                Rectangle {
                                    width: (parent.width - 8) / 5
                                    height: parent.height
                                    color: fanSpeed === 0 ? "rgba(255,0,127,0.1)" : "#10121a"
                                    border.color: fanSpeed === 0 ? "#ff007f" : "#1a1c24"
                                    border.width: 1
                                    radius: 4
                                    Text { anchors.centerIn: parent; text: "OFF"; color: fanSpeed === 0 ? "#ff007f" : "#4e5366"; font.pixelSize: 9; font.bold: true }
                                    MouseArea { anchors.fill: parent; onClicked: fanSpeed = 0 }
                                }

                                // Speed 1 Button
                                Rectangle {
                                    width: (parent.width - 8) / 5
                                    height: parent.height
                                    color: fanSpeed === 1 ? "rgba(0,240,255,0.1)" : "#10121a"
                                    border.color: fanSpeed === 1 ? themeColor : "#1a1c24"
                                    border.width: 1
                                    radius: 4
                                    Text { anchors.centerIn: parent; text: "1"; color: fanSpeed === 1 ? themeColor : "#4e5366"; font.pixelSize: 9; font.bold: true }
                                    MouseArea { anchors.fill: parent; onClicked: fanSpeed = 1 }
                                }

                                // Speed 2 Button
                                Rectangle {
                                    width: (parent.width - 8) / 5
                                    height: parent.height
                                    color: fanSpeed === 2 ? "rgba(0,240,255,0.1)" : "#10121a"
                                    border.color: fanSpeed === 2 ? themeColor : "#1a1c24"
                                    border.width: 1
                                    radius: 4
                                    Text { anchors.centerIn: parent; text: "2"; color: fanSpeed === 2 ? themeColor : "#4e5366"; font.pixelSize: 9; font.bold: true }
                                    MouseArea { anchors.fill: parent; onClicked: fanSpeed = 2 }
                                }

                                // Speed 3 Button
                                Rectangle {
                                    width: (parent.width - 8) / 5
                                    height: parent.height
                                    color: fanSpeed === 3 ? "rgba(0,240,255,0.1)" : "#10121a"
                                    border.color: fanSpeed === 3 ? themeColor : "#1a1c24"
                                    border.width: 1
                                    radius: 4
                                    Text { anchors.centerIn: parent; text: "3"; color: fanSpeed === 3 ? themeColor : "#4e5366"; font.pixelSize: 9; font.bold: true }
                                    MouseArea { anchors.fill: parent; onClicked: fanSpeed = 3 }
                                }

                                // AUTO Button
                                Rectangle {
                                    width: (parent.width - 8) / 5
                                    height: parent.height
                                    color: fanSpeed === 4 ? "rgba(57,255,20,0.1)" : "#10121a"
                                    border.color: fanSpeed === 4 ? "#39ff14" : "#1a1c24"
                                    border.width: 1
                                    radius: 4
                                    Text { anchors.centerIn: parent; text: "AUTO"; color: fanSpeed === 4 ? "#39ff14" : "#4e5366"; font.pixelSize: 9; font.bold: true }
                                    MouseArea { anchors.fill: parent; onClicked: fanSpeed = 4 }
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: 10

                                Text {
                                    text: "CONSOMMATION AUXILIAIRE :"
                                    color: "#4e5366"
                                    font.pixelSize: 9
                                    font.bold: true
                                }

                                Text {
                                    text: {
                                        if (fanSpeed === 0) return "0 W (ÉTEINT)"
                                        if (fanSpeed === 1) return "80 W (DOUX)"
                                        if (fanSpeed === 2) return "200 W (MOYEN)"
                                        if (fanSpeed === 3) return "450 W (MAX)"
                                        return "180 W (MODULÉ)"
                                    }
                                    color: fanSpeed === 0 ? "#ff007f" : (fanSpeed === 4 ? "#39ff14" : themeColor)
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                            }
                        }
                    }

                    // Static Shuttle Info Details
                    Column {
                        width: parent.width
                        spacing: 4
                        Text { text: "ESTIMATIONS TRAJET"; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
                        Row {
                            width: parent.width
                            Text { text: "Consommation Moy."; color: "#4e5366"; font.pixelSize: 9 }
                            Text { text: "14.2 kWh / 100km"; color: "#ffffff"; font.pixelSize: 10; font.bold: true; anchors.right: parent.right }
                        }
                        Row {
                            width: parent.width
                            Text { text: "Capacité Batterie"; color: "#4e5366"; font.pixelSize: 9 }
                            Text { text: "30.0 kWh (LFP)"; color: "#ffffff"; font.pixelSize: 10; font.bold: true; anchors.right: parent.right }
                        }
                    }
                }
            }
        }
    }
}
