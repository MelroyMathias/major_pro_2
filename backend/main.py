import cv2
import threading
import time
import os
import json
import numpy as np
from flask import Flask, Response, jsonify, send_from_directory
from flask_cors import CORS

from weapon import WeaponDetector
from posture import PostureAnalyzer
from activity import ActivityDetector
from decision import DecisionEngine
from alert import AlertSystem

app = Flask(__name__)
CORS(app)

# Use absolute path for captures
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CAPTURES_DIR = os.path.join(BASE_DIR, "captures")

if not os.path.exists(CAPTURES_DIR):
    os.makedirs(CAPTURES_DIR)

# Serve captures directory
@app.route('/captures/<path:filename>')
def get_capture(filename):
    return send_from_directory(CAPTURES_DIR, filename)

output_frame = None
lock = threading.Lock()

current_status = {
    "threat": "LOW",
    "weapon": "None",
    "activity": "none",
    "posture": "normal"
}


def processing_loop():
    global output_frame, current_status

    try:
        print("Loading models...")

        weapon_detector = WeaponDetector("yolov8n.pt")
        posture_analyzer = PostureAnalyzer("yolov8n-pose.pt")
        activity_detector = ActivityDetector()
        decision_engine = DecisionEngine()
        alert_system = AlertSystem()

        print("Opening camera...")
        cap = cv2.VideoCapture(0, cv2.CAP_DSHOW)

        if not cap.isOpened():
            print("Camera error")
            return

        print("System running...")

        weapon_persistence_counter = 0
        last_weapon_type = "None"
        last_alert_time = 0
        threat_history = []

        while True:
            ret, frame = cap.read()

            if not ret:
                continue

            # Detection
            weapon_detections, person_detections = weapon_detector.detect_all(frame)

            # Weapon smoothing
            if len(weapon_detections) > 0:
                weapon_persistence_counter = 5
                last_weapon_type = weapon_detections[0]["type"]
            elif weapon_persistence_counter > 0:
                weapon_persistence_counter -= 1

            weapon_found = weapon_persistence_counter > 0
            weapon_type = last_weapon_type if weapon_found else "None"

            # Posture
            posture = "normal"
            if person_detections:
                posture = posture_analyzer.analyze(frame, person_detections[0]["bbox"])

            # Activity
            activity = activity_detector.detect(person_detections, frame)

            # Decision
            current_threat = decision_engine.evaluate(weapon_found, posture, activity)

            threat_history.append(current_threat)
            if len(threat_history) > 5:
                threat_history.pop(0)

            threat_level = max(set(threat_history), key=threat_history.count)

            # Update status
            current_status["threat"] = threat_level
            current_status["weapon"] = weapon_type
            current_status["activity"] = activity
            current_status["posture"] = posture

            # Alert
            current_time = time.time()
            if threat_level in ["HIGH", "MEDIUM"] and (current_time - last_alert_time > 3):
                alert_system.process_alert(frame, weapon_type, posture, activity, threat_level)
                last_alert_time = current_time

            # Draw boxes
            for d in weapon_detections:
                x1, y1, x2, y2 = d["bbox"]
                cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 0, 255), 2)

            for p in person_detections:
                x1, y1, x2, y2 = p["bbox"]
                cv2.rectangle(frame, (x1, y1), (x2, y2), (255, 0, 0), 1)

            cv2.putText(frame, f"Threat: {threat_level}", (10, 30),
                        cv2.FONT_HERSHEY_SIMPLEX, 1,
                        (0, 0, 255) if threat_level == "HIGH" else (0, 255, 0), 2)

            with lock:
                output_frame = frame.copy()

            time.sleep(0.03)

    except Exception as e:
        print("ERROR:", e)


def generate():
    global output_frame

    while True:
        time.sleep(0.1)

        with lock:
            if output_frame is not None:
                flag, encodedImage = cv2.imencode(".jpg", output_frame)

                if not flag:
                    continue

                yield (b'--frame\r\n'
                       b'Content-Type: image/jpeg\r\n\r\n' +
                       bytearray(encodedImage) +
                       b'\r\n')


@app.route("/")
def index():
    return "Backend Running"


@app.route("/video")
def video():
    response = Response(generate(), mimetype='multipart/x-mixed-replace; boundary=frame')
    response.headers.add("Access-Control-Allow-Origin", "*")
    return response


@app.route("/status")
def status():
    return jsonify(current_status)


@app.route("/alerts")
def alerts():
    try:
        if os.path.exists("alerts.json"):
            with open("alerts.json", "r") as f:
                alerts_data = json.load(f)
                return jsonify(alerts_data[::-1])  # reverse to show newest first
        return jsonify([])
    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    t = threading.Thread(target=processing_loop)
    t.daemon = True
    t.start()

    print("Server running at http://192.168.1.2:5000/")
    app.run(host="0.0.0.0", port=5000)