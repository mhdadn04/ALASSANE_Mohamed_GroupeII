# Tableau de Bord - Navette Électrique 8 Places (Groupe II - Frontend)

Ce projet contient le prototype d'interface de tableau de bord (dashboard) pour une navette électrique urbaine de 8 places, développé dans le cadre du **Challenge Technique (Groupe II)**.

L'objectif principal est de concevoir un écran fonctionnel fluide, hautement lisible et modulaire, tournant sous un environnement embarqué (cible : Raspberry Pi 4 avec écran 10" - 1280 × 800) et simulant les comportements physiques du véhicule de façon réaliste (inertie, frottements, freinage, récupération d'énergie).

---

## 🚀 Architecture & Modularité

Conformément aux contraintes d'architecture du challenge, les données et la logique d'affichage sont **strictement isolées** :

```
┌────────────────────────────────────────────────────────┐
│               SIMULATION PHYSIQUE (Python)              │
│                [src/vehicle_simulator.py]              │
│                                                        │
│ - Boucle de simulation (physique Euler @60Hz)          │
│ - Propriétés Qt (speed, odometer, pedal, brake, power)│
│ - Émissions de signaux lors des changements            │
└───────────────────────────┬────────────────────────────┘
                            │ (Liaison / PySide6 Context)
                            ▼
┌────────────────────────────────────────────────────────┐
│                RENDU & INTERFACE (QML)                 │
│                   [src/dashboard.qml]                  │
│                                                        │
│ - Fenêtre principale 1280x800                          │
│ - Cadran de vitesse vectoriel (Canvas dynamique Glow)   │
│ - Odomètre numérique avec gestion de décimale           │
│ - Commandes tactiles & Clavier (Accélérateur / Frein)  │
└────────────────────────────────────────────────────────┘
```

**Pourquoi ce choix ?**
- **Séparation nette** : L'interface QML ne contient aucune logique de calcul physique ou de bus de données. Elle se contente de lire les propriétés Qt standard (`@Property`) et de s'abonner aux signaux notifiés par l'objet `vehicle`.
- **Remplacement CAN trivial** : Pour brancher l'application sur le vrai bus CAN de la navette (via un transceiver CAN connecté au port SPI d'une Raspberry Pi et SocketCAN), il suffit d'instancier un adaptateur CAN exposant la même API que le simulateur. **Le code QML de l'interface graphique reste rigoureusement inchangé (0 ligne modifiée).**

### 🔌 Remplacement par le flux CAN réel (Exemple d'intégration)

Voici comment s'implémenterait le composant de lecture CAN réel (`src/vehicle_can_reader.py`) :

```python
import can
from PySide6.QtCore import QObject, Signal, Property, QThread

class CANListenerThread(QThread):
    speed_received = Signal(float)
    odometer_received = Signal(float)
    power_received = Signal(float)

    def run(self):
        # Connexion à l'interface SocketCAN (ex: interface can0 configurée sous Linux)
        try:
            bus = can.interface.Bus(channel='can0', bustype='socketcan')
            for msg in bus:
                # Filtrage et décodage des trames selon la table d'adressage CAN
                if msg.arbitration_id == 0x101:  # ID Vitesse / Odomètre
                    # Exemple: Vitesse sur 2 octets en 100e de km/h
                    raw_speed = (msg.data[0] << 8) | msg.data[1]
                    self.speed_received.emit(raw_speed / 100.0)
                elif msg.arbitration_id == 0x102: # ID Batterie / Puissance
                    # Puissance signée (complément à 2) en 10e de kW
                    power_kw = int.from_bytes(msg.data[0:2], byteorder='big', signed=True) / 10.0
                    self.power_received.emit(power_kw)
        except Exception as e:
            print("Erreur SocketCAN:", e)

class VehicleCANReader(QObject):
    speedChanged = Signal(float)
    odometerChanged = Signal(float)
    powerChanged = Signal(float)
    # ... autres signaux identiques au simulateur ...

    def __init__(self):
        super().__init__()
        self._speed = 0.0
        self._odometer = 124.0
        self._power = 0.0

        # Lancement du thread d'écoute réseau CAN
        self.thread = CANListenerThread()
        self.thread.speed_received.connect(self.on_speed_rx)
        self.thread.power_received.connect(self.on_power_rx)
        self.thread.start()

    def on_speed_rx(self, val):
        if self._speed != val:
            self._speed = val
            self.speedChanged.emit(val)

    def on_power_rx(self, val):
        if self._power != val:
            self._power = val
            self.powerChanged.emit(val)

    @Property(float, notify=speedChanged)
    def speed(self): return self._speed

    @Property(float, notify=powerChanged)
    def power(self): return self._power
    
    # ... autres propriétés Qt exposées identiquement ...
```

