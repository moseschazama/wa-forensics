import os
import hashlib
import subprocess
import sys
from datetime import datetime

LOG_FILE = "write_blocker.log"


# ---------------------------
# Logging
# ---------------------------
def log(msg):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{timestamp}] {msg}"
    print(line)
    with open(LOG_FILE, "a") as f:
        f.write(line + "\n")


# ---------------------------
# Permissions
# ---------------------------
def make_read_only(path):
    for root, dirs, files in os.walk(path):
        for d in dirs:
            os.chmod(os.path.join(root, d), 0o555)
        for f in files:
            os.chmod(os.path.join(root, f), 0o444)
    log(f"Read-only permissions applied → {path}")


def make_immutable(path):
    try:
        subprocess.run(["chattr", "-R", "+i", path], check=True)
        log(f"Immutable flag applied → {path}")
    except Exception as e:
        log(f"WARNING: Failed to apply immutability: {e}")


# ---------------------------
# Hashing
# ---------------------------
def hash_file(filepath):
    sha256 = hashlib.sha256()
    with open(filepath, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            sha256.update(chunk)
    return sha256.hexdigest()


def generate_hashes(path):
    hash_file_path = os.path.join(path, "hashes.txt")

    with open(hash_file_path, "w") as out:
        for root, _, files in os.walk(path):
            for f in files:
                full = os.path.join(root, f)
                h = hash_file(full)
                out.write(f"{h}  {full}\n")

    log(f"Hashes generated → {hash_file_path}")


# ---------------------------
# Verification
# ---------------------------
def verify_hashes(path):
    hash_file_path = os.path.join(path, "hashes.txt")

    if not os.path.exists(hash_file_path):
        log("ERROR: hashes.txt missing")
        return False

    with open(hash_file_path, "r") as f:
        for line in f:
            expected, filepath = line.strip().split("  ")

            if not os.path.exists(filepath):
                log(f"ERROR: Missing file → {filepath}")
                return False

            actual = hash_file(filepath)

            if actual != expected:
                log(f"ERROR: Hash mismatch → {filepath}")
                return False

    log("Hash verification PASSED")
    return True


# ---------------------------
# Protection State Check
# ---------------------------
def is_read_only(path):
    for root, dirs, files in os.walk(path):
        for f in files:
            if os.access(os.path.join(root, f), os.W_OK):
                return False
    return True


# ---------------------------
# Apply Write Blocker
# ---------------------------
def apply_write_blocker(path):
    log(f"Applying write blocker → {path}")

    make_read_only(path)
    make_immutable(path)
    generate_hashes(path)

    log("Write blocker applied successfully")


# ---------------------------
# Verify Protection
# ---------------------------
def verify_protection(path):
    log(f"Verifying protection → {path}")

    if not is_read_only(path):
        log("ERROR: Files are still writable")
        return False

    if not verify_hashes(path):
        return False

    log("Protection verified successfully")
    return True


# ---------------------------
# CLI ENTRY
# ---------------------------
if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage:")
        print("  apply  <path>")
        print("  verify <path>")
        sys.exit(1)

    action = sys.argv[1]
    target = sys.argv[2]

    if action == "apply":
        apply_write_blocker(target)

    elif action == "verify":
        ok = verify_protection(target)
        sys.exit(0 if ok else 1)

    else:
        print("Unknown action")
        sys.exit(1)