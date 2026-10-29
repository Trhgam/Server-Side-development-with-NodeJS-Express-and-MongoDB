#!/usr/bin/env bash
# ==============================================================================
# SDN302 PROJECT GENERATOR (pe-tool.sh)
# Express + Handlebars + Mongoose + Bootstrap CDN + JWT API + Session UI Authentication
# Single-file generator supporting Independent Entities (Lookup/Master),
# Dependent Entities (1-1 / N-1 Foreign Keys), and customizable View Layouts.
# Architecture: Master routes/index.js router + Function-based Controllers
# ==============================================================================

set -Eeuo pipefail

# --- Color Definitions ---
CLR_RESET="\033[0m"
CLR_BOLD="\033[1m"
CLR_RED="\033[0;31m"
CLR_GREEN="\033[0;32m"
CLR_YELLOW="\033[0;33m"
CLR_BLUE="\033[0;34m"
CLR_CYAN="\033[0;36m"

# Error trap handler
trap 'error_handler $? $LINENO "$BASH_COMMAND"' ERR

error_handler() {
  local exit_code="$1"
  local line_no="$2"
  local last_cmd="$3"
  echo -e "\n${CLR_RED}✗ Execution failed!${CLR_RESET}"
  echo -e "${CLR_RED}  Error occurred at line ${line_no} (Exit code: ${exit_code})${CLR_RESET}"
  echo -e "${CLR_RED}  Failed command: ${last_cmd}${CLR_RESET}"
  exit "$exit_code"
}

# Pluralization helper
pluralize() {
  local word="$1"
  local lower
  lower=$(echo "$word" | tr '[:upper:]' '[:lower:]')
  if [[ "$lower" =~ (s|x|z|ch|sh)$ ]]; then
    echo "${word}es"
  elif [[ "$lower" =~ [^aeiou]y$ ]]; then
    echo "${word%y}ies"
  else
    echo "${word}s"
  fi
}

# Helper to normalize view choice
parse_view_choice() {
  local input="$1"
  local default_val="$2"
  local val="${input:-$default_val}"
  case "$val" in
    1|[Tt]|[Tt][Aa][Bb][Ll][Ee]|[Ll][Ii][Ss][Tt])
      echo "table"
      ;;
    2|[Cc]|[Cc][Aa][Rr][Dd])
      echo "card"
      ;;
    3|[Bb]|[Bb][Oo][Tt][Hh])
      echo "both"
      ;;
    4|[Nn]|[Nn][Oo][Nn][Ee]|[Hh][Ii][Dd][Dd][Ee][Nn])
      echo "none"
      ;;
    *)
      echo "$default_val"
      ;;
  esac
}

