#!/usr/bin/env python3
"""
=============================================================================
 WA-Forensics Toolkit — Encrypted Database Decryption Helper
 Supports: .crypt12, .crypt14, .crypt15
=============================================================================

Usage (called internally by db_handler.sh):
    python3 decrypt_helper.py --keyfile /path/to/key --encrypted /path/to/msgstore.db.crypt14 --output /path/to/output.db

Requirements:
    pip3 install pycryptodome

Legal Notice:
    This script is intended for use ONLY by authorised investigators with
    a valid warrant or device owner consent.
=============================================================================
"""

import argparse
import sys
import os
import struct
import hashlib

def check_dependencies():
    try:
        from Crypto.Cipher import AES
        return True
    except ImportError:
        print("[ERROR] pycryptodome is required: pip3 install pycryptodome", file=sys.stderr)
        return False

def read_key_file(key_path):
    """Read raw key bytes from extracted key file."""
    with open(key_path, 'rb') as f:
        return f.read()

def decrypt_crypt14(key_bytes, encrypted_path, output_path):
    """
    Decrypt a .crypt14 WhatsApp backup database.
    Key file must be the raw 'key' file extracted from the device sandbox.
    """
    from Crypto.Cipher import AES

    with open(encrypted_path, 'rb') as f:
        data = f.read()

    # crypt14 header: 'WhatsApp Backup Key' + version bytes + IV
    # The actual key is derived from the key file
    # Key bytes 30-62 are the AES-256 key (32 bytes)
    if len(key_bytes) < 158:
        print("[ERROR] Key file appears invalid or truncated.", file=sys.stderr)
        sys.exit(1)

    aes_key = key_bytes[126:158]  # 32-byte AES key
    iv = data[51:67]              # 16-byte IV from encrypted file header

    ciphertext = data[67:-20]     # Strip header and HMAC footer

    cipher = AES.new(aes_key, AES.MODE_CBC, iv)
    plaintext = cipher.decrypt(ciphertext)

    # Strip PKCS7 padding
    pad_len = plaintext[-1]
    plaintext = plaintext[:-pad_len]

    with open(output_path, 'wb') as f:
        f.write(plaintext)

    print(f"[OK] Decryption successful: {output_path}")

def decrypt_crypt12(key_bytes, encrypted_path, output_path):
    """
    Decrypt a .crypt12 WhatsApp backup database.
    """
    from Crypto.Cipher import AES

    with open(encrypted_path, 'rb') as f:
        data = f.read()

    # crypt12 uses AES-GCM
    # Key: bytes 126:158 from keyfile
    # IV:  bytes 67:83 from encrypted file
    aes_key = key_bytes[126:158]
    iv = data[67:83]
    ciphertext = data[83:-20]

    from Crypto.Cipher import AES
    cipher = AES.new(aes_key, AES.MODE_GCM, nonce=iv)
    plaintext = cipher.decrypt(ciphertext)

    with open(output_path, 'wb') as f:
        f.write(plaintext)

    print(f"[OK] Decryption successful: {output_path}")

def main():
    parser = argparse.ArgumentParser(
        description='WA-Forensics — WhatsApp Encrypted Database Decryption Helper'
    )
    parser.add_argument('--keyfile',   required=True, help='Path to extracted WhatsApp key file')
    parser.add_argument('--encrypted', required=True, help='Path to encrypted .crypt* database')
    parser.add_argument('--output',    required=True, help='Output path for decrypted SQLite database')

    args = parser.parse_args()

    if not check_dependencies():
        sys.exit(1)

    if not os.path.isfile(args.keyfile):
        print(f"[ERROR] Key file not found: {args.keyfile}", file=sys.stderr)
        sys.exit(1)

    if not os.path.isfile(args.encrypted):
        print(f"[ERROR] Encrypted file not found: {args.encrypted}", file=sys.stderr)
        sys.exit(1)

    key_bytes = read_key_file(args.keyfile)
    ext = args.encrypted.split('.')[-1].lower()

    print(f"[INFO] Detected format: .{ext}")
    print(f"[INFO] Key file size: {len(key_bytes)} bytes")

    try:
        if ext in ('crypt14', 'crypt15'):
            decrypt_crypt14(key_bytes, args.encrypted, args.output)
        elif ext == 'crypt12':
            decrypt_crypt12(key_bytes, args.encrypted, args.output)
        else:
            print(f"[ERROR] Unsupported encryption format: .{ext}", file=sys.stderr)
            print("[INFO] Supported: .crypt12, .crypt14, .crypt15", file=sys.stderr)
            sys.exit(1)
    except Exception as e:
        print(f"[ERROR] Decryption failed: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
