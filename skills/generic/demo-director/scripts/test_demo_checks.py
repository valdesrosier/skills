"""Pure fixture tests: no OS inspection, recording, UI actions, or permissions."""

import copy
import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

import demo_checks
import host_inventory


class DemoChecksTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        script = self.root / "script.md"
        script.write_text("Approved narration.", encoding="utf-8")
        self.path = self.root / "plan.json"
        self.plan = {
            "schema_version": 1, "title": "A real task", "version": "v1",
            "target_seconds": 2, "fps": 30, "width": 1920, "height": 1080,
            "audio": "silent", "hardware": {
                "method": "provided", "os": "Windows", "capture_host": "User's recording PC",
                "discovery_approved": False,
            },
            "capture_mode": "native", "evidence_mode": "prepared-real",
            "script": {"path": "script.md", "approved": True, "approval_note": "User approved v1",
                       "sha256": hashlib.sha256(script.read_bytes()).hexdigest()},
            "scenes": [{"id": "result", "start_frame": 0, "end_frame": 60,
                        "pause_frames": 30, "direction": "Show the result.",
                        "narration": "A working result.", "expected_result": "The record is visible."}],
        }
        self.metadata = {
            "streams": [{"codec_type": "video", "codec_name": "h264", "pix_fmt": "yuv420p",
                         "width": 1920, "height": 1080, "r_frame_rate": "30/1",
                         "avg_frame_rate": "30/1", "nb_read_frames": "60", "duration": "2.0",
                         "sample_aspect_ratio": "1:1"}],
            "format": {"duration": "2.0"},
        }

    def check(self):
        self.path.write_text(json.dumps(self.plan), encoding="utf-8")
        return demo_checks.load_plan(self.path, approved=True)[1]

    def test_valid_platform_neutral_plan(self):
        for system in ("Windows", "Linux", "macOS"):
            self.plan["hardware"]["os"] = system
            self.assertTrue(self.check()["passed"])

    def test_host_inventory_requires_approval_before_probing(self):
        with patch("host_inventory.platform.system") as probe:
            with self.assertRaises(PermissionError):
                host_inventory.inventory(False)
            probe.assert_not_called()

    def test_approved_inventory_is_minimal(self):
        with patch("host_inventory.platform.system", return_value="Linux"), \
                patch("host_inventory.platform.release", return_value="fixture"), \
                patch("host_inventory.platform.machine", return_value="fixture"):
            result = host_inventory.inventory(True)
        self.assertEqual(result["os"], "Linux")
        self.assertNotIn("hostname", result)
        self.assertNotIn("username", result)

    def test_discovery_requires_explicit_approval(self):
        self.plan["hardware"]["method"] = "approved-discovery"
        self.assertFalse(self.check()["passed"])

    def test_audio_never_defaults(self):
        self.plan["audio"] = None
        self.assertFalse(self.check()["passed"])

    def test_malformed_audio_is_a_validation_error(self):
        self.plan["audio"] = []
        self.assertFalse(self.check()["passed"])

    def test_unapproved_script_rejected(self):
        self.plan["script"]["approved"] = False
        self.assertFalse(self.check()["passed"])

    def test_changed_script_rejected(self):
        (self.root / "script.md").write_text("Changed narration.", encoding="utf-8")
        self.assertFalse(self.check()["passed"])

    def test_overlap_or_gap_rejected(self):
        self.plan["scenes"][0]["start_frame"] = 1
        self.assertFalse(self.check()["passed"])

    def test_wrong_total_frames_rejected(self):
        self.plan["scenes"][0]["end_frame"] = 59
        self.assertFalse(self.check()["passed"])

    def test_pause_cannot_consume_narration_time(self):
        self.plan["scenes"][0]["pause_frames"] = 60
        self.assertFalse(self.check()["passed"])

    def test_nonfinite_duration_rejected(self):
        self.plan["target_seconds"] = "NaN"
        self.assertFalse(self.check()["passed"])

    def test_duplicate_scene_ids_rejected(self):
        scene = copy.deepcopy(self.plan["scenes"][0])
        self.plan["scenes"][0]["end_frame"] = 30
        self.plan["scenes"][0]["pause_frames"] = 0
        scene.update(start_frame=30, pause_frames=0)
        self.plan["scenes"].append(scene)
        self.assertFalse(self.check()["passed"])

    def test_template_rejected(self):
        self.plan["title"] = "Replace with title"
        self.assertFalse(self.check()["passed"])

    def test_valid_streams(self):
        self.assertEqual(demo_checks.check_streams(self.metadata, self.plan, 60), [])

    def test_audio_drift_rejected(self):
        self.metadata["streams"].append({"codec_type": "audio"})
        self.assertTrue(demo_checks.check_streams(self.metadata, self.plan, 60))
        self.plan["audio"] = "voiceover"
        self.assertEqual(demo_checks.check_streams(self.metadata, self.plan, 60), [])
        self.metadata["streams"].pop()
        self.assertTrue(demo_checks.check_streams(self.metadata, self.plan, 60))

    def test_wrong_rate_frames_and_size_rejected(self):
        self.metadata["streams"][0].update(width=1280, nb_read_frames="59", avg_frame_rate="29/1")
        self.assertEqual(len(demo_checks.check_streams(self.metadata, self.plan, 60)), 3)

    def test_faststart_parses_atoms(self):
        movie = self.root / "movie.mp4"
        atom = lambda name: struct.pack(">I4s", 8, name)
        movie.write_bytes(atom(b"ftyp") + atom(b"moov") + atom(b"mdat"))
        self.assertTrue(demo_checks.mp4_faststart(movie))
        movie.write_bytes(atom(b"ftyp") + atom(b"mdat") + atom(b"moov"))
        self.assertFalse(demo_checks.mp4_faststart(movie))

    def test_invalid_atom_rejected(self):
        movie = self.root / "movie.mp4"
        movie.write_bytes(struct.pack(">I4s", 100, b"moov"))
        with self.assertRaises(ValueError):
            demo_checks.mp4_faststart(movie)


if __name__ == "__main__":
    unittest.main()
