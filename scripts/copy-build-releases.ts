import { copyFileSync, existsSync, mkdirSync, readFileSync, readdirSync, unlinkSync, writeFileSync } from "node:fs";
import { join, basename } from "node:path";
import { createHash } from "node:crypto";

const rootDir = process.cwd();
const bundleDir = join(rootDir, "src-tauri", "target", "release", "bundle");
const releaseDir = join(rootDir, "release");

// En Windows el instalador oficial ya no lo genera Tauri: se compila con Inno
// Setup 6 desde packaging\windows\setup.iss y lo publica
// scripts\packaging\Build-Installer.ps1, que escribe su propio
// release\SHA256SUMS.txt. Este script solo sirve para los bundles de Tauri en
// Linux y macOS. En Windows copiaría un instalador NSIS residual y sobrescribiría
// el fichero de sumas oficial con un conjunto incompleto.
if (process.platform === "win32") {
  console.log(
    "ℹ️ Windows: la copia de bundles de Tauri se omite. El instalador oficial lo genera " +
      "scripts\\packaging\\Build-Installer.ps1 (Inno Setup 6).",
  );
  process.exit(0);
}

// Leer la versión actual desde package.json
const packageJson = JSON.parse(readFileSync(join(rootDir, "package.json"), "utf-8"));
const currentVersion = packageJson.version;

if (!existsSync(bundleDir)) {
  console.log("⚠️ No se encontró la carpeta de bundle en:", bundleDir);
  process.exit(0);
}

if (!existsSync(releaseDir)) {
  mkdirSync(releaseDir, { recursive: true });
}

function findArtifacts(dir: string): string[] {
  const results: string[] = [];
  if (!existsSync(dir)) return results;

  const entries = readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...findArtifacts(fullPath));
    } else if (
      entry.isFile() &&
      entry.name.endsWith(".exe") &&
      entry.name.includes(currentVersion)
    ) {
      results.push(fullPath);
    }
  }
  return results;
}

const artifacts = findArtifacts(bundleDir);

if (artifacts.length === 0) {
  console.log(`ℹ️ No se encontraron instaladores para la versión v${currentVersion} en el bundle.`);
} else {
  console.log(`\n🚀 Copiando instaladores v${currentVersion} a la carpeta 'release/'...`);
  const checksums: string[] = [];

  for (const artifact of artifacts) {
    const fileName = basename(artifact);
    const destPath = join(releaseDir, fileName);
    copyFileSync(artifact, destPath);
    console.log(`  ✅ Copiado: release/${fileName}`);

    // Calcular SHA256
    const fileBuffer = readFileSync(destPath);
    const hash = createHash("sha256").update(fileBuffer).digest("hex");
    checksums.push(`${hash}  ${fileName}`);
  }

  if (checksums.length > 0) {
    const sumsPath = join(releaseDir, "SHA256SUMS.txt");
    writeFileSync(sumsPath, checksums.join("\n") + "\n", "utf-8");
    console.log(`  📝 Sumas SHA256 generadas en release/SHA256SUMS.txt`);
  }

  console.log(`\n🎉 ¡Listo! Instaladores y sumas disponibles en 'release/'.\n`);
}
