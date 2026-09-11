export function getSmartFolderName(
  folderPath: string,
  allFolders: { path: string }[] = []
): string {
  if (!folderPath) return "";
  const norm = folderPath.replace(/\\/g, "/").replace(/\/$/, "");
  const parts = norm.split("/").filter(Boolean);
  if (parts.length === 0) return folderPath;
  const leaf = parts[parts.length - 1];

  // Count how many folders in allFolders share this leaf name
  const sameLeafCount = allFolders.filter((f) => {
    const fNorm = f.path.replace(/\\/g, "/").replace(/\/$/, "");
    const fParts = fNorm.split("/").filter(Boolean);
    return fParts[fParts.length - 1]?.toLowerCase() === leaf.toLowerCase();
  }).length;

  // If there are duplicate folder names (like two "Descargas"), disambiguate with parent folder
  if (sameLeafCount > 1 && parts.length >= 2) {
    const parent = parts[parts.length - 2];
    const isDriveOnly = parent.endsWith(":") || parent.length <= 2;
    if (isDriveOnly) {
      return `${parent}\\${leaf}`;
    }
    return `${parent} / ${leaf}`;
  }

  // If this is a custom nested folder (not just the default user profile folder)
  if (
    parts.length >= 2 &&
    !folderPath.toLowerCase().includes("/users/") &&
    !folderPath.toLowerCase().includes("\\users\\")
  ) {
    const parent = parts[parts.length - 2];
    const isDriveOnly = parent.endsWith(":") || parent.length <= 2;
    if (!isDriveOnly) {
      return `${parent} / ${leaf}`;
    }
  }

  return leaf;
}
