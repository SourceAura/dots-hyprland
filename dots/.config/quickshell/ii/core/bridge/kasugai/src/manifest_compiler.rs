/* manifest_compiler.rs — Substrate Policy Compiler
 * ==================================================
 * Parses the constitutional schemas inside LAW.mdx and compiles them
 * into a serialized Manifest.bin file (in JSON for portability and hot-swaps).
 *
 * Fold: SAGE (◈) — Compilation & System Verification.
 */

use std::fs;
use std::path::PathBuf;
use serde::{Serialize, Deserialize};
use serde_json;
use anyhow::{Result, Context};
use log::info;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct RuleEntry {
    pub command: String,
    pub required_sibyls: Vec<String>,
    pub breathing_styles: Vec<String>,
    pub action: String,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Manifest {
    pub rules: Vec<RuleEntry>,
    pub compiled_at: String,
}

fn resolve_paths() -> Result<(PathBuf, PathBuf)> {
    let home = dirs_next::home_dir().context("Failed to get home directory")?;
    let base_dir = home.join(".config/DankMaterialShell/plugins/SiM");
    let law_path = base_dir.join("LAW.mdx");
    let bin_path = base_dir.join("core/bridge/kasugai/Manifest.bin");
    Ok((law_path, bin_path))
}

pub fn compile() -> Result<()> {
    let (law_path, bin_path) = resolve_paths()?;
    info!("[compiler] Loading law from: {}", law_path.display());
    
    let content = fs::read_to_string(&law_path)
        .context(format!("Failed to read LAW.mdx from {}", law_path.display()))?;

    // Extract yaml block between ```yaml and ```
    let start_tag = "```yaml";
    let end_tag = "```";
    
    let start_idx = content.find(start_tag)
        .context("Could not find start of ```yaml block in LAW.mdx")? + start_tag.len();
    
    let end_idx = content[start_idx..].find(end_tag)
        .context("Could not find end of ```yaml block in LAW.mdx")? + start_idx;
        
    let yaml_str = content[start_idx..end_idx].trim();
    
    // Parse the rules
    let mut rules = Vec::new();
    let mut current_rule: Option<RuleEntry> = None;
    
    // Standard YAML parser fallback (since we don't have yaml crate, we parse structured lines)
    for line in yaml_str.lines() {
        let line = line.trim();
        if line.is_empty() { continue; }
        
        if line.starts_with("- command:") {
            if let Some(r) = current_rule.take() {
                rules.push(r);
            }
            let cmd_val = line.split("command:")
                .nth(1).unwrap_or("")
                .trim()
                .trim_matches('"')
                .trim_matches('\'')
                .to_string();
            current_rule = Some(RuleEntry {
                command: cmd_val,
                required_sibyls: Vec::new(),
                breathing_styles: Vec::new(),
                action: String::new(),
            });
        } else if line.starts_with("required_sibyls:") {
            if let Some(ref mut r) = current_rule {
                let sibyls_str = line.split("required_sibyls:").nth(1).unwrap_or("[]").trim();
                let parsed: Vec<String> = serde_json::from_str(sibyls_str).unwrap_or_default();
                r.required_sibyls = parsed;
            }
        } else if line.starts_with("breathing_styles:") {
            if let Some(ref mut r) = current_rule {
                let styles_str = line.split("breathing_styles:").nth(1).unwrap_or("[]").trim();
                let parsed: Vec<String> = serde_json::from_str(styles_str).unwrap_or_default();
                r.breathing_styles = parsed;
            }
        } else if line.starts_with("action:") {
            if let Some(ref mut r) = current_rule {
                let act_val = line.split("action:")
                    .nth(1).unwrap_or("")
                    .trim()
                    .trim_matches('"')
                    .trim_matches('\'')
                    .to_string();
                r.action = act_val;
            }
        }
    }
    
    if let Some(r) = current_rule {
        rules.push(r);
    }
    
    let duration = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default();
    
    let manifest = Manifest {
        rules,
        compiled_at: format!("{}", duration.as_secs()),
    };
    
    let serialized = serde_json::to_string_pretty(&manifest)?;
    
    // Ensure parent directory exists
    if let Some(parent) = bin_path.parent() {
        fs::create_dir_all(parent)?;
    }
    
    fs::write(&bin_path, serialized)?;
    info!("[compiler] Compiled successfully to: {}", bin_path.display());
    Ok(())
}

fn main() {
    env_logger::init();
    if let Err(e) = compile() {
        eprintln!("Manifest Compilation Failed: {:?}", e);
        std::process::exit(1);
    }
}
