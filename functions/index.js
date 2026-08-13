const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.database();

exports.enforceSafetyCutoffs = onSchedule(
  {
    schedule: "every 1 minutes",
    timeZone: "Asia/Colombo",
  },
  async () => {
    const now = Date.now();
    const devicesSnapshot = await db.ref("devices").get();
    const devices = devicesSnapshot.val() || {};

    await Promise.all(
      Object.entries(devices).map(async ([deviceId, device]) => {
        if (
          device.type !== "safetyCritical" ||
          device.status !== "on" ||
          !Number.isInteger(device.turnedOnAt) ||
          !Number.isInteger(device.maxOnDurationSeconds)
        ) {
          return;
        }

        const durationSeconds = Math.max(
          0,
          Math.round((now - device.turnedOnAt) / 1000),
        );
        if (durationSeconds < device.maxOnDurationSeconds) {
          return;
        }

        const deviceRef = db.ref(`devices/${deviceId}`);
        const currentSnapshot = await deviceRef.get();
        const current = currentSnapshot.val();
        if (
          !current ||
          current.status !== "on" ||
          current.turnedOnAt !== device.turnedOnAt
        ) {
          return;
        }

        const floorSnapshot = await db.ref(`floors/${current.floorId}`).get();
        const floor = floorSnapshot.val() || {};
        const usageLogRef = db.ref(`usageLogs/${deviceId}`).push();
        const alertRef = db.ref("alerts").push();

        await Promise.all([
          deviceRef.update({
            status: "off",
            turnedOnAt: null,
            totalOnSeconds: (current.totalOnSeconds || 0) + durationSeconds,
          }),
          usageLogRef.set({
            endedAt: now,
            durationSeconds,
          }),
          alertRef.set({
            deviceId,
            deviceName: current.name || "Safety device",
            floorName: floor.name || "Unknown floor",
            status: "off",
            severity: "safetyCutoff",
            message: `${floor.name || "Unknown floor"}: ${current.name || "Safety device"} was switched off after reaching its safety limit.`,
            timestamp: now,
          }),
        ]);
      }),
    );
  },
);
