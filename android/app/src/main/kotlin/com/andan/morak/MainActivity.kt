package com.andan.morak

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var locationChannel: MethodChannel? = null
    private var locationPermissionResult: MethodChannel.Result? = null
    private val locationRequestCode = 13021

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        locationChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "morak/location_permission")
        locationChannel?.setMethodCallHandler { call, result ->
            if (call.method != "requestForegroundLocation") {
                result.notImplemented()
            } else if (hasLocationAccess()) {
                result.success(true)
            } else if (locationPermissionResult != null) {
                result.error("permission_request_pending", "A location permission request is already open.", null)
            } else {
                locationPermissionResult = result
                // Android 12+ requires coarse and fine to be requested together.
                requestPermissions(arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION,
                    Manifest.permission.ACCESS_FINE_LOCATION), locationRequestCode)
            }
        }
    }

    private fun hasLocationAccess(): Boolean = Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
        checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
        checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == locationRequestCode) {
            locationPermissionResult?.success(hasLocationAccess())
            locationPermissionResult = null
        }
    }

    override fun onDestroy() {
        locationPermissionResult?.success(false)
        locationPermissionResult = null
        locationChannel?.setMethodCallHandler(null)
        locationChannel = null
        super.onDestroy()
    }
}
