use log::info;
use omnix_hub::core::config::AppConfig;
use omnix_hub::core::database::Database;
use omnix_hub::core::reports::ReportGenerator;
use omnix_hub::core::scanner::Scanner;
use std::env;
use std::path::PathBuf;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    env_logger::init();

    let config = AppConfig::load_or_default()?;
    info!("OmniX Hub v{} initialized", env!("CARGO_PKG_VERSION"));

    let db = Database::open(&config.database_path)?;
    db.initialize()?;

    let scanner = Scanner::new(&config, &db)?;

    let target = env::args()
        .nth(1)
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("."));

    if !target.exists() {
        eprintln!("Error: path '{}' does not exist.", target.display());
        std::process::exit(1);
    }

    println!("Scanning: {}", target.display());
    let results = scanner.scan_path(&target)?;

    let report = ReportGenerator::generate(&results);
    println!("{report}");

    let threats: Vec<_> = results.iter().filter(|r| r.is_threat()).collect();
    if !threats.is_empty() {
        println!(
            "\n{} threat(s) detected. Use --quarantine to isolate them.",
            threats.len()
        );

        if env::args().any(|a| a == "--quarantine") {
            let quarantine =
                omnix_hub::core::quarantine::Quarantine::new(&config.quarantine_dir, &db)?;
            for result in &threats {
                match quarantine.isolate(&result.file_path) {
                    Ok(record) => println!("Quarantined: {} -> {}", result.file_path, record.id),
                    Err(e) => eprintln!("Failed to quarantine {}: {e}", result.file_path),
                }
            }
        }
    } else {
        println!("\nNo threats detected.");
    }

    Ok(())
}
