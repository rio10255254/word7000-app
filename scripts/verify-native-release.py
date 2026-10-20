import argparse
import base64
import json
import plistlib
import zipfile
from pathlib import Path
from urllib.parse import urlparse


def require(condition, message):
    if not condition:
        raise ValueError(message)


def verify(args):
    builds = json.loads(Path(args.metadata).read_text(encoding="utf-8"))
    build = builds[0] if isinstance(builds, list) else builds
    require(build["status"] == "FINISHED", "Native build did not finish")
    require(str(build["appBuildVersion"]) == args.expected_build, "EAS build number changed while staging")
    require(build["appVersion"] == args.expected_version, "EAS app version does not match")

    with zipfile.ZipFile(args.archive) as archive:
        names = archive.namelist()
        app_info_name = next(name for name in names if name.startswith("Payload/")
                             and name.endswith(".app/Info.plist") and "/PlugIns/" not in name)
        app_root = app_info_name.rsplit("/", 1)[0] + "/"
        widget_info_name = next(name for name in names if name.startswith(app_root)
                                and "/PlugIns/" in name and name.endswith(".appex/Info.plist"))
        widget_root = widget_info_name.rsplit("/", 1)[0] + "/"
        app = plistlib.loads(archive.read(app_info_name))
        widget = plistlib.loads(archive.read(widget_info_name))

        for label, info, identifier in [("App", app, "com.rio.word7000"),
                                        ("Widget", widget, "com.rio.word7000.ExpoWidgetsTarget")]:
            require(info["CFBundleIdentifier"] == identifier, f"{label} bundle identifier is incorrect")
            require(str(info["CFBundleVersion"]) == args.expected_build,
                    f"{label} contains build {info['CFBundleVersion']}, expected {args.expected_build}")
            require(info["CFBundleShortVersionString"] == args.expected_version,
                    f"{label} app version does not match")

        url = app.get("Word7000SupabaseURL", "")
        key = app.get("Word7000SupabasePublishableKey", "") or app.get("Word7000SupabaseAnonKey", "")
        require(urlparse(url).scheme == "https" and bool(urlparse(url).hostname) and "$(" not in url,
                "Account backend URL is unresolved")
        require(urlparse(url).hostname == "byyaepkhxexppjrdhcaw.supabase.co", "Account backend differs from the shared project")
        require(key.startswith(("sb_publishable_", "eyJ")), "Account publishable key is unresolved")
        if key.startswith("eyJ"):
            pieces = key.split(".")
            require(len(pieces) == 3, "Legacy account key is malformed")
            claims = json.loads(base64.urlsafe_b64decode(pieces[1] + "=" * (-len(pieces[1]) % 4)))
            require(claims.get("role") == "anon", "Privileged or personal account key must not ship in the app")
        require(app.get("NSSupportsLiveActivities") is True, "Live Activities are not enabled")
        schemes = [scheme for entry in app.get("CFBundleURLTypes", [])
                   for scheme in entry.get("CFBundleURLSchemes", [])]
        require("word7000" in schemes, "Account callback URL scheme is missing")

        word_file = next(name for name in names if name.startswith(app_root) and name.endswith("/words.json"))
        words = json.loads(archive.read(word_file))
        source_words = json.loads(Path(args.words).read_text(encoding="utf-8"))
        require(len(words) == 7000 and words == source_words, "Packaged word data differs from the reviewed library")

        speaking_file = next(name for name in names if name.startswith(app_root) and "/PlugIns/" not in name
                             and name.endswith("/Word7000Core_Word7000Core.bundle/speaking-prompts.json"))
        speaking = json.loads(archive.read(speaking_file))
        source_speaking = json.loads(Path(args.speaking).read_text(encoding="utf-8"))
        require(speaking == source_speaking, "Packaged speaking questions differ from the reviewed library")
        require(type(speaking.get("schemaVersion")) is int and speaking["schemaVersion"] == 1,
                "Speaking library uses an unsupported schema")
        records = speaking.get("records", [])
        fields = ["id", "word", "keywordZh", "question", "answerEn", "answerZh"]
        require(isinstance(records, list) and len(records) > 0
                and all(isinstance(row, dict) and all(isinstance(row.get(field), str) and row[field].strip()
                                                    for field in fields) for row in records),
                "Speaking questions or paired answers are missing")
        require(len({row["id"] for row in records}) == len(records), "Speaking question identifiers are not unique")

        for root in [app_root, widget_root]:
            raw = archive.read(root + "embedded.mobileprovision")
            start = raw.index(b"<?xml")
            end = raw.index(b"</plist>", start) + len(b"</plist>")
            profile = plistlib.loads(raw[start:end])
            groups = profile["Entitlements"].get("com.apple.security.application-groups", [])
            require("group.com.rio.word7000" in groups, "Signing profile is missing the existing App Group")

    return {"version": args.expected_version, "build": args.expected_build, "wordCount": len(words),
            "reviewedSpeakingQuestions": len(records), "speakingLibraryMatchesSource": True,
            "accountBackendConfigured": True, "dynamicIslandEmbedded": True, "signingGroupsMatched": True}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--archive", required=True)
    parser.add_argument("--metadata", required=True)
    parser.add_argument("--words", required=True)
    parser.add_argument("--speaking", default=str(Path(__file__).resolve().parents[1] /
                        "ios/Packages/Word7000Core/Sources/Word7000Core/Resources/speaking-prompts.json"))
    parser.add_argument("--expected-build", required=True)
    parser.add_argument("--expected-version", required=True)
    arguments = parser.parse_args()
    try:
        print(json.dumps(verify(arguments)))
    except (ValueError, KeyError, StopIteration, zipfile.BadZipFile) as error:
        raise SystemExit(f"Native release verification failed: {error}")
