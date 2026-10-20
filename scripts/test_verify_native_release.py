import argparse
import base64
import importlib.util
import json
import plistlib
import tempfile
import unittest
import zipfile
from pathlib import Path


spec = importlib.util.spec_from_file_location("native_release", Path(__file__).with_name("verify-native-release.py"))
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class NativeReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="word7000-release-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.words = [{"id": str(index)} for index in range(7000)]
        self.speaking = {"schemaVersion": 1, "records": [{
            "id": "q1", "word": "about", "keywordZh": "\u95dc\u65bc", "question": "What do you enjoy talking about?",
            "answerEn": "I enjoy talking about books.", "answerZh": "\u6211\u559c\u6b61\u804a\u66f8\u3002"
        }]}
        (self.root / "words.json").write_text(json.dumps(self.words), encoding="utf-8")
        (self.root / "speaking.json").write_text(json.dumps(self.speaking), encoding="utf-8")
        (self.root / "build.json").write_text(json.dumps({"status": "FINISHED", "appVersion": "2.0.1", "appBuildVersion": "39"}), encoding="utf-8")
        self.args = argparse.Namespace(archive=str(self.root / "app.ipa"), metadata=str(self.root / "build.json"),
                                       words=str(self.root / "words.json"), speaking=str(self.root / "speaking.json"),
                                       expected_build="39", expected_version="2.0.1")

    def archive(self, *, app_questions=True, questions=None, config=None):
        app_root = "Payload/Word7000.app/"
        widget_root = app_root + "PlugIns/Word7000Widgets.appex/"
        app = {"CFBundleIdentifier": "com.rio.word7000", "CFBundleVersion": "39", "CFBundleShortVersionString": "2.0.1",
               "Word7000SupabaseURL": "https://byyaepkhxexppjrdhcaw.supabase.co", "Word7000SupabasePublishableKey": "sb_publishable_test",
               "NSSupportsLiveActivities": True, "CFBundleURLTypes": [{"CFBundleURLSchemes": ["word7000"]}]}
        app.update(config or {})
        widget = {"CFBundleIdentifier": "com.rio.word7000.ExpoWidgetsTarget", "CFBundleVersion": "39", "CFBundleShortVersionString": "2.0.1"}
        profile = plistlib.dumps({"Entitlements": {"com.apple.security.application-groups": ["group.com.rio.word7000"]}})
        resource = "Word7000Core_Word7000Core.bundle/speaking-prompts.json"
        with zipfile.ZipFile(self.args.archive, "w") as archive:
            archive.writestr(app_root + "Info.plist", plistlib.dumps(app))
            archive.writestr(widget_root + "Info.plist", plistlib.dumps(widget))
            archive.writestr(app_root + "words.json", json.dumps(self.words))
            archive.writestr(app_root + "embedded.mobileprovision", profile)
            archive.writestr(widget_root + "embedded.mobileprovision", profile)
            archive.writestr(widget_root + resource, json.dumps(self.speaking))
            if app_questions:
                archive.writestr(app_root + resource, json.dumps(questions if questions is not None else self.speaking))

    def test_complete_app_contains_reviewed_questions_and_answers(self):
        self.archive()
        result = release.verify(self.args)
        self.assertEqual(result["wordCount"], 7000)
        self.assertEqual(result["reviewedSpeakingQuestions"], 1)
        self.assertTrue(result["speakingLibraryMatchesSource"])

    def test_widget_copy_cannot_hide_missing_main_app_questions(self):
        self.archive(app_questions=False)
        with self.assertRaises(StopIteration):
            release.verify(self.args)

    def test_stale_packaged_questions_are_rejected(self):
        self.archive(questions={"schemaVersion": 1, "records": []})
        with self.assertRaisesRegex(ValueError, "differ"):
            release.verify(self.args)

    def test_missing_reference_answer_is_rejected_even_in_source(self):
        self.speaking["records"][0]["answerZh"] = ""
        (self.root / "speaking.json").write_text(json.dumps(self.speaking), encoding="utf-8")
        self.archive()
        with self.assertRaisesRegex(ValueError, "paired answers"):
            release.verify(self.args)

    def test_unsupported_schema_is_rejected(self):
        self.speaking["schemaVersion"] = 2
        (self.root / "speaking.json").write_text(json.dumps(self.speaking), encoding="utf-8")
        self.archive()
        with self.assertRaisesRegex(ValueError, "unsupported schema"):
            release.verify(self.args)

    def test_a_different_account_backend_is_rejected(self):
        self.archive(config={"Word7000SupabaseURL": "https://different-project.supabase.co"})
        with self.assertRaisesRegex(ValueError, "shared project"):
            release.verify(self.args)

    def test_legacy_public_key_is_accepted(self):
        payload = base64.urlsafe_b64encode(json.dumps({"role": "anon"}).encode()).decode().rstrip("=")
        self.archive(config={"Word7000SupabasePublishableKey": "eyJhbGciOiJIUzI1NiJ9." + payload + ".test-signature"})
        self.assertTrue(release.verify(self.args)["accountBackendConfigured"])

    def test_a_privileged_key_is_never_packaged(self):
        payload = base64.urlsafe_b64encode(json.dumps({"role": "service_role"}).encode()).decode().rstrip("=")
        self.archive(config={"Word7000SupabasePublishableKey": "eyJhbGciOiJIUzI1NiJ9." + payload + ".test-signature"})
        with self.assertRaisesRegex(ValueError, "Privileged"):
            release.verify(self.args)


if __name__ == "__main__":
    unittest.main()
