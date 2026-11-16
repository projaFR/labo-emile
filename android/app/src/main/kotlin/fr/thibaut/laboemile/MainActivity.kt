package fr.thibaut.laboemile

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ContentProvider
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.Uri
import android.os.Build
import android.os.ParcelFileDescriptor
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileNotFoundException

class MainActivity : FlutterActivity() {
    companion object {
        private const val CANAL_PHOTO = "fr.thibaut.laboemile/photo"
        private const val REQ_CAMERA = 2001
        private const val REQ_GALERIE = 2002
        private const val MAX_DIM_PX = 1800
        private const val MAX_OCTETS = 1_500_000
    }

    private var resultatEnAttente: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CANAL_PHOTO,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "prendrePhoto" -> lancerCamera(result)
                "choisirGalerie" -> lancerGalerie(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun lancerCamera(result: MethodChannel.Result) {
        if (resultatEnAttente != null) {
            result.error("occupe", "Une sélection de photo est déjà en cours.", null)
            return
        }
        val fichier = File(cacheDir, "photo_capture.jpg")
        try {
            if (fichier.exists()) fichier.delete()
            fichier.createNewFile()
        } catch (_: Exception) {
            result.error("fichier", "Impossible de préparer le fichier photo.", null)
            return
        }

        val uri = Uri.parse("content://$packageName.photoprovider/capture.jpg")
        val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
            putExtra(MediaStore.EXTRA_OUTPUT, uri)
            clipData = ClipData.newRawUri("", uri)
            addFlags(
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
        }
        val targets = packageManager.queryIntentActivities(
            intent,
            PackageManager.MATCH_DEFAULT_ONLY,
        )
        for (info in targets) {
            grantUriPermission(
                info.activityInfo.packageName,
                uri,
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
        }

        resultatEnAttente = result
        try {
            @Suppress("DEPRECATION")
            startActivityForResult(intent, REQ_CAMERA)
        } catch (_: ActivityNotFoundException) {
            resultatEnAttente = null
            result.error("camera_absente", "Aucun appareil photo trouvé.", null)
        }
    }

    private fun lancerGalerie(result: MethodChannel.Result) {
        if (resultatEnAttente != null) {
            result.error("occupe", "Une sélection de photo est déjà en cours.", null)
            return
        }
        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
            type = "image/*"
            addCategory(Intent.CATEGORY_OPENABLE)
        }
        resultatEnAttente = result
        try {
            @Suppress("DEPRECATION")
            startActivityForResult(
                Intent.createChooser(intent, "Choisir une image"),
                REQ_GALERIE,
            )
        } catch (_: ActivityNotFoundException) {
            resultatEnAttente = null
            result.error("galerie_absente", "Impossible d'ouvrir la galerie.", null)
        }
    }

    @Deprecated("Requis par FlutterActivity pour les intents sans plugin")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_CAMERA && requestCode != REQ_GALERIE) return
        val pending = resultatEnAttente ?: return
        resultatEnAttente = null

        if (resultCode != Activity.RESULT_OK) {
            pending.success(null)
            return
        }

        Thread {
            try {
                val octets = if (requestCode == REQ_CAMERA) {
                    lireEtReduireCamera(data)
                } else {
                    lireEtReduireUri(data?.data)
                }
                runOnUiThread { pending.success(octets) }
            } catch (_: Exception) {
                runOnUiThread {
                    pending.error(
                        "lecture_impossible",
                        "Impossible de lire cette image.",
                        null,
                    )
                }
            }
        }.start()
    }

    private fun lireEtReduireCamera(data: Intent?): ByteArray? {
        val fichier = File(cacheDir, "photo_capture.jpg")
        try {
            if (fichier.exists() && fichier.length() > 0L) {
                val raw = fichier.readBytes()
                return reduireSiBesoin(raw, fichier.absolutePath)
            }
            @Suppress("DEPRECATION")
            val miniature = data?.extras?.get("data") as? Bitmap ?: return null
            val out = ByteArrayOutputStream()
            miniature.compress(Bitmap.CompressFormat.JPEG, 88, out)
            miniature.recycle()
            return out.toByteArray()
        } finally {
            fichier.delete()
        }
    }

    private fun lireEtReduireUri(uri: Uri?): ByteArray? {
        if (uri == null) return null
        val raw = contentResolver.openInputStream(uri)?.use { it.readBytes() }
            ?: return null
        if (raw.isEmpty()) return null
        return reduireSiBesoin(raw, null)
    }

    private fun reduireSiBesoin(raw: ByteArray, cheminExif: String?): ByteArray {
        val bornes = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(raw, 0, raw.size, bornes)
        val maxOrig = maxOf(bornes.outWidth, bornes.outHeight)
        if (raw.size <= MAX_OCTETS && maxOrig in 1..MAX_DIM_PX) {
            return raw
        }

        var sample = 1
        if (maxOrig > MAX_DIM_PX) {
            var demi = maxOrig / 2
            while (demi / sample >= MAX_DIM_PX) {
                sample *= 2
            }
        }
        val opts = BitmapFactory.Options().apply { inSampleSize = sample }
        var bmp = BitmapFactory.decodeByteArray(raw, 0, raw.size, opts) ?: return raw

        val angle = lireAngleExif(raw, cheminExif)
        if (angle != 0) {
            val mat = Matrix().apply { postRotate(angle.toFloat()) }
            val rotated = Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, mat, true)
            if (rotated != bmp) bmp.recycle()
            bmp = rotated
        }

        val maxActuel = maxOf(bmp.width, bmp.height)
        if (maxActuel > MAX_DIM_PX) {
            val ratio = MAX_DIM_PX.toFloat() / maxActuel.toFloat()
            val w = (bmp.width * ratio).toInt().coerceAtLeast(1)
            val h = (bmp.height * ratio).toInt().coerceAtLeast(1)
            val scaled = Bitmap.createScaledBitmap(bmp, w, h, true)
            if (scaled != bmp) bmp.recycle()
            bmp = scaled
        }

        val out = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.JPEG, 85, out)
        bmp.recycle()
        return out.toByteArray()
    }

    private fun lireAngleExif(raw: ByteArray, cheminExif: String?): Int {
        return try {
            val exif = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                ExifInterface(ByteArrayInputStream(raw))
            } else if (cheminExif != null) {
                ExifInterface(cheminExif)
            } else {
                return 0
            }
            when (
                exif.getAttributeInt(
                    ExifInterface.TAG_ORIENTATION,
                    ExifInterface.ORIENTATION_NORMAL,
                )
            ) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90
                ExifInterface.ORIENTATION_ROTATE_180 -> 180
                ExifInterface.ORIENTATION_ROTATE_270 -> 270
                else -> 0
            }
        } catch (_: Exception) {
            0
        }
    }
}

/// Fournisseur de fichier privé pour récupérer la photo prise par l'appareil photo.
class PhotoProvider : ContentProvider() {
    override fun onCreate(): Boolean = true

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        val ctx = context ?: throw FileNotFoundException("Contexte absent")
        val fichier = File(ctx.cacheDir, "photo_capture.jpg")
        if (!fichier.exists()) {
            fichier.createNewFile()
        }
        return ParcelFileDescriptor.open(fichier, ParcelFileDescriptor.parseMode(mode))
    }

    override fun getType(uri: Uri): String = "image/jpeg"

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor? = null

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun delete(
        uri: Uri,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = 0

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = 0
}
