# JSON-mode install request parsing and non-interactive plan application.

install::json_request_schema() {
  printf '%s' "dotfiles.install.request.v1"
}

install::read_stdin_all() {
  cat
}

install::json_parse_with_python() {
  local input_file="$1"

  python3 - "$input_file" <<'PY'
import json
import re
import shlex
import sys

path = sys.argv[1]
allowed = {
    "schema",
    "profile",
    "modules",
    "items",
    "theme",
    "packageManager",
    "reviewSelectedItems",
    "git",
    "summaryAction",
    "runThemeInstall",
    "allowAutoLaunchZsh",
}
git_allowed = {"identityMode", "name", "email", "signingMode", "signingKey"}
id_pattern = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9_-]*$")

def fail(message, field="", value=""):
    print(f"INSTALL_JSON_PARSE_ERROR={shlex.quote(message)}")
    print(f"INSTALL_JSON_PARSE_FIELD={shlex.quote(field)}")
    print(f"INSTALL_JSON_PARSE_VALUE={shlex.quote(value)}")
    raise SystemExit(0)

try:
    text = open(path, encoding="utf-8").read()
except OSError as exc:
    fail("unable to read JSON request", "stdin", str(exc))

if not text.strip():
    fail("missing JSON request", "stdin", "")

try:
    data = json.loads(text)
except json.JSONDecodeError as exc:
    fail("invalid JSON request", "stdin", exc.msg)

if not isinstance(data, dict):
    fail("JSON request must be an object", "stdin", type(data).__name__)

for key in data:
    if key not in allowed:
        fail("unknown JSON request field", key, "")

schema = data.get("schema")
if schema != "dotfiles.install.request.v1":
    fail("invalid JSON request schema", "schema", "" if schema is None else str(schema))

def emit(key, value):
    print(f"{key}={shlex.quote(str(value))}")

def valid_id(value):
    return isinstance(value, str) and bool(value) and id_pattern.match(value)

emit("INSTALL_JSON_SCHEMA", schema)

if "profile" in data:
    if not valid_id(data["profile"]):
        fail("profile must be a profile ID", "profile", str(data["profile"]))
    emit("INSTALL_JSON_PROFILE", data["profile"])

if "modules" in data:
    if not isinstance(data["modules"], list) or not all(valid_id(item) for item in data["modules"]):
        fail("modules must be an array of module IDs", "modules", "")
    emit("INSTALL_JSON_MODULES", " ".join(data["modules"]))

if "items" in data:
    if not isinstance(data["items"], dict):
        fail("items must be an object", "items", "")
    item_modules = []
    for module_id, item_ids in data["items"].items():
        if not valid_id(module_id):
            fail("items keys must be module IDs", "items", str(module_id))
        if not isinstance(item_ids, list) or not all(valid_id(item) for item in item_ids):
            fail("items values must be arrays of item IDs", f"items.{module_id}", "")
        safe_module = module_id.replace("-", "_")
        item_modules.append(module_id)
        emit(f"INSTALL_JSON_HAS_ITEMS__{safe_module}", "1")
        emit(f"INSTALL_JSON_ITEMS__{safe_module}", " ".join(item_ids))
    emit("INSTALL_JSON_ITEM_MODULES", " ".join(item_modules))

for field in ("theme", "packageManager", "summaryAction"):
    if field in data:
        if not valid_id(data[field]):
            fail(f"{field} must be an ID", field, str(data[field]))
        emit("INSTALL_JSON_" + field.replace("packageManager", "PACKAGE_MANAGER").replace("summaryAction", "SUMMARY_ACTION").upper(), data[field])

for field in ("reviewSelectedItems", "runThemeInstall", "allowAutoLaunchZsh"):
    if field in data:
        if not isinstance(data[field], bool):
            fail(f"{field} must be a boolean", field, str(data[field]))
        emit("INSTALL_JSON_" + field.replace("reviewSelectedItems", "REVIEW_SELECTED_ITEMS").replace("runThemeInstall", "RUN_THEME_INSTALL").replace("allowAutoLaunchZsh", "ALLOW_AUTO_LAUNCH_ZSH").upper(), "1" if data[field] else "0")

