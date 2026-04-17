from flask import Flask, Response
from flask_cors import CORS
import cv2
from ultralytics import YOLO
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timezone
import time

# -------------------- FLASK --------------------
app = Flask(__name__)
CORS(app)

# -------------------- FIREBASE --------------------
cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# -------------------- YOLO MODEL --------------------
# using pretrained model (general objects)
model = YOLO("yolov8n.pt")

# -------------------- CAMERA --------------------
cap = cv2.VideoCapture(0)

last_sent = 0

def send_detection():
    db.collection("detections").add({
        "weapon": "Gun",
        "threatLevel": "HIGH",
        "area": "Live Camera",
        "cameraLat": 12.9716,
        "cameraLon": 77.5946,
        "alertSent": False,
        "timestamp": datetime.now(timezone.utc)
    })
    print("🚨 Detection sent!")

# 🔥 detect object (simulate weapon using 'cell phone')
def detect_weapon(frame):
    results = model(frame)

    for r in results:
        for box in r.boxes:
            cls = int(box.cls[0])
            label = model.names[cls]

            # 🔥 Use "cell phone" as demo weapon
            if label == "cell phone":
                return True, box.xyxy[0]

    return False, None


def generate_frames():
    global last_sent

    while True:
        success, frame = cap.read()
        if not success:
            break

        detected, box = detect_weapon(frame)

        current_time = time.time()

        if detected and (current_time - last_sent > 5):
            send_detection()
            last_sent = current_time

        # 🔴 Draw bounding box
        if detected and box is not None:
            x1, y1, x2, y2 = map(int, box)
            cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 0, 255), 2)
            cv2.putText(frame, "Weapon Detected", (x1, y1 - 10),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 0, 255), 2)

        # encode frame
        ret, buffer = cv2.imencode('.jpg', frame)
        frame_bytes = buffer.tobytes()

        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n')


@app.route('/video')
def video():
    return Response(generate_frames(),
                    mimetype='multipart/x-mixed-replace; boundary=frame')


if __name__ == "__main__":
    print("🎥 Running YOLO Detection Server...")
    app.run(host='0.0.0.0', port=5000)