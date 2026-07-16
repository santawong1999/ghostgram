#!/usr/bin/env python3
"""Create entitlements plist for code signing."""
import plistlib, sys
ent = {
    'get-task-allow': True,
    'aps-environment': 'development',
    'com.apple.security.application-groups': ['group.telegram'],
    'keychain-access-groups': ['$(AppIdentifierPrefix)org.telegram.Telegram'],
}
plistlib.dump(ent, open(sys.argv[1], 'wb'))
print(f"Entitlements written to {sys.argv[1]}")
