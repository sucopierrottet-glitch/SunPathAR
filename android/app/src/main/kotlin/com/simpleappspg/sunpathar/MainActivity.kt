package com.simpleappspg.sunpathar

import android.Manifest
import android.annotation.SuppressLint
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.SurfaceTexture
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CaptureRequest
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.media.ImageReader
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.HandlerThread
import android.provider.MediaStore
import android.util.Size
import android.view.Surface
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.io.File
import java.io.FileOutputStream
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.sqrt

class MainActivity : FlutterActivity(), SensorEventListener {
    private val CHANNEL = "com.simpleappspg.sensors/data"
    private val REQ_CAMERA = 1001
    private val REQ_LOCATION = 1002

    private var sensorManager: SensorManager? = null
    private var locationManager: LocationManager? = null
    private var flutterRenderer: TextureRegistry? = null

    private var accel = FloatArray(3) { 0f }
    private var gyro = FloatArray(3) { 0f }
    private var mag = FloatArray(3) { 0f }
    private var rotationVec = FloatArray(5) { 0f }
    private var hasRotationVec = false
    private var pressure: Float = 1013.25f
    private var lightLux: Float = 450f
    private var hasBarometer = false
    private var hasLight = false
    private var hasMag = false

    // Camera2 fields
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var surfaceEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var previewSurface: Surface? = null
    private var imageReader: ImageReader? = null
    private var currentSensorOrientation: Int = 90
    private var currentIsFront: Boolean = false
    private var cameraThread: HandlerThread? = null
    private var cameraHandler: Handler? = null
    private var pendingCameraResult: MethodChannel.Result? = null
    private var pendingCameraLens: String = "back"
    private var pendingCaptureResult: MethodChannel.Result? = null

