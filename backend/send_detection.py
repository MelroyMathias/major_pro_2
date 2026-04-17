import cv2
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timezone
import time

# 🔑 Firebase setup
cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)

db = firestore.client()

# 🎥 Open camera (0 = webcam)
cap = cv2.VideoCapture(0)

# ⏱ Control sending frequency
last_sent = 0

# 🚨 Function to send detection to Firebase
def send_detection():
    db.collection("detections").add({
        "weapon": "Gun",
        "threatLevel": "HIGH",
        "area": "Live Camera",
        "cameraLat": 12.9716,   # 🔥 Example (change later)
        "cameraLon": 77.5946,
        "alertSent": False,
        "timestamp": datetime.now(timezone.utc)
    })
    print("🚨 Detection sent!")

print("🎥 Starting Live Detection... Press ESC to stop")

while True:
    ret, frame = cap.read()
    if not ret:
        break

    # 🔴 SIMULATION (for now)
    detected = True  # later replace with YOLO

    current_time = time.time()

    # ⏱ Send every 5 seconds only
    if detected and (current_time - last_sent > 5):
        send_detection()
        last_sent = current_time

    # 🔴 Draw detection text
    if detected:
        cv2.putText(
            frame,
            "Gun Detected",
            (50, 50),
            cv2.FONT_HERSHEY_SIMPLEX,
            1,
            (0, 0, 255),
            2
        )

    # 🎥 Show video
    cv2.imshow("Live Weapon Detection", frame)

    # ❌ Exit on ESC key
    if cv2.waitKey(1) == 27:
        break

# 🧹 Cleanup
cap.release()
cv2.destroyAllWindows()