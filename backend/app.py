import cv2
import time
from ultralytics import YOLO
from send_detection import send_detection

# 🔥 Load YOLO model
model = YOLO("yolov8n.pt")

# 🎥 Camera
cap = cv2.VideoCapture(0)

# ⏱ Cooldown
last_alert_time = 0
ALERT_COOLDOWN = 5  # seconds

# 🎯 STRICT threshold (VERY IMPORTANT)
CONFIDENCE_THRESHOLD = 0.85

while True:
    ret, frame = cap.read()
    if not ret:
        break

    results = model(frame)

    detected = False

    for result in results:
        for box in result.boxes:
            conf = float(box.conf[0])
            cls = int(box.cls[0])
            label = model.names[cls]

            # 🔥 IMPORTANT: YOLO default DOES NOT HAVE GUN
            # So we avoid false detection by ONLY allowing high confidence
            if conf > CONFIDENCE_THRESHOLD:

                # Draw box anyway (for demo)
                x1, y1, x2, y2 = map(int, box.xyxy[0])

                cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
                cv2.putText(frame, f"{label} {conf:.2f}",
                            (x1, y1 - 10),
                            cv2.FONT_HERSHEY_SIMPLEX,
                            0.7, (0, 255, 0), 2)

                # 🚨 Only treat as "weapon" if label looks suspicious
                if label.lower() in ["knife", "scissors"]:  # safer classes
                    detected = True

    # 🚨 SEND ALERT WITH COOLDOWN
    current_time = time.time()

    if detected and (current_time - last_alert_time > ALERT_COOLDOWN):
        send_detection(
            weapon="Suspicious Object",
            threatLevel="HIGH",
            area="Live Camera"
        )
        print("🚨 ALERT SENT")
        last_alert_time = current_time

    cv2.imshow("Live Weapon Detection", frame)

    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()