if "git" in data:
    git = data["git"]
    if not isinstance(git, dict):
        fail("git must be an object", "git", "")
    for key in git:
        if key not in git_allowed:
            fail("unknown git field", f"git.{key}", "")
    emit("INSTALL_JSON_HAS_GIT", "1")
    mapping = {
        "identityMode": "GIT_IDENTITY_MODE",
        "name": "GIT_NAME",
        "email": "GIT_EMAIL",
        "signingMode": "GIT_SIGNING_MODE",
        "signingKey": "GIT_SIGNING_KEY",
    }
    for field, env_name in mapping.items():
        if field not in git:
            continue
        if not isinstance(git[field], str):
            fail(f"git.{field} must be a string", f"git.{field}", str(git[field]))
        emit("INSTALL_JSON_" + env_name, git[field])
PY
}

install::json_eval_assignments() {
  local assignments="$1"

  eval "$assignments"
}

install::json_parse_request() {
  local request_text="$1"
  local request_file assignments

  if [[ -z "${request_text//[[:space:]]/}" ]]; then
    ui::input_required "JSON mode requires an install request on stdin" \
      $'field\tstdin' \
      $'schema\t'"$(install::json_request_schema)"
    return 1
  fi

  request_file="$(mktemp "${TMPDIR:-/tmp}/dotfiles-install-request.XXXXXX")"
  printf '%s' "$request_text" >"$request_file"

  if ! command -v python3 >/dev/null 2>&1; then
    rm -f "$request_file"
    ui::validation_error "missing required command" \
      $'command\tpython3' \
      $'usage\tinstall < request.json'
    return 1
  fi

  assignments="$(install::json_parse_with_python "$request_file")"
  rm -f "$request_file"
  install::json_eval_assignments "$assignments"

  if [[ -n "${INSTALL_JSON_PARSE_ERROR:-}" ]]; then
    ui::validation_error "$INSTALL_JSON_PARSE_ERROR" \
      $'field\t'"${INSTALL_JSON_PARSE_FIELD:-stdin}" \
      $'value\t'"${INSTALL_JSON_PARSE_VALUE:-}"
    return 1
  fi
}

install::catalog_id_exists() {
  local id="$1"
  shift
  local record record_id

  while IFS= read -r record; do
    record_id="${record%%$'\t'*}"
    [[ "$record_id" == "$id" ]] && return 0
  done < <("$@")

  return 1
}

install::validate_json_word_ids() {
  local field="$1"
  local words="$2"
  shift 2
  local id

  for id in $words; do
    if ! install::catalog_id_exists "$id" "$@"; then
      ui::validation_error "invalid JSON request value" \
        $'field\t'"$field" \
        $'value\t'"$id"
      return 1
    fi
  done
}

install::validate_json_single_id() {
  local field="$1"
  local id="$2"
  shift 2

  case "$id" in
    *[!A-Za-z0-9_-]*|"")
      ui::validation_error "invalid JSON request value" \
        $'field\t'"$field" \
        $'value\t'"$id"
      return 1
      ;;
  esac

  if ! install::catalog_id_exists "$id" "$@"; then
    ui::validation_error "invalid JSON request value" \
      $'field\t'"$field" \
      $'value\t'"$id"
    return 1
  fi
}

install::validate_json_package_manager() {
  local package_manager="$1"

  case "$DOTFILES_PLATFORM" in
    macos)
      [[ "$package_manager" == "brew" ]] && return 0
      ;;
    linux)
      case "$package_manager" in
        apt|brew) return 0 ;;
      esac
      ;;
  esac

  ui::validation_error "invalid package manager for platform" \
    $'field\tpackageManager' \
    $'value\t'"$package_manager" \
    $'platform\t'"$DOTFILES_PLATFORM"
  return 1
}

