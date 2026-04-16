// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Interface parser for idrisiser.
//
// Parses interface definitions (OpenAPI, C headers, Protocol Buffers, type signatures)
// and extracts function contracts: name, parameters, return type, pre/postconditions.
//
// Each parsed function becomes a proof obligation in the generated Idris2 code.

use anyhow::Result;

use crate::manifest::{InterfaceConfig, InterfaceFormat};

/// A parsed function contract extracted from an interface definition.
#[derive(Debug, Clone)]
pub struct FunctionContract {
    /// Function name (used in generated Idris2 module).
    pub name: String,
    /// Parameters with types.
    pub params: Vec<Param>,
    /// Return type.
    pub return_type: String,
    /// Preconditions (require clauses).
    pub preconditions: Vec<String>,
    /// Postconditions (ensure clauses).
    pub postconditions: Vec<String>,
    /// Invariants that must hold before and after.
    pub invariants: Vec<String>,
    /// Whether the function should be proven total.
    pub require_total: bool,
    /// HTTP method (for OpenAPI endpoints).
    pub http_method: Option<String>,
    /// URL path (for OpenAPI endpoints).
    pub path: Option<String>,
}

/// A function parameter with name and type.
#[derive(Debug, Clone)]
pub struct Param {
    pub name: String,
    pub type_name: String,
    /// Whether this parameter is required (non-optional).
    pub required: bool,
}

/// Parse an interface definition and extract function contracts.
/// The actual parsing depends on the format.
pub fn parse_interface(iface: &InterfaceConfig) -> Result<Vec<FunctionContract>> {
    // If the source file exists, try to read it for real parsing.
    // If it doesn't exist, generate synthetic contracts from the interface config.
    let source_content = std::fs::read_to_string(&iface.source).ok();

    let mut contracts = match iface.format {
        InterfaceFormat::Openapi => parse_openapi(iface, source_content.as_deref())?,
        InterfaceFormat::CHeader => parse_c_header(iface, source_content.as_deref())?,
        InterfaceFormat::Protobuf => parse_protobuf(iface, source_content.as_deref())?,
        InterfaceFormat::TypeSig => parse_type_sig(iface, source_content.as_deref())?,
    };

    // Apply user-specified preconditions/postconditions/invariants to all functions.
    for contract in &mut contracts {
        contract
            .preconditions
            .extend(iface.preconditions.iter().cloned());
        contract
            .postconditions
            .extend(iface.postconditions.iter().cloned());
        contract.invariants.extend(iface.invariants.iter().cloned());
    }

    // Filter to only verified functions if specified.
    // If filtering removes all contracts (e.g., source file not found and synthetic
    // contract name doesn't match), generate one contract per verify entry instead.
    if !iface.verify.is_empty() {
        contracts.retain(|c| iface.verify.contains(&c.name));

        if contracts.is_empty() {
            // Source file wasn't found or didn't contain the requested functions.
            // Generate synthetic contracts from the verify list so codegen can proceed.
            for func_name in &iface.verify {
                contracts.push(FunctionContract {
                    name: func_name.clone(),
                    params: vec![],
                    return_type: "()".to_string(),
                    preconditions: iface.preconditions.clone(),
                    postconditions: iface.postconditions.clone(),
                    invariants: iface.invariants.clone(),
                    require_total: true,
                    http_method: None,
                    path: None,
                });
            }
        }
    }

    Ok(contracts)
}

