class DecisionEngine:
    def evaluate(self, weapon_detected, posture, activity):
        """
        FINAL LOGIC (STABLE + CORRECT)

        HIGH   → Weapon + Aiming posture
        MEDIUM → Weapon only
        LOW    → No weapon
        """

        # ✅ HIGH THREAT
        if weapon_detected and posture == "aiming":
            return "HIGH"

        # ✅ MEDIUM THREAT
        elif weapon_detected:
            return "MEDIUM"

        # ✅ LOW THREAT
        return "LOW"