install::record_id_exists() {
  local wanted_id="$1"
  shift || true
  local record id

  for record in "$@"; do
    id="$(prompt::record_field "$record" 1)"
    [[ "$id" == "$wanted_id" ]] && return 0
  done

  return 1
}

install::validate_json_item_ids() {
  local module_id="$1"
  local words="$2"
  shift 2 || true
  local id

  for id in $words; do
    if ! install::record_id_exists "$id" "$@"; then
      ui::validation_error "invalid JSON request value" \
        $'field\t'"items.$module_id" \
        $'value\t'"$id"
      return 1
    fi
  done
}

install::validate_json_item_modules() {
  local module_id

  for module_id in ${INSTALL_JSON_ITEM_MODULES:-}; do
    if ! install::catalog_id_exists "$module_id" catalog::module_records "$DOTFILES_PLATFORM"; then
      ui::validation_error "invalid JSON request value" \
        $'field\t'"items.$module_id" \
        $'value\t'"$module_id"
      return 1
    fi

    if ! install::module_is_selected "$module_id"; then
      ui::validation_error "JSON request items target is not selected" \
        $'field\t'"items.$module_id" \
        $'value\t'"$module_id"
      return 1
    fi

    if ! catalog::module_is_leaf "$module_id"; then
      ui::validation_error "JSON request items target does not accept items" \
        $'field\t'"items.$module_id" \
        $'value\t'"$module_id"
      return 1
    fi
  done
}

install::json_items_var_suffix() {
  local module_id="$1"
  printf '%s' "${module_id//-/_}"
}

install::json_has_items_for_module() {
  local module_id="$1"
  local suffix

  suffix="$(install::json_items_var_suffix "$module_id")"
  install::named_value_is_set "INSTALL_JSON_HAS_ITEMS__${suffix}"
}

install::json_items_for_module() {
  local module_id="$1"
  local suffix

  suffix="$(install::json_items_var_suffix "$module_id")"
  install::get_named_value "INSTALL_JSON_ITEMS__${suffix}"
}

install::apply_json_leaf_items() {
  local module_id leaf_ids selectable_count
  local leaf_options=()

  for module_id in "${MODULE_ORDER[@]}"; do
    if ! install::module_is_selected "$module_id" || ! catalog::module_is_leaf "$module_id"; then
      continue
    fi

    install::prepare_leaf_options "$module_id" leaf_options
    selectable_count="$(install::count_selectable_records "${leaf_options[@]}")"

    if install::json_has_items_for_module "$module_id"; then
      leaf_ids="$(install::json_items_for_module "$module_id")"
      install::validate_json_item_ids "$module_id" "$leaf_ids" "${leaf_options[@]}" || return 1
    elif [[ "${DOTFILES_REVIEW_SELECTED_ITEMS:-no}" == "yes" ]]; then
      ui::input_required "JSON request must include selected items for requested review" \
        $'field\t'"items.$module_id" \
        $'module\t'"$module_id"
      return 1
    else
      leaf_ids="$(install::selected_ids_from_records "${leaf_options[@]}")"
    fi

    install::apply_leaf_selection "$module_id" "$leaf_ids" "$selectable_count" "${leaf_options[@]}"
  done
}

