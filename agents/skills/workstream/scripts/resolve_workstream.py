#!/usr/bin/env python3
"""Resolve and optionally initialize deterministic workstream identity paths."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import secrets
import stat
import sys
import unicodedata
from dataclasses import asdict, dataclass
from pathlib import Path


SCHEMA_VERSION = 3
SLUG_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
ASCII_TOKEN_RE = re.compile(r"[a-z0-9]+")
STATE_ROOT = ".tasks"
ITEMS_DIR = "items"
MANIFEST_NAME = "manifest.json"
TEMP_MANIFEST_PREFIX = ".manifest.json.tmp-"


class ResolutionError(ValueError):
    """Raised when deterministic resolution cannot continue safely."""


@dataclass(frozen=True)
class WorkstreamLayout:
    schema_version: int
    repo_root: str
    slug: str
    goal: str
    goal_identity: str
    goal_hash: str
    artifact_depth: str
    intent_source_kind: str
    intent_source: str
    task_project: str
    work_dir: str
    work_dir_relative: str
    manifest_path: str
    manifest_path_relative: str
    spec_required: bool
    spec_path: str | None
    spec_path_relative: str | None
    plan_path: str
    plan_path_relative: str
    validation_path: str
    validation_path_relative: str
    manifest_status: str = "absent"


def normalize_goal(goal: str) -> tuple[str, str]:
    display = re.sub(r"\s+", " ", unicodedata.normalize("NFKC", goal)).strip()
    if not display:
        raise ResolutionError("goal must contain non-whitespace text")
    identity = display.casefold()
    return identity, identity


def validate_explicit_slug(slug: str) -> str:
    if len(slug) > 63:
        raise ResolutionError("explicit slug must be 63 characters or fewer")
    if not SLUG_RE.fullmatch(slug):
        raise ResolutionError(
            "explicit slug must be lowercase ASCII kebab-case: [a-z0-9]+(-[a-z0-9]+)*"
        )
    return slug


def derive_slug(identity_goal: str, digest: str) -> str:
    ascii_goal = (
        unicodedata.normalize("NFKD", identity_goal)
        .encode("ascii", "ignore")
        .decode("ascii")
    )
    tokens = ASCII_TOKEN_RE.findall(ascii_goal)
    prefix = "-".join(tokens[:5]) or "goal"
    prefix = prefix[:48].strip("-") or "goal"
    return f"{prefix}-{digest}"


def resolve_repo_root(value: str) -> Path:
    root = Path(value).expanduser().resolve()
    if not root.is_dir():
        raise ResolutionError(f"repo root is not a directory: {root}")
    return root


def resolve_work_dir(repo_root: Path, slug: str) -> Path:
    candidate = repo_root / STATE_ROOT / ITEMS_DIR / slug
    resolved = candidate.resolve()
    try:
        resolved.relative_to(repo_root)
    except ValueError as exc:
        raise ResolutionError("canonical task record path escapes repo root") from exc
    if resolved != candidate:
        raise ResolutionError("canonical task record path cannot contain symlinks")
    return candidate


def build_layout(
    *,
    repo_root: str,
    goal: str,
    artifact_depth: str,
    slug: str | None = None,
    intent_source_kind: str = "plan-local",
    intent_source: str | None = None,
) -> WorkstreamLayout:
    root = resolve_repo_root(repo_root)
    display_goal, identity_goal = normalize_goal(goal)
    digest = hashlib.sha256(identity_goal.encode("utf-8")).hexdigest()[:10]
    resolved_slug = validate_explicit_slug(slug) if slug else derive_slug(identity_goal, digest)
    resolved_work_dir = resolve_work_dir(root, resolved_slug)
    if intent_source_kind == "plan-local":
        if intent_source is not None:
            raise ResolutionError("plan-local intent forbids --intent-source")
        source = "plan-local"
    elif intent_source_kind == "authoritative":
        if intent_source is None or not intent_source.strip():
            raise ResolutionError("authoritative intent requires --intent-source")
        source = intent_source
        if any(character in source for character in ("\x00", "\r", "\n")):
            raise ResolutionError("authoritative intent source must be one line without NUL")
    else:
        raise ResolutionError("intent source kind must be plan-local or authoritative")

    spec_required = artifact_depth != "light" and intent_source_kind == "plan-local"
    work_dir_relative = resolved_work_dir.relative_to(root).as_posix()
    return WorkstreamLayout(
        schema_version=SCHEMA_VERSION,
        repo_root=str(root),
        slug=resolved_slug,
        goal=display_goal,
        goal_identity=identity_goal,
        goal_hash=digest,
        artifact_depth=artifact_depth,
        intent_source_kind=intent_source_kind,
        intent_source=source,
        task_project=resolved_slug,
        work_dir=str(resolved_work_dir),
        work_dir_relative=work_dir_relative,
        manifest_path=str(resolved_work_dir / MANIFEST_NAME),
        manifest_path_relative=f"{work_dir_relative}/{MANIFEST_NAME}",
        spec_required=spec_required,
        spec_path=str(resolved_work_dir / "spec.md") if spec_required else None,
        spec_path_relative=f"{work_dir_relative}/spec.md" if spec_required else None,
        plan_path=str(resolved_work_dir / "plan.md"),
        plan_path_relative=f"{work_dir_relative}/plan.md",
        validation_path=str(resolved_work_dir / "validation.md"),
        validation_path_relative=f"{work_dir_relative}/validation.md",
    )


def expected_manifest(layout: WorkstreamLayout) -> dict[str, object]:
    return {
        "schema_version": layout.schema_version,
        "slug": layout.slug,
        "goal_identity": layout.goal_identity,
        "goal_hash": layout.goal_hash,
        "artifact_depth": layout.artifact_depth,
        "intent_source_kind": layout.intent_source_kind,
        "intent_source": layout.intent_source,
        "task_project": layout.task_project,
    }


def require_secure_filesystem_primitives() -> None:
    required_dir_fd = (os.open, os.mkdir, os.link, os.unlink)
    missing = [function.__name__ for function in required_dir_fd if function not in os.supports_dir_fd]
    if os.listdir not in os.supports_fd:
        missing.append("listdir(fd)")
    required_flags = ("O_DIRECTORY", "O_NOFOLLOW", "O_NONBLOCK")
    absent_flags = [name for name in required_flags if not hasattr(os, name)]
    if absent_flags:
        missing.append("/".join(absent_flags))
    if missing:
        names = ", ".join(missing)
        raise ResolutionError(
            f"platform lacks secure no-follow task initialization primitives: {names}"
        )


def directory_flags() -> int:
    return os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW


def open_work_dir(layout: WorkstreamLayout, *, create: bool) -> int | None:
    require_secure_filesystem_primitives()
    parts = Path(layout.work_dir_relative).parts
    if not parts or any(part in ("", ".", "..") for part in parts):
        raise ResolutionError("resolved work directory contains an unsafe component")

    try:
        current_fd = os.open(layout.repo_root, directory_flags())
    except OSError as exc:
        raise ResolutionError(f"cannot securely open repo root: {layout.repo_root}") from exc

    for part in parts:
        try:
            if create:
                try:
                    os.mkdir(part, mode=0o755, dir_fd=current_fd)
                except FileExistsError:
                    pass
            next_fd = os.open(part, directory_flags(), dir_fd=current_fd)
        except FileNotFoundError:
            os.close(current_fd)
            return None
        except OSError as exc:
            os.close(current_fd)
            raise ResolutionError(
                f"task path component is not a safe directory: {part}"
            ) from exc
        os.close(current_fd)
        current_fd = next_fd

    return current_fd


def read_manifest_from_dir(work_dir_fd: int, layout: WorkstreamLayout) -> bool:
    try:
        manifest_fd = os.open(
            MANIFEST_NAME,
            os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW,
            dir_fd=work_dir_fd,
        )
    except FileNotFoundError:
        return False
    except OSError as exc:
        raise ResolutionError("manifest must be a regular non-symlink file") from exc

    try:
        if not stat.S_ISREG(os.fstat(manifest_fd).st_mode):
            raise ResolutionError("manifest must be a regular file")
        chunks: list[bytes] = []
        while chunk := os.read(manifest_fd, 65536):
            chunks.append(chunk)
        actual = json.loads(b"".join(chunks).decode("utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ResolutionError("cannot read a valid manifest") from exc
    finally:
        os.close(manifest_fd)

    if actual != expected_manifest(layout):
        raise ResolutionError(
            "task identity collision; use the original goal/depth/intent or an explicit new slug"
        )
    return True


def write_all(file_descriptor: int, payload: bytes) -> None:
    view = memoryview(payload)
    while view:
        written = os.write(file_descriptor, view)
        if written <= 0:
            raise ResolutionError("failed to write complete manifest")
        view = view[written:]


def publish_manifest(work_dir_fd: int, layout: WorkstreamLayout) -> str:
    payload = (json.dumps(expected_manifest(layout), indent=2, sort_keys=True) + "\n").encode(
        "utf-8"
    )
    temporary_name = f"{TEMP_MANIFEST_PREFIX}{os.getpid()}-{secrets.token_hex(6)}"
    temporary_fd: int | None = None
    try:
        temporary_fd = os.open(
            temporary_name,
            os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
            0o600,
            dir_fd=work_dir_fd,
        )
        write_all(temporary_fd, payload)
        os.fchmod(temporary_fd, 0o644)
        os.fsync(temporary_fd)
        os.close(temporary_fd)
        temporary_fd = None

        try:
            os.link(
                temporary_name,
                MANIFEST_NAME,
                src_dir_fd=work_dir_fd,
                dst_dir_fd=work_dir_fd,
                follow_symlinks=False,
            )
        except FileExistsError:
            read_manifest_from_dir(work_dir_fd, layout)
            return "reused"
        os.fsync(work_dir_fd)
        return "created"
    except ResolutionError:
        raise
    except OSError as exc:
        raise ResolutionError("cannot atomically publish manifest") from exc
    finally:
        if temporary_fd is not None:
            os.close(temporary_fd)
        try:
            os.unlink(temporary_name, dir_fd=work_dir_fd)
        except FileNotFoundError:
            pass
        except OSError as exc:
            raise ResolutionError("cannot remove temporary manifest") from exc


def resolve_manifest(layout: WorkstreamLayout, *, initialize: bool) -> WorkstreamLayout:
    work_dir_fd = open_work_dir(layout, create=initialize)
    if work_dir_fd is None:
        return WorkstreamLayout(**{**asdict(layout), "manifest_status": "absent"})
    try:
        if read_manifest_from_dir(work_dir_fd, layout):
            status = "reused"
        else:
            names = os.listdir(work_dir_fd)
            if names:
                raise ResolutionError(
                    "unmanaged non-empty task directory; do not adopt or suffix it automatically"
                )
            status = publish_manifest(work_dir_fd, layout) if initialize else "empty"
        return WorkstreamLayout(**{**asdict(layout), "manifest_status": status})
    finally:
        os.close(work_dir_fd)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", required=True, help="Absolute or relative repository root")
    parser.add_argument("--goal", required=True, help="Settled one-sentence goal")
    parser.add_argument(
        "--artifact-depth",
        required=True,
        choices=("light", "standard", "high-risk"),
    )
    parser.add_argument("--slug", help="Explicit lowercase ASCII kebab-case slug")
    parser.add_argument(
        "--intent-source-kind",
        required=True,
        choices=("plan-local", "authoritative"),
    )
    parser.add_argument(
        "--intent-source",
        help="Required exact path/URL/identifier when kind is authoritative",
    )
    parser.add_argument(
        "--init",
        action="store_true",
        help="Create the directory and identity manifest after successful resolution",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        layout = build_layout(
            repo_root=args.repo_root,
            goal=args.goal,
            artifact_depth=args.artifact_depth,
            slug=args.slug,
            intent_source_kind=args.intent_source_kind,
            intent_source=args.intent_source,
        )
        layout = resolve_manifest(layout, initialize=args.init)
    except ResolutionError as exc:
        parser.error(str(exc))
    json.dump(asdict(layout), sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