/// Parse an OpenAPI 3.x specification.
/// Extracts each endpoint as a function contract.
fn parse_openapi(iface: &InterfaceConfig, content: Option<&str>) -> Result<Vec<FunctionContract>> {
    let mut contracts = Vec::new();

    if let Some(text) = content {
        // Simple YAML/JSON parsing: look for path definitions.
        // A full implementation would use an OpenAPI parser crate.
        // For now, extract paths and methods from common patterns.
        for line in text.lines() {
            let trimmed = line.trim();

            // Detect YAML path entries like "  /users:"
            if trimmed.starts_with('/') && trimmed.ends_with(':') {
                let path = trimmed.trim_end_matches(':').to_string();
                let func_name = path_to_function_name(&path);

                // Look ahead for HTTP methods — for now, generate a GET contract
                contracts.push(FunctionContract {
                    name: func_name,
                    params: vec![],
                    return_type: "Response".to_string(),
                    preconditions: vec!["valid_auth_token".to_string()],
                    postconditions: vec![
                        "status_code >= 200".to_string(),
                        "status_code < 500".to_string(),
                    ],
                    invariants: vec![],
                    require_total: true,
                    http_method: Some("GET".to_string()),
                    path: Some(path),
                });
            }

            // Detect method entries like "    get:" or "    post:"
            let methods = ["get:", "post:", "put:", "delete:", "patch:"];
            for method in &methods {
                if trimmed == *method
                    && let Some(last) = contracts.last_mut()
                {
                    last.http_method = Some(method.trim_end_matches(':').to_uppercase());
                }
            }
        }
    }

    // If no content or no paths found, generate a synthetic contract from the interface name
    if contracts.is_empty() {
        contracts.push(FunctionContract {
            name: iface.name.replace('-', "_"),
            params: vec![Param {
                name: "request".to_string(),
                type_name: "Request".to_string(),
                required: true,
            }],
            return_type: "Response".to_string(),
            preconditions: vec![],
            postconditions: vec![],
            invariants: vec![],
            require_total: true,
            http_method: None,
            path: None,
        });
    }

    Ok(contracts)
}

/// Parse a C header file.
/// Extracts function declarations as contracts.
fn parse_c_header(iface: &InterfaceConfig, content: Option<&str>) -> Result<Vec<FunctionContract>> {
    let mut contracts = Vec::new();

    if let Some(text) = content {
        // Simple C function declaration parser.
        // Matches patterns like: int function_name(type param, type param);
        for line in text.lines() {
            let trimmed = line.trim();

            // Skip comments and preprocessor directives
            if trimmed.starts_with("//")
                || trimmed.starts_with("/*")
                || trimmed.starts_with('#')
                || trimmed.is_empty()
            {
                continue;
            }

            // Look for function declarations: return_type name(params);
            if let Some(contract) = try_parse_c_function(trimmed) {
                contracts.push(contract);
            }
        }
    }

    if contracts.is_empty() {
        contracts.push(FunctionContract {
            name: iface.name.replace('-', "_"),
            params: vec![
                Param {
                    name: "input".to_string(),
                    type_name: "Ptr".to_string(),
                    required: true,
                },
                Param {
                    name: "len".to_string(),
                    type_name: "Int".to_string(),
                    required: true,
                },
            ],
            return_type: "Int".to_string(),
            preconditions: vec!["input != NULL".to_string()],
            postconditions: vec!["result >= 0".to_string()],
            invariants: vec![],
            require_total: true,
            http_method: None,
            path: None,
        });
    }

    Ok(contracts)
}

