import time
import numpy as np

class ActivityDetector:
    def __init__(self):
        self.prev_persons = []
        self.last_check_time = time.time()

        self.running_threshold = 500
        self.fighting_distance = 120
        self.movement_threshold = 80  # for fight motion

    def detect(self, persons, frame):
        current_time = time.time()
        dt = current_time - self.last_check_time
        if dt == 0:
            dt = 0.01

        activity = "none"

        # ----------------------------
        # 1. RUNNING DETECTION
        # ----------------------------
        for i, p in enumerate(persons):
            if i < len(self.prev_persons):
                prev_p = self.prev_persons[i]

                curr_center = self._get_center(p['bbox'])
                prev_center = self._get_center(prev_p['bbox'])

                dist = np.linalg.norm(np.array(curr_center) - np.array(prev_center))
                speed = dist / dt

                if speed > self.running_threshold:
                    activity = "running"
                    break

        # ----------------------------
        # 2. FIGHTING DETECTION (Improved)
        # ----------------------------
        if len(persons) >= 2 and activity == "none":
            for i in range(len(persons)):
                for j in range(i + 1, len(persons)):

                    c1 = self._get_center(persons[i]['bbox'])
                    c2 = self._get_center(persons[j]['bbox'])

                    dist = np.linalg.norm(np.array(c1) - np.array(c2))

                    if dist < self.fighting_distance:
                        # check if BOTH are moving (not just standing)
                        if i < len(self.prev_persons) and j < len(self.prev_persons):

                            prev_c1 = self._get_center(self.prev_persons[i]['bbox'])
                            prev_c2 = self._get_center(self.prev_persons[j]['bbox'])

                            move1 = np.linalg.norm(np.array(c1) - np.array(prev_c1))
                            move2 = np.linalg.norm(np.array(c2) - np.array(prev_c2))

                            if move1 > self.movement_threshold and move2 > self.movement_threshold:
                                activity = "fighting"
                                break

                if activity != "none":
                    break

        # ----------------------------
        # UPDATE STATE
        # ----------------------------
        self.prev_persons = persons
        self.last_check_time = current_time

        return activity

    def _get_center(self, bbox):
        x1, y1, x2, y2 = bbox
        return ((x1 + x2) / 2, (y1 + y2) / 2)