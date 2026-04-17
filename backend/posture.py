from ultralytics import YOLO
import numpy as np

class PostureAnalyzer:
    def __init__(self, model_path="yolov8n-pose.pt"):
        try:
            self.model = YOLO(model_path)
        except Exception as e:
            print(f"Error loading Pose model: {e}")
            self.model = None

    def analyze(self, frame, person_bbox=None):
        if self.model is None:
            return "normal"

        results = self.model(frame, verbose=False)

        for result in results:
            if result.keypoints is None:
                continue

            for kpts in result.keypoints.data:
                kpts = kpts.cpu().numpy()

                # Key points
                l_shoulder = kpts[5]
                r_shoulder = kpts[6]
                l_wrist = kpts[9]
                r_wrist = kpts[10]

                # Confidence check
                if l_wrist[2] < 0.5 and r_wrist[2] < 0.5:
                    return "normal"

                # ✅ STRICT AIMING CONDITION (FIXED)
                # Wrist must be horizontal + far from shoulder
                if (
                    abs(l_wrist[1] - l_shoulder[1]) < 20 and
                    abs(l_wrist[0] - l_shoulder[0]) > 120 and
                    l_wrist[2] > 0.5
                ) or (
                    abs(r_wrist[1] - r_shoulder[1]) < 20 and
                    abs(r_wrist[0] - r_shoulder[0]) > 120 and
                    r_wrist[2] > 0.5
                ):
                    return "aiming"

        return "normal"