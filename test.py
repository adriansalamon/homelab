import sys, base64, os, hashlib

input = sys.stdin.readlines()[0].strip()
base64_adapted_alphabet = (
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789./"
)


def encode_base64_adapted(data):
    base64_encoded = base64.b64encode(data).decode("utf-8").strip("=")
    return base64_encoded.translate(
        str.maketrans(
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",
            base64_adapted_alphabet,
        )
    )


salt = os.urandom(16)
key = hashlib.pbkdf2_hmac("sha512", input.encode(), salt, 310000, 64)
salt_b64 = encode_base64_adapted(salt)
key_b64 = encode_base64_adapted(key)
print(f"$pbkdf2-sha512${310000}${salt_b64}${key_b64}")
