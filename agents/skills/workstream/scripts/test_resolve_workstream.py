from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


sys.dont_write_bytecode = True
MODULE_PATH = Path(__file__).with_name("resolve_workstream.py")
SPEC = importlib.util.spec_from_file_location("resolve_workstream", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


def secure_filesystem_available() -> bool:
    required_dir_fd = (MODULE.os.open, MODULE.os.mkdir, MODULE.os.link, MODULE.os.unlink)
    return (
        all(function in MODULE.os.supports_dir_fd for function in required_dir_fd)
        and MODULE.os.listdir in MODULE.os.supports_fd
        and hasattr(MODULE.os, "O_DIRECTORY")
        and hasattr(MODULE.os, "O_NOFOLLOW")
        and hasattr(MODULE.os, "O_NONBLOCK")
    )


SECURE_FILESYSTEM_AVAILABLE = secure_filesystem_available()


class ResolveWorkstreamTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.repo = Path(self.tempdir.name)

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def build(self, **overrides):
        values = {
            "repo_root": str(self.repo),
            "goal": "Add user authentication",
            "artifact_depth": "standard",
            "intent_source_kind": "plan-local",
        }
        values.update(overrides)
        return MODULE.build_layout(**values)

    def test_goal_normalization_is_stable(self) -> None:
        first = self.build(goal="  Add   User Authentication  ")
        second = self.build(goal="add user authentication")
        self.assertEqual(first, second)
        self.assertEqual(first.slug, second.slug)
        self.assertEqual(first.goal_hash, second.goal_hash)

    def test_non_ascii_goal_has_deterministic_fallback(self) -> None:
        layout = self.build(goal="사용자 인증 추가")
        self.assertRegex(layout.slug, r"^goal-[0-9a-f]{10}$")

    def test_explicit_slug_is_strict(self) -> None:
        self.assertEqual(self.build(slug="account-email-change").slug, "account-email-change")
        with self.assertRaises(MODULE.ResolutionError):
            self.build(slug="Account Email")

    def test_canonical_paths_and_project(self) -> None:
        layout = self.build(slug="account-email-change")
        expected = self.repo.resolve() / ".tasks" / "items" / "account-email-change"
        self.assertEqual(Path(layout.work_dir), expected)
        self.assertEqual(layout.work_dir_relative, ".tasks/items/account-email-change")
        self.assertEqual(layout.task_project, "account-email-change")
        self.assertEqual(Path(layout.manifest_path), expected / "manifest.json")
        self.assertEqual(Path(layout.plan_path), expected / "plan.md")
        self.assertEqual(
            layout.plan_path_relative,
            ".tasks/items/account-email-change/plan.md",
        )
        self.assertEqual(Path(layout.validation_path), expected / "validation.md")
        self.assertEqual(Path(layout.review_path), expected / "review.md")

    def test_external_intent_omits_local_spec(self) -> None:
        external = self.build(
            intent_source_kind="authoritative",
            intent_source="https://example.test/rfc/42",
        )
        local = self.build()
        light = self.build(artifact_depth="light")
        self.assertFalse(external.spec_required)
        self.assertIsNone(external.spec_path)
        self.assertTrue(local.spec_required)
        self.assertIsNotNone(local.spec_path)
        self.assertFalse(light.spec_required)

    def test_intent_source_contract_is_strict_and_preserves_content(self) -> None:
        with self.assertRaises(MODULE.ResolutionError):
            self.build(intent_source="plan-local")
        with self.assertRaises(MODULE.ResolutionError):
            self.build(intent_source_kind="authoritative")
        with self.assertRaises(MODULE.ResolutionError):
            self.build(intent_source_kind="plan-lcoal")

        layout = self.build(
            intent_source_kind="authoritative",
            intent_source="docs/My  RFC.md",
        )
        self.assertEqual(layout.intent_source, "docs/My  RFC.md")
        exact = self.build(
            intent_source_kind="authoritative",
            intent_source=" docs/My  RFC.md ",
        )
        self.assertEqual(exact.intent_source, " docs/My  RFC.md ")

    def test_canonical_symlink_escape_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as outside:
            try:
                (self.repo / ".tasks").symlink_to(outside, target_is_directory=True)
            except OSError as exc:
                self.skipTest(f"symlink unavailable: {exc}")
            with self.assertRaises(MODULE.ResolutionError):
                self.build(slug="escaped")

    def test_internal_symlink_alias_is_rejected(self) -> None:
        target = self.repo / "local-state"
        target.mkdir()
        try:
            (self.repo / ".tasks").symlink_to(target, target_is_directory=True)
        except OSError as exc:
            self.skipTest(f"symlink unavailable: {exc}")
        with self.assertRaises(MODULE.ResolutionError):
            self.build(slug="aliased")

    def test_secure_primitive_policy_is_explicit(self) -> None:
        layout = self.build(slug="capability-check")
        if SECURE_FILESYSTEM_AVAILABLE:
            MODULE.require_secure_filesystem_primitives()
        else:
            with self.assertRaises(MODULE.ResolutionError):
                MODULE.resolve_manifest(layout, initialize=True)

    @unittest.skipUnless(SECURE_FILESYSTEM_AVAILABLE, "secure dir-fd APIs unavailable")
    def test_manifest_reuse_and_collision(self) -> None:
        first = self.build(slug="stable-work")
        created = MODULE.resolve_manifest(first, initialize=True)
        self.assertEqual(created.manifest_status, "created")
        reused = MODULE.resolve_manifest(first, initialize=True)
        self.assertEqual(reused.manifest_status, "reused")

        collision = self.build(slug="stable-work", goal="Different goal")
        with self.assertRaises(MODULE.ResolutionError):
            MODULE.resolve_manifest(collision, initialize=False)

        depth_collision = self.build(slug="stable-work", artifact_depth="light")
        with self.assertRaises(MODULE.ResolutionError):
            MODULE.resolve_manifest(depth_collision, initialize=False)

        path = Path(first.work_dir)
        self.assertFalse(
            any(entry.name.startswith(MODULE.TEMP_MANIFEST_PREFIX) for entry in path.iterdir())
        )

    @unittest.skipUnless(SECURE_FILESYSTEM_AVAILABLE, "secure dir-fd APIs unavailable")
    def test_manifest_symlink_is_rejected(self) -> None:
        layout = self.build(slug="manifest-link")
        work_dir = Path(layout.work_dir)
        work_dir.mkdir(parents=True)
        external = self.repo / "external.json"
        external.write_text("{}\n", encoding="utf-8")
        try:
            (work_dir / MODULE.MANIFEST_NAME).symlink_to(external)
        except OSError as exc:
            self.skipTest(f"symlink unavailable: {exc}")
        with self.assertRaises(MODULE.ResolutionError):
            MODULE.resolve_manifest(layout, initialize=False)

    @unittest.skipUnless(SECURE_FILESYSTEM_AVAILABLE, "secure dir-fd APIs unavailable")
    def test_symlink_swap_before_init_is_rejected(self) -> None:
        layout = self.build(slug="race")
        with tempfile.TemporaryDirectory() as outside:
            try:
                (self.repo / ".tasks").symlink_to(outside, target_is_directory=True)
            except OSError as exc:
                self.skipTest(f"symlink unavailable: {exc}")
            with self.assertRaises(MODULE.ResolutionError):
                MODULE.resolve_manifest(layout, initialize=True)

    @unittest.skipUnless(SECURE_FILESYSTEM_AVAILABLE, "secure dir-fd APIs unavailable")
    def test_work_directory_file_is_rejected(self) -> None:
        layout = self.build(slug="not-a-directory")
        path = Path(layout.work_dir)
        path.parent.mkdir(parents=True)
        path.write_text("file", encoding="utf-8")
        with self.assertRaises(MODULE.ResolutionError):
            MODULE.resolve_manifest(layout, initialize=False)

    @unittest.skipUnless(SECURE_FILESYSTEM_AVAILABLE, "secure dir-fd APIs unavailable")
    def test_unmanaged_nonempty_directory_is_rejected(self) -> None:
        layout = self.build(slug="unmanaged")
        path = Path(layout.work_dir)
        path.mkdir(parents=True)
        (path / "plan.md").write_text("unmanaged", encoding="utf-8")
        with self.assertRaises(MODULE.ResolutionError):
            MODULE.resolve_manifest(layout, initialize=False)

    @unittest.skipUnless(SECURE_FILESYSTEM_AVAILABLE, "secure dir-fd APIs unavailable")
    def test_temp_prefixed_entry_does_not_make_directory_managed(self) -> None:
        layout = self.build(slug="temp-user-data")
        path = Path(layout.work_dir)
        path.mkdir(parents=True)
        (path / f"{MODULE.TEMP_MANIFEST_PREFIX}user-data").write_text(
            "user data", encoding="utf-8"
        )
        with self.assertRaises(MODULE.ResolutionError):
            MODULE.resolve_manifest(layout, initialize=True)
        self.assertFalse((path / MODULE.MANIFEST_NAME).exists())

    @unittest.skipUnless(SECURE_FILESYSTEM_AVAILABLE, "secure dir-fd APIs unavailable")
    def test_fifo_manifest_is_rejected_without_blocking(self) -> None:
        if not hasattr(MODULE.os, "mkfifo"):
            self.skipTest("FIFO unavailable")
        layout = self.build(slug="fifo-manifest")
        path = Path(layout.work_dir)
        path.mkdir(parents=True)
        MODULE.os.mkfifo(path / MODULE.MANIFEST_NAME)
        with self.assertRaises(MODULE.ResolutionError):
            MODULE.resolve_manifest(layout, initialize=False)


if __name__ == "__main__":
    unittest.main()
