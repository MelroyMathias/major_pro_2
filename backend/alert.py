import os
import cv2
import json
import time
from datetime import datetime
import firebase_admin
from firebase_admin import credentials, firestore

class AlertSystem:
    def __init__(self, capture_dir=None, log_file=None):
        # ✅ Use absolute paths to be safe
        base_dir = os.path.dirname(os.path.abspath(__file__))
        self.capture_dir = capture_dir or os.path.join(base_dir, "captures")
        self.log_file = log_file or os.path.join(base_dir, "alerts.json")
        self.last_alert_time = 0
        self.cooldown = 5  # seconds

        if not os.path.exists(self.capture_dir):
            os.makedirs(self.capture_dir)

        # ✅ Initialize Firebase
        self.db = None
        try:
            # Look for service account key in current dir or parent dir
            key_path = "serviceAccountKey.json"
            if not os.path.exists(key_path):
                key_path = os.path.join("backend", "serviceAccountKey.json")
            
            if os.path.exists(key_path):
                cred = credentials.Certificate(key_path)
                if not firebase_admin._apps:
                    firebase_admin.initialize_app(cred)
                self.db = firestore.client()
                print("✅ Firebase Admin initialized")
            else:
                print("⚠️ serviceAccountKey.json not found. Firebase alerts disabled.")
        except Exception as e:
            print(f"❌ Firebase initialization error: {e}")

    def process_alert(self, frame, weapon, posture, activity, threat_level, area="Camera 1"):
        if threat_level not in ["HIGH", "MEDIUM"]:
            return False

        current_time = time.time()
        if current_time - self.last_alert_time < self.cooldown:
            return False

        timestamp_str = datetime.now().strftime("%Y%m%d_%H%M%S")
        image_name = f"alert_{timestamp_str}.jpg"
        image_path = os.path.join(self.capture_dir, image_name)

        cv2.imwrite(image_path, frame)

        alert_data = {
            "weapon": weapon,
            "posture": posture,
            "activity": activity,
            "threatLevel": threat_level,
            "timestamp": datetime.now().isoformat(),
            "image_path": image_path,
            "area": area
        }

        self._log_alert(alert_data)
        
        # ✅ Send to Firebase
        if self.db:
            try:
                # 1. Add to detections collection
                self.db.collection("detections").add({
                    "weapon": weapon,
                    "threatLevel": threat_level,
                    "area": area,
                    "timestamp": firestore.SERVER_TIMESTAMP,
                    "image_path": image_path,
                    "posture": posture,
                    "activity": activity
                })

                # 2. Notify Guards (add to alerts collection)
                # Query all online guards
                users_ref = self.db.collection("users")
                online_guards = users_ref.where("isOnline", "==", True).stream()
                
                guards_notified = 0
                for guard in online_guards:
                    self.db.collection("alerts").add({
                        "targetGuardId": guard.id,
                        "type": "priority" if threat_level == "HIGH" else "normal",
                        "status": "pending",
                        "threatLevel": threat_level,
                        "weapon": weapon,
                        "timestamp": firestore.SERVER_TIMESTAMP,
                        "area": area,
                        "image_name": image_name, # 🔥 Simplified field
                        "image_path": image_path  # Keep for compatibility
                    })
                    guards_notified += 1
                
                if guards_notified > 0:
                    print(f"🚀 Firebase alerts sent to {guards_notified} guards for {threat_level} threat")
                else:
                    print("⚠️ No online guards found to notify.")
            except Exception as e:
                print(f"❌ Error sending to Firebase: {e}")

        self.last_alert_time = current_time
        print(f"🚨 ALERT: {threat_level} | {weapon}, {posture}, {activity}")

        return True

    def _log_alert(self, alert_data):
        alerts = []

        # ✅ SAFE READ
        if os.path.exists(self.log_file):
            try:
                with open(self.log_file, 'r') as f:
                    alerts = json.load(f)
                    if not isinstance(alerts, list):
                        alerts = []
            except:
                alerts = []

        alerts.append(alert_data)

        # ✅ LIMIT SIZE (keep last 100 alerts)
        alerts = alerts[-100:]

        with open(self.log_file, 'w') as f:
            json.dump(alerts, f, indent=4)