/// Try to parse a single C function declaration.
fn try_parse_c_function(line: &str) -> Option<FunctionContract> {
    // Strip trailing semicolon
    let line = line.trim_end_matches(';').trim();

    // Find the opening parenthesis
    let paren_pos = line.find('(')?;
    let close_paren = line.rfind(')')?;

    // Everything before '(' is "return_type function_name"
    let before_paren = &line[..paren_pos];
    let param_str = &line[paren_pos + 1..close_paren];

    // Split return type and function name
    let parts: Vec<&str> = before_paren.split_whitespace().collect();
    if parts.len() < 2 {
        return None;
    }

    let func_name = parts.last()?.trim_start_matches('*').to_string();
    let return_type = parts[..parts.len() - 1].join(" ");

    // Parse parameters
    let params: Vec<Param> = if param_str.trim() == "void" || param_str.trim().is_empty() {
        vec![]
    } else {
        param_str
            .split(',')
            .filter_map(|p| {
                let p = p.trim();
                let parts: Vec<&str> = p.split_whitespace().collect();
                if parts.len() >= 2 {
                    let param_name = parts.last()?.trim_start_matches('*').to_string();
                    let type_name = parts[..parts.len() - 1].join(" ");
                    Some(Param {
                        name: param_name,
                        type_name: c_type_to_idris(&type_name),
                        required: true,
                    })
                } else {
                    None
                }
            })
            .collect()
    };

    // Auto-generate preconditions for pointer parameters
    let preconditions: Vec<String> = params
        .iter()
        .filter(|p| p.type_name.contains("Ptr"))
        .map(|p| format!("{} != NULL", p.name))
        .collect();

    Some(FunctionContract {
        name: func_name,
        params,
        return_type: c_type_to_idris(&return_type),
        preconditions,
        postconditions: vec![],
        invariants: vec![],
        require_total: true,
        http_method: None,
        path: None,
    })
}

/// Parse a Protocol Buffers .proto file.
/// Extracts service RPC methods as contracts.
fn parse_protobuf(iface: &InterfaceConfig, content: Option<&str>) -> Result<Vec<FunctionContract>> {
    let mut contracts = Vec::new();

    if let Some(text) = content {
        // Look for rpc declarations: rpc MethodName (RequestType) returns (ResponseType);
        for line in text.lines() {
            let trimmed = line.trim();
            if trimmed.starts_with("rpc ")
                && let Some(contract) = try_parse_rpc(trimmed)
            {
                contracts.push(contract);
            }
        }
    }

    if contracts.is_empty() {
        contracts.push(FunctionContract {
            name: iface.name.replace('-', "_"),
            params: vec![Param {
                name: "request".to_string(),
                type_name: "Message".to_string(),
                required: true,
            }],
            return_type: "Message".to_string(),
            preconditions: vec![],
            postconditions: vec![],
            invariants: vec![],
            require_total: true,
            http_method: None,
            path: None,
        });
    }

    Ok(contracts)
}

/// Try to parse a protobuf RPC declaration.
fn try_parse_rpc(line: &str) -> Option<FunctionContract> {
    // rpc MethodName (RequestType) returns (ResponseType);
    let line = line.trim_start_matches("rpc ").trim_end_matches(';').trim();

    let name_end = line.find('(')?;
    let name = line[..name_end].trim().to_string();

    let req_start = name_end + 1;
    let req_end = line.find(')')?;
    let request_type = line[req_start..req_end].trim().to_string();

    // Find "returns" keyword
    let returns_pos = line.find("returns")?;
    let resp_start = line[returns_pos..].find('(')? + returns_pos + 1;
    let resp_end = line[returns_pos..].find(')')? + returns_pos;
    let response_type = line[resp_start..resp_end].trim().to_string();

    Some(FunctionContract {
        name,
        params: vec![Param {
            name: "request".to_string(),
            type_name: request_type,
            required: true,
        }],
        return_type: response_type,
        preconditions: vec![],
        postconditions: vec![],
        invariants: vec![],
        require_total: true,
        http_method: None,
        path: None,
    })
}

