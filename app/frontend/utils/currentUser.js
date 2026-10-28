// Role du compte connecte, pose par le layout Rails (meta dashboard-role).
// FRIEND_ROUTES est a tenir aligne avec SpaController::FRIEND_PATHS.
// Un ami n'a acces qu'aux pages ci-dessous ; l'API refuse de toute facon le reste.
export const currentRole = document.querySelector('meta[name="dashboard-role"]')?.content || null
export const isFriend = currentRole === 'friend'

export const FRIEND_ROUTES = ['Tools', 'Downloader', 'DownloaderFolder', 'Transfer']