Dans `src/main.py`, la transition consiste simplement à remplacer la source de données :

```diff
-from vehicle_simulator import VehicleSimulator
-vehicle = VehicleSimulator()
+from vehicle_can_reader import VehicleCANReader
+vehicle = VehicleCANReader()

# La liaison avec QML reste strictement identique :
engine.rootContext().setContextProperty("vehicle", vehicle)
```

---

## 🛠️ Modélisation Physique (Réalisme)

Pour éviter un rendu purement artificiel ou "trop IA", le simulateur intègre un modèle de forces physiques simplifié mais cohérent avec les spécifications de la navette :
- **Inertie** : Le véhicule pèse environ 1 500 kg. L'accélération de 0 à 50 km/h prend ~9 secondes à pleine charge de pédale.
- **Roue libre (Coasting)** : Lorsque l'accélérateur est relâché, le véhicule subit une faible friction (décélération très lente sur ~25s).
- **Freinage** : Le freinage applique une décélération forte et proportionnelle à la pression sur la pédale de frein.
- **Flux d'énergie (kW)** : 
  - En accélération, la consommation augmente en fonction de la vitesse et de la pédale (jusqu'à 35 kW).
  - En décélération et freinage, l'énergie est récupérée par le moteur (courbe de récupération négative jusqu'à -15 kW), simulant le freinage régénératif et rechargeant la batterie.

---

## 📦 Installation & Prérequis

L'application requiert **Python 3** et la bibliothèque officielle **PySide6** (Qt pour Python).

### 1. Installation des dépendances

Sous Linux (Ubuntu/Debian/Raspberry Pi OS) :

```bash
# Création d'un environnement virtuel (recommandé)
python3 -m venv .venv
source .venv/bin/activate

# Installation de PySide6
pip install --upgrade pip
pip install PySide6
```

---

## 🚦 Lancement de l'application

Pour lancer l'application à partir du dossier racine du projet, exécutez :

```bash
python3 src/main.py
```

---

## 🎮 Commandes & Interactions

Le tableau de bord est entièrement interactif. Vous pouvez piloter le véhicule de deux manières :

### 1. Contrôle à la Souris / Tactile (Écran 10")
- **Accélérateur (Pedal)** : Faites glisser la jauge bleue horizontale sur le panneau de gauche pour accélérer (de 0 à 100 %).
- **Frein (Brake)** : Faites glisser la jauge rouge horizontale pour freiner (de 0 à 100 %).
- **Boutons clignotants et phares** : Cliquez sur les symboles `◀`, `▶`, `⚠️` ou `⛯` en haut pour activer/désactiver les indicateurs lumineux.

### 2. Raccourcis Clavier (Simulateur de conduite)
- **Flèche du HAUT `[↑]` (Maintenue)** : Accélérateur à $100\%$ (revient à $0\%$ au relâchement).
- **Flèche du BAS `[↓]` (Maintenue)** : Frein à $100\%$ (revient à $0\%$ au relâchement).
- **Flèche GAUCHE `[←]`** : Activer/Désactiver le clignotant gauche.
- **Flèche DROITE `[→]`** : Activer/Désactiver le clignotant droit.

---

## 🎨 Design & Rendu Visuel
- **Résolution fixe 1280x800** : S'adapte parfaitement à l'écran tactile cible de 10 pouces sans déformation.
- **Thème sombre "Electric Cyberpunk"** : Les couleurs principales combinent un fond noir profond, un bleu cyan électrique pour la puissance, un vert émeraude pour la charge régénérative, et une aiguille rose magenta rétro-éclairée.
- **Fluidité 60 FPS** : La boucle physique est cadencée à 16 ms et le dessin vectoriel du cadran par `Canvas` utilise l'accélération GPU disponible sur la Raspberry Pi 4.