/// Parse a type signature file (custom format).
/// Each line is: function_name : ParamType -> ParamType -> ReturnType
fn parse_type_sig(iface: &InterfaceConfig, content: Option<&str>) -> Result<Vec<FunctionContract>> {
    let mut contracts = Vec::new();

    if let Some(text) = content {
        for line in text.lines() {
            let trimmed = line.trim();
            if trimmed.is_empty() || trimmed.starts_with("--") {
                continue;
            }

            // Format: name : Type -> Type -> ReturnType
            if let Some(colon_pos) = trimmed.find(':') {
                let name = trimmed[..colon_pos].trim().to_string();
                let sig = trimmed[colon_pos + 1..].trim();

                let parts: Vec<&str> = sig.split("->").map(|s| s.trim()).collect();
                if parts.is_empty() {
                    continue;
                }

                let return_type = parts.last().expect("TODO: handle error").to_string();
                let params: Vec<Param> = parts[..parts.len() - 1]
                    .iter()
                    .enumerate()
                    .map(|(i, t)| Param {
                        name: format!("arg{}", i),
                        type_name: t.to_string(),
                        required: true,
                    })
                    .collect();

                contracts.push(FunctionContract {
                    name,
                    params,
                    return_type,
                    preconditions: vec![],
                    postconditions: vec![],
                    invariants: vec![],
                    require_total: true,
                    http_method: None,
                    path: None,
                });
            }
        }
    }

    if contracts.is_empty() {
        contracts.push(FunctionContract {
            name: iface.name.replace('-', "_"),
            params: vec![],
            return_type: "()".to_string(),
            preconditions: vec![],
            postconditions: vec![],
            invariants: vec![],
            require_total: true,
            http_method: None,
            path: None,
        });
    }

    Ok(contracts)
}

/// Convert an OpenAPI path to a function name.
/// /users/{id}/posts → get_users_by_id_posts
fn path_to_function_name(path: &str) -> String {
    path.trim_start_matches('/')
        .replace('/', "_")
        .replace('{', "by_")
        .replace('}', "")
        .replace("__", "_")
        .trim_end_matches('_')
        .to_string()
}

/// Convert a C type to an Idris2-compatible type name.
fn c_type_to_idris(c_type: &str) -> String {
    match c_type.trim() {
        "int" => "Int".to_string(),
        "unsigned int" | "uint32_t" => "Bits32".to_string(),
        "long" | "int64_t" => "Bits64".to_string(),
        "size_t" => "Nat".to_string(),
        "void*" | "void *" => "AnyPtr".to_string(),
        "const char*" | "const char *" | "char*" | "char *" => "String".to_string(),
        "uint8_t*" | "uint8_t *" | "const uint8_t*" => "Ptr Bits8".to_string(),
        "double" => "Double".to_string(),
        "float" => "Double".to_string(),
        "bool" | "_Bool" => "Bool".to_string(),
        "void" => "()".to_string(),
        other => {
            // Pointer types
            if other.ends_with('*') {
                format!(
                    "Ptr {}",
                    c_type_to_idris(other.trim_end_matches('*').trim())
                )
            } else {
                other.to_string()
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn path_to_function_name_basic() {
        assert_eq!(path_to_function_name("/users"), "users");
        assert_eq!(path_to_function_name("/users/{id}"), "users_by_id");
        assert_eq!(
            path_to_function_name("/users/{id}/posts"),
            "users_by_id_posts"
        );
    }

    #[test]
    fn c_type_conversion() {
        assert_eq!(c_type_to_idris("int"), "Int");
        assert_eq!(c_type_to_idris("void*"), "AnyPtr");
        assert_eq!(c_type_to_idris("const char*"), "String");
        assert_eq!(c_type_to_idris("size_t"), "Nat");
    }

    #[test]
    fn parse_c_function_simple() {
        let contract = try_parse_c_function("int process_item(void* input, size_t len);").expect("TODO: handle error");
        assert_eq!(contract.name, "process_item");
        assert_eq!(contract.return_type, "Int");
        assert_eq!(contract.params.len(), 2);
        assert_eq!(contract.params[0].name, "input");
        assert!(
            contract
                .preconditions
                .iter()
                .any(|p| p.contains("input != NULL"))
        );
    }

    #[test]
    fn parse_rpc_method() {
        let contract =
            try_parse_rpc("rpc GetUser (GetUserRequest) returns (UserResponse);").expect("TODO: handle error");
        assert_eq!(contract.name, "GetUser");
        assert_eq!(contract.params[0].type_name, "GetUserRequest");
        assert_eq!(contract.return_type, "UserResponse");
    }
}