install::apply_json_git_identity() {
  local personal_file_display

  if ! install::module_is_selected "dotfiles"; then
    install::clear_git_identity_state
    return 0
  fi

  personal_file_display="$(install::git_personal_config_display_path)"

  case "${INSTALL_JSON_GIT_IDENTITY_MODE:-}" in
    "")
      if ! dotfiles_git_personal_config_is_template "$(install::git_personal_config_path)"; then
        DOTFILES_GIT_IDENTITY_MODE="reuse_existing"
        DOTFILES_GIT_CONFIGURE_PERSONAL="no"
        DOTFILES_GIT_SUMMARY="Existing machine-local Git identity at $personal_file_display. You can edit it directly later."
      else
        DOTFILES_GIT_IDENTITY_MODE="skip_for_now"
        DOTFILES_GIT_CONFIGURE_PERSONAL="no"
        DOTFILES_GIT_SUMMARY="Git identity setup skipped for now. Edit $personal_file_display directly later if needed."
      fi
      ;;
    reuse_existing)
      DOTFILES_GIT_IDENTITY_MODE="reuse_existing"
      DOTFILES_GIT_CONFIGURE_PERSONAL="no"
      DOTFILES_GIT_SUMMARY="Current machine-local Git file state at $personal_file_display will be kept as-is. You can edit it directly later."
      ;;
    skip_for_now)
      DOTFILES_GIT_IDENTITY_MODE="skip_for_now"
      DOTFILES_GIT_CONFIGURE_PERSONAL="no"
      DOTFILES_GIT_SUMMARY="Git identity setup skipped for now. Edit $personal_file_display directly later if needed."
      ;;
    configure_now)
      DOTFILES_GIT_IDENTITY_MODE="configure_now"
      DOTFILES_GIT_CONFIGURE_PERSONAL="yes"
      DOTFILES_GIT_NAME="${INSTALL_JSON_GIT_NAME:-}"
      DOTFILES_GIT_EMAIL="${INSTALL_JSON_GIT_EMAIL:-}"
      DOTFILES_GIT_SIGNING_MODE="${INSTALL_JSON_GIT_SIGNING_MODE:-none}"
      DOTFILES_GIT_SIGNING_KEY="${INSTALL_JSON_GIT_SIGNING_KEY:-}"
      if [[ -z "$DOTFILES_GIT_NAME" ]]; then
        ui::input_required "JSON request must include Git name" $'field\tgit.name'
        return 1
      fi
      if ! install::git_email_is_valid "$DOTFILES_GIT_EMAIL"; then
        ui::validation_error "invalid Git email" $'field\tgit.email' $'value\t'"$DOTFILES_GIT_EMAIL"
        return 1
      fi
      case "$DOTFILES_GIT_SIGNING_MODE" in
        none)
          DOTFILES_GIT_SIGNING_KEY=""
          DOTFILES_GIT_SUMMARY="Machine-local Git identity without signing at $personal_file_display."
          ;;
        gpg|ssh)
          if [[ -z "$DOTFILES_GIT_SIGNING_KEY" ]]; then
            ui::input_required "JSON request must include Git signing key" $'field\tgit.signingKey'
            return 1
          fi
          DOTFILES_GIT_SUMMARY="Machine-local Git identity with ${DOTFILES_GIT_SIGNING_MODE} signing at $personal_file_display."
          ;;
        *)
          ui::validation_error "invalid Git signing mode" $'field\tgit.signingMode' $'value\t'"$DOTFILES_GIT_SIGNING_MODE"
          return 1
          ;;
      esac
      ;;
    *)
      ui::validation_error "invalid Git identity mode" $'field\tgit.identityMode' $'value\t'"$INSTALL_JSON_GIT_IDENTITY_MODE"
      return 1
      ;;
  esac
}

