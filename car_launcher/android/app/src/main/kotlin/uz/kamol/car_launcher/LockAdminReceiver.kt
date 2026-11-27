package uz.kamol.car_launcher

import android.app.admin.DeviceAdminReceiver

/** Device admin with the single "force-lock" policy (DevicePolicyManager.lockNow). */
class LockAdminReceiver : DeviceAdminReceiver()
