fn main() {
    // SQLx embeds migrations. Recompile when SQL changes, including new files.
    println!("cargo:rerun-if-changed=migrations");
}