install::apply_json_request() {
  DOTFILES_INSTALL_PROFILE="${INSTALL_JSON_PROFILE:-recommended}"
  install::validate_json_single_id "profile" "$DOTFILES_INSTALL_PROFILE" catalog::profile_records "$DOTFILES_PLATFORM" || return 1
  DOTFILES_INSTALL_PROFILE_LABEL="$(catalog::profile_label "$DOTFILES_INSTALL_PROFILE")"

  if [[ "$DOTFILES_INSTALL_PROFILE" == "custom" ]]; then
    DOTFILES_SELECTED_MODULES="${INSTALL_JSON_MODULES:-}"
    if [[ -z "$DOTFILES_SELECTED_MODULES" ]]; then
      ui::input_required "custom profile requires modules in JSON request" $'field\tmodules'
      return 1
    fi
  else
    install::apply_profile_defaults
    if [[ -n "${INSTALL_JSON_MODULES:-}" ]]; then
      DOTFILES_SELECTED_MODULES="$INSTALL_JSON_MODULES"
    fi
  fi

  DOTFILES_REQUESTED_MODULES="$DOTFILES_SELECTED_MODULES"
  install::validate_json_word_ids "modules" "$DOTFILES_SELECTED_MODULES" catalog::module_records "$DOTFILES_PLATFORM" || return 1

  if [[ -n "${INSTALL_JSON_THEME:-}" ]]; then
    install::validate_json_single_id "theme" "$INSTALL_JSON_THEME" catalog::theme_records || return 1
    DOTFILES_THEME="$INSTALL_JSON_THEME"
  fi

  if [[ -n "${INSTALL_JSON_PACKAGE_MANAGER:-}" ]]; then
    install::validate_json_package_manager "$INSTALL_JSON_PACKAGE_MANAGER" || return 1
    DOTFILES_PACKAGE_MANAGER="$INSTALL_JSON_PACKAGE_MANAGER"
  fi

  case "${INSTALL_JSON_REVIEW_SELECTED_ITEMS:-0}" in
    0) DOTFILES_REVIEW_SELECTED_ITEMS="no" ;;
    1) DOTFILES_REVIEW_SELECTED_ITEMS="yes" ;;
  esac

  if [[ -n "${INSTALL_JSON_RUN_THEME_INSTALL:-}" ]]; then
    DOTFILES_RUN_THEME_INSTALL="$INSTALL_JSON_RUN_THEME_INSTALL"
  fi
  if [[ -n "${INSTALL_JSON_ALLOW_AUTO_LAUNCH_ZSH:-}" ]]; then
    DOTFILES_ALLOW_AUTO_LAUNCH_ZSH="$INSTALL_JSON_ALLOW_AUTO_LAUNCH_ZSH"
  else
    DOTFILES_ALLOW_AUTO_LAUNCH_ZSH="0"
  fi

  install::clear_unselected_leaf_item_state
  if install::plan_needs_theme_prompt; then
    DOTFILES_THEME_NEEDED="1"
    if [[ -z "${INSTALL_JSON_RUN_THEME_INSTALL:-}" ]]; then
      DOTFILES_RUN_THEME_INSTALL="1"
    fi
  else
    DOTFILES_THEME_NEEDED="0"
    if [[ -z "${INSTALL_JSON_RUN_THEME_INSTALL:-}" ]]; then
      DOTFILES_RUN_THEME_INSTALL="0"
    fi
  fi
  if install::plan_needs_package_manager; then
    DOTFILES_PACKAGE_MANAGER_NEEDED="1"
  else
    DOTFILES_PACKAGE_MANAGER_NEEDED="0"
  fi
  install::resolve_install_plan
  install::validate_json_item_modules || return 1
  install::apply_json_leaf_items || return 1
  install::resolve_install_plan
  install::clear_unselected_leaf_item_state
  install::apply_json_git_identity || return 1
  install::finalize_runtime_state
  if [[ -n "${INSTALL_JSON_ALLOW_AUTO_LAUNCH_ZSH:-}" ]]; then
    DOTFILES_ALLOW_AUTO_LAUNCH_ZSH="$INSTALL_JSON_ALLOW_AUTO_LAUNCH_ZSH"
  else
    DOTFILES_ALLOW_AUTO_LAUNCH_ZSH="0"
  fi

  DOTFILES_SUMMARY_ACTION="${INSTALL_JSON_SUMMARY_ACTION:-proceed}"
  case "$DOTFILES_SUMMARY_ACTION" in
    proceed|cancel) ;;
    *)
      ui::validation_error "invalid summary action" $'field\tsummaryAction' $'value\t'"$DOTFILES_SUMMARY_ACTION"
      return 1
      ;;
  esac
}

install::run_json_request() {
  local request_text

  request_text="$(install::read_stdin_all)"
  install::json_parse_request "$request_text" || return 1
  install::apply_json_request || return 1

  if [[ "$DOTFILES_SUMMARY_ACTION" == "cancel" ]]; then
    ui::json_event install_cancelled install "{\"summaryAction\":\"cancel\"}"
    return 0
  fi

  install::run_install_plan_or_exit "Installation failed."
}
