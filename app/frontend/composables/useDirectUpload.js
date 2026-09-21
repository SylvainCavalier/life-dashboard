// Direct upload vers le bucket OVH S3 via Active Storage.
// Le fichier ne transite pas par Rails : le navigateur recupere une URL pre-signee
// puis envoie le fichier en PUT directement au bucket (pas de timeout serveur).
import { DirectUpload } from '@rails/activestorage'

const DIRECT_UPLOAD_URL = '/rails/active_storage/direct_uploads'

export function useDirectUpload() {
  // Renvoie une promesse resolue avec le blob { signed_id, filename, byte_size... }
  // onProgress recoit un pourcentage entier (0-100)
  const uploadFile = (file, onProgress) => {
    return new Promise((resolve, reject) => {
      const delegate = {
        directUploadWillStoreFileWithXHR(xhr) {
          xhr.upload.addEventListener('progress', (event) => {
            if (!event.lengthComputable || !onProgress) return
            onProgress(Math.round((event.loaded / event.total) * 100))
          })
        },
      }

      const upload = new DirectUpload(file, DIRECT_UPLOAD_URL, delegate)

      upload.create((error, blob) => {
        if (error) {
          reject(error)
        } else {
          resolve(blob)
        }
      })
    })
  }

  return { uploadFile }
}