# Helper to read multi-line or single-line DSL / fields input
read_dsl_or_fields() {
  local prompt_label="$1"
  local default_val="$2"
  local lines=()
  local line=""

  echo -n -e "$prompt_label" >&2
  while IFS= read -r line; do
    line="${line%$'\r'}"
    line=$(echo "$line" | sed -r 's/\x1b\[[0-9;]*[a-zA-Z]//g')

    # If first line is empty, use default
    if [[ ${#lines[@]} -eq 0 && -z "$line" ]]; then
      echo "$default_val"
      return
    fi

    # Empty line or 'done' finishes multi-line input
    if [[ -z "$line" || "$line" == "done" || "$line" == "DONE" || "$line" == "EOF" ]]; then
      break
    fi

    lines+=("$line")

    # If traditional single comma list without colons: "name, price, description"
    if [[ ${#lines[@]} -eq 1 && "$line" =~ , && ! "$line" =~ : ]]; then
      break
    fi

    # If closing brace of an entity block
    if [[ "${lines[0]}" =~ entity[[:space:]] && "$line" =~ ^[[:space:]]*\} ]]; then
      break
    fi
  done

  if [ ${#lines[@]} -eq 0 ]; then
    echo "$default_val"
  else
    printf "%s\n" "${lines[@]}"
  fi
}

# Helper to parse DSL or fields input into structured JSON
parse_dsl_to_json() {
  local dsl_text="$1"
  local fallback_name="$2"
  local fallback_col="$3"

  node -e '
  const input = process.argv[1] || "";
  const fallbackName = process.argv[2] || "";
  const fallbackCol = process.argv[3] || "";

  function inferType(name) {
    const lower = name.toLowerCase();
    if (["price", "cost", "amount", "year", "quantity", "age", "rating", "pages", "speed", "range", "weight", "height", "capacity", "progress"].some(k => lower.includes(k))) return "Number";
    if (lower.startsWith("is") || lower.startsWith("has") || lower === "status" || lower === "available" || lower.includes("stock")) return "Boolean";
    if (lower.includes("date") || lower === "dob") return "Date";
    return "String";
  }

  function parse(raw, defName, defCol) {
    let entityName = defName;
    let collection = defCol;
    
    const entityMatch = raw.match(/entity\s+([A-Za-z0-9_$]+)(?:\s+collection=([^\s{]+))?\s*\{([\s\S]*?)\}/i);
    let content = raw;
    if (entityMatch) {
      if (!entityName || entityName === defName) entityName = entityMatch[1].toLowerCase();
      if (!collection || collection === defCol) collection = entityMatch[2] || (entityMatch[1].toLowerCase() + "s");
      content = entityMatch[3];
    }

    let lines = [];
    if (content.includes("\n")) {
      lines = content.split(/\r?\n/).map(l => l.trim()).filter(Boolean);
    } else if (content.includes(";") || content.includes("|")) {
      if (content.includes(",")) lines = content.split(",").map(l => l.trim()).filter(Boolean);
      else lines = [content.trim()];
    } else {
      lines = content.split(",").map(l => l.trim()).filter(Boolean);
    }

    const fields = [];
    const references = [];

    for (const line of lines) {
      if (line.startsWith("//") || line.startsWith("#")) continue;
      const colonIdx = line.indexOf(":");
      if (colonIdx > 0) {
        const fName = line.slice(0, colonIdx).trim().replace(/^[^a-zA-Z0-9_$]+/, "");
        const defStr = line.slice(colonIdx + 1).trim();
        const tokens = defStr.split("|").map(t => t.trim()).filter(Boolean);
        let typeToken = tokens.shift() || "String";
        const optionMap = {};
        const flags = new Set();
        tokens.forEach(tok => {
          const eqIdx = tok.indexOf("=");
          if (eqIdx > 0) optionMap[tok.slice(0, eqIdx).trim()] = tok.slice(eqIdx + 1).trim();
          else flags.add(tok.toLowerCase());
        });

        const isRef = typeToken.toLowerCase() === "objectid" || optionMap.ref || flags.has("ref");
        if (isRef) {
          let target = (optionMap.ref || typeToken).replace(/^ObjectId/i, "").trim() || fName;
          const lowerTarget = target.toLowerCase();
          if (lowerTarget.endsWith("ies")) {
            target = target.slice(0, -3) + "y";
          } else if (lowerTarget.endsWith("es") && (lowerTarget.endsWith("ches") || lowerTarget.endsWith("shes") || lowerTarget.endsWith("xes") || lowerTarget.endsWith("sses"))) {
            target = target.slice(0, -2);
          } else if (lowerTarget.endsWith("s") && !lowerTarget.endsWith("ss")) {
            target = target.slice(0, -1);
          }
          const display = optionMap.display || "name";
          const relType = (flags.has("1:1") || flags.has("onetoone") || flags.has("unique") || optionMap.type === "1:1") ? "1:1" : "N:1";
          references.push({
            targetEntity: target.toLowerCase(),
            targetModel: target.charAt(0).toUpperCase() + target.slice(1),
            fieldName: fName,
            type: relType,
            displayField: display,
            required: flags.has("required") || flags.has("req")
          });
        } else {
          let fType = typeToken;
          if (fType.toLowerCase() === "string") fType = "String";
          else if (fType.toLowerCase() === "number") fType = "Number";
          else if (fType.toLowerCase() === "boolean") fType = "Boolean";
          else if (fType.toLowerCase() === "date") fType = "Date";
          else if (fType.toLowerCase().startsWith("[string]") || fType.toLowerCase() === "array") fType = "[String]";
          
          fields.push({
            name: fName,
            type: fType,
            required: flags.has("required") || flags.has("req"),
            unique: flags.has("unique"),
            trim: flags.has("trim"),
            lowercase: flags.has("lowercase"),
            uppercase: flags.has("uppercase"),
            min: optionMap.min || "",
            max: optionMap.max || "",
            defaultValue: optionMap.default || "",
            ui: optionMap.ui || (fType === "Boolean" ? "switch" : (fType === "Number" ? "number" : (fType === "Date" ? "date" : "text"))),
            label: fName.charAt(0).toUpperCase() + fName.slice(1)
          });
        }
      } else {
        const fName = line.trim();
        if (!fName) continue;
        const inf = inferType(fName);
        fields.push({
          name: fName,
          type: inf,
          required: fields.length === 0,
          unique: false,
          min: "",
          max: "",
          defaultValue: "",
          ui: inf === "Boolean" ? "switch" : (inf === "Number" ? "number" : (inf === "Date" ? "date" : "text")),
          label: fName.charAt(0).toUpperCase() + fName.slice(1)
        });
      }
    }

    return { entityName, collection, fields, references };
  }

  const result = parse(input, fallbackName, fallbackCol);
  process.stdout.write(JSON.stringify(result));
  ' "$dsl_text" "$fallback_name" "$fallback_col"
}

# Helper to print formatted Schema JSON preview
print_schema_preview() {
  local parsed_json="$1"
  node -e '
  const r = JSON.parse(process.argv[1]);
  const schemaObj = {};
  (r.fields || []).forEach(f => {
    const def = { type: f.type };
    if (f.required) def.required = true;
    if (f.unique) def.unique = true;
    if (f.min !== undefined && f.min !== "") def.min = isNaN(f.min) ? f.min : Number(f.min);
    if (f.max !== undefined && f.max !== "") def.max = isNaN(f.max) ? f.max : Number(f.max);
    if (f.defaultValue !== undefined && f.defaultValue !== "") def.default = f.defaultValue;
    if (f.ui && f.ui !== "text") def.ui = f.ui;
    schemaObj[f.name] = def;
  });

  (r.references || []).forEach(ref => {
    schemaObj[ref.fieldName] = {
      type: "ObjectId",
      ref: ref.targetModel,
      relationship: ref.type === "1:1" ? "One-to-One (1:1)" : "Many-to-One (N:1)",
      displayField: ref.displayField || "name",
      required: !!ref.required
    };
  });

  const preview = {
    entity: r.entityName,
    collection: r.collection,
    schema: schemaObj
  };

  const rawJson = JSON.stringify(preview, null, 2);
  const indented = rawJson.split("\n").map(l => "    " + l).join("\n");
  console.log("\x1b[36m" + indented + "\x1b[0m\n");
  ' "$parsed_json"
}



echo -e "${CLR_CYAN}${CLR_BOLD}========================================${CLR_RESET}"
echo -e "${CLR_CYAN}${CLR_BOLD}        SDN302 PROJECT GENERATOR        ${CLR_RESET}"
echo -e "${CLR_CYAN}${CLR_BOLD}========================================${CLR_RESET}"

# ------------------------------------------------------------------------------
# 1. PREREQUISITE CHECKS
# ------------------------------------------------------------------------------
for tool in node npm npx; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo -e "${CLR_RED}✗ Required prerequisite tool '$tool' is not installed or not in PATH.${CLR_RESET}"
    exit 1
  fi
done

# ------------------------------------------------------------------------------
# 2. INTERACTIVE USER INPUTS
# ------------------------------------------------------------------------------

# Project Name
while true; do
  read -r -e -p "Project name [sdn302-pe]: " input_proj || true
  PROJECT_NAME=$(echo "${input_proj:-sdn302-pe}" | tr -cd '[:alnum:]_-')
  PROJECT_NAME="${PROJECT_NAME:-sdn302-pe}"
  if [ -d "$PROJECT_NAME" ]; then
    echo -e "${CLR_YELLOW}Directory '$PROJECT_NAME' already exists. Choose another name to avoid overwriting.${CLR_RESET}"
  else
    break
  fi
done

# MongoDB Database Name
while true; do
  read -r -e -p "MongoDB database name [Lab1]: " input_db || true
  DB_NAME=$(echo "${input_db:-Lab1}" | tr -cd '[:alnum:]_-')
  DB_NAME="${DB_NAME:-Lab1}"
  if [[ -n "$DB_NAME" ]]; then
    break
  fi
  echo -e "${CLR_YELLOW}Invalid database name. Use alphanumeric characters, hyphens, and underscores only.${CLR_RESET}"
done

# ------------------------------------------------------------------------------
# [1] MANAGER / AUTH ENTITY
# ------------------------------------------------------------------------------
echo ""
echo -e "${CLR_BOLD}[1] MANAGER / AUTH ENTITY${CLR_RESET}"
while true; do
  read -r -e -p "Entity name (singular) [member]: " input_mgr || true
  MGR_NAME=$(echo "${input_mgr:-member}" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]_')
  MGR_NAME="${MGR_NAME:-member}"
  if [[ -n "$MGR_NAME" ]]; then
    break
  fi
  echo -e "${CLR_YELLOW}Invalid entity name. Use letters, numbers, and underscores only.${CLR_RESET}"
done

sug_mgr_col=$(pluralize "$MGR_NAME")
read -r -e -p "Collection name [$sug_mgr_col]: " input_mgr_col || true
MGR_COL=$(echo "${input_mgr_col:-$sug_mgr_col}" | tr -cd '[:alnum:]_')
MGR_COL="${MGR_COL:-$sug_mgr_col}"

read -r -e -p "Username field name [username]: " input_mgr_user || true
MGR_USER_FIELD=$(echo "${input_mgr_user:-username}" | tr -cd '[:alnum:]_')
MGR_USER_FIELD="${MGR_USER_FIELD:-username}"

read -r -e -p "Password field name [password]: " input_mgr_pass || true
MGR_PASS_FIELD=$(echo "${input_mgr_pass:-password}" | tr -cd '[:alnum:]_')
MGR_PASS_FIELD="${MGR_PASS_FIELD:-password}"

read -r -e -p "Additional fields for $MGR_NAME (DSL, e.g. fullName:String, avatar:Image) [n]: " input_mgr_fields || true
MGR_FIELDS_RAW=$(echo "${input_mgr_fields}" | tr -d '\r' | xargs)
MGR_FIELDS_LOWER=$(echo "$MGR_FIELDS_RAW" | tr '[:upper:]' '[:lower:]')
if [[ -z "$MGR_FIELDS_RAW" || "$MGR_FIELDS_LOWER" == "none" || "$MGR_FIELDS_LOWER" == "n" || "$MGR_FIELDS_LOWER" == "no" || "$MGR_FIELDS_LOWER" == "0" ]]; then
  MGR_FIELDS="none"
else
  MGR_FIELDS="$MGR_FIELDS_RAW"
fi

read -r -e -p "View layout: [1] Table list, [2] Card list, [3] Both, [4] None (Hidden/No UI) [1]: " input_mgr_view || true
MGR_VIEW=$(parse_view_choice "$input_mgr_view" "table")

# ------------------------------------------------------------------------------
# [2] INDEPENDENT ENTITIES (Lookup / Master data, no foreign keys)
# E.g.: Category, Brand, Supplier, Department
# ------------------------------------------------------------------------------
echo ""
echo -e "${CLR_BOLD}[2] INDEPENDENT ENTITIES (No foreign keys: Category, Brand...)${CLR_RESET}"
INDEP_NAMES=()
INDEP_COLS=()
INDEP_FIELDS_LIST=()
INDEP_FIELDS_JSON=()
INDEP_VIEWS=()

first_indep=true
while true; do
  def_name="category"
  if [ "$first_indep" = false ]; then
    def_name="brand"
  fi

  while true; do
    read -r -e -p "Entity name (singular) [$def_name]: " input_indep || true
    indep_name=$(echo "${input_indep:-$def_name}" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]_')
    indep_name="${indep_name:-$def_name}"
    if [[ "$indep_name" == "$MGR_NAME" ]]; then
      echo -e "${CLR_YELLOW}Entity name cannot be identical to manager. Try again.${CLR_RESET}"
      continue
    fi
    dup=false
    for existing in "${INDEP_NAMES[@]:-}"; do
      if [[ "$existing" == "$indep_name" ]]; then
        dup=true; break
      fi
    done
    if [ "$dup" = true ]; then
      echo -e "${CLR_YELLOW}Entity '$indep_name' already added. Choose another name.${CLR_RESET}"
      continue
    fi
    break
  done

  sug_indep_col=$(pluralize "$indep_name")
  read -r -e -p "Collection name [$sug_indep_col]: " input_indep_col || true
  indep_col=$(echo "${input_indep_col:-$sug_indep_col}" | tr -cd '[:alnum:]_')
  indep_col="${indep_col:-$sug_indep_col}"

  while true; do
    echo -e "  Fields / DSL [name, description]:"
    echo -e "  ${CLR_YELLOW}(Tip: Paste DSL lines below. When done, press Enter on an empty line or type 'done')${CLR_RESET}"
    input_indep_dsl=$(read_dsl_or_fields "  > " "name, description")

    parsed_indep_json=$(parse_dsl_to_json "$input_indep_dsl" "$indep_name" "$indep_col")
    extracted_name=$(node -e "const r = JSON.parse(process.argv[1]); console.log(r.entityName || '');" "$parsed_indep_json")
    extracted_col=$(node -e "const r = JSON.parse(process.argv[1]); console.log(r.collection || '');" "$parsed_indep_json")
    if [[ -n "$extracted_name" && "$extracted_name" != "$indep_name" && "$input_indep_dsl" =~ entity[[:space:]] ]]; then
      indep_name="$extracted_name"
      indep_col="${extracted_col:-$(pluralize "$indep_name")}"
    fi
    indep_fields_json=$(node -e "const r = JSON.parse(process.argv[1]); console.log(JSON.stringify(r.fields || []));" "$parsed_indep_json")

    echo -e "\n  ${CLR_GREEN}${CLR_BOLD}✓ Parsed Schema JSON:${CLR_RESET}"
    print_schema_preview "$parsed_indep_json"

    read -r -e -p "  Confirm this schema? (y/n) [y]: " confirm_schema || true
    confirm_schema="${confirm_schema:-y}"
    if [[ "$confirm_schema" =~ ^[Yy]$ ]]; then
      break
    fi
    echo -e "  ${CLR_YELLOW}Re-entering fields for '${indep_name}':${CLR_RESET}"
  done

  read -r -e -p "View layout: [1] Table list, [2] Card list, [3] Both, [4] None (Hidden/No UI) [1]: " input_indep_view || true
  indep_view=$(parse_view_choice "$input_indep_view" "table")

  INDEP_NAMES+=("$indep_name")
  INDEP_COLS+=("$indep_col")
  INDEP_FIELDS_JSON+=("$indep_fields_json")
  INDEP_FIELDS_LIST+=("$input_indep_dsl")
  INDEP_VIEWS+=("$indep_view")

  first_indep=false

  read -r -e -p "Add another independent entity? (y/n) [n]: " add_more_indep || true
  add_more_indep="${add_more_indep:-n}"
  if [[ ! "$add_more_indep" =~ ^[Yy]$ ]]; then
    break
  fi
done

# ------------------------------------------------------------------------------
# [3] DEPENDENT ENTITIES (Entities with foreign keys / references)
# E.g.: Product, Book, Order, Car - can reference 1 or more entities (1-1 or N-1)
# ------------------------------------------------------------------------------
echo ""
echo -e "${CLR_BOLD}[3] DEPENDENT ENTITIES (Referencing independent entities)${CLR_RESET}"
DEP_NAMES=()
DEP_COLS=()
DEP_FIELDS_LIST=()
DEP_FIELDS_JSON=()
DEP_VIEWS=()
DEP_REFS_JSON=()

first_dep=true
while true; do
  if [ "$first_dep" = true ]; then
    def_dep_name="product"
  else
    read -r -e -p "Add another dependent entity? (y/n) [n]: " add_dep || true
    add_dep="${add_dep:-n}"
    if [[ ! "$add_dep" =~ ^[Yy]$ ]]; then
      break
    fi
    def_dep_name="item"
  fi

  while true; do
    read -r -e -p "Entity name (singular) [$def_dep_name]: " input_dep || true
    dep_name=$(echo "${input_dep:-$def_dep_name}" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]_')
    dep_name="${dep_name:-$def_dep_name}"
    if [[ "$dep_name" == "$MGR_NAME" ]]; then
      echo -e "${CLR_YELLOW}Entity name cannot be identical to manager. Try again.${CLR_RESET}"
      continue
    fi
    dup=false
    for existing in "${INDEP_NAMES[@]:-}" "${DEP_NAMES[@]:-}"; do
      if [[ "$existing" == "$dep_name" ]]; then
        dup=true; break
      fi
    done
    if [ "$dup" = true ]; then
      echo -e "${CLR_YELLOW}Entity '$dep_name' already exists. Choose another name.${CLR_RESET}"
      continue
    fi
    break
  done

  sug_dep_col=$(pluralize "$dep_name")
  read -r -e -p "Collection name [$sug_dep_col]: " input_dep_col || true
  dep_col=$(echo "${input_dep_col:-$sug_dep_col}" | tr -cd '[:alnum:]_')
  dep_col="${dep_col:-$sug_dep_col}"

  while true; do
    echo -e "  Fields / DSL [name, price, description]:"
    echo -e "  ${CLR_YELLOW}(Tip: Paste DSL lines below. When done, press Enter on an empty line or type 'done')${CLR_RESET}"
    input_dep_dsl=$(read_dsl_or_fields "  > " "name, price, description")

    parsed_dep_json=$(parse_dsl_to_json "$input_dep_dsl" "$dep_name" "$dep_col")
    extracted_name=$(node -e "const r = JSON.parse(process.argv[1]); console.log(r.entityName || '');" "$parsed_dep_json")
    extracted_col=$(node -e "const r = JSON.parse(process.argv[1]); console.log(r.collection || '');" "$parsed_dep_json")
    if [[ -n "$extracted_name" && "$extracted_name" != "$dep_name" && "$input_dep_dsl" =~ entity[[:space:]] ]]; then
      dep_name="$extracted_name"
      dep_col="${extracted_col:-$(pluralize "$dep_name")}"
    fi
    dep_fields_json=$(node -e "const r = JSON.parse(process.argv[1]); console.log(JSON.stringify(r.fields || []));" "$parsed_dep_json")

    echo -e "\n  ${CLR_GREEN}${CLR_BOLD}✓ Parsed Schema JSON:${CLR_RESET}"
    print_schema_preview "$parsed_dep_json"

    # Foreign Keys / References configuration (Auto-detected from DSL or manual fallback)
    dsl_refs_count=$(node -e "const r = JSON.parse(process.argv[1]); console.log((r.references || []).length);" "$parsed_dep_json")
    current_refs_json="[]"

    if [ "$dsl_refs_count" -gt 0 ]; then
      current_refs_json=$(node -e "const r = JSON.parse(process.argv[1]); console.log(JSON.stringify(r.references || []));" "$parsed_dep_json")
      echo -e "  ${CLR_CYAN}⚡ Auto-detected ${dsl_refs_count} reference(s) from DSL (No manual reference input needed)${CLR_RESET}"
    else
      # Fallback to manual prompt only if no references were defined in DSL
      candidates=()
      for cand in "${INDEP_NAMES[@]:-}"; do
        if [[ -n "$cand" ]]; then candidates+=("$cand"); fi
      done
      for cand in "${DEP_NAMES[@]:-}"; do
        if [[ -n "$cand" ]]; then candidates+=("$cand"); fi
      done

      if [ ${#candidates[@]} -gt 0 ]; then
        cand_str=$(IFS=', '; echo "${candidates[*]}")
        default_ref="${candidates[0]}"
        echo -e "  Available entities to reference: ${CLR_CYAN}[${cand_str}]${CLR_RESET}"
        read -r -e -p "  Referenced entities (comma-separated, or 'none') [$default_ref]: " input_refs || true
        raw_refs=$(echo "${input_refs:-$default_ref}" | tr -d ' ' | tr -d '\\"'\''')
        
        if [[ "$raw_refs" != "none" && -n "$raw_refs" ]]; then
          IFS=',' read -ra SELECTED_REFS <<< "$raw_refs"
          refs_arr=()
          for r_target in "${SELECTED_REFS[@]}"; do
            r_target_clean=$(echo "$r_target" | tr -cd '[:alnum:]_')
            if [[ -z "$r_target_clean" ]]; then continue; fi

            read -r -e -p "  - Reference field name for '${r_target_clean}' [${r_target_clean}]: " input_rf || true
            r_field=$(echo "${input_rf:-$r_target_clean}" | tr -cd '[:alnum:]_')
            r_field="${r_field:-$r_target_clean}"

            read -r -e -p "  - Relationship type for '${r_field}' ([1] Many-to-One N:1, [2] One-to-One 1:1) [1]: " input_rtype || true
            r_type="N:1"
            if [[ "$input_rtype" == "2" || "$input_rtype" == "1:1" ]]; then
              r_type="1:1"
            fi

            refs_arr+=("{\"targetEntity\":\"$r_target_clean\",\"fieldName\":\"$r_field\",\"type\":\"$r_type\"}")
          done
          if [ ${#refs_arr[@]} -gt 0 ]; then
            current_refs_json="["$(IFS=','; echo "${refs_arr[*]}")"]"
          fi
        fi
      fi
    fi

    read -r -e -p "  Confirm this schema? (y/n) [y]: " confirm_schema || true
    confirm_schema="${confirm_schema:-y}"
    if [[ "$confirm_schema" =~ ^[Yy]$ ]]; then
      break
    fi
    echo -e "  ${CLR_YELLOW}Re-entering fields for '${dep_name}':${CLR_RESET}"
  done

  read -r -e -p "View layout: [1] Table list, [2] Card list, [3] Both, [4] None (Hidden/No UI) [3]: " input_dep_view || true
  dep_view=$(parse_view_choice "$input_dep_view" "both")

  DEP_NAMES+=("$dep_name")
  DEP_COLS+=("$dep_col")
  DEP_FIELDS_JSON+=("$dep_fields_json")
  DEP_FIELDS_LIST+=("$input_dep_dsl")
  DEP_VIEWS+=("$dep_view")
  DEP_REFS_JSON+=("$current_refs_json")

  first_dep=false
done

# Summary Display
echo ""
echo -e "${CLR_CYAN}${CLR_BOLD}Summary Configuration:${CLR_RESET}"
echo "  Project:      $PROJECT_NAME"
echo "  Database:     $DB_NAME"
echo "  Manager:      $MGR_NAME (col: $MGR_COL, view: $MGR_VIEW)"
for i in "${!INDEP_NAMES[@]}"; do
  echo "  Independent:  ${INDEP_NAMES[$i]} (col: ${INDEP_COLS[$i]}, view: ${INDEP_VIEWS[$i]})"
done
for i in "${!DEP_NAMES[@]}"; do
  echo "  Dependent:    ${DEP_NAMES[$i]} (col: ${DEP_COLS[$i]}, view: ${DEP_VIEWS[$i]}, refs: ${DEP_REFS_JSON[$i]})"
done
echo ""

# ------------------------------------------------------------------------------
# STEP [01/12] VALIDATING INPUT
# ------------------------------------------------------------------------------
echo -e "${CLR_BLUE}[01/12] Validating input...${CLR_RESET}"
all_cols=("$MGR_COL")
for c in "${INDEP_COLS[@]:-}"; do all_cols+=("$c"); done
for c in "${DEP_COLS[@]:-}"; do all_cols+=("$c"); done

unique_cols=($(printf "%s\n" "${all_cols[@]}" | sort -u))
if [ "${#all_cols[@]}" -ne "${#unique_cols[@]}" ]; then
  echo -e "${CLR_RED}✗ Duplicate collection names detected: ${all_cols[*]}${CLR_RESET}"
  exit 1
fi

echo -e "        ${CLR_GREEN}✓ Project: $PROJECT_NAME${CLR_RESET}"
echo -e "        ${CLR_GREEN}✓ Database: $DB_NAME${CLR_RESET}"
echo -e "        ${CLR_GREEN}✓ Entities: ${all_cols[*]}${CLR_RESET}"

# ------------------------------------------------------------------------------
# STEP [02/12] CREATING EXPRESS HBS PROJECT
# ------------------------------------------------------------------------------
echo -e "${CLR_BLUE}[02/12] Creating Express HBS project...${CLR_RESET}"
npx --yes express-generator --view=hbs "$PROJECT_NAME" >/dev/null 2>&1
echo -e "        ${CLR_GREEN}✓ Express Generator completed${CLR_RESET}"

# Switch into generated project folder
cd "$PROJECT_NAME"

# ------------------------------------------------------------------------------
# STEP [03/12] INSTALLING DEPENDENCIES (Clean CDN Bootstrap, NO npm bootstrap)
# ------------------------------------------------------------------------------
npm install dotenv mongoose jsonwebtoken bcryptjs express-session cookie-parser hbs >/dev/null 2>&1
npm install -D nodemon >/dev/null 2>&1
npm pkg set 'scripts.dev=nodemon ./bin/www' >/dev/null 2>&1
echo -e "        ${CLR_GREEN}✓ npm install completed (Dependencies verified)${CLR_RESET}"

# ------------------------------------------------------------------------------
# STEP [04/12] WRITING .env (STRICTLY 3 LINES)
# ------------------------------------------------------------------------------
echo -e "${CLR_BLUE}[04/12] Writing .env...${CLR_RESET}"
printf "PORT=5000\nMONGODB_URI=mongodb://127.0.0.1:27017/%s\nJWT_SECRET=SE190703\n" "$DB_NAME" > .env

line_count=$(wc -l < .env | tr -d ' ')
if [ "$line_count" -ne 3 ]; then
  echo -e "${CLR_RED}✗ .env file must have exactly 3 lines, found ${line_count}.${CLR_RESET}"
  exit 1
fi
echo -e "        ${CLR_GREEN}✓ Database: ${DB_NAME}${CLR_RESET}"
echo -e "        ${CLR_GREEN}✓ mongodb://127.0.0.1:27017/${DB_NAME}${CLR_RESET}"

# ------------------------------------------------------------------------------
# PREPARE GENERATOR CONFIGURATION JSON
# ------------------------------------------------------------------------------
INDEP_JSON_ITEMS=()
for i in "${!INDEP_NAMES[@]}"; do
  INDEP_JSON_ITEMS+=("{\"name\":\"${INDEP_NAMES[$i]}\",\"col\":\"${INDEP_COLS[$i]}\",\"fields\":${INDEP_FIELDS_JSON[$i]},\"viewType\":\"${INDEP_VIEWS[$i]}\",\"apiPath\":\"/v1/${INDEP_COLS[$i]}\",\"pagePath\":\"/admin/${INDEP_COLS[$i]}\",\"apiEnabled\":true,\"uiEnabled\":true}")
done
INDEP_JSON="["$(IFS=','; echo "${INDEP_JSON_ITEMS[*]}")"]"

DEP_JSON_ITEMS=()
for i in "${!DEP_NAMES[@]}"; do
  DEP_JSON_ITEMS+=("{\"name\":\"${DEP_NAMES[$i]}\",\"col\":\"${DEP_COLS[$i]}\",\"fields\":${DEP_FIELDS_JSON[$i]},\"references\":${DEP_REFS_JSON[$i]},\"viewType\":\"${DEP_VIEWS[$i]}\",\"apiPath\":\"/v1/${DEP_COLS[$i]}\",\"pagePath\":\"/admin/${DEP_COLS[$i]}\",\"apiEnabled\":true,\"uiEnabled\":true}")
done
DEP_JSON="["$(IFS=','; echo "${DEP_JSON_ITEMS[*]}")"]"

cat << EOF > .generator_config.json
{
  "projectName": "$PROJECT_NAME",
  "dbName": "$DB_NAME",
  "manager": {
    "name": "$MGR_NAME",
    "col": "$MGR_COL",
    "userField": "$MGR_USER_FIELD",
    "passField": "$MGR_PASS_FIELD",
    "fields": "$MGR_FIELDS",
    "viewType": "$MGR_VIEW",
    "apiPath": "/v1/$MGR_COL",
    "pagePath": "/admin/$MGR_COL",
    "apiEnabled": true,
    "uiEnabled": true
  },
  "independentEntities": $INDEP_JSON,
  "dependentEntities": $DEP_JSON
}
EOF

# ------------------------------------------------------------------------------
# NODE GENERATOR HELPER SCRIPT
# ------------------------------------------------------------------------------
cat << 'EOF_NODE_GEN' > .build_project.js
const fs = require('fs');
const path = require('path');

const config = JSON.parse(fs.readFileSync('.generator_config.json', 'utf8'));

function capitalize(s) {
  if (!s) return '';
  return s.charAt(0).toUpperCase() + s.slice(1);
}

function singularizeJs(word) {
  if (!word) return '';
  const lower = word.toLowerCase();
  if (lower.endsWith('ies')) return word.slice(0, -3) + 'y';
  if (lower.endsWith('es') && (lower.endsWith('ches') || lower.endsWith('shes') || lower.endsWith('xes') || lower.endsWith('sses'))) {
    return word.slice(0, -2);
  }
  if (lower.endsWith('s') && !lower.endsWith('ss')) {
    return word.slice(0, -1);
  }
  return word;
}

function pluralizeJs(word) {
  if (!word) return '';
  const lower = word.toLowerCase();
  // Already plural forms:
  if (lower.endsWith('ies') || (lower.endsWith('es') && (lower.endsWith('ches') || lower.endsWith('shes') || lower.endsWith('xes') || lower.endsWith('sses')))) {
    return word;
  }
  if (lower.endsWith('s') && !lower.endsWith('ss')) {
    return word;
  }
  if (/[^aeiou]y$/.test(lower)) {
    return word.slice(0, -1) + 'ies';
  }
  if (lower.endsWith('x') || lower.endsWith('z') || lower.endsWith('ch') || lower.endsWith('sh')) {
    return word + 'es';
  }
  return word + 's';
}

function inferType(name) {
  const lower = name.toLowerCase();
  if (['price', 'cost', 'amount', 'year', 'quantity', 'age', 'rating', 'pages', 'speed', 'range', 'weight', 'height', 'capacity', 'progress'].some(k => lower.includes(k))) {
    return 'Number';
  }
  if (lower.startsWith('is') || lower.startsWith('has') || lower === 'status' || lower === 'available' || lower.includes('stock')) {
    return 'Boolean';
  }
  if (lower.includes('date') || lower === 'dob') {
    return 'Date';
  }
  return 'String';
}

function parseFields(fieldInput) {
  if (!fieldInput) return [];
  if (Array.isArray(fieldInput)) {
    return fieldInput.map(f => {
      let rawType = f.type || inferType(f.name);
      let isImg = f.ui === 'image';
      if (/^image$/i.test(rawType)) {
        rawType = 'String';
        isImg = true;
      } else if (/^\[image\]$/i.test(rawType)) {
        rawType = '[String]';
        isImg = true;
      }
      return {
        name: f.name,
        type: rawType,
        required: !!f.required,
        unique: !!f.unique,
        min: f.min !== undefined && f.min !== '' ? f.min : '',
        max: f.max !== undefined && f.max !== '' ? f.max : '',
        defaultValue: f.defaultValue !== undefined ? f.defaultValue : '',
        ui: isImg ? 'image' : (f.ui || (rawType === 'Boolean' ? 'switch' : (rawType === 'Number' ? 'number' : (rawType === 'Date' ? 'date' : (rawType === '[String]' ? 'comma-list' : 'text'))))),
        displayField: f.displayField || '',
        label: f.label || capitalize(f.name)
      };
    });
  }
  if (typeof fieldInput === 'string' && fieldInput.trim().startsWith('[')) {
    try {
      const arr = JSON.parse(fieldInput);
      if (Array.isArray(arr)) return parseFields(arr);
    } catch (e) {}
  }
  const parts = String(fieldInput).split(',').map(p => p.trim()).filter(Boolean);
  return parts.map((part, index) => {
    const tokens = part.split(':').map(t => t.trim());
    const name = tokens[0];
    let rawType = tokens[1] || inferType(name);
    let isImg = false;

    if (/^image$/i.test(rawType)) {
      rawType = 'String';
      isImg = true;
    } else if (/^\[image\]$/i.test(rawType)) {
      rawType = '[String]';
      isImg = true;
    }

    const flags = tokens.slice(2).map(t => t.toLowerCase());
    if (flags.includes('image') || flags.includes('img') || flags.some(t => t.startsWith('ui=image'))) {
      isImg = true;
    }

    const type = rawType.startsWith('[') ? rawType : (rawType.charAt(0).toUpperCase() + rawType.slice(1));
    const isReq = flags.includes('req') || flags.includes('required') || (index === 0);
    const isUnique = flags.includes('unique');

    return {
      name,
      type,
      required: isReq,
      unique: isUnique,
      min: '',
      max: '',
      defaultValue: '',
      ui: isImg ? 'image' : (type === 'Boolean' ? 'switch' : (type === 'Number' ? 'number' : (type === 'Date' ? 'date' : (type === '[String]' ? 'comma-list' : 'text')))),
      label: capitalize(name)
    };
  });
}

// Ensure required directories
[
  'bin',
  'models',
  'repositories',
  'services',
  'controllers',
  'routes',
  'middlewares',
  'utils/constants',
  'views/partials',
  'views/auth',
  'public/javascripts',
  'public/stylesheets'
].forEach(dir => {
  fs.mkdirSync(dir, { recursive: true });
});

// Parse Manager additional fields from DSL
let extraMgrFields = [];
const mgrFieldsInput = (config.manager.fields || '').trim();
const isNone = !mgrFieldsInput || /^(none|no|n|0|null)$/i.test(mgrFieldsInput);

if (!isNone) {
  const rawMgrFields = parseFields(mgrFieldsInput);
  extraMgrFields = rawMgrFields.filter(f => f.name !== config.manager.userField && f.name !== config.manager.passField);
}
config.manager.fields = extraMgrFields;

// All entities list
const allEntities = [
  {
    ...config.manager,
    isManager: true,
    fields: extraMgrFields,
    references: [],
    apiPath: config.manager.apiPath || `/v1/${config.manager.col}`,
    pagePath: config.manager.pagePath || `/admin/${config.manager.col}`,
    apiEnabled: config.manager.apiEnabled !== false,
    uiEnabled: config.manager.uiEnabled !== false
  },
  ...config.independentEntities.map(e => ({
    ...e,
    isManager: false,
    references: [],
    apiPath: e.apiPath || `/v1/${e.col}`,
    pagePath: e.pagePath || `/admin/${e.col}`,
    apiEnabled: e.apiEnabled !== false,
    uiEnabled: e.uiEnabled !== false
  })),
  ...config.dependentEntities.map(e => ({
    ...e,
    isManager: false,
    apiPath: e.apiPath || `/v1/${e.col}`,
    pagePath: e.pagePath || `/admin/${e.col}`,
    apiEnabled: e.apiEnabled !== false,
    uiEnabled: e.uiEnabled !== false
  }))
];

// Normalize all references so targetEntity ALWAYS maps to the canonical singular entity name (e.g. categories -> category)
function findCanonicalEntity(targetName) {
  if (!targetName) return null;
  const tn = String(targetName).toLowerCase().trim();
  const sing = singularizeJs(tn);
  return allEntities.find(e => 
    e.name.toLowerCase() === tn || 
    e.name.toLowerCase() === sing ||
    e.col.toLowerCase() === tn || 
    e.col.toLowerCase() === sing ||
    pluralizeJs(e.name).toLowerCase() === tn ||
    (e.name + 's').toLowerCase() === tn ||
    (e.name.endsWith('y') && (e.name.slice(0, -1) + 'ies').toLowerCase() === tn)
  );
}

function resolveReference(r) {
  const matched = findCanonicalEntity(r.targetEntity);
  const canonicalName = matched ? matched.name : singularizeJs(r.targetEntity || '').toLowerCase();
  const canonicalModel = capitalize(canonicalName);

  let disp = r.displayField;
  if (!disp || disp === 'name') {
    if (matched && matched.fields) {
      const parsed = parseFields(matched.fields);
      const aliasOrTitle = parsed.find(f => f.type === 'String' && /alias|title|name|user/i.test(f.name));
      const firstString = parsed.find(f => f.type === 'String');
      if (aliasOrTitle) disp = aliasOrTitle.name;
      else if (firstString) disp = firstString.name;
    }
  }

  return {
    ...r,
    targetEntity: canonicalName,
    targetModel: canonicalModel,
    displayField: disp || 'name'
  };
}

allEntities.forEach(ent => {
  if (ent.references && Array.isArray(ent.references)) {
    ent.references = ent.references.map(resolveReference);
  }
});
config.dependentEntities.forEach(ent => {
  if (ent.references && Array.isArray(ent.references)) {
    ent.references = ent.references.map(resolveReference);
  }
});

const visibleEntities = allEntities.filter(e => e.viewType !== 'none');
const defaultEntity = visibleEntities.length > 0
  ? (visibleEntities.find(e => !e.isManager) || visibleEntities[0])
  : (config.dependentEntities[0] || config.independentEntities[0] || config.manager);
const defaultPagePath = defaultEntity ? `/admin/${defaultEntity.col}` : '/';

// -----------------------------------------------------------------------------
// 1. MODELS (Mongoose Schemas & models/index.js)
// -----------------------------------------------------------------------------

// Manager Model with dynamic DSL fields
let mgrExtraCode = extraMgrFields.map(f => {
  let typeStr = f.type === 'Number' ? 'Number' : f.type === 'Boolean' ? 'Boolean' : f.type === 'Date' ? 'Date' : (f.type === '[String]' || f.type === '[Image]') ? '[String]' : 'String';
  let lines = [`    type: ${typeStr}`, `    required: ${f.required ? 'true' : 'false'}`];
  if (typeStr === 'String') lines.push('    trim: true');
  if (f.lowercase) lines.push('    lowercase: true');
  if (f.uppercase) lines.push('    uppercase: true');
  if (f.unique) lines.push('    unique: true');
  if (f.min !== undefined && f.min !== '') lines.push(`    min: ${f.min}`);
  if (f.max !== undefined && f.max !== '') lines.push(`    max: ${f.max}`);
  if (f.defaultValue !== undefined && f.defaultValue !== '') {
    lines.push(`    default: ${typeStr === 'String' ? `'${f.defaultValue}'` : f.defaultValue}`);
  }
  return `  ${f.name}: {\n${lines.join(',\n')}\n  }`;
}).join(',\n');

const mgrSchemaFields = `
  ${config.manager.userField}: {
    type: String,
    required: true,
    unique: true,
    trim: true
  },
  ${config.manager.passField}: {
    type: String,
    required: true
  }${mgrExtraCode ? ',\n' + mgrExtraCode : ''}
`;

fs.writeFileSync(`models/${config.manager.name}.js`, `const mongoose = require('mongoose');

const schema = new mongoose.Schema({${mgrSchemaFields}}, {
  timestamps: true,
  collection: '${config.manager.col}'
});

module.exports = mongoose.model('${capitalize(config.manager.name)}', schema);
`);

// Independent Models
config.independentEntities.forEach(ent => {
  const fields = parseFields(ent.fields);
  let fieldsCode = fields.map(f => {
    let typeStr = f.type === 'Number' ? 'Number' : f.type === 'Boolean' ? 'Boolean' : f.type === 'Date' ? 'Date' : f.type === '[String]' ? '[String]' : 'String';
    let lines = [`    type: ${typeStr}`, `    required: ${f.required ? 'true' : 'false'}`];
    if (typeStr === 'String') lines.push('    trim: true');
    if (f.lowercase) lines.push('    lowercase: true');
    if (f.uppercase) lines.push('    uppercase: true');
    if (f.unique) lines.push('    unique: true');
    if (f.min !== undefined && f.min !== '') lines.push(`    min: ${f.min}`);
    if (f.max !== undefined && f.max !== '') lines.push(`    max: ${f.max}`);
    if (f.defaultValue !== undefined && f.defaultValue !== '') {
      lines.push(`    default: ${f.type === 'String' ? `'${f.defaultValue}'` : f.defaultValue}`);
    }
    return `  ${f.name}: {\n${lines.join(',\n')}\n  }`;
  }).join(',\n');

  fs.writeFileSync(`models/${ent.name}.js`, `const mongoose = require('mongoose');

const schema = new mongoose.Schema({
${fieldsCode}
}, {
  timestamps: true,
  collection: '${ent.col}'
});

module.exports = mongoose.model('${capitalize(ent.name)}', schema);
`);
});

// Dependent Models
config.dependentEntities.forEach(ent => {
  const fields = parseFields(ent.fields);
  let fieldsCode = fields.map(f => {
    let typeStr = f.type === 'Number' ? 'Number' : f.type === 'Boolean' ? 'Boolean' : f.type === 'Date' ? 'Date' : f.type === '[String]' ? '[String]' : 'String';
    let lines = [`    type: ${typeStr}`, `    required: ${f.required ? 'true' : 'false'}`];
    if (typeStr === 'String') lines.push('    trim: true');
    if (f.lowercase) lines.push('    lowercase: true');
    if (f.uppercase) lines.push('    uppercase: true');
    if (f.unique) lines.push('    unique: true');
    if (f.min !== undefined && f.min !== '') lines.push(`    min: ${f.min}`);
    if (f.max !== undefined && f.max !== '') lines.push(`    max: ${f.max}`);
    if (f.defaultValue !== undefined && f.defaultValue !== '') {
      lines.push(`    default: ${f.type === 'String' ? `'${f.defaultValue}'` : f.defaultValue}`);
    }
    return `  ${f.name}: {\n${lines.join(',\n')}\n  }`;
  }).join(',\n');

  if (ent.references && ent.references.length > 0) {
    const refCodes = ent.references.map(r => `  ${r.fieldName}: {
    type: mongoose.Schema.Types.ObjectId,
    ref: '${capitalize(r.targetEntity)}',
    required: true${r.type === '1:1' ? ',\n    unique: true' : ''}
  }`).join(',\n');
    fieldsCode += (fieldsCode ? ',\n' : '') + refCodes;
  }

  fs.writeFileSync(`models/${ent.name}.js`, `const mongoose = require('mongoose');

const schema = new mongoose.Schema({
${fieldsCode}
}, {
  timestamps: true,
  collection: '${ent.col}'
});

module.exports = mongoose.model('${capitalize(ent.name)}', schema);
`);
});

// models/index.js (Central Model Registration)
const modelRequires = allEntities.map(e => `const ${capitalize(e.name)} = require('./${e.name}');`).join('\n');
const modelExports = allEntities.map(e => `  ${capitalize(e.name)}`).join(',\n');

fs.writeFileSync('models/index.js', `${modelRequires}

module.exports = {
${modelExports}
};
`);

// -----------------------------------------------------------------------------
// 2. REPOSITORIES (PRESERVED 100% UNCHANGED BaseRepository)
// -----------------------------------------------------------------------------

fs.writeFileSync('repositories/baseRepository.js', `class BaseRepository {
  constructor(model) {
    this.model = model;
  }

  async findAll(filter = {}, populateOptions = null) {
    let query = this.model.find(filter);
    if (populateOptions) {
      if (Array.isArray(populateOptions)) {
        populateOptions.forEach(opt => { query = query.populate(opt); });
      } else {
        query = query.populate(populateOptions);
      }
    }
    return await query.lean().exec();
  }

  async findById(id, populateOptions = null) {
    let query = this.model.findById(id);
    if (populateOptions) {
      if (Array.isArray(populateOptions)) {
        populateOptions.forEach(opt => { query = query.populate(opt); });
      } else {
        query = query.populate(populateOptions);
      }
    }
    return await query.lean().exec();
  }

  async findOne(filter = {}, populateOptions = null) {
    let query = this.model.findOne(filter);
    if (populateOptions) {
      if (Array.isArray(populateOptions)) {
        populateOptions.forEach(opt => { query = query.populate(opt); });
      } else {
        query = query.populate(populateOptions);
      }
    }
    return await query.exec();
  }

  async create(data) {
    return await this.model.create(data);
  }

  async updateById(id, data) {
    return await this.model.findByIdAndUpdate(id, data, { new: true, runValidators: true }).lean().exec();
  }

  async deleteById(id) {
    return await this.model.findByIdAndDelete(id).exec();
  }
}

module.exports = BaseRepository;
`);

// Manager Repository
fs.writeFileSync(`repositories/${config.manager.name}Repository.js`, `const BaseRepository = require('./baseRepository');
const ${capitalize(config.manager.name)} = require('../models/${config.manager.name}');

class ${capitalize(config.manager.name)}Repository extends BaseRepository {
  constructor() {
    super(${capitalize(config.manager.name)});
  }

  async findByUsername(username) {
    return await this.model.findOne({ ${config.manager.userField}: username }).exec();
  }

  async findAllSafe() {
    return await this.model.find({}).select('-${config.manager.passField}').lean().exec();
  }

  async findByIdSafe(id) {
    return await this.model.findById(id).select('-${config.manager.passField}').lean().exec();
  }
}

module.exports = new ${capitalize(config.manager.name)}Repository();
`);

// Independent Repositories
config.independentEntities.forEach(ent => {
  fs.writeFileSync(`repositories/${ent.name}Repository.js`, `const BaseRepository = require('./baseRepository');
const ${capitalize(ent.name)} = require('../models/${ent.name}');

class ${capitalize(ent.name)}Repository extends BaseRepository {
  constructor() {
    super(${capitalize(ent.name)});
  }

  async findByTitle(title) {
    return await this.model.findOne({ title }).lean().exec();
  }
}

module.exports = new ${capitalize(ent.name)}Repository();
`);
});

// Dependent Repositories
config.dependentEntities.forEach(ent => {
  const refPopulateArray = (ent.references || []).map(r => `'${r.fieldName}'`).join(', ');

  fs.writeFileSync(`repositories/${ent.name}Repository.js`, `const BaseRepository = require('./baseRepository');
const ${capitalize(ent.name)} = require('../models/${ent.name}');

class ${capitalize(ent.name)}Repository extends BaseRepository {
  constructor() {
    super(${capitalize(ent.name)});
  }

  async findAllPopulated(filter = {}) {
    return await this.findAll(filter, [${refPopulateArray}]);
  }

  async findByIdPopulated(id) {
    return await this.findById(id, [${refPopulateArray}]);
  }

  async findByTitle(title) {
    return await this.model.findOne({ title }).lean().exec();
  }
}

module.exports = new ${capitalize(ent.name)}Repository();
`);
});

// -----------------------------------------------------------------------------
// 3. UTILS & CONSTANTS
// -----------------------------------------------------------------------------

fs.writeFileSync('utils/constants/auth.js', `module.exports = {
  USER_FIELD: '${config.manager.userField}',
  PASS_FIELD: '${config.manager.passField}',
  SESSION_USER_KEY: 'user',
  JWT_EXPIRES_IN: '1h'
};
`);

fs.writeFileSync('utils/constants/messages.js', `module.exports = {
  AUTH: {
    LOGIN_SUCCESS: 'Login successful',
    INVALID_CREDENTIALS: 'Invalid username or password',
    UNAUTHORIZED: 'Please log in to continue',
    LOGOUT_SUCCESS: 'Logged out successfully'
  },
  CRUD: {
    CREATED: 'Created successfully',
    UPDATED: 'Updated successfully',
    DELETED: 'Deleted successfully',
    NOT_FOUND: 'Item not found',
    DELETE_RESTRICTED: 'Cannot delete item because it is referenced by other records'
  }
};
`);

let entityRoutesEntries = [];
allEntities.forEach(ent => {
  entityRoutesEntries.push(`  ${ent.name.toUpperCase()}: { PAGE: '/admin/${ent.col}', API: '/v1/${ent.col}' }`);
});

fs.writeFileSync('utils/constants/routes.js', `module.exports = {
  HOME: '/',
  AUTH: {
    LOGIN: '/auth/login',
    LOGOUT: '/auth/logout',
    TOKEN: '/auth/tokens'
  },
  ENTITIES: {
${entityRoutesEntries.join(',\n')}
  },
  DEFAULT_PAGE: '${defaultPagePath}',
  AFTER_LOGIN: '${defaultPagePath}'
};
`);

fs.writeFileSync('utils/constants/ui.js', `module.exports = {
  // Cấu hình kích thước hình ảnh cho toàn bộ giao diện (dễ dàng chỉnh sửa width / height)
  IMAGE: {
    TABLE: {
      WIDTH: 75,
      HEIGHT: 75,
      FIT: 'cover',
      BORDER_RADIUS: '8px'
    },
    DETAIL: {
      WIDTH: 260,
      HEIGHT: 260,
      FIT: 'cover',
      BORDER_RADIUS: '12px'
    },
    CARD: {
      WIDTH: '100%',
      HEIGHT: 180,
      FIT: 'cover',
      BORDER_RADIUS: '8px'
    }
  }
};
`);

// -----------------------------------------------------------------------------
// 4. MIDDLEWARES (authPage for Session UI & authJWT for Bearer Token API)
// -----------------------------------------------------------------------------

// Session Authentication for Web Pages
fs.writeFileSync('middlewares/authPage.js', `const routes = require('../utils/constants/routes');

module.exports = function authPage(req, res, next) {
  if (req.session && req.session.user) {
    return next();
  }
  return res.redirect(routes.AUTH.LOGIN);
};
`);

// JWT Authentication for REST APIs
fs.writeFileSync('middlewares/authJWT.js', `const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'SE190703';

module.exports = function authJWT(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      success: false,
      message: 'Access denied: Bearer token required'
    });
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
    next();
  } catch (err) {
    return res.status(403).json({
      success: false,
      message: 'Invalid or expired token'
    });
  }
};
`);

// Central Error Handler
fs.writeFileSync('middlewares/errorHandler.js', `module.exports = function errorHandler(err, req, res, next) {
  const status = err.status || 500;
  const isApi = req.path.startsWith('/v1/') || (req.headers.accept && req.headers.accept.includes('application/json'));

  if (isApi) {
    return res.status(status).json({
      success: false,
      message: err.message || 'Internal Server Error'
    });
  }

  res.status(status);
  res.render('error', {
    title: 'Error ' + status,
    message: err.message,
    error: req.app.get('env') === 'development' ? err : {}
  });
};
`);

// -----------------------------------------------------------------------------
// 5. SERVICES (Auth & Entity Services with Business Rules & Validations)
// -----------------------------------------------------------------------------

// Auth Service
fs.writeFileSync('services/authService.js', `const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const managerRepo = require('../repositories/${config.manager.name}Repository');

const JWT_SECRET = process.env.JWT_SECRET || 'SE190703';

async function login(username, password) {
  if (!username || !password) {
    const err = new Error('Username and password are required');
    err.status = 400;
    throw err;
  }

  const admin = await managerRepo.findByUsername(username);
  if (!admin) {
    const err = new Error('Invalid username or password');
    err.status = 401;
    throw err;
  }

  const match = bcrypt.compareSync(password, admin['${config.manager.passField}']);
  if (!match) {
    const err = new Error('Invalid username or password');
    err.status = 401;
    throw err;
  }

  const token = jwt.sign(
    {
      id: admin._id,
      username: admin['${config.manager.userField}'],
      role: admin.role || 'admin'
    },
    JWT_SECRET,
    { expiresIn: '1h' }
  );

  const safeUser = admin.toObject ? admin.toObject() : { ...admin };
  delete safeUser['${config.manager.passField}'];

  return { token, user: safeUser };
}

function verifyToken(token) {
  return jwt.verify(token, JWT_SECRET);
}

module.exports = {
  login,
  verifyToken
};
`);

// Entity Services
allEntities.forEach(ent => {
  const cap = capitalize(ent.name);
  const capPlural = capitalize(pluralizeJs(ent.name));
  const fields = ent.isManager ? [] : parseFields(ent.fields);
  const references = ent.references || [];

  const booleanFieldNames = fields.filter(f => f.type === 'Boolean').map(f => f.name);
  const numberFieldNames = fields.filter(f => f.type === 'Number').map(f => f.name);

  const refRepoRequires = references.map(r => `const ${r.targetEntity}Repo = require('../repositories/${r.targetEntity}Repository');`).join('\n');
  const refDataFetches = references.map(r => `refData.${pluralizeJs(r.targetEntity)} = await ${r.targetEntity}Repo.findAll();`).join('\n    ');

  let cascadeDeleteChecks = '';
  config.dependentEntities.forEach(dep => {
    (dep.references || []).forEach(r => {
      if (r.targetEntity === ent.name) {
        cascadeDeleteChecks += `
  const ${dep.name}Repo = require('../repositories/${dep.name}Repository');
  const count${capitalize(dep.name)} = await ${dep.name}Repo.model.countDocuments({ ${r.fieldName}: id });
  if (count${capitalize(dep.name)} > 0) {
    const err = new Error('Cannot delete ${ent.name}: referenced by ' + count${capitalize(dep.name)} + ' ${dep.name}(s)');
    err.status = 400;
    throw err;
  }`;
      }
    });
  });

  let refExistenceValidation = '';
  references.forEach(r => {
    refExistenceValidation += `
  if (data['${r.fieldName}']) {
    const target = await ${r.targetEntity}Repo.findById(data['${r.fieldName}']);
    if (!target) {
      const err = new Error('${capitalize(r.targetEntity)} not found');
      err.status = 400;
      throw err;
    }
  }`;
  });

  let normalizationLogic = `  const data = { ...inputData };\n`;

  if (ent.isManager) {
    normalizationLogic += `  if (data['${config.manager.passField}'] && data['${config.manager.passField}'].trim()) {
    data['${config.manager.passField}'] = bcrypt.hashSync(data['${config.manager.passField}'], 10);
  } else if (!isCreate) {
    delete data['${config.manager.passField}'];
  }\n`;
  }

  booleanFieldNames.forEach(bf => {
    normalizationLogic += `  data['${bf}'] = (data['${bf}'] === true || data['${bf}'] === 'true' || data['${bf}'] === 'on' || data['${bf}'] === '1');\n`;
  });

  numberFieldNames.forEach(nf => {
    normalizationLogic += `  if (data['${nf}'] !== undefined && data['${nf}'] !== '') {
    data['${nf}'] = Number(data['${nf}']);
    if (isNaN(data['${nf}'])) {
      const err = new Error('${capitalize(nf)} must be a valid number');
      err.status = 400;
      throw err;
    }
    ${nf.toLowerCase().includes('progress') ? `if (data['${nf}'] < 0 || data['${nf}'] > 1) {
      const err = new Error('${capitalize(nf)} must be between 0 and 1');
      err.status = 400;
      throw err;
    }` : ''}
  }\n`;
  });

  const arrayFieldNames = fields.filter(f => f.type === '[String]' || f.ui === 'comma-list').map(f => f.name);
  arrayFieldNames.forEach(af => {
    normalizationLogic += `  if (data['${af}'] !== undefined) {
    if (typeof data['${af}'] === 'string') {
      data['${af}'] = data['${af}'].split(',').map(s => s.trim()).filter(Boolean);
    }
  }\n`;
  });

  const serviceCode = `const ${ent.isManager ? "bcrypt = require('bcryptjs');\n" : ''}repo = require('../repositories/${ent.name}Repository');
${refRepoRequires}

async function getAll${capPlural}(filter = {}) {
  ${ent.isManager ? 'return await repo.findAllSafe();' : (references.length > 0 ? 'return await repo.findAllPopulated(filter);' : 'return await repo.findAll(filter);')}
}

async function get${cap}ById(id) {
  const item = ${ent.isManager ? 'await repo.findByIdSafe(id);' : (references.length > 0 ? 'await repo.findByIdPopulated(id);' : 'await repo.findById(id);')}
  if (!item) {
    const err = new Error('${cap} not found');
    err.status = 404;
    throw err;
  }
  return item;
}

function normalizeData(inputData, isCreate = false) {
${normalizationLogic}  return data;
}

async function create${cap}(raw) {
  const data = normalizeData(raw, true);

  ${ent.isManager ? `if (data['${config.manager.userField}']) {
    const existing = await repo.findByUsername(data['${config.manager.userField}'].trim());
    if (existing) {
      const err = new Error('Username already exists');
      err.status = 400;
      throw err;
    }
  }` : `if (data.title && typeof data.title === 'string' && data.title.trim()) {
    const existing = await repo.model.findOne({ title: data.title.trim() });
    if (existing) {
      const err = new Error('Title already exists');
      err.status = 400;
      throw err;
    }
  }`}
${refExistenceValidation}
  const item = await repo.create(data);
  ${ent.isManager ? `const safe = item.toObject ? item.toObject() : { ...item };
  delete safe['${config.manager.passField}'];
  return safe;` : 'return item;'}
}

async function update${cap}(id, raw) {
  await get${cap}ById(id);
  const data = normalizeData(raw, false);

  ${ent.isManager ? `if (data['${config.manager.userField}']) {
    const existing = await repo.findByUsername(data['${config.manager.userField}'].trim());
    if (existing && existing._id.toString() !== id.toString()) {
      const err = new Error('Username already exists');
      err.status = 400;
      throw err;
    }
  }` : `if (data.title && typeof data.title === 'string' && data.title.trim()) {
    const existing = await repo.model.findOne({ title: data.title.trim() });
    if (existing && existing._id.toString() !== id.toString()) {
      const err = new Error('Title already exists');
      err.status = 400;
      throw err;
    }
  }`}
${refExistenceValidation}
  const item = await repo.updateById(id, data);
  ${ent.isManager ? `if (item && item['${config.manager.passField}']) {
    delete item['${config.manager.passField}'];
  }
  return item;` : 'return item;'}
}

async function delete${cap}(id) {
  await get${cap}ById(id);${cascadeDeleteChecks}
  return await repo.deleteById(id);
}

async function getRefData() {
  const refData = {};
  try {
    ${refDataFetches}
  } catch (e) {
    console.error('Error fetching reference data:', e.message);
  }
  return refData;
}

module.exports = {
  getAll${capPlural},
  getAll: getAll${capPlural},
  get${cap}ById,
  getById: get${cap}ById,
  create${cap},
  create: create${cap},
  update${cap},
  update: update${cap},
  delete${cap},
  delete: delete${cap},
  getRefData
};
`;

  fs.writeFileSync(`services/${ent.name}Service.js`, serviceCode);
});

// -----------------------------------------------------------------------------
// 6. CONTROLLERS (Named Functions Exported with module.exports = { ... })
// -----------------------------------------------------------------------------

// Auth Controller
fs.writeFileSync('controllers/auth.js', `const authService = require('../services/authService');
const routes = require('../utils/constants/routes');
const messages = require('../utils/constants/messages');
const authConstants = require('../utils/constants/auth');

function showLogin(req, res) {
  if (req.session && req.session.user) {
    return res.redirect(routes.AFTER_LOGIN);
  }
  const error = req.session ? req.session.login_error : null;
  if (req.session) delete req.session.login_error;

  res.render('auth/login', {
    title: 'Login',
    error,
    userField: authConstants.USER_FIELD,
    passField: authConstants.PASS_FIELD,
    routes
  });
}

async function processLogin(req, res) {
  try {
    const username = req.body[authConstants.USER_FIELD] || req.body.username;
    const password = req.body[authConstants.PASS_FIELD] || req.body.password;

    if (!username || !password) {
      return res.render('auth/login', {
        title: 'Login',
        error: messages.AUTH.INVALID_CREDENTIALS,
        userField: authConstants.USER_FIELD,
        passField: authConstants.PASS_FIELD,
        routes
      });
    }

    const result = await authService.login(username, password);
    req.session.user = {
      id: result.user._id,
      username: result.user[authConstants.USER_FIELD],
      role: result.user.role || 'admin',
      fullName: result.user.fullName || 'User'
    };

    return res.redirect(routes.AFTER_LOGIN);
  } catch (err) {
    return res.render('auth/login', {
      title: 'Login',
      error: err.message || messages.AUTH.INVALID_CREDENTIALS,
      userField: authConstants.USER_FIELD,
      passField: authConstants.PASS_FIELD,
      routes
    });
  }
}

function logout(req, res) {
  if (req.session) {
    req.session.destroy(() => {
      res.redirect(routes.AUTH.LOGIN);
    });
  } else {
    res.redirect(routes.AUTH.LOGIN);
  }
}

async function issueToken(req, res) {
  try {
    const username = req.body[authConstants.USER_FIELD] || req.body.username;
    const password = req.body[authConstants.PASS_FIELD] || req.body.password;

    if (!username || !password) {
      return res.status(400).json({ success: false, message: 'Username and password required' });
    }

    const result = await authService.login(username, password);
    return res.json({
      success: true,
      message: 'Token issued successfully',
      token: result.token,
      expiresIn: '1h'
    });
  } catch (err) {
    return res.status(err.status || 401).json({ success: false, message: err.message });
  }
}

module.exports = {
  showLogin,
  processLogin,
  logout,
  issueToken
};
`);

// Entity Controllers (Named Functions, imports Service only)
allEntities.forEach(ent => {
  const cap = capitalize(ent.name);
  const capPlural = capitalize(pluralizeJs(ent.name));
  const pagePath = `/admin/${ent.col}`;

  const ctrlCode = `const ${ent.name}Service = require('../services/${ent.name}Service');

// Page UI Controllers (Session Authenticated)
async function renderCards(req, res, next) {
  try {
    const items = await ${ent.name}Service.getAll${capPlural}();
    const refData = await ${ent.name}Service.getRefData();
    res.render('${ent.name}/cards', { title: '${capPlural} (Cards)', items, ...refData });
  } catch (err) {
    next(err);
  }
}

async function renderList(req, res, next) {
  try {
    const items = await ${ent.name}Service.getAll${capPlural}();
    const refData = await ${ent.name}Service.getRefData();
    res.render('${ent.name}/list', { title: '${capPlural} (List)', items, ...refData });
  } catch (err) {
    next(err);
  }
}

async function renderDetail(req, res, next) {
  try {
    const item = await ${ent.name}Service.get${cap}ById(req.params.id);
    const refData = await ${ent.name}Service.getRefData();
    res.render('${ent.name}/detail', {
      title: item.name || item.title || item.username || '${cap} Detail',
      item,
      ...refData
    });
  } catch (err) {
    if (err.status === 404 && req.session) {
      req.session.error_msg = '${cap} not found';
      return res.redirect('${pagePath}');
    }
    next(err);
  }
}

async function create(req, res, next) {
  try {
    await ${ent.name}Service.create${cap}(req.body);
    if (req.session) {
      req.session.success_msg = '${cap} created successfully';
    }
    res.redirect('${pagePath}');
  } catch (err) {
    if (req.session) {
      req.session.error_msg = err.message;
    }
    res.redirect('${pagePath}');
  }
}

async function update(req, res, next) {
  try {
    await ${ent.name}Service.update${cap}(req.params.id, req.body);
    if (req.session) {
      req.session.success_msg = '${cap} updated successfully';
    }
    res.redirect('${pagePath}');
  } catch (err) {
    if (req.session) {
      req.session.error_msg = err.message;
    }
    res.redirect('${pagePath}');
  }
}

async function deleteRecord(req, res, next) {
  try {
    await ${ent.name}Service.delete${cap}(req.params.id);
    if (req.method === 'DELETE' || (req.headers.accept && req.headers.accept.includes('application/json'))) {
      return res.json({ success: true, message: '${cap} deleted successfully' });
    }
    if (req.session) {
      req.session.success_msg = '${cap} deleted successfully';
    }
    res.redirect('${pagePath}');
  } catch (err) {
    if (req.method === 'DELETE' || (req.headers.accept && req.headers.accept.includes('application/json'))) {
      return res.status(err.status || 400).json({ success: false, message: err.message });
    }
    if (req.session) {
      req.session.error_msg = err.message;
    }
    res.redirect('${pagePath}');
  }
}

// REST API Controllers (JWT Bearer Authenticated)
async function apiGetAll(req, res, next) {
  try {
    const items = await ${ent.name}Service.getAll${capPlural}();
    res.json({ success: true, count: items.length, data: items });
  } catch (err) {
    next(err);
  }
}

async function apiGetById(req, res, next) {
  try {
    const item = await ${ent.name}Service.get${cap}ById(req.params.id);
    res.json({ success: true, data: item });
  } catch (err) {
    res.status(err.status || 404).json({ success: false, message: err.message });
  }
}

async function apiCreate(req, res, next) {
  try {
    const item = await ${ent.name}Service.create${cap}(req.body);
    res.status(201).json({ success: true, message: 'Created successfully', data: item });
  } catch (err) {
    res.status(err.status || 400).json({ success: false, message: err.message });
  }
}

async function apiUpdate(req, res, next) {
  try {
    const item = await ${ent.name}Service.update${cap}(req.params.id, req.body);
    res.json({ success: true, message: 'Updated successfully', data: item });
  } catch (err) {
    res.status(err.status || 400).json({ success: false, message: err.message });
  }
}

async function apiDelete(req, res, next) {
  try {
    await ${ent.name}Service.delete${cap}(req.params.id);
    res.json({ success: true, message: 'Deleted successfully' });
  } catch (err) {
    res.status(err.status || 400).json({ success: false, message: err.message });
  }
}

module.exports = {
  renderCards,
  renderList,
  renderDetail,
  create,
  update,
  deleteRecord,
  delete: deleteRecord,
  apiGetAll,
  apiGetById,
  apiCreate,
  apiUpdate,
  apiDelete
};
`;

  fs.writeFileSync(`controllers/${ent.name}.js`, ctrlCode);
});

// -----------------------------------------------------------------------------
// 7. ROUTES (Destructuring Imports, Clean Architecture, routes/index.js Hub)
// -----------------------------------------------------------------------------

// routes/auth.js
fs.writeFileSync('routes/auth.js', `const express = require('express');
const router = express.Router();
const { showLogin, processLogin, logout, issueToken } = require('../controllers/auth');

// UI Web Pages (Session)
router.get('/login', showLogin);
router.post('/login', processLogin);
router.get('/access', showLogin);
router.post('/access', processLogin);
router.get('/logout', logout);
router.post('/logout', logout);

// REST API Token (JWT)
router.post('/tokens', issueToken);

module.exports = router;
`);

// Entity Page & API Routes
allEntities.forEach(ent => {
  const isBoth = ent.viewType === 'both';
  const isCard = ent.viewType === 'card';
  const defaultAction = isCard ? 'renderCards' : (isBoth ? 'renderCards' : 'renderList');

  let pageSubRoutes = `router.get('/', ${defaultAction});\n`;
  if (isBoth) {
    pageSubRoutes += `router.get('/cards', renderCards);\n`;
    pageSubRoutes += `router.get('/list', renderList);\n`;
  } else if (isCard) {
    pageSubRoutes += `router.get('/cards', renderCards);\n`;
  } else {
    pageSubRoutes += `router.get('/list', renderList);\n`;
  }

  // routes/${ent.col}.page.js (UI Page Router, Session Protected)
  const pageRouteCode = `const express = require('express');
const router = express.Router();
const authPage = require('../middlewares/authPage');
const {
  renderCards,
  renderList,
  renderDetail,
  create,
  update,
  deleteRecord
} = require('../controllers/${ent.name}');

// Protected by Session authentication
router.use(authPage);

${pageSubRoutes}router.get('/:id', renderDetail);
router.post('/', create);
router.post('/:id', update);
router.delete('/:id', deleteRecord);

module.exports = router;
`;
  fs.writeFileSync(`routes/${ent.col}.page.js`, pageRouteCode);

  // routes/${ent.col}.api.js (REST API Router, JWT Protected)
  const apiRouteCode = `const express = require('express');
const router = express.Router();
const authJWT = require('../middlewares/authJWT');
const {
  apiGetAll,
  apiGetById,
  apiCreate,
  apiUpdate,
  apiDelete
} = require('../controllers/${ent.name}');

// Protected by JWT Bearer token
router.use(authJWT);

router.get('/', apiGetAll);
router.get('/:id', apiGetById);
router.post('/', apiCreate);
router.put('/:id', apiUpdate);
router.delete('/:id', apiDelete);

module.exports = router;
`;
  fs.writeFileSync(`routes/${ent.col}.api.js`, apiRouteCode);
});

// routes/index.js (Central Route Hub)
let indexRequires = `const express = require('express');
const router = express.Router();
const routes = require('../utils/constants/routes');

const authRouter = require('./auth');
`;

let indexMounts = `// Auth Routes (Session UI Login & REST API Token)
router.use('/auth', authRouter);

// REST API Routes (JWT Bearer Token Protected)
`;

allEntities.forEach(ent => {
  indexRequires += `const ${ent.name}ApiRouter = require('./${ent.col}.api');\n`;
  indexMounts += `router.use('/v1/${ent.col}', ${ent.name}ApiRouter);\n`;
});

indexMounts += `\n// Web Page Routes (Session Protected)\n`;
allEntities.forEach(ent => {
  indexRequires += `const ${ent.name}PageRouter = require('./${ent.col}.page');\n`;
  indexMounts += `router.use('/admin/${ent.col}', ${ent.name}PageRouter);\n`;
  // Backward compatibility: also support direct /${ent.col}
  indexMounts += `router.use('/${ent.col}', ${ent.name}PageRouter);\n`;
});

indexMounts += `
// Home route redirect
router.get('/', (req, res) => {
  if (req.session && req.session.user) {
    return res.redirect(routes.AFTER_LOGIN);
  }
  return res.redirect(routes.AUTH.LOGIN);
});
`;

fs.writeFileSync('routes/index.js', `${indexRequires}
${indexMounts}
module.exports = router;
`);

// Clean up unused default express users.js if present
if (fs.existsSync('routes/users.js')) fs.unlinkSync('routes/users.js');

// -----------------------------------------------------------------------------
// 8. VIEWS & TEMPLATES (Server-rendered Handlebars UI with Session)
// -----------------------------------------------------------------------------

fs.writeFileSync('views/layout.hbs', `{{{body}}}\n`);

fs.writeFileSync('views/partials/header.hbs', `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{{title}}</title>
  <link
    href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css"
    rel="stylesheet"
  >
  <link rel="stylesheet" href="/stylesheets/style.css">
</head>
<body>
  <header>
    {{#unless hideNavbar}}
      {{> navbar}}
    {{/unless}}
  </header>
  <main class="container my-4">
    {{> alerts}}
`);

fs.writeFileSync('views/partials/footer.hbs', `  </main>
  <!-- Global Bootstrap Delete Confirmation Modal -->
  <div class="modal fade" id="deleteConfirmModal" tabindex="-1" aria-labelledby="deleteConfirmModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
      <div class="modal-content shadow border-0">
        <div class="modal-header bg-danger text-white">
          <h5 class="modal-title fw-bold" id="deleteConfirmModalLabel">
            <span class="me-2">⚠️</span> Confirm Delete
          </h5>
          <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close"></button>
        </div>
        <div class="modal-body p-4">
          <p class="mb-0 fs-6">Are you sure you want to permanently delete this item? This action cannot be undone.</p>
        </div>
        <div class="modal-footer bg-light border-0">
          <button type="button" class="btn btn-secondary px-4" data-bs-dismiss="modal">Cancel</button>
          <button type="button" class="btn btn-danger px-4" id="btnConfirmDeleteAction">Delete</button>
        </div>
      </div>
    </div>
  </div>

  <footer class="text-center py-4 text-muted border-top mt-auto">
    <div class="container">
      <small>&copy; ${new Date().getFullYear()} ${config.projectName} &bull; SDN302 Practical Exam</small>
    </div>
  </footer>
  <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
  <script src="/javascripts/main.js"></script>
</body>
</html>
`);

fs.writeFileSync('views/partials/alerts.hbs', `{{#if success_msg}}
  <div class="alert alert-success alert-dismissible fade show" role="alert">
    {{success_msg}}
    <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
  </div>
{{/if}}
{{#if error_msg}}
  <div class="alert alert-danger alert-dismissible fade show" role="alert">
    {{error_msg}}
    <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
  </div>
{{/if}}
`);

// Navbar links
let navLinks = '';
allEntities.forEach(ent => {
  if (ent.viewType === 'none') return;
  const label = capitalize(pluralizeJs(ent.name));
  const pageUrl = `/admin/${ent.col}`;
  if (ent.viewType === 'both') {
    navLinks += `
        <li class="nav-item">
          <a class="nav-link" href="${pageUrl}">${label} (Cards)</a>
        </li>
        <li class="nav-item">
          <a class="nav-link" href="${pageUrl}/list">${label} (List)</a>
        </li>`;
  } else {
    navLinks += `
        <li class="nav-item">
          <a class="nav-link" href="${pageUrl}">${label}</a>
        </li>`;
  }
});

fs.writeFileSync('views/partials/navbar.hbs', `<nav class="navbar navbar-expand-lg navbar-dark bg-dark shadow-sm">
  <div class="container">
    <a class="navbar-brand fw-bold" href="/">${config.projectName}</a>
    <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navContent" aria-controls="navContent" aria-expanded="false" aria-label="Toggle navigation">
      <span class="navbar-toggler-icon"></span>
    </button>
    <div class="collapse navbar-collapse" id="navContent">
      <ul class="navbar-nav me-auto mb-2 mb-lg-0">${navLinks}
      </ul>
      <div class="d-flex align-items-center">
        {{#if currentUser}}
          <span class="navbar-text me-3 text-light">
            User: <strong>{{currentUser.username}}</strong>
          </span>
          <form action="/auth/logout" method="POST" class="d-inline">
            <button type="submit" class="btn btn-outline-light btn-sm">Logout</button>
          </form>
        {{else}}
          <a href="/auth/login" class="btn btn-primary btn-sm">Login</a>
        {{/if}}
      </div>
    </div>
  </div>
</nav>
`);

// Login View (Standard Session Form)
fs.writeFileSync('views/auth/login.hbs', `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{{title}}</title>
  <link
    href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css"
    rel="stylesheet"
  >
  <link rel="stylesheet" href="/stylesheets/style.css">
</head>
<body class="bg-light d-flex align-items-center justify-content-center min-vh-100">
  <div class="card shadow p-4" style="max-width: 420px; width: 100%;">
    <div class="text-center mb-4">
      <h3 class="fw-bold">{{title}}</h3>
      <p class="text-muted small">Sign in to manage your system</p>
    </div>
    {{#if error}}
      <div class="alert alert-danger py-2" role="alert">
        {{error}}
      </div>
    {{/if}}
    <form action="/auth/login" method="POST">
      <div class="mb-3">
        <label for="username" class="form-label fw-semibold">Username</label>
        <input type="text" class="form-control" id="username" name="{{userField}}" placeholder="Enter username" required autofocus>
      </div>
      <div class="mb-3">
        <label for="password" class="form-label fw-semibold">Password</label>
        <input type="password" class="form-control" id="password" name="{{passField}}" placeholder="Enter password" required>
      </div>
      <button type="submit" class="btn btn-primary w-100 py-2 fw-semibold">Sign In</button>
    </form>
  </div>
  <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
`);

fs.writeFileSync('views/error.hbs', `{{> header}}
<div class="alert alert-danger my-5">
  <h1 class="display-6">{{message}}</h1>
  <h2>{{error.status}}</h2>
  <pre>{{error.stack}}</pre>
</div>
{{> footer}}
`);

// Entity Views Generator (cards, list, detail, addModal, editModal)
allEntities.forEach(ent => {
  const edir = `views/${ent.name}`;
  fs.mkdirSync(`${edir}/partials`, { recursive: true });

  const pagePath = `/admin/${ent.col}`;
  const isBoth = ent.viewType === 'both';
  const isCard = ent.viewType === 'card';
  const isTable = ent.viewType === 'table';

  const fieldsList = parseFields(ent.fields || []);
  const references = ent.references || [];

  let addInputs = '';
  let editInputs = '';

  const dynamicInputs = fieldsList.map(f => {
      const isProg = f.name.toLowerCase().includes('progress');
      const minAttr = f.min !== undefined && f.min !== '' ? `min="${f.min}"` : '';
      const maxAttr = f.max !== undefined && f.max !== '' ? `max="${f.max}"` : '';
      const rangeAttr = isProg ? 'min="0" max="1"' : `${minAttr} ${maxAttr}`.trim();

      if (f.ui === 'switch' || (f.type === 'Boolean' && f.ui !== 'checkbox')) {
        return `<div class="mb-3 form-check form-switch">
            <input type="checkbox" role="switch" name="${f.name}" class="form-check-input" id="add-${ent.name}-${f.name}" value="true" ${f.defaultValue === 'true' || f.defaultValue === true ? 'checked' : ''}>
            <label class="form-check-label fw-semibold" for="add-${ent.name}-${f.name}">${f.label}</label>
          </div>`;
      } else if (f.ui === 'checkbox' || f.type === 'Boolean') {
        return `<div class="mb-3 form-check">
            <input type="checkbox" name="${f.name}" class="form-check-input" id="add-${ent.name}-${f.name}" value="true" ${f.defaultValue === 'true' || f.defaultValue === true ? 'checked' : ''}>
            <label class="form-check-label fw-semibold" for="add-${ent.name}-${f.name}">${f.label}</label>
          </div>`;
      } else if (f.ui === 'textarea') {
        return `<div class="mb-3">
            <label class="form-label fw-semibold">${f.label}</label>
            <textarea name="${f.name}" class="form-control" rows="3" placeholder="Enter ${f.label}" ${f.required ? 'required' : ''}></textarea>
          </div>`;
      } else if (f.ui === 'url' || f.ui === 'image' || f.type === 'Image') {
        return `<div class="mb-3">
            <label class="form-label fw-semibold">${f.label}</label>
            <input type="url" name="${f.name}" class="form-control" placeholder="https://example.com/image.jpg" ${f.required ? 'required' : ''}>
          </div>`;
      } else if (f.ui === 'password') {
        return `<div class="mb-3">
            <label class="form-label fw-semibold">${f.label}</label>
            <input type="password" name="${f.name}" class="form-control" placeholder="Enter ${f.label}" ${f.required ? 'required' : ''}>
          </div>`;
      } else if (f.ui === 'comma-list' || f.type === '[String]' || f.type === '[Image]') {
        return `<div class="mb-3">
            <label class="form-label fw-semibold">${f.label} (comma-separated list)</label>
            <input type="text" name="${f.name}" class="form-control" placeholder="item1, item2, item3" ${f.required ? 'required' : ''}>
          </div>`;
      } else if (f.ui === 'number' || f.type === 'Number') {
        return `<div class="mb-3">
            <label class="form-label fw-semibold">${f.label}${isProg ? ' (0 - 1)' : ''}</label>
            <input type="number" step="any" ${rangeAttr} name="${f.name}" class="form-control" placeholder="Enter ${f.label}" ${f.required ? 'required' : ''}>
          </div>`;
      } else if (f.ui === 'date' || f.type === 'Date') {
        return `<div class="mb-3">
            <label class="form-label fw-semibold">${f.label}</label>
            <input type="date" name="${f.name}" class="form-control" ${f.required ? 'required' : ''}>
          </div>`;
      } else {
        return `<div class="mb-3">
            <label class="form-label fw-semibold">${f.label}</label>
            <input type="text" name="${f.name}" class="form-control" placeholder="Enter ${f.label}" ${f.defaultValue ? `value="${f.defaultValue}"` : ''} ${f.required ? 'required' : ''}>
          </div>`;
      }
    }).join('\n          ');

    const dynamicEditInputs = fieldsList.map(f => {
      const isProg = f.name.toLowerCase().includes('progress');
      const minAttr = f.min !== undefined && f.min !== '' ? `min="${f.min}"` : '';
      const maxAttr = f.max !== undefined && f.max !== '' ? `max="${f.max}"` : '';
      const rangeAttr = isProg ? 'min="0" max="1"' : `${minAttr} ${maxAttr}`.trim();

      if (f.ui === 'switch' || (f.type === 'Boolean' && f.ui !== 'checkbox')) {
        return `<div class="mb-3 form-check form-switch">
            <input type="checkbox" role="switch" name="${f.name}" class="form-check-input" id="edit-${ent.name}-${f.name}-{{this._id}}" value="true" {{#if this.${f.name}}}checked{{/if}}>
            <label class="form-check-label fw-semibold" for="edit-${ent.name}-${f.name}-{{this._id}}">${f.label}</label>
          </div>`;
      } else if (f.ui === 'checkbox' || f.type === 'Boolean') {
        return `<div class="mb-3 form-check">
            <input type="checkbox" name="${f.name}" class="form-check-input" id="edit-${ent.name}-${f.name}-{{this._id}}" value="true" {{#if this.${f.name}}}checked{{/if}}>
            <label class="form-check-label fw-semibold" for="edit-${ent.name}-${f.name}-{{this._id}}">${f.label}</label>
          </div>`;
      } else if (f.ui === 'textarea') {
        return `<div class="mb-3">
            <label class="form-label fw-semibold">${f.label}</label>
            <textarea name="${f.name}" class="form-control" rows="3" ${f.required ? 'required' : ''}>{{this.${f.name}}}</textarea>
          </div>`;
      } else if (f.ui === 'url' || f.ui === 'image' || f.type === 'Image') {
        return `<div class="mb-3">
            <label class="form-label fw-semibold">${f.label}</label>
            <input type="url" name="${f.name}" class="form-control" value="{{this.${f.name}}}" placeholder="https://example.com/image.jpg" ${f.required ? 'required' : ''}>
          </div>`;
      } else if (f.ui === 'password') {
        return `<div class="mb-3">
            <label class="form-label fw-semibold">${f.label}</label>
            <input type="password" name="${f.name}" class="form-control" placeholder="Leave blank to keep current">
          </div>`;
      } else if (f.ui === 'comma-list' || f.type === '[String]' || f.type === '[Image]') {
        return `<div class="mb-3">
            <label class="form-label fw-semibold">${f.label} (comma-separated list)</label>
            <input type="text" name="${f.name}" class="form-control" value="{{this.${f.name}}}" placeholder="item1, item2, item3" ${f.required ? 'required' : ''}>
          </div>`;
      } else if (f.ui === 'number' || f.type === 'Number') {
        return `<div class="mb-3">
            <label class="form-label fw-semibold">${f.label}${isProg ? ' (0 - 1)' : ''}</label>
            <input type="number" step="any" ${rangeAttr} name="${f.name}" class="form-control" value="{{this.${f.name}}}" ${f.required ? 'required' : ''}>
          </div>`;
      } else if (f.ui === 'date' || f.type === 'Date') {
        return `<div class="mb-3">
            <label class="form-label fw-semibold">${f.label}</label>
            <input type="date" name="${f.name}" class="form-control" value="{{this.${f.name}}}" ${f.required ? 'required' : ''}>
          </div>`;
      } else {
        return `<div class="mb-3">
            <label class="form-label fw-semibold">${f.label}</label>
            <input type="text" name="${f.name}" class="form-control" value="{{this.${f.name}}}" ${f.required ? 'required' : ''}>
          </div>`;
      }
    }).join('\n          ');

  if (ent.isManager) {
    addInputs = `<div class="mb-3">
            <label class="form-label fw-semibold">${capitalize(config.manager.userField)}</label>
            <input type="text" name="${config.manager.userField}" class="form-control" placeholder="Enter ${config.manager.userField}" required>
          </div>
          <div class="mb-3">
            <label class="form-label fw-semibold">Password</label>
            <input type="password" name="${config.manager.passField}" class="form-control" placeholder="Enter password" required>
          </div>
          ${dynamicInputs}`;

    editInputs = `<div class="mb-3">
            <label class="form-label fw-semibold">${capitalize(config.manager.userField)}</label>
            <input type="text" name="${config.manager.userField}" class="form-control" value="{{this.${config.manager.userField}}}" required>
          </div>
          <div class="mb-3">
            <label class="form-label fw-semibold">New Password (leave blank to keep current)</label>
            <input type="password" name="${config.manager.passField}" class="form-control" placeholder="New password">
          </div>
          ${dynamicEditInputs}`;
  } else {
    addInputs = dynamicInputs;
    editInputs = dynamicEditInputs;
    addInputs = fieldsList.map(f => {
      const isProg = f.name.toLowerCase().includes('progress');
      const minAttr = f.min !== undefined && f.min !== '' ? `min="${f.min}"` : '';
      const maxAttr = f.max !== undefined && f.max !== '' ? `max="${f.max}"` : '';
      const rangeAttr = isProg ? 'min="0" max="1"' : `${minAttr} ${maxAttr}`.trim();

      if (f.ui === 'switch' || (f.type === 'Boolean' && f.ui !== 'checkbox')) {
        return `<div class="mb-3 form-check form-switch">
            <input type="checkbox" role="switch" name="${f.name}" class="form-check-input" id="add-${ent.name}-${f.name}" value="true" ${f.defaultValue === 'true' || f.defaultValue === true ? 'checked' : ''}>
            <label class="form-check-label fw-semibold" for="add-${ent.name}-${f.name}">${f.label}</label>
          </div>`;
      } else if (f.ui === 'checkbox' || f.type === 'Boolean') {
        return `<div class="mb-3 form-check">
            <input type="checkbox" name="${f.name}" class="form-check-input" id="add-${ent.name}-${f.name}" value="true" ${f.defaultValue === 'true' || f.defaultValue === true ? 'checked' : ''}>
            <label class="form-check-label fw-semibold" for="add-${ent.name}-${f.name}">${f.label}</label>
          </div>`;
      } else if (f.ui === 'textarea') {
        return `<div class="mb-3">
            <label class="form-label fw-semibold">${f.label}</label>
            <textarea name="${f.name}" class="form-control" rows="3" placeholder="Enter ${f.label}" ${f.required ? 'required' : ''}></textarea>
          </div>`;
      } else if (f.ui === 'url') {
        return `<div class="mb-3">
            <label class="form-label fw-semibold">${f.label}</label>
            <input type="url" name="${f.name}" class="form-control" placeholder="https://example.com" ${f.required ? 'required' : ''}>
          </div>`;
      } else if (f.ui === 'password') {
        return `<div class="mb-3">
            <label class="form-label fw-semibold">${f.label}</label>
            <input type="password" name="${f.name}" class="form-control" placeholder="Enter ${f.label}" ${f.required ? 'required' : ''}>
          </div>`;
      } else if (f.ui === 'comma-list' || f.type === '[String]') {
        return `<div class="mb-3">
            <label class="form-label fw-semibold">${f.label} (comma-separated list)</label>
            <input type="text" name="${f.name}" class="form-control" placeholder="item1, item2, item3" ${f.required ? 'required' : ''}>
          </div>`;
      } else if (f.ui === 'number' || f.type === 'Number') {
        return `<div class="mb-3">
            <label class="form-label fw-semibold">${f.label}${isProg ? ' (0 - 1)' : ''}</label>
            <input type="number" step="any" ${rangeAttr} name="${f.name}" class="form-control" placeholder="Enter ${f.label}" ${f.required ? 'required' : ''}>
          </div>`;
      } else if (f.ui === 'date' || f.type === 'Date') {
        return `<div class="mb-3">
            <label class="form-label fw-semibold">${f.label}</label>
            <input type="date" name="${f.name}" class="form-control" ${f.required ? 'required' : ''}>
          </div>`;
      } else {
        return `<div class="mb-3">
            <label class="form-label fw-semibold">${f.label}</label>
            <input type="text" name="${f.name}" class="form-control" placeholder="Enter ${f.label}" ${f.required ? 'required' : ''}>
          </div>`;
      }
    }).join('\n          ');

    editInputs = fieldsList.map(f => {
      const isProg = f.name.toLowerCase().includes('progress');
      const minAttr = f.min !== undefined && f.min !== '' ? `min="${f.min}"` : '';
      const maxAttr = f.max !== undefined && f.max !== '' ? `max="${f.max}"` : '';
      const rangeAttr = isProg ? 'min="0" max="1"' : `${minAttr} ${maxAttr}`.trim();

      if (f.ui === 'switch' || (f.type === 'Boolean' && f.ui !== 'checkbox')) {
        return `<div class="mb-3 form-check form-switch">
            <input type="checkbox" role="switch" name="${f.name}" class="form-check-input" id="edit-${ent.name}-${f.name}-{{this._id}}" value="true" {{#if this.${f.name}}}checked{{/if}}>
            <label class="form-check-label fw-semibold" for="edit-${ent.name}-${f.name}-{{this._id}}">${f.label}</label>
          </div>`;
      } else if (f.ui === 'checkbox' || f.type === 'Boolean') {
        return `<div class="mb-3 form-check">
            <input type="checkbox" name="${f.name}" class="form-check-input" id="edit-${ent.name}-${f.name}-{{this._id}}" value="true" {{#if this.${f.name}}}checked{{/if}}>
            <label class="form-check-label fw-semibold" for="edit-${ent.name}-${f.name}-{{this._id}}">${f.label}</label>
          </div>`;
      } else if (f.ui === 'textarea') {
        return `<div class="mb-3">
            <label class="form-label fw-semibold">${f.label}</label>
            <textarea name="${f.name}" class="form-control" rows="3" ${f.required ? 'required' : ''}>{{this.${f.name}}}</textarea>
          </div>`;
      } else if (f.ui === 'url') {
        return `<div class="mb-3">
            <label class="form-label fw-semibold">${f.label}</label>
            <input type="url" name="${f.name}" class="form-control" value="{{this.${f.name}}}" placeholder="https://example.com" ${f.required ? 'required' : ''}>
          </div>`;
      } else if (f.ui === 'password') {
        return `<div class="mb-3">
            <label class="form-label fw-semibold">${f.label}</label>
            <input type="password" name="${f.name}" class="form-control" placeholder="Leave blank to keep current">
          </div>`;
      } else if (f.ui === 'comma-list' || f.type === '[String]') {
        return `<div class="mb-3">
            <label class="form-label fw-semibold">${f.label} (comma-separated list)</label>
            <input type="text" name="${f.name}" class="form-control" value="{{this.${f.name}}}" placeholder="item1, item2, item3" ${f.required ? 'required' : ''}>
          </div>`;
      } else if (f.ui === 'number' || f.type === 'Number') {
        return `<div class="mb-3">
            <label class="form-label fw-semibold">${f.label}${isProg ? ' (0 - 1)' : ''}</label>
            <input type="number" step="any" ${rangeAttr} name="${f.name}" class="form-control" value="{{this.${f.name}}}" ${f.required ? 'required' : ''}>
          </div>`;
      } else if (f.ui === 'date' || f.type === 'Date') {
        return `<div class="mb-3">
            <label class="form-label fw-semibold">${f.label}</label>
            <input type="date" name="${f.name}" class="form-control" value="{{this.${f.name}}}" ${f.required ? 'required' : ''}>
          </div>`;
      } else {
        return `<div class="mb-3">
            <label class="form-label fw-semibold">${f.label}</label>
            <input type="text" name="${f.name}" class="form-control" value="{{this.${f.name}}}" ${f.required ? 'required' : ''}>
          </div>`;
      }
    }).join('\n          ');

    references.forEach(r => {
      const targetSingular = singularizeJs(r.targetEntity);
      const targetPlural = pluralizeJs(r.targetEntity);
      const isOneToOne = r.type === '1:1';
      const refLabel = capitalize(r.fieldName) + (isOneToOne ? ' (1:1)' : '');
      const disp = r.displayField || 'name';

      const addRefSelect = `<div class="mb-3">
            <label class="form-label fw-semibold">${refLabel}</label>
            <select name="${r.fieldName}" class="form-select" required>
              <option value="">-- Select ${capitalize(targetSingular)} --</option>
              {{#if ${targetPlural}}}
                {{#each ${targetPlural}}}
                  <option value="{{this._id}}">{{#if this.${disp}}}{{this.${disp}}}{{else}}{{#if this.userAlias}}{{this.userAlias}}{{else}}{{#if this.name}}{{this.name}}{{else}}{{#if this.title}}{{this.title}}{{else}}{{#if this.username}}{{this.username}}{{else}}{{this._id}}{{/if}}{{/if}}{{/if}}{{/if}}{{/if}}</option>
                {{/each}}
              {{else if ${targetSingular}}}
                {{#each ${targetSingular}}}
                  <option value="{{this._id}}">{{#if this.${disp}}}{{this.${disp}}}{{else}}{{#if this.userAlias}}{{this.userAlias}}{{else}}{{#if this.name}}{{this.name}}{{else}}{{#if this.title}}{{this.title}}{{else}}{{#if this.username}}{{this.username}}{{else}}{{this._id}}{{/if}}{{/if}}{{/if}}{{/if}}{{/if}}</option>
                {{/each}}
              {{else if @root.${targetPlural}}}
                {{#each @root.${targetPlural}}}
                  <option value="{{this._id}}">{{#if this.${disp}}}{{this.${disp}}}{{else}}{{#if this.userAlias}}{{this.userAlias}}{{else}}{{#if this.name}}{{this.name}}{{else}}{{#if this.title}}{{this.title}}{{else}}{{#if this.username}}{{this.username}}{{else}}{{this._id}}{{/if}}{{/if}}{{/if}}{{/if}}{{/if}}</option>
                {{/each}}
              {{else if @root.${targetSingular}}}
                {{#each @root.${targetSingular}}}
                  <option value="{{this._id}}">{{#if this.${disp}}}{{this.${disp}}}{{else}}{{#if this.userAlias}}{{this.userAlias}}{{else}}{{#if this.name}}{{this.name}}{{else}}{{#if this.title}}{{this.title}}{{else}}{{#if this.username}}{{this.username}}{{else}}{{this._id}}{{/if}}{{/if}}{{/if}}{{/if}}{{/if}}</option>
                {{/each}}
              {{/if}}
            </select>
          </div>`;

      const editRefSelect = `<div class="mb-3">
            <label class="form-label fw-semibold">${refLabel}</label>
            <select name="${r.fieldName}" class="form-select" required>
              <option value="">-- Select ${capitalize(targetSingular)} --</option>
              {{#if ../${targetPlural}}}
                {{#each ../${targetPlural}}}
                  <option value="{{this._id}}" {{#if (eq this._id ../${r.fieldName}._id)}}selected{{else}}{{#if (eq this._id ../${r.fieldName})}}selected{{/if}}{{/if}}>
                    {{#if this.${disp}}}{{this.${disp}}}{{else}}{{#if this.userAlias}}{{this.userAlias}}{{else}}{{#if this.name}}{{this.name}}{{else}}{{#if this.title}}{{this.title}}{{else}}{{#if this.username}}{{this.username}}{{else}}{{this._id}}{{/if}}{{/if}}{{/if}}{{/if}}{{/if}}
                  </option>
                {{/each}}
              {{else if ../${targetSingular}}}
                {{#each ../${targetSingular}}}
                  <option value="{{this._id}}" {{#if (eq this._id ../${r.fieldName}._id)}}selected{{else}}{{#if (eq this._id ../${r.fieldName})}}selected{{/if}}{{/if}}>
                    {{#if this.${disp}}}{{this.${disp}}}{{else}}{{#if this.userAlias}}{{this.userAlias}}{{else}}{{#if this.name}}{{this.name}}{{else}}{{#if this.title}}{{this.title}}{{else}}{{#if this.username}}{{this.username}}{{else}}{{this._id}}{{/if}}{{/if}}{{/if}}{{/if}}{{/if}}
                  </option>
                {{/each}}
              {{else if @root.${targetPlural}}}
                {{#each @root.${targetPlural}}}
                  <option value="{{this._id}}" {{#if (eq this._id ../${r.fieldName}._id)}}selected{{else}}{{#if (eq this._id ../${r.fieldName})}}selected{{/if}}{{/if}}>
                    {{#if this.${disp}}}{{this.${disp}}}{{else}}{{#if this.userAlias}}{{this.userAlias}}{{else}}{{#if this.name}}{{this.name}}{{else}}{{#if this.title}}{{this.title}}{{else}}{{#if this.username}}{{this.username}}{{else}}{{this._id}}{{/if}}{{/if}}{{/if}}{{/if}}{{/if}}
                  </option>
                {{/each}}
              {{else if @root.${targetSingular}}}
                {{#each @root.${targetSingular}}}
                  <option value="{{this._id}}" {{#if (eq this._id ../${r.fieldName}._id)}}selected{{else}}{{#if (eq this._id ../${r.fieldName})}}selected{{/if}}{{/if}}>
                    {{#if this.${disp}}}{{this.${disp}}}{{else}}{{#if this.userAlias}}{{this.userAlias}}{{else}}{{#if this.name}}{{this.name}}{{else}}{{#if this.title}}{{this.title}}{{else}}{{#if this.username}}{{this.username}}{{else}}{{this._id}}{{/if}}{{/if}}{{/if}}{{/if}}{{/if}}
                  </option>
                {{/each}}
              {{/if}}
            </select>
          </div>`;

      addInputs += (addInputs ? '\n          ' : '') + addRefSelect;
      editInputs += (editInputs ? '\n          ' : '') + editRefSelect;
    });
  }

  // addModal.hbs
  fs.writeFileSync(`${edir}/partials/addModal.hbs`, `<div class="modal fade" id="addModal" tabindex="-1" aria-labelledby="addModalLabel" aria-hidden="true">
  <div class="modal-dialog">
    <div class="modal-content">
      <form action="${pagePath}" method="POST">
        <div class="modal-header">
          <h5 class="modal-title" id="addModalLabel">Add New ${capitalize(ent.name)}</h5>
          <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
        </div>
        <div class="modal-body">
          ${addInputs}
        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
          <button type="submit" class="btn btn-primary">Save ${capitalize(ent.name)}</button>
        </div>
      </form>
    </div>
  </div>
</div>
`);

  // editModal.hbs
  fs.writeFileSync(`${edir}/partials/editModal.hbs`, `<div class="modal fade" id="editModal-{{this._id}}" tabindex="-1" aria-labelledby="editModalLabel-{{this._id}}" aria-hidden="true">
  <div class="modal-dialog">
    <div class="modal-content">
      <form action="${pagePath}/{{this._id}}" method="POST">
        <div class="modal-header">
          <h5 class="modal-title" id="editModalLabel-{{this._id}}">Edit ${capitalize(ent.name)}</h5>
          <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
        </div>
        <div class="modal-body">
          ${editInputs}
        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
          <button type="submit" class="btn btn-primary">Update ${capitalize(ent.name)}</button>
        </div>
      </form>
    </div>
  </div>
</div>
`);

  const addModalRefParams = references.map(r => `${pluralizeJs(r.targetEntity)}=${pluralizeJs(r.targetEntity)} ${r.targetEntity}=${pluralizeJs(r.targetEntity)}`).join(' ');
  const editModalRefParams = references.map(r => `${pluralizeJs(r.targetEntity)}=../${pluralizeJs(r.targetEntity)} ${r.targetEntity}=../${pluralizeJs(r.targetEntity)}`).join(' ');
  const detailModalRefParams = references.map(r => `${pluralizeJs(r.targetEntity)}=${pluralizeJs(r.targetEntity)} ${r.targetEntity}=${pluralizeJs(r.targetEntity)}`).join(' ');

  let cardsTopActions = '';
  let listTopActions = '';

  if (isBoth) {
    cardsTopActions = `<a href="${pagePath}/list" class="btn btn-outline-secondary me-2">Table View</a>`;
    listTopActions = `<a href="${pagePath}" class="btn btn-outline-secondary me-2">Cards View</a>`;
  }

  let cardBadges = '';
  references.forEach(r => {
    const disp = r.displayField || 'name';
    cardBadges += `<span class="badge bg-info text-dark mb-2 me-1">{{this.${r.fieldName}.${disp}}}{{#unless this.${r.fieldName}.${disp}}}{{this.${r.fieldName}.userAlias}}{{this.${r.fieldName}.name}}{{this.${r.fieldName}.title}}{{this.${r.fieldName}.username}}{{/unless}}</span>`;
  });

  const isImageField = (f) => {
    if (!f) return false;
    return f.ui === 'image' || f.type === 'Image' || f.type === '[Image]' || /image|avatar|photo|thumb|poster|logo|banner/i.test(f.name || '');
  };

  const imgField = fieldsList.find(isImageField);
  let cardImageHtml = '';
  if (imgField) {
    cardImageHtml = `{{#if this.${imgField.name}}}
        <div style="height: {{@root.uiConfig.IMAGE.CARD.HEIGHT}}px; overflow: hidden; border-top-left-radius: 8px; border-top-right-radius: 8px;">
          {{#if this.${imgField.name}.[0]}}
            {{#each this.${imgField.name}}}
              {{#if @first}}
                <img src="{{this}}" class="card-img-top w-100 h-100" style="object-fit: {{@root.uiConfig.IMAGE.CARD.FIT}};" onerror="this.onerror=null;this.src='https://placehold.co/400x180?text=No+Image';">
              {{/if}}
            {{/each}}
          {{else}}
            <img src="{{this.${imgField.name}}}" class="card-img-top w-100 h-100" style="object-fit: {{@root.uiConfig.IMAGE.CARD.FIT}};" onerror="this.onerror=null;this.src='https://placehold.co/400x180?text=No+Image';">
          {{/if}}
        </div>
      {{/if}}`;
  }

  const cardsContent = `{{> header}}
<div class="d-flex justify-content-between align-items-center mb-4">
  <div>
    <h2 class="fw-bold mb-1">${capitalize(pluralizeJs(ent.name))}</h2>
    <p class="text-muted mb-0">Browse ${ent.name} records in cards view</p>
  </div>
  <div>
    ${cardsTopActions}
    <button type="button" class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#addModal">+ Add ${capitalize(ent.name)}</button>
  </div>
</div>

<div class="row row-cols-1 row-cols-md-3 g-4">
  {{#each items}}
    <div class="col">
      <div class="card h-100 shadow-sm border-0">
        ${cardImageHtml}
        <div class="card-body">
          <div class="d-flex justify-content-between align-items-start mb-2">
            <h5 class="card-title fw-bold mb-0">{{#if this.name}}{{this.name}}{{else}}{{#if this.title}}{{this.title}}{{else}}{{#if this.username}}{{this.username}}{{else}}{{this._id}}{{/if}}{{/if}}{{/if}}</h5>
            {{#if this.price}}<span class="badge bg-primary fs-6">\${{this.price}}</span>{{/if}}
          </div>
          ${cardBadges}
          {{#if this.description}}<p class="card-text text-muted small mt-2">{{this.description}}</p>{{/if}}
          {{#if this.progress}}<div class="mt-2"><small class="text-muted">Progress: {{this.progress}}</small></div>{{/if}}
        </div>
        <div class="card-footer bg-transparent border-0 d-flex justify-content-between">
          <a href="${pagePath}/{{this._id}}" class="btn btn-sm btn-outline-primary">Details</a>
          <div class="text-nowrap">
            <button type="button" class="btn btn-sm btn-outline-warning me-1" data-bs-toggle="modal" data-bs-target="#editModal-{{this._id}}">Edit</button>
            <button type="button" class="btn btn-sm btn-outline-danger" onclick="deleteItem('${pagePath}/{{this._id}}', '${pagePath}')">Delete</button>
          </div>
        </div>
      </div>
    </div>
  {{else}}
    <div class="col-12 text-center py-5">
      <p class="text-muted fs-5">No ${ent.name} records found.</p>
    </div>
  {{/each}}
</div>

{{#each items}}
  {{> ${ent.name}EditModal this ${editModalRefParams}}}
{{/each}}

{{> ${ent.name}AddModal ${addModalRefParams}}}
{{> footer}}
`;

    const dynamicTableHeaders = fieldsList.map(f => `<th>${f.label}</th>`).join('\n            ');
  const dynamicTableCells = fieldsList.map(f => {
    const isImg = isImageField(f);
    if (isImg) {
      return `<td>
                {{#if this.${f.name}}}
                  <div class="d-flex gap-1 flex-wrap align-items-center">
                    {{#if this.${f.name}.[0]}}
                      {{#each this.${f.name}}}
                        <a href="{{this}}" target="_blank" title="View full image">
                          <img src="{{this}}" alt="${f.label}" class="table-img-thumb" style="width: {{@root.uiConfig.IMAGE.TABLE.WIDTH}}px; height: {{@root.uiConfig.IMAGE.TABLE.HEIGHT}}px; max-width: {{@root.uiConfig.IMAGE.TABLE.WIDTH}}px; max-height: {{@root.uiConfig.IMAGE.TABLE.HEIGHT}}px; object-fit: {{@root.uiConfig.IMAGE.TABLE.FIT}}; border-radius: {{@root.uiConfig.IMAGE.TABLE.BORDER_RADIUS}};" onerror="this.onerror=null;this.src='https://placehold.co/75x75?text=Img';">
                        </a>
                      {{/each}}
                    {{else}}
                      <a href="{{this.${f.name}}}" target="_blank" title="View full image">
                        <img src="{{this.${f.name}}}" alt="${f.label}" class="table-img-thumb" style="width: {{@root.uiConfig.IMAGE.TABLE.WIDTH}}px; height: {{@root.uiConfig.IMAGE.TABLE.HEIGHT}}px; max-width: {{@root.uiConfig.IMAGE.TABLE.WIDTH}}px; max-height: {{@root.uiConfig.IMAGE.TABLE.HEIGHT}}px; object-fit: {{@root.uiConfig.IMAGE.TABLE.FIT}}; border-radius: {{@root.uiConfig.IMAGE.TABLE.BORDER_RADIUS}};" onerror="this.onerror=null;this.src='https://placehold.co/75x75?text=Img';">
                      </a>
                    {{/if}}
                  </div>
                {{else}}
                  <span class="text-muted small">No image</span>
                {{/if}}
              </td>`;
    }
    if (f.type === '[String]' || f.ui === 'comma-list') {
      return `<td class="text-truncate" style="max-width: 250px;" title="{{this.${f.name}}}">{{this.${f.name}}}</td>`;
    }
    return `<td>{{this.${f.name}}}</td>`;
  }).join('\n              ');

  let tableHeaders = '';
  let tableCells = '';

  if (ent.isManager) {
    tableHeaders = `<th>${capitalize(config.manager.userField)}</th>` + (dynamicTableHeaders ? '\n            ' + dynamicTableHeaders : '');
    tableCells = `<td>{{this.${config.manager.userField}}}</td>` + (dynamicTableCells ? '\n              ' + dynamicTableCells : '');
  } else {
    tableHeaders = dynamicTableHeaders;
    references.forEach(r => {
      tableHeaders += `\n            <th>${capitalize(r.fieldName)}</th>`;
    });
    tableCells = dynamicTableCells;
    references.forEach(r => {
      const disp = r.displayField || 'name';
      tableCells += `\n              <td><span class="badge bg-info text-dark">{{this.${r.fieldName}.${disp}}}{{#unless this.${r.fieldName}.${disp}}}{{this.${r.fieldName}.userAlias}}{{this.${r.fieldName}.name}}{{this.${r.fieldName}.title}}{{this.${r.fieldName}.username}}{{/unless}}</span></td>`;
    });
  }

  const listContent = `{{> header}}
<div class="d-flex justify-content-between align-items-center mb-4">
  <div>
    <h2 class="fw-bold mb-1">${capitalize(pluralizeJs(ent.name))} (Table View)</h2>
    <p class="text-muted mb-0">Detailed list view of ${ent.name} records</p>
  </div>
  <div>
    ${listTopActions}
    <button type="button" class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#addModal">+ Add ${capitalize(ent.name)}</button>
  </div>
</div>

<div class="card shadow-sm border-0">
  <div class="card-body p-0">
    <div class="table-responsive">
      <table class="table table-hover align-middle mb-0">
        <thead>
          <tr>
            ${tableHeaders}
            <th class="text-end text-nowrap" style="width: 190px;">Actions</th>
          </tr>
        </thead>
        <tbody>
          {{#each items}}
            <tr>
              ${tableCells}
              <td class="text-end text-nowrap" style="width: 190px;">
                <a href="${pagePath}/{{this._id}}" class="btn btn-sm btn-outline-primary me-1">Details</a>
                <button type="button" class="btn btn-sm btn-outline-warning me-1" data-bs-toggle="modal" data-bs-target="#editModal-{{this._id}}">Edit</button>
                <button type="button" class="btn btn-sm btn-outline-danger" onclick="deleteItem('${pagePath}/{{this._id}}', '${pagePath}/list')">Delete</button>
              </td>
            </tr>
          {{else}}
            <tr>
              <td colspan="10" class="text-center py-4 text-muted">No ${ent.name} records found.</td>
            </tr>
          {{/each}}
        </tbody>
      </table>
    </div>
  </div>
</div>

{{#each items}}
  {{> ${ent.name}EditModal this ${editModalRefParams}}}
{{/each}}

{{> ${ent.name}AddModal ${addModalRefParams}}}
{{> footer}}
`;

  if (isCard || isBoth) {
    fs.writeFileSync(`${edir}/cards.hbs`, cardsContent);
  }
  if (isTable || isBoth) {
    fs.writeFileSync(`${edir}/list.hbs`, listContent);
  }

  // Detail View
    const dynamicDetailRows = fieldsList.map(f => {
    const isImg = isImageField(f);
    if (isImg) {
      return `<div class="mb-3">
        <label class="text-muted small fw-semibold text-uppercase">${f.label}</label>
        <div>
          {{#if item.${f.name}}}
            <div class="d-flex gap-2 flex-wrap mt-1">
              {{#if item.${f.name}.[0]}}
                {{#each item.${f.name}}}
                  <a href="{{this}}" target="_blank" title="View full image">
                    <img src="{{this}}" alt="${f.label}" class="img-thumbnail" style="width: {{@root.uiConfig.IMAGE.DETAIL.WIDTH}}px; height: {{@root.uiConfig.IMAGE.DETAIL.HEIGHT}}px; max-width: {{@root.uiConfig.IMAGE.DETAIL.WIDTH}}px; max-height: {{@root.uiConfig.IMAGE.DETAIL.HEIGHT}}px; object-fit: {{@root.uiConfig.IMAGE.DETAIL.FIT}}; border-radius: {{@root.uiConfig.IMAGE.DETAIL.BORDER_RADIUS}};" onerror="this.onerror=null;this.src='https://placehold.co/260x260?text=No+Image';">
                  </a>
                {{/each}}
              {{else}}
                <a href="{{item.${f.name}}}" target="_blank" title="View full image">
                  <img src="{{item.${f.name}}}" alt="${f.label}" class="img-thumbnail" style="width: {{@root.uiConfig.IMAGE.DETAIL.WIDTH}}px; height: {{@root.uiConfig.IMAGE.DETAIL.HEIGHT}}px; max-width: {{@root.uiConfig.IMAGE.DETAIL.WIDTH}}px; max-height: {{@root.uiConfig.IMAGE.DETAIL.HEIGHT}}px; object-fit: {{@root.uiConfig.IMAGE.DETAIL.FIT}}; border-radius: {{@root.uiConfig.IMAGE.DETAIL.BORDER_RADIUS}};" onerror="this.onerror=null;this.src='https://placehold.co/260x260?text=No+Image';">
                </a>
              {{/if}}
            </div>
          {{else}}
            <p class="text-muted mb-0">No image</p>
          {{/if}}
        </div>
      </div>`;
    }
    return `<div class="mb-3">
        <label class="text-muted small fw-semibold text-uppercase">${f.label}</label>
        <p class="fs-5 mb-0">{{item.${f.name}}}</p>
      </div>`;
  }).join('\n      ');

  let detailRows = '';
  if (ent.isManager) {
    detailRows = `<div class="mb-3">
        <label class="text-muted small fw-semibold text-uppercase">${capitalize(config.manager.userField)}</label>
        <p class="fs-5 mb-0">{{item.${config.manager.userField}}}</p>
      </div>` + (dynamicDetailRows ? '\n      ' + dynamicDetailRows : '');
  } else {
    detailRows = dynamicDetailRows;
    references.forEach(r => {
      const disp = r.displayField || 'name';
      detailRows += `\n      <div class="mb-3">
        <label class="text-muted small fw-semibold text-uppercase">${capitalize(r.fieldName)}</label>
        <p class="fs-5 mb-0"><span class="badge bg-info text-dark fs-6">{{item.${r.fieldName}.${disp}}}{{#unless item.${r.fieldName}.${disp}}}{{item.${r.fieldName}.userAlias}}{{item.${r.fieldName}.name}}{{item.${r.fieldName}.title}}{{item.${r.fieldName}.username}}{{/unless}}</span></p>
      </div>`;
    });
  }

  fs.writeFileSync(`${edir}/detail.hbs`, `{{> header}}
<div class="card shadow-sm border-0 mx-auto my-4" style="max-width: 680px;">
  <div class="card-header bg-primary text-white d-flex justify-content-between align-items-center py-3">
    <h4 class="mb-0 fw-bold">{{#if item.name}}{{item.name}}{{else}}{{#if item.title}}{{item.title}}{{else}}{{#if item.username}}{{item.username}}{{else}}Record Details{{/if}}{{/if}}{{/if}}</h4>
    {{#if item.price}}<span class="badge bg-light text-dark fs-6">\${{item.price}}</span>{{/if}}
  </div>
  <div class="card-body p-4">
      ${detailRows}
    <div class="mb-3">
      <label class="text-muted small fw-semibold text-uppercase">Record ID</label>
      <p class="text-muted font-monospace small mb-0">{{item._id}}</p>
    </div>
  </div>
  <div class="card-footer bg-light d-flex justify-content-between p-3">
    <a href="${pagePath}" class="btn btn-outline-secondary">&larr; Back to List</a>
    <div>
      <button type="button" class="btn btn-warning me-2" data-bs-toggle="modal" data-bs-target="#editModal-{{item._id}}">Edit</button>
      <button type="button" class="btn btn-danger" onclick="deleteItem('${pagePath}/{{item._id}}', '${pagePath}')">Delete</button>
    </div>
  </div>
</div>

{{> ${ent.name}EditModal item ${detailModalRefParams}}}
{{> footer}}
`);
});

// -----------------------------------------------------------------------------
// 9. CLIENT JAVASCRIPT & STYLES (Clean UI - NO localStorage, NO JWT)
// -----------------------------------------------------------------------------

fs.writeFileSync('public/javascripts/main.js', `let pendingDeleteUrl = null;
let pendingRedirectUrl = null;
let deleteModalInstance = null;

document.addEventListener('DOMContentLoaded', () => {
  const modalEl = document.getElementById('deleteConfirmModal');
  if (modalEl && typeof bootstrap !== 'undefined') {
    deleteModalInstance = new bootstrap.Modal(modalEl);
  }

  const confirmBtn = document.getElementById('btnConfirmDeleteAction');
  if (confirmBtn) {
    confirmBtn.addEventListener('click', async () => {
      if (deleteModalInstance) {
        deleteModalInstance.hide();
      }
      if (pendingDeleteUrl) {
        await executeDelete(pendingDeleteUrl, pendingRedirectUrl);
      }
    });
  }
});

function deleteItem(url, redirectUrl) {
  pendingDeleteUrl = url;
  pendingRedirectUrl = redirectUrl;

  if (deleteModalInstance) {
    deleteModalInstance.show();
  } else if (confirm('Are you sure you want to permanently delete this item?')) {
    executeDelete(url, redirectUrl);
  }
}

async function executeDelete(url, redirectUrl) {
  try {
    const response = await fetch(url, {
      method: 'DELETE',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      }
    });
    const result = await response.json().catch(() => ({}));
    if (response.ok && result.success !== false) {
      if (redirectUrl && redirectUrl !== window.location.pathname) {
        window.location.href = redirectUrl;
      } else {
        window.location.reload();
      }
    } else {
      alert(result.message || 'Delete operation failed.');
    }
  } catch (err) {
    alert('Network error: ' + err.message);
  }
}
`);

fs.writeFileSync('public/stylesheets/style.css', `body {
  background-color: #f8f9fa;
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}
main {
  flex: 1;
}
.card {
  transition: transform 0.15s ease-in-out, box-shadow 0.15s ease-in-out;
}
.card:hover {
  transform: translateY(-2px);
  box-shadow: 0 0.5rem 1rem rgba(0, 0, 0, 0.1) !important;
}
.table th {
  background-color: #f1f3f5;
}
.table-img-thumb {
  object-fit: cover;
  border-radius: 8px;
  border: 1px solid #dee2e6;
  display: inline-block;
  box-shadow: 0 1px 3px rgba(0,0,0,0.08);
}
`);

// -----------------------------------------------------------------------------
// 10. APP CONFIGURATION (Clean app.js & bin/www with session & central routes)
// -----------------------------------------------------------------------------

// bin/www
fs.writeFileSync('bin/www', `#!/usr/bin/env node

const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const app = require('../app');
const debug = require('debug')('${config.projectName}:server');
const http = require('http');

const port = normalizePort(process.env.PORT || '5000');
app.set('port', port);

const server = http.createServer(app);
server.listen(port);
server.on('error', onError);
server.on('listening', onListening);

function normalizePort(val) {
  const port = parseInt(val, 10);
  if (isNaN(port)) return val;
  if (port >= 0) return port;
  return false;
}

function onError(error) {
  if (error.syscall !== 'listen') throw error;
  const bind = typeof port === 'string' ? 'Pipe ' + port : 'Port ' + port;
  switch (error.code) {
    case 'EACCES':
      console.error(bind + ' requires elevated privileges');
      process.exit(1);
      break;
    case 'EADDRINUSE':
      console.error(bind + ' is already in use');
      process.exit(1);
      break;
    default:
      throw error;
  }
}

function onListening() {
  const addr = server.address();
  const bind = typeof addr === 'string' ? 'pipe ' + addr : 'port ' + addr.port;
  console.log('Server is running and listening on ' + bind);
}
`);

// app.js
fs.writeFileSync('app.js', `const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const createError = require('http-errors');
const express = require('express');
const cookieParser = require('cookie-parser');
const logger = require('morgan');
const session = require('express-session');
const mongoose = require('mongoose');
const hbs = require('hbs');
const fs = require('fs');

// Register all Mongoose models at startup
require('./models');

const routes = require('./utils/constants/routes');
const uiConfig = require('./utils/constants/ui');
const indexRouter = require('./routes/index');
const errorHandler = require('./middlewares/errorHandler');

const app = express();

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/${config.dbName}';
mongoose.connect(MONGODB_URI)
  .then(() => console.log('MongoDB connected successfully to ${config.dbName}'))
  .catch(err => console.error('MongoDB connection error:', err.message));

app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'hbs');

hbs.registerHelper('eq', function (a, b) {
  if (a !== undefined && b !== undefined && a !== null && b !== null) {
    return a.toString() === b.toString();
  }
  return a === b;
});


function registerPartialsRecursively(dir) {
  if (!fs.existsSync(dir)) return;
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      registerPartialsRecursively(fullPath);
    } else if (entry.name.endsWith('.hbs')) {
      const relPath = path.relative(path.join(__dirname, 'views'), fullPath);
      const partialName = relPath.replace(/\\\\/g, '/').replace(/\\.hbs$/, '');
      const content = fs.readFileSync(fullPath, 'utf8');
      hbs.registerPartial(partialName, content);

      const parts = relPath.split(path.sep);
      if (parts.length >= 3 && parts[1] === 'partials') {
        const entName = parts[0];
        const base = path.basename(entry.name, '.hbs');
        const alias = entName + base.charAt(0).toUpperCase() + base.slice(1);
        hbs.registerPartial(alias, content);
      }
      hbs.registerPartial(path.basename(entry.name, '.hbs'), content);
    }
  }
}
registerPartialsRecursively(path.join(__dirname, 'views'));

app.use(logger('dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(cookieParser());
app.use(express.static(path.join(__dirname, 'public')));

app.use(session({
  secret: 'sdn302-session-secret-key-se190703',
  resave: false,
  saveUninitialized: false,
  cookie: { maxAge: 24 * 60 * 60 * 1000 }
}));

app.use((req, res, next) => {
  res.locals.appName = '${config.projectName}';
  res.locals.routes = routes;
  res.locals.uiConfig = uiConfig;
  res.locals.currentUser = (req.session && req.session.user) ? req.session.user : null;
  res.locals.success_msg = req.session ? req.session.success_msg : null;
  res.locals.error_msg = req.session ? req.session.error_msg : null;
  if (req.session) {
    delete req.session.success_msg;
    delete req.session.error_msg;
  }
  next();
});

// Single Mount of Master Router Hub
app.use('/', indexRouter);

// Catch 404 and forward to error handler
app.use((req, res, next) => {
  next(createError(404));
});

// Central Error Handler
app.use(errorHandler);

module.exports = app;
`);

console.log('Project builder completed.');
EOF_NODE_GEN

# ------------------------------------------------------------------------------
# STEP [05/12] GENERATING MONGOOSE MODELS
# ------------------------------------------------------------------------------
echo -e "${CLR_BLUE}[05/12] Generating Mongoose models...${CLR_RESET}"
node .build_project.js >/dev/null
echo -e "        ${CLR_GREEN}✓ Mongoose models generated for all entities${CLR_RESET}"

# ------------------------------------------------------------------------------
# STEP [06/12] GENERATING REPOSITORIES
# ------------------------------------------------------------------------------
echo -e "${CLR_BLUE}[06/12] Generating repositories...${CLR_RESET}"
echo -e "        ${CLR_GREEN}✓ Repositories created with BaseRepository support${CLR_RESET}"

# ------------------------------------------------------------------------------
# STEP [07/12] GENERATING CONTROLLERS AND AUTHENTICATION
# ------------------------------------------------------------------------------
echo -e "${CLR_BLUE}[07/12] Generating controllers and authentication...${CLR_RESET}"
echo -e "        ${CLR_GREEN}✓ Controllers and authentication middleware generated${CLR_RESET}"

# ------------------------------------------------------------------------------
# STEP [08/12] REGISTERING PAGE AND API ROUTES
# ------------------------------------------------------------------------------
echo -e "${CLR_BLUE}[08/12] Registering page and API routes...${CLR_RESET}"
echo -e "        ${CLR_GREEN}✓ Page and API routes created with master routes/index.js${CLR_RESET}"

# ------------------------------------------------------------------------------
# STEP [09/12] GENERATING HBS PAGES AND BOOTSTRAP MODALS
# ------------------------------------------------------------------------------
echo -e "${CLR_BLUE}[09/12] Generating HBS pages and Bootstrap modals...${CLR_RESET}"
echo -e "        ${CLR_GREEN}✓ Handlebars templates and pre-filled Bootstrap modals generated${CLR_RESET}"

# ------------------------------------------------------------------------------
# STEP [10/12] CONFIGURING app.js AND bin/www
# ------------------------------------------------------------------------------
echo -e "${CLR_BLUE}[10/12] Configuring app.js and bin/www...${CLR_RESET}"
echo -e "        ${CLR_GREEN}✓ app.js and bin/www configured successfully${CLR_RESET}"

# ------------------------------------------------------------------------------
# STEP [11/12] CHECKING SYNTAX AND GENERATED FILES
# ------------------------------------------------------------------------------
echo -e "${CLR_BLUE}[11/12] Checking syntax and generated files...${CLR_RESET}"
js_files=$(find . -maxdepth 4 -name "*.js" -not -path "*/node_modules/*")
for js_file in $js_files; do
  if ! node --check "$js_file" >/dev/null 2>&1; then
    echo -e "${CLR_RED}✗ Syntax error in file: $js_file${CLR_RESET}"
    exit 1
  fi
done
echo -e "        ${CLR_GREEN}✓ All generated JavaScript files passed node syntax checks${CLR_RESET}"

# ------------------------------------------------------------------------------
# STEP [12/12] MONGODB PROVISIONING AND COLLECTION VERIFICATION
# ------------------------------------------------------------------------------
echo -e "${CLR_BLUE}[12/12] MongoDB provisioning and collection verification...${CLR_RESET}"

cat << 'EOF_PROVISION' > .provision_db.js
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const mongoose = require('mongoose');
const fs = require('fs');

const config = JSON.parse(fs.readFileSync('.generator_config.json', 'utf8'));

async function runProvisioning() {
  const uri = process.env.MONGODB_URI;
  console.log('Connecting to MongoDB at ' + uri + '...');

  try {
    await mongoose.connect(uri, { serverSelectionTimeoutMS: 5000 });
  } catch (err) {
    console.error('✗ Failed to connect to MongoDB server on 127.0.0.1:27017: ' + err.message);
    process.exit(1);
  }

  const db = mongoose.connection.db;
  console.log('✓ Connected to MongoDB database: ' + db.databaseName);

  const existingColsRaw = await db.listCollections().toArray();
  const existingCols = existingColsRaw.map(c => c.name);

  const requiredCols = [
    config.manager.col,
    ...config.independentEntities.map(e => e.col),
    ...config.dependentEntities.map(e => e.col)
  ];

  for (const col of requiredCols) {
    if (existingCols.includes(col)) {
      console.log("  - Collection '" + col + "' already exists in '" + db.databaseName + "' (preserved, no changes)");
    } else {
      await db.createCollection(col);
      console.log("  - Collection '" + col + "' created successfully in '" + db.databaseName + "'");
    }
  }

  const finalColsRaw = await db.listCollections().toArray();
  const finalCols = finalColsRaw.map(c => c.name);
  const missing = requiredCols.filter(c => !finalCols.includes(c));

  if (missing.length > 0) {
    console.error("✗ Verification failed. Missing required collections: " + missing.join(', '));
    process.exit(1);
  }

  console.log("✓ Verified all required collections exist: " + requiredCols.join(', '));
  console.log("  Collections are ready for data import via mongoimport or application usage.");
  await mongoose.disconnect();
  console.log("✓ MongoDB connection closed cleanly");
}

runProvisioning().catch(err => {
  console.error("✗ MongoDB provisioning error:", err);
  process.exit(1);
});
EOF_PROVISION

node .provision_db.js

rm -f .generator_config.json .build_project.js .provision_db.js

echo -e "        ${CLR_GREEN}✓ MongoDB provisioning and collection verification completed${CLR_RESET}"

# ------------------------------------------------------------------------------
# COMPLETION BANNER
# ------------------------------------------------------------------------------
echo ""
echo -e "${CLR_GREEN}${CLR_BOLD}================================================================${CLR_RESET}"
echo -e "${CLR_GREEN}${CLR_BOLD}✓ SDN302 Project '${PROJECT_NAME}' successfully generated!${CLR_RESET}"
echo -e "${CLR_GREEN}${CLR_BOLD}================================================================${CLR_RESET}"
echo ""
echo -e "Project location: $(pwd)"
echo -e "Database & Collections:"
echo -e "  All required collections are initialized and ready for mongoimport or direct use."
echo ""
echo -e "Next steps to run the application:"
echo -e "  ${CLR_CYAN}cd ${PROJECT_NAME}${CLR_RESET}"
echo -e "  ${CLR_CYAN}npm run dev${CLR_RESET}"
echo ""
echo -e "Web App Login URL:       ${CLR_BOLD}http://localhost:5000/auth/login${CLR_RESET}"
echo -e "JWT REST Token URL:      ${CLR_BOLD}POST http://localhost:5000/auth/tokens${CLR_RESET}"
echo ""
