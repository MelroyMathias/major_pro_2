from ultralytics import YOLO

class WeaponDetector:
    def __init__(self, model_path="yolov8n.pt"):
        try:
            self.model = YOLO(model_path)
            self.classes = self.model.names
        except Exception as e:
            print(f"Error loading YOLO model: {e}")
            self.model = None

    def detect_all(self, frame):
        if self.model is None:
            return [], []

        WEAPON_THRESHOLD = 0.6
        PERSON_THRESHOLD = 0.5

        results = self.model(frame, verbose=False)

        weapon_detections = []
        persons = []

        for result in results:
            for box in result.boxes:
                conf = float(box.conf[0])
                cls = int(box.cls[0])
                label = self.classes[cls].lower()

                x1, y1, x2, y2 = map(int, box.xyxy[0])

                # ❌ Ignore small noisy detections
                width = x2 - x1
                height = y2 - y1
                if width < 40 or height < 40:
                    continue

                # 👤 PERSON DETECTION
                if label == "person" and conf > PERSON_THRESHOLD:
                    persons.append({
                        "id": 0,
                        "bbox": (x1, y1, x2, y2),
                        "confidence": conf
                    })

                # 🔥 WEAPON DETECTION (FIXED — NO GUN)
                weapon_type = None

                if label == "knife" and conf > WEAPON_THRESHOLD:
                    weapon_type = "knife"

                elif label == "scissors" and conf > WEAPON_THRESHOLD:
                    weapon_type = "sharp object"

                elif label in ["baseball bat", "stick"] and conf > WEAPON_THRESHOLD:
                    weapon_type = "rod / stick"

                # ❌ REMOVED GUN (to avoid wrong detection)

                if weapon_type:
                    weapon_detections.append({
                        "type": weapon_type,
                        "confidence": conf,
                        "bbox": (x1, y1, x2, y2)
                    })

        return weapon_detections, persons