    // Location fields
    private var pendingLocationResult: MethodChannel.Result? = null
    private var lastKnownLat: Double? = null
    private var lastKnownLon: Double? = null
    private var lastKnownAlt: Double = 0.0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterRenderer = flutterEngine.renderer
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        locationManager = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        registerSensors()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSensorSnapshot" -> {
                    result.success(buildSensorSnapshot())
                }
                "startCamera" -> {
                    val lens = call.argument<String>("lens") ?: "back"
                    handleStartCamera(lens, result)
                }
                "capturePhoto" -> {
                    handleCapturePhoto(result)
                }
                "stopCamera" -> {
                    closeCamera()
                    result.success(true)
                }
                "getGpsLocation" -> {
                    handleGetGpsLocation(result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun buildSensorSnapshot(): Map<String, Any> {
        val ax = accel[0].toDouble()
        val ay = accel[1].toDouble()
        val az = accel[2].toDouble()
        val pitch = Math.toDegrees(atan2(ay, sqrt(ax * ax + az * az)))
        val roll = Math.toDegrees(atan2(-ax, az))
        // Camera elevation angle: 0° = pointing horizontally at horizon, +90° = pointing straight up at zenith
        val cameraElevation = Math.toDegrees(atan2(-az, sqrt(ax * ax + ay * ay))).coerceIn(-90.0, 90.0)

        var azimuth = 0.0
        val rMat = FloatArray(9)
        val remappedMat = FloatArray(9)
        val orientation = FloatArray(3)
        var orientationReady = false

        if (hasRotationVec) {
            SensorManager.getRotationMatrixFromVector(rMat, rotationVec)
            orientationReady = true
        } else {
            val iMat = FloatArray(9)
            if (SensorManager.getRotationMatrix(rMat, iMat, accel, mag)) {
                orientationReady = true
            }
        }

        if (orientationReady) {
            // Remap coordinate system when phone is held vertically (pointing camera toward horizon/sky)
            if (abs(ay) > abs(az) * 0.7) {
                SensorManager.remapCoordinateSystem(
                    rMat,
                    SensorManager.AXIS_X,
                    SensorManager.AXIS_Z,
                    remappedMat
                )
                SensorManager.getOrientation(remappedMat, orientation)
            } else {
                SensorManager.getOrientation(rMat, orientation)
            }
            azimuth = (Math.toDegrees(orientation[0].toDouble()) + 360.0) % 360.0
        }

        val magStrength = sqrt(
            (mag[0] * mag[0] + mag[1] * mag[1] + mag[2] * mag[2]).toDouble()
        )

        return mapOf(
            "ax" to ax,
            "ay" to ay,
            "az" to az,
            "gx" to gyro[0].toDouble(),
            "gy" to gyro[1].toDouble(),
            "gz" to gyro[2].toDouble(),
            "mx" to mag[0].toDouble(),
            "my" to mag[1].toDouble(),
            "mz" to mag[2].toDouble(),
            "magFieldUt" to if (magStrength > 0.1) magStrength else 46.5,
            "pressureHpa" to pressure.toDouble(),
            "lightLux" to lightLux.toDouble(),
            "pitch" to pitch,
            "roll" to roll,
            "cameraElevation" to cameraElevation,
            "azimuth" to azimuth,
            "hasBarometer" to hasBarometer,
            "hasLight" to hasLight,
            "hasMag" to hasMag
        )
    }

    private fun handleStartCamera(lens: String, result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            pendingCameraLens = lens
            pendingCameraResult = result
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.CAMERA), REQ_CAMERA)
            return
        }
        openCameraWithPermission(lens, result)
    }

    @SuppressLint("MissingPermission")
    private fun openCameraWithPermission(lens: String, result: MethodChannel.Result) {
        try {
            closeCamera()
            val manager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val targetFacing = if (lens == "front") {
                CameraCharacteristics.LENS_FACING_FRONT
            } else {
                CameraCharacteristics.LENS_FACING_BACK
            }

            var selectedId: String? = null
            var sensorOrientation = 90
            var isFront = false

            for (id in manager.cameraIdList) {
                val chars = manager.getCameraCharacteristics(id)
                val facing = chars.get(CameraCharacteristics.LENS_FACING)
                if (facing == targetFacing) {
                    selectedId = id
                    sensorOrientation = chars.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 90
                    isFront = (facing == CameraCharacteristics.LENS_FACING_FRONT)
                    break
                }
            }

            if (selectedId == null && manager.cameraIdList.isNotEmpty()) {
                selectedId = manager.cameraIdList[0]
                val chars = manager.getCameraCharacteristics(selectedId)
                sensorOrientation = chars.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 90
                isFront = (chars.get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_FRONT)
            }

            if (selectedId == null) {
                result.success(mapOf("status" to "no_camera"))
                return
            }

            val chars = manager.getCameraCharacteristics(selectedId)
            val map = chars.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
            val sizes = map?.getOutputSizes(SurfaceTexture::class.java)
            val chosenSize = sizes?.firstOrNull { it.width <= 1280 && it.height <= 960 } ?: Size(640, 480)

            currentSensorOrientation = sensorOrientation
            currentIsFront = isFront

            startCameraThread()
            val entry = flutterRenderer?.createSurfaceTexture()
            if (entry == null) {
                result.success(mapOf("status" to "error", "message" to "No SurfaceTexture"))
                return
            }
            surfaceEntry = entry
            val texture = entry.surfaceTexture()
            texture.setDefaultBufferSize(chosenSize.width, chosenSize.height)
            val surface = Surface(texture)
            previewSurface = surface

            val reader = ImageReader.newInstance(chosenSize.width, chosenSize.height, ImageFormat.JPEG, 2)
            imageReader = reader
            reader.setOnImageAvailableListener({ r ->
                val img = r.acquireLatestImage() ?: return@setOnImageAvailableListener
                try {
                    val buffer = img.planes[0].buffer
                    val bytes = ByteArray(buffer.remaining())
                    buffer.get(bytes)
                    saveCapturedJpeg(bytes)
                } catch (e: Exception) {
                    val capRes = pendingCaptureResult
                    pendingCaptureResult = null
                    runOnUiThread {
                        capRes?.success(mapOf("status" to "error", "message" to (e.message ?: "Save failed")))
                    }
                } finally {
                    img.close()
                }
            }, cameraHandler)

            var replied = false
            manager.openCamera(selectedId, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    cameraDevice = camera
                    try {
                        val builder = camera.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)
                        builder.addTarget(surface)
                        @Suppress("DEPRECATION")
                        camera.createCaptureSession(listOf(surface, reader.surface), object : CameraCaptureSession.StateCallback() {
                            override fun onConfigured(session: CameraCaptureSession) {
                                if (cameraDevice == null) return
                                captureSession = session
                                try {
                                    builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
                                    session.setRepeatingRequest(builder.build(), null, cameraHandler)
                                    if (!replied) {
                                        replied = true
                                        runOnUiThread {
                                            result.success(mapOf(
                                                "status" to "ok",
                                                "textureId" to entry.id(),
                                                "isFront" to isFront,
                                                "sensorOrientation" to sensorOrientation,
                                                "width" to chosenSize.width,
                                                "height" to chosenSize.height
                                            ))
                                        }
                                    }
                                } catch (e: Exception) {
                                    if (!replied) {
                                        replied = true
                                        runOnUiThread {
                                            result.success(mapOf("status" to "error", "message" to (e.message ?: "Preview failed")))
                                        }
                                    }
                                }
                            }

                            override fun onConfigureFailed(session: CameraCaptureSession) {
                                if (!replied) {
                                    replied = true
                                    runOnUiThread {
                                        result.success(mapOf("status" to "error", "message" to "Configure failed"))
                                    }
                                }
                            }
                        }, cameraHandler)
                    } catch (e: Exception) {
                        if (!replied) {
                            replied = true
                            runOnUiThread {
                                result.success(mapOf("status" to "error", "message" to (e.message ?: "Session failed")))
                            }
                        }
                    }
                }

                override fun onDisconnected(camera: CameraDevice) {
                    camera.close()
                    cameraDevice = null
                }

                override fun onError(camera: CameraDevice, error: Int) {
                    camera.close()
                    cameraDevice = null
                    if (!replied) {
                        replied = true
                        runOnUiThread {
                            result.success(mapOf("status" to "error", "message" to "Camera error $error"))
                        }
                    }
                }
            }, cameraHandler)
        } catch (e: Exception) {
            result.success(mapOf("status" to "error", "message" to (e.message ?: "Exception")))
        }
    }

    private fun handleCapturePhoto(result: MethodChannel.Result) {
        val cam = cameraDevice
        val session = captureSession
        val reader = imageReader
        if (cam == null || session == null || reader == null) {
            result.success(mapOf("status" to "camera_not_active"))
            return
        }
        try {
            pendingCaptureResult = result
            val captureBuilder = cam.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE)
            captureBuilder.addTarget(reader.surface)
            captureBuilder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
            session.capture(captureBuilder.build(), null, cameraHandler)
        } catch (e: Exception) {
            pendingCaptureResult = null
            result.success(mapOf("status" to "error", "message" to (e.message ?: "Capture failed")))
        }
    }

    private fun saveCapturedJpeg(bytes: ByteArray) {
        val rawBitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        val finalBitmap = if (rawBitmap != null) {
            val matrix = Matrix()
            // Rotate bitmap to match upright portrait orientation
            if (rawBitmap.width > rawBitmap.height) {
                matrix.postRotate(currentSensorOrientation.toFloat())
            }
            if (currentIsFront) {
                matrix.postScale(-1f, 1f)
            }
            val rotated = Bitmap.createBitmap(rawBitmap, 0, 0, rawBitmap.width, rawBitmap.height, matrix, true)
            if (rotated !== rawBitmap) rawBitmap.recycle()
            rotated
        } else {
            null
        }

        val filename = "SunPathAR_${System.currentTimeMillis()}.jpg"
        val cacheFile = File(cacheDir, filename)
        FileOutputStream(cacheFile).use { fos ->
            if (finalBitmap != null) {
                finalBitmap.compress(Bitmap.CompressFormat.JPEG, 92, fos)
            } else {
                fos.write(bytes)
            }
        }

        var savedToGallery = false
        try {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, filename)
                put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.Images.Media.RELATIVE_PATH, "${Environment.DIRECTORY_PICTURES}/SunPathAR")
                    put(MediaStore.Images.Media.IS_PENDING, 1)
                }
            }
            val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            if (uri != null) {
                contentResolver.openOutputStream(uri)?.use { out ->
                    if (finalBitmap != null) {
                        finalBitmap.compress(Bitmap.CompressFormat.JPEG, 92, out)
                    } else {
                        out.write(bytes)
                    }
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    values.clear()
                    values.put(MediaStore.Images.Media.IS_PENDING, 0)
                    contentResolver.update(uri, values, null, null)
                }
                savedToGallery = true
            }
        } catch (_: Exception) {
            savedToGallery = false
        } finally {
            finalBitmap?.recycle()
        }

        val capRes = pendingCaptureResult
        pendingCaptureResult = null
        runOnUiThread {
            capRes?.success(mapOf(
                "status" to "ok",
                "filePath" to cacheFile.absolutePath,
                "savedToGallery" to savedToGallery
            ))
        }
    }

    private fun startCameraThread() {
        if (cameraThread == null) {
            cameraThread = HandlerThread("SunPathCameraThread").also { it.start() }
            cameraHandler = Handler(cameraThread!!.looper)
        }
    }

    private fun closeCamera() {
        try {
            captureSession?.close()
            captureSession = null
            cameraDevice?.close()
            cameraDevice = null
            imageReader?.close()
            imageReader = null
            previewSurface?.release()
            previewSurface = null
            surfaceEntry?.release()
            surfaceEntry = null
            cameraThread?.quitSafely()
            cameraThread = null
            cameraHandler = null
        } catch (_: Exception) {}
    }

    private fun handleGetGpsLocation(result: MethodChannel.Result) {
        val fineGranted = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val coarseGranted = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

        if (!fineGranted && !coarseGranted) {
            pendingLocationResult = result
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
                REQ_LOCATION
            )
            return
        }
        resolveGpsLocation(result)
    }

    @SuppressLint("MissingPermission")
    private fun resolveGpsLocation(result: MethodChannel.Result) {
        try {
            val lm = locationManager
            if (lm == null) {
                result.success(mapOf("status" to "unavailable"))
                return
            }

            val providers = listOf(
                LocationManager.GPS_PROVIDER,
                LocationManager.NETWORK_PROVIDER,
                LocationManager.PASSIVE_PROVIDER
            )
            var bestLocation: Location? = null
            for (provider in providers) {
                if (lm.isProviderEnabled(provider)) {
                    val loc = lm.getLastKnownLocation(provider)
                    if (loc != null && (bestLocation == null || loc.accuracy < bestLocation.accuracy)) {
                        bestLocation = loc
                    }
                }
            }

            if (bestLocation != null) {
                lastKnownLat = bestLocation.latitude
                lastKnownLon = bestLocation.longitude
                lastKnownAlt = bestLocation.altitude
                result.success(mapOf(
                    "status" to "ok",
                    "lat" to bestLocation.latitude,
                    "lon" to bestLocation.longitude,
                    "alt" to bestLocation.altitude
                ))
                return
            }

            // Request a single update if no cached location exists
            val activeProvider = when {
                lm.isProviderEnabled(LocationManager.GPS_PROVIDER) -> LocationManager.GPS_PROVIDER
                lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER) -> LocationManager.NETWORK_PROVIDER
                else -> null
            }

            if (activeProvider == null) {
                result.success(mapOf("status" to "gps_disabled"))
                return
            }

            var replied = false
            val listener = object : LocationListener {
                override fun onLocationChanged(location: Location) {
                    if (!replied) {
                        replied = true
                        lm.removeUpdates(this)
                        result.success(mapOf(
                            "status" to "ok",
                            "lat" to location.latitude,
                            "lon" to location.longitude,
                            "alt" to location.altitude
                        ))
                    }
                }
                @Deprecated("Deprecated in Java")
                override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
                override fun onProviderEnabled(provider: String) {}
                override fun onProviderDisabled(provider: String) {}
            }
            lm.requestLocationUpdates(activeProvider, 0L, 0f, listener, mainLooper)
            Handler(mainLooper).postDelayed({
                if (!replied) {
                    replied = true
                    lm.removeUpdates(listener)
                    if (lastKnownLat != null && lastKnownLon != null) {
                        result.success(mapOf("status" to "ok", "lat" to lastKnownLat!!, "lon" to lastKnownLon!!, "alt" to lastKnownAlt))
                    } else {
                        result.success(mapOf("status" to "timeout"))
                    }
                }
            }, 4000L)
        } catch (e: Exception) {
            result.success(mapOf("status" to "error", "message" to (e.message ?: "GPS error")))
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_CAMERA) {
            val res = pendingCameraResult
            pendingCameraResult = null
            if (res != null) {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    openCameraWithPermission(pendingCameraLens, res)
                } else {
                    res.success(mapOf("status" to "permission_denied"))
                }
            }
        } else if (requestCode == REQ_LOCATION) {
            val res = pendingLocationResult
            pendingLocationResult = null
            if (res != null) {
                val granted = grantResults.any { it == PackageManager.PERMISSION_GRANTED }
                if (granted) {
                    resolveGpsLocation(res)
                } else {
                    res.success(mapOf("status" to "permission_denied"))
                }
            }
        }
    }

    private fun registerSensors() {
        val sm = sensorManager ?: return
        sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)?.let {
            sm.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
        }
        sm.getDefaultSensor(Sensor.TYPE_GYROSCOPE)?.let {
            sm.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
        }
        sm.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)?.let {
            hasMag = true
            sm.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
        }
        sm.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)?.let {
            hasRotationVec = true
            sm.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
        }
        sm.getDefaultSensor(Sensor.TYPE_PRESSURE)?.let {
            hasBarometer = true
            sm.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
        }
        sm.getDefaultSensor(Sensor.TYPE_LIGHT)?.let {
            hasLight = true
            sm.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
        }
    }

    override fun onSensorChanged(event: SensorEvent?) {
        val e = event ?: return
        val alpha = 0.2f
        when (e.sensor.type) {
            Sensor.TYPE_ACCELEROMETER -> {
                for (i in 0..2) accel[i] = accel[i] + alpha * (e.values[i] - accel[i])
            }
            Sensor.TYPE_GYROSCOPE -> gyro = e.values.clone()
            Sensor.TYPE_MAGNETIC_FIELD -> {
                for (i in 0..2) mag[i] = mag[i] + alpha * (e.values[i] - mag[i])
            }
            Sensor.TYPE_ROTATION_VECTOR -> {
                val len = minOf(e.values.size, rotationVec.size)
                for (i in 0 until len) rotationVec[i] = e.values[i]
            }
            Sensor.TYPE_PRESSURE -> if (e.values.isNotEmpty()) pressure = e.values[0]
            Sensor.TYPE_LIGHT -> if (e.values.isNotEmpty()) lightLux = e.values[0]
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    override fun onPause() {
        super.onPause()
        sensorManager?.unregisterListener(this)
    }

    override fun onResume() {
        super.onResume()
        registerSensors()
    }

    override fun onDestroy() {
        closeCamera()
        super.onDestroy()
    }
}
