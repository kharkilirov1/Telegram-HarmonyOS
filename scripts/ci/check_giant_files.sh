#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel)"
cd "${ROOT_DIR}"

ALLOWLIST_FILE=".github/giant-files.allowlist"
declare -A ALLOWLIST=()

if [[ -f "${ALLOWLIST_FILE}" ]]; then
  while IFS= read -r raw_line; do
    line="${raw_line%%#*}"
    line="$(echo "${line}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [[ -z "${line}" ]] && continue
    ALLOWLIST["${line}"]=1
  done < "${ALLOWLIST_FILE}"
fi

get_limit() {
  local path="$1"
  case "${path}" in
    entry/src/main/ets/pages/*|entry/src/main/ets/components/*)
      echo 350
      ;;
    entry/src/main/ets/controllers/*|entry/src/main/ets/services/*)
      echo 500
      ;;
    entry/src/main/ets/*)
      echo 450
      ;;
    *.ets|*.ts)
      echo 500
      ;;
    *)
      echo 0
      ;;
  esac
}

resolve_base_ref() {
  if [[ "${GITHUB_EVENT_NAME:-}" == "pull_request" && -n "${GITHUB_BASE_REF:-}" ]]; then
    git fetch --no-tags --depth=1 origin "${GITHUB_BASE_REF}" >/dev/null 2>&1 || true
    if git rev-parse --verify "origin/${GITHUB_BASE_REF}" >/dev/null 2>&1; then
      echo "origin/${GITHUB_BASE_REF}"
      return
    fi
  fi

  if [[ -n "${GITHUB_EVENT_BEFORE:-}" && "${GITHUB_EVENT_BEFORE}" != "0000000000000000000000000000000000000000" ]]; then
    if git rev-parse --verify "${GITHUB_EVENT_BEFORE}" >/dev/null 2>&1; then
      echo "${GITHUB_EVENT_BEFORE}"
      return
    fi
  fi

  if git rev-parse --verify HEAD~1 >/dev/null 2>&1; then
    echo "HEAD~1"
    return
  fi

  echo ""
}

BASE_REF="$(resolve_base_ref)"

if [[ -n "${BASE_REF}" ]]; then
  mapfile -t CHANGED < <(git diff --name-status --diff-filter=AMR "${BASE_REF}...HEAD")
else
  mapfile -t CHANGED < <(git diff-tree --no-commit-id --name-status -r HEAD --diff-filter=AMR)
fi

if [[ ${#CHANGED[@]} -eq 0 ]]; then
  echo "No changed files to check."
  exit 0
fi

violations=0

for row in "${CHANGED[@]}"; do
  status="$(awk '{print $1}' <<< "${row}")"
  current_path="$(awk '{print $2}' <<< "${row}")"
  previous_path="${current_path}"

  if [[ "${status}" == R* ]]; then
    previous_path="$(awk '{print $2}' <<< "${row}")"
    current_path="$(awk '{print $3}' <<< "${row}")"
    status="M"
  fi

  limit="$(get_limit "${current_path}")"
  if [[ "${limit}" -eq 0 ]]; then
    continue
  fi

  if [[ ! -f "${current_path}" ]]; then
    continue
  fi

  if [[ -n "${ALLOWLIST[${current_path}]+x}" ]]; then
    echo "::notice file=${current_path}::Skipped by ${ALLOWLIST_FILE}."
    continue
  fi

  current_lines="$(wc -l < "${current_path}" | tr -d '[:space:]')"
  previous_lines=0
  had_previous=0

  if [[ -n "${BASE_REF}" ]] && git cat-file -e "${BASE_REF}:${previous_path}" 2>/dev/null; then
    previous_lines="$(git show "${BASE_REF}:${previous_path}" | wc -l | tr -d '[:space:]')"
    had_previous=1
  fi

  if [[ "${status}" == "A" || "${had_previous}" -eq 0 ]]; then
    if (( current_lines > limit )); then
      echo "::error file=${current_path}::New file has ${current_lines} lines (limit ${limit}). Split responsibilities or add allowlist entry with reason."
      violations=$((violations + 1))
    fi
    continue
  fi

  if (( previous_lines <= limit && current_lines > limit )); then
    echo "::error file=${current_path}::File crossed size limit ${limit}: ${previous_lines} -> ${current_lines}. Decompose before merge."
    violations=$((violations + 1))
    continue
  fi

  if (( previous_lines > limit && current_lines > previous_lines )); then
    growth=$((current_lines - previous_lines))
    if (( growth > 30 )); then
      echo "::error file=${current_path}::Existing giant file grew by +${growth} lines (${previous_lines} -> ${current_lines}). Decompose or add temporary allowlist entry with reason."
      violations=$((violations + 1))
    else
      echo "::warning file=${current_path}::Existing giant file grew by +${growth} lines. Keep growth minimal."
    fi
  fi
done

if (( violations > 0 )); then
  echo "Giant-file guard failed: ${violations} violation(s)."
  exit 1
fi

echo "Giant-file guard